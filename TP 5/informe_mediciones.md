# Informe de Mediciones — EXPLAIN ANALYZE antes y después de indexación

**Motor:** PostgreSQL 18.6
**Base de medición:** `TP2_Concurrencia_IA_Grupo11_clon` (copia de trabajo, protocolo `protocolo_seguridad.md`)
**Volumen de datos:** `usuario` 20.000 filas · `producto` 50.000 filas · `pedido` 200.000 filas
**Método:** `EXPLAIN (ANALYZE, BUFFERS, TIMING)` sobre cada consulta, antes y después de crear los índices.

---

## 1. Consultas analizadas

### Consulta 1 — Login / lookup por mail

```sql
SELECT id_usuario, nombre, rol
FROM   usuario
WHERE  mail = 'cliente_1234@foodstore.com'
  AND  eliminado = FALSE;
```

### Consulta 2 — Catálogo de productos por categoría

```sql
SELECT id_producto, nombre, precio, stock
FROM   producto
WHERE  categoria_id = 1
  AND  disponible = TRUE
  AND  eliminado = FALSE
ORDER  BY precio
LIMIT  50;
```

### Consulta 3 — Últimos pedidos de un usuario

```sql
SELECT id_pedido, fecha, estado, total
FROM   pedido
WHERE  usuario_id = 450
  AND  eliminado = FALSE
ORDER  BY fecha DESC
LIMIT  20;
```

---

## 2. Índices aplicados

| Nombre | Definición | Justificación |
| :----- | :--------- | :------------ |
| `idx_producto_categoria_precio` | `ON producto (categoria_id, precio) WHERE eliminado = FALSE AND disponible = TRUE` | Cubre los dos filtros de la consulta 2 (parcial) y entrega las filas ya ordenadas por `precio`, eliminando el `Sort`. |
| `idx_pedido_usuario_fecha` | `ON pedido (usuario_id, fecha DESC) WHERE eliminado = FALSE` | Parcial que precodifica `eliminado = FALSE` y entrega los pedidos del usuario ya ordenados por `fecha DESC`. |
| `usuario_mail_key` | `UNIQUE (usuario.mail)` — **ya existente** | Índice B-tree de punto para el login por mail. No se crea ningún índice nuevo. |

Se ejecutó `VACUUM ANALYZE producto;` y `VACUUM ANALYZE pedido;` antes de volver a medir, para que el planner use estadísticas actualizadas.

---

## 3. Comparación de resultados

| Consulta | Execution antes | Execution después | Variación | Índice usado antes | Índice usado después |
| :------- | --------------: | ----------------: | :-------- | :----------------- | :------------------- |
| **1. Login por mail** | 0.090 ms | 0.108 ms | sin cambio (ruido) | `usuario_mail_key` | `usuario_mail_key` |
| **2. Catálogo producto** | 4.592 ms | **0.289 ms** | **−93,7%** | `idx_producto_categoria_id` (simple) | `idx_producto_categoria_precio` |
| **3. Pedidos usuario 450** | 0.126 ms | 0.180 ms | neutro (ruido) | `idx_pedido_usuario_id` | `idx_pedido_usuario_fecha` |

---

### 3.1 Consulta 1 — antes y después (idéntico plan)

Antes:

```
Index Scan using usuario_mail_key on usuario  (cost=0.41..8.43 rows=1)
  Index Cond: ((mail)::text = 'cliente_1234@foodstore.com'::text)
  Filter: (NOT eliminado)
  Buffers: shared hit=4
Planning Time: 1.518 ms
Execution Time: 0.090 ms
```

Después (sin cambios):

```
Index Scan using usuario_mail_key on usuario  (cost=0.41..8.43 rows=1)
  Index Cond: ((mail)::text = 'cliente_1234@foodstore.com'::text)
  Filter: (NOT eliminado)
  Buffers: shared hit=4
Planning Time: 1.435 ms
Execution Time: 0.108 ms
```

### 3.2 Consulta 2 — antes y después

Antes (Bitmap Heap Scan + Sort):

```
Limit  (cost=1061.64..1061.77 rows=50)            actual 4.573 ms
  ->  Sort  (top-N heapsort, 31kB)               actual 4.569 ms  rows=50
        ->  Bitmap Heap Scan on producto         actual 3.772 ms  rows=3723
              Filter: (disponible AND (NOT eliminado))
              Rows Removed by Filter: 443
              Heap Blocks: exact=831   Buffers: shared hit=836
              ->  Bitmap Index Scan on idx_producto_categoria_id  rows=4166
Planning Time: 1.297 ms
Execution Time: 4.592 ms
```

Después (Index Scan directo):

```
Limit  (cost=0.29..46.48 rows=50)                 actual 0.278 ms  rows=50
  ->  Index Scan using idx_producto_categoria_precio on producto  rows=50
        Index Cond: (categoria_id = 1)
        Buffers: shared hit=50 read=2
Planning Time: 1.993 ms
Execution Time: 0.289 ms
```

### 3.3 Consulta 3 — antes y después

Antes:

```
Limit  (cost=43.10..43.12 rows=20)                actual 0.104 ms  rows=8
  ->  Sort  (quicksort, 25kB)                    actual 0.102 ms  rows=8
        ->  Bitmap Heap Scan on pedido           actual 0.083 ms  rows=8
              Filter: (NOT eliminado)
              Heap Blocks: exact=8   Buffers: shared hit=11
              ->  Bitmap Index Scan on idx_pedido_usuario_id  rows=8
Planning Time: 2.294 ms
Execution Time: 0.126 ms
```

Después:

```
Limit  (cost=43.10..43.12 rows=20)                actual 0.158 ms  rows=8
  ->  Sort  (quicksort, 25kB)                    actual 0.157 ms  rows=8
        ->  Bitmap Heap Scan on pedido           actual 0.133 ms  rows=8
              Recheck Cond: ((usuario_id = 450) AND (NOT eliminado))
              Heap Blocks: exact=8   Buffers: shared hit=8 read=3
              ->  Bitmap Index Scan on idx_pedido_usuario_fecha  rows=8
Planning Time: 2.359 ms
Execution Time: 0.180 ms
```

---

## 4. Análisis por consulta

### Consulta 1 — índice descartado y justificación

Se **descartó** la creación de cualquier índice nuevo (incluido un parcial `ON usuario (mail) WHERE eliminado = FALSE` y el `idx_usuario_activo` de la propuesta original). Motivos:

1. **El `UNIQUE (usuario.mail)` ya resuelve el acceso es un *point lookup*:** el B-tree del constraint devuelve a lo sumo una fila (`rows=1`). El plan resultante es un `Index Scan` de costo 0.41–8.43 con solo 4 buffers leídos.
2. **El filtro `eliminado = FALSE` no justifica un índice parcial:** se evalúa como `Filter` sobre una única fila. Duplicar el índice de `mail` para precodificar ese predicado ahorraría como mucho el filtrado de 1 tupla: beneficio nulo en tiempo (`0.090 ms` antes vs. `0.108 ms` después, diferencia de ruido) mientras que **agrega sobrecarga de escritura** (INSERT/UPDATE deben mantener dos B-trees).
3. **Integridad y simplicidad:** el `UNIQUE` global sobre `mail` garantiza unicidad incluso sobre filas borradas lógicamente; reemplazarlo por un parcial cambiaría la regla de negocio sin ganancia medible.

**Conclusión:** para el login por mail el índice correcto ya existía; no se crea nada nuevo.

### Consulta 2 — índice ganador

`idx_producto_categoria_precio` produjo el mayor impacto: **4.592 ms → 0.289 ms (−93,7%)**.

- El índice parcial **absorbe los tres predicados** (`categoria_id`, `disponible`, `eliminado`) como parte de la estructura, eliminando el `Rows Removed by Filter` (443 tuplas descartadas) y el `Heap Blocks: exact=831`.
- La segunda columna `precio` hace que el `Sort (top-N heapsort)` **desaparezca**: las 50 filas del `LIMIT` salen directamente del orden del índice.
- Cambio de plan: `Sort → Bitmap Heap Scan → Bitmap Index Scan` pasa a **`Index Scan` puro**, leyendo solo 50 filas (Buffers: 839 → 52).

### Consulta 3 — índice correcto con impacto no visible en este caso de prueba

`idx_pedido_usuario_fecha` pasó a ser el índice usado (nodo `Bitmap Index Scan on idx_pedido_usuario_fecha`), pero el tiempo no bajó (0.126 → 0.180 ms, dentro del ruido).

Motivo: el usuario `id = 450` tiene **solo 8 pedidos**. El planner considera más barato un `quicksort` de 25 kB sobre 8 filas que recorrer el índice en orden; por eso mantiene el nodo `Sort` y el `Bitmap Heap Scan`. El beneficio del índice compuesto (parcial + orden `fecha DESC`) se manifiesta cuando un usuario tiene muchos pedidos: ahí entrega las filas ya ordenadas y corta con `LIMIT 20` sin ordenar ni barrer todo el histórico. Se mantiene porque es el índice correcto para el *workload* real de paginación keyset de `indices.sql` (Q2).

---

## 5. Resumen

| Consulta | Decisión | Resultado medible |
| :------- | :------- | :---------------- |
| 1. Login por mail | Sin índice nuevo (usar `usuario_mail_key`) | sin cambio (ya óptimo) |
| 2. Catálogo por categoría | Crear `idx_producto_categoria_precio` | 4.592 → 0.289 ms (−93,7%), sin Sort |
| 3. Pedidos por usuario | Crear `idx_pedido_usuario_fecha` | cambio de índice usado; Sort no desaparece por volumen pequeño (8 filas) |

**Respaldo previo a los cambios:** `backup_pre_indices_20260917_194800.dump`.
**Rollback de emergencia:**

```sql
DROP INDEX idx_producto_categoria_precio;
DROP INDEX idx_pedido_usuario_fecha;
```
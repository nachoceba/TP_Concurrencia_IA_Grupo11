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

---

## 6. Vistas de negocio (`views.sql`)

Las tres vistas se ejecutaron sobre el clon con `psql -U postgres -d TP2_Concurrencia_IA_Grupo11_clon -f views.sql` (envueltas en `BEGIN/COMMIT`, protocolo Paso 2).

| Vista | Propósito | Notas |
| :---- | :-------- | :---- |
| `v_pedidos_resumen` | Resumen de pedidos vigentes con cliente (HU-PED-01) | Referenciada por `queries.sql`; antes no existía y la consulta fallaba |
| `v_catalogo_productos` | Catálogo vigente para el frontend | Solo productos vigentes y disponibles, con categoría |
| `v_usuarios_segura` | **Vista de seguridad** sobre `usuario` | Omite `contrasena`; solo usuarios vigentes; permite `GRANT SELECT` sin acceso a la tabla base |

### 6.1 Criterio de seguridad de `v_usuarios_segura`

Expone únicamente: `id_usuario, nombre, apellido, mail, celular, rol` — **nunca `contrasena`**. Al no otorgarse privilegios sobre la tabla `usuario`, un rol solo puede leer el resultado a través de la vista:

```sql
GRANT SELECT ON v_usuarios_segura TO aplicacion_lectura;
```

Verificación: `SELECT count(*) FROM information_schema.columns WHERE table_name = 'v_usuarios_segura' AND column_name = 'contrasena';` → **0** filas (la columna no existe en la vista).

---

## 7. Verificación de equivalencia de las vistas contra la consulta manual

Método simétrico con `EXCEPT` en ambas direcciones (`vista EXCEPT manual` y `manual EXCEPT vista`): un resultado de 0 filas en las dos direcciones garantiza que vista y consulta manual producen **exactamente el mismo conjunto** (mismas filas, misma cantidad).

### 7.1 `v_pedidos_resumen` vs. consulta manual

```sql
-- (manual)
SELECT p.id_pedido, u.nombre || ' ' || u.apellido, p.fecha, p.estado,
       p.forma_pago, p.total
FROM   pedido p
JOIN   usuario u ON u.id_usuario = p.usuario_id
WHERE  p.eliminado = FALSE AND u.eliminado = FALSE;
```

| Dirección | Filas de diferencia |
| :-------- | ------------------: |
| `vista EXCEPT manual` | 0 |
| `manual EXCEPT vista` | 0 |

**Equivalencia comprobada.**

### 7.2 `v_catalogo_productos` vs. consulta manual

```sql
-- (manual)
SELECT pr.id_producto, pr.nombre, pr.precio, pr.stock, pr.disponible, c.nombre
FROM   producto pr
JOIN   categoria c ON c.id_categoria = pr.categoria_id
WHERE  pr.eliminado = FALSE AND c.eliminado = FALSE;
```

| Dirección | Filas de diferencia |
| :-------- | ------------------: |
| `vista EXCEPT manual` | 0 |
| `manual EXCEPT vista` | 0 |

**Equivalencia comprobada.**

### 7.3 `v_usuarios_segura` vs. consulta manual

```sql
-- (manual)
SELECT id_usuario, nombre, apellido, mail, celular, rol
FROM   usuario
WHERE  eliminado = FALSE;
```

| Dirección | Filas de diferencia |
| :-------- | ------------------: |
| `vista EXCEPT manual` | 0 |
| `manual EXCEPT vista` | 0 |

Además se validó el criterio de vigencia: `v_usuarios_segura` = **20.000** filas = total de `usuario` con `eliminado = FALSE` (20.000). **Equivalencia comprobada.**

---

## 8. Resumen de la parte A

1. **Consulta 1 (login por mail):** sin índice nuevo — el `UNIQUE (usuario.mail)` ya era óptimo (punto 4).
2. **Consulta 2 (catálogo):** `idx_producto_categoria_precio` → 4.592 → 0.289 ms (−93,7%).
3. **Consulta 3 (pedidos por usuario):** `idx_pedido_usuario_fecha` → plan usa el índice parcial; el `Sort` persiste solo por el bajo volumen de filas del usuario de prueba.
4. **Vistas (`views.sql`):** `v_pedidos_resumen`, `v_catalogo_productos` y `v_usuarios_segura` (seguridad, sin `contrasena`) — equivalencia contra la consulta manual verificada con `EXCEPT` (0 filas en ambos sentidos).

---

## 9. Vista materializada del ranking Top-3 por categoría

### 9.1 Selección de la consulta (la más costosa)

Se compararon las consultas del repositorio que usan `SUM()`/`COUNT()`/`AVG()` con `GROUP BY` y **sin índice dedicado en `indices.sql`**:

| # | Consulta (origen) | Tablas | Costo estimado (`EXPLAIN`) |
| :- | :---------------- | :----- | -------------------------: |
| C1 | TP3 `Consulta1.sql` (HAVING + AVG) | usuario, pedido | ~12.231 |
| C2 | TP3 `Consulta2.sql` (CTE) | usuario, pedido | ~7.261 |
| C3 | TP4 Parte 3, Consulta 1 (`ROW_NUMBER`) | detalle_pedido, producto, categoria | ~83.584 |
| **C4** | **TP4 Parte 3, Consulta 2 (correlacionada)** | detalle_pedido, producto, categoria | **~1.600.277.688** |
| C5 | `queries.sql` B (facturación por categoría/mes) | detalle_pedido, pedido, producto, categoria | ~87.328 |

**Consulta elegida: C4** (TP4 Parte 3, Consulta 2). Es la más costosa (~19.000× la siguiente) por sus dos `COUNT(*)` correlacionados que re-escanean el CTE completo por fila → comportamiento **O(n²)**. Ninguna de las 12 propuestas de `indices.sql` la cubre.

### 9.2 Definición materializada

Se materializa con la **versión equivalente con `ROW_NUMBER()` (C3)** — semánticamente idéntica a C4 (equivalencia ya probada con `EXCEPT` en TP4) pero de build rápido, evitando pagar el O(n²) en cada refresco.

```sql
CREATE MATERIALIZED VIEW mv_top_productos_categoria AS
WITH agg AS ( ... SUM(dp.subtotal) ... GROUP BY c.nombre, pr.id_producto, pr.nombre ),
     ranked AS ( ... ROW_NUMBER() OVER (PARTITION BY categoria ORDER BY facturado DESC, id_producto ASC) ... )
SELECT categoria, id_producto, producto, facturado, puesto
FROM   ranked
WHERE  puesto <= 3
ORDER  BY categoria ASC, puesto ASC, id_producto ASC
WITH DATA;

CREATE UNIQUE INDEX uq_mv_top_productos_puesto
    ON mv_top_productos_categoria (categoria, id_producto);
```

- **`WITH DATA`:** llenado inmediato (exigido).
- **Índice único `(categoria, id_producto)`:** requisito para `REFRESH MATERIALIZED VIEW CONCURRENTLY`; cada `id_producto` aparece una sola vez (1 producto → 1 categoría), por lo que la clave es única por fila.

### 9.3 Resultados medidos (clon)

| Operación | Resultado |
| :-------- | :-------- |
| Build `CREATE MATERIALIZED VIEW ... WITH DATA` | **241,962 ms** |
| `CREATE UNIQUE INDEX` | 2,519 ms |
| `REFRESH MATERIALIZED VIEW CONCURRENTLY` | **248,513 ms** (OK, el índice único lo habilita) |

Saneamiento: `max(puesto) = 1`, ninguna categoría con más de 3 productos, y **equivalencia simétrica `EXCEPT`** del MV contra la consulta inline → **0 filas en ambas direcciones**.

Nota sobre el volumen observado: el resultado del MV tiene **1 fila** (categoría `Empanadas`, producto `#4538`, facturado 2.260.420.000,00) porque en los datos cargados **solo un producto (de 50.000) tiene filas en `detalle_pedido`**. La lógica del MV queda validada igualmente por la equivalencia `EXCEPT`.

### 9.4 Comparación de tiempo: vista materializada vs. consulta original

Medición con `EXPLAIN (ANALYZE, BUFFERS, TIMING)` sobre el clon:

| Consulta | Plan | Execution Time | Buffers |
| :------- | :--- | -------------: | ------: |
| **Vista materializada** (`SELECT * FROM mv_top_productos_categoria`) | `Seq Scan` (1 fila) | **0.087 ms** | 1 |
| **Original C4** (correlacionada, la elegida) | `Sort` + CTE + 2 subplan correlacionados | 242.733 ms | 3.379 + temp 2.597 |
| **C3 equivalente** (`ROW_NUMBER`, definición del MV) | `Incremental Sort` + `WindowAgg` | 237.930 ms | 3.376 + temp 2.597 |

**Speedup del MV ≈ 2.790×** respecto de la consulta original (`242,733 / 0,087`). El MV además elimina el derrame a disco (`temp read=2597 written=2605`) y los ~3.379 buffers de la consulta original.

Observación: C4 midió 242 ms —no el tiempo catastrófico que sugería su costo estimado (1,6×10⁹)— porque el planner **sobreestima el CTE `agg`** (estima ~200.000 filas cuando en los datos reales produce 1). Aun con la estimación pesimista corregida, el MV evita por completo ese trabajo en cada consulta.

### 9.5 Rollback

```sql
DROP MATERIALIZED VIEW mv_top_productos_categoria;
```

Respaldo previo: `backup_pre_mv_20260917_203453.dump`.

---

### 9.6 Frecuencia de `REFRESH` y consistencia temporal

#### Uso esperado del reporte

El MV `mv_top_productos_categoria` alimenta el **Top-3 de productos por facturación acumulada por categoría**: un **KPI de gestión**, no un panel operativo en tiempo real. La métrica es *acumulada*, por lo que evoluciona lentamente y no exige reflejar cada venta al instante.

#### Frecuencia recomendada: **1 vez por día, a las 03:00**

- Se ejecuta fuera del horario pico de escritura (menor contención con las operaciones de venta).
- Es un reporte de gestión: la ventana de datos "hasta el cierre del día anterior" es funcionalmente suficiente.
- El refresh medido es barato (**~248 ms**) y, al usar `CONCURRENTLY`, **no bloquea las lecturas** del reporte mientras corre.

```sql
-- Programacion diaria con pg_cron (03:00)
SELECT cron.schedule(
    'refresh-top3',
    '0 3 * * *',
    'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_productos_categoria;'
);
```

Alternativas sin `pg_cron`: Task Scheduler de Windows o un job de la aplicación que dispare la misma sentencia.

#### Por qué `REFRESH ... CONCURRENTLY`

- No toma `AccessExclusiveLock`: los usuarios pueden **seguir consultando el MV** durante el refresco.
- Requiere el **índice único** `uq_mv_top_productos_puesto` (ya creado) — sin él, PostgreSQL rechaza el refresh concurrente.
- **No puede ejecutarse dentro de una transacción** ni en funciones con control transaccional; debe lanzarse como sentencia suelta (compatible con `pg_cron`).
- Es más costoso que un `REFRESH` normal, pero con 248 ms medidos la diferencia es despreciable.

#### Implicaciones para los usuarios cuando el dato no está actualizado

| Aspecto | Implicación |
| :------ | :---------- |
| **Ventana de inconsistencia** | El reporte refleja el estado del **último refresh (03:00)**. Un pedido pasado a `TERMINADO` después de esa hora **no aparece** hasta la noche siguiente (hasta ~24 h). |
| **Atomicidad** | Cada refresh es un **snapshot atómico**: nunca se ven datos a medio actualizar ni lecturas parciales. |
| **Toma de decisiones** | El ranking puede estar "un día atrasado". Para decisiones de gestión es aceptable (la facturación acumulada casi no cambia de posición); **no** es apto para decisiones operativas en vivo. |
| **Datos que desaparecen** | Si un dato sale del Top-3 por ventas más recientes, el MV lo sigue mostrando hasta el próximo refresh. |
| **Mitigación** | Exponer la antigüedad del dato ("Datos al &lt;fecha&gt;"), idealmente con una columna `refreshed_at` (`now() AS refreshed_at` en la definición del MV). Si se necesita el valor exacto del momento, consultar la base en vivo. |
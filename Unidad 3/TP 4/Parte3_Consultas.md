## 1. Especificaciones de las Consultas

### Consulta A (Ranking con Función de Ventana)

- **Objetivo:** Obtener el top-3 de productos por facturación acumulada dentro de cada categoría.
- **Tablas:** `categoria` (c), `producto` (pr), `detalle_pedido` (dp).
- **Filtros de vigencia:** `pr.eliminado = FALSE` y `c.eliminado = FALSE`.
- **Columnas de salida:** `categoria`, `id_producto`, `producto`, `facturado`, `puesto`.
- **Criterio de orden y desempate:** `facturado DESC`, `id_producto ASC`.
- **Corte:** `puesto <= 3`.

---

## 2. Código SQL

### Consulta 1: Ranking con Función de Ventana (`ROW_NUMBER`)

```sql
WITH agg AS (
    SELECT c.nombre        AS categoria,
           pr.id_producto,
           pr.nombre        AS producto,
           SUM(dp.subtotal) AS facturado
    FROM   detalle_pedido dp
    JOIN   producto pr  ON pr.id_producto  = dp.producto_id
    JOIN   categoria c  ON c.id_categoria = pr.categoria_id
    WHERE  pr.eliminado = FALSE
      AND  c.eliminado = FALSE
    GROUP  BY c.nombre, pr.id_producto, pr.nombre
),
ranked AS (
    SELECT categoria, id_producto, producto, facturado,
           ROW_NUMBER() OVER (
               PARTITION BY categoria
               ORDER BY facturado DESC, id_producto ASC
           ) AS puesto
    FROM agg
)
SELECT categoria, id_producto, producto, facturado, puesto
FROM   ranked
WHERE  puesto <= 3
ORDER  BY categoria ASC, puesto ASC, id_producto ASC;
```

---

### Consulta 2: Estructura equivalente con Subconsulta Correlacionada

```sql
WITH agg AS (
    SELECT c.nombre        AS categoria,
           pr.id_producto,
           pr.nombre        AS producto,
           SUM(dp.subtotal) AS facturado
    FROM   detalle_pedido dp
    JOIN   producto pr  ON pr.id_producto  = dp.producto_id
    JOIN   categoria c  ON c.id_categoria = pr.categoria_id
    WHERE  pr.eliminado = FALSE
      AND  c.eliminado = FALSE
    GROUP  BY c.nombre, pr.id_producto, pr.nombre
)
SELECT a.categoria,
       a.id_producto,
       a.producto,
       a.facturado,
       ((SELECT COUNT(*)
         FROM   agg b
         WHERE  b.categoria = a.categoria
           AND  (b.facturado > a.facturado
                 OR (b.facturado = a.facturado AND b.id_producto < a.id_producto))
        ) + 1) AS puesto
FROM   agg a
WHERE  (SELECT COUNT(*)
        FROM   agg b
        WHERE  b.categoria = a.categoria
          AND  (b.facturado > a.facturado
                OR (b.facturado = a.facturado AND b.id_producto < a.id_producto))
       ) < 3
ORDER  BY a.categoria ASC, puesto ASC, a.id_producto ASC;
```

---

## 3. Verificación de Equivalencia (`EXCEPT`)

```sql
WITH agg AS (
    SELECT c.nombre AS categoria, pr.id_producto, pr.nombre AS producto,
           SUM(dp.subtotal) AS facturado
    FROM detalle_pedido dp
    JOIN producto pr ON pr.id_producto = dp.producto_id
    JOIN categoria c ON c.id_categoria = pr.categoria_id
    WHERE pr.eliminado = FALSE AND c.eliminado = FALSE
    GROUP BY c.nombre, pr.id_producto, pr.nombre
),
q1 AS (
    SELECT categoria, id_producto, producto, facturado,
           ROW_NUMBER() OVER (PARTITION BY categoria ORDER BY facturado DESC, id_producto ASC) AS puesto
    FROM agg
),
q1f AS (SELECT * FROM q1 WHERE puesto <= 3),
q2 AS (
    SELECT a.categoria, a.id_producto, a.producto, a.facturado,
           ((SELECT COUNT(*) FROM agg b
             WHERE b.categoria = a.categoria
               AND (b.facturado > a.facturado
                    OR (b.facturado = a.facturado AND b.id_producto < a.id_producto))) + 1) AS puesto
    FROM agg a
    WHERE (SELECT COUNT(*) FROM agg b
           WHERE b.categoria = a.categoria
             AND (b.facturado > a.facturado
                  OR (b.facturado = a.facturado AND b.id_producto < a.id_producto))) < 3
)
(SELECT * FROM q1f EXCEPT SELECT * FROM q2)
UNION ALL
(SELECT * FROM q2 EXCEPT SELECT * FROM q1f);
```

**Resultado de la verificación:** `0 filas` (Equivalencia comprobada).

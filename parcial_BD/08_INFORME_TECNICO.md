# Informe Tecnico - Food Store (Parcial BD II)

## 1. Que se implemento por unidad

- **U1 Integridad/transacciones/concurrencia:** DDL `01_schema.sql` (PK/FK/CHECK/UNIQUE),
  `04_objects.sql` (triggers + `sp_crear_pedido` con `FOR UPDATE`), `06_transacciones.sql`
  (COMMIT/ROLLBACK, READ COMMITTED vs REPEATABLE READ, bloqueo).
- **U2 Optimizacion:** `05_indices.sql` (parciales, compuestos, covering, trigram) +
  reescrituras Q1-Q6 medidas con `EXPLAIN (ANALYZE, BUFFERS, TIMING)`.
- **U3 Indices/vistas/programables:** 6 vistas + 1 materializada en `04_objects.sql`,
  funcion `calcular_total_pedido`, procedimiento `CALL sp_crear_pedido`,
  triggers ROW + STATEMENT con transition tables.

## 2. Modelo y normalizacion

![DER - modelo conceptual](imagenes/der.png)
![Esquema relacional-fisico](imagenes/relacional.png)

- 1FN: items de pedido en `detalle_pedido` (atomicos).
- 2FN: PKs surrogadas IDENTITY simples, sin dependencias parciales.
- 3FN: sin transitivas (`producto.categoria_id` en vez de nombre; `precio_unitario`
  congelado para historizar, no deriva transitiva).
- BCNF: `usuario(id)` y `usuario(mail UNIQUE)` ambas determinantes.
  Excepcion justificada: `subtotal/total` derivados, mantenidos por trigger.

## 3. Metodologia de pruebas

Cada script se probo en clon (`createdb -T`), con `BEGIN; \i <file>` +
inspeccion de mensajes + `ROLLBACK` antes del `COMMIT` definitivo, y `pg_dump -Fc`
previo a cambios estructurales. Equivalencia de vistas con `EXCEPT` bidireccional
(0 filas). Triggers verificados con inserts validos/invalidos. Transacciones en
2 terminales psql lado a lado.

## 4. Resultados

- Triggers: `subtotal=cantidad*precio` (BEFORE) y `total=SUM(subtotal)` (AFTER ROW
  + STATEMENT `REFERENCING NEW/OLD TABLE`) verificados; `CALL sp_crear_pedido`
  descuenta stock con `FOR UPDATE` y falla atomica ante stock insuficiente.
- Vistas: 6 + MV `mv_top_productos_categoria` con `WITH DATA` e indice unico para
  `REFRESH CONCURRENTLY`; `EXCEPT` 0 filas en ambas direcciones.
- Transacciones: non-repeatable read visible en READ COMMITTED y evitado en
  REPEATABLE READ; bloqueo `FOR UPDATE` con espera liberada por COMMIT.

## 5. Optimizacion: antes vs despues

![EXPLAIN pedido por usuario antes](imagenes/explain_pedido_antes.png)
![EXPLAIN pedido por usuario despues](imagenes/explain_pedido_despues.png)
![EXPLAIN producto por nombre antes](imagenes/explain_producto_antes.png)
![EXPLAIN producto por nombre despues](imagenes/explain_producto_despues.png)

| Consulta | Antes | Despues | Mejora |
|---|---|---|---|
| Catalogo `categoria_id=1 ORDER BY precio LIMIT 50` | Bitmap Heap + Sort ~4.59 ms | Index Scan `idx_producto_categoria_precio` ~0.29 ms | -93% |
| Pedidos `usuario_id=450` | Bitmap + Sort ~0.13 ms | Bitmap `idx_pedido_usuario_fecha` ~0.18 ms (ruido, 8 filas) | neutro, indice correcto para paginacion |
| Login `mail=` | Index Scan `usuario_mail_key` 0.09 ms | igual 0.11 ms | sin indice nuevo (UNIQUE ya optimo) |

En tablas chicas el planner prefiere Seq Scan; se uso `SET enable_seqscan=OFF`
solo para comparar planes de forma controlada. El beneficio real aparece con
volumen (`03_data_masivo.sql`).

## 6. Capturas de concurrencia

![Sesion A/B read committed](imagenes/concurrencia_read_committed.png)
![Sesion A/B repeatable read](imagenes/concurrencia_repeatable.png)

Pasos sec.5 del PDF: stock=12, B vende 5 (COMMIT 7), A relee: 7 en
READ COMMITTED (anomalia) vs 12 en REPEATABLE READ (snapshot).

## 7. Transparencia IA

Se utilizaron asistentes de codigo (OpenCode / Gemini) para la refactorizacion
de scripts DDL/DML, optimizacion de triggers PL/pgSQL y estructuracion de
pruebas con EXPLAIN ANALYZE.
- Aceptado: migración SERIAL→IDENTITY, DATE→TIMESTAMPTZ, columna JSONB
  `pedido.metadatos`, unificacion de vistas A+B, triggers statement-level con
  transition tables, correccion de `queries.sql` (nombres PK, JOIN pedido-detalle,
  HAVING, filtro `eliminado`).
- Descartado: reemplazar triggers ROW por solo statement-level (se mantienen
  ambos por compatibilidad con inserts unitarios); crear indice parcial sobre
  `usuario(mail)` (el UNIQUE existente ya es optimo); renombrar PKs a `id`
  corto (se conserva `id_producto/id_pedido` del esquema vigente).

## 8. Bibliografia

- Docs PostgreSQL: trigger-definition, CREATE VIEW/FUNCTION/PROCEDURE, MVCC.
- W3Schools SQL, PostgreSQLTutorial triggers.
- Videos YouTube + docs oficiales para transition tables (`REFERENCING NEW TABLE`)
  y diferencia BEFORE/AFTER (prueba con `RAISE NOTICE` sobre `afectados`).

## 9. Como reproducir en vivo

```bash
psql -d food_store_parcial -f 01_schema.sql
psql -d food_store_parcial -f 04_objects.sql
psql -d food_store_parcial -f 02_data_demo.sql
psql -d food_store_parcial -f 05_indices.sql
# 06 por bloques en 2 terminales, 07 por bloques, EXPLAIN con BUFFERS
```

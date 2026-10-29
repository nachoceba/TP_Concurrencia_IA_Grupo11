-- validacion_restore.sql — Validación mínima post-restauración (Parte 4)
-- Se ejecuta SOLO contra foodstore_restore_test:
--   psql -d foodstore_restore_test -f sql/validacion_restore.sql
--
-- Diferencia con el PDF: la consulta de referencia cuenta la tabla "cliente",
-- que no existe en nuestro schema. Se reemplaza por "usuario". El conteo por
-- tabla lo hace conteo_filas.sql; acá van los controles de reglas lógicas.

\echo '== Base conectada (tiene que ser foodstore_restore_test)'
SELECT current_database();

\echo '== Productos inválidos (tiene que dar 0)'
SELECT COUNT(*) AS productos_invalidos
FROM producto
WHERE precio < 0 OR stock < 0;

\echo '== Detalles inválidos (tiene que dar 0)'
SELECT COUNT(*) AS detalles_invalidos
FROM detalle_pedido
WHERE cantidad <= 0 OR precio_unitario < 0;

-- Controles extra: que vengan las restricciones y los triggers, no sólo los datos
\echo '== Restricciones restauradas por tipo (c=CHECK, f=FK, p=PK, u=UNIQUE)'
SELECT contype, COUNT(*) AS cantidad
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
GROUP BY contype ORDER BY contype;

\echo '== FKs huérfanas en detalle_pedido (tiene que dar 0)'
SELECT COUNT(*) AS detalles_huerfanos
FROM detalle_pedido d
LEFT JOIN pedido p ON p.id_pedido = d.pedido_id
WHERE p.id_pedido IS NULL;

\echo '== Triggers de Food Store restaurados'
SELECT event_object_table AS tabla, trigger_name
FROM information_schema.triggers
WHERE trigger_schema = 'public'
GROUP BY 1, 2 ORDER BY 1, 2;

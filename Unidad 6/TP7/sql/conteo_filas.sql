-- conteo_filas.sql — Conteo de filas por tabla de Food Store.
-- Lo usan backup_foodstore.sh (antes del dump, se guarda en .counts)
-- y restore_test.sh (después de restaurar, para comparar).
-- Salida pensada para psql -tA -F '|'  →  tabla|filas
-- NOTA: el PDF de la cátedra pide contar "cliente", pero esa tabla no existe en
-- nuestro schema (parcial_BD/01_schema.sql). Los clientes viven en "usuario".
SELECT 'categoria'      AS tabla, COUNT(*) AS filas FROM categoria
UNION ALL SELECT 'usuario',        COUNT(*) FROM usuario
UNION ALL SELECT 'producto',       COUNT(*) FROM producto
UNION ALL SELECT 'pedido',         COUNT(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido
ORDER BY tabla;

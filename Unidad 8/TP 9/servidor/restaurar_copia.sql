-- =============================================================================
-- TP 8 · Deja la copia de pruebas como estaba antes de preparar_casos.sql
-- (para poder repetir los casos desde cero). Solo sobre food_store_tp8.
-- =============================================================================
BEGIN;
UPDATE producto SET precio = 5200.00 WHERE id_producto = 4;
UPDATE producto SET eliminado = false WHERE id_producto = 7;
COMMIT;

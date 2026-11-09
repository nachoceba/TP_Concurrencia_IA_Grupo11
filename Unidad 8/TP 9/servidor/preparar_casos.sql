-- =============================================================================
-- TP 8 · Consigna 2.c · Cambios en la COPIA del servidor para preparar los casos
-- Solo sobre la copia de pruebas (food_store_tp8). Valores fijos para que se
-- pueda repetir. NO toca stock ni pedidos: así la verificación final lo demuestra.
--   C2: sube el precio de la Napolitana (id 4): 5200.00 -> 5600.00
--   C4: baja lógica de la Empanada Roquefort (id 7)
-- =============================================================================
BEGIN;
UPDATE producto SET precio = 5600.00 WHERE id_producto = 4;   -- C2
UPDATE producto SET eliminado = true WHERE id_producto = 7;   -- C4 (baja lógica)
COMMIT;

SELECT id_producto, nombre, precio, stock, disponible, eliminado
FROM producto WHERE id_producto IN (4, 7) ORDER BY 1;

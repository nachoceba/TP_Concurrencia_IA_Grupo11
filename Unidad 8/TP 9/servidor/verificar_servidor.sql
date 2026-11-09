-- =============================================================================
-- TP 8 · Consigna 2.c · Prueba de que la simulación NO cambió PostgreSQL
-- Se corre antes y después de los casos: los dos resultados tienen que ser iguales.
--   pedidos / detalles: la tablet no creó ninguna venta (SIMULADO_APROBADO no es venta)
--   stock_total y huella_stock: ningún stock se movió (md5 de id:stock de todos los productos)
-- =============================================================================
SELECT (SELECT count(*) FROM pedido)          AS pedidos,
       (SELECT count(*) FROM detalle_pedido)  AS detalles,
       (SELECT sum(stock) FROM producto)      AS stock_total,
       (SELECT md5(string_agg(id_producto || ':' || stock, ',' ORDER BY id_producto))
          FROM producto)                      AS huella_stock;

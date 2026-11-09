-- =============================================================================
-- TP 8 · Consigna 3.c · Hallazgo H4 (corregido) · agregado a Unidad 6/TP7/sql/validacion_restore.sql
-- El control "productos inválidos (precio < 0 OR stock < 0)" siempre da 0 porque ya
-- lo garantizan los CHECK del esquema. Lo que de verdad hay que validar después de un
-- restore son las reglas que mantienen los triggers y el CHECK compuesto:
-- =============================================================================
\echo '== Pedidos con total distinto de la suma de sus subtotales (tiene que dar 0)'
SELECT count(*) AS pedidos_total_incoherente
FROM pedido p
WHERE p.total <> COALESCE((SELECT sum(d.subtotal) FROM detalle_pedido d
                           WHERE d.pedido_id = p.id_pedido), 0);

\echo '== Detalles con subtotal distinto de cantidad * precio_unitario (tiene que dar 0)'
SELECT count(*) AS detalles_subtotal_incoherente
FROM detalle_pedido WHERE subtotal <> cantidad * precio_unitario;

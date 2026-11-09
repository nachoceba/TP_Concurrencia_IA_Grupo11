-- =============================================================================
-- TP 8 · Consigna 2.c · Paso 1 (tablet, sin señal): se arman los borradores
-- Los precios vistos salen de producto_cache (instantánea S1, antes de los cambios).
-- Cada borrador se guarda en una transacción con su solicitud PENDIENTE.
-- =============================================================================
PRAGMA foreign_keys = ON;

-- limpieza para poder repetir (ON DELETE CASCADE borra ítems y solicitudes)
DELETE FROM pedido_borrador WHERE id_local IN (
  'c2c2c2c2-0000-4000-8000-000000000002', 'c3c3c3c3-0000-4000-8000-000000000003',
  'c4c4c4c4-0000-4000-8000-000000000004', 'c5c5c5c5-0000-4000-8000-000000000005',
  'c6c6c6c6-0000-4000-8000-000000000006');

-- C2 · 2 Napolitanas + 1 Coca (después el servidor sube la Napolitana)
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id, forma_pago) VALUES ('c2c2c2c2-0000-4000-8000-000000000002', 1, 'EFECTIVO');
INSERT INTO item_borrador SELECT 'c2c2c2c2-0000-4000-8000-000000000002', id, 2, precio_centavos FROM producto_cache WHERE id = 4;
INSERT INTO item_borrador SELECT 'c2c2c2c2-0000-4000-8000-000000000002', id, 1, precio_centavos FROM producto_cache WHERE id = 11;
INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES ('5c200000-0000-4000-8000-00000000c2a1', 'c2c2c2c2-0000-4000-8000-000000000002');
COMMIT;

-- C3 · 15 flanes; la copia dice que quedan 12 (stock_visto es referencia, no reserva)
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id, forma_pago) VALUES ('c3c3c3c3-0000-4000-8000-000000000003', 2, 'TARJETA');
INSERT INTO item_borrador SELECT 'c3c3c3c3-0000-4000-8000-000000000003', id, 15, precio_centavos FROM producto_cache WHERE id = 14;
INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES ('5c300000-0000-4000-8000-00000000c300', 'c3c3c3c3-0000-4000-8000-000000000003');
COMMIT;

-- C4 · 6 empanadas de roquefort (después el servidor las da de baja)
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id, forma_pago) VALUES ('c4c4c4c4-0000-4000-8000-000000000004', 3, 'TRANSFERENCIA');
INSERT INTO item_borrador SELECT 'c4c4c4c4-0000-4000-8000-000000000004', id, 6, precio_centavos FROM producto_cache WHERE id = 7;
INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES ('5c400000-0000-4000-8000-00000000c400', 'c4c4c4c4-0000-4000-8000-000000000004');
COMMIT;

-- C5 · 1 Muzzarella + 2 aguas (nada cambia en el servidor)
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id, forma_pago) VALUES ('c5c5c5c5-0000-4000-8000-000000000005', 4, 'EFECTIVO');
INSERT INTO item_borrador SELECT 'c5c5c5c5-0000-4000-8000-000000000005', id, 1, precio_centavos FROM producto_cache WHERE id = 1;
INSERT INTO item_borrador SELECT 'c5c5c5c5-0000-4000-8000-000000000005', id, 2, precio_centavos FROM producto_cache WHERE id = 13;
INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES ('5c500000-0000-4000-8000-00000000c500', 'c5c5c5c5-0000-4000-8000-000000000005');
COMMIT;

-- C6 · 1 Burger Simple; después se reenvía la MISMA solicitud
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id, forma_pago) VALUES ('c6c6c6c6-0000-4000-8000-000000000006', 5, 'TARJETA');
INSERT INTO item_borrador SELECT 'c6c6c6c6-0000-4000-8000-000000000006', id, 1, precio_centavos FROM producto_cache WHERE id = 8;
INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES ('5c600000-0000-4000-8000-00000000c600', 'c6c6c6c6-0000-4000-8000-000000000006');
COMMIT;

.headers on
.mode column --wrap 0
SELECT substr(c.solicitud_uuid,25) AS solicitud, substr(b.id_local,1,8) AS borrador,
       group_concat(i.cantidad || ' x ' || p.nombre || ' @ ' || i.precio_centavos_visto, ' + ') AS items,
       c.estado
FROM cola_sync c JOIN pedido_borrador b USING (id_local)
JOIN item_borrador i USING (id_local) JOIN producto_cache p ON p.id = i.producto_id
WHERE c.estado = 'PENDIENTE'
GROUP BY c.solicitud_uuid ORDER BY c.solicitud_uuid;

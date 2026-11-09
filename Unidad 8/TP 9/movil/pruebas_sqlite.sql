-- =============================================================================
-- TP 8 · Consigna 1.c · Pruebas de la base de la tablet
-- Requisito: haber corrido schema_sqlite.sql y cargar_snapshot.sql.
-- Uso:  sqlite3 foodstore_movil.db < pruebas_sqlite.sql
-- Sin .bail: los errores esperados (C7) se muestran y el script sigue.
-- UUIDs fijos para que las pruebas se puedan leer y repetir; en la app real
-- se generan en la tablet, por ejemplo con:
--   SELECT lower(hex(randomblob(4))||'-'||hex(randomblob(2))||'-4'||substr(hex(randomblob(2)),2)||'-'||
--          substr('89ab',1+(abs(random())%4),1)||substr(hex(randomblob(2)),2)||'-'||hex(randomblob(6)));
-- =============================================================================

PRAGMA foreign_keys = ON;      -- es por conexión: hay que activarlo en cada sesión
.headers on
.mode column

-- Limpieza para que el script se pueda correr más de una vez
DELETE FROM pedido_borrador
WHERE id_local IN ('11111111-1111-4111-8111-111111111111',
                   '22222222-2222-4222-8222-222222222222',
                   '77777777-7777-4777-8777-777777777777');

.print ''
.print '=== PRUEBA 1 · Borrador completo con BEGIN ... COMMIT ==='
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id, forma_pago)
VALUES ('11111111-1111-4111-8111-111111111111', 2, 'EFECTIVO');

-- el precio visto se toma del catálogo local en el momento de armar el pedido
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT '11111111-1111-4111-8111-111111111111', id, 2, precio_centavos FROM producto_cache WHERE id = 1;
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT '11111111-1111-4111-8111-111111111111', id, 3, precio_centavos FROM producto_cache WHERE id = 11;

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('a1111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111');
COMMIT;

SELECT b.id_local, b.forma_pago, i.producto_id, i.cantidad, i.precio_centavos_visto, c.estado
FROM pedido_borrador b
JOIN item_borrador i USING (id_local)
JOIN cola_sync c     USING (id_local)
WHERE b.id_local = '11111111-1111-4111-8111-111111111111';

.print ''
.print '=== PRUEBA 2 · Operación deshecha con ROLLBACK ==='
.print '(el vendedor arma un pedido y el cliente se arrepiente antes de guardarlo)'
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id, forma_pago)
VALUES ('22222222-2222-4222-8222-222222222222', 3, 'TARJETA');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT '22222222-2222-4222-8222-222222222222', id, 1, precio_centavos FROM producto_cache WHERE id = 9;
SELECT 'dentro de la transacción' AS momento,
       (SELECT count(*) FROM pedido_borrador WHERE id_local LIKE '2222%') AS borradores,
       (SELECT count(*) FROM item_borrador   WHERE id_local LIKE '2222%') AS items;
ROLLBACK;
SELECT 'después del ROLLBACK' AS momento,
       (SELECT count(*) FROM pedido_borrador WHERE id_local LIKE '2222%') AS borradores,
       (SELECT count(*) FROM item_borrador   WHERE id_local LIKE '2222%') AS items;

.print ''
.print '=== CASO C1 · Catálogo disponible sin conexión al servidor ==='
.print '(la única base abierta es el archivo local; no hay ningún vínculo con PostgreSQL)'
SELECT name AS base_abierta, file AS archivo FROM pragma_database_list WHERE name = 'main';
SELECT id, nombre, precio, stock_visto, fecha_copia FROM v_catalogo_local ORDER BY id;
SELECT 'ocultos (no disponibles o dados de baja)' AS detalle, count(*) AS cantidad
FROM producto_cache WHERE disponible = 0 OR eliminado = 1;

.print ''
.print '=== CASO C7 · Datos inválidos: dan error y no dejan filas nuevas ==='
CREATE TEMP TABLE conteo_antes AS
SELECT (SELECT count(*) FROM pedido_borrador) AS borradores,
       (SELECT count(*) FROM item_borrador)   AS items,
       (SELECT count(*) FROM cola_sync)       AS solicitudes;

.print '-- C7.a cantidad = 0 (espera: CHECK constraint failed)'
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('11111111-1111-4111-8111-111111111111', 5, 0, 95000);

.print '-- C7.b producto inexistente id 999 (espera: FOREIGN KEY constraint failed)'
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('11111111-1111-4111-8111-111111111111', 999, 1, 100000);

.print '-- C7.c borrador nuevo dentro de una transacción con un ítem inválido: la app hace ROLLBACK'
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id, forma_pago)
VALUES ('77777777-7777-4777-8777-777777777777', 4, 'TRANSFERENCIA');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('77777777-7777-4777-8777-777777777777', 999, 2, 50000);
ROLLBACK;

.print '-- C7.d forma de pago fuera de la lista (espera: CHECK constraint failed)'
INSERT INTO pedido_borrador (id_local, usuario_id, forma_pago)
VALUES ('77777777-7777-4777-8777-777777777777', 4, 'BITCOIN');

SELECT 'antes'   AS momento, * FROM conteo_antes
UNION ALL
SELECT 'después', (SELECT count(*) FROM pedido_borrador),
                  (SELECT count(*) FROM item_borrador),
                  (SELECT count(*) FROM cola_sync);
DROP TABLE conteo_antes;

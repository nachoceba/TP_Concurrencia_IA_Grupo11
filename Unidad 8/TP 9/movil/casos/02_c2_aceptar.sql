-- =============================================================================
-- TP 8 · Caso C2 · El cliente acepta el precio nuevo
-- La solicitud vieja queda en CONFLICTO (historial). Se actualiza el precio visto
-- del borrador con el de la última instantánea y se genera una solicitud NUEVA
-- (otro UUID) en PENDIENTE. La tablet no toca el precio del servidor: lo copia.
-- =============================================================================
PRAGMA foreign_keys = ON;

BEGIN;
UPDATE item_borrador
SET precio_centavos_visto = (SELECT p.precio_centavos FROM producto_cache p
                             WHERE p.id = item_borrador.producto_id)
WHERE id_local = 'c2c2c2c2-0000-4000-8000-000000000002';

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('5c200000-0000-4000-8000-00000000c2b2', 'c2c2c2c2-0000-4000-8000-000000000002');
COMMIT;

.headers on
.mode column
SELECT producto_id, cantidad, precio_centavos_visto FROM item_borrador
WHERE id_local = 'c2c2c2c2-0000-4000-8000-000000000002';

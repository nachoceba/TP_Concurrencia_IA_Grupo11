-- =============================================================================
-- TP 8 · Caso C6 · Reenvío de la misma solicitud (mismo UUID)
-- Ej.: se cortó la señal y la tablet no supo si el envío llegó, así que reintenta.
-- Espera: UNIQUE/PRIMARY KEY constraint failed y ninguna fila nueva.
-- =============================================================================
PRAGMA foreign_keys = ON;
.headers on
.mode column

SELECT 'antes' AS momento, count(*) AS solicitudes_c6, max(estado) AS estado, max(evaluada_en) AS evaluada_en
FROM cola_sync WHERE id_local = 'c6c6c6c6-0000-4000-8000-000000000006';

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('5c600000-0000-4000-8000-00000000c600', 'c6c6c6c6-0000-4000-8000-000000000006');

SELECT 'después' AS momento, count(*) AS solicitudes_c6, max(estado) AS estado, max(evaluada_en) AS evaluada_en
FROM cola_sync WHERE id_local = 'c6c6c6c6-0000-4000-8000-000000000006';

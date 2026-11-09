-- =============================================================================
-- TP 8 · Consigna 2.b · El semáforo (simulación de sincronización)
-- Uso:  sqlite3 foodstore_movil.db < semaforo.sql
--
-- Compara cada solicitud PENDIENTE de cola_sync con snapshot_servidor (la última
-- instantánea importada de PostgreSQL) y guarda estado + motivo:
--   ROJO     RECHAZADO          algún producto no existe, no está disponible,
--                               fue dado de baja o no alcanza el stock
--   AMARILLO CONFLICTO          no hay rojo, pero cambió algún precio
--   VERDE    SIMULADO_APROBADO  todo coincide (¡NO es una venta!)
--
-- * Solo toca filas en PENDIENTE: correrlo dos veces no cambia nada (idempotente).
-- * No se conecta a PostgreSQL ni modifica nada del servidor: el precio, el stock
--   y la venta real los decide el servidor cuando la tablet tenga señal.
-- * Si snapshot_servidor está vacía no evalúa nada (sin instantánea no hay con qué
--   comparar, y todo saldría RECHAZADO por "producto inexistente").
-- =============================================================================

PRAGMA foreign_keys = ON;
.headers on
.mode column --wrap 0

WITH
eval_item AS (
    SELECT c.solicitud_uuid,
           -- problemas ROJOS (alcanza con uno para rechazar)
           CASE
             WHEN i.producto_id IS NULL      THEN 'borrador sin ítems'
             WHEN s.id_producto IS NULL      THEN 'producto ' || i.producto_id || ' no existe en el servidor'
             WHEN s.eliminado = 1            THEN 'producto ' || i.producto_id || ' (' || s.nombre || ') fue dado de baja'
             WHEN s.disponible = 0           THEN 'producto ' || i.producto_id || ' (' || s.nombre || ') no está disponible'
             WHEN i.cantidad > s.stock       THEN 'producto ' || i.producto_id || ' (' || s.nombre || ') sin stock suficiente: pide '
                                                  || i.cantidad || ', quedan ' || s.stock
           END AS problema_rojo,
           -- problemas AMARILLOS (cambio de precio)
           CASE
             WHEN s.precio_centavos <> i.precio_centavos_visto
               THEN 'producto ' || i.producto_id || ' (' || s.nombre || ') cambió de precio: visto '
                    || printf('%d.%02d', i.precio_centavos_visto / 100, i.precio_centavos_visto % 100)
                    || ', actual ' || printf('%d.%02d', s.precio_centavos / 100, s.precio_centavos % 100)
           END AS problema_amarillo
    FROM cola_sync c
    LEFT JOIN item_borrador     i ON i.id_local    = c.id_local
    LEFT JOIN snapshot_servidor s ON s.id_producto = i.producto_id
    WHERE c.estado = 'PENDIENTE'
      AND EXISTS (SELECT 1 FROM snapshot_servidor)
),
eval AS (
    SELECT solicitud_uuid,
           CASE
             WHEN count(problema_rojo)     > 0 THEN 'RECHAZADO'
             WHEN count(problema_amarillo) > 0 THEN 'CONFLICTO'
             ELSE 'SIMULADO_APROBADO'
           END AS estado,
           CASE
             WHEN count(problema_rojo)     > 0 THEN group_concat(problema_rojo, '; ')
             WHEN count(problema_amarillo) > 0 THEN group_concat(problema_amarillo, '; ')
             ELSE 'coincide con la instantánea del ' || (SELECT max(fecha_snapshot) FROM snapshot_servidor)
                  || ' (pendiente de confirmación real del servidor)'
           END AS motivo
    FROM eval_item
    GROUP BY solicitud_uuid
)
UPDATE cola_sync
SET estado      = eval.estado,
    motivo      = eval.motivo,
    evaluada_en = strftime('%Y-%m-%dT%H:%M:%S', 'now', 'localtime')
FROM eval
WHERE cola_sync.solicitud_uuid = eval.solicitud_uuid
  AND cola_sync.estado = 'PENDIENTE';

SELECT changes() AS solicitudes_evaluadas_en_esta_corrida;

SELECT substr(solicitud_uuid, 25) AS solicitud,
       substr(id_local, 1, 8)       AS borrador,
       CASE estado WHEN 'RECHAZADO' THEN 'ROJO' WHEN 'CONFLICTO' THEN 'AMARILLO'
                   WHEN 'SIMULADO_APROBADO' THEN 'VERDE' ELSE '-' END AS luz,
       estado, motivo
FROM cola_sync
ORDER BY creada_en, solicitud_uuid;

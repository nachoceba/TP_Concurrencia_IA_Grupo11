-- =============================================================================
-- TP 8 · Consigna 2.a · Cargar la instantánea del servidor en la tablet
-- Uso (en la carpeta movil/, con servidor_snapshot.csv ya exportado):
--   sqlite3 foodstore_movil.db < cargar_snapshot.sql
--
-- 1) Vacía snapshot_servidor e importa el CSV (saltea el encabezado).
-- 2) Actualiza producto_cache con un UPSERT: los productos nuevos se insertan,
--    los existentes se pisan con lo que dice el servidor (precio, stock,
--    disponible, eliminado) y la fecha de la copia.
--    No se borra ninguna fila: una baja lógica queda como lápida (eliminado = 1),
--    así los borradores viejos que la referencian no rompen la FK.
-- Nada de esto toca PostgreSQL: la tablet solo LEE la instantánea.
-- =============================================================================

PRAGMA foreign_keys = ON;

DELETE FROM snapshot_servidor;

.import --csv --skip 1 servidor_snapshot.csv snapshot_servidor

BEGIN;

INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto,
                            disponible, eliminado, fecha_copia)
SELECT id_producto, nombre, precio_centavos, stock, disponible, eliminado, fecha_snapshot
FROM snapshot_servidor
WHERE true                      -- requerido por SQLite para usar ON CONFLICT tras un SELECT
ON CONFLICT (id) DO UPDATE SET
    nombre          = excluded.nombre,
    precio_centavos = excluded.precio_centavos,
    stock_visto     = excluded.stock_visto,
    disponible      = excluded.disponible,
    eliminado       = excluded.eliminado,
    fecha_copia     = excluded.fecha_copia;

COMMIT;

-- Fecha de la copia (queda anotada en cada fila de producto_cache)
SELECT 'Instantánea cargada' AS evento,
       (SELECT count(*) FROM snapshot_servidor)        AS filas_snapshot,
       (SELECT max(fecha_copia) FROM producto_cache)   AS fecha_copia,
       (SELECT count(*) FROM v_catalogo_local)         AS productos_vendibles,
       (SELECT count(*) FROM producto_cache WHERE eliminado = 1) AS lapidas;

-- =============================================================================
-- TP 8 · Consigna 2.a · Vista de la instantánea para la tablet
-- Correr SOLO sobre la COPIA de pruebas (ej. food_store_tp8), nunca en la base real.
--   createdb -T food_store food_store_tp8      (o cargar 01_schema + 04_objects + 02_data_demo)
--   psql -d food_store_tp8 -f servidor/v_snapshot_movil.sql
--
-- Qué viaja: solo columnas de producto que la tablet necesita para vender.
-- Qué NO viaja: usuario (mail, contraseña, celular), pedidos, descripcion, imagen,
--               categoria (no hace falta para cobrar).
-- Lápidas: las bajas lógicas (eliminado = true) SÍ viajan, para que la tablet
--          sepa que tiene que ocultar ese producto aunque ya lo tuviera en caché.
-- Booleanos como 0/1 y precio en centavos enteros: así el CSV entra directo en
--          las tablas STRICT de SQLite (en CSV de psql un boolean sale como t/f).
-- =============================================================================

CREATE OR REPLACE VIEW v_snapshot_movil AS
SELECT p.id_producto,
       p.nombre,
       round(p.precio * 100)::integer                         AS precio_centavos,
       p.stock,
       p.disponible::integer                                  AS disponible,
       p.eliminado::integer                                   AS eliminado,
       to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS')              AS fecha_snapshot
FROM producto p
ORDER BY p.id_producto;

COMMENT ON VIEW v_snapshot_movil IS
  'TP8 U8: instantánea de catálogo para la tablet offline (incluye lápidas de bajas lógicas)';

-- Exportar (desde psql, en la carpeta movil/):
-- \copy (SELECT * FROM v_snapshot_movil) TO 'servidor_snapshot.csv' CSV HEADER

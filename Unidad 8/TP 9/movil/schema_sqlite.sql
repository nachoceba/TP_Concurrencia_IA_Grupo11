-- =============================================================================
-- TP 8 · Unidad 8 · Food Store en la feria · Consigna 1.b
-- schema_sqlite.sql — base local de la tablet (SQLite 3.37+, tablas STRICT)
-- Grupo 11 · Bases de Datos II
--
-- Regla de oro: el móvil propone, el servidor dispone.
--   * producto_cache y snapshot_servidor son COPIAS de PostgreSQL: solo lectura
--     para la tablet (se pisan con cada instantánea nueva).
--   * pedido_borrador / item_borrador / cola_sync son PROPUESTAS: nunca son una
--     venta. SIMULADO_APROBADO solo significa "el servidor probablemente lo acepte".
--
-- Uso:  sqlite3 foodstore_movil.db < schema_sqlite.sql
-- Es re-ejecutable: borra y recrea todo (base de la tablet desde cero).
-- =============================================================================

PRAGMA foreign_keys = ON;

DROP VIEW  IF EXISTS v_catalogo_local;
DROP TABLE IF EXISTS cola_sync;
DROP TABLE IF EXISTS item_borrador;
DROP TABLE IF EXISTS pedido_borrador;
DROP TABLE IF EXISTS producto_cache;
DROP TABLE IF EXISTS snapshot_servidor;

-- -----------------------------------------------------------------------------
-- 1. producto_cache: catálogo que viaja a la tablet (copia del servidor)
--    Solo columnas de producto; nada de usuarios, mails ni contraseñas.
--    Las bajas lógicas viajan como "lápida" (eliminado = 1): la fila queda,
--    pero el catálogo no la muestra.
-- -----------------------------------------------------------------------------
CREATE TABLE producto_cache (
    id               INTEGER PRIMARY KEY,               -- = producto.id_producto en PostgreSQL
    nombre           TEXT    NOT NULL CHECK (length(trim(nombre)) > 0),
    precio_centavos  INTEGER NOT NULL CHECK (precio_centavos >= 0),  -- entero: 4500.00 -> 450000
    stock_visto      INTEGER NOT NULL CHECK (stock_visto >= 0),      -- stock al momento de la copia (referencia, no reserva)
    disponible       INTEGER NOT NULL CHECK (disponible IN (0, 1)),
    eliminado        INTEGER NOT NULL DEFAULT 0 CHECK (eliminado IN (0, 1)),
    fecha_copia      TEXT    NOT NULL                   -- ISO-8601 de la instantánea de la que salió la fila
) STRICT;

-- -----------------------------------------------------------------------------
-- 2. pedido_borrador: lo que arma el vendedor en la feria, sin señal
--    id_local es un UUID generado en la tablet (no choca con el IDENTITY del server).
-- -----------------------------------------------------------------------------
CREATE TABLE pedido_borrador (
    id_local    TEXT    PRIMARY KEY
                CHECK (length(id_local) = 36 AND id_local GLOB '????????-????-????-????-????????????'),
    usuario_id  INTEGER NOT NULL CHECK (usuario_id > 0),  -- id del cliente en el server (sin datos personales)
    forma_pago  TEXT    NOT NULL CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    fecha       TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', 'localtime'))
) STRICT;

-- -----------------------------------------------------------------------------
-- 3. item_borrador: líneas del borrador, con el precio que vio el vendedor
-- -----------------------------------------------------------------------------
CREATE TABLE item_borrador (
    id_local               TEXT    NOT NULL
                           REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    producto_id            INTEGER NOT NULL
                           REFERENCES producto_cache(id),
    cantidad               INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto  INTEGER NOT NULL CHECK (precio_centavos_visto >= 0),
    PRIMARY KEY (id_local, producto_id)
) STRICT;

CREATE INDEX idx_item_borrador_producto ON item_borrador(producto_id);

-- -----------------------------------------------------------------------------
-- 4. cola_sync: solicitudes de envío al servidor (una por intento)
--    solicitud_uuid es la clave de idempotencia: reenviar el mismo UUID falla.
--    Un mismo borrador puede tener varias solicitudes (ej. C2: CONFLICTO y
--    después una nueva tras aceptar el precio).
-- -----------------------------------------------------------------------------
CREATE TABLE cola_sync (
    solicitud_uuid  TEXT PRIMARY KEY
                    CHECK (length(solicitud_uuid) = 36 AND solicitud_uuid GLOB '????????-????-????-????-????????????'),
    id_local        TEXT NOT NULL REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    estado          TEXT NOT NULL DEFAULT 'PENDIENTE'
                    CHECK (estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO', 'SIMULADO_APROBADO')),
    motivo          TEXT,
    creada_en       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', 'localtime')),
    evaluada_en     TEXT,
    -- coherencia: una solicitud evaluada siempre tiene fecha de evaluación
    CHECK ((estado = 'PENDIENTE') = (evaluada_en IS NULL))
) STRICT;

CREATE INDEX idx_cola_sync_id_local ON cola_sync(id_local);
CREATE INDEX idx_cola_sync_estado   ON cola_sync(estado);

-- -----------------------------------------------------------------------------
-- 5. snapshot_servidor: destino del CSV exportado de v_snapshot_movil (2.a)
--    Se crea vacía acá para que el .import respete los tipos y los CHECK.
--    Los booleanos vienen como 0/1 porque la vista los castea a int
--    (el CSV de psql los exportaría como t/f).
-- -----------------------------------------------------------------------------
CREATE TABLE snapshot_servidor (
    id_producto      INTEGER PRIMARY KEY,
    nombre           TEXT    NOT NULL,
    precio_centavos  INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock            INTEGER NOT NULL CHECK (stock >= 0),
    disponible       INTEGER NOT NULL CHECK (disponible IN (0, 1)),
    eliminado        INTEGER NOT NULL CHECK (eliminado IN (0, 1)),
    fecha_snapshot   TEXT    NOT NULL
) STRICT;

-- -----------------------------------------------------------------------------
-- 6. Catálogo que ve el vendedor (consulta 100% local, caso C1)
-- -----------------------------------------------------------------------------
CREATE VIEW v_catalogo_local AS
SELECT id, nombre,
       printf('%d.%02d', precio_centavos / 100, precio_centavos % 100) AS precio,
       precio_centavos, stock_visto, fecha_copia
FROM producto_cache
WHERE disponible = 1 AND eliminado = 0;

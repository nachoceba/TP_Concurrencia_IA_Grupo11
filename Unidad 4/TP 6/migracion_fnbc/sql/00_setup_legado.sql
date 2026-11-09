-- =============================================================================
-- TP Unidad 4 · Migración FNBC · 00 · Esquema heredado (SOLO base de prueba)
-- Crea la tabla heredada control_lote_almacen con la instancia del enunciado,
-- más las maestras mínimas. Los responsables 801 y 802 son usuarios sintéticos.
-- Uso: psql -d tp_u4_fnbc -f sql/00_setup_legado.sql   (sobre una copia)
-- =============================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS lote     (id_lote     BIGINT PRIMARY KEY);
CREATE TABLE IF NOT EXISTS deposito (id_deposito BIGINT PRIMARY KEY);
INSERT INTO lote     VALUES (501), (502), (503) ON CONFLICT DO NOTHING;
INSERT INTO deposito VALUES (30), (31)          ON CONFLICT DO NOTHING;

-- Responsables sintéticos (sin datos personales reales)
INSERT INTO usuario (id_usuario, nombre, apellido, mail, contrasena)
OVERRIDING SYSTEM VALUE
VALUES (801, 'Resp', 'Ochocientos uno', 'resp801@ejemplo.edu', 'hash_demo'),
       (802, 'Resp', 'Ochocientos dos', 'resp802@ejemplo.edu', 'hash_demo')
ON CONFLICT DO NOTHING;

-- Tabla heredada: PK (lote, deposito) y la DF oculta responsable -> deposito
DROP TABLE IF EXISTS control_lote_almacen;
CREATE TABLE control_lote_almacen (
    lote_id                 BIGINT NOT NULL REFERENCES lote(id_lote),
    deposito_id             BIGINT NOT NULL REFERENCES deposito(id_deposito),
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario(id_usuario),
    PRIMARY KEY (lote_id, deposito_id)
);
INSERT INTO control_lote_almacen VALUES
    (501, 30, 801),
    (502, 30, 801),
    (503, 31, 802);

COMMIT;

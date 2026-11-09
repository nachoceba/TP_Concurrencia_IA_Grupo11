-- =============================================================================
-- TP Unidad 4 · Migración FNBC · 01 · IDA (control_lote_almacen -> FNBC)
-- Spec: .kiro/specs/migracion-fnbc-control-lote/  (REQ-01 a REQ-05)
--
-- Todo en UNA transacción: si cualquier verificación falla se lanza una
-- excepción y PostgreSQL deshace todo (la base queda exactamente como estaba).
-- La tabla heredada NO se borra: se renombra a control_lote_almacen_legado y
-- queda como respaldo para la reversión (02_reversion_fnbc.sql).
-- Uso: psql -v ON_ERROR_STOP=1 -d tp_u4_fnbc -f sql/01_migracion_fnbc.sql
-- =============================================================================
\set ON_ERROR_STOP on
BEGIN;

-- ---------------------------------------------------------------------------
-- Paso 0 · Precondiciones (REQ-01): validar las DF contra los DATOS REALES
-- antes de tocar nada. Si la DF responsable -> deposito no se cumple, la
-- descomposición perdería información: se aborta.
-- ---------------------------------------------------------------------------
DO $$
DECLARE v_viol INT; v_ya INT;
BEGIN
  IF to_regclass('public.control_lote_almacen') IS NULL THEN
    RAISE EXCEPTION 'PRECONDICION: no existe control_lote_almacen (¿ya migrada?)';
  END IF;
  SELECT count(*) INTO v_ya FROM pg_tables
  WHERE schemaname = 'public' AND tablename IN ('responsable_deposito', 'control_lote');
  IF v_ya > 0 THEN
    RAISE EXCEPTION 'PRECONDICION: las tablas destino ya existen';
  END IF;

  SELECT count(*) INTO v_viol FROM (
    SELECT responsable_control_id FROM control_lote_almacen
    GROUP BY responsable_control_id HAVING count(DISTINCT deposito_id) > 1) x;
  IF v_viol > 0 THEN
    RAISE EXCEPTION 'DF responsable_control_id -> deposito_id VIOLADA por % responsable(s): no se migra', v_viol;
  END IF;
  RAISE NOTICE 'OK precondiciones: DF responsable -> deposito se cumple en los datos';
END $$;

-- Foto del origen para comparar al final (vive solo en esta transacción)
CREATE TEMP TABLE origen_foto ON COMMIT DROP AS
SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen;

-- ---------------------------------------------------------------------------
-- Paso 1 · Esquema FNBC (REQ-02)
-- ---------------------------------------------------------------------------
CREATE TABLE responsable_deposito (
    responsable_control_id BIGINT PRIMARY KEY REFERENCES usuario(id_usuario),
    deposito_id            BIGINT NOT NULL    REFERENCES deposito(id_deposito)
);
CREATE TABLE control_lote (
    lote_id                BIGINT NOT NULL REFERENCES lote(id_lote),
    responsable_control_id BIGINT NOT NULL REFERENCES responsable_deposito(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);

-- ---------------------------------------------------------------------------
-- Paso 2 · Migración de datos desde la tabla heredada (no valores a mano)
-- ---------------------------------------------------------------------------
INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id FROM control_lote_almacen;

INSERT INTO control_lote (lote_id, responsable_control_id)
SELECT lote_id, responsable_control_id FROM control_lote_almacen;

-- ---------------------------------------------------------------------------
-- Paso 3 · Conservar la heredada como respaldo + vista de compatibilidad (REQ-04)
-- ---------------------------------------------------------------------------
ALTER TABLE control_lote_almacen RENAME TO control_lote_almacen_legado;
COMMENT ON TABLE control_lote_almacen_legado IS
  'Respaldo pre-FNBC: lo usa 02_reversion_fnbc.sql. Borrar solo tras el periodo de validacion.';

CREATE VIEW control_lote_almacen AS          -- mismo nombre: las consultas viejas siguen andando
SELECT cl.lote_id, rd.deposito_id, cl.responsable_control_id
FROM control_lote cl
JOIN responsable_deposito rd USING (responsable_control_id);

-- ---------------------------------------------------------------------------
-- Paso 4 · Verificación sin pérdida (REQ-03): EXCEPT en los dos sentidos
-- ---------------------------------------------------------------------------
DO $$
DECLARE v_falta INT; v_sobra INT; v_o INT; v_n INT;
BEGIN
  SELECT count(*) INTO v_falta FROM (SELECT * FROM origen_foto EXCEPT SELECT * FROM control_lote_almacen) a;
  SELECT count(*) INTO v_sobra FROM (SELECT * FROM control_lote_almacen EXCEPT SELECT * FROM origen_foto) b;
  SELECT count(*) INTO v_o FROM origen_foto;
  SELECT count(*) INTO v_n FROM control_lote_almacen;
  IF v_falta > 0 OR v_sobra > 0 OR v_o <> v_n THEN
    RAISE EXCEPTION 'PERDIDA DE INFORMACION: faltan %, sobran %, origen % vs nuevo % -> ROLLBACK',
                    v_falta, v_sobra, v_o, v_n;
  END IF;
  RAISE NOTICE 'OK sin perdida: % filas, 0 faltantes, 0 sobrantes', v_n;
END $$;

COMMIT;

SELECT * FROM control_lote_almacen ORDER BY lote_id;

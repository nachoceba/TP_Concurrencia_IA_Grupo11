-- =============================================================================
-- TP Unidad 4 · Migración FNBC · 02 · PLAN DE REVERSIÓN (vuelta al esquema heredado)
-- Spec: REQ-05. Se usa si después de migrar aparece un problema (consultas que
-- dependían de la tabla, rendimiento, datos nuevos que la vista no cubre, etc.).
--
-- Estrategia: la tabla heredada se conservó como control_lote_almacen_legado.
-- Antes de volver se le agregan las filas que se hayan cargado DESPUÉS de la
-- migración en el esquema nuevo (vía la vista), así la vuelta tampoco pierde datos.
-- Todo en una transacción: si la verificación falla, no cambia nada.
-- Uso: psql -v ON_ERROR_STOP=1 -d tp_u4_fnbc -f sql/02_reversion_fnbc.sql
-- =============================================================================
\set ON_ERROR_STOP on
BEGIN;

DO $$
BEGIN
  IF to_regclass('public.control_lote_almacen_legado') IS NULL THEN
    RAISE EXCEPTION 'PRECONDICION: no existe control_lote_almacen_legado; no hay a qué volver';
  END IF;
  IF (SELECT relkind FROM pg_class WHERE oid = 'public.control_lote_almacen'::regclass) <> 'v' THEN
    RAISE EXCEPTION 'PRECONDICION: control_lote_almacen no es la vista de compatibilidad';
  END IF;
END $$;

-- Foto del estado actual (esquema nuevo, incluye lo cargado después de migrar)
CREATE TEMP TABLE actual_foto ON COMMIT DROP AS
SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen;

-- 0 · Datos que el esquema heredado NO puede representar: responsables sin
--     ningún lote (justo la anomalía de inserción que resolvió la FNBC).
--     Volver los perdería, así que se aborta salvo que se fuerce a conciencia:
--     SET fnbc.forzar_reversion = 'on';  (antes de correr este script)
DO $$
DECLARE v_sin_lote INT;
BEGIN
  SELECT count(*) INTO v_sin_lote FROM responsable_deposito rd
  WHERE NOT EXISTS (SELECT 1 FROM control_lote cl WHERE cl.responsable_control_id = rd.responsable_control_id);
  IF v_sin_lote > 0 AND coalesce(current_setting('fnbc.forzar_reversion', true), 'off') <> 'on' THEN
    RAISE EXCEPTION 'REVERSION BLOQUEADA: % responsable(s) sin lote no entran en el esquema heredado y se perderian. Asignales un lote o SET fnbc.forzar_reversion = on', v_sin_lote;
  END IF;
  IF v_sin_lote > 0 THEN
    RAISE WARNING 'Reversion forzada: se pierden % responsable(s) sin lote', v_sin_lote;
  END IF;
END $$;

-- 1 · Sincronizar el legado con la verdad vigente (el esquema nuevo):
--     a) borrar lo que ya no existe, b) actualizar responsables cambiados,
--     c) insertar lo cargado después de migrar.  (En este orden, por la PK)
DELETE FROM control_lote_almacen_legado l
WHERE NOT EXISTS (SELECT 1 FROM actual_foto a
                  WHERE a.lote_id = l.lote_id AND a.deposito_id = l.deposito_id);

UPDATE control_lote_almacen_legado l
SET responsable_control_id = a.responsable_control_id
FROM actual_foto a
WHERE a.lote_id = l.lote_id AND a.deposito_id = l.deposito_id
  AND a.responsable_control_id <> l.responsable_control_id;

INSERT INTO control_lote_almacen_legado (lote_id, deposito_id, responsable_control_id)
SELECT a.lote_id, a.deposito_id, a.responsable_control_id FROM actual_foto a
WHERE NOT EXISTS (SELECT 1 FROM control_lote_almacen_legado l
                  WHERE l.lote_id = a.lote_id AND l.deposito_id = a.deposito_id);

-- 3 · Desarmar el esquema FNBC y devolver el nombre original
DROP VIEW  control_lote_almacen;
DROP TABLE control_lote;
DROP TABLE responsable_deposito;
ALTER TABLE control_lote_almacen_legado RENAME TO control_lote_almacen;
COMMENT ON TABLE control_lote_almacen IS NULL;

-- 4 · Verificación: lo que hay ahora = lo que mostraba el esquema nuevo
DO $$
DECLARE v_falta INT; v_sobra INT;
BEGIN
  SELECT count(*) INTO v_falta FROM (SELECT * FROM actual_foto EXCEPT SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen) a;
  SELECT count(*) INTO v_sobra FROM (SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen EXCEPT SELECT * FROM actual_foto) b;
  IF v_falta > 0 OR v_sobra > 0 THEN
    RAISE EXCEPTION 'REVERSION CON DIFERENCIAS: faltan %, sobran % -> ROLLBACK', v_falta, v_sobra;
  END IF;
  RAISE NOTICE 'OK reversion: esquema heredado restaurado sin perdida';
END $$;

COMMIT;

SELECT * FROM control_lote_almacen ORDER BY lote_id;

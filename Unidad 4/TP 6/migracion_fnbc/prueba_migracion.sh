#!/usr/bin/env bash
# =============================================================================
# TP Unidad 4 · Prueba de la migración FNBC y de su plan de reversión
# Corre todo sobre bases DESCARTABLES (tp_u4_fnbc*) y guarda la salida en
# evidencias/prueba_migracion.txt. Nunca toca la base real.
# Uso:  ./prueba_migracion.sh      (psql en el PATH; PGUSER/PGPASSWORD si hace falta)
# =============================================================================
set -u
cd "$(dirname "$0")"
REPO=../../..
OUT=evidencias/prueba_migracion.txt
mkdir -p evidencias
q()  { psql -X -q -d "$1" "${@:2}"; }

nueva_base() {        # base descartable con el esquema del proyecto + tabla heredada
  dropdb --if-exists "$1"; createdb "$1"
  q "$1" -f "$REPO/parcial_BD/01_schema.sql"
  q "$1" -f sql/00_setup_legado.sql
}
estado() {            # qué es cada objeto y qué contiene
  psql -X -d "$1" -c "SELECT relname AS objeto, CASE relkind WHEN 'r' THEN 'tabla' WHEN 'v' THEN 'vista' END AS tipo
    FROM pg_class WHERE relname IN ('control_lote_almacen','control_lote_almacen_legado','control_lote','responsable_deposito')
    AND relnamespace = 'public'::regnamespace ORDER BY 1" \
    -c "SELECT * FROM control_lote_almacen ORDER BY lote_id"
}

{
echo "Prueba de migración FNBC + reversión · $(date '+%Y-%m-%d %H:%M:%S') · $(psql -X -At -d postgres -c 'SHOW server_version')"

echo; echo "=== E1 · IDA: control_lote_almacen -> responsable_deposito + control_lote (REQ-01..04)"
nueva_base tp_u4_fnbc
echo "-- antes"; estado tp_u4_fnbc
psql -X -d tp_u4_fnbc -f sql/01_migracion_fnbc.sql 2>&1
echo "-- después"; estado tp_u4_fnbc
psql -X -d tp_u4_fnbc -c "SELECT * FROM responsable_deposito ORDER BY 1" -c "SELECT * FROM control_lote ORDER BY 1,2"

echo; echo "=== E2 · Las anomalías desaparecen: alta de responsable sin lote (803 -> depósito 32)"
psql -X -d tp_u4_fnbc -c "INSERT INTO deposito VALUES (32)" \
  -c "INSERT INTO usuario (id_usuario, nombre, apellido, mail, contrasena) OVERRIDING SYSTEM VALUE VALUES (803,'Resp','Ochocientos tres','resp803@ejemplo.edu','hash_demo')" \
  -c "INSERT INTO responsable_deposito VALUES (803, 32)" 2>&1

echo; echo "=== E3 · REVERSIÓN BLOQUEADA: el 803 no tiene lote y el esquema heredado no lo puede guardar (REQ-05)"
psql -X -d tp_u4_fnbc -f sql/02_reversion_fnbc.sql 2>&1
echo "-- el esquema FNBC sigue intacto:"; estado tp_u4_fnbc

echo; echo "=== E4 · REVERSIÓN con cambios posteriores: se le asigna lote al 803 y se agrega 504/31/802"
psql -X -d tp_u4_fnbc -c "INSERT INTO lote VALUES (504),(505)" \
  -c "INSERT INTO control_lote VALUES (504, 802), (505, 803)" 2>&1
echo "-- vista antes de revertir:"; psql -X -d tp_u4_fnbc -c "SELECT * FROM control_lote_almacen ORDER BY lote_id"
psql -X -d tp_u4_fnbc -f sql/02_reversion_fnbc.sql 2>&1
echo "-- después de revertir:"; estado tp_u4_fnbc

echo; echo "=== E5 · IDA RECHAZADA: los datos violan la DF (802 en los depósitos 30 y 31) -> no cambia nada"
nueva_base tp_u4_fnbc_viola
psql -X -q -d tp_u4_fnbc_viola -c "INSERT INTO control_lote_almacen VALUES (503, 30, 802)" 2>&1
psql -X -d tp_u4_fnbc_viola -f sql/01_migracion_fnbc.sql 2>&1
echo "-- sigue la tabla heredada, sin tablas nuevas:"; estado tp_u4_fnbc_viola

echo; echo "=== E6 · REVERSIÓN FORZADA (decisión consciente de perder responsables sin lote)"
nueva_base tp_u4_fnbc_forzada
psql -X -q -d tp_u4_fnbc_forzada -f sql/01_migracion_fnbc.sql >/dev/null 2>&1
psql -X -q -d tp_u4_fnbc_forzada -c "INSERT INTO deposito VALUES (32)" \
  -c "INSERT INTO usuario (id_usuario, nombre, apellido, mail, contrasena) OVERRIDING SYSTEM VALUE VALUES (803,'Resp','Ochocientos tres','resp803@ejemplo.edu','hash_demo')" \
  -c "INSERT INTO responsable_deposito VALUES (803, 32)"
PGOPTIONS="-c fnbc.forzar_reversion=on" psql -X -d tp_u4_fnbc_forzada -f sql/02_reversion_fnbc.sql 2>&1
estado tp_u4_fnbc_forzada

dropdb tp_u4_fnbc; dropdb tp_u4_fnbc_viola; dropdb tp_u4_fnbc_forzada
echo; echo "Bases descartables eliminadas."
} 2>&1 | tee "$OUT"

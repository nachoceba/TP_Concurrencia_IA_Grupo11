#!/usr/bin/env bash
# =============================================================================
# TP6 (Unidad 5) · Auditoría ACTIVADA EN VIVO + simulacro de acceso indebido
# Cierra la limitación de informe_auditoria.md / log_auditoria_prueba.txt: acá
# los parámetros se aplican con ALTER SYSTEM y el log es la salida REAL del motor.
#
# Requisitos: superusuario de una instancia de LABORATORIO (nunca producción),
# psql en el PATH, conexión TCP a 127.0.0.1 con scram-sha-256 (pg_hba.conf).
# Uso:  PGLOG=/ruta/al/log/de/postgres ./simulacro_live.sh
#   (en Windows el log está en  <data>/log/  con logging_collector = on)
#
# Qué hace:
#   1. Base efímera tp6_u5_work: 01_schema → 04_objects → 02_data_demo → roles.sql
#   2. Auditoría:  log_connections / log_disconnections / log_statement = 'mod'
#                  / log_line_prefix  (ALTER SYSTEM + pg_reload_conf)
#   3. auditoria_test.sql (con 'mod': queda el INSERT/UPDATE, no el SELECT)
#   4. Ventana de incidente: log_statement = 'all' (política de la Parte B)
#      - 4 logins FALLIDOS reales de anon_test007 (clave incorrecta)
#      - 1 login EXITOSO; lectura masiva de usuario; GRANT y SET ROLE admin_datos
#        (los dos deben fallar: la sesión NO es superusuario)
#   5. El owner verifica pg_auth_members y se vuelve a 'mod'
#   6. Recorta el log (entre marcadores) a ../docs/log_auditoria_live.txt
#   7. Limpieza: ALTER SYSTEM RESET, se borran el login sintético y la base efímera
# Las claves sintéticas se generan al vuelo y NO se guardan en ningún archivo.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"
DB=tp6_u5_work
REPO=../../..
PGLOG="${PGLOG:-/var/log/postgresql/postgresql-16-main.log}"
OUT=../docs/log_auditoria_live.txt
CLAVE_OK="sim-$(openssl rand -hex 6)"          # sintética, solo en memoria
su_psql() { psql -X -q -v ON_ERROR_STOP=1 "$@"; }
marca()  { su_psql -d postgres -c "DO \$\$BEGIN RAISE LOG 'SIMULACRO_TP6 %', '$1'; END\$\$;"; }

echo "== 1. Base efímera $DB"
dropdb --if-exists "$DB"; createdb "$DB"
su_psql -d "$DB" -f "$REPO/parcial_BD/01_schema.sql"
su_psql -d "$DB" -f "$REPO/parcial_BD/04_objects.sql" 2>/dev/null
su_psql -d "$DB" -f "$REPO/parcial_BD/02_data_demo.sql"
su_psql -d "$DB" -f roles.sql

echo "== 2. Activar auditoría (ALTER SYSTEM)"
su_psql -d postgres <<'SQL'
ALTER SYSTEM SET log_connections    = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
ALTER SYSTEM SET log_statement      = 'mod';
ALTER SYSTEM SET log_line_prefix    = '%m [%p] %u@%d %h %a ';
SELECT pg_reload_conf();
SQL
sleep 1
psql -X -At -d postgres -c "SELECT name || ' = ' || setting FROM pg_settings WHERE name IN ('log_connections','log_disconnections','log_statement','log_line_prefix') ORDER BY name"
marca INICIO

echo "== 3. auditoria_test.sql con log_statement = 'mod'"
PGAPPNAME=auditoria_test psql -X -d "$DB" -f auditoria_test.sql 2>&1 | grep -E "ERROR|ROLLBACK|filas|rows" || true

echo "== 4. Ventana de incidente: log_statement = 'all'"
su_psql -d postgres -c "ALTER SYSTEM SET log_statement = 'all'" -c "SELECT pg_reload_conf()" >/dev/null
sleep 1
marca VENTANA_INCIDENTE_ALL
# HALLAZGO: con log_statement 'mod' o 'all', un CREATE/ALTER ROLE ... PASSWORD queda en el
# log con la clave en texto plano. Se apaga el log SOLO para esta sentencia (SET de sesión,
# requiere superusuario). En producción: \password en psql, que envía la clave ya cifrada.
su_psql -d "$DB" -c "SET log_statement = 'none'" -c "CREATE ROLE anon_test007 LOGIN PASSWORD '$CLAVE_OK' CONNECTION LIMIT 2 IN ROLE rol_soporte" 2>/dev/null
for i in 1 2 3 4; do
  PGSSLMODE=disable PGPASSWORD="clave-mala-0$i" PGAPPNAME=psql_atacante psql -X -h 127.0.0.1 -U anon_test007 -d "$DB" -c "SELECT 1" 2>&1 | sed 's/^/   intento '"$i"': /' || true
done
echo "   intento 5 (clave correcta), lectura masiva y escalamiento:"
PGSSLMODE=disable PGPASSWORD="$CLAVE_OK" PGAPPNAME=psql_atacante psql -X -h 127.0.0.1 -U anon_test007 -d "$DB" <<'SQL' 2>&1 | sed 's/^/   /'
SELECT current_user, session_user;
SELECT count(*) AS filas_leidas FROM (SELECT id_usuario, mail, rol FROM usuario) t;
GRANT admin_datos TO rol_soporte;
SET ROLE admin_datos;
SQL

echo "== 5. Verificación del owner y vuelta a 'mod'"
PGAPPNAME=owner_verificacion psql -X -At -d "$DB" -c "SELECT 'membresias rol_soporte->admin_datos: ' || count(*) FROM pg_auth_members m JOIN pg_roles r ON r.oid = m.roleid JOIN pg_roles s ON s.oid = m.member WHERE r.rolname = 'admin_datos' AND s.rolname IN ('rol_soporte','anon_test007')"
su_psql -d postgres -c "ALTER SYSTEM SET log_statement = 'mod'" -c "SELECT pg_reload_conf()" >/dev/null
marca FIN

echo "== 6. Recorte del log real -> $OUT"
{
  echo "# Log de auditoría REAL de PostgreSQL (capturado en vivo, no reconstruido)"
  echo "# Generado por sql/simulacro_live.sh el $(date '+%Y-%m-%d %H:%M:%S %z') · $(psql -X -At -d postgres -c 'SHOW server_version')"
  echo "# log_line_prefix = '%m [%p] %u@%d %h %a '  ·  'mod' para la operación normal, 'all' solo en la ventana de incidente"
  echo "# Datos sintéticos: anon_test007 (login de laboratorio, borrado al final), base efímera $DB, origen 127.0.0.1"
  echo
  INI=$(grep -n "SIMULACRO_TP6 INICIO" "$PGLOG" | tail -1 | cut -d: -f1)   # solo la última corrida
  tail -n +"$INI" "$PGLOG" | sed -n '1,/SIMULACRO_TP6 FIN/p' \
    | grep -v "pg_reload_conf\|ALTER SYSTEM\|received SIGHUP\|parameter \"log_statement\" changed" \
    | sed -E "s/PASSWORD '[^']*'/PASSWORD '***'/g"
} > "$OUT"
wc -l "$OUT"

echo "== 7. Limpieza"
su_psql -d postgres <<'SQL'
ALTER SYSTEM RESET log_connections;
ALTER SYSTEM RESET log_disconnections;
ALTER SYSTEM RESET log_statement;
ALTER SYSTEM RESET log_line_prefix;
SELECT pg_reload_conf();
SQL
su_psql -d "$DB" -c "DROP ROLE IF EXISTS anon_test007" 2>/dev/null || true
dropdb "$DB"
echo "OK: auditoría probada en vivo; base efímera y login sintético eliminados."

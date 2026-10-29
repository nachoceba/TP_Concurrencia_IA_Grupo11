#!/usr/bin/env bash
# =============================================================================
# backup_foodstore.sh — Respaldo lógico diario de Food Store (formato custom)
#
# Uso:      ./scripts/backup_foodstore.sh
# Conexión: variables estándar de libpq, con valores por defecto:
#           PGHOST=localhost PGPORT=5432 PGUSER=postgres PGDATABASE=foodstore
# Clave:    NO va en este script. Se toma de ~/.pgpass (chmod 600) o de
#           PGPASSWORD exportada en la sesión. Se usa --no-password: si no hay
#           credencial, el script falla en vez de quedarse esperando (cron).
# Salida:   backups/foodstore_AAAAMMDD_HHMMSS.dump  (+ .counts con filas previas)
#           logs/backup_AAAAMMDD.log (una línea por evento, se acumula en el día)
# Exit:     0 = OK · distinto de 0 = falló (y queda ERROR en el log)
# =============================================================================
set -euo pipefail

export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-postgres}"
DB="${PGDATABASE:-foodstore}"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$BASE_DIR/backups"
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
DUMP="$BACKUP_DIR/${DB}_${STAMP}.dump"
TMP="$DUMP.tmp"
COUNTS="$BACKUP_DIR/${DB}_${STAMP}.counts"
LOG="$LOG_DIR/backup_$(date +%Y%m%d).log"   # un log por día; cada corrida agrega líneas

log() { echo "$(date '+%Y-%m-%d %H:%M:%S%z') [$1] $2" | tee -a "$LOG"; }

# Si cualquier comando falla: se registra, se limpia el parcial y se sale con error
on_error() {
  local rc=$?
  log ERROR "Respaldo FALLIDO (código $rc, línea $1). Se descarta el archivo parcial."
  rm -f "$TMP" "$COUNTS"
  exit "$rc"
}
trap 'on_error $LINENO' ERR

log INFO "Inicio respaldo de '$DB' en $PGHOST:$PGPORT como $PGUSER"
log INFO "pg_dump: $(pg_dump --version)"

# 1) Conteo de filas ANTES del respaldo (se compara después de restaurar)
psql --no-password -X -q -tA -F '|' -v ON_ERROR_STOP=1 -d "$DB" \
     -f "$BASE_DIR/sql/conteo_filas.sql" 2> >(tee -a "$LOG" >&2) | tr -d '\r' > "$COUNTS"
# tr -d '\r': en Windows psql termina las líneas con \r\n y rompe log y comparación
log INFO "Filas antes del respaldo: $(tr '\n' ' ' < "$COUNTS")"

# 2) Dump en formato custom a un .tmp: si falla a mitad de camino nunca queda
#    un .dump incompleto que restore_test.sh pueda tomar como "el último"
INICIO=$(date +%s)
pg_dump --no-password -d "$DB" -Fc -f "$TMP" 2>>"$LOG"
FIN=$(date +%s)

# 3) Verificación: el archivo no está vacío y pg_restore puede leer su índice
[ -s "$TMP" ] || { log ERROR "El dump quedó vacío"; false; }
OBJETOS=$(pg_restore --list "$TMP" | grep -vc '^;')
mv "$TMP" "$DUMP"

TAMANO=$(du -h "$DUMP" | cut -f1)
SHA=$(sha256sum "$DUMP" | cut -d' ' -f1)
log OK "Respaldo generado: $(basename "$DUMP") | $TAMANO | $((FIN-INICIO)) s | $OBJETOS objetos en el TOC | sha256 $SHA"
exit 0

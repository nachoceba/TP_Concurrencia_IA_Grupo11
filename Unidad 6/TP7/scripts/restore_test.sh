#!/usr/bin/env bash
# =============================================================================
# restore_test.sh — Simulacro de desastre contra reloj (Parte 4)
#
# Restaura el ÚLTIMO respaldo de backups/ en una base NUEVA
# (foodstore_restore_test), valida y mide RTO y antigüedad del respaldo (RPO).
#
# Uso:      ./scripts/restore_test.sh [ruta/al/archivo.dump]
#           JOBS=4 ./scripts/restore_test.sh    → pg_restore en paralelo
# Clave:    igual que backup_foodstore.sh (~/.pgpass o PGPASSWORD, nunca acá)
# Exit:     0 = restaurada y validada · distinto de 0 = falló
# =============================================================================
set -euo pipefail

export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-postgres}"
ORIGEN="foodstore"
DESTINO="foodstore_restore_test"
JOBS="${JOBS:-1}"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$BASE_DIR/logs"; mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/restore_$(date +%Y%m%d).log"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S%z') [$1] $2" | tee -a "$LOG"; }
seg() { awk -v a="$1" -v b="$2" 'BEGIN{printf "%.1f", b-a}'; }   # sin bc (Git Bash no lo trae)
trap 'log ERROR "Simulacro FALLIDO en línea $LINENO"; exit 1' ERR

# --- Guardas de seguridad ----------------------------------------------------
if [ "$DESTINO" = "$ORIGEN" ]; then
  log ERROR "La base destino no puede ser $ORIGEN. Se aborta."; exit 2
fi

DUMP="${1:-$(ls -1t "$BASE_DIR"/backups/${ORIGEN}_*.dump 2>/dev/null | head -n1 || true)}"
[ -n "$DUMP" ] && [ -s "$DUMP" ] || { log ERROR "No hay respaldo para restaurar"; exit 3; }
COUNTS="${DUMP%.dump}.counts"
[ -s "$COUNTS" ] || { log ERROR "Falta $COUNTS (conteo previo al respaldo)"; exit 3; }

# --- RPO observado: antigüedad del respaldo al empezar el simulacro --------
STAMP=$(basename "$DUMP" .dump | sed "s/^${ORIGEN}_//")         # AAAAMMDD_HHMMSS
FECHA_BK=$(date -d "${STAMP:0:8} ${STAMP:9:2}:${STAMP:11:2}:${STAMP:13:2}" +%s)
EDAD=$(( $(date +%s) - FECHA_BK ))
log INFO "Respaldo: $(basename "$DUMP") | tomado $(date -d @"$FECHA_BK" '+%F %T') | antigüedad $((EDAD/3600)) h $((EDAD%3600/60)) min $((EDAD%60)) s"

# Limpieza previa de un ensayo anterior (sólo la base descartable, fuera del reloj)
dropdb --no-password --if-exists "$DESTINO"

# --- CRONÓMETRO ---------------------------------------------------------------
T0=$(date +%s.%N)
log INFO "Cronómetro INICIO — createdb $DESTINO"
createdb --no-password "$DESTINO"

pg_restore --no-password -d "$DESTINO" --no-owner --no-privileges \
           --exit-on-error --jobs="$JOBS" "$DUMP" 2>>"$LOG"
T1=$(date +%s.%N)
log INFO "pg_restore terminó (jobs=$JOBS) en $(seg "$T0" "$T1") s"

# Validación 1: conteos idénticos a los registrados antes del respaldo
DESPUES=$(psql --no-password -X -q -tA -F '|' -v ON_ERROR_STOP=1 -d "$DESTINO" \
          -f "$BASE_DIR/sql/conteo_filas.sql" | tr -d '\r')     # \r\n de psql en Windows
if [ "$DESPUES" = "$(tr -d '\r' < "$COUNTS")" ]; then
  log OK "Conteos iguales al registro previo: $(echo "$DESPUES" | tr '\n' ' ')"
else
  log ERROR "Conteos DISTINTOS"; diff <(cat "$COUNTS") <(echo "$DESPUES") | tee -a "$LOG"; false
fi

# Validación 2: reglas lógicas (tienen que dar 0)
INV_PROD=$(psql --no-password -X -tA -d "$DESTINO" -c \
  "SELECT COUNT(*) FROM producto WHERE precio < 0 OR stock < 0" | tr -d '\r')
INV_DET=$(psql --no-password -X -tA -d "$DESTINO" -c \
  "SELECT COUNT(*) FROM detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0" | tr -d '\r')
[ "$INV_PROD" = 0 ] && [ "$INV_DET" = 0 ] || {
  log ERROR "Inválidos: productos=$INV_PROD detalles=$INV_DET"; false; }
log OK "productos_invalidos=$INV_PROD detalles_invalidos=$INV_DET"

T2=$(date +%s.%N)
# --- FIN CRONÓMETRO -----------------------------------------------------------
RTO=$(seg "$T0" "$T2")
log OK "Cronómetro FIN — RTO observado: ${RTO} s | RPO observado (antigüedad del respaldo): ${EDAD} s"

# Detalle completo de la validación para la evidencia (fuera del reloj)
psql --no-password -X -v ON_ERROR_STOP=1 -d "$DESTINO" \
     -f "$BASE_DIR/sql/validacion_restore.sql" >> "$LOG"
log INFO "Detalle de validación agregado al log: $LOG"

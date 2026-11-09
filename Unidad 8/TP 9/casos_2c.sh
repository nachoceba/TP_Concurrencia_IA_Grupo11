#!/usr/bin/env bash
# =============================================================================
# TP 8 · Consigna 2.c · Corre los casos C2 a C6 de punta a punta y guarda la
# evidencia en docs/evidencias/casos_2c.txt
#
# Requisitos: psql y sqlite3 en el PATH (en Windows, Git Bash), la copia de
# pruebas creada y la vista v_snapshot_movil instalada (ver README).
# Conexión: usa las variables estándar de PostgreSQL si hacen falta
#   PGDB=food_store_tp8 PGUSER=postgres PGPASSWORD=... ./casos_2c.sh
# =============================================================================
set -u
cd "$(dirname "$0")"
PGDB="${PGDB:-food_store_tp8}"
DB="movil/foodstore_movil.db"
OUT="docs/evidencias/casos_2c.txt"
mkdir -p docs/evidencias

titulo() { printf '\n==================== %s ====================\n' "$1"; }
pg()     { psql -X -q -d "$PGDB" "$@"; }
tablet() { (cd movil && sqlite3 foodstore_movil.db) ; }

# Exporta una instantánea nueva desde PostgreSQL y la carga en la tablet
instantanea() {
  (cd movil && psql -X -q -d "$PGDB" \
     -c "\copy (SELECT * FROM v_snapshot_movil) TO 'servidor_snapshot.csv' CSV HEADER" \
   && sqlite3 -header -column foodstore_movil.db < cargar_snapshot.sql)
}
semaforo() { (cd movil && sqlite3 foodstore_movil.db < semaforo.sql); }

{
echo "TP 8 · Casos C2 a C6 · corrida del $(date '+%Y-%m-%d %H:%M:%S')"
echo "Base de pruebas: $PGDB · tablet: $DB"

titulo "0 · Copia del servidor en su estado inicial + instantánea S1"
pg -f servidor/restaurar_copia.sql
echo "-- Estado del servidor ANTES de la simulación:"
pg -f servidor/verificar_servidor.sql
instantanea

titulo "1 · Tablet sin señal: se arman los borradores (precios de S1)"
(cd movil && sqlite3 foodstore_movil.db < casos/01_borradores.sql)

titulo "2 · Mientras tanto, en el servidor: sube la Napolitana (C2) y baja lógica de la Roquefort (C4)"
pg -f servidor/preparar_casos.sql

titulo "3 · Vuelve la señal: instantánea S2 + catálogo recargado"
instantanea
echo "-- C4: la Roquefort (id 7) ya no aparece en el catálogo..."
(cd movil && sqlite3 -header -column foodstore_movil.db \
   "SELECT count(*) AS roquefort_en_catalogo FROM v_catalogo_local WHERE id = 7;")
echo "-- ...pero la fila sigue en producto_cache como lápida:"
(cd movil && sqlite3 -header -column foodstore_movil.db \
   "SELECT id, nombre, disponible, eliminado, fecha_copia FROM producto_cache WHERE id = 7;")

titulo "4 · Semáforo"
semaforo

titulo "5 · C2: el cliente acepta el precio nuevo -> solicitud nueva"
(cd movil && sqlite3 foodstore_movil.db < casos/02_c2_aceptar.sql)
semaforo

titulo "6 · C6: reenvío de la misma solicitud (mismo UUID)"
(cd movil && sqlite3 foodstore_movil.db < casos/03_c6_reenvio.sql 2>&1)
echo "-- Repetir la simulación no reevalúa nada:"
semaforo

titulo "7 · PostgreSQL no cambió: pedidos y stock iguales a los del paso 0"
pg -f servidor/verificar_servidor.sql
} 2>&1 | tee "$OUT"

echo
echo "Evidencia guardada en $OUT"

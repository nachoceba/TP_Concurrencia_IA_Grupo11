-- =============================================================================
-- maintenance.sql — Revisión semanal de mantenimiento de Food Store (Parte 3)
-- Uso:  psql -d foodstore -X -f sql/maintenance.sql > logs/maint_AAAA-MM-DD.txt
--
-- Flujo: (1) revisar la configuración de autovacuum, (2) diagnosticar cada tabla,
-- (3) aplicar SOLO las acciones que el diagnóstico justifica, (4) volver a medir.
--
-- Criterio de la cátedra: NO se usa VACUUM FULL. Toma un ACCESS EXCLUSIVE lock,
-- bloquea lecturas y escrituras y reescribe la tabla entera. No sirve como tarea
-- periódica. VACUUM común y ANALYZE no bloquean lecturas ni escrituras.
--
-- Las acciones se generan con \gexec: psql ejecuta cada sentencia generada por
-- separado, fuera de una transacción (VACUUM no puede correr dentro de una).
-- Si ninguna tabla cumple el criterio, \gexec no ejecuta nada.
-- =============================================================================
\pset null '—'
\echo '=================== MANTENIMIENTO FOOD STORE ==================='
SELECT current_database() AS base, now() AS ejecutado;

-- ---------------------------------------------------------------------------
\echo '\n== 1. CONFIGURACIÓN DE AUTOVACUUM'
SELECT name, setting, unit
FROM pg_settings
WHERE name IN ('autovacuum', 'track_counts', 'autovacuum_naptime',
               'autovacuum_vacuum_threshold', 'autovacuum_vacuum_scale_factor',
               'autovacuum_analyze_threshold', 'autovacuum_analyze_scale_factor',
               'autovacuum_max_workers')
ORDER BY name;

\echo '-- Workers de autovacuum corriendo ahora'
SELECT pid, date_trunc('second', now() - xact_start) AS duracion, left(query, 70) AS tarea
FROM pg_stat_activity WHERE backend_type = 'autovacuum worker';

-- ---------------------------------------------------------------------------
-- Diagnóstico: para cada tabla se calcula el umbral con el que autovacuum
-- actuaría (threshold + scale_factor * filas) y se marca lo que hace falta.
CREATE TEMP VIEW diag AS
SELECT s.relname AS tabla, s.relid,
       s.n_live_tup AS vivas, s.n_dead_tup AS muertas,
       round(100.0 * s.n_dead_tup / NULLIF(s.n_live_tup, 0), 1) AS pct_muertas,
       s.n_mod_since_analyze AS mod_desde_analyze,
       (current_setting('autovacuum_vacuum_threshold')::int
        + current_setting('autovacuum_vacuum_scale_factor')::float8 * s.n_live_tup)::bigint AS umbral_autovacuum,
       GREATEST(s.last_vacuum,  s.last_autovacuum)  AS ultimo_vacuum,
       GREATEST(s.last_analyze, s.last_autoanalyze) AS ultimo_analyze,
       (s.n_dead_tup > 1000 AND s.n_dead_tup > 0.2 * s.n_live_tup)          AS necesita_vacuum,
       (s.last_analyze IS NULL AND s.last_autoanalyze IS NULL)
         OR s.n_mod_since_analyze > GREATEST(1000, 0.1 * s.n_live_tup)      AS necesita_analyze
FROM pg_stat_user_tables s;

\echo '\n== 2. DIAGNÓSTICO PREVIO (justifica las acciones del punto 3)'
SELECT tabla, vivas, muertas, pct_muertas, umbral_autovacuum, mod_desde_analyze,
       to_char(ultimo_vacuum,  'MM-DD HH24:MI') AS ult_vacuum,
       to_char(ultimo_analyze, 'MM-DD HH24:MI') AS ult_analyze,
       CASE WHEN necesita_vacuum  THEN 'VACUUM (ANALYZE)'
            WHEN necesita_analyze THEN 'ANALYZE'
            ELSE 'nada' END AS accion
FROM diag ORDER BY muertas DESC, tabla;

-- ---------------------------------------------------------------------------
\echo '\n== 3. ACCIONES JUSTIFICADAS'
\echo '-- 3a. VACUUM (ANALYZE) sólo en tablas con > 20 % de tuplas muertas y > 1000 muertas'
\echo '--     Libera espacio reutilizable y actualiza estadísticas sin bloquear la tabla.'
SELECT format('VACUUM (ANALYZE, VERBOSE) %I', tabla)
FROM diag WHERE necesita_vacuum
\gexec

\echo '-- 3b. REFRESH de la vista materializada si está vacía y hay ventas cargadas'
\echo '--     (pasa cuando 04_objects.sql corre antes de cargar los datos).'
\echo '--     CONCURRENTLY usa el índice único uq_mv_top_productos_puesto y no bloquea lecturas.'
\echo '--     Va ANTES del ANALYZE: analizar una MV vacía y después refrescarla deja estadísticas viejas.'
SELECT 'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_productos_categoria'
WHERE NOT EXISTS (SELECT 1 FROM mv_top_productos_categoria)
  AND EXISTS (SELECT 1 FROM detalle_pedido)
\gexec

\echo '-- 3c. ANALYZE sólo en tablas o MV sin estadísticas o con muchos cambios desde el último'
\echo '--     Sin estadísticas el planificador estima mal y elige planes malos.'
SELECT format('ANALYZE VERBOSE %I', tabla)
FROM diag WHERE necesita_analyze AND NOT necesita_vacuum
\gexec

-- ---------------------------------------------------------------------------
-- pg_stat se actualiza de forma asíncrona: se fuerza la lectura de valores nuevos
SELECT pg_stat_clear_snapshot();
\echo '\n== 4. ESTADO POSTERIOR (todas las tablas tienen que quedar en "nada")'
SELECT tabla, vivas, muertas, pct_muertas,
       to_char(ultimo_vacuum,  'MM-DD HH24:MI') AS ult_vacuum,
       to_char(ultimo_analyze, 'MM-DD HH24:MI') AS ult_analyze,
       CASE WHEN necesita_vacuum  THEN 'PENDIENTE VACUUM'
            WHEN necesita_analyze THEN 'PENDIENTE ANALYZE'
            ELSE 'nada' END AS accion
FROM diag ORDER BY tabla;
SELECT COUNT(*) AS filas_mv_top_productos FROM mv_top_productos_categoria;

\echo '=================== FIN MANTENIMIENTO ==================='

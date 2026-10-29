-- =============================================================================
-- health_check.sql — Chequeo de salud diario de Food Store (Parte 3)
-- Uso:  psql -d foodstore -X -f sql/health_check.sql > logs/health_AAAA-MM-DD.txt
-- Sólo hace lecturas sobre vistas de estadísticas: no modifica nada.
-- Usa current_database() en vez de 'foodstore' fijo, así también sirve sobre
-- foodstore_restore_test. Probado en PostgreSQL 16.
-- Umbrales (SPEC_U6.md): conexiones > 80 % del máximo, consultas > 5 min,
-- tuplas muertas > 20 %, cache hit < 95 %.
-- =============================================================================
\pset null '—'
\echo '=================== HEALTH CHECK FOOD STORE ==================='
SELECT current_database() AS base, now() AS ejecutado, version() AS motor;

-- ---------------------------------------------------------------------------
\echo '\n== 1. TAMAÑO DE LA BASE'
SELECT pg_size_pretty(pg_database_size(current_database())) AS tamano;

\echo '-- Top 5 tablas por tamaño total (datos + índices + TOAST)'
SELECT relname AS tabla,
       pg_size_pretty(pg_total_relation_size(relid)) AS total,
       pg_size_pretty(pg_indexes_size(relid))        AS indices
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 5;

-- ---------------------------------------------------------------------------
\echo '\n== 2. ACTIVIDAD DE CONEXIONES'
SELECT d.numbackends                                          AS conexiones,
       current_setting('max_connections')::int                AS max_conexiones,
       round(100.0 * d.numbackends
             / current_setting('max_connections')::int, 1)    AS pct_uso,
       d.xact_commit, d.xact_rollback,
       round(100.0 * d.xact_rollback
             / NULLIF(d.xact_commit + d.xact_rollback, 0), 2) AS pct_rollback,
       round(100.0 * d.blks_hit
             / NULLIF(d.blks_hit + d.blks_read, 0), 2)        AS cache_hit_pct,
       d.deadlocks,
       CASE WHEN d.numbackends > 0.8 * current_setting('max_connections')::int
              THEN 'ALERTA: >80% conexiones'
            WHEN 100.0 * d.blks_hit / NULLIF(d.blks_hit + d.blks_read, 0) < 95
              THEN 'ALERTA: cache hit < 95%'
            ELSE 'OK' END                                     AS estado
FROM pg_stat_database d
WHERE d.datname = current_database();

\echo '-- Conexiones por usuario y estado'
SELECT usename AS usuario, COALESCE(state, 'background') AS estado, COUNT(*) AS cantidad
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY 1, 2 ORDER BY 3 DESC;

-- ---------------------------------------------------------------------------
\echo '\n== 3. ESTADO DE TABLAS (tuplas muertas, autovacuum, estadísticas)'
SELECT relname AS tabla,
       n_live_tup AS vivas,
       n_dead_tup AS muertas,
       round(100.0 * n_dead_tup / NULLIF(n_live_tup, 0), 1)       AS pct_muertas,
       n_mod_since_analyze                                         AS mod_desde_analyze,
       to_char(GREATEST(last_vacuum,  last_autovacuum),  'YYYY-MM-DD HH24:MI') AS ultimo_vacuum,
       to_char(GREATEST(last_analyze, last_autoanalyze), 'YYYY-MM-DD HH24:MI') AS ultimo_analyze,
       CASE WHEN n_dead_tup > 1000 AND n_dead_tup > 0.2 * n_live_tup THEN 'ALERTA: >20% muertas'
            WHEN last_analyze IS NULL AND last_autoanalyze IS NULL   THEN 'AVISO: sin estadísticas'
            ELSE 'OK' END AS estado
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC, relname;

\echo '-- Vistas materializadas: ¿pobladas y con filas?'
SELECT m.matviewname AS vista, m.ispopulated AS poblada,
       pg_size_pretty(pg_relation_size(format('%I.%I', m.schemaname, m.matviewname)::regclass)) AS tamano
FROM pg_matviews m
WHERE m.schemaname = 'public';
-- La MV viene de parcial_BD/04_objects.sql; si la base no la tiene, se saltea.
SELECT to_regclass('public.mv_top_productos_categoria') IS NOT NULL AS hay_mv \gset
\if :hay_mv
SELECT COUNT(*) AS filas_mv_top_productos,
       CASE WHEN COUNT(*) = 0 AND EXISTS (SELECT 1 FROM detalle_pedido)
            THEN 'ALERTA: MV vacía con ventas cargadas (falta REFRESH)'
            ELSE 'OK' END AS estado
FROM mv_top_productos_categoria;
\else
\echo '(la base no tiene mv_top_productos_categoria: control omitido)'
\endif

-- ---------------------------------------------------------------------------
\echo '\n== 4. CONSULTAS ACTIVAS (no idle; se excluye esta sesión)'
SELECT pid, usename AS usuario, state AS estado,
       date_trunc('second', now() - query_start) AS duracion,
       wait_event_type || ':' || wait_event      AS espera,
       left(regexp_replace(query, '\s+', ' ', 'g'), 80) AS consulta,
       CASE WHEN now() - query_start > interval '5 minutes'
            THEN 'ALERTA: > 5 min' ELSE 'OK' END AS alerta
FROM pg_stat_activity
WHERE datname = current_database()
  AND state <> 'idle'
  AND pid <> pg_backend_pid()
ORDER BY duracion DESC NULLS LAST;

\echo '-- Sesiones bloqueadas por otra (tiene que dar 0 filas)'
SELECT pid, pg_blocking_pids(pid) AS bloqueada_por,
       date_trunc('second', now() - query_start) AS esperando,
       left(query, 60) AS consulta
FROM pg_stat_activity
WHERE datname = current_database() AND cardinality(pg_blocking_pids(pid)) > 0;

-- ---------------------------------------------------------------------------
\echo '\n== 5. EDAD DE TRANSACCIONES (prevención de wraparound)'
SELECT datname AS base, age(datfrozenxid) AS edad_xid,
       round(100.0 * age(datfrozenxid) / 2000000000, 2) AS pct_hacia_limite,
       CASE WHEN age(datfrozenxid) > 200000000 THEN 'AVISO: revisar freeze' ELSE 'OK' END AS estado
FROM pg_database
WHERE datname = current_database();

\echo '=================== FIN HEALTH CHECK ==================='

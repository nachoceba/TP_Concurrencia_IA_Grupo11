-- =============================================================================
-- TP6 Parte B/E — Secuencia de prueba de auditoría (runnable, sin residuos)
-- Uso: psql -d tp6_u5_work -f TP6/sql/auditoria_test.sql
--   Requiere credencial válida (auth scram-sha-256, ver pg_hba.conf).
--   Sin credencial el live queda pendiente (error fe_sendauth), no inventar logs.
-- Corre en transacción: BEGIN ... ROLLBACK (no deja residuos en pedido/producto).
-- Base: parcial_BD/01_schema (pedido, producto, v_pedidos_resumen) + Parte A roles.
-- Solo datos sintéticos existentes (ids 1); sin datos reales / sin PII.
-- =============================================================================

BEGIN;

-- Paso 0. Operar con el login de aplicación (mínimo privilegio, Parte A).
SET ROLE app_web;

-- Paso 1. Lectura en vista resumen (con log_statement='mod' no registra
-- texto SELECT; solo conexión/sesión. Con 'all' en ventana de incidente sí).
SELECT * FROM v_pedidos_resumen LIMIT 5;

-- Paso 2. INSERT en pedido (queda registrado con log_statement='mod').
-- Cliente existente (usuario_id = 1), forma_pago válido del ENUM, total 0
-- que luego calcula el trigger (trg_total_ins); metadatos sintéticos.
INSERT INTO pedido (estado, forma_pago, total, metadatos, usuario_id)
VALUES ('PENDIENTE', 'TARJETA', 0, '{"canal":"web"}', 1)
RETURNING id_pedido, estado, forma_pago, total, usuario_id;

-- Verificación inmediata del pedido insertado (misma transacción).
SELECT id_pedido, estado, forma_pago, total, usuario_id
FROM pedido
ORDER BY id_pedido DESC
LIMIT 1;

-- Paso 3. UPDATE de stock en producto (queda registrado con 'mod').
UPDATE producto SET stock = stock - 1
WHERE id_producto = 1 AND eliminado = FALSE;

-- Verificación inmediata del stock (valor nuevo; el log solo guarda texto).
SELECT id_producto, stock FROM producto WHERE id_producto = 1;

-- Paso 4. Login fallido: NO se prueba dentro de esta transacción.
-- Probar fuera con psql y password errónea; deja FATAL en el log del motor:
--   PGPASSWORD=incorrecta psql -h 127.0.0.1 -U app_web -d tp6_u5_work -c "SELECT 1;"
-- (esperado: FATAL password authentication failed, auth scram-sha-256).

-- Cierre: no dejar residuos + devolver rol.
RESET ROLE;
ROLLBACK;

-- Nota: ROLLBACK revierte INSERT/UPDATE de esta secuencia; el log del motor
-- (conexión, INSERT, UPDATE, FATAL externo, desconexión) sí persiste para B.3.

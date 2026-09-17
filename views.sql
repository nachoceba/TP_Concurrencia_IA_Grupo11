-- =============================================================================
-- TP2 Concurrencia IA Grupo 11 - Vistas de negocio (views.sql)
-- Motor: PostgreSQL 18.6 | Base: clon de TP2_Concurrencia_IA_Grupo11
--
-- PROTOCOLO DE SEGURIDAD (protocolo_seguridad.md) - OBLIGATORIO:
--   Paso 1 (Clon, nunca sobre la principal):
--     dropdb -U postgres TP2_Concurrencia_IA_Grupo11_clon --if-exists;
--     createdb -U postgres -T TP2_Concurrencia_IA_Grupo11 TP2_Concurrencia_IA_Grupo11_clon;
--     psql -U postgres -d TP2_Concurrencia_IA_Grupo11_clon -f views.sql
--   Paso 2 (Transaccion: probar con ROLLBACK antes del COMMIT definitivo):
--     BEGIN; \i views.sql  -- inspeccionar mensajes, luego ROLLBACK o COMMIT
--   Paso 3 (Respaldo antes de aplicar):
--     pg_dump -U postgres -Fc TP2_Concurrencia_IA_Grupo11_clon > backup_pre_views.dump
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. v_pedidos_resumen
--    Resumen de pedidos vigentes con datos del cliente.
--    Resuelve HU-PED-01 de queries.sql ("SELECT id, usuario, fecha, estado,
--    forma_pago, total FROM v_pedidos_resumen"), que hoy falla al no existir.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_pedidos_resumen AS
SELECT p.id_pedido,
       u.nombre || ' ' || u.apellido AS usuario,
       p.fecha,
       p.estado,
       p.forma_pago,
       p.total
FROM   pedido p
JOIN   usuario u ON u.id_usuario = p.usuario_id
WHERE  p.eliminado = FALSE
  AND  u.eliminado = FALSE;

-- -----------------------------------------------------------------------------
-- 2. v_catalogo_productos
--    Catalogo vigente para el frontend (localhost:8080): productos vigentes y
--    disponibles con el nombre de su categoria.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_catalogo_productos AS
SELECT pr.id_producto,
       pr.nombre,
       pr.precio,
       pr.stock,
       pr.disponible,
       c.nombre AS categoria
FROM   producto pr
JOIN   categoria c ON c.id_categoria = pr.categoria_id
WHERE  pr.eliminado = FALSE
  AND  c.eliminado = FALSE;

-- -----------------------------------------------------------------------------
-- 3. v_usuarios_segura
--    Vista de SEGURIDAD sobre usuario: expone todas las columnas EXCEPTO
--    contrasena y solo los usuarios vigentes (eliminado = FALSE).
--    Permite otorgar SELECT sin dar acceso a la tabla base:
--       GRANT SELECT ON v_usuarios_segura TO aplicacion_lectura;
--    (sin ningun privilegio sobre la tabla usuario)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_usuarios_segura AS
SELECT id_usuario,
       nombre,
       apellido,
       mail,
       celular,
       rol
FROM   usuario
WHERE  eliminado = FALSE;

COMMIT;
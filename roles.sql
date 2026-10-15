-- 1. Roles de grupo
CREATE ROLE rol_app_lectura;
CREATE ROLE rol_app_escritura;
CREATE ROLE rol_soporte;
CREATE ROLE rol_reportes;
-- 2. Uso del esquema
GRANT USAGE ON SCHEMA public
TO rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes;
-- 3. Asignación de privilegios específicos
GRANT SELECT ON v_productos_vigentes, v_categorias_vigentes
TO rol_app_lectura;
GRANT SELECT, INSERT, UPDATE ON pedido, detalle_pedido
TO rol_app_escritura;
GRANT EXECUTE ON PROCEDURE sp_crear_pedido(BIGINT, forma_pago, JSONB)
TO rol_app_escritura;
GRANT SELECT ON v_usuarios_publico, v_pedidos_resumen
TO rol_soporte;
GRANT SELECT ON mv_ventas_categoria_mes
TO rol_reportes;
-- 4. Roles de login y membresías
CREATE ROLE app_web WITH LOGIN PASSWORD 'cambiar_en_produccion';
GRANT rol_app_lectura, rol_app_escritura TO app_web;
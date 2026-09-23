-- =============================================================================
-- Food Store - Indices de optimizacion (05_indices.sql)
-- Base: 01_schema.sql + 04_objects.sql + datos (demo o masivo).
-- Estrategia: parciales WHERE eliminado=FALSE (soft delete), compuestos para
-- ORDER BY/LIMIT, covering INCLUDE para Index-Only, GIN trigram para ILIKE.
-- Protocolo: clon + BEGIN/ROLLBACK de prueba + pg_dump + VACUUM ANALYZE.
-- Post: VACUUM ANALYZE producto; VACUUM ANALYZE pedido; etc.
-- =============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- B1. Soft-delete parciales ------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_producto_activo ON producto (id_producto) WHERE eliminado = FALSE;
CREATE INDEX IF NOT EXISTS idx_pedido_activo ON pedido (id_pedido) WHERE eliminado = FALSE;
CREATE INDEX IF NOT EXISTS idx_usuario_activo ON usuario (id_usuario) WHERE eliminado = FALSE;
CREATE INDEX IF NOT EXISTS idx_categoria_activa ON categoria (id_categoria) WHERE eliminado = FALSE;

-- B2. Catalogo: categoria + disponibilidad + precio --------------------------------
CREATE INDEX IF NOT EXISTS idx_producto_categoria_disponible
    ON producto (categoria_id, disponible) WHERE eliminado = FALSE;
CREATE INDEX IF NOT EXISTS idx_producto_categoria_precio
    ON producto (categoria_id, precio) WHERE eliminado = FALSE AND disponible = TRUE;

-- B3/B4. Pedidos por usuario+fecha y estado+fecha ----------------------------------
CREATE INDEX IF NOT EXISTS idx_pedido_usuario_fecha
    ON pedido (usuario_id, fecha DESC) WHERE eliminado = FALSE;
CREATE INDEX IF NOT EXISTS idx_pedido_estado_fecha
    ON pedido (estado, fecha DESC) WHERE eliminado = FALSE;

-- B5/B6. Detalle: covering + inverso ------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_detalle_pedido_covering
    ON detalle_pedido (pedido_id) INCLUDE (producto_id, cantidad, subtotal)
    WHERE eliminado = FALSE;
CREATE INDEX IF NOT EXISTS idx_detalle_producto_pedido
    ON detalle_pedido (producto_id, pedido_id) WHERE eliminado = FALSE;

-- B7. Login por mail: ya existe UNIQUE(usuario.mail). No se crea nada.

-- B8. Busqueda ILIKE %texto% (solo si la app la usa) ---------------------------------
CREATE INDEX IF NOT EXISTS idx_producto_nombre_trgm ON producto USING GIN (nombre gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_usuario_apellido_trgm ON usuario USING GIN (apellido gin_trgm_ops);

COMMIT;

-- Reescrituras de referencia (medir con EXPLAIN (ANALYZE, BUFFERS, TIMING)):
-- Q1 catalogo: SELECT id_producto,nombre,precio,stock FROM producto WHERE categoria_id=1 AND disponible AND eliminado=FALSE ORDER BY precio LIMIT 50;
-- Q2 pedidos usuario: SELECT id_pedido,fecha,estado,total FROM pedido WHERE usuario_id=1 AND eliminado=FALSE ORDER BY fecha DESC LIMIT 20;
-- Q3 estado+fecha: SELECT id_pedido,fecha,total FROM pedido WHERE estado='PENDIENTE' AND fecha BETWEEN now()-interval '30 days' AND now() AND eliminado=FALSE ORDER BY fecha DESC LIMIT 100;
-- Q4 detalle: SELECT d.cantidad,d.subtotal,p.nombre FROM detalle_pedido d JOIN producto p ON p.id_producto=d.producto_id WHERE d.pedido_id=1 AND d.eliminado=FALSE;
-- Q5 login: SELECT id_usuario,nombre,rol FROM usuario WHERE mail='cliente_1@foodstore.com' AND eliminado=FALSE;
-- Q6 ILIKE: SELECT id_producto,nombre FROM producto WHERE nombre ILIKE '%Pizza%' AND eliminado=FALSE LIMIT 20;

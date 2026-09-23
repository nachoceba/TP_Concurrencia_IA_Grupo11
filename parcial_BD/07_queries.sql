-- ============================================================================
-- Food Store - Consultas HU + analiticas (07_queries.sql)
-- Base: 01 + 04 + 02. Nombres corregidos a id_categoria/id_producto/etc.
-- Cubre parcial.md punto 6: JOIN, agregacion, subconsulta, GROUP BY + HAVING,
-- window functions. Cada bloque es ejecutable en vivo.
-- ============================================================================

-- EPICA 1: CATEGORIAS -------------------------------------------------------------
-- HU-CAT-01
SELECT id_categoria AS id, nombre, descripcion FROM categoria
WHERE eliminado = FALSE ORDER BY id_categoria;
-- HU-CAT-02
INSERT INTO categoria (nombre, descripcion) VALUES ('Empanadas Test', 'Demo') RETURNING id_categoria AS id;
-- HU-CAT-03
UPDATE categoria SET nombre='Pizzas y Empanadas' WHERE id_categoria=1 AND eliminado=FALSE;
-- HU-CAT-04 (baja logica)
UPDATE categoria SET eliminado=TRUE WHERE id_categoria=2 AND eliminado=FALSE;

-- EPICA 2: PRODUCTOS ---------------------------------------------------------------
-- HU-PROD-01
SELECT p.id_producto AS id, p.nombre, p.precio, p.stock, c.nombre AS categoria
FROM producto p JOIN categoria c ON c.id_categoria = p.categoria_id
WHERE p.eliminado = FALSE ORDER BY p.id_producto;
-- HU-PROD-02
INSERT INTO producto (nombre, descripcion, precio, stock, imagen, disponible, categoria_id)
SELECT 'Fugazzeta', 'Rellena de queso', 1800.00, 10, NULL, TRUE, c.id_categoria
FROM categoria c WHERE c.id_categoria=1 AND c.eliminado=FALSE
RETURNING id_producto AS id;
-- HU-PROD-03
UPDATE producto SET precio=2000.00 WHERE id_producto=1 AND eliminado=FALSE;
-- HU-PROD-04
UPDATE producto SET eliminado=TRUE WHERE id_producto=1 AND eliminado=FALSE;

-- EPICA 3: USUARIOS ------------------------------------------------------------------
SELECT id_usuario AS id, nombre, apellido, mail, rol FROM usuario
WHERE eliminado=FALSE ORDER BY id_usuario;
INSERT INTO usuario (nombre, apellido, mail, celular, contrasena)
VALUES ('Juan','Perez','juan.perez@example.com','2611234567','hash_pass_123')
RETURNING id_usuario AS id;
UPDATE usuario SET celular='2617654321' WHERE id_usuario=1 AND eliminado=FALSE;
UPDATE usuario SET eliminado=TRUE WHERE id_usuario=1 AND eliminado=FALSE;

-- EPICA 4: PEDIDOS --------------------------------------------------------------------
-- HU-PED-01 (vista unificada)
SELECT id, usuario, fecha, estado, forma_pago, total FROM v_pedidos_resumen ORDER BY id;
-- HU-PED-02 (procedimiento con CALL + JSONB)
CALL sp_crear_pedido(1, 'EFECTIVO', '[{"producto_id":1,"cantidad":2},{"producto_id":2,"cantidad":1}]'::jsonb);
-- HU-PED-03
UPDATE pedido SET estado='CONFIRMADO', forma_pago='TARJETA' WHERE id_pedido=1 AND eliminado=FALSE;
-- HU-PED-04 (baja logica encadenada; detalle ya tiene eliminado)
BEGIN;
  UPDATE detalle_pedido SET eliminado=TRUE WHERE pedido_id=1;
  UPDATE pedido SET eliminado=TRUE WHERE id_pedido=1;
COMMIT;

-- ANALITICAS --------------------------------------------------------------------------
-- A) Top 5 productos por unidades (JOIN + GROUP BY + HAVING + ORDER + LIMIT)
SELECT pr.id_producto AS id, pr.nombre, SUM(dp.cantidad) AS unidades
FROM detalle_pedido dp JOIN producto pr ON pr.id_producto = dp.producto_id
WHERE dp.eliminado = FALSE AND pr.eliminado = FALSE
GROUP BY pr.id_producto, pr.nombre
HAVING SUM(dp.cantidad) > 1
ORDER BY unidades DESC LIMIT 5;

-- B) Facturacion por categoria y mes (JOIN 4 tablas + GROUP BY)
SELECT c.nombre AS categoria, date_trunc('month', ped.fecha) AS mes,
       SUM(dp.subtotal) AS facturado
FROM detalle_pedido dp
JOIN pedido ped ON ped.id_pedido = dp.pedido_id AND ped.eliminado = FALSE
JOIN producto pr ON pr.id_producto = dp.producto_id
JOIN categoria c ON c.id_categoria = pr.categoria_id
WHERE dp.eliminado = FALSE
GROUP BY c.nombre, date_trunc('month', ped.fecha)
HAVING SUM(dp.subtotal) > 5000
ORDER BY mes, facturado DESC;

-- C) Ranking usuarios por gasto (window RANK)
SELECT u.id_usuario AS id, u.nombre || ' ' || u.apellido AS usuario,
       SUM(ped.total) AS gasto,
       RANK() OVER (ORDER BY SUM(ped.total) DESC) AS puesto
FROM pedido ped JOIN usuario u ON u.id_usuario = ped.usuario_id
WHERE ped.eliminado = FALSE
GROUP BY u.id_usuario, u.nombre, u.apellido
ORDER BY puesto;

-- D) Pedidos sobre el promedio (subconsulta)
SELECT id_pedido AS id, total FROM pedido
WHERE eliminado = FALSE
  AND total > (SELECT AVG(total) FROM pedido WHERE eliminado = FALSE)
ORDER BY total DESC;

-- E) Productos sin ventas (LEFT JOIN + IS NULL)
SELECT pr.id_producto AS id, pr.nombre
FROM producto pr
LEFT JOIN detalle_pedido dp ON dp.producto_id = pr.id_producto AND dp.eliminado = FALSE
WHERE pr.eliminado = FALSE AND dp.id_detalle_pedido IS NULL
ORDER BY pr.id_producto;

-- F) Uso JSONB metadatos (exigencia parcial.md)
SELECT id_pedido, metadatos->>'canal' AS canal FROM pedido
WHERE metadatos ? 'canal' AND eliminado = FALSE LIMIT 20;

-- =============================================================================
-- Food Store - Seed DEMO chico (02_data_demo.sql)
-- Uso: demo en vivo del parcial (triggers, transacciones, EXPLAIN).
-- Base vacia post 01_schema.sql + 04_objects.sql (triggers activos).
-- Volumen: 6 categorias / 18 productos / 6 usuarios / 7 pedidos / 17 detalles.
-- IDs deterministas: en base vacia los IDENTITY generan 1..N en orden de INSERT,
-- por eso los detalles referencian pedido_id/producto_id 1..N sin OVERRIDING.
-- Alternativa masiva: ver 03_data_masivo.sql (EXCLUYENTE, no acumulable).
-- Protocolo: BEGIN de prueba + ROLLBACK antes del COMMIT definitivo.
-- =============================================================================

BEGIN;

-- 1. CATEGORIAS ---------------------------------------------------------------
INSERT INTO categoria (nombre, descripcion, eliminado) VALUES
('Pizzas', 'Pizza con masa madre', FALSE),
('Empanadas', 'Empanadas tradicionales de masa casera y rellenos abundantes', FALSE),
('Hamburguesas', 'Hamburguesas 100% carne vacuna y opciones veggie', FALSE),
('Bebidas', 'Gaseosas, aguas y jugos naturales', FALSE),
('Postres', 'Postres caseros y helados', FALSE),
('Promociones Especiales', 'Combos y ofertas descontinuadas', TRUE);

-- 2. PRODUCTOS (18 filas: 1 sin stock, 1 sin ventas, 1 eliminado) --------------
INSERT INTO producto (nombre, precio, descripcion, stock, imagen, disponible, categoria_id, eliminado) VALUES
('Muzzarella', 4500.00, 'Salsa de tomate casera, muzzarella y oregano', 50, 'muzza.jpg', TRUE, 1, FALSE),
('Especial de Jamon y Morrones', 5800.00, 'Muzzarella, jamon y morrones', 35, 'especial.jpg', TRUE, 1, FALSE),
('Fugazzeta Rellena', 6200.00, 'Rellena de muzzarella con cebolla', 20, 'fugazzeta.jpg', TRUE, 1, FALSE),
('Napolitana', 5200.00, 'Muzzarella, tomate, ajo y albahaca', 15, 'napo.jpg', TRUE, 1, FALSE),
('Empanada Carne Cuchillo', 950.00, 'Carne a cuchillo, cebolla y huevo', 120, 'emp_carne.jpg', TRUE, 2, FALSE),
('Empanada Jamon y Queso', 900.00, 'Jamon y muzzarella', 100, 'emp_jq.jpg', TRUE, 2, FALSE),
('Empanada Roquefort', 950.00, 'Queso azul y muzzarella', 40, 'emp_roque.jpg', TRUE, 2, FALSE),
('Burger Simple Cheese', 6500.00, 'Medallon 180g y cheddar', 30, 'burger_simple.jpg', TRUE, 3, FALSE),
('Burger Doble Bacon', 8200.00, 'Doble medallon y bacon', 25, 'burger_doble.jpg', TRUE, 3, FALSE),
('Burger Veggie NotMeat', 7100.00, 'Medallon vegetal y aderezo', 15, 'burger_veggie.jpg', TRUE, 3, FALSE),
('Coca-Cola Original 1.5L', 2200.00, 'Gaseosa 1.5L', 80, 'coca_15.jpg', TRUE, 4, FALSE),
('Cerveza Patagonia 730ml', 3500.00, 'Amber Ale', 45, 'cerveza_patagonia.jpg', TRUE, 4, FALSE),
('Agua Mineral 500ml', 1200.00, 'Sin gas', 100, 'agua_500.jpg', TRUE, 4, FALSE),
('Flan Casero', 2800.00, 'Con dulce de leche y crema', 12, 'flan.jpg', TRUE, 5, FALSE),
('Volcan de Chocolate', 3400.00, 'Corazon fundido', 0, 'volcan.jpg', FALSE, 5, FALSE),
('Tarta de Frutilla', 3200.00, 'Crema pastelera y frutillas', 10, 'tarta_frutilla.jpg', TRUE, 5, FALSE),
('Pizza de Anana (Hawaiana)', 4800.00, 'Muzzarella, jamon y anana', 0, 'hawaiana.jpg', FALSE, 1, TRUE),
('Hamburguesa Doble Test', 7000.00, 'Fila extra para pruebas de stock id 18', 12, 'test.jpg', TRUE, 3, FALSE);

-- 3. USUARIOS -----------------------------------------------------------------
INSERT INTO usuario (nombre, apellido, mail, celular, contrasena, rol, eliminado) VALUES
('Milton', 'Gimenez', 'milton.gimenez@email.com', '2614123456', '$2a$10$e83U...hash1', 'USUARIO', FALSE),
('Ana', 'Garis', 'ana.garis@email.com', '2615987654', '$2a$10$f94V...hash2', 'USUARIO', FALSE),
('Carlos', 'Mendoza', 'carlos.mendoza@email.com', '2613112233', '$2a$10$g05W...hash3', 'ADMIN', FALSE),
('Lucia', 'Fernandez', 'lucia.f@email.com', '2616445566', '$2a$10$h16X...hash4', 'USUARIO', FALSE),
('Roberto', 'Gomez', 'roberto.g@email.com', '2612778899', '$2a$10$i27Y...hash5', 'USUARIO', FALSE),
('Mariano', 'Lopez', 'mariano.lopez@email.com', '2618990011', '$2a$10$j38Z...hash6', 'USUARIO', TRUE);

-- 4. PEDIDOS (total=0, lo recalcula el trigger; fecha TIMESTAMPTZ) -------------
INSERT INTO pedido (fecha, estado, total, forma_pago, metadatos, usuario_id, eliminado) VALUES
('2026-06-15T12:00:00Z', 'TERMINADO', 0.00, 'EFECTIVO', '{"canal":"mostrador"}', 1, FALSE),
('2026-06-20T12:00:00Z', 'TERMINADO', 0.00, 'TARJETA', '{"canal":"web","cuotas":3}', 2, FALSE),
('2026-07-05T12:00:00Z', 'TERMINADO', 0.00, 'TRANSFERENCIA', '{"canal":"app"}', 1, FALSE),
('2026-07-18T12:00:00Z', 'TERMINADO', 0.00, 'TARJETA', '{"canal":"app"}', 4, FALSE),
('2026-08-01T12:00:00Z', 'CONFIRMADO', 0.00, 'EFECTIVO', '{"canal":"web"}', 2, FALSE),
('2026-08-10T12:00:00Z', 'PENDIENTE', 0.00, 'TRANSFERENCIA', '{"canal":"web"}', 5, FALSE),
('2026-08-12T12:00:00Z', 'CANCELADO', 0.00, 'EFECTIVO', '{"motivo":"cliente"}', 4, FALSE);

-- 5. DETALLES (disparan trg_subtotal + trg_total; subtotal lo pone el trigger) -
-- Se pasa precio_unitario explicito (precio congelado); el trigger lo valida.
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario) VALUES
(1, 1, 2, 4500.00),
(1, 11, 2, 2200.00),
(2, 9, 2, 8200.00),
(2, 12, 2, 3500.00),
(2, 14, 2, 2800.00),
(3, 5, 12, 950.00),
(3, 6, 6, 900.00),
(3, 11, 1, 2200.00),
(4, 3, 1, 6200.00),
(4, 11, 1, 2200.00),
(5, 2, 1, 5800.00),
(5, 5, 6, 950.00),
(5, 13, 2, 1200.00),
(6, 8, 1, 6500.00),
(6, 11, 1, 2200.00),
(7, 10, 1, 7100.00);

-- 6. Via procedimiento (prueba transaccional con CALL + JSONB) -----------------
-- Descomentar para demo en vivo despues del COMMIT inicial:
-- CALL sp_crear_pedido(1, 'EFECTIVO', '[{"producto_id":5,"cantidad":2}]'::jsonb);

COMMIT;

-- Verificaciones post-carga:
-- SELECT count(*) FROM categoria;   -- 6
-- SELECT count(*) FROM producto;    -- 18
-- SELECT count(*) FROM pedido WHERE total <> (SELECT COALESCE(SUM(subtotal),0) FROM detalle_pedido d WHERE d.pedido_id = pedido.id_pedido AND d.eliminado=FALSE); -- 0

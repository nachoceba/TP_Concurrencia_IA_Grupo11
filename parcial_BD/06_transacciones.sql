-- =============================================================================
-- Food Store - Pruebas de transacciones y concurrencia (06_transacciones.sql)
-- Requisito parcial.md punto 9: atomicidad COMMIT/ROLLBACK, aislamiento,
-- control de concurrencia. Ejecutar por bloques en 2 terminales psql.
-- Base: 02_data_demo.sql (producto id_producto=18 con stock=12 para el test).
-- Antes: UPDATE producto SET stock = 12 WHERE id_producto = 18;
-- =============================================================================

-- BLOQUE 1: COMMIT con SAVEPOINT (cabecera + detalles atomicos) ------------------
BEGIN;
    INSERT INTO pedido (estado, total, forma_pago, metadatos, usuario_id, eliminado)
    VALUES ('PENDIENTE', 0.00, 'EFECTIVO', '{"test":"commit"}', 5, FALSE)
    RETURNING id_pedido;
    -- Anotar el id devuelto (ej. 8) y usarlo abajo:
    SAVEPOINT antes_de_detalles;
    -- INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario) VALUES
    --     (8, 1, 3, 4500.00),
    --     (8, 11, 3, 2200.00);
    -- SELECT id_pedido, total FROM pedido WHERE id_pedido = 8;
COMMIT;
-- Verificacion: SELECT * FROM pedido WHERE id_pedido = 8;

-- BLOQUE 2: ROLLBACK ante CHECK violation (cantidad > 0) ---------------------------
BEGIN;
    INSERT INTO pedido (estado, total, forma_pago, usuario_id, eliminado)
    VALUES ('PENDIENTE', 0.00, 'TARJETA', 2, FALSE)
    RETURNING id_pedido;
    -- Suponiendo id 9:
    -- INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario) VALUES (9, 2, 2, 5800.00);
    -- INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario) VALUES (9, 13, 0, 1200.00); -- INVALIDO
ROLLBACK;
-- Verificacion: SELECT * FROM pedido WHERE id_pedido = 9; -- 0 filas

-- BLOQUE 3: READ COMMITTED (non-repeatable read) ------------------------------------
-- SESION A (terminal 1):
-- BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- SELECT id_producto, nombre, stock FROM producto WHERE id_producto = 18; -- stock=12
-- (dejar abierta; ir a sesion B)
-- SESION B (terminal 2):
-- BEGIN;
-- UPDATE producto SET stock = stock - 5 WHERE id_producto = 18;
-- COMMIT;
-- SELECT id_producto, nombre, stock FROM producto WHERE id_producto = 18; -- stock=7
-- SESION A (misma transaccion):
-- SELECT id_producto, nombre, stock FROM producto WHERE id_producto = 18; -- stock=7 (ve cambio => non-repeatable)
-- COMMIT;

-- BLOQUE 4: REPEATABLE READ (evita non-repeatable) ------------------------------------
-- Reset: UPDATE producto SET stock = 12 WHERE id_producto = 18;
-- SESION A:
-- BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- SELECT id_producto, nombre, stock FROM producto WHERE id_producto = 18; -- 12
-- SESION B:
-- BEGIN; UPDATE producto SET stock = stock - 5 WHERE id_producto = 18; COMMIT;
-- SESION A (misma transaccion):
-- SELECT id_producto, nombre, stock FROM producto WHERE id_producto = 18; -- 12 (snapshot, no ve cambio)
-- COMMIT;
-- Final: SELECT id_producto, stock FROM producto WHERE id_producto = 18; -- 7 aplicado

-- BLOQUE 5: Bloqueo FOR UPDATE (espera) ----------------------------------------------
-- SESION A: BEGIN; SELECT * FROM producto WHERE id_producto = 1 FOR UPDATE;
-- SESION B: BEGIN; UPDATE producto SET precio = 2000.00 WHERE id_producto = 1; -- queda esperando
-- SESION A: COMMIT; -- libera, B se destraba
-- SESION B: COMMIT;

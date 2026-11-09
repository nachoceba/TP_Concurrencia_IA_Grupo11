-- =============================================================================
-- TP 8 · Consigna 3.c · Hallazgo H1 (corregido)
-- Problema: sp_crear_pedido (parcial_BD/04_objects.sql) descuenta stock pero deja
-- disponible = true. Si el pedido se lleva las últimas unidades, la fila queda
-- (disponible = true, stock = 0) y viola ck_producto_disponible_stock: el pedido
-- entero falla y NO SE PUEDEN VENDER LAS ÚLTIMAS UNIDADES de ningún producto.
-- Corrección: en el mismo UPDATE, disponible pasa a false cuando el stock llega a 0
-- (la regla que ya expresa el CHECK). Única línea cambiada: la del UPDATE producto.
-- Probar primero en una copia (createdb -T food_store_tp8 food_store_review).
-- =============================================================================
CREATE OR REPLACE PROCEDURE sp_crear_pedido(
    p_usuario_id BIGINT,
    p_forma_pago forma_pago,
    p_items JSONB
)
AS $$
DECLARE
    v_pedido_id BIGINT;
    v_item JSONB;
    v_producto_id BIGINT;
    v_cantidad INTEGER;
    v_stock INTEGER;
    v_disponible BOOLEAN;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE id_usuario = p_usuario_id AND eliminado = FALSE) THEN
        RAISE EXCEPTION 'Usuario % inexistente o eliminado', p_usuario_id;
    END IF;
    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'El pedido debe tener al menos un item';
    END IF;

    INSERT INTO pedido (usuario_id, forma_pago, metadatos)
    VALUES (p_usuario_id, p_forma_pago, '{"origen":"sp_crear_pedido"}')
    RETURNING id_pedido INTO v_pedido_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_producto_id := (v_item->>'producto_id')::BIGINT;
        v_cantidad := (v_item->>'cantidad')::INTEGER;
        IF v_cantidad IS NULL OR v_cantidad <= 0 THEN
            RAISE EXCEPTION 'Cantidad invalida para producto %', v_producto_id;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM producto WHERE id_producto = v_producto_id AND eliminado = FALSE) THEN
            RAISE EXCEPTION 'Producto % inexistente o eliminado', v_producto_id;
        END IF;
        SELECT stock, disponible INTO v_stock, v_disponible
        FROM producto WHERE id_producto = v_producto_id FOR UPDATE;
        IF NOT v_disponible THEN RAISE EXCEPTION 'Producto % no disponible', v_producto_id; END IF;
        IF v_stock < v_cantidad THEN RAISE EXCEPTION 'Stock insuficiente producto % (stock=%)', v_producto_id, v_stock; END IF;

        INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad)
        VALUES (v_pedido_id, v_producto_id, v_cantidad);

        UPDATE producto
        SET stock      = stock - v_cantidad,
            disponible = (stock - v_cantidad) > 0      -- H1: sin esto, vender lo último viola el CHECK
        WHERE id_producto = v_producto_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

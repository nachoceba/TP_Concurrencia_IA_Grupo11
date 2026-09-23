-- =============================================================================
-- Food Store - Objetos programables unificados (04_objects.sql)
-- Motor: PostgreSQL 16+ | PL/pgSQL
-- Contenido:
--   A. Vistas unificadas (B: vigentes/resumen/detalle + A: catalogo/segura/MV)
--   B. Funcion calcular_total_pedido(BIGINT)
--   C. Triggers ROW: trg_subtotal (BEFORE) + trg_total (AFTER ROW)
--   D. Triggers STATEMENT con TRANSITION TABLES (exigencia parcial.md)
--   E. Procedimiento sp_crear_pedido(...) invocable con CALL + JSONB
-- Orden: ejecutar DESPUES de 01_schema.sql y ANTES de 02/03 datos.
-- Protocolo: probar en clon con BEGIN + ROLLBACK antes de COMMIT.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- A1. v_categorias_vigentes (origen B)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_categorias_vigentes AS
SELECT id_categoria AS id, nombre, descripcion
FROM categoria WHERE eliminado = FALSE;

-- A2. v_productos_vigentes (origen B) -------------------------------------------
CREATE OR REPLACE VIEW v_productos_vigentes AS
SELECT p.id_producto AS id, p.nombre, p.precio, p.stock, c.nombre AS categoria
FROM producto p
JOIN categoria c ON c.id_categoria = p.categoria_id
WHERE p.eliminado = FALSE AND c.eliminado = FALSE;

-- A3. v_pedidos_resumen (unificada A+B: trae id, usuario, fecha, estado, pago, total)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_pedidos_resumen AS
SELECT p.id_pedido AS id,
       u.nombre || ' ' || u.apellido AS usuario,
       p.fecha, p.estado, p.forma_pago, p.total
FROM pedido p
JOIN usuario u ON u.id_usuario = p.usuario_id
WHERE p.eliminado = FALSE AND u.eliminado = FALSE;

-- A4. v_pedido_detalle (origen B) ------------------------------------------------
CREATE OR REPLACE VIEW v_pedido_detalle AS
SELECT dp.pedido_id, pr.nombre AS producto,
       dp.cantidad, dp.precio_unitario, dp.subtotal
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.producto_id
WHERE dp.eliminado = FALSE;

-- A5. v_catalogo_productos (origen A: frontend) -----------------------------------
CREATE OR REPLACE VIEW v_catalogo_productos AS
SELECT pr.id_producto, pr.nombre, pr.precio, pr.stock, pr.disponible,
       c.nombre AS categoria
FROM producto pr
JOIN categoria c ON c.id_categoria = pr.categoria_id
WHERE pr.eliminado = FALSE AND c.eliminado = FALSE;

-- A6. v_usuarios_segura (origen A: seguridad, sin contrasena) ----------------------
CREATE OR REPLACE VIEW v_usuarios_segura AS
SELECT id_usuario, nombre, apellido, mail, celular, rol
FROM usuario WHERE eliminado = FALSE;
-- Uso: GRANT SELECT ON v_usuarios_segura TO aplicacion_lectura;

-- A7. mv_top_productos_categoria (origen A: materializada Top-3 por categoria) -----
DROP MATERIALIZED VIEW IF EXISTS mv_top_productos_categoria;
CREATE MATERIALIZED VIEW mv_top_productos_categoria AS
WITH agg AS (
    SELECT c.nombre AS categoria, pr.id_producto, pr.nombre AS producto,
           SUM(dp.subtotal) AS facturado
    FROM detalle_pedido dp
    JOIN producto pr ON pr.id_producto = dp.producto_id
    JOIN categoria c ON c.id_categoria = pr.categoria_id
    WHERE pr.eliminado = FALSE AND c.eliminado = FALSE AND dp.eliminado = FALSE
    GROUP BY c.nombre, pr.id_producto, pr.nombre
),
ranked AS (
    SELECT categoria, id_producto, producto, facturado,
           ROW_NUMBER() OVER (PARTITION BY categoria ORDER BY facturado DESC, id_producto ASC) AS puesto
    FROM agg
)
SELECT categoria, id_producto, producto, facturado, puesto
FROM ranked WHERE puesto <= 3
ORDER BY categoria, puesto, id_producto
WITH DATA;
CREATE UNIQUE INDEX uq_mv_top_productos_puesto
    ON mv_top_productos_categoria (categoria, id_producto);
-- Refresh fuera de transaccion:
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_productos_categoria;

-- -----------------------------------------------------------------------------
-- B. Funcion: total de un pedido (solo items vigentes)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calcular_total_pedido(p_pedido_id BIGINT)
RETURNS NUMERIC(10,2) AS $$
DECLARE v_total NUMERIC(10,2);
BEGIN
    SELECT COALESCE(SUM(subtotal), 0.00) INTO v_total
    FROM detalle_pedido
    WHERE pedido_id = p_pedido_id AND eliminado = FALSE;
    RETURN v_total;
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- C. Triggers ROW: subtotal (BEFORE) y total (AFTER ROW) - compatibilidad
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_subtotal()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.precio_unitario IS NULL THEN
        SELECT precio INTO NEW.precio_unitario FROM producto WHERE id_producto = NEW.producto_id;
    END IF;
    NEW.subtotal := NEW.cantidad * NEW.precio_unitario;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_subtotal_ins ON detalle_pedido;
CREATE TRIGGER trg_subtotal_ins BEFORE INSERT ON detalle_pedido
FOR EACH ROW EXECUTE FUNCTION fn_trg_subtotal();
DROP TRIGGER IF EXISTS trg_subtotal_upd ON detalle_pedido;
CREATE TRIGGER trg_subtotal_upd BEFORE UPDATE ON detalle_pedido
FOR EACH ROW EXECUTE FUNCTION fn_trg_subtotal();

CREATE OR REPLACE FUNCTION fn_trg_total()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        UPDATE pedido SET total = calcular_total_pedido(NEW.pedido_id) WHERE id_pedido = NEW.pedido_id;
    END IF;
    IF (TG_OP = 'DELETE' OR (TG_OP = 'UPDATE' AND OLD.pedido_id <> NEW.pedido_id)) THEN
        UPDATE pedido SET total = calcular_total_pedido(OLD.pedido_id) WHERE id_pedido = OLD.pedido_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_total_ins ON detalle_pedido;
CREATE TRIGGER trg_total_ins AFTER INSERT ON detalle_pedido FOR EACH ROW EXECUTE FUNCTION fn_trg_total();
DROP TRIGGER IF EXISTS trg_total_upd ON detalle_pedido;
CREATE TRIGGER trg_total_upd AFTER UPDATE ON detalle_pedido FOR EACH ROW EXECUTE FUNCTION fn_trg_total();
DROP TRIGGER IF EXISTS trg_total_del ON detalle_pedido;
CREATE TRIGGER trg_total_del AFTER DELETE ON detalle_pedido FOR EACH ROW EXECUTE FUNCTION fn_trg_total();

-- -----------------------------------------------------------------------------
-- D. Triggers STATEMENT con TRANSITION TABLES (exigencia parcial.md)
--    Recalculan el total una sola vez por sentencia (eficiente en bulk).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_trg_total_stmt_ins_upd()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE pedido p SET total = calcular_total_pedido(p.id_pedido)
    WHERE p.id_pedido IN (SELECT DISTINCT pedido_id FROM afectados);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_total_stmt_ins ON detalle_pedido;
CREATE TRIGGER trg_total_stmt_ins
AFTER INSERT ON detalle_pedido
REFERENCING NEW TABLE AS afectados
FOR EACH STATEMENT EXECUTE FUNCTION fn_trg_total_stmt_ins_upd();

DROP TRIGGER IF EXISTS trg_total_stmt_upd ON detalle_pedido;
CREATE TRIGGER trg_total_stmt_upd
AFTER UPDATE ON detalle_pedido
REFERENCING NEW TABLE AS afectados
FOR EACH STATEMENT EXECUTE FUNCTION fn_trg_total_stmt_ins_upd();

CREATE OR REPLACE FUNCTION fn_trg_total_stmt_del()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE pedido p SET total = calcular_total_pedido(p.id_pedido)
    WHERE p.id_pedido IN (SELECT DISTINCT pedido_id FROM eliminados);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_total_stmt_del ON detalle_pedido;
CREATE TRIGGER trg_total_stmt_del
AFTER DELETE ON detalle_pedido
REFERENCING OLD TABLE AS eliminados
FOR EACH STATEMENT EXECUTE FUNCTION fn_trg_total_stmt_del();

-- -----------------------------------------------------------------------------
-- E. Procedimiento sp_crear_pedido (CALL + JSONB + FOR UPDATE + atomicidad)
--    Ejemplo: CALL sp_crear_pedido(1, 'EFECTIVO', '[{"producto_id":1,"cantidad":2}]'::jsonb);
-- -----------------------------------------------------------------------------
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

        UPDATE producto SET stock = stock - v_cantidad WHERE id_producto = v_producto_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMIT;

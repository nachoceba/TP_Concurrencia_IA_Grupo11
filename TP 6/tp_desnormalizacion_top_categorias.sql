-- =============================================================================
-- TP Unidad 4 - Parte 2: Desnormalizacion controlada (top 5 categorias/dia)
-- Food Store | PostgreSQL 16+
--
-- Resuelve los puntos 5.2 a) a e) del enunciado contra el esquema REAL del
-- proyecto (parcial_BD/01_schema.sql): categoria.id_categoria,
-- producto.id_producto/categoria_id, pedido.id_pedido/usuario_id/fecha
-- (TIMESTAMPTZ), detalle_pedido.id_detalle_pedido/pedido_id/producto_id/
-- subtotal/eliminado.
--
-- Como correr este archivo: por bloques, no de punta a punta, porque entre
-- el "antes" y el "despues" hay que ejecutar EXPLAIN ANALYZE a mano y
-- guardar el resultado (ver Informe_TP_Unidad_4.md).
-- =============================================================================


-- =============================================================================
-- a) Consulta base (la que usa hoy el panel) + EXPLAIN ANALYZE "antes"
-- =============================================================================
-- Ejecutar esto tal cual sobre una base ya poblada (parcial_BD/02_data_demo.sql
-- o 03_data_masivo.sql) y guardar la salida completa para el informe.
--
-- Nota sobre la fecha: en el enunciado original la columna fecha es DATE y
-- se compara con "= CURRENT_DATE". En este proyecto pedido.fecha es
-- TIMESTAMPTZ (tiene hora), asi que comparamos por rango de todo el dia de
-- hoy en vez de con "=", que es la forma simple y correcta de filtrar "hoy"
-- sobre una columna con hora.

EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre AS categoria,
       SUM(dp.subtotal) AS total_vendido
FROM detalle_pedido dp
JOIN producto  pr  ON pr.id_producto  = dp.producto_id
JOIN categoria c   ON c.id_categoria  = pr.categoria_id
JOIN pedido    ped ON ped.id_pedido   = dp.pedido_id
WHERE ped.fecha >= CURRENT_DATE
  AND ped.fecha <  CURRENT_DATE + INTERVAL '1 day'
  AND dp.eliminado  = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;

-- [PEGAR ACA la salida completa de este EXPLAIN ANALYZE -> va al informe]


-- =============================================================================
-- b) Patron de desnormalizacion elegido: tabla resumen + trigger
-- =============================================================================
-- Se elige una TABLA RESUMEN mantenida por TRIGGER (en vez de una vista
-- materializada) porque el panel necesita el dato "en tiempo real, con
-- actualizacion frecuente" (consigna 5.1). Una vista materializada solo se
-- actualiza cuando alguien corre REFRESH; un trigger la actualiza sola, en
-- la misma transaccion que crea el pedido. La justificacion completa (las
-- 3 preguntas de 5.2.b) va en el informe; esto es solo la implementacion.


-- =============================================================================
-- c) Implementacion: estructura desnormalizada + mecanismo de sincronizacion
-- =============================================================================
BEGIN;

-- Tabla resumen: un total acumulado por categoria y por dia.
CREATE TABLE IF NOT EXISTS resumen_venta_categoria_dia (
    categoria_id   BIGINT        NOT NULL REFERENCES categoria(id_categoria),
    fecha          DATE          NOT NULL,
    total_vendido  NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total_vendido >= 0),
    PRIMARY KEY (categoria_id, fecha)
);

COMMENT ON TABLE resumen_venta_categoria_dia IS
    'Desnormalizacion controlada: total vendido por categoria y dia, '
    'mantenido por trigger desde detalle_pedido. Fuente de verdad real: '
    'SUM(detalle_pedido.subtotal) via JOIN con producto/categoria/pedido.';

-- Funcion de sincronizacion: ante un INSERT o UPDATE en detalle_pedido,
-- recalcula el total del dia para la categoria afectada y lo guarda (o lo
-- actualiza) en la tabla resumen. Se recalcula con un SELECT SUM(...) en
-- vez de sumar/restar a mano, el mismo estilo que ya usa el proyecto en
-- parcial_BD/04_objects.sql (trg_total_ins_fn) para mantener pedido.total:
-- es mas simple de entender y evita errores de "doble resta" si el trigger
-- se dispara varias veces.
CREATE OR REPLACE FUNCTION fn_trg_resumen_venta_categoria_dia()
RETURNS TRIGGER AS $$
DECLARE
    v_categoria_id BIGINT;
    v_fecha        DATE;
    v_total        NUMERIC(12,2);
BEGIN
    -- Categoria del producto y fecha (solo el dia) del pedido afectados
    SELECT pr.categoria_id, ped.fecha::date
      INTO v_categoria_id, v_fecha
    FROM producto pr
    JOIN pedido ped ON ped.id_pedido = NEW.pedido_id
    WHERE pr.id_producto = NEW.producto_id;

    -- Recalculo del total real para esa categoria y ese dia
    SELECT COALESCE(SUM(dp.subtotal), 0)
      INTO v_total
    FROM detalle_pedido dp
    JOIN producto pr  ON pr.id_producto = dp.producto_id
    JOIN pedido   ped ON ped.id_pedido  = dp.pedido_id
    WHERE pr.categoria_id = v_categoria_id
      AND ped.fecha::date = v_fecha
      AND dp.eliminado  = FALSE
      AND ped.eliminado = FALSE;

    INSERT INTO resumen_venta_categoria_dia (categoria_id, fecha, total_vendido)
    VALUES (v_categoria_id, v_fecha, v_total)
    ON CONFLICT (categoria_id, fecha)
    DO UPDATE SET total_vendido = EXCLUDED.total_vendido;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_resumen_venta_categoria_dia
AFTER INSERT OR UPDATE ON detalle_pedido
FOR EACH ROW
EXECUTE FUNCTION fn_trg_resumen_venta_categoria_dia();

-- Limite conocido de este trigger (declarado a proposito, no es un bug
-- escondido): reacciona a cambios en detalle_pedido, pero NO a que se
-- cancele el pedido entero (UPDATE pedido SET eliminado = TRUE). Para
-- detectar justamente ese caso esta el script de auditoria del punto e).

COMMIT;

-- Backfill: calcular el resumen para los datos que ya existian ANTES de
-- crear el trigger (el trigger solo corre para cambios nuevos).
INSERT INTO resumen_venta_categoria_dia (categoria_id, fecha, total_vendido)
SELECT pr.categoria_id,
       ped.fecha::date,
       SUM(dp.subtotal)
FROM detalle_pedido dp
JOIN producto pr  ON pr.id_producto = dp.producto_id
JOIN pedido   ped ON ped.id_pedido  = dp.pedido_id
WHERE dp.eliminado  = FALSE
  AND ped.eliminado = FALSE
GROUP BY pr.categoria_id, ped.fecha::date
ON CONFLICT (categoria_id, fecha)
DO UPDATE SET total_vendido = EXCLUDED.total_vendido;


-- =============================================================================
-- d) Consulta equivalente leyendo de la estructura desnormalizada + EXPLAIN "despues"
-- =============================================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre AS categoria,
       r.total_vendido
FROM resumen_venta_categoria_dia r
JOIN categoria c ON c.id_categoria = r.categoria_id
WHERE r.fecha = CURRENT_DATE
ORDER BY r.total_vendido DESC
LIMIT 5;

-- [PEGAR ACA la salida completa de este EXPLAIN ANALYZE -> va al informe,
--  junto con la de a), en la tabla antes/despues]


-- =============================================================================
-- e) Script de auditoria: el dato redundante, ¿se desincronizo?
-- =============================================================================
-- Compara, para el dia de hoy, el total guardado en la tabla resumen contra
-- el total recalculado desde las tablas originales. Si todo esta
-- sincronizado, no devuelve ninguna fila.
SELECT
    r.categoria_id,
    r.fecha,
    r.total_vendido      AS total_guardado,
    real.total_real
FROM resumen_venta_categoria_dia r
JOIN (
    SELECT pr.categoria_id,
           ped.fecha::date AS fecha,
           SUM(dp.subtotal) AS total_real
    FROM detalle_pedido dp
    JOIN producto pr  ON pr.id_producto = dp.producto_id
    JOIN pedido   ped ON ped.id_pedido  = dp.pedido_id
    WHERE dp.eliminado  = FALSE
      AND ped.eliminado = FALSE
    GROUP BY pr.categoria_id, ped.fecha::date
) real
  ON real.categoria_id = r.categoria_id
 AND real.fecha        = r.fecha
WHERE r.fecha = CURRENT_DATE
  AND r.total_vendido <> real.total_real;

-- Resultado esperado: 0 filas (si da filas, el trigger no alcanzo a
-- actualizar ese caso -- por ejemplo, un pedido cancelado luego de cargado
-- -- y hay que correr de nuevo el backfill del punto c).

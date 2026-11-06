-- =============================================================================
-- TP Unidad 7 · Food Store · Consultas equivalentes en PostgreSQL (Consigna 5)
-- Grupo 11 · Bases de Datos II
-- Base: parcial_BD/01_schema.sql -> 04_objects.sql -> 02_data_demo.sql
-- Sólo lectura (SELECT): no modifica datos, no requiere BEGIN/ROLLBACK.
-- Ejecución:  psql -d foodstore -X -f consultas_postgresql.sql
--
-- Subconjunto migrado: pedidos 1..7 (los del seed demo). Si en la base se
-- corrió 06_transacciones.sql existen pedidos de prueba (8, 10, ...) que NO se
-- migraron; por eso cada consulta se limita a id_pedido <= 7 para comparar
-- el mismo universo de datos en ambos motores.
-- =============================================================================

-- 0) Origen de la migración: arma desde PostgreSQL el mismo documento que se
--    insertó en MongoDB (un JSON por pedido con cliente y líneas embebidas).
SELECT jsonb_pretty(jsonb_build_object(
         'id_pedido', p.id_pedido,
         'fecha', p.fecha,
         'estado', p.estado,
         'forma_pago', p.forma_pago,
         'total', p.total,
         'cliente', jsonb_build_object('id_usuario', u.id_usuario,
                                       'nombre', u.nombre, 'apellido', u.apellido),
         'lineas', (SELECT jsonb_agg(jsonb_build_object(
                        'id_detalle_pedido', d.id_detalle_pedido,
                        'producto', jsonb_build_object(
                            'id_producto', pr.id_producto, 'nombre', pr.nombre,
                            'categoria', jsonb_build_object('id_categoria', c.id_categoria,
                                                            'nombre', c.nombre)),
                        'cantidad', d.cantidad,
                        'precio_unitario', d.precio_unitario,
                        'subtotal', d.subtotal) ORDER BY d.id_detalle_pedido)
                    FROM detalle_pedido d
                    JOIN producto  pr ON pr.id_producto  = d.producto_id
                    JOIN categoria c  ON c.id_categoria  = pr.categoria_id
                    WHERE d.pedido_id = p.id_pedido AND d.eliminado = FALSE)
       )) AS documento
FROM pedido p
JOIN usuario u ON u.id_usuario = p.usuario_id
WHERE p.id_pedido = 1;   -- quitar el filtro para exportar los 7

-- Conteo de control (MongoDB debe dar 7 pedidos y 16 líneas)
SELECT (SELECT count(*) FROM pedido WHERE id_pedido <= 7)          AS pedidos,
       (SELECT count(*) FROM detalle_pedido WHERE pedido_id <= 7)  AS lineas;

-- a) Todos los pedidos con su identificador y estado
SELECT id_pedido, fecha, estado, total
FROM pedido
WHERE id_pedido <= 7
ORDER BY id_pedido;

-- b) Pedidos en estado TERMINADO (equivalente a la consulta b de MongoDB)
SELECT id_pedido, fecha, estado, total
FROM pedido
WHERE estado = 'TERMINADO'
  AND eliminado = FALSE
  AND id_pedido <= 7
ORDER BY id_pedido;

SELECT count(*) AS cantidad_b,
       string_agg(id_pedido::text, ', ' ORDER BY id_pedido) AS ids_b
FROM pedido
WHERE estado = 'TERMINADO' AND eliminado = FALSE AND id_pedido <= 7;

-- c) Pedidos que contienen el producto 11 (Coca-Cola Original 1.5L)
--    En el modelo relacional hace falta el JOIN con detalle_pedido;
--    en MongoDB la línea está embebida en el documento.
SELECT p.id_pedido, p.estado, d.id_detalle_pedido, pr.nombre,
       d.cantidad, d.precio_unitario, d.subtotal
FROM pedido p
JOIN detalle_pedido d ON d.pedido_id = p.id_pedido
JOIN producto pr      ON pr.id_producto = d.producto_id
WHERE d.producto_id = 11
  AND p.eliminado = FALSE
  AND d.eliminado = FALSE
  AND p.id_pedido <= 7
ORDER BY p.id_pedido;

SELECT count(DISTINCT p.id_pedido) AS cantidad_c,
       string_agg(DISTINCT p.id_pedido::text, ', ') AS ids_c
FROM pedido p
JOIN detalle_pedido d ON d.pedido_id = p.id_pedido
WHERE d.producto_id = 11
  AND p.eliminado = FALSE AND d.eliminado = FALSE AND p.id_pedido <= 7;

-- d) Pedidos con total > 14000 (umbral = ticket promedio redondeado)
SELECT round(avg(total), 2) AS ticket_promedio FROM pedido WHERE id_pedido <= 7;

SELECT id_pedido, fecha, estado, total
FROM pedido
WHERE total > 14000 AND id_pedido <= 7
ORDER BY total DESC;

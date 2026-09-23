-- =============================================================================
-- Food Store - Carga MASIVA sintetica (03_data_masivo.sql) - ALTERNATIVA a demo
-- NO ACUMULABLE con 02_data_demo.sql: ejecutar sobre base vacia post
-- 01_schema.sql + 04_objects.sql, o hacer TRUNCATE antes.
-- Volumen: 12 categorias / 50.000 productos / 20.000 usuarios /
--          200.000 pedidos / ~500-600k detalles.
-- Set-Based exclusivo (generate_series, sin LOOP). Transaccional BEGIN/COMMIT.
-- Compatible con IDENTITY: no inserta ids, deja que la secuencia los genere.
-- Compatible con TIMESTAMPTZ: CURRENT_DATE - N castea implicito.
-- Compatible con trigger ck_detalle_subtotal: subtotal = cantidad*precio.
-- Secuencias IDENTITY: se sincronizan con pg_get_serial_sequence + setval.
-- =============================================================================

BEGIN;

SET LOCAL synchronous_commit TO OFF;
SET LOCAL statement_timeout TO 0;
SET LOCAL lock_timeout TO 0;

-- 1. CATEGORIAS ----------------------------------------------------------------
INSERT INTO categoria (nombre, descripcion, eliminado) VALUES
 ('Hamburguesas', 'Hamburguesas gourmet, clasicas y dobles', FALSE),
 ('Pizzas', 'Pizzas a la piedra y al molde', FALSE),
 ('Empanadas', 'Empanadas fritas y al horno', FALSE),
 ('Bebidas', 'Gaseosas, aguas, cervezas y jugos', FALSE),
 ('Postres', 'Helados, tortas y dulces', FALSE),
 ('Papas Fritas', 'Papas fritas y papas rusticas', FALSE),
 ('Combos', 'Combos familiares y promociones', FALSE),
 ('Milanesas', 'Milanesas de carne, pollo y vegetarianas', FALSE),
 ('Pastas', 'Pastas caseras y salsas', FALSE),
 ('Ensaladas', 'Ensaladas frescas y bowls', FALSE),
 ('Sandwiches', 'Sandwiches y lomitos', FALSE),
 ('Helados', 'Helados artesanales por kilo y vasito', FALSE);

-- 2. PRODUCTOS (50.000) ---------------------------------------------------------
INSERT INTO producto (nombre, precio, descripcion, stock, imagen, disponible, categoria_id, eliminado)
SELECT
    b.bases[1 + floor(random()*array_length(b.bases,1))::int]
    || ' ' ||
    v.variantes[1 + floor(random()*array_length(v.variantes,1))::int]
    || ' #' || gs AS nombre,
    round((1500 + random()*33500)::numeric, 2) AS precio,
    'Producto Food Store' AS descripcion,
    s.stock AS stock,
    'img/producto_' || gs || '.jpg' AS imagen,
    CASE WHEN s.stock = 0 THEN FALSE ELSE (random() < 0.90) END AS disponible,
    1 + (gs % 12) AS categoria_id,
    FALSE AS eliminado
FROM generate_series(1, 50000) AS gs
CROSS JOIN (SELECT ARRAY['Hamburguesa','Pizza','Empanada','Milanesa','Lomito','Papas','Ensalada','Pasta','Sandwich','Taco','Bebida','Postre','Combo','Wrap','Panchito','Arepa']::text[] AS bases) AS b
CROSS JOIN (SELECT ARRAY['Clasica','Especial','Doble','Picante','Veggie','Premium','XL','BBQ','Napolitana','Crispy','Gourmet','Familiar']::text[] AS variantes) AS v
CROSS JOIN LATERAL (SELECT floor(random()*501)::int AS stock) AS s;

-- 3. USUARIOS (20.000) ----------------------------------------------------------
INSERT INTO usuario (nombre, apellido, mail, celular, contrasena, rol, eliminado)
SELECT
    n.nombres[1 + floor(random()*array_length(n.nombres,1))::int],
    a.apellidos[1 + floor(random()*array_length(a.apellidos,1))::int],
    'cliente_' || gs || '@foodstore.com',
    '11' || lpad((30000000 + floor(random()*7000000)::int)::text, 8, '0'),
    '$2b$12$' || substr(md5(random()::text), 1, 53),
    CASE WHEN random() < 0.05 THEN 'ADMIN'::rol_usuario ELSE 'USUARIO'::rol_usuario END,
    FALSE
FROM generate_series(1, 20000) AS gs
CROSS JOIN (SELECT ARRAY['Juan','Maria','Pedro','Lucia','Santiago','Valentina','Matias','Sofia','Nicolas','Florencia']::text[] AS nombres) AS n
CROSS JOIN (SELECT ARRAY['Gonzalez','Perez','Rodriguez','Garcia','Lopez','Martinez','Fernandez','Gomez','Diaz','Torres']::text[] AS apellidos) AS a;

-- 4. PEDIDOS (200.000) -----------------------------------------------------------
INSERT INTO pedido (fecha, estado, total, forma_pago, metadatos, usuario_id, eliminado)
SELECT
    (CURRENT_DATE - (floor(random()*730)::int)),
    (ARRAY['PENDIENTE','CONFIRMADO','TERMINADO','CANCELADO']::estado_pedido[])[1 + floor(random()*4)::int],
    0::numeric(10,2),
    (ARRAY['EFECTIVO','TARJETA','TRANSFERENCIA']::forma_pago[])[1 + floor(random()*3)::int],
    '{}'::jsonb,
    1 + floor(random()*20000)::int,
    FALSE
FROM generate_series(1, 200000) AS gs;

-- 5. DETALLES (1-4 por pedido) ----------------------------------------------------
-- Si los triggers statement-level existen, el recalculo por UPDATE final es
-- redundante pero inocuo y garantiza consistencia.
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
SELECT
    p.id_pedido, prod.id_producto, det.cantidad, prod.precio,
    (det.cantidad * prod.precio)
FROM pedido p
CROSS JOIN LATERAL (SELECT 1 + floor(random()*4)::int AS n_items) cnt
CROSS JOIN LATERAL generate_series(1, cnt.n_items) AS g(item_n)
CROSS JOIN LATERAL (SELECT 1 + floor(random()*5)::int AS cantidad, 1 + floor(random()*50000)::int AS prod_id) det
JOIN producto prod ON prod.id_producto = det.prod_id;

-- 6. Recalculo de totales (idempotente) -------------------------------------------
UPDATE pedido p SET total = agg.s
FROM (SELECT pedido_id, SUM(subtotal)::numeric(10,2) AS s FROM detalle_pedido WHERE eliminado = FALSE GROUP BY pedido_id) agg
WHERE p.id_pedido = agg.pedido_id;

-- 7. Sincronizacion de secuencias IDENTITY ----------------------------------------
SELECT setval(pg_get_serial_sequence('categoria','id_categoria'), COALESCE((SELECT MAX(id_categoria) FROM categoria), 1), true);
SELECT setval(pg_get_serial_sequence('producto','id_producto'), COALESCE((SELECT MAX(id_producto) FROM producto), 1), true);
SELECT setval(pg_get_serial_sequence('usuario','id_usuario'), COALESCE((SELECT MAX(id_usuario) FROM usuario), 1), true);
SELECT setval(pg_get_serial_sequence('pedido','id_pedido'), COALESCE((SELECT MAX(id_pedido) FROM pedido), 1), true);
SELECT setval(pg_get_serial_sequence('detalle_pedido','id_detalle_pedido'), COALESCE((SELECT MAX(id_detalle_pedido) FROM detalle_pedido), 1), true);

COMMIT;

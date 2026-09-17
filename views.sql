-- =============================================================================
-- TP2 Concurrencia IA Grupo 11 - Vistas de negocio (views.sql)
-- Motor: PostgreSQL 18.6 | Base: clon de TP2_Concurrencia_IA_Grupo11
--
-- PROTOCOLO DE SEGURIDAD (protocolo_seguridad.md) - OBLIGATORIO:
--   Paso 1 (Clon, nunca sobre la principal):
--     dropdb -U postgres TP2_Concurrencia_IA_Grupo11_clon --if-exists;
--     createdb -U postgres -T TP2_Concurrencia_IA_Grupo11 TP2_Concurrencia_IA_Grupo11_clon;
--     psql -U postgres -d TP2_Concurrencia_IA_Grupo11_clon -f views.sql
--   Paso 2 (Transaccion: probar con ROLLBACK antes del COMMIT definitivo):
--     BEGIN; \i views.sql  -- inspeccionar mensajes, luego ROLLBACK o COMMIT
--   Paso 3 (Respaldo antes de aplicar):
--     pg_dump -U postgres -Fc TP2_Concurrencia_IA_Grupo11_clon > backup_pre_views.dump
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. v_pedidos_resumen
--    Resumen de pedidos vigentes con datos del cliente.
--    Resuelve HU-PED-01 de queries.sql ("SELECT id, usuario, fecha, estado,
--    forma_pago, total FROM v_pedidos_resumen"), que hoy falla al no existir.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_pedidos_resumen AS
SELECT p.id_pedido,
       u.nombre || ' ' || u.apellido AS usuario,
       p.fecha,
       p.estado,
       p.forma_pago,
       p.total
FROM   pedido p
JOIN   usuario u ON u.id_usuario = p.usuario_id
WHERE  p.eliminado = FALSE
  AND  u.eliminado = FALSE;

-- -----------------------------------------------------------------------------
-- 2. v_catalogo_productos
--    Catalogo vigente para el frontend (localhost:8080): productos vigentes y
--    disponibles con el nombre de su categoria.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_catalogo_productos AS
SELECT pr.id_producto,
       pr.nombre,
       pr.precio,
       pr.stock,
       pr.disponible,
       c.nombre AS categoria
FROM   producto pr
JOIN   categoria c ON c.id_categoria = pr.categoria_id
WHERE  pr.eliminado = FALSE
  AND  c.eliminado = FALSE;

-- -----------------------------------------------------------------------------
-- 3. v_usuarios_segura
--    Vista de SEGURIDAD sobre usuario: expone todas las columnas EXCEPTO
--    contrasena y solo los usuarios vigentes (eliminado = FALSE).
--    Permite otorgar SELECT sin dar acceso a la tabla base:
--       GRANT SELECT ON v_usuarios_segura TO aplicacion_lectura;
--    (sin ningun privilegio sobre la tabla usuario)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_usuarios_segura AS
SELECT id_usuario,
       nombre,
       apellido,
       mail,
       celular,
       rol
FROM   usuario
WHERE  eliminado = FALSE;

-- -----------------------------------------------------------------------------
-- 4. mv_top_productos_categoria (VISTA MATERIALIZADA)
--    Ranking Top-3 de productos por facturacion acumulada dentro de cada
--    categoria (TP4, Parte 3). Se materializa para no recalcular la agregacion
--    en cada consulta; el build usa la version equivalente con ROW_NUMBER()
--    (mismo resultado que la version correlacionada, verificada por EXCEPT).
--    WITH DATA: llena la vista inmediatamente al crearla.
--    El indice UNICO (categoria, id_producto) es requisito para poder usar
--    REFRESH MATERIALIZED VIEW CONCURRENTLY a futuro (cada producto pertenece
--    a una unica categoria, por lo que la clave es unica por fila).
--    Alternativa equivalente pero O(n^2) (no recomendada para el build):
--    la variante con subconsulta correlacionada de TP4 Parte 3.
-- -----------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS mv_top_productos_categoria;

CREATE MATERIALIZED VIEW mv_top_productos_categoria AS
WITH agg AS (
    SELECT c.nombre        AS categoria,
           pr.id_producto,
           pr.nombre        AS producto,
           SUM(dp.subtotal) AS facturado
    FROM   detalle_pedido dp
    JOIN   producto pr  ON pr.id_producto  = dp.producto_id
    JOIN   categoria c  ON c.id_categoria = pr.categoria_id
    WHERE  pr.eliminado = FALSE
      AND  c.eliminado = FALSE
    GROUP  BY c.nombre, pr.id_producto, pr.nombre
),
ranked AS (
    SELECT categoria, id_producto, producto, facturado,
           ROW_NUMBER() OVER (
               PARTITION BY categoria
               ORDER BY facturado DESC, id_producto ASC
           ) AS puesto
    FROM agg
)
SELECT categoria, id_producto, producto, facturado, puesto
FROM   ranked
WHERE  puesto <= 3
ORDER  BY categoria ASC, puesto ASC, id_producto ASC
WITH DATA;

CREATE UNIQUE INDEX uq_mv_top_productos_puesto
    ON mv_top_productos_categoria (categoria, id_producto);

COMMIT;

-- -----------------------------------------------------------------------------
-- Actualizacion (FUERA de transaccion, requiere el indice UNICO).
--
-- Frecuencia recomendada: 1 vez por dia, a las 03:00 (fuera del pico de
-- escritura). El reporte es un KPI de facturacion ACUMULADA de gestion, no
-- operativo en tiempo real; una ventana de datos diaria es suficiente.
--
-- CONCURRENTLY no toma AccessExclusiveLock: los usuarios pueden seguir
-- consultando el MV mientras se refresca. No puede correr dentro de una
-- transaccion; lanzar como sentencia suelta.
--
--   REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_productos_categoria;
--
-- Programacion diaria con pg_cron:
--   SELECT cron.schedule(
--       'refresh-top3',
--       '0 3 * * *',
--       'REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_productos_categoria;'
--   );
-- (Alternativa sin pg_cron: Task Scheduler de Windows o un job de la app.)
--
-- Impacto para el usuario: el dato puede quedar hasta ~24 h desactualizado
-- (muestra el ultimo refresh). Mitigacion: exponer "Datos al <fecha>", p.ej.
-- agregando now() AS refreshed_at a la definicion del MV.
-- -----------------------------------------------------------------------------
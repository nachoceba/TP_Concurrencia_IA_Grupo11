WITH totales_por_usuario AS (
    SELECT 
        u.id_usuario,
        u.nombre || ' ' || u.apellido AS cliente_nombre,
        u.mail,
        SUM(p.total) AS total_gastado
    FROM usuario u
    JOIN pedido p ON p.usuario_id = u.id_usuario
    WHERE u.eliminado = FALSE
      AND p.eliminado = FALSE
      AND p.estado = 'TERMINADO'
    GROUP BY u.id_usuario, u.nombre, u.apellido, u.mail
),
promedio_global AS (
    SELECT AVG(total_gastado) AS promedio FROM totales_por_usuario
)
SELECT 
    t.id_usuario,
    t.cliente_nombre,
    t.mail,
    t.total_gastado
FROM totales_por_usuario t
CROSS JOIN promedio_global pg
WHERE t.total_gastado > pg.promedio
ORDER BY t.total_gastado DESC
LIMIT 20;
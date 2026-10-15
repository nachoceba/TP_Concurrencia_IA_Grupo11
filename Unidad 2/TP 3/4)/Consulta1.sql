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
HAVING SUM(p.total) > (
    SELECT AVG(total_usuario)
    FROM (
        SELECT SUM(p_sub.total) AS total_usuario
        FROM pedido p_sub
        JOIN usuario u_sub ON u_sub.id_usuario = p_sub.usuario_id
        WHERE p_sub.eliminado = FALSE
          AND u_sub.eliminado = FALSE
          AND p_sub.estado = 'TERMINADO'
        GROUP BY p_sub.usuario_id
    ) sub
)
ORDER BY total_gastado DESC
LIMIT 20;
-- TP6 Parte D — Vista anonimizada usuario_anon (fuente para IA)
-- Uso: fuente SEGURA para análisis con IA. Nunca exponer tabla usuario real.
-- Criterio determinista 1:1 por id (mismo que TP6/docs/log_simulacro_anonimizado.txt):
--   nombre real    -> 'Anon-' || id_usuario
--   apellido real  -> 'Usuario-' || id_usuario
--   mail real      -> 'anon-user-' || LPAD(id::text,3,'0') || '@ejemplo.edu'
--   celular real   -> '+54-000-' || LPAD(id::text,4,'0')
--   contrasena     -> NULL (nunca exponer hash, ni siquiera hasheado)
-- Se conservan sin transformar para equivalencia: id_usuario, rol, fecha_alta, eliminado.
-- Requiere: tabla usuario(id_usuario, nombre, apellido, mail, celular, contrasena, rol, fecha_alta, eliminado)
--   y roles rol_reportes, rol_auditor (ver TP6/sql/roles.sql Parte A).
-- Ejecutar (con credencial, DB clon): psql -d tp6_u5_work -f TP6/sql/usuario_anon.sql

CREATE OR REPLACE VIEW usuario_anon AS
SELECT
    u.id_usuario,
    ('Anon-' || u.id_usuario) AS nombre,
    ('Usuario-' || u.id_usuario) AS apellido,
    ('anon-user-' || LPAD(u.id_usuario::text, 3, '0') || '@ejemplo.edu') AS mail,
    ('+54-000-' || LPAD(u.id_usuario::text, 4, '0')) AS celular,
    NULL::VARCHAR(255) AS contrasena,
    u.rol,
    u.fecha_alta,
    u.eliminado
FROM usuario AS u;

COMMENT ON VIEW usuario_anon IS 'Fuente para IA (TP6-D): PII sintética determinista por id; contrasena siempre NULL; conserva rol/fecha_alta/eliminado para equivalencia 1:1 con usuario.';

GRANT SELECT ON usuario_anon TO rol_reportes, rol_auditor;

-- Q_ANON (agregación sobre vista anonimizada — apta para IA):
-- SELECT rol, date_trunc('month', fecha_alta) AS mes, COUNT(*)
-- FROM usuario_anon WHERE eliminado = FALSE GROUP BY 1, 2 ORDER BY 1, 2;

-- Q_REAL (equivalente sobre tabla real — solo humano con privilegio, nunca a IA):
-- SELECT rol, date_trunc('month', fecha_alta) AS mes, COUNT(*)
-- FROM usuario WHERE eliminado = FALSE GROUP BY 1, 2 ORDER BY 1, 2;

-- Nota: resultados esperados idénticos por construcción determinista 1:1
-- (misma fila por id_usuario, mismo rol/fecha_alta/eliminado; solo cambian PII).

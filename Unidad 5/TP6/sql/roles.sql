-- =============================================================================
-- TP6 Parte A — Roles y privilegios mínimos (food_store)
-- Base canónica: parcial_BD/04_objects.sql (vistas A1-A7, función
--   calcular_total_pedido(BIGINT), procedimiento sp_crear_pedido(BIGINT,
--   forma_pago, JSONB), MV mv_top_productos_categoria)
-- Protocolo: protocolo_seguridad.md (probar en copia de trabajo con
--   BEGIN + ROLLBACK antes de COMMIT; pg_dump antes de cambios estructurales;
--   NUNCA ejecutar en la base principal sin clon previo)
-- Corrige a roles.sql previo: v_usuarios_publico -> v_usuarios_segura,
--   mv_ventas_categoria_mes -> mv_top_productos_categoria.
-- Idempotencia: grupos creados con DO $$ IF NOT EXISTS ... $$; re-ejecutar
--   este script no duplica roles (los GRANT son re-ejecutables).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Bloque 0. Hardening del esquema public y la base
-- NOTA: base de trabajo tp6_u5_work (antes food_store_parcial).
-- Ajustar al nombre real si difiere.
-- -----------------------------------------------------------------------------
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE tp6_u5_work FROM PUBLIC; -- Ajustar al nombre real si difiere

-- -----------------------------------------------------------------------------
-- Bloque 1. Grupos NOLOGIN (5): creación idempotente
-- -----------------------------------------------------------------------------
DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'rol_app_lectura') THEN CREATE ROLE rol_app_lectura WITH NOLOGIN; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'rol_app_escritura') THEN CREATE ROLE rol_app_escritura WITH NOLOGIN; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'rol_soporte') THEN CREATE ROLE rol_soporte WITH NOLOGIN; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'rol_reportes') THEN CREATE ROLE rol_reportes WITH NOLOGIN; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'rol_auditor') THEN CREATE ROLE rol_auditor WITH NOLOGIN; END IF; END $$;
-- Mínimo exigido (equivalente simple si se prefiere sin DO):
-- CREATE ROLE rol_app_lectura WITH NOLOGIN;
-- CREATE ROLE rol_app_escritura WITH NOLOGIN;
-- CREATE ROLE rol_soporte WITH NOLOGIN;
-- CREATE ROLE rol_reportes WITH NOLOGIN;
-- CREATE ROLE rol_auditor WITH NOLOGIN;

-- -----------------------------------------------------------------------------
-- Bloque 2. Herencia: escritura hereda lectura (no duplicar SELECT)
-- -----------------------------------------------------------------------------
GRANT rol_app_lectura TO rol_app_escritura;

-- -----------------------------------------------------------------------------
-- Bloque 3. Base: CONNECT + USAGE esquema + USAGE tipos ENUM
-- -----------------------------------------------------------------------------
GRANT CONNECT ON DATABASE tp6_u5_work TO rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes, rol_auditor; -- Ajustar al nombre real si difiere
GRANT USAGE ON SCHEMA public TO rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes, rol_auditor;
-- Los ENUM se usan en pedido (estado_pedido, forma_pago) y usuario (rol_usuario);
-- solo se da USAGE a los roles que leen/escriben esas columnas vía vistas/procedimiento.
GRANT USAGE ON TYPE rol_usuario, estado_pedido, forma_pago TO rol_app_lectura, rol_app_escritura, rol_soporte;
-- Reportes y auditor leen enums vía vistas (v_pedidos_resumen, v_usuarios_segura).
GRANT USAGE ON TYPE rol_usuario, estado_pedido, forma_pago TO rol_reportes, rol_auditor;

-- -----------------------------------------------------------------------------
-- Bloque 4. Lectura app: SELECT sobre vistas + MV (corrige nombres viejos)
-- NOTA: v_usuarios_publico (nombre viejo en roles.sql) -> v_usuarios_segura;
--   mv_ventas_categoria_mes (nombre viejo) -> mv_top_productos_categoria.
-- -----------------------------------------------------------------------------
GRANT SELECT ON v_categorias_vigentes, v_productos_vigentes, v_pedidos_resumen, v_pedido_detalle, v_catalogo_productos, v_usuarios_segura, mv_top_productos_categoria TO rol_app_lectura;

-- -----------------------------------------------------------------------------
-- Bloque 5. Columna-level exigido: soporte ve usuario sin contrasena
-- -----------------------------------------------------------------------------
REVOKE ALL ON usuario FROM PUBLIC;
GRANT SELECT (id_usuario, nombre, apellido, mail, celular, rol) ON usuario TO rol_soporte;
-- Sin contrasena: la columna contrasena queda excluida a propósito.
-- Diseño intencional: eliminado también queda excluido (sin privilegio SELECT para
-- rol_soporte); por eso el simulacro (simulacro_incidente.sql Bloque 4) no filtra
-- por eliminado y hace lectura masiva sin WHERE. No agregar grants aquí.

-- -----------------------------------------------------------------------------
-- Bloque 6. Escritura mínima: solo vía procedimiento + función de cálculo
-- Mínimo privilegio: SIN INSERT/UPDATE/DELETE directo en pedido/detalle_pedido;
-- toda alta de pedido pasa por sp_crear_pedido.
-- -----------------------------------------------------------------------------
REVOKE ALL ON PROCEDURE sp_crear_pedido(BIGINT, forma_pago, JSONB) FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE sp_crear_pedido(BIGINT, forma_pago, JSONB) TO rol_app_escritura;
REVOKE ALL ON FUNCTION calcular_total_pedido(BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION calcular_total_pedido(BIGINT) TO rol_soporte, rol_auditor;

-- -----------------------------------------------------------------------------
-- Bloque 7. Soporte: lectura operativa de pedidos + usuarios seguros + detalle
-- -----------------------------------------------------------------------------
GRANT SELECT ON v_pedidos_resumen, v_usuarios_segura, v_pedido_detalle TO rol_soporte;

-- -----------------------------------------------------------------------------
-- Bloque 8. Reportes: solo lectura analítica (MV + resumen)
-- -----------------------------------------------------------------------------
GRANT SELECT ON mv_top_productos_categoria, v_pedidos_resumen TO rol_reportes;

-- -----------------------------------------------------------------------------
-- Bloque 9. Auditor: lectura de control (resumen + usuarios + MV)
-- -----------------------------------------------------------------------------
GRANT SELECT ON v_pedidos_resumen, v_usuarios_segura, mv_top_productos_categoria TO rol_auditor;

-- -----------------------------------------------------------------------------
-- Bloque 10. Futuro: privilegios por defecto para objetos nuevos (owner de carga)
-- Alinear FOR ROLE con el owner real de carga (CURRENT_USER por defecto).
-- -----------------------------------------------------------------------------
ALTER DEFAULT PRIVILEGES FOR ROLE CURRENT_USER IN SCHEMA public GRANT SELECT ON TABLES TO rol_app_lectura, rol_soporte, rol_reportes, rol_auditor;
ALTER DEFAULT PRIVILEGES FOR ROLE CURRENT_USER IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO rol_app_escritura;

-- -----------------------------------------------------------------------------
-- Bloque 11. Logins + membresías + search_path
-- Passwords: NO van en el repo. Setear fuera con \password app_web,
-- \password admin_datos o variable de entorno (p. ej. PGPASSWORD).
-- -----------------------------------------------------------------------------
DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_web') THEN CREATE ROLE app_web WITH LOGIN CONNECTION LIMIT 20; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'admin_datos') THEN CREATE ROLE admin_datos WITH LOGIN CONNECTION LIMIT 5; END IF; END $$;
GRANT rol_app_escritura TO app_web;
GRANT rol_auditor TO admin_datos;
ALTER ROLE app_web SET search_path = public, pg_temp;
ALTER ROLE admin_datos SET search_path = public, pg_temp;

-- -----------------------------------------------------------------------------
-- Bloque 12. Verificación comentada (solo contra BD clon; no usar has_table_privilege:
-- devuelve TRUE con grant por columnas y no distingue "sin contrasena").
-- Columna-level esperado: contrasena = false para soporte/reportes/app_web.
-- SELECT has_column_privilege('rol_soporte', 'usuario', 'id_usuario', 'SELECT'); -- esperado true
-- SELECT has_column_privilege('rol_soporte', 'usuario', 'contrasena', 'SELECT'); -- esperado false
-- SELECT has_column_privilege('rol_reportes', 'usuario', 'contrasena', 'SELECT'); -- esperado false (sin grant en usuario)
-- SELECT has_column_privilege('app_web', 'usuario', 'contrasena', 'SELECT'); -- esperado false
-- -----------------------------------------------------------------------------

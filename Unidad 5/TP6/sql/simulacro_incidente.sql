-- =============================================================================
-- TP6 Parte C — Simulacro de incidente (SCRIPT IDEMPOTENTE, NO EJECUTADO)
-- Estado: LISTO PARA EJECUTAR en instancia propia, pendiente credencial.
-- =============================================================================
-- Bloque 0 — AVISO ÉTICO + PRERREQUISITOS (leer antes de ejecutar)
-- -----------------------------------------------------------------------------
-- AVISO ÉTICO: usar SOLO en instancia propia / clon de laboratorio.
-- PROHIBIDO ejecutar contra producción o contra cuentas reales.
-- Todos los datos de este script son SINTÉTICOS (anon-*). No usar mails,
-- nombres ni contraseñas reales.
-- Prerrequisitos:
--   1) parcial_BD cargado (01_schema.sql → 04_objects.sql, tabla usuario con
--      columnas id_usuario,nombre,apellido,mail,celular,contrasena,rol,
--      fecha_alta?,eliminado — ver nota: fecha_alta si existe en clon;
--      este script solo usa id_usuario,mail,contrasena,rol,eliminado).
--   2) TP6/sql/roles.sql aplicado (existen rol_soporte NOLOGIN y admin_datos).
--   3) Ejecutar como owner / superuser del clon para poder SET ROLE y verificar
--      pg_auth_members. Transacción controlada + RESET ROLE al final.
-- =============================================================================

-- Verificación de prerrequisito (solo lectura, no modifica nada):
-- SELECT to_regclass('public.usuario'), to_regrole('rol_soporte'), to_regrole('admin_datos');

BEGIN;

-- =============================================================================
-- Bloque 1 — STUB fn_autenticar(p_mail TEXT, p_contrasena TEXT) → BOOLEAN
-- -----------------------------------------------------------------------------
-- Documenta: Clase 2 no versionada en repo; stub mínimo solo para simulacro.
-- Valida contra usuario.contrasena (comparación simple, sin hash real) y
-- retorna TRUE/FALSE. SECURITY DEFINER del owner (defecto documentado:
-- requiere REVOKE + search_path fijo en producción, ver Parte A).
-- Idempotente: solo crea si no existe.
-- =============================================================================
DO $$
BEGIN
  IF to_regproc('public.fn_autenticar(text,text)') IS NULL THEN
    CREATE FUNCTION public.fn_autenticar(p_mail TEXT, p_contrasena TEXT)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public
    AS $fn$
    DECLARE
      v stored TEXT;
    BEGIN
      SELECT contrasena INTO v FROM usuario WHERE mail = p_mail AND eliminado = FALSE;
      IF NOT FOUND THEN RETURN FALSE; END IF;
      RETURN (v = p_contrasena); -- stub: comparación directa solo simulacro
    END;
    $fn$;
    REVOKE ALL ON FUNCTION public.fn_autenticar(TEXT,TEXT) FROM PUBLIC;
  END IF;
END;
$$;

-- =============================================================================
-- Bloque 2 — Paso 1: 4 intentos FALLIDOS (misma cuenta sintética, distinta clave)
-- Cuenta sintética: anon-user-007 / anon.test007@ejemplo.edu (NO real).
-- Cada SELECT retorna FALSE (no eleva excepción, queda en log_statement).
-- =============================================================================
SELECT public.fn_autenticar('anon.test007@ejemplo.edu', 'clave-mala-01') AS intento_1_falla;
SELECT public.fn_autenticar('anon.test007@ejemplo.edu', 'clave-mala-02') AS intento_2_falla;
SELECT public.fn_autenticar('anon.test007@ejemplo.edu', 'clave-mala-03') AS intento_3_falla;
SELECT public.fn_autenticar('anon.test007@ejemplo.edu', 'clave-mala-04') AS intento_4_falla;

-- =============================================================================
-- Bloque 3 — Paso 2: 1 intento EXITOSO (misma cuenta, clave correcta sintética)
-- Requiere que exista fila sintética previa en clon:
--   mail='anon.test007@ejemplo.edu', contrasena='clave-simulacro-007', eliminado=FALSE
-- Si no existe, este SELECT retorna FALSE y el simulacro se detiene aquí.
-- =============================================================================
-- (Setup sintético idempotente para el clon — solo anon-*):
-- INSERT INTO usuario (nombre,apellido,mail,celular,contrasena,rol)
-- SELECT 'Anon','User007','anon.test007@ejemplo.edu','000000','clave-simulacro-007','USUARIO'
-- WHERE NOT EXISTS (SELECT 1 FROM usuario WHERE mail='anon.test007@ejemplo.edu');
SELECT public.fn_autenticar('anon.test007@ejemplo.edu', 'clave-simulacro-007') AS intento_5_exito;

-- =============================================================================
-- Bloque 4 — Paso 3: lectura MASIVA como rol de bajo privilegio (rol_soporte)
-- Evidencia esperada en log: 1 statement SELECT masivo sobre usuario.
-- =============================================================================
SET ROLE rol_soporte;
SELECT id_usuario, mail, rol FROM usuario WHERE eliminado = FALSE; -- lectura masiva simulada
RESET ROLE;

-- =============================================================================
-- Bloque 5 — Paso 4: intento de ESCALAMIENTO (debe FALLAR)
-- 5a) GRANT admin_datos TO rol_soporte → ERROR permission denied (no es miembro/admin).
-- 5b) SET ROLE admin_datos desde rol_soporte → ERROR must be member.
-- Se envuelven en bloques DO con EXCEPTION para que el script continúe y
-- deje evidencia NOTICE del bloqueo (no se otorga nada).
-- =============================================================================
SET ROLE rol_soporte;
DO $$
BEGIN
  BEGIN
    GRANT admin_datos TO rol_soporte; -- DEBE FALLAR
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'BLOQUEO OK: GRANT admin_datos denegado a rol_soporte (%)', SQLERRM;
  END;
  BEGIN
    EXECUTE 'SET ROLE admin_datos'; -- DEBE FALLAR: must be member
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'BLOQUEO OK: SET ROLE admin_datos denegado (%)', SQLERRM;
  END;
END;
$$;
RESET ROLE;

-- =============================================================================
-- Bloque 6 — VERIFICACIÓN: pg_auth_members sin membresía nueva (defecto Parte A)
-- Si aparece rol_soporte → admin_datos, EXCEPTION (falla el simulacro).
-- Caso contrario NOTICE 'ESCALAMIENTO BLOQUEADO: OK'.
-- =============================================================================
DO $$
DECLARE
  v_count INT;
BEGIN
  SELECT count(*) INTO v_count
  FROM pg_auth_members m
  JOIN pg_roles r1 ON r1.oid = m.roleid
  JOIN pg_roles r2 ON r2.oid = m.member
  WHERE r1.rolname = 'admin_datos' AND r2.rolname = 'rol_soporte';
  IF v_count > 0 THEN
    RAISE EXCEPTION 'HALLAZGO: rol_soporte es miembro de admin_datos (%)', v_count;
  ELSE
    RAISE NOTICE 'ESCALAMIENTO BLOQUEADO: OK';
  END IF;
END;
$$;

RESET ROLE;
-- ROLLBACK controlado: el simulacro no deja rastro (cambiar a COMMIT solo si se
-- quiere conservar la fila sintética anon.test007 para re-ejecución).
ROLLBACK;
-- Fin: verificar con SHOW ROLE; debe ser el owner original.

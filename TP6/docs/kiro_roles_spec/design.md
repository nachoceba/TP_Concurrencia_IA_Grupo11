# TP6 Parte A — Design (Kiro spec: roles)

## 1. Diagrama de herencia (texto)

```
rol_app_lectura ──hereda──> rol_app_escritura ──miembro──> app_web (LOGIN, LIMIT 20)
rol_soporte (independiente, columna-level en usuario)
rol_reportes (independiente, analítico)
rol_auditor ──miembro──> admin_datos (LOGIN, LIMIT 5)
```

- `GRANT rol_app_lectura TO rol_app_escritura`: escritura obtiene todo el SELECT de lectura sin duplicar GRANTs.
- Logins: `app_web` cuelga de escritura (opera); `admin_datos` cuelga de auditor (control). Sin NOLOGIN solo esos dos.

## 2. Matriz GRANT por objeto

| Objeto | Tipo | lectura | escritura | soporte | reportes | auditor |
|---|---|---|---|---|---|---|
| v_categorias_vigentes | vista | SELECT | SELECT (heredado) | — | — | — |
| v_productos_vigentes | vista | SELECT | SELECT (heredado) | — | — | — |
| v_pedidos_resumen | vista | SELECT | SELECT (heredado) | SELECT | SELECT | SELECT |
| v_pedido_detalle | vista | SELECT | SELECT (heredado) | SELECT | — | — |
| v_catalogo_productos | vista | SELECT | SELECT (heredado) | — | — | — |
| v_usuarios_segura | vista | SELECT | SELECT (heredado) | SELECT | — | SELECT |
| mv_top_productos_categoria | MV | SELECT | SELECT (heredado) | — | SELECT | SELECT |
| usuario (id,nombre,apellido,mail,celular,rol) | tabla col-level | — | — | SELECT cols | — | — |
| sp_crear_pedido(BIGINT,forma_pago,JSONB) | procedure | — | EXECUTE | — | — | — |
| calcular_total_pedido(BIGINT) | function | — | — | EXECUTE | — | EXECUTE |
| pedido / detalle_pedido | tabla | — | — (solo vía SP) | — | — | — |
| ENUM rol_usuario, estado_pedido, forma_pago | type | USAGE | USAGE | USAGE | — | — |

Base común a los 5: CONNECT + USAGE ON SCHEMA public.

## 3. Orden de aplicación

1. Bloque 0 hardening (REVOKE PUBLIC) — primero para partir de cero.
2. Crear grupos NOLOGIN idempotentes (Bloque 1) + herencia (Bloque 2).
3. CONNECT/USAGE/TYPE (Bloque 3).
4. SELECT vistas/MV a lectura (Bloque 4); columna-level usuario a soporte (Bloque 5).
5. EXECUTE SP/función (Bloque 6) + SELECT soporte/reportes/auditor (Bloques 7-9).
6. ALTER DEFAULT PRIVILEGES (Bloque 10) — rige objetos futuros del owner postgres.
7. Logins + membresías + search_path (Bloque 11); passwords fuera del repo.

## 4. Rollback

- Todo GRANT es reversible con el REVOKE espejo (p. ej. `REVOKE SELECT ON v_pedidos_resumen FROM rol_reportes;`).
- Membresías: `REVOKE rol_app_escritura FROM app_web; REVOKE rol_auditor FROM admin_datos;`.
- DEFAULT PRIVILEGES: re-ejecutar con `REVOKE` en lugar de `GRANT`, o `ALTER DEFAULT PRIVILEGES ... REVOKE ...`.
- Roles: `DROP ROLE IF EXISTS app_web, admin_datos, rol_app_escritura, rol_app_lectura, rol_soporte, rol_reportes, rol_auditor;` (en ese orden por dependencia; falla si aún poseen objetos o membresías).
- Protocolo: probar en clon con `BEGIN; ... ROLLBACK;` y `pg_dump` previo si hay ALTER/DROP (ver protocolo_seguridad.md).

## 5. Decisión: v_usuarios_segura vs tabla usuario

- Se expone `v_usuarios_segura (id_usuario, nombre, apellido, mail, celular, rol)` y NUNCA la tabla `usuario` completa, porque la tabla contiene `contrasena` y exponerla viola mínimo privilegio.
- `rol_soporte` recibe además SELECT por columnas sobre `usuario` con la misma lista (sin contrasena) solo para casos donde la vista no alcance; igualmente sin contrasena.
- `v_usuarios_publico` (nombre viejo de roles.sql) se descarta: el nombre canónico es `v_usuarios_segura` según parcial_BD/04_objects.sql A6.

## 6. MV solo SELECT

- `mv_top_productos_categoria` es precalculada (Top-3 por categoría); a lectura/reportes/auditor se les da solo SELECT porque el refresh (`REFRESH MATERIALIZED VIEW [CONCURRENTLY]`) es tarea del owner/admin, no de consumidores.
- No se otorga INSERT/UPDATE/DELETE sobre la MV ni sobre sus tablas base a estos roles.

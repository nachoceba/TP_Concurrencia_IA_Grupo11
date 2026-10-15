# TP6 Parte B — Informe de auditoría (logging del motor)

## Encabezado / entorno
- **Motor:** PostgreSQL 17.10 local, puerto `:5432`, compatible PG16+ (ENUM, TIMESTAMPTZ, JSONB, IDENTITY, PL/pgSQL según `parcial_BD/01_schema.sql`).
- **Fecha:** 2026-10-15.
- **Protocolo citado:** `protocolo_seguridad.md` (motor PostgreSQL 18.6; clon de trabajo + `BEGIN`/`ROLLBACK` antes de `COMMIT` definitivo).
- **Nota honesta:** sin credencial superuser (autenticación `scram-sha-256`, error `fe_sendauth`) **no se pudo aplicar `ALTER SYSTEM` en vivo**; los parámetros de abajo están **documentados para aplicar con credencial**, y el fragmento de log es **reconstruido a modo de evidencia esperada** (ver `TP6/docs/log_auditoria_prueba.txt`), pendiente de captura live.

## B.1 — Parámetros de auditoría

| Parámetro | Valor propuesto | Justificación |
|---|---|---|
| `log_connections` | `on` | Registra inicio de cada sesión (quién se conectó, desde dónde, cuándo). Base para detectar accesos fuera de horario o暴力 logins. |
| `log_disconnections` | `on` | Registra fin de sesión (duración). Permite correlacionar conexión ↔ desconexión por PID `%p`. |
| `log_statement` | `'mod'` | Registra DDL + DML que **modifican** (`INSERT`/`UPDATE`/`DELETE`/`DDL`), pero **no** `SELECT` puros. Equilibrio entre trazabilidad y volumen/PII: `'all'` en producción permanente genera demasiado volumen y expone datos personales en cada lectura; `'all'` se reserva solo como **ventana temporal ante un incidente** (ver corrección en BITÁCORA Parte B). |
| `log_line_prefix` | `'%m [%p] %u@%d %h %a '` | `%m` = timestamp con ms (cuándo) · `%p` = PID/backend (correlaciona líneas de la misma sesión) · `%u` = usuario (quién) · `%d` = base de datos (dónde) · `%h` = host remoto (desde dónde) · `%a` = aplicación (psql/app, qué cliente). Sin este prefijo las líneas del log no son atribuibles. |
| `log_destination` | `'csvlog'` (preferido) o `'stderr'` + archivo | `csvlog` facilita análisis/filter por campo (usuario, BD, mensaje); `stderr` + `log_directory`/`log_filename` sirve si no hay colector CSV. En ambos casos el archivo debe quedar bajo el directorio de log del servidor con rotación (`log_rotation_age`/`log_rotation_size`). |

## B.2 — Comandos exactos para aplicar (documentados, SIN ejecutar)
```sql
-- TP6 Parte B — aplicar SOLO con credencial superuser, en clon de trabajo.
-- Sin ejecutar en esta entrega (bloqueado por fe_sendauth / scram-sha-256).
-- ALTER SYSTEM SET log_connections = 'on';
-- ALTER SYSTEM SET log_disconnections = 'on';
-- ALTER SYSTEM SET log_statement = 'mod';
-- ALTER SYSTEM SET log_line_prefix = '%m [%p] %u@%d %h %a ';
-- ALTER SYSTEM SET log_destination = 'csvlog';
-- SELECT pg_reload_conf();
-- SHOW log_connections;
-- SHOW log_disconnections;
-- SHOW log_statement;
-- SHOW log_line_prefix;
-- SHOW log_destination;
```

## Secuencia de prueba prevista (food store, coherente con `parcial_BD/01_schema.sql`)

1. **SELECT en vista resumen** (lectura, no queda en `log_statement='mod'`, solo conexión/sesión):
   ```sql
   -- Paso 1 (usuario de lectura, sesión psql正常):
   SELECT * FROM v_pedidos_resumen LIMIT 5;
   ```
2. **INSERT en `pedido`** (queda registrado con `'mod'`):
   ```sql
   -- Paso 2:
   INSERT INTO pedido (estado, forma_pago, metadatos, usuario_id)
   VALUES ('PENDIENTE', 'TARJETA', '{"canal":"web"}', 1);
   ```
3. **UPDATE de stock en `producto`** (queda registrado con `'mod'`):
   ```sql
   -- Paso 3:
   UPDATE producto SET stock = stock - 1 WHERE id_producto = 1 AND eliminado = FALSE;
   ```
4. **Login fallido con psql** (password errónea, queda `FATAL`):
   ```bash
   # Paso 4 (comando previsto, NO ejecutado):
   # PGPASSWORD=incorrecta psql -h 127.0.0.1 -U anon-user-001 -d foodstore -c "SELECT 1;"
   ```

## B.3 — Análisis del fragmento (`TP6/docs/log_auditoria_prueba.txt`, líneas 6–15)

| Línea del log | Quién | Qué | Cuándo | Desde dónde |
|---|---|---|---|---|
| `connection received` (l.6) | aún sin usuario autenticado (PID 12345) | intento de conexión entrante | 2026-10-15 10:00:01.123 -03 | host 127.0.0.1, app `psql`, BD `foodstore` |
| `SELECT` (l.8, `statement:`) | `anon-user-001` | lectura `SELECT * FROM v_pedidos_resumen LIMIT 5` | 10:00:12.410 | misma sesión PID 12345, 127.0.0.1/psql |
| `INSERT` (l.9, `statement:`) | `anon-user-001` | `INSERT INTO pedido ...` (modificación) | 10:00:35.802 | misma sesión PID 12345 |
| `FATAL password authentication failed` (l.12) | `anon-user-002` (no autenticado) | login fallido con password errónea | 10:01:44.009 | host 127.0.0.1, app `psql`, PID 12347 |

**Límite sin granularidad fila-a-fila:** el `log_statement` estándar registra el *texto* de la sentencia, pero **no** qué filas/columnas se vieron ni valores antes/después. Ejemplos: en el `SELECT` masivo sobre `v_pedidos_resumen` no queda constancia de **qué columnas de `usuario` (mails/teléfonos) devolvió cada fila**; en el `UPDATE` de `producto.stock` no queda el **valor viejo vs. nuevo** (solo `stock = stock - 1`). **pgaudit (a nivel nociones):** aportaría auditoría por objeto y por rol —clases `read`/`write`, auditoría a nivel de objeto (`AUDIT SELECT ON usuario`) y filtrado por rol— de modo que se registra *qué rol leyó/escribió qué objeto*, complementando al `log_statement` global sin pasar a `'all'` permanente.

## B.4 — Respuestas

- **¿El log es un activo sensible?** Sí. Contiene mails y patrones de acceso, horarios de actividad, textos de sentencias (posibles hashes/codificaciones si viajan en parámetros) y huellas de comportamiento, por lo que sirve para ingeniería social y ataques de replay o enumeración. Debe tratarse con el mismo nivel de protección que los datos que describe.
- **¿Quién debe leerlo y con qué permisos?** Solo el DBA y el rol auditor. A nivel OS, archivos del grupo `postgres` con modo `640` (sin acceso para la cuenta de la app); a nivel motor, acceso restringido a un rol tipo `rol_auditor`/`monitor` (lectura de vistas de log), nunca al rol de aplicación.

## Cierre — limitación honesta y verificación
- **Limitación:** la configuración **no quedó aplicada en vivo** (pendiente de credencial superuser; bloqueo `fe_sendauth` con `scram-sha-256`) y el fragmento de log es **reconstruido como evidencia esperada**, no capturado.
- **Cómo verificar cuando haya credencial:** (1) `SHOW log_connections; SHOW log_disconnections; SHOW log_statement; SHOW log_line_prefix; SHOW log_destination;` y confirmar valores de la tabla B.1; (2) correr la secuencia de 4 pasos y contrastar el fragmento real contra `log_auditoria_prueba.txt` (conexión, `SELECT`, `INSERT`, `UPDATE`, `FATAL`, desconexión con el mismo prefijo).

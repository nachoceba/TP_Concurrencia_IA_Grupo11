# TP6 (Unidad 5) · Auditoría activada en vivo y simulacro reconstruido desde el log real

**Fecha:** 09/11/2026 · **Motor:** PostgreSQL 16.15 (instancia de laboratorio, con superusuario) · **Script:** `sql/simulacro_live.sh` · **Evidencia:** `docs/log_auditoria_live.txt`, que es la salida **real** del motor recortada entre marcadores, no una reconstrucción.

Este documento cierra la limitación de `informe_auditoria.md` y `log_auditoria_prueba.txt`. En la Parte B los parámetros quedaron documentados pero no aplicados, porque faltaba la credencial de superusuario, y el log era una reconstrucción de la salida esperada. Ahora se aplicaron con `ALTER SYSTEM` y el simulacro se reconstruye **a partir del log del motor**.

## 1. Auditoría aplicada

| Parámetro | Valor | Cuándo |
|---|---|---|
| `log_connections` / `log_disconnections` | `on` | Siempre |
| `log_statement` | `'mod'` | Operación normal: DDL y DML que modifican |
| `log_statement` | `'all'` | Solo en la **ventana de incidente** (política de la Parte B) |
| `log_line_prefix` | `'%m [%p] %u@%d %h %a '` | Hora, PID, usuario@base, origen y aplicación |

Se aplicó con `ALTER SYSTEM SET …` + `SELECT pg_reload_conf()`, se verificó con `pg_settings` y al terminar se dejó todo como estaba (`ALTER SYSTEM RESET`). La base fue la efímera `tp6_u5_work`: `01_schema` → `04_objects` → `02_data_demo` → `roles.sql`. Se borra al final.

## 2. Línea de tiempo reconstruida desde el log real

| Hora (UTC) | PID | Evento en el log | Lectura |
|---|---|---|---|
| 23:39:02.480 | 442 | `statement: INSERT INTO pedido …` → `ERROR: permission denied for table pedido` | `auditoria_test.sql` con `'mod'`: el INSERT directo de `app_web` queda **registrado y denegado**. El SELECT previo no aparece, como se esperaba con `'mod'` |
| 23:39:03.603 – .692 | 453, 456, 459, 462 | 4 × `FATAL: password authentication failed for user "anon_test007"` desde `127.0.0.1` | Fuerza bruta: 4 conexiones distintas, la misma cuenta y el mismo origen, en menos de 0,1 s |
| 23:39:03.718 | 465 | `connection authenticated: identity="anon_test007" method=scram-sha-256` | Quinto intento exitoso: la cuenta quedó comprometida |
| 23:39:03.719 | 465 | `statement: SELECT … FROM (SELECT id_usuario, mail, rol FROM usuario)` | Lectura masiva de usuarios (6 filas) con los privilegios por columna de `rol_soporte`. Solo se ve porque la ventana estaba en `'all'` |
| 23:39:03.720 | 465 | `GRANT admin_datos TO rol_soporte` → `ERROR: permission denied to grant role "admin_datos"` | Intento de escalar: **bloqueado** |
| 23:39:03.720 | 465 | `SET ROLE admin_datos` → `ERROR: permission denied to set role "admin_datos"` | Segundo intento: **bloqueado**. Ahora es fiel, porque la sesión no es superusuario (en la Parte C/LIVE corría como `postgres` y no fallaba) |
| 23:39:03.720 | 465 | `disconnection: session time: 0:00:00.006` | Fin de la sesión del atacante |
| 23:39:03.743 | 467 | `owner_verificacion`: consulta a `pg_auth_members` | El owner confirma **0 membresías** nuevas hacia `admin_datos` |

## 3. Contraste con el log reconstruido de la Parte B/C

| En `log_auditoria_prueba.txt` / `log_simulacro_anonimizado.txt` | En el log real | Veredicto |
|---|---|---|
| 4 `FATAL` + 1 autenticación `scram-sha-256` | Igual | Coincide |
| `ERROR: must be member of role "admin_datos"` | `ERROR: permission denied to set role "admin_datos"` | El texto esperado era de otra versión: PostgreSQL 16 usa otro mensaje |
| Intentos separados por segundos y en una sola sesión | Cada intento es **una conexión con su propio PID** | El reconstruido simplificaba: en el real hay que agrupar por usuario y origen, no por PID |
| `%u` = el rol que opera | `%u` = **usuario de sesión**: `auditoria_test` figura como `root` aunque hizo `SET ROLE app_web` | **Hallazgo:** el log estándar no muestra el rol efectivo después de `SET ROLE`. Para atribuirlo hace falta pgaudit o prohibir `SET ROLE` en los logins de aplicación |

## 4. Hallazgo de seguridad encontrado al activar la auditoría

Con `log_statement` en `'mod'` o en `'all'`, una sentencia `CREATE ROLE … PASSWORD 'xxx'` (o `ALTER ROLE`) **queda en el log con la clave en texto plano**. Se comprobó en la primera corrida, y ese log se descartó.

**Decisión del equipo:**

- Crear y cambiar claves solo con `\password` en psql, que envía la clave ya cifrada.
- Cuando no quede otra que usar SQL, hacer `SET log_statement = 'none'` en esa sesión antes de la sentencia. Así lo hace ahora `simulacro_live.sh`.
- El log de auditoría también es información sensible: acceso restringido y rotación.

## 5. Contención propuesta (decisión humana)

1. **Bloquear el origen** en `pg_hba.conf` con una línea `reject` para el host y el usuario afectados, y recargar. Es temporal y reversible.
2. **Deshabilitar la cuenta comprometida** (`ALTER ROLE anon_test007 NOLOGIN`) y rotar su clave con `\password`.
3. **Verificar que no hubo escalamiento**: `pg_auth_members` debe dar 0 filas hacia `admin_datos`. Ya confirmado.
4. **Evaluar la exposición**: se leyeron `id_usuario`, `mail` y `rol` de 6 usuarios, pero no `contrasena`, porque la columna no está otorgada. Si fuera una base real, correspondería avisar a los afectados por los mails expuestos.
5. **Mejoras:**
   - Detectar 3 o más `FATAL` por usuario y origen en menos de 1 minuto. Hoy no hay bloqueo automático: PostgreSQL no limita intentos, así que haría falta fail2ban o un bloqueo en el firewall.
   - Evaluar pgaudit para registrar el rol efectivo y las lecturas por objeto sin tener `'all'` siempre prendido.

## 6. Cómo repetirlo

```bash
cd "Unidad 5/TP6/sql"
PGLOG=/var/log/postgresql/postgresql-16-main.log ./simulacro_live.sh
```

Requiere el superusuario de una instancia de **laboratorio**. En Windows, `PGLOG` es el archivo en `<data>/log/` (con `logging_collector = on`). El script deja la configuración como estaba y borra la base efímera y el login sintético.

# Informe de incidente — Simulacro TP6 Parte C (anonimizado, sin live)

> Datos 100% sintéticos (anon-user-007@ejemplo.edu, IP 203.0.113.7 RFC5737). Sin live por falta de credencial; script `TP6/sql/simulacro_incidente.sql` listo para ejecutar en clon propio.

## 1) Resumen secuencia

| Hora (-03) | Evento | Evidencia |
|---|---|---|
| 10:02:01–10:03:02 | 4 intentos fallidos misma cuenta | 4× `FATAL: password authentication failed` PID 12401 en `log_simulacro_anonimizado.txt` |
| 10:03:30 | 1 autenticación exitosa | `connection authenticated ... method=scram-sha-256` PID 12401 |
| 10:04:10 | Lectura masiva como rol bajo privilegio | `statement: SELECT id_usuario, mail, rol FROM usuario WHERE eliminado=FALSE` |
| 10:04:55 | Intento `GRANT admin_datos TO rol_soporte` | `ERROR: permission denied for role admin_datos` |
| 10:05:12 | Intento `SET ROLE admin_datos` | `ERROR: must be member of role "admin_datos"` |
| 10:05:40 | Verificación owner en `pg_auth_members` | `SELECT count(*) FROM pg_auth_members ...` PID 12402 → 0 filas |
| 10:06:05 | Cierre sesión | `disconnection: session time 0:04:04` |

## 2) Reconstrucción ciega de IA (solo con el log anonimizado)

Timeline inferido: un origen único (203.0.113.7) prueba 4 claves contra `anon-user-007` entre 10:02:01 y 10:03:02, logra entrar a las 10:03:30, exfiltra/lee la tabla `usuario` a las 10:04:10 y escala a `admin_datos` a las 10:04:55–10:05:12; el owner verifica a las 10:05:40 y la sesión se cierra a las 10:06:05.

Hipótesis de contención propuesta por IA: (a) bloquear origen 203.0.113.7 en `pg_hba.conf`/firewall, (b) revertir membresía `rol_soporte→admin_datos` si existiera, (c) forzar reset de passwords de cuentas afectadas [INFERENCIA: el log no muestra qué claves se probaron ni si hubo otras cuentas], (d) rotar credencial comprometida [INFERENCIA: no evidenciado qué secreto se comprometió], (e) ampliar ventana de `log_statement='all'` [INFERENCIA: no evidenciado que el modo actual sea insuficiente].

## 3) Contraste escrito (IA vs. verdad del simulacro)

| Afirmación IA (ciega) | Veredicto | Motivo |
|---|---|---|
| Incidente ocurrió el 2026-10-14 23:00 UTC por timezone mal convertido | **sin sustento** (error deliberado detectado #1) | Log dice `2026-10-15 10:02–10:06 -03`; IA restó/mal convirtió a UTC sin evidencia |
| Origen es `ataque externo` desde internet | **sin sustento** (error deliberado detectado #2) | `203.0.113.0/24` es rango DOCUMENTACIÓN RFC5737 (IP simulada de laboratorio), no geolocalizable como externa |
| IA afirma que hubo `UPDATE usuario SET contrasena` no registrado | **sin sustento** (error deliberado detectado #3 / paso no registrado) | Ni el script ni el log contienen UPDATE; es alucinación de paso |
| 4 fallidos + 1 éxito misma cuenta | **acertó** | Coincide con Bloques 2–3 del script y líneas FATAL + authenticated |
| Lectura masiva `SELECT id_usuario, mail, rol ...` | **acertó** | Literal Bloque 4 y línea 10:04:10 |
| Escalamiento bloqueado (2 errores) | **acertó** | `permission denied` + `must be member` = Bloque 5 |
| Verificación `pg_auth_members` sin membresía nueva | **omitió** (IA ciega no lo vio) | Solo visible en sesión PID 12402 + Bloque 6 `ESCALAMIENTO BLOQUEADO: OK`; IA lo pasó por alto |

## 4) Decisión final HUMANA del equipo (no automática)

El equipo decide con evidencia del script + log anonimizado:

1. Bloquear origen `203.0.113.7` a nivel `pg_hba.conf`/firewall (ventana temporal, reversible).
2. Verificar `pg_auth_members`: confirmar 0 filas `rol_soporte→admin_datos` (Bloque 6).
3. Forzar reset de passwords de cuentas afectadas (`anon.test007` en clon; en real, las que el live indique).
4. Re-auditar `GRANT`s Parte A (mínimo privilegio, sin `GRANT ALL`, sin passwords en claro).

Explícito: esta es una **decisión humana con evidencia**; la IA solo reconstruye y propone. **Pendiente ejecutar con credencial** (superuser/owner del clon); no se tomó acción automática.

## 5) Limitación honesta

Sin captura live por falta de credencial (`fe_sendauth`/scram-sha-256, mismo bloqueo que Parte A/B). Log de este informe es **reconstruido como evidencia esperada** (14 líneas, PIDs/horas coherentes). Script `TP6/sql/simulacro_incidente.sql` idempotente y comentado, listo para ejecutar con `BEGIN … ROLLBACK` controlado y `RESET ROLE`.

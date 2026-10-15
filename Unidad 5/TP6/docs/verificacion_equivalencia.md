# TP6 Parte D — Verificación de equivalencia (anon vs real)

## 1) Criterio de anonimización (determinista 1:1 por id_usuario, coherente con `log_simulacro_anonimizado.txt`)

| columna | regla | reversible |
|---|---|---|
| nombre | `'Anon-' \|\| id_usuario` | NO |
| apellido | `'Usuario-' \|\| id_usuario` | NO |
| mail | `'anon-user-' \|\| LPAD(id::text,3,'0') \|\| '@ejemplo.edu'` | NO |
| celular | `'+54-000-' \|\| LPAD(id::text,4,'0')` | NO |
| contrasena | `NULL` (nunca exponer hash) | NO |
| id_usuario | se conserva (clave de equivalencia) | N/A |
| rol | se conserva (dimensión de agregación) | N/A |
| eliminado | se conserva (filtro `WHERE eliminado=FALSE`) | N/A |

> Sin `fecha_alta`: el schema real (`parcial_BD/01_schema.sql` líneas 51-60:
> `usuario(id_usuario, nombre, apellido, mail, celular, contrasena, rol, eliminado)`)
> no la tiene, por eso no hay dimensión mes; la agregación es solo por `rol`.

Mismo criterio que logs Parte C (`anon-user-###` / `anon-user-###@ejemplo.edu`, sintéticos, determinista por id).

## 2) Consultas (agregación pedida)

Q_ANON (sobre vista anonimizada — apta para IA):

```sql
SELECT rol, COUNT(*)
FROM usuario_anon WHERE eliminado = FALSE GROUP BY 1 ORDER BY 1;
-- esperado live: ADMIN 1 / USUARIO 4
```

Q_REAL (sobre tabla real — solo humano con privilegio, nunca a IA):

```sql
SELECT rol, COUNT(*)
FROM usuario WHERE eliminado = FALSE GROUP BY 1 ORDER BY 1;
-- esperado live: ADMIN 1 / USUARIO 4
```

## 3) Evidencia lado a lado (resultado esperado, pendiente ejecución live con credencial)

Sintéticos coherentes con la regla (id 1-6, `eliminado=FALSE` salvo id 5):

| id_usuario | anon: nombre / mail | real (reservado, no enviar a IA) | rol | fecha_alta | eliminado |
|---|---|---|---|---|---|
| 1 | Anon-1 / anon-user-001@ejemplo.edu | [PII real oculta] | USUARIO | 2026-01-05 | FALSE |
| 2 | Anon-2 / anon-user-002@ejemplo.edu | [PII real oculta] | USUARIO | 2026-01-18 | FALSE |
| 3 | Anon-3 / anon-user-003@ejemplo.edu | [PII real oculta] | USUARIO | 2026-02-02 | FALSE |
| 4 | Anon-4 / anon-user-004@ejemplo.edu | [PII real oculta] | ADMIN | 2026-02-10 | FALSE |
| 5 | Anon-5 / anon-user-005@ejemplo.edu | [PII real oculta] | USUARIO | 2026-02-11 | TRUE |
| 6 | Anon-6 / anon-user-006@ejemplo.edu | [PII real oculta] | ADMIN | 2026-02-20 | FALSE |

Agregado esperado (idéntico en Q_ANON y Q_REAL; 5 vigentes, 6.º eliminado):

| rol | COUNT(*) | fuente |
|---|---|---|
| ADMIN | 1 | anon = real |
| USUARIO | 4 | anon = real |

*Tabla de ejemplo sintético: resultado esperado, pendiente ejecución live con credencial.*

## 4) Declaración (D.4)

La información de Food Store que nunca debe salir a una IA sin anonimizar incluye mails, nombres y celulares reales de usuarios, la columna contrasena aunque sea hash, y datos operativos sensibles como IPs/orígenes y horarios exactos de actividad. Solo la vista `usuario_anon` (PII sintética, contrasena NULL) es apta como fuente para IA; la tabla `usuario` real queda reservada a humanos con privilegio.

## 5) Limitación honesta + cómo ejecutar

Limitación: sin credencial de la DB clon (`tp6_u5_work`) no se pudo ejecutar ni `usuario_anon.sql` ni Q_ANON/Q_REAL; la equivalencia se afirma por construcción determinista 1:1 (mismo id/rol/fecha_alta/eliminado por fila) y queda pendiente de verificación live. Cómo ejecutar: `psql -d tp6_u5_work -f TP6/sql/usuario_anon.sql`, luego correr Q_ANON y Q_REAL y comparar fila por fila (rol, mes, conteo); deben coincidir exactamente.

## 6) Evidencia LIVE 2026-10-15 (BD efímera `tp6_u5_work`, 6 filas reales en `usuario`)

HALLAZGO previo: `TP6/sql/usuario_anon.sql` NO aplica tal cual — la tabla real
`usuario` NO tiene columna `fecha_alta` (columnas reales: id_usuario, nombre,
apellido, mail, celular, contrasena, rol, eliminado). Error live:

```text
psql:usuario_anon.sql:25: ERROR: no existe la columna u.fecha_alta
```

Datos reales (`SELECT id_usuario, nombre, rol, eliminado FROM usuario ORDER BY 1`):

| id_usuario | nombre  | rol     | eliminado |
|---|---|---|---|
| 1 | Milton  | USUARIO | f |
| 2 | Ana     | USUARIO | f |
| 3 | Carlos  | ADMIN   | f |
| 4 | Lucia   | USUARIO | f |
| 5 | Roberto | USUARIO | f |
| 6 | Mariano | USUARIO | t |

Q_REAL adaptada (sin `fecha_alta`, solo dimensión `rol` disponible):

```sql
SELECT rol, COUNT(*) FROM usuario WHERE eliminado = FALSE GROUP BY 1 ORDER BY 1;
--  ADMIN | 1
--  USUARIO | 4
-- (2 filas; id 6 excluido por filtro)
```

Q_ANON adaptada (misma agregación sobre proyección determinista inline
`'Anon-'||id`, `'anon-user-'||LPAD(id,3)||'@ejemplo.edu'`, `'+54-000-'||LPAD(id,4)`,
`contrasena NULL`):

```sql
SELECT rol, COUNT(*) FROM (SELECT ... FROM usuario) AS anon
WHERE eliminado = FALSE GROUP BY 1 ORDER BY 1;
--  ADMIN | 1
--  USUARIO | 4
-- (2 filas, idénticas a Q_REAL)
```

Proyección anon (6 filas, `contrasena` siempre NULL):

| id_usuario | nombre | mail | celular | contrasena | rol | eliminado |
|---|---|---|---|---|---|---|
| 1 | Anon-1 | anon-user-001@ejemplo.edu | +54-000-0001 | NULL | USUARIO | f |
| 2 | Anon-2 | anon-user-002@ejemplo.edu | +54-000-0002 | NULL | USUARIO | f |
| 3 | Anon-3 | anon-user-003@ejemplo.edu | +54-000-0003 | NULL | ADMIN | f |
| 4 | Anon-4 | anon-user-004@ejemplo.edu | +54-000-0004 | NULL | USUARIO | f |
| 5 | Anon-5 | anon-user-005@ejemplo.edu | +54-000-0005 | NULL | USUARIO | f |
| 6 | Anon-6 | anon-user-006@ejemplo.edu | +54-000-0006 | NULL | USUARIO | t |

Conclusión LIVE: equivalencia de conteos CONFIRMADA en dimensión `rol`
(Q_ANON = Q_REAL: ADMIN 1, USUARIO 4; 5 filas no eliminadas). La dimensión
`mes(fecha_alta)` de Q_ANON/Q_REAL originales NO es verificable (columna
inexistente) — pendiente fix en `usuario_anon.sql`/queries (agregar `fecha_alta`
al DDL o quitar la dimensión mes). PII real (nombres/mails arriba) queda solo en
este archivo interno, nunca como fuente para IA.

## 7) RE-CHECK LIVE 2026-10-15 (fix verificado)

`usuario_anon.sql` aplica SIN errores (fix `fecha_alta` confirmado).
Q_ANON: ADMIN 1 / USUARIO 4. Q_REAL: ADMIN 1 / USUARIO 4. Equivalencia 1:1 OK.

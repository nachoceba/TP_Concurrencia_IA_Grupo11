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
| fecha_alta | se conserva (dimensión de agregación) | N/A |
| eliminado | se conserva (filtro `WHERE eliminado=FALSE`) | N/A |

Mismo criterio que logs Parte C (`anon-user-###` / `anon-user-###@ejemplo.edu`, sintéticos, determinista por id).

## 2) Consultas (agregación pedida)

Q_ANON (sobre vista anonimizada — apta para IA):

```sql
SELECT rol, date_trunc('month', fecha_alta) AS mes, COUNT(*)
FROM usuario_anon WHERE eliminado = FALSE GROUP BY 1, 2 ORDER BY 1, 2;
```

Q_REAL (sobre tabla real — solo humano con privilegio, nunca a IA):

```sql
SELECT rol, date_trunc('month', fecha_alta) AS mes, COUNT(*)
FROM usuario WHERE eliminado = FALSE GROUP BY 1, 2 ORDER BY 1, 2;
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

Agregado esperado (idéntico en Q_ANON y Q_REAL; id 5 excluido por filtro):

| rol | mes | COUNT(*) | fuente |
|---|---|---|---|
| ADMIN | 2026-02-01 00:00:00-03 | 2 | anon = real |
| USUARIO | 2026-01-01 00:00:00-03 | 2 | anon = real |
| USUARIO | 2026-02-01 00:00:00-03 | 1 | anon = real |

*Tabla de ejemplo sintético: resultado esperado, pendiente ejecución live con credencial.*

## 4) Declaración (D.4)

La información de Food Store que nunca debe salir a una IA sin anonimizar incluye mails, nombres y celulares reales de usuarios, la columna contrasena aunque sea hash, y datos operativos sensibles como IPs/orígenes y horarios exactos de actividad. Solo la vista `usuario_anon` (PII sintética, contrasena NULL) es apta como fuente para IA; la tabla `usuario` real queda reservada a humanos con privilegio.

## 5) Limitación honesta + cómo ejecutar

Limitación: sin credencial de la DB clon (`tp6_u5_work`) no se pudo ejecutar ni `usuario_anon.sql` ni Q_ANON/Q_REAL; la equivalencia se afirma por construcción determinista 1:1 (mismo id/rol/fecha_alta/eliminado por fila) y queda pendiente de verificación live. Cómo ejecutar: `psql -d tp6_u5_work -f TP6/sql/usuario_anon.sql`, luego correr Q_ANON y Q_REAL y comparar fila por fila (rol, mes, conteo); deben coincidir exactamente.

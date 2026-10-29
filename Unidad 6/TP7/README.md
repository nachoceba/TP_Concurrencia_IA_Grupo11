# TP Unidad 6 — Mantenimiento, respaldo y recuperación (Food Store)

| Entregable | Archivo |
|---|---|
| Especificación y reglas de seguridad | `SPEC_U6.md` (+ `AGENTS.md` para el asistente de IA) |
| Respaldo automatizable | `scripts/backup_foodstore.sh` |
| Monitoreo | `sql/health_check.sql` |
| Mantenimiento justificado | `sql/maintenance.sql` |
| Ensayo de restauración (opcional) | `scripts/restore_test.sh` + `sql/validacion_restore.sql` |
| Informe post-incidente | `informe_u6.pdf` (fuente: `informe_u6.md`) |
| Evidencias de las corridas | `evidencias/01` a `04` |

## Requisitos

- PostgreSQL 16+ con `foodstore` cargada (`parcial_BD/01_schema.sql` → `04_objects.sql` → `02` o `03`).
- Bash. En Windows sirve **Git Bash** con `psql`, `pg_dump` y `pg_restore` en el `PATH` (por ejemplo `C:\Program Files\PostgreSQL\16\bin`).
- La contraseña **no** va en ningún archivo del repo. Se carga una sola vez en el archivo de contraseñas de libpq:
  - Linux/macOS: `~/.pgpass` con `chmod 600`
  - Windows: `%APPDATA%\postgresql\pgpass.conf`
  - Contenido: `localhost:5432:*:postgres:TU_CLAVE`

## Cómo correrlo

```bash
cd "Unidad 6/TP7"
psql -d foodstore -X -f sql/health_check.sql     # 1. estado de salud
psql -d foodstore -X -f sql/maintenance.sql      # 2. diagnóstico + acciones justificadas
./scripts/backup_foodstore.sh                    # 3. respaldo → backups/ y logs/
./scripts/restore_test.sh                        # 4. simulacro cronometrado → logs/restore_*.log
JOBS=4 ./scripts/restore_test.sh                 #    misma prueba con pg_restore en paralelo
```

Cada script termina con código distinto de 0 si algo falla. `restore_test.sh` sólo crea y borra `foodstore_restore_test`. Nunca toca `foodstore`.

Los `.dump`, los `.counts` y `logs/` no se versionan (`.gitignore`): los dumps tienen datos personales de `usuario`.

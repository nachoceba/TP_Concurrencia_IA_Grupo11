# SPEC_U6 — Plan de mantenimiento, respaldo y recuperación de Food Store

**Motor:** PostgreSQL 16+ · **Base principal:** `foodstore` · **Base de ensayo:** `foodstore_restore_test`

## Qué se automatiza, cada cuánto y cómo se sabe que terminó bien

| Tarea | Script | Frecuencia | Condición de éxito (evidencia) |
|---|---|---|---|
| Respaldo de `foodstore` | `scripts/backup_foodstore.sh` | Diaria, 02:30 (baja actividad) | Código de salida 0; `backups/foodstore_AAAAMMDD_HHMMSS.dump` de tamaño > 0 y legible por `pg_restore --list`; línea `OK` en `logs/backup_AAAAMMDD.log`; conteo de filas guardado en `.counts` junto al dump |
| Chequeo de salud | `sql/health_check.sql` | Diaria, después del respaldo | Corre sin errores; salida guardada en `logs/`. Alerta si: conexiones > 80 % de `max_connections`, consultas activas > 5 min, tabla con `n_dead_tup` > 20 % de `n_live_tup`, cache hit < 95 % |
| Revisión de mantenimiento | `sql/maintenance.sql` | Semanal (domingo) | Autovacuum activo; ninguna tabla con > 20 % de tuplas muertas o sin estadísticas al terminar. `VACUUM (ANALYZE)` o `ANALYZE` manual **sólo** sobre las tablas que el diagnóstico previo señala |
| Restauración de prueba | `scripts/restore_test.sh` | Semanal (domingo, después del respaldo) | `foodstore_restore_test` restaurada desde el último `.dump`; conteos iguales a los del `.counts`; `productos_invalidos = 0` y `detalles_invalidos = 0`; RTO y antigüedad del respaldo registrados en `logs/restore_AAAAMMDD.log` |

## Objetivos de recuperación (laboratorio)

- **RPO previsto: 24 h.** Con un respaldo lógico diario se puede perder como máximo lo escrito desde el último respaldo.
- **RTO previsto: 15 min.** Es el tiempo desde crear la base de ensayo hasta tener las validaciones en verde.
- El RPO observado es la antigüedad del respaldo al empezar el simulacro. El RTO observado es lo que mide el cronómetro de `restore_test.sh`.

## Reglas de seguridad (no negociables)

1. **Sin contraseñas en el repositorio.** Los scripts no aceptan ni contienen contraseñas. La autenticación sale de `~/.pgpass` (en Windows, `%APPDATA%\postgresql\pgpass.conf`) con permisos 600, o de `PGPASSWORD` exportada en la sesión. Se usa `--no-password` para que, si falta la credencial, el script falle en vez de quedarse esperando.
2. **`foodstore` nunca se borra ni se reemplaza.** `restore_test.sh` aborta si la base destino es `foodstore`, y sólo hace `DROP` sobre `foodstore_restore_test`.
3. **Formato custom (`-Fc`)** para poder usar `pg_restore` con `--no-owner --no-privileges`.
4. **Sin `VACUUM FULL`** en el mantenimiento periódico, porque toma un lock exclusivo y reescribe la tabla.
5. **Fallar fuerte:** `set -euo pipefail`. Si `pg_dump`, `pg_restore` o alguna validación falla, se escribe `ERROR` en el log y el script termina con código distinto de 0.
6. **Los `.dump` no se versionan** (`.gitignore`): tienen datos personales de `usuario`. En la entrega va la evidencia (nombre, tamaño, log), no el archivo.
7. **Código generado con IA:** se lee, se prueba sobre la base descartable y recién después se acepta. Ningún comando destructivo se corre sin revisión humana previa.

## Programación sugerida (después de la prueba manual)

```cron
30 2 * * *  /ruta/TP7/scripts/backup_foodstore.sh && psql -d foodstore -f /ruta/TP7/sql/health_check.sql > /ruta/TP7/logs/health_$(date +\%F).txt
0  4 * * 0  /ruta/TP7/scripts/restore_test.sh && psql -d foodstore -f /ruta/TP7/sql/maintenance.sql > /ruta/TP7/logs/maint_$(date +\%F).txt
```

En Windows se usa el Programador de tareas, ejecutando los mismos scripts desde Git Bash.

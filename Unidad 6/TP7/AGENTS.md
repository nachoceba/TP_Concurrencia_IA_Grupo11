# AGENTS — TP Unidad 6 (Mantenimiento, respaldo y recuperación)

Instrucciones para el asistente de IA que trabaje en esta carpeta. Se suman al `AGENTS.md` y al `protocolo_seguridad.md` de la raíz del repo.

- La fuente de verdad es `SPEC_U6.md`. No agregar tareas ni frecuencias que no estén ahí.
- El schema real está en `parcial_BD/01_schema.sql`. **No existe la tabla `cliente`**: los clientes son filas de `usuario` (rol `USUARIO`). Antes de escribir SQL, verificar los nombres de tablas y columnas contra ese archivo.
- Nunca escribir contraseñas en scripts, logs, comentarios ni ejemplos. Para autenticarse se usa `.pgpass` o `PGPASSWORD` definido fuera del repo.
- Nunca proponer `DROP DATABASE foodstore`, `pg_restore --clean` contra `foodstore`, ni `VACUUM FULL` como mantenimiento periódico.
- Toda operación destructiva va sólo contra `foodstore_restore_test`.
- Los scripts de shell usan `set -euo pipefail` y terminan con código de salida distinto de 0 si algo falla.
- No se suben los `.dump` al repo.

# Bitácora de uso de IA — TP 9 (Unidad 8)

**Herramienta:** Claude (Anthropic, Opus 5.5). Con ella se hicieron la spec (en formato Kiro: `.kiro/specs/food-store-feria/` y una copia en `docs/kiro/`), los scripts y el code review. Todo se ejecutó sobre la copia de pruebas `food_store_tp8` y sobre `movil/foodstore_movil.db`. Ningún dato personal real pasó por la IA.

| # | Fecha | Qué se pidió | Qué se aceptó | Qué se descartó y por qué | Cómo se verificó |
|---|---|---|---|---|---|
| 1 | 09/11/2026 | Spec antes del código: requisitos EARS ligados a los casos, más design y tasks | 6 requisitos (REQ-01 a REQ-06), cada uno con el caso que lo prueba | Un requisito de "reserva de stock en la tablet": contradice la regla de oro (el servidor dispone) | Cada criterio tiene su caso y el caso da lo esperado en la evidencia |
| 2 | 09/11/2026 | Esquema SQLite de la tablet a partir de `producto` del parcial | 4 tablas STRICT con centavos, CHECK, FK, PK compuesta en `item_borrador` y bajas como lápidas | El precio como `REAL` (errores de redondeo; la consigna pide centavos enteros) y guardar mail o nombre del cliente (regla 2; queda solo `usuario_id`) | `pruebas_sqlite.sql`: COMMIT/ROLLBACK, C1 y C7 dan lo esperado, y una segunda corrida también |
| 3 | 09/11/2026 | Vista `v_snapshot_movil` y carga del CSV | Centavos y booleanos 0/1 **en la vista**, y UPSERT en `producto_cache` | Importar `t/f` y convertir en SQLite (no entra en las tablas STRICT) y recargar con `DELETE` + `INSERT` (rompe la FK de los borradores viejos, C4) | `\copy` → `.import`: 18 filas, 16 vendibles, 1 lápida |
| 4 | 09/11/2026 | Semáforo y casos C2 a C6 | `semaforo.sql` (solo PENDIENTE, motivo por producto, protección si la instantánea está vacía) y `casos_2c.sh` | El primer formato de salida cortaba el UUID a 8 caracteres, y las dos solicitudes de C2 se veían iguales. Se cambió para mostrar el final del UUID | `docs/evidencias/casos_2c.txt`: C2 a C6 OK; 7 pedidos y la misma huella md5 de stock antes y después |
| 5 | 09/11/2026 | Code review de todos los scripts de la cursada (3.c) | H1 (corregido), H2 (aceptado como mejora) y H4 (corregido) | H3: acumular stock entre solicitudes en la tablet. Se descarta porque `SIMULADO_APROBADO` no es una reserva, y el control real es el `FOR UPDATE` del servidor | Cada hallazgo se reprodujo en `food_store_review`. El servidor rechaza la segunda venta de 8 tartas (*stock insuficiente*) |

## Error de IA más relevante

La primera versión del semáforo mostraba solo los 8 primeros caracteres del `solicitud_uuid`. Como los UUID de prueba de C2 comparten el prefijo, la solicitud en CONFLICTO y la nueva aprobada aparecían con el mismo identificador, y parecía que una misma solicitud había cambiado de estado, que es justamente lo que el C6 dice que no pasa. Se detectó leyendo la evidencia antes de aceptarla y se corrigió mostrando el final del UUID. La salida de la IA puede ser correcta en los datos y engañosa en cómo los muestra.

# Declaración de Uso de IA (DUIA) — TP 9 (Unidad 8): Food Store en la feria

**Grupo 11 · Bases de Datos II**
**Herramienta:** Claude (Anthropic, Opus 5.5), usada para la spec en formato Kiro, los scripts, el code review y la documentación.
**Base de trabajo:** copia de pruebas `food_store_tp8` (PostgreSQL) con datos de demo, más `movil/foodstore_movil.db` (SQLite). La base real no se tocó. Los hallazgos de la revisión se reprodujeron en `food_store_review`, una copia descartable.
**Protocolo:** `protocolo_seguridad.md` (clon de trabajo → prueba → recién ahí aplicar). Ningún dato personal real se le pasó a la IA ni se guardó en SQLite.

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Qué generó | Se aceptó / se descartó, y por qué | Verificación realizada |
| :-- | :-- | :-- | :-- | :-- | :-- |
| Claude | Spec (4.a) | Consigna 4.a + casos C1 a C7 | `.kiro/specs/food-store-feria/` (copia en `docs/kiro/`) | Aceptado; se descartó la "reserva de stock en la tablet" | Cada criterio EARS tiene su caso y el caso da lo esperado |
| Claude | Esquema de la tablet (1.b) | Consigna 1.b + `producto` del parcial | `movil/schema_sqlite.sql` | Aceptado; se descartaron `REAL` y los datos personales | `movil/pruebas_sqlite.sql` (COMMIT/ROLLBACK, C1, C7) |
| Claude | Instantánea (2.a) | Consigna 2.a | `servidor/v_snapshot_movil.sql`, `movil/cargar_snapshot.sql` | Aceptado; se descartaron `t/f` y `DELETE` + `INSERT` | Importación de 18 filas con 1 lápida |
| Claude | Semáforo y casos (2.b, 2.c) | Consigna 2.b/2.c + spec | `movil/semaforo.sql`, `movil/casos/*.sql`, `casos_2c.sh` | Aceptado; se corrigió el formato de salida del UUID | `docs/evidencias/casos_2c.txt` y PostgreSQL sin cambios |
| Claude | Code review (3.c) | Revisión de solo lectura de todos los scripts de la cursada | H1 a H4 | H1 y H4 corregidos, H2 aceptado, H3 descartado | Reproducción en `food_store_review` |

**Declaración.** Todo lo generado con IA fue leído, ejecutado y comprobado en la base antes de incorporarlo, y el grupo puede explicar los scripts entregados.

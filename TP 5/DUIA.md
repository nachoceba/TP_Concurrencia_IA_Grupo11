# Declaración de Uso de IA (DUIA) — TP 5: Optimización, Vistas y Vista Materializada

**Herramienta general:** OpenCode CLI (modelo `big-pickle`), operando sobre PostgreSQL 18.6.
**Base de trabajo:** clon `TP2_Concurrencia_IA_Grupo11_clon` (la base principal `TP2_Concurrencia_IA_Grupo11` no existía en el motor local).
**Protocolo aplicado en toda la sesión:** `protocolo_seguridad.md` (clon de trabajo → `BEGIN/ROLLBACK` de prueba → `pg_dump` de respaldo antes de cambios estructurales).

---

## 1. Optimización de consultas e índices (parte 4.2)

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Qué generó | Se aceptó / se descartó — por qué | Verificación realizada |
| :---------- | :-------------- | :---------------------- | :--------- | :-------------------------------- | :--------------------- |
| OpenCode + `psql` (bash) | Baseline de rendimiento de 3 consultas | *"necesito que hagas un explain analyze de la siguientes consultas"* + los 3 `SELECT` (login por `mail`, catálogo por `categoria_id`, pedidos por `usuario_id`) | `EXPLAIN (ANALYZE, BUFFERS, TIMING)` de las 3 consultas sobre el clon; planes con `Index Scan` / `Bitmap Heap Scan` y tiempos reales | **Aceptado.** Se detectó la base real con datos (`..._clon`) y se midió sobre ella | Tiempos: login 0.090 ms; catálogo 4.592 ms; pedidos 0.126 ms |
| OpenCode + PostgreSQL | Elegir el índice adecuado por consulta | *"necesito que me digas que indice es el adecuado para cada consulta"* | Recomendación: (**1**) sin índice nuevo — usar el `UNIQUE(usuario.mail)` existente; (**2**) `idx_producto_categoria_precio (categoria_id, precio) WHERE eliminado = FALSE AND disponible = TRUE`; (**3**) `idx_pedido_usuario_fecha (usuario_id, fecha DESC) WHERE eliminado = FALSE` | **Aceptado.** Se priorizó reutilizar el `UNIQUE` existente en vez de duplicar índices; los dos parciales coinciden con las propuestas B2/B3 de `indices.sql` | Contraste contra `indices.sql` y `schema.sql` (no duplicar `idx_producto_categoria_id` ni `idx_pedido_usuario_id`) |
| OpenCode + `psql` | Aplicar índices y comparar antes/después | *"ahora añade los indices y realiza un explain analyze para comparar los tiempos con los previos a los indices"* | `pg_dump` de respaldo, creación de los 2 índices en transacción, `VACUUM ANALYZE`, re-medición | **Aceptado.** Catálogo −93,7% (4.592 → 0.289 ms) sin `Sort`; pedidos con cambio de índice y tiempo dentro del ruido (0.126 → 0.180 ms); login sin cambio | Respaldo `backup_pre_indices_20260917_194800.dump`; rollback documentado (`DROP INDEX`) |
| OpenCode | Redactar informe y commitear | *"necesito que crees una carpeta llamada 'TP 5'... con un archivo llamado 'informe_mediciones.md'... Ademas quiero que hagas un commit y un push, en el commit quiero que ponga 'subo tp 5 parte A'"* | `TP 5/informe_mediciones.md` con la comparación antes/después y la justificación del índice descartado | **Aceptado.** Se justificó por qué **no** se crea índice para el login (el UNIQUE ya hace *point lookup* de 1 fila; un parcial solo agregaría costo de escritura) | Commit `8024521` "subo tp 5 parte A" + push |

---

## 2. Vistas de negocio y seguridad (parte 4.3)

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Qué generó | Se aceptó / se descartó — por qué | Verificación realizada |
| :---------- | :-------------- | :---------------------- | :--------- | :-------------------------------- | :--------------------- |
| OpenCode + PostgreSQL | Detectar vistas faltantes | *"dime tres vistas que hacen falta para la base de datos"* | Propuesta de `v_pedidos_resumen` (requerida por HU-PED-01 de `queries.sql`, que hoy falla), `v_catalogo_productos` y `v_usuarios_segura` | **Aceptado.** Se detectó que la base **no tiene ninguna vista** y que `queries.sql` referencia `v_pedidos_resumen`, inexistente | `\dv` en el clon → "No se encontraron vistas"; `grep` del uso en `queries.sql` |
| OpenCode | Vista con criterio de seguridad | *"necesito que una de las vistas siga el siguiente criterio de seguridad: exponer usuario sin la columna contraseña, de modo que pueda otorgarse SELECT sobre esa vista sin dar acceso a la tabla base"* | `v_usuarios_segura` con `id_usuario, nombre, apellido, mail, celular, rol` (sin `contrasena`) | **Aceptado.** Se documentó el `GRANT SELECT ON v_usuarios_segura` sin privilegios sobre la tabla base | `information_schema.columns` → `contrasena` en la vista = 0 |
| OpenCode + PostgreSQL | Restringir a vigentes | *"quiero que la vista muestre solo los usuarios vigentes"* | Filtro `WHERE eliminado = FALSE` en `v_usuarios_segura` | **Aceptado**, consistente con el patrón soft-delete del esquema | `count(v_usuarios_segura)` = 20.000 = `count(usuario WHERE eliminado=FALSE)` |
| OpenCode + `psql` | Crear archivo de vistas y verificar equivalencia | *"crea un archivo views.sql con las vistas incluidas en la raiz del proyecto. En el archivo 'informe_mediciones'... agrega la verificacion de equivalencia de cada vista contra la consulta manual"* | `views.sql` (3 vistas, `BEGIN/COMMIT`, cabecera de protocolo) y sección de verificación en el informe | **Aceptado.** Se creó en el clon y se verificó equivalencia **simétrica** `EXCEPT` (vista ↔ consulta manual) | 0 filas en ambas direcciones para las 3 vistas; commit `2cd5a85` "subo parte 4.2 parte b" + push |

---

## 3. Vista materializada y mantenimiento (parte 4.3)

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Qué generó | Se aceptó / se descartó — por qué | Verificación realizada |
| :---------- | :-------------- | :---------------------- | :--------- | :-------------------------------- | :--------------------- |
| OpenCode + `psql` | Elegir la consulta más costosa | *"Elegí una consulta SQL que use funciones como SUM(), COUNT() o AVG(), agrupadas con GROUP BY, y que junte varias tablas. Ademas no debe tener un indice creado en el archivo indices.sql. Entre todas las consultas que cumplan esos requisitos elige la mas costosa"* | Comparación de costos con `EXPLAIN` de C1–C5 y elección de **C4** (TP4 Parte 3, Consulta 2 correlacionada), costo ≈ **1,6×10⁹** (~19.000× la siguiente) | **Aceptado.** C4 cumple los 3 requisitos (SUM/COUNT, GROUP BY, 3 tablas) y ninguna de las 12 propuestas de `indices.sql` la cubre | Contraste de índices existentes en el clon (`pg_indexes`) y contra `indices.sql` |
| OpenCode + PostgreSQL | Crear la vista materializada | *"crea la vista materializada correspondiente, con WITH DATA y un índice único que permita, a futuro, un REFRESH CONCURRENTLY"* | `mv_top_productos_categoria` (definición `ROW_NUMBER` equivalente a C4) `WITH DATA` + `CREATE UNIQUE INDEX uq_mv_top_productos_puesto (categoria, id_producto)` | **Aceptado.** Se materializó la versión equivalente con ventana (build rápido) en lugar de la correlacionada O(n²); el índice único es requisito del refresh concurrente | `EXCEPT` simétrico MV ↔ consulta inline = 0 filas; `REFRESH ... CONCURRENTLY` OK (248 ms) |
| OpenCode + `psql` | Comparar MV vs consulta original | *"compara el tiempo de ejecucion entre la vista materializada y la consulta original"* | Tabla comparativa: MV **0.087 ms** vs original C4 **242.733 ms** vs C3 inline **237.930 ms** (**≈2.790×**) | **Aceptado.** Se registró también que C4 midió 242 ms (no el valor catastrófico del costo estimado) porque el planner sobreestima el CTE `agg` | `EXPLAIN (ANALYZE, BUFFERS, TIMING)` de las 3 variantes; sección 9.4 del informe |
| OpenCode | Documentar frecuencia de refresh e impacto | *"Documentar con qué frecuencia debería ejecutarse el REFRESH MATERIALIZED VIEW dado el uso esperado del reporte, y qué implica para los usuarios que el dato no se actualice en cada REFRESH"* | Sección **9.6** del informe + comentario en `views.sql`: refresh **diario 03:00** vía `pg_cron`, uso de `CONCURRENTLY` (no bloquea lecturas, requiere índice único, fuera de transacción) y tabla de implicaciones de desactualización (hasta ~24 h) | **Aceptado.** Cadencia diaria nocturna acorde a un KPI de facturación acumulada de gestión, no operativo | Commit `d8af50e` "subo parte 4.3" + push |

---

## 4. Resumen de artefactos generados

- `TP 5/informe_mediciones.md` — comparación `EXPLAIN ANALYZE` antes/después, justificación del índice descartado, verificación de equivalencia de vistas y de la vista materializada, y política de refresh.
- `views.sql` — 3 vistas (`v_pedidos_resumen`, `v_catalogo_productos`, `v_usuarios_segura`) y la vista materializada `mv_top_productos_categoria` con su índice único.
- Índices aplicados en el clon: `idx_producto_categoria_precio`, `idx_pedido_usuario_fecha`.

## 5. Resguardos de seguridad y trazabilidad

- Ninguna sentencia (índices, vistas, MV) se ejecutó sobre la base principal; todo se probó en el clon de trabajo.
- Cambios estructurales precedidos por `pg_dump` (`backup_pre_indices_20260917_194800.dump`, `backup_pre_mv_20260917_203453.dump`).
- Rollbacks documentados en el informe (`DROP INDEX`, `DROP MATERIALIZED VIEW`).
- Todo el trabajo IA-originado fue verificado empíricamente en el motor (planes reales, `EXCEPT`, `REFRESH CONCURRENTLY`).

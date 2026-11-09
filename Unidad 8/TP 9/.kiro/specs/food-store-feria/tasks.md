# Implementation Plan

- [x] 1. Esquema de la tablet
  - `movil/schema_sqlite.sql`: `PRAGMA foreign_keys = ON`, 4 tablas STRICT + `snapshot_servidor`, los CHECK, las FK y la vista `v_catalogo_local`
  - _Requirements: 5.1, 6.1_

- [x] 2. Pruebas locales de la tablet
  - `movil/pruebas_sqlite.sql`: un borrador guardado con COMMIT, otro deshecho con ROLLBACK, C1 y C7
  - _Requirements: 5.1, 6.1_

- [x] 3. Instantánea del servidor
  - [x] 3.1 Vista `servidor/v_snapshot_movil.sql` (centavos, booleanos 0/1, lápidas, fecha)
  - [x] 3.2 Exportar con `\copy` y cargar con `movil/cargar_snapshot.sql` (UPSERT sin DELETE)
  - _Requirements: 2.2_

- [x] 4. Semáforo
  - `movil/semaforo.sql`: solo PENDIENTE, rojo antes que amarillo, motivo por producto, sin evaluar si no hay instantánea
  - _Requirements: 1.1, 2.1, 3.1, 4.2_

- [x] 5. Casos de sincronización
  - [x] 5.1 `servidor/preparar_casos.sql` y `servidor/restaurar_copia.sql` (cambios solo en la copia)
  - [x] 5.2 `movil/casos/01_borradores.sql`, `02_c2_aceptar.sql` y `03_c6_reenvio.sql`
  - [x] 5.3 `casos_2c.sh`, que orquesta todo y guarda la evidencia
  - _Requirements: 1.1, 1.2, 2.1, 2.2, 3.1, 4.1, 4.2_

- [x] 6. Verificar que PostgreSQL no cambió
  - `servidor/verificar_servidor.sql`: pedidos, detalles, stock total y huella md5, antes y después
  - _Requirements: 3.2_

- [x] 7. README con el orden para crear todo desde cero

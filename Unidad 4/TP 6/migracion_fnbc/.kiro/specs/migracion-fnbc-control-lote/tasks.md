# Implementation Plan

- [x] 1. Base de prueba con el esquema heredado
  - `sql/00_setup_legado.sql`: maestras mínimas, responsables sintéticos 801 y 802, y `control_lote_almacen` con la instancia del enunciado
  - _Requirements: 1.1_

- [x] 2. Script de ida
  - [x] 2.1 Precondiciones: la DF R → D validada sobre los datos, tablas destino inexistentes
  - [x] 2.2 Crear `responsable_deposito` y `control_lote` con PK y FK
  - [x] 2.3 Poblar con `INSERT … SELECT` desde la tabla heredada
  - [x] 2.4 Renombrar la heredada a `_legado` y crear la vista `control_lote_almacen`
  - [x] 2.5 Verificación sin pérdida (`EXCEPT` en los dos sentidos + conteo) dentro de la transacción
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 3.1, 3.2, 4.1, 4.2_

- [x] 3. Script de vuelta (plan de reversión)
  - [x] 3.1 Precondiciones: existe `_legado` y `control_lote_almacen` es la vista
  - [x] 3.2 Bloqueo por datos no representables, más el escape `fnbc.forzar_reversion`
  - [x] 3.3 Sincronizar el legado (DELETE → UPDATE → INSERT) con lo vigente
  - [x] 3.4 Desarmar FNBC, restaurar el nombre y verificar con `EXCEPT`
  - _Requirements: 5.1, 5.2, 5.3_

- [x] 4. Banco de pruebas
  - `prueba_migracion.sh`: escenarios E1 a E6 sobre bases descartables, con evidencia en `evidencias/prueba_migracion.txt`
  - _Requirements: todos_

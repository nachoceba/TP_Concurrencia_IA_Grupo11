# Requirements Document

## Introduction

Food Store hereda la tabla `control_lote_almacen (lote_id, deposito_id, responsable_control_id)`, con PK (lote_id, deposito_id). La regla de negocio "cada responsable pertenece a un único depósito" crea la DF `responsable_control_id → deposito_id`, cuyo determinante no es superclave: la tabla no está en FNBC y tiene anomalías de inserción, borrado y actualización (ver `tp_fnbc_control_lote.sql`, puntos a–d).

Esta spec define la **migración de datos** al esquema FNBC (`responsable_deposito` + `control_lote`) sin pérdida, dentro de transacciones reversibles, y con un **plan de reversión obligatorio**.

## Requirements

### Requirement 1 · Validar las DF contra los datos reales (REQ-01)

**User Story:** Como responsable de la base, quiero comprobar que los datos cumplen la DF antes de descomponer, para no perder información con una descomposición basada en una regla que los datos no respetan.

#### Acceptance Criteria

1. WHEN se ejecuta la migración THEN THE SYSTEM SHALL verificar, antes de crear cualquier objeto, que ningún `responsable_control_id` aparezca con más de un `deposito_id`. **Se prueba con: E1 (pasa) y E5 (falla)**
2. IF la DF no se cumple THEN THE SYSTEM SHALL abortar la transacción sin dejar cambios. **Se prueba con: E5**
3. IF las tablas destino ya existen o falta la tabla heredada THEN THE SYSTEM SHALL abortar. **Se prueba con: precondiciones del paso 0**

### Requirement 2 · Esquema en FNBC (REQ-02)

**User Story:** Como diseñador, quiero que cada DF quede garantizada por una clave, para eliminar las anomalías.

#### Acceptance Criteria

1. THE SYSTEM SHALL crear `responsable_deposito` con PK `responsable_control_id` (garantiza R → D) y `control_lote` con PK (`lote_id`, `responsable_control_id`) y FK a `responsable_deposito`. **Se prueba con: E1**
2. WHEN se da de alta un responsable sin lote THEN THE SYSTEM SHALL permitirlo, cosa que la tabla heredada no permitía. **Se prueba con: E2**

### Requirement 3 · Migración sin pérdida (REQ-03)

**User Story:** Como dueño de los datos, quiero la certeza de que no se perdió ni se inventó ninguna fila.

#### Acceptance Criteria

1. THE SYSTEM SHALL poblar las tablas nuevas con `INSERT … SELECT` desde la tabla heredada, sin cargar valores a mano. **Se prueba con: E1**
2. WHEN termina la carga THEN THE SYSTEM SHALL comparar origen y resultado con `EXCEPT` en los dos sentidos más el conteo, y abortar ante cualquier diferencia. **Se prueba con: E1 (0 faltantes, 0 sobrantes)**

### Requirement 4 · Compatibilidad (REQ-04)

**User Story:** Como desarrollador de la app, quiero que las consultas existentes sigan funcionando después de migrar.

#### Acceptance Criteria

1. THE SYSTEM SHALL exponer una vista con el nombre original `control_lote_almacen`, que reconstruya la relación con un JOIN. **Se prueba con: E1**
2. THE SYSTEM SHALL conservar la tabla heredada como `control_lote_almacen_legado` hasta cerrar el período de validación. **Se prueba con: E1**

### Requirement 5 · Plan de reversión obligatorio (REQ-05)

**User Story:** Como responsable de la base, quiero poder volver al esquema heredado si la migración trae problemas, sin perder lo cargado después.

#### Acceptance Criteria

1. WHEN se ejecuta la reversión THEN THE SYSTEM SHALL sincronizar el legado con el estado vigente (borrar, actualizar e insertar) y restaurar el nombre original, en una sola transacción. **Se prueba con: E4**
2. IF existen responsables sin lote (no representables en el esquema heredado) THEN THE SYSTEM SHALL bloquear la reversión, salvo `fnbc.forzar_reversion = on` explícito, que deja una advertencia. **Se prueba con: E3 (bloqueada) y E6 (forzada)**
3. WHEN termina la reversión THEN THE SYSTEM SHALL verificar con `EXCEPT` que la tabla restaurada es igual a lo que mostraba el esquema nuevo. **Se prueba con: E4, E6**

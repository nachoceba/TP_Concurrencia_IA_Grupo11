# Requirements Document

## Introduction

Food Store vende con un food truck en una feria sin señal. Una tablet guarda en SQLite una copia del catálogo y los borradores de pedido; cuando vuelve la señal, se simula la sincronización contra una instantánea de PostgreSQL con un semáforo (RECHAZADO / CONFLICTO / SIMULADO_APROBADO).

**Regla de oro:** el móvil propone, el servidor dispone. La tablet nunca modifica precio, stock ni pedidos del servidor, y `SIMULADO_APROBADO` no es una venta.

**Alcance:** base de la tablet (`movil/schema_sqlite.sql`), carga de la instantánea (`movil/cargar_snapshot.sql`) y semáforo (`movil/semaforo.sql`). Fuera de alcance: app móvil, interfaz y API real de sincronización.

## Requirements

### Requirement 1 · Conflicto de precio (REQ-01)

**User Story:** Como vendedor del food truck, quiero que la tablet me avise cuando el precio de un producto cambió en el servidor, para que el cliente decida si acepta el precio nuevo antes de confirmar.

#### Acceptance Criteria

1. WHEN el precio actual de algún producto de una solicitud PENDIENTE es distinto del `precio_centavos_visto` AND ningún producto tiene un problema de rechazo THEN THE SYSTEM SHALL marcar la solicitud como `CONFLICTO` e indicar en `motivo` el precio visto y el precio actual. **Se prueba con: C2**
2. WHEN el cliente acepta el precio nuevo THEN THE SYSTEM SHALL copiar el precio de `producto_cache` al borrador y crear una solicitud nueva (otro UUID) en `PENDIENTE`, dejando la anterior en `CONFLICTO`. **Se prueba con: C2**

### Requirement 2 · Rechazo (REQ-02)

**User Story:** Como encargado, quiero que se rechacen los borradores imposibles de cumplir, para no prometer productos que no existen o no alcanzan.

#### Acceptance Criteria

1. WHEN algún producto de la solicitud no existe en la instantánea, fue dado de baja, no está disponible o pide más unidades que el stock del servidor THEN THE SYSTEM SHALL marcar la solicitud como `RECHAZADO` con el motivo de cada producto en problema. **Se prueba con: C3, C4**
2. WHEN se carga una instantánea con un producto dado de baja THEN THE SYSTEM SHALL ocultarlo del catálogo sin borrar su fila de `producto_cache`. **Se prueba con: C4**

### Requirement 3 · Aprobación simulada sin tocar el servidor (REQ-03)

**User Story:** Como dueño del negocio, quiero que la simulación nunca cambie la base real, para que precio, stock y ventas los decida solo PostgreSQL.

#### Acceptance Criteria

1. WHEN una solicitud PENDIENTE coincide en existencia, disponibilidad, stock y precio con la instantánea THEN THE SYSTEM SHALL marcarla como `SIMULADO_APROBADO`. **Se prueba con: C5**
2. THE SYSTEM SHALL NOT crear pedidos ni modificar stock o precios en PostgreSQL durante la simulación. **Se prueba con: verificación final (`servidor/verificar_servidor.sql`)**

### Requirement 4 · Idempotencia (REQ-04)

**User Story:** Como vendedor, quiero poder reintentar el envío cuando se corta la señal sin duplicar el pedido.

#### Acceptance Criteria

1. IF llega una solicitud con un `solicitud_uuid` que ya existe en `cola_sync` THEN THE SYSTEM SHALL rechazarla por clave primaria sin crear filas nuevas. **Se prueba con: C6**
2. WHILE una solicitud no esté en `PENDIENTE` THE SYSTEM SHALL excluirla de nuevas corridas del semáforo. **Se prueba con: C6**

### Requirement 5 · Datos inválidos (REQ-05)

**User Story:** Como vendedor, quiero que la tablet no guarde borradores mal cargados.

#### Acceptance Criteria

1. IF se intenta guardar un ítem con cantidad menor o igual a 0, con un producto que no está en `producto_cache` o con una forma de pago fuera de EFECTIVO/TARJETA/TRANSFERENCIA THEN THE SYSTEM SHALL rechazar la operación sin dejar filas nuevas. **Se prueba con: C7**

### Requirement 6 · Catálogo offline (REQ-06)

**User Story:** Como vendedor en la feria sin señal, quiero ver el catálogo vendible para poder tomar pedidos.

#### Acceptance Criteria

1. WHILE la tablet no tenga conexión con el servidor THE SYSTEM SHALL permitir consultar el catálogo vendible (disponible y no eliminado) solo con los datos locales. **Se prueba con: C1**

## Restricciones

- Importes en centavos enteros (`INTEGER`), nunca `REAL`.
- Tablas `STRICT` y `PRAGMA foreign_keys = ON` en cada conexión.
- Sin datos personales en la tablet: el cliente se identifica solo con `usuario_id`.
- Todo se prueba sobre una copia de PostgreSQL (`food_store_tp8`) con datos de demo.

# Design Document

## Overview

Tres piezas: una vista en PostgreSQL que publica la instantánea del catálogo, una base SQLite en la tablet con copias y propuestas, y un semáforo en SQL puro que compara las propuestas con la instantánea. No hay app ni Python.

## Architecture

```
PostgreSQL (copia food_store_tp8)                 Tablet (SQLite foodstore_movil.db)
 producto ──► v_snapshot_movil ──\copy CSV──►  snapshot_servidor ──UPSERT──► producto_cache
                                                                               │ (catálogo offline, C1)
                                                 pedido_borrador ◄── vendedor ─┘
                                                 item_borrador (precio_centavos_visto)
                                                 cola_sync (solicitud_uuid, PENDIENTE)
                                                        │
                                       semaforo.sql: compara con snapshot_servidor
                                                        ▼
                                RECHAZADO / CONFLICTO / SIMULADO_APROBADO  (+ motivo)
```

## Components and Interfaces

| Componente | Archivo | Entrada → salida |
|---|---|---|
| Vista de la instantánea | `servidor/v_snapshot_movil.sql` | `producto` → filas con `precio_centavos`, `disponible` y `eliminado` como 0/1, más `fecha_snapshot` |
| Esquema de la tablet | `movil/schema_sqlite.sql` | — → 5 tablas STRICT + `v_catalogo_local` |
| Carga | `movil/cargar_snapshot.sql` | `servidor_snapshot.csv` → `snapshot_servidor` → UPSERT en `producto_cache` |
| Semáforo | `movil/semaforo.sql` | `cola_sync` PENDIENTE × `snapshot_servidor` → estado + motivo |

## Data Models

| Tabla | Clave | Reglas |
|---|---|---|
| `producto_cache` | `id` | `precio_centavos >= 0`; `disponible`, `eliminado` ∈ {0,1}; `fecha_copia` |
| `pedido_borrador` | `id_local` (UUID) | `forma_pago` ∈ {EFECTIVO, TARJETA, TRANSFERENCIA}; `usuario_id > 0` |
| `item_borrador` | (`id_local`, `producto_id`) | FK a las dos anteriores; `cantidad > 0` |
| `cola_sync` | `solicitud_uuid` | `estado` ∈ {PENDIENTE, CONFLICTO, RECHAZADO, SIMULADO_APROBADO}; evaluada ⇔ `evaluada_en` no nulo |
| `snapshot_servidor` | `id_producto` | Destino del CSV, con los mismos CHECK |

## Decisiones

| Decisión | Por qué |
|---|---|
| La vista exporta centavos enteros y booleanos como 0/1 | El CSV entra directo en tablas STRICT, sin los `t/f` de psql ni los errores de redondeo de `REAL`. |
| Las bajas lógicas viajan como lápidas y `producto_cache` se actualiza con UPSERT, sin `DELETE` | Un borrador viejo puede apuntar a un producto dado de baja, y la FK tiene que seguir siendo válida (C4). |
| `item_borrador` guarda `precio_centavos_visto` | Es lo que aceptó el cliente; sin ese dato no se puede detectar el CONFLICTO (C2). |
| Una solicitud por intento, con `solicitud_uuid` como clave de idempotencia | Aceptar un precio nuevo genera otra solicitud y la vieja queda como historial. Reenviar el mismo UUID falla (C6). |
| Primero rojo y después amarillo | Si hay un problema de stock y además un cambio de precio, aceptar el precio no salva la solicitud. |
| El semáforo evalúa cada solicitud por separado | `SIMULADO_APROBADO` no reserva stock; el control real es el `FOR UPDATE` de `sp_crear_pedido` en el servidor. |

## Error Handling

- Las violaciones de CHECK y FK abortan la sentencia. La app hace `ROLLBACK` del borrador completo (C7).
- Si `snapshot_servidor` está vacía, el semáforo no evalúa nada; si no, todo saldría RECHAZADO por "producto inexistente".
- Un UUID repetido da `UNIQUE constraint failed` (C6).

## Testing Strategy

- `movil/pruebas_sqlite.sql`: COMMIT, ROLLBACK, C1 y C7.
- `casos_2c.sh`: C2 a C6 de punta a punta, con evidencia en `docs/evidencias/casos_2c.txt`.
- `servidor/verificar_servidor.sql` antes y después: pedidos, detalles, stock total y una huella md5 del stock.

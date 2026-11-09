# Design Document

## Overview

La migración son dos scripts transaccionales, ida (`sql/01_migracion_fnbc.sql`) y vuelta (`sql/02_reversion_fnbc.sql`), más un banco de pruebas (`prueba_migracion.sh`) que los ejercita sobre bases descartables.

## Architecture

```
ANTES                                   DESPUÉS (FNBC)
control_lote_almacen (tabla)            responsable_deposito (PK responsable)   ← R → D
  PK (lote, deposito)          ──IDA──► control_lote (PK lote, responsable)     ← {L, R} clave
  DF oculta R → D                        control_lote_almacen  (VISTA = JOIN)    ← compatibilidad
                               ◄─VUELTA─ control_lote_almacen_legado (tabla)     ← respaldo
```

## Descomposición

- DF: {L, D} → R y R → D. Claves candidatas: {L, D} y {L, R}. R → D viola FNBC, porque {R} no es superclave.
- Algoritmo sobre la DF violatoria: R1 = {R, D} (`responsable_deposito`) y R2 = {L, R} (`control_lote`).
- **Sin pérdida (Heath):** el atributo común R es clave de R1.
- **Preservación de dependencias:** R → D queda garantizada por la PK de R1. **{L, D} → R no se preserva**: ninguna tabla tiene a la vez L, D y R. En el esquema nuevo se podría cargar `(504, 801)` y `(504, 805)` con 801 y 805 en el mismo depósito, y el lote 504 quedaría con dos responsables en un depósito. Es el costo conocido de llevar a FNBC un esquema que está en 3FN.
  - **Decisión:** se acepta, porque la anomalía que importaba al negocio era la de R → D. Si se quisiera garantizar también {L, D} → R, habría que agregar un trigger en `control_lote` que rechace un segundo responsable del mismo depósito para el mismo lote.
  - **Efecto en la reversión:** si hubiera datos así, el `INSERT` en el legado chocaría con su PK (lote, depósito) y la transacción se desharía entera. La vuelta no puede dejar el legado inconsistente.

## Transacciones y reversibilidad

| Script | Atomicidad | Si algo falla |
|---|---|---|
| Ida | `BEGIN … COMMIT` con las validaciones dentro (`DO … RAISE EXCEPTION`) | PostgreSQL deshace todo: la tabla heredada queda intacta (E5) |
| Vuelta | Ídem | El esquema FNBC queda intacto (E3) |

- La tabla heredada **no se borra** al migrar: se renombra a `_legado`. La vuelta no depende de un respaldo externo.
- La vuelta **no recupera una foto vieja**: sincroniza el legado con la verdad vigente (lo que muestra la vista), así no se pierde lo cargado después de migrar.
- Lo que el esquema viejo no puede representar (responsables sin lote) bloquea la vuelta. Perder datos tiene que ser una decisión explícita (`fnbc.forzar_reversion`).

## Retiro del legado

Cuando termina el período de validación (sin incidentes y con las consultas de la app migradas a las tablas nuevas): `pg_dump -t control_lote_almacen_legado` y después `DROP TABLE control_lote_almacen_legado`. Desde ese momento, la vuelta exige restaurar ese dump.

## Testing Strategy

`prueba_migracion.sh` → `evidencias/prueba_migracion.txt`:

| Escenario | Qué prueba |
|---|---|
| E1 | Ida feliz: DF validada, 2 + 3 filas migradas, vista igual al origen |
| E2 | Alta de un responsable sin lote (la anomalía de inserción resuelta) |
| E3 | Vuelta bloqueada por datos no representables; el esquema nuevo queda intacto |
| E4 | Vuelta con cambios posteriores (lotes 504 y 505): sin pérdida |
| E5 | Ida rechazada porque los datos violan la DF; nada cambia |
| E6 | Vuelta forzada, con advertencia |

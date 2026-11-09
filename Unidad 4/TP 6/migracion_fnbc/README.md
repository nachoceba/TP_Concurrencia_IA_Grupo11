# Migración FNBC de `control_lote_almacen`, con plan de reversión

Spec Kiro: `.kiro/specs/migracion-fnbc-control-lote/` (requirements · design · tasks).

| Archivo | Qué hace |
|---|---|
| `sql/00_setup_legado.sql` | Crea la tabla heredada con la instancia del enunciado (solo en una base de prueba) |
| `sql/01_migracion_fnbc.sql` | **Ida**: valida la DF sobre los datos, crea el esquema FNBC, migra con `INSERT … SELECT`, deja la vista de compatibilidad y verifica sin pérdida. Todo en una transacción |
| `sql/02_reversion_fnbc.sql` | **Vuelta** (plan de reversión): sincroniza el legado con lo vigente, desarma FNBC y verifica. Se bloquea si hay datos no representables |
| `prueba_migracion.sh` | Corre los escenarios E1 a E6 sobre bases descartables y guarda `evidencias/prueba_migracion.txt` |

```bash
cd "Unidad 4/TP 6/migracion_fnbc"
./prueba_migracion.sh
```

Resultados: E1, ida sin pérdida (3 filas, 0 faltantes y 0 sobrantes). E2, alta de un responsable sin lote. E3, vuelta bloqueada. E4, vuelta con lotes nuevos sin pérdida (5 filas). E5, ida rechazada por violar la DF. E6, vuelta forzada con advertencia.

# Food Store - Entrega Parcial BD II (parcial_BD)

Motor: PostgreSQL 16+ | Cumple Requisito Tecnico Exclusivo: ENUM, TIMESTAMPTZ,
JSONB (`pedido.metadatos`), IDENTITY, PL/pgSQL, CALL, triggers con transition tables.

## Orden estricto de ejecucion

1. `01_schema.sql` — DDL (ENUMs, tablas, CHECKs, indices base)
2. `04_objects.sql` — vistas + funcion + triggers ROW + triggers STATEMENT + `sp_crear_pedido`
3. `02_data_demo.sql` — seed chico para demo en vivo (18 prod / 7 ped)
   **O** `03_data_masivo.sql` — seed grande para indices (50k / 200k). Son EXCLUYENTES.
4. `05_indices.sql` — indices parciales/covering/trigram
5. `06_transacciones.sql` — por bloques, en 2 terminales (punto 9)
6. `07_queries.sql` — HU + analiticas (punto 6)
7. `08_INFORME_TECNICO.md` — informe acompañante (punto sec.4 parcial.md)

## Despliegue (clon, protocolo_seguridad)

```bash
createdb -U postgres food_store_parcial
psql -U postgres -d food_store_parcial -f 01_schema.sql
psql -U postgres -d food_store_parcial -f 04_objects.sql
psql -U postgres -d food_store_parcial -f 02_data_demo.sql
psql -U postgres -d food_store_parcial -f 05_indices.sql
# 06 y 07 por bloques en psql interactivo
```

Seguridad: probar cada archivo con `BEGIN; \i <file>` + `ROLLBACK` antes del
`COMMIT` definitivo; `pg_dump -Fc` antes de cambios estructurales;
`VACUUM ANALYZE` tras indices/datos masivos.

## Mapeo a checklist parcial.md (9 puntos)

| Punto | Evidencia |
|---|---|
| 1 ER / 2 Relacional / 3 3FN-BCNF | `08_INFORME_TECNICO.md` sec.1-2 + `![DER](imagenes/der.png)` |
| 4 DDL | `01_schema.sql` |
| 5 Soft delete | `eliminado` en 5 tablas + parciales en `05_indices.sql` |
| 6 DML avanzada | `07_queries.sql` A-F (HAVING, RANK, subconsulta) |
| 7 CHECK/UNIQUE + triggers | CHECKs en `01`, `fn_trg_subtotal/total` en `04` |
| 8 vistas/funcion/procedimiento | 6 vistas + MV + `calcular_total_pedido` + `CALL sp_crear_pedido` en `04` |
| 9 transacciones | `06_transacciones.sql` + capturas en `08` sec.5 |

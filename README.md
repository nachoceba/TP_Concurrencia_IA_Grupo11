# Proyecto Bases de Datos II — Grupo 11

## Integrantes (orden alfabético)

1. Ciro Cattáneo
2. Ignacio Ceballos
3. Santiago Copia
4. Franco Gagliardi
5. Emmanuel Miranda
6. Ramiro Quiroga

## Contexto

Proyecto correspondiente a la Tecnicatura en Programación de la UTN FRM — Asignatura de Bases de Datos II.

## Stack

- **Base de datos**: PostgreSQL 18.6 con ENUM types, soft deletes (`eliminado BOOLEAN`) y triggers con tablas de transición
- **Esquema**: `parcial_BD/01_schema.sql` (tipos → categoria → producto → usuario → pedido → detalle_pedido) | `schema.sql` (original con SERIAL)
- **Frontend**: App servida en `localhost:8080`
- **Motor exigido**: PostgreSQL 16+ — ENUM, TIMESTAMPTZ, JSONB, IDENTITY, PL/pgSQL, CALL, triggers con transition tables

## Estructura del proyecto

- `parcial_BD/` — Entrega Parcial BD II (`01_schema.sql` → `08_INFORME_TECNICO.md` + `TPI_Base_de_Datos_Food_Store_Corrected.pdf`):
  - `01_schema.sql` — DDL (ENUMs, tablas con IDENTITY, CHECKs, índices base)
  - `02_data_demo.sql` — seed chico para demo en vivo (18 prod / 7 ped)
  - `03_data_masivo.sql` — seed grande para índices (50k prod / 200k ped). Excluyente con `02`.
  - `04_objects.sql` — vistas (6) + MV + funcion `calcular_total_pedido` + triggers ROW + STATEMENT con transition tables + `sp_crear_pedido`
  - `05_indices.sql` — índices parciales, compuestos, covering, trigram
  - `06_transacciones.sql` — pruebas de concurrencia (COMMIT/ROLLBACK, READ COMMITTED vs REPEATABLE READ, FOR UPDATE)
  - `07_queries.sql` — HU + consultas analíticas (HAVING, RANK, subconsulta)
  - `08_INFORME_TECNICO.md` — informe acompañante (secciones 1-9)
  - `TPI_Base_de_Datos_Food_Store_Corrected.pdf` — informe técnico original corregido
- `schema.sql` — DDL original del esquema (SERIAL)
- `data.sql` — DML de carga masiva sintética (categorías, productos, usuarios, pedidos y detalles)
- `views.sql` — Vistas originales del proyecto
- `indices.sql` — Índices de optimización (TP3)
- `queries.sql` — Consultas avanzadas originales (JOINs, agregaciones, funciones de ventana)
- `sp_crear_pedido.sql` — Procedimiento sp_crear_pedido con entrada JSONB
- `objects.sql` — Triggers de subtotal y total del pedido
- `AGENTS.md` — Instrucciones del proyecto para agentes
- `protocolo_seguridad.md` — Protocolo de trabajo con la base de datos
- `TP 2/` — TP2 Concurrencia e IA (`Parte 1/` integridad referencial, `Parte 2/` concurrencia y anomalías, `Parte 3/` lectura crítica)
- `TP 3/` — TP3 Optimización (capturas `EXPLAIN ANALYZE`, `2.2) Tabla de resultados.xlsx`, `3.4) Lectura crítica.xlsx`, `DUIA.md`, consultas y spec en `4)/`)
- `TP 4/` — TP4: vistas materializadas y análisis (`DUIA.md`, `Parte3_Consultas.md`, tablas de resultados)
- `TP 5/` — TP5 Mediciones y optimización final (`informe_mediciones.md`, `DUIA.md`)

## Orden de ejecución del parcial

```bash
psql -d food_store_parcial -f 01_schema.sql
psql -d food_store_parcial -f 04_objects.sql
psql -d food_store_parcial -f 02_data_demo.sql
psql -d food_store_parcial -f 05_indices.sql
# 06 y 07 por bloques en psql interactivo
```

## Configuración del repositorio remoto

- **Remoto**: `origin` → `https://github.com/nachoceba/TP2_ConcURREncia_IA_Grupo11.git`
- **Rama principal**: `main`

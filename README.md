# Proyecto Bases de Datos II — Grupo 11 · Food Store

## Integrantes (orden alfabético)

1. Ciro Cattáneo
2. Ignacio Ceballos
3. Santiago Copia
4. Franco Gagliardi
5. Emmanuel Miranda
6. Ramiro Quiroga

## Contexto

Proyecto de la Tecnicatura Universitaria en Programación (UTN FRM), asignatura Bases de Datos II. Es el proyecto integrador «Food Store»: la capa de datos completa, relacional, documental y móvil.

## Stack

- **PostgreSQL 16+** (motor exigido; el grupo usa 17.10 y 18.6): ENUM, TIMESTAMPTZ, JSONB, IDENTITY, PL/pgSQL, CALL, borrado lógico (`eliminado BOOLEAN`) y triggers con tablas de transición.
- **MongoDB 8.0** (Unidad 7): colección `pedido` como modelo documental de lectura.
- **SQLite 3.37+** (Unidad 8): base de la tablet del food truck, que trabaja sin conexión.
- **Esquema de referencia**: `parcial_BD/01_schema.sql` (tipos → categoria → producto → usuario → pedido → detalle_pedido).

## Informe técnico del TPI (segunda entrega, unidades 4 a 8)

**[`TPI/informe_tecnico_tpi.pdf`](TPI/informe_tecnico_tpi.pdf)** (fuente: `TPI/informe_tecnico_tpi.md`). Resume qué se implementó en cada unidad, cómo se probó, qué resultados dio y qué decisiones de diseño se tomaron.

## Estructura del proyecto

### Base del proyecto

- `parcial_BD/` — Primera entrega (parcial):
  - `01_schema.sql` — DDL (ENUMs, tablas con IDENTITY, CHECKs, índices base)
  - `02_data_demo.sql` — seed chico para la demo en vivo (18 productos, 7 pedidos)
  - `03_data_masivo.sql` — seed grande para índices (50k productos, 200k pedidos). Excluyente con `02`
  - `04_objects.sql` — vistas (6), MV, función `calcular_total_pedido`, triggers ROW y STATEMENT con tablas de transición, `sp_crear_pedido`
  - `05_indices.sql` — índices parciales, compuestos, covering y trigram
  - `06_transacciones.sql` — pruebas de concurrencia (COMMIT/ROLLBACK, READ COMMITTED vs. REPEATABLE READ, FOR UPDATE)
  - `07_queries.sql` — historias de usuario y consultas analíticas (HAVING, RANK, subconsultas)
  - `TPI_Base_de_Datos_Food_Store_Corrected.pdf` — informe técnico de la primera entrega
- `schema.sql`, `data.sql`, `views.sql`, `indices.sql`, `queries.sql`, `roles.sql` — scripts originales del esquema (con SERIAL) usados en los primeros TPs
- `AGENTS.md` — instrucciones del proyecto para los agentes de IA
- `protocolo_seguridad.md` — protocolo de trabajo con la base: clon, prueba con `BEGIN … ROLLBACK` y respaldo antes de cambios estructurales

### Trabajos prácticos por unidad

| Carpeta | Tema | Contenido principal |
|---|---|---|
| `Unidad 2/TP 2/` | Concurrencia e IA | `Parte 1/` integridad referencial · `Parte 2/` concurrencia y anomalías · `Parte 3/` lectura crítica |
| `Unidad 2/TP 3/` | Optimización | Tablas de resultados, lectura crítica, `DUIA.md`, consultas y spec en `4)/` |
| `Unidad 3/TP 4/` | Vistas materializadas y análisis | `Parte3_Consultas.md`, resultados, hallazgos, `DUIA.md` |
| `Unidad 4/TP 5/` | Mediciones, índices, vistas y MV | `informe_mediciones.md`, `DUIA.md` |
| `Unidad 4/TP 6/` | **Normalización (FNBC) y desnormalización controlada** | `tp_fnbc_control_lote.sql`, `tp_desnormalizacion_top_categorias.sql`, `Informe_TP_Unidad_4.docx` · `migracion_fnbc/`: spec Kiro, migración de ida, **plan de reversión** y prueba de 6 escenarios |
| `Unidad 5/TP6/` | **Administración y seguridad** | `sql/roles.sql` (mínimo privilegio, spec Kiro en `docs/kiro_roles_spec/`), auditoría, simulacro de acceso indebido · `sql/simulacro_live.sh` + `docs/log_auditoria_live.txt`: auditoría activada en vivo, con log real del motor · `BITACORA.md` |
| `Unidad 6/TP7/` | **Mantenimiento** | `SPEC_U6.md`, `scripts/backup_foodstore.sh`, `scripts/restore_test.sh`, `sql/health_check.sql`, `sql/maintenance.sql`, `informe_u6.pdf` (post-incidente) |
| `Unidad 7/TP 8/` | **NoSQL (MongoDB)** | `foodstore.mongodb.js` (modelo y validador R1/R2), `consultas.mongodb.js`, `consultas_postgresql.sql`, `informe_u7.pdf` |
| `Unidad 8/TP 9/` | **Base móvil e integración** | Spec Kiro en `.kiro/specs/food-store-feria/`, `movil/` (SQLite, semáforo), `servidor/`, `casos_2c.sh` (casos C2 a C6), `docs/informe.pdf`, bitácora y DUIA |
| `TPI/` | **Segunda entrega del TPI** | `informe_tecnico_tpi.pdf` / `.md` |

Cada carpeta de TP tiene su propio README o informe con el orden de ejecución.

## Orden de ejecución de la base del proyecto

```bash
createdb food_store_parcial
psql -d food_store_parcial -f parcial_BD/01_schema.sql
psql -d food_store_parcial -f parcial_BD/04_objects.sql
psql -d food_store_parcial -f parcial_BD/02_data_demo.sql      # o 03_data_masivo.sql
psql -d food_store_parcial -f parcial_BD/05_indices.sql
# 06 y 07 por bloques, en psql interactivo
```

Siguiendo el `protocolo_seguridad.md`, los scripts de cada unidad se corren sobre una **copia** de esta base (`createdb -T food_store_parcial <copia>`), nunca sobre la original.

## Configuración del repositorio remoto

- **Remoto**: `origin` → `https://github.com/nachoceba/TP_Concurrencia_IA_Grupo11`
- **Rama principal**: `main`

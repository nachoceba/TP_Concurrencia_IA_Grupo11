# Unidad 8 · TP 9 · Food Store en la feria — Grupo 11 · Bases de Datos II

Base offline de la tablet del food truck (SQLite), simulación de sincronización con PostgreSQL (semáforo) y cierre de la capa de datos.

**Regla de oro:** el móvil propone, el servidor dispone. La tablet no modifica precio, stock ni pedidos del servidor, y `SIMULADO_APROBADO` **no es una venta**.

## Requisitos

- PostgreSQL 16+ (`psql` en el PATH) y SQLite 3.37+ (`sqlite3` en el PATH, o DB Browser for SQLite)
- En Windows: correr los comandos desde **Git Bash**
- Esta carpeta está en `Unidad 8/TP 9/` del repo del grupo (`TP_Concurrencia_IA_Grupo11`). Los comandos se corren desde acá adentro

## Crear todo desde cero (en este orden)

```bash
cd "Unidad 8/TP 9"

# 1. Copia de PRUEBAS del servidor (nunca la base real)
createdb food_store_tp8
psql -d food_store_tp8 -f ../../parcial_BD/01_schema.sql
psql -d food_store_tp8 -f ../../parcial_BD/04_objects.sql
psql -d food_store_tp8 -f ../../parcial_BD/02_data_demo.sql
#    (o, si ya tenés la base:  createdb -T food_store food_store_tp8)

# 2. Vista de la instantánea (2.a)
psql -d food_store_tp8 -f servidor/v_snapshot_movil.sql

# 3. Base de la tablet (1.b)
cd movil
rm -f foodstore_movil.db
sqlite3 foodstore_movil.db < schema_sqlite.sql

# 4. Exportar la instantánea y cargarla en la tablet (2.a)
psql -d food_store_tp8 -c "\copy (SELECT * FROM v_snapshot_movil) TO 'servidor_snapshot.csv' CSV HEADER"
sqlite3 foodstore_movil.db < cargar_snapshot.sql

# 5. Pruebas de la tablet (1.c): COMMIT/ROLLBACK, C1 y C7 (los errores de C7 son esperados)
sqlite3 foodstore_movil.db < pruebas_sqlite.sql
cd ..

# 6. Casos C2 a C6 de punta a punta + verificación de PostgreSQL (2.b y 2.c)
./casos_2c.sh            # evidencia en docs/evidencias/casos_2c.txt
```

Si tu PostgreSQL pide usuario o contraseña: `PGUSER=postgres PGPASSWORD=... ./casos_2c.sh` (y `-U postgres` en los `psql` de los pasos 1 y 2).

`casos_2c.sh` se puede repetir: restaura la copia del servidor (`servidor/restaurar_copia.sql`) y recrea sus borradores.

## Estructura

```
Unidad 8/TP 9/
├── README.md
├── .kiro/specs/food-store-feria/   4.a · spec Kiro (requirements · design · tasks)
├── casos_2c.sh                   2.c · orquesta C2 a C6 y guarda la evidencia
├── movil/
│   ├── schema_sqlite.sql         1.b · tablas STRICT de la tablet
│   ├── pruebas_sqlite.sql        1.c · COMMIT/ROLLBACK, C1, C7
│   ├── cargar_snapshot.sql       2.a · .import del CSV + UPSERT a producto_cache
│   ├── semaforo.sql              2.b · ROJO / AMARILLO / VERDE
│   ├── servidor_snapshot.csv     2.a · última instantánea exportada
│   ├── foodstore_movil.db        base de la tablet (estado final de los casos)
│   └── casos/                    2.c · borradores, aceptación de C2, reenvío de C6
├── servidor/                     (solo sobre la copia food_store_tp8)
│   ├── v_snapshot_movil.sql      2.a · vista de la instantánea
│   ├── preparar_casos.sql        2.c · sube un precio (C2) y da de baja un producto (C4)
│   ├── restaurar_copia.sql       deshace preparar_casos.sql
│   ├── verificar_servidor.sql    2.c · pedidos y stock sin cambios (huella md5)
│   ├── fix_sp_crear_pedido.sql   3.c · H1 corregido
│   └── validacion_restore_extra.sql  3.c · H4 corregido
└── docs/
    ├── informe.pdf / informe.md  1.a, 2.c, 3.a, 3.b, 3.c
    ├── evidencias/casos_2c.txt
    ├── kiro/                     copia de la spec (formato de entrega)
    ├── bitacora_ia.md
    └── DUIA.md
```

## Ensayo de defensa (10 min)

1. **Mapa** (3 min): informe 3.a, con quién manda sobre cada dato.
2. **Caso en vivo** (4 min): C2. Correr `./casos_2c.sh`, mostrar el CONFLICTO, la aceptación y la solicitud nueva en verde, y cerrar con `verificar_servidor.sql` igual antes y después.
3. **Hallazgo de la IA** (3 min): H3, el descartado. Por qué acumular stock en la tablet contradice la regla de oro, y cómo lo resuelve el `FOR UPDATE` de `sp_crear_pedido`.

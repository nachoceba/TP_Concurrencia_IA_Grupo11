# Ejercicio de Lectura Crítica — Análisis y Corrección de Scripts SQL

---

## Script 1

```sql
-- Generado para: dar de baja las funciones de películas retiradas de cartel
UPDATE funcion
SET activa = FALSE;
```

### Qué haría realmente tal como está escrito

Afectaría **todas las filas** de la tabla `funcion`, sin excepción. Al no contar con una cláusula `WHERE`, la sentencia `UPDATE` aplica el cambio a **el 100 % de los registros** de la tabla, estableciendo `activa = FALSE` para todas las funciones — incluyendo las que aún están en cartel y activas.

### Por qué no coincide con la consigna

La consigna dice que el objetivo es **dar de baja únicamente las funciones de películas retiradas de cartel**. Lo que el script produce es un apagado total de todas las funciones, lo cual contradice completamente la intención. Se trataría de un `UPDATE` sin filtro, equivalente a un `UPDATE` sin `WHERE`, que en contexto de producción causaría la baja lógica inmediata de **todos** los eventos funcionales del sistema, sin distinción de estado.

### Versión corregida

Se debe agregar una cláusula `WHERE` que identifique únicamente las funciones cuya película fue retirada de cartel. Asumiendo que la tabla `funcion` cuenta con una columna de fecha de fin o una bandera de retiro:

```sql
UPDATE funcion
SET activa = FALSE
WHERE fecha_fin < CURRENT_DATE;
```

> **Nota:** El nombre de la columna de filtro (`fecha_fin`) es una suposición razonable. La corrección requiere confirmar el nombre real de la columna que indica el retiro de cartel en el esquema de la cátedra. Cualquier condición equivalente que distinga funciones vencidas/retiradas de las activas es válida (por ejemplo, `WHERE retirada_de_cartel = TRUE`, `WHERE fecha_salida < CURRENT_DATE`, etc.).

---

## Script 2

```sql
-- Generado para: limpiar las categorías sin productos asociados
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto);
```

### Qué haría realmente tal como está escrito

El script intenta eliminar todas las categorías cuyo `id` no aparezca en el resultado de la subconsulta `SELECT categoria_id FROM producto`. Sin embargo, en PostgreSQL la cláusula `NOT IN` tiene un **comportamiento trampa con valores NULL**:

- Si **al menos una fila** de la subconsulta devuelve `categoria_id IS NULL`, la expresión `id NOT IN (valor1, valor2, NULL)` se evalúa como **UNKNOWN** para cualquier `id` (por la semántica ternaria de las comparaciones en SQL: `1 = NULL` → UNKNOWN, y `NOT IN` con cualquier UNKNOWN → UNKNOWN).
- Como el `WHERE` de `DELETE` solo ejecuta la eliminación donde la condición es `TRUE`, y aquí el resultado es `UNKNOWN`, **ninguna fila se elimina**.
- Esto ocurre incluso si hay categorías legítimamente sin productos asociados.

En resumen: si existe al menos un producto con `categoria_id` en `NULL`, el script **no borra nada** (resultado silencioso, sin errores, sin filas afectadas). Si no hay NULLs en `categoria_id`, funciona correctamente.

### Por qué no coincide con la consigna

La consigna dice que el objetivo es **limpiar las categorías sin productos asociados**. El script falla silenciosamente cuando la tabla `producto` contiene filas con `categoria_id IS NULL`, que es un caso perfectamente válido y frecuente (un producto sin categoría asignada). La presencia de NULLs en la subconsulta rompe la lógica de `NOT IN`, haciendo que el resultado real sea **cero filas eliminadas**, cuando en realidad podrían haber categorías huérfanas esperando ser limpiadas.

### Versión corregida

La forma idiomática y segura en PostgreSQL es reemplazar `NOT IN` por `NOT EXISTS`, que no se ve afectado por valores NULL:

```sql
DELETE FROM categoria c
WHERE NOT EXISTS (
    SELECT 1
    FROM producto p
    WHERE p.categoria_id = c.id
);
```

Alternativa válida (agregando el filtro de NULL a la subconsulta original):

```sql
DELETE FROM categoria
WHERE id NOT IN (
    SELECT categoria_id
    FROM producto
    WHERE categoria_id IS NOT NULL
);
```

**Recomendación:** `NOT EXISTS` es la opción preferida porque:
1. No requiere modificar la subconsulta para excluir NULLs.
2. El optimizador de PostgreSQL generalmente la maneja de forma más eficiente.
3. Es la práctica estándar ante subconsultas que podrían contener NULLs.

---

## Resumen de correcciones

| Script | Problema original | Filas afectadas realmente | Corrección aplicada |
|---|---|---|---|
| **Script 1** | Falta cláusula `WHERE` | Todas las filas de `funcion` | Se agregó `WHERE fecha_fin < CURRENT_DATE` para limitar solo a funciones retiradas |
| **Script 2** | `NOT IN` con valores NULL en la subconsulta | Cero filas (si hay NULLs) | Se reemplazó `NOT IN` por `NOT EXISTS` para eliminar correctamente categorías sin productos |

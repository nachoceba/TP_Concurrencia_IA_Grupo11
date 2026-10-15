================================================================================
INFORME TÉCNICO DE VERIFICACIÓN DE EQUIVALENCIA - FOOD STORE
================================================================================

--------------------------------------------------------------------------------
CONSULTA 1: RESUMEN Y AGREGACIÓN CON CRITERIO DE CORTE
--------------------------------------------------------------------------------
* Lógica Comparada:
    - Versión A (JOINs Directos): Unifica las tablas categoria, producto, 
      detalle_pedido y pedido en una única consulta, realizando el agrupamiento 
      y filtrado HAVING sobre el conjunto global resultante.
    - Versión B (Modular con CTE): Pre-agrega las ventas a nivel de producto 
      filtrando pedidos válidos dentro de una Expresión de Tabla Común (WITH), 
      y posteriormente vincula los resultados reducidos con las tablas 
      producto y categoria.

* Criterios de Equivalencia Semántica:
    1. Universo de datos: Ambos enfoques procesan exactamente las mismas filas, 
       garantizando el filtro de borrado lógico (eliminado = FALSE) en todas 
       las entidades y restringiendo el estado del pedido a 'TERMINADO'.
    2. Operaciones numéricas: La suma de unidades (SUM(cantidad)) y de montos 
       (SUM(subtotal)) produce los mismos valores algebraicos por categoría.
    3. Condición de corte: El filtro HAVING SUM(...) > 500000 evalúa los 
       mismos totales calculados, omitiendo las mismas categorías.

* Prueba Lógica de Validación (PostgreSQL):
    Se confirma la equivalencia estricta mediante el operador de conjuntos EXCEPT. 
    La siguiente consulta debe retornar exactamente 0 filas:

    ( <Consulta 1 - Versión A> )
    EXCEPT
    ( <Consulta 1 - Versión B> )


--------------------------------------------------------------------------------
CONSULTA 2: FILTRADO RELACIONAL MEDIANTE SUBCONSULTA (CLIENTES TOP)
--------------------------------------------------------------------------------
* Lógica Comparada:
    - Versión A (Subconsulta en HAVING): Evalúa la condición de corte en la 
      cláusula HAVING de la consulta principal, ejecutando una subconsulta 
      escalar anidada que calcula el promedio global de facturación por cliente.
    - Versión B (Modular con CTE y CROSS JOIN): Separa el problema en dos 
      bloques WITH: uno para consolidar los totales por usuario y otro para 
      extraer el promedio general. Luego vincula ambos mediante un CROSS JOIN 
      y aplica el filtro en la cláusula WHERE.

* Criterios de Equivalencia Semántica:
    1. Determinación de la métrica (Barra Promedio): Ambas versiones calculan 
       idéntico promedio global, derivado únicamente de usuarios no eliminados 
       con pedidos no eliminados en estado 'TERMINADO'.
    2. Selección de entidades: Ambos métodos aplican el predicado de corte 
       (total_gastado > promedio) sobre los mismos identificadores de usuario.
    3. Formato y Restricción: Ambos métodos retornan la misma estructura 
       (id_usuario, cliente_nombre, mail, total_gastado), idéntico ordenamiento 
       descendente y el mismo límite de registros (LIMIT 20).

* Prueba Lógica de Validación (PostgreSQL):
    Se confirma la equivalencia estricta mediante el operador de conjuntos EXCEPT. 
    La siguiente consulta debe retornar exactamente 0 filas:

    ( <Consulta 2 - Versión A> )
    EXCEPT
    ( <Consulta 2 - Versión B> )

================================================================================
CONCLUSIÓN TÉCNICA:
Ambas alternativas para cada consulta son semánticamente equivalentes y 
garantizan la integridad del resultado esperado bajo las especificaciones fijadas.
================================================================================
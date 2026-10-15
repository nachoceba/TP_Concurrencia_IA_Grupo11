================================================================================
ESPECIFICACIÓN TÉCNICA DE CONSULTAS SQL (SPEC) - FOOD STORE
================================================================================

--------------------------------------------------------------------------------
CONSULTA 1: RESUMEN Y AGREGACIÓN CON CRITERIO DE CORTE
--------------------------------------------------------------------------------
* Propósito:
    Identificar el volumen total facturado y la cantidad de unidades vendidas 
    por categoría, considerando únicamente ventas efectivas y filtrando aquellas 
    categorías que superen un umbral significativo de facturación.

* Tablas involucradas:
    - categoria
    - producto
    - detalle_pedido
    - pedido

* Filtros de borrado lógico (Soft Delete):
    - categoria.eliminado = FALSE
    - producto.eliminado = FALSE
    - pedido.eliminado = FALSE

* Filtros de negocio adicionales:
    - pedido.estado = 'TERMINADO'

* Columnas de salida:
    - categoria_nombre (categoria.nombre)
    - unidades_vendidas (SUM(detalle_pedido.cantidad))
    - monto_total (SUM(detalle_pedido.subtotal))

* Agrupamiento:
    - GROUP BY categoria.id_categoria, categoria.nombre

* Criterio de corte / Filtrado de agregación (HAVING):
    - Retener solo categorías cuya facturación total sea mayor a $500.000:
      HAVING SUM(detalle_pedido.subtotal) > 500000

* Ordenamiento:
    - ORDER BY monto_total DESC


--------------------------------------------------------------------------------
CONSULTA 2: FILTRADO RELACIONAL MEDIANTE SUBCONSULTA (CLIENTES TOP)
--------------------------------------------------------------------------------
* Propósito:
    Listar los usuarios activos cuyo gasto total acumulado sea estrictamente 
    mayor al promedio general gastado por el total de usuarios con compras 
    válidas en el sistema.

* Tablas involucradas:
    - usuario
    - pedido

* Filtros de borrado lógico (Soft Delete):
    - usuario.eliminado = FALSE (tanto en consulta principal como en subconsulta)
    - pedido.eliminado = FALSE (tanto en consulta principal como en subconsulta)

* Filtros de negocio adicionales:
    - pedido.estado = 'TERMINADO'

* Columnas de salida:
    - id_usuario (usuario.id_usuario)
    - cliente_nombre (Concatenación: usuario.nombre || ' ' || usuario.apellido)
    - mail (usuario.mail)
    - total_gastado (SUM(pedido.total))

* Subconsulta (Cálculo de umbral):
    - Calcular el promedio global gastado por cliente:
      SELECT AVG(total_usuario)
      FROM (
          SELECT SUM(pedido.total) AS total_usuario
          FROM pedido
          JOIN usuario ON usuario.id_usuario = pedido.usuario_id
          WHERE pedido.eliminado = FALSE
            AND usuario.eliminado = FALSE
            AND pedido.estado = 'TERMINADO'
          GROUP BY pedido.usuario_id
      ) sub

* Agrupamiento y Criterio de corte:
    - GROUP BY usuario.id_usuario, usuario.nombre, usuario.apellido, usuario.mail
    - HAVING SUM(pedido.total) > (Subconsulta de promedio global)

* Ordenamiento y Límite:
    - ORDER BY total_gastado DESC
    - LIMIT 20
================================================================================
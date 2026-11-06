# Consigna 6 · Consulta a la herramienta de IA

- **Herramienta:** Claude (Anthropic), modelo Claude Opus 5.5, usado desde Claude Code.
- **Fecha:** 05/11/2026

## Prompt enviado

> Tenemos el proyecto Food Store en PostgreSQL. El modelo actual es relacional:
> `pedido` (id_pedido, fecha, estado ENUM, forma_pago ENUM, total, usuario_id FK),
> `detalle_pedido` (id_detalle_pedido, pedido_id FK, producto_id FK, cantidad,
> precio_unitario congelado al momento de la venta, subtotal), `producto`, `categoria`
> y `usuario`. `subtotal` y `total` se calculan con triggers. La aplicación accede con
> mucha frecuencia al **pedido completo** (cabecera + líneas + cliente) y necesitamos
> **conservar la coherencia de cantidades y precios**. Compará PostgreSQL y MongoDB
> para almacenar y consultar los pedidos. ¿Conviene mantener PostgreSQL, pasar ese
> subconjunto a MongoDB o combinar ambas tecnologías?

## Respuesta (resumen, afirmaciones numeradas)

- **A1.** En MongoDB conviene embeber las líneas y un snapshot del cliente dentro del
  documento del pedido: el pedido completo se lee en una sola operación, sin JOIN, y la
  escritura de un único documento es atómica, así que cabecera y líneas no pueden quedar
  a medio guardar.
- **A2.** MongoDB no tiene claves foráneas ni triggers declarativos como los de
  PostgreSQL; la coherencia de cantidades, precios y totales queda a cargo de la
  aplicación.
- **A3.** Si confirmar un pedido también descuenta stock en `producto`, en MongoDB eso
  toca dos documentos/colecciones y requiere transacciones multi-documento, que sólo
  funcionan sobre un replica set o clúster fragmentado.
- **A4.** Con pocos miles de pedidos, PostgreSQL resuelve la lectura del pedido completo
  con índices sobre `detalle_pedido.pedido_id` e incluso puede devolverlo como documento
  con `jsonb_build_object`/`jsonb_agg`.
- **Recomendación de la IA:** mantener PostgreSQL como sistema de registro; usar MongoDB
  sólo como modelo de lectura (historial de pedidos, catálogo) si la carga de lectura lo
  justifica, alimentado desde PostgreSQL.

El contraste de A1 y A2 con documentación oficial y con el laboratorio está en el informe
(sección 6).

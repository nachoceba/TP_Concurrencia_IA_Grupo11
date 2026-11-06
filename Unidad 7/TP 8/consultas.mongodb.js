// =============================================================================
// TP Unidad 7 · Food Store en MongoDB · Consultas (Consigna 4)
// Grupo 11 · Bases de Datos II
// Requiere haber ejecutado antes foodstore.mongodb.js
// Ejecución: VS Code (MongoDB Playground) o  mongosh --file consultas.mongodb.js
// =============================================================================

use("foodstore");

const proy = { _id: 0, id_pedido: 1, estado: 1, fecha: 1, total: 1 };

// a) Todos los pedidos, con su identificador y estado ------------------------
print("\n== a) Todos los pedidos");
printjson(db.pedido.find({}, proy).sort({ id_pedido: 1 }).toArray());

// b) Pedidos en un estado existente: TERMINADO --------------------------------
//    Se excluyen los dados de baja lógica, igual que en PostgreSQL.
print("\n== b) Pedidos TERMINADO");
const filtroEstado = { estado: "TERMINADO", eliminado: false };
printjson(db.pedido.find(filtroEstado, proy).sort({ id_pedido: 1 }).toArray());
print("cantidad b): " + db.pedido.countDocuments(filtroEstado));

// c) Pedidos que contienen un producto: Coca-Cola Original 1.5L (id_producto 11)
//    Se busca por el ID conservado (no por nombre) dentro del arreglo de líneas.
//    "lineas.$" muestra sólo la línea que coincidió.
print("\n== c) Pedidos con el producto 11 (Coca-Cola Original 1.5L)");
const filtroProducto = { "lineas.producto.id_producto": 11, eliminado: false };
printjson(db.pedido
  .find(filtroProducto, { _id: 0, id_pedido: 1, estado: 1, "lineas.$": 1 })
  .sort({ id_pedido: 1 }).toArray());
print("cantidad c): " + db.pedido.countDocuments(filtroProducto));

// d) Pedidos con total superior a $14.000 --------------------------------------
//    Umbral = ticket promedio de los pedidos migrados (14.214,29), redondeado
//    a 14.000: recupera los pedidos "por encima de lo habitual".
print("\n== d) Ticket promedio (justificación del umbral)");
printjson(db.pedido.aggregate([
  { $group: { _id: null, ticket_promedio: { $avg: "$total" }, pedidos: { $sum: 1 } } },
  { $project: { _id: 0, pedidos: 1, ticket_promedio: { $round: ["$ticket_promedio", 2] } } },
]).toArray());

print("\n== d) Pedidos con total > 14000");
const filtroTotal = { total: { $gt: NumberDecimal("14000") } };
printjson(db.pedido.find(filtroTotal, proy).sort({ total: -1 }).toArray());
print("cantidad d): " + db.pedido.countDocuments(filtroTotal));

// Control de coherencia (Consigna 3): pedidos con total != suma de subtotales
print("\n== Control: pedidos descuadrados (esperado 0)");
print(db.pedido.countDocuments({ $expr: { $ne: ["$total", { $sum: "$lineas.subtotal" }] } }));

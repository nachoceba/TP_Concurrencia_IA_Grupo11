// =============================================================================
// TP Unidad 7 · Food Store en MongoDB · Migración (Consignas 1, 2 y 3)
// Grupo 11 · Bases de Datos II
//
// Origen: base relacional Food Store (parcial_BD/01_schema.sql + 04_objects.sql
//         + 02_data_demo.sql). Se migran los 7 pedidos existentes y sus 16 líneas.
//         No se agregaron pedidos de prueba: todos los datos vienen del seed demo.
// Tablas que intervienen: pedido (PK id_pedido) · detalle_pedido (PK id_detalle_pedido,
//         FK pedido_id, FK producto_id) · usuario (PK id_usuario, vía pedido.usuario_id)
//         · producto (PK id_producto) · categoria (PK id_categoria, vía producto.categoria_id)
//
// Modelo: una colección "pedido", un documento por pedido.
//   - cliente  -> objeto embebido (snapshot de usuario: id + nombre + apellido)
//   - lineas   -> arreglo embebido (una entrada por fila de detalle_pedido)
//   - lineas[].producto -> objeto embebido (id_producto, nombre, categoria)
//   - Identificadores conservados: id_pedido, id_usuario, id_detalle_pedido,
//     id_producto, id_categoria.
//   - Importes en Decimal128 (equivalente a NUMERIC(10,2)); cantidad en int.
//
// Reglas de integridad que conserva el validador (Consigna 3):
//   R1. subtotal de cada línea = cantidad * precio_unitario (precio histórico
//       congelado, igual que trg_subtotal en PostgreSQL).
//   R2. total del pedido = suma de los subtotales de sus líneas (igual que
//       trg_total / calcular_total_pedido en PostgreSQL).
//   + id_pedido único, estado y forma_pago restringidos a los valores del ENUM,
//     cantidad >= 1 e importes >= 0 (CHECKs del schema relacional).
//
// Ejecución: VS Code (MongoDB Playground) o  mongosh --file foodstore.mongodb.js
// Es re-ejecutable: borra y recrea la colección.
// =============================================================================

use("foodstore");

db.pedido.drop();

db.createCollection("pedido", {
  validator: {
    $and: [
      {
        $jsonSchema: {
          bsonType: "object",
          required: ["id_pedido", "fecha", "estado", "forma_pago", "total",
                     "cliente", "lineas", "eliminado"],
          properties: {
            id_pedido: { bsonType: ["int", "long", "double"], minimum: 1 },
            fecha: { bsonType: "date" },
            estado: { enum: ["PENDIENTE", "CONFIRMADO", "TERMINADO", "CANCELADO"] },
            forma_pago: { enum: ["EFECTIVO", "TARJETA", "TRANSFERENCIA"] },
            total: { bsonType: "decimal", minimum: 0 },
            metadatos: { bsonType: "object" },
            eliminado: { bsonType: "bool" },
            cliente: {
              bsonType: "object",
              required: ["id_usuario", "nombre", "apellido"],
              properties: {
                id_usuario: { bsonType: ["int", "long", "double"], minimum: 1 },
                nombre: { bsonType: "string" },
                apellido: { bsonType: "string" },
              },
            },
            lineas: {
              bsonType: "array",
              minItems: 1,
              items: {
                bsonType: "object",
                required: ["id_detalle_pedido", "producto", "cantidad",
                           "precio_unitario", "subtotal"],
                properties: {
                  id_detalle_pedido: { bsonType: ["int", "long", "double"], minimum: 1 },
                  producto: {
                    bsonType: "object",
                    required: ["id_producto", "nombre"],
                    properties: {
                      id_producto: { bsonType: ["int", "long", "double"], minimum: 1 },
                      nombre: { bsonType: "string" },
                      categoria: { bsonType: "object" },
                    },
                  },
                  cantidad: { bsonType: "int", minimum: 1 },
                  precio_unitario: { bsonType: "decimal", minimum: 0 },
                  subtotal: { bsonType: "decimal", minimum: 0 },
                },
              },
            },
          },
        },
      },
      // R1: subtotal = cantidad * precio_unitario en TODAS las líneas
      {
        $expr: {
          $allElementsTrue: [{
            $map: {
              input: "$lineas",
              as: "l",
              in: { $eq: ["$$l.subtotal", { $multiply: ["$$l.cantidad", "$$l.precio_unitario"] }] },
            },
          }],
        },
      },
      // R2: total = suma de subtotales
      { $expr: { $eq: ["$total", { $sum: "$lineas.subtotal"}] } },
    ],
  },
  validationLevel: "strict",
  validationAction: "error",
});

// id_pedido es la PK de origen: no puede repetirse
db.pedido.createIndex({ id_pedido: 1 }, { unique: true });
// Índice multikey para buscar pedidos por producto (consulta c)
db.pedido.createIndex({ "lineas.producto.id_producto": 1 });

// Categorías y productos usados (mismos IDs que en PostgreSQL)
const cat = {
  pizzas:       { id_categoria: 1, nombre: "Pizzas" },
  empanadas:    { id_categoria: 2, nombre: "Empanadas" },
  hamburguesas: { id_categoria: 3, nombre: "Hamburguesas" },
  bebidas:      { id_categoria: 4, nombre: "Bebidas" },
  postres:      { id_categoria: 5, nombre: "Postres" },
};
const prod = (id_producto, nombre, categoria) => ({ id_producto, nombre, categoria });
const linea = (id_detalle_pedido, producto, cantidad, precio, subtotal) => ({
  id_detalle_pedido,
  producto,
  cantidad: NumberInt(cantidad),
  precio_unitario: NumberDecimal(precio),
  subtotal: NumberDecimal(subtotal),
});

const P = {
  muzzarella:  prod(1,  "Muzzarella", cat.pizzas),
  especial:    prod(2,  "Especial de Jamon y Morrones", cat.pizzas),
  fugazzeta:   prod(3,  "Fugazzeta Rellena", cat.pizzas),
  empCarne:    prod(5,  "Empanada Carne Cuchillo", cat.empanadas),
  empJyQ:      prod(6,  "Empanada Jamon y Queso", cat.empanadas),
  burgerSimp:  prod(8,  "Burger Simple Cheese", cat.hamburguesas),
  burgerDoble: prod(9,  "Burger Doble Bacon", cat.hamburguesas),
  burgerVeg:   prod(10, "Burger Veggie NotMeat", cat.hamburguesas),
  coca:        prod(11, "Coca-Cola Original 1.5L", cat.bebidas),
  cerveza:     prod(12, "Cerveza Patagonia 730ml", cat.bebidas),
  agua:        prod(13, "Agua Mineral 500ml", cat.bebidas),
  flan:        prod(14, "Flan Casero", cat.postres),
};

// Clientes: sólo los datos esenciales (sin mail, celular ni contraseña)
const C = {
  u1: { id_usuario: 1, nombre: "Milton",  apellido: "Gimenez" },
  u2: { id_usuario: 2, nombre: "Ana",     apellido: "Garis" },
  u4: { id_usuario: 4, nombre: "Lucia",   apellido: "Fernandez" },
  u5: { id_usuario: 5, nombre: "Roberto", apellido: "Gomez" },
};

db.pedido.insertMany([
  {
    id_pedido: 1, fecha: ISODate("2026-06-15T12:00:00Z"), estado: "TERMINADO",
    forma_pago: "EFECTIVO", metadatos: { canal: "mostrador" }, cliente: C.u1,
    lineas: [
      linea(1, P.muzzarella, 2, "4500.00", "9000.00"),
      linea(2, P.coca,       2, "2200.00", "4400.00"),
    ],
    total: NumberDecimal("13400.00"), eliminado: false,
  },
  {
    id_pedido: 2, fecha: ISODate("2026-06-20T12:00:00Z"), estado: "TERMINADO",
    forma_pago: "TARJETA", metadatos: { canal: "web", cuotas: 3 }, cliente: C.u2,
    lineas: [
      linea(3, P.burgerDoble, 2, "8200.00", "16400.00"),
      linea(4, P.cerveza,     2, "3500.00", "7000.00"),
      linea(5, P.flan,        2, "2800.00", "5600.00"),
    ],
    total: NumberDecimal("29000.00"), eliminado: false,
  },
  {
    id_pedido: 3, fecha: ISODate("2026-07-05T12:00:00Z"), estado: "TERMINADO",
    forma_pago: "TRANSFERENCIA", metadatos: { canal: "app" }, cliente: C.u1,
    lineas: [
      linea(6, P.empCarne, 12, "950.00", "11400.00"),
      linea(7, P.empJyQ,    6, "900.00", "5400.00"),
      linea(8, P.coca,      1, "2200.00", "2200.00"),
    ],
    total: NumberDecimal("19000.00"), eliminado: false,
  },
  {
    id_pedido: 4, fecha: ISODate("2026-07-18T12:00:00Z"), estado: "TERMINADO",
    forma_pago: "TARJETA", metadatos: { canal: "app" }, cliente: C.u4,
    lineas: [
      linea(9,  P.fugazzeta, 1, "6200.00", "6200.00"),
      linea(10, P.coca,      1, "2200.00", "2200.00"),
    ],
    total: NumberDecimal("8400.00"), eliminado: false,
  },
  {
    id_pedido: 5, fecha: ISODate("2026-08-01T12:00:00Z"), estado: "CONFIRMADO",
    forma_pago: "EFECTIVO", metadatos: { canal: "web" }, cliente: C.u2,
    lineas: [
      linea(11, P.especial, 1, "5800.00", "5800.00"),
      linea(12, P.empCarne, 6, "950.00",  "5700.00"),
      linea(13, P.agua,     2, "1200.00", "2400.00"),
    ],
    total: NumberDecimal("13900.00"), eliminado: false,
  },
  {
    id_pedido: 6, fecha: ISODate("2026-08-10T12:00:00Z"), estado: "PENDIENTE",
    forma_pago: "TRANSFERENCIA", metadatos: { canal: "web" }, cliente: C.u5,
    lineas: [
      linea(14, P.burgerSimp, 1, "6500.00", "6500.00"),
      linea(15, P.coca,       1, "2200.00", "2200.00"),
    ],
    total: NumberDecimal("8700.00"), eliminado: false,
  },
  {
    id_pedido: 7, fecha: ISODate("2026-08-12T12:00:00Z"), estado: "CANCELADO",
    forma_pago: "EFECTIVO", metadatos: { motivo: "cliente" }, cliente: C.u4,
    lineas: [
      linea(16, P.burgerVeg, 1, "7100.00", "7100.00"),
    ],
    total: NumberDecimal("7100.00"), eliminado: false,
  },
]);

// -----------------------------------------------------------------------------
// Verificación post-migración (comparar con PostgreSQL: 7 pedidos, 16 líneas)
// -----------------------------------------------------------------------------
print("pedidos migrados: " + db.pedido.countDocuments());
print("lineas migradas:  " + db.pedido.aggregate([
  { $project: { n: { $size: "$lineas" } } },
  { $group: { _id: null, n: { $sum: "$n" } } },
]).toArray()[0].n);

// Prueba de las reglas: estos documentos DEBEN ser rechazados por el validador
try {
  db.pedido.insertOne({
    id_pedido: 99, fecha: new Date(), estado: "PENDIENTE", forma_pago: "EFECTIVO",
    cliente: C.u1, eliminado: false, total: NumberDecimal("9000.00"),
    lineas: [linea(99, P.muzzarella, 2, "4500.00", "8000.00")], // R1 rota
  });
  print("ERROR: se aceptó un subtotal incoherente");
} catch (e) {
  print("R1 OK, rechazado: " + e.errmsg);
}
try {
  db.pedido.insertOne({
    id_pedido: 99, fecha: new Date(), estado: "PENDIENTE", forma_pago: "EFECTIVO",
    cliente: C.u1, eliminado: false, total: NumberDecimal("1.00"), // R2 rota
    lineas: [linea(99, P.muzzarella, 2, "4500.00", "9000.00")],
  });
  print("ERROR: se aceptó un total incoherente");
} catch (e) {
  print("R2 OK, rechazado: " + e.errmsg);
}

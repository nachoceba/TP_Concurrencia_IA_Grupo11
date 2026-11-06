use("foodstore");

db.pedido.insertMany([
  {
    id_pedido: 1,
    fecha: "2026-03-14",
    estado: "CONFIRMADO",
    producto: {
      nombre: "Hamburguesa Clásica",
      precio: 8500.0,
      descripcion: "Hamburguesa clásica con carne, queso y vegetales",
      stock: 120,
      imagen: "img/producto_1.jpg",
      disponible: true,
      categoria: {
        nombre: "Hamburguesas",
        descripcion: "Hamburguesas gourmet, clasicas y dobles",
        eliminado: false,
      },
      eliminado: false,
    },
    total: 8500.0,
    forma_pago: "TARJETA",
    eliminado: false,
  },
  {
    id_pedido: 2,
    fecha: "2025-11-27",
    estado: "TERMINADO",
    producto: {
      nombre: "Pizza Especial de la Casa",
      precio: 12500.0,
      descripcion: "Pizza especial de la casa con ingredientes seleccionados",
      stock: 75,
      imagen: "img/producto_2.jpg",
      disponible: true,
      categoria: {
        nombre: "Pizzas",
        descripcion: "Pizzas a la piedra y al molde",
        eliminado: false,
      },
      eliminado: false,
    },
    total: 12500.0,
    forma_pago: "EFECTIVO",
    eliminado: false,
  },
  {
    id_pedido: 3,
    fecha: "2024-12-08",
    estado: "PENDIENTE",
    producto: {
      nombre: "Empanada de Carne",
      precio: 1800.0,
      descripcion: "Empanada de carne al horno",
      stock: 240,
      imagen: "img/producto_3.jpg",
      disponible: true,
      categoria: {
        nombre: "Empanadas",
        descripcion: "Empanadas fritas y al horno",
        eliminado: false,
      },
      eliminado: false,
    },
    total: 1800.0,
    forma_pago: "TRANSFERENCIA",
    eliminado: false,
  },
  {
    id_pedido: 4,
    fecha: "2026-08-19",
    estado: "CANCELADO",
    producto: {
      nombre: "Bebida Gaseosa",
      precio: 2500.0,
      descripcion: "Bebida gaseosa de 1,5 litros",
      stock: 0,
      imagen: "img/producto_4.jpg",
      disponible: false,
      categoria: {
        nombre: "Bebidas",
        descripcion: "Gaseosas, aguas, cervezas y jugos",
        eliminado: false,
      },
      eliminado: false,
    },
    total: 2500.0,
    forma_pago: "TARJETA",
    eliminado: false,
  },
  {
    id_pedido: 5,
    fecha: "2025-06-02",
    estado: "CONFIRMADO",
    producto: {
      nombre: "Helado Artesanal",
      precio: 4500.0,
      descripcion: "Helado artesanal en vasito",
      stock: 60,
      imagen: "img/producto_5.jpg",
      disponible: true,
      categoria: {
        nombre: "Helados",
        descripcion: "Helados artesanales por kilo y vasito",
        eliminado: false,
      },
      eliminado: false,
    },
    total: 4500.0,
    forma_pago: "EFECTIVO",
    eliminado: false,
  },
]);

db.detalle_pedido.insertMany([
  {
    pedido_id: 1,
    cantidad: 1,
    precio_unitario: 8500.0,
    subtotal: 8500.0,
  },
  {
    pedido_id: 2,
    cantidad: 1,
    precio_unitario: 12500.0,
    subtotal: 12500.0,
  },
  {
    pedido_id: 3,
    cantidad: 1,
    precio_unitario: 1800.0,
    subtotal: 1800.0,
  },
  {
    pedido_id: 4,
    cantidad: 1,
    precio_unitario: 2500.0,
    subtotal: 2500.0,
  },
  {
    pedido_id: 5,
    cantidad: 1,
    precio_unitario: 4500.0,
    subtotal: 4500.0,
  },
]);

db.runCommand({
  collMod: "pedido",
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: [
        "id_pedido",
        "fecha",
        "estado",
        "producto",
        "total",
        "forma_pago",
        "eliminado",
      ],
      properties: {
        id_pedido: {
          bsonType: ["int", "long", "double", "decimal"],
          minimum: 1,
        },
        fecha: { bsonType: "string" },
        estado: {
          enum: ["PENDIENTE", "CONFIRMADO", "TERMINADO", "CANCELADO"],
        },
        producto: { bsonType: "object" },
        total: {
          bsonType: ["int", "long", "double", "decimal"],
          minimum: 0,
        },
        forma_pago: {
          enum: ["EFECTIVO", "TARJETA", "TRANSFERENCIA"],
        },
        eliminado: { bsonType: "bool" },
      },
    },
  },
  validationLevel: "strict",
  validationAction: "error",
});

db.runCommand({
  collMod: "detalle_pedido",
  validator: {
    $and: [
      {
        $jsonSchema: {
          bsonType: "object",
          required: ["pedido_id", "cantidad", "precio_unitario", "subtotal"],
          properties: {
            pedido_id: {
              bsonType: ["int", "long", "double", "decimal"],
              minimum: 1,
            },
            cantidad: { bsonType: "int", minimum: 1 },
            precio_unitario: {
              bsonType: ["int", "long", "double", "decimal"],
              minimum: 0,
            },
            subtotal: {
              bsonType: ["int", "long", "double", "decimal"],
              minimum: 0,
            },
          },
        },
      },
      {
        $expr: {
          $eq: ["$subtotal", { $multiply: ["$cantidad", "$precio_unitario"] }],
        },
      },
    ],
  },
  validationLevel: "strict",
  validationAction: "error",
});

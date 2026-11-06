//a)
use("foodstore");
db.pedido.find();

//b)
use("foodstore");
db.pedido.find({ estado: "CANCELADO" });

//c)
use("foodstore");
db.pedido.find({ "producto.nombre": "Bebida Gaseosa" });

//d)
use("foodstore");
db.pedido.find({ total: { $gt: 4000 } });

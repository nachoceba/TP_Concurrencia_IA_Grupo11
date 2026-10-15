ALTER TABLE producto
  ADD CONSTRAINT ck_producto_disponible_stock
  CHECK (NOT (disponible AND stock = 0));

ALTER TABLE detalle_pedido
  ADD CONSTRAINT ck_detalle_subtotal
  CHECK (subtotal = cantidad * precio_unitario);
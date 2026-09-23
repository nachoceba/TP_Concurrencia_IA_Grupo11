-- =============================================================================
-- Food Store - DDL migrado para parcial (01_schema.sql)
-- Motor: PostgreSQL 16+ | Cumple Requisito Tecnico Exclusivo parcial.md:
--   ENUM, TIMESTAMPTZ, JSONB, IDENTITY, PL/pgSQL (ver 04_objects.sql)
-- Orden: 1) ENUMs 2) categoria 3) producto 4) usuario 5) pedido 6) detalle
-- Protocolo: probar en clon con BEGIN + ROLLBACK antes de COMMIT definitivo.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 0. TIPOS ENUM
-- -----------------------------------------------------------------------------
CREATE TYPE rol_usuario AS ENUM ('ADMIN', 'USUARIO');
CREATE TYPE estado_pedido AS ENUM ('PENDIENTE', 'CONFIRMADO', 'TERMINADO', 'CANCELADO');
CREATE TYPE forma_pago AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');

-- -----------------------------------------------------------------------------
-- 1. CATEGORIA
-- -----------------------------------------------------------------------------
CREATE TABLE categoria (
    id_categoria    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre          VARCHAR(100)    NOT NULL,
    descripcion     VARCHAR(255),
    eliminado       BOOLEAN         NOT NULL DEFAULT FALSE
);
COMMENT ON COLUMN categoria.eliminado IS 'Soft delete: TRUE = baja logica';

-- -----------------------------------------------------------------------------
-- 2. PRODUCTO
-- -----------------------------------------------------------------------------
CREATE TABLE producto (
    id_producto     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre          VARCHAR(150)    NOT NULL,
    precio          NUMERIC(10,2)   NOT NULL CHECK (precio >= 0),
    descripcion     VARCHAR(255),
    stock           INTEGER         NOT NULL DEFAULT 0 CHECK (stock >= 0),
    imagen          VARCHAR(255),
    disponible      BOOLEAN         NOT NULL DEFAULT TRUE,
    categoria_id    BIGINT          NOT NULL REFERENCES categoria(id_categoria),
    eliminado       BOOLEAN         NOT NULL DEFAULT FALSE,
    CONSTRAINT ck_producto_disponible_stock CHECK (NOT (disponible AND stock = 0))
);
COMMENT ON COLUMN producto.eliminado IS 'Soft delete: TRUE = baja logica';
COMMENT ON COLUMN producto.disponible IS 'Disponibilidad comercial (distinto de eliminado)';
CREATE INDEX idx_producto_categoria_id ON producto(categoria_id);

-- -----------------------------------------------------------------------------
-- 3. USUARIO
-- -----------------------------------------------------------------------------
CREATE TABLE usuario (
    id_usuario      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre          VARCHAR(100)    NOT NULL,
    apellido        VARCHAR(100)    NOT NULL,
    mail            VARCHAR(150)    NOT NULL UNIQUE,
    celular         VARCHAR(20),
    contrasena      VARCHAR(255)    NOT NULL,
    rol             rol_usuario     NOT NULL DEFAULT 'USUARIO',
    eliminado       BOOLEAN         NOT NULL DEFAULT FALSE
);
COMMENT ON COLUMN usuario.contrasena IS 'Hash (nunca texto plano)';
COMMENT ON COLUMN usuario.eliminado IS 'Soft delete: TRUE = baja logica';

-- -----------------------------------------------------------------------------
-- 4. PEDIDO (TIMESTAMPTZ + JSONB exigidos por parcial.md)
-- -----------------------------------------------------------------------------
CREATE TABLE pedido (
    id_pedido       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha           TIMESTAMPTZ     NOT NULL DEFAULT now(),
    estado          estado_pedido   NOT NULL DEFAULT 'PENDIENTE',
    total           NUMERIC(10,2)   NOT NULL DEFAULT 0 CHECK (total >= 0),
    forma_pago      forma_pago      NOT NULL,
    metadatos       JSONB           NOT NULL DEFAULT '{}',
    usuario_id      BIGINT          NOT NULL REFERENCES usuario(id_usuario),
    eliminado       BOOLEAN         NOT NULL DEFAULT FALSE
);
COMMENT ON COLUMN pedido.total IS 'Calculado por trigger desde detalle_pedido (ver 04_objects.sql)';
COMMENT ON COLUMN pedido.metadatos IS 'JSONB libre: info_pago, cupon, notas, canal (exigencia parcial.md)';
COMMENT ON COLUMN pedido.fecha IS 'TIMESTAMPTZ (exigencia parcial.md)';
CREATE INDEX idx_pedido_usuario_id ON pedido(usuario_id);
CREATE INDEX idx_pedido_fecha ON pedido(fecha);
CREATE INDEX idx_pedido_estado ON pedido(estado);

-- -----------------------------------------------------------------------------
-- 5. DETALLE_PEDIDO (con eliminado para coherencia con queries analiticas)
-- -----------------------------------------------------------------------------
CREATE TABLE detalle_pedido (
    id_detalle_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pedido_id         BIGINT        NOT NULL REFERENCES pedido(id_pedido),
    producto_id       BIGINT        NOT NULL REFERENCES producto(id_producto),
    cantidad          INTEGER       NOT NULL CHECK (cantidad > 0),
    precio_unitario   NUMERIC(10,2) NOT NULL CHECK (precio_unitario >= 0),
    subtotal          NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    eliminado         BOOLEAN       NOT NULL DEFAULT FALSE,
    CONSTRAINT ck_detalle_subtotal CHECK (subtotal = cantidad * precio_unitario)
);
COMMENT ON COLUMN detalle_pedido.precio_unitario IS 'Precio congelado al momento de la venta';
COMMENT ON COLUMN detalle_pedido.subtotal IS 'Trigger BEFORE: cantidad * precio_unitario';
COMMENT ON COLUMN detalle_pedido.eliminado IS 'Soft delete: TRUE = item anulado (no suma al total)';
CREATE INDEX idx_detalle_pedido_pedido_id ON detalle_pedido(pedido_id);
CREATE INDEX idx_detalle_pedido_producto_id ON detalle_pedido(producto_id);

COMMIT;

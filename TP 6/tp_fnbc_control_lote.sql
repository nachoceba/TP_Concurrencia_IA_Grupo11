-- =============================================================================
-- TP Unidad 4 - Parte 1: FNBC sobre control_lote_almacen
-- Food Store | PostgreSQL 16+
--
-- Este script resuelve los puntos a) a f) de la Parte 1 del enunciado.
-- Todo el razonamiento (dependencias funcionales, clausuras, verificacion de
-- BCNF y anomalias) va documentado en comentarios, en el orden en que se
-- pide. El SQL ejecutable (creacion de tablas, vista y migracion de datos)
-- va al final, en la seccion "e) y f)".
--
-- Protocolo: probar en un clon descartable (ver protocolo_seguridad.md),
-- dentro de BEGIN/ROLLBACK antes de confirmar.
-- =============================================================================


-- =============================================================================
-- a) Dependencias funcionales
-- =============================================================================
-- Abreviamos: LoteID = L, DepositoID = D, ResponsableControlID = R
--
-- DF1: { L, D } -> R
--      "Para un lote y un deposito dados, el responsable queda unicamente
--       determinado." Esta es la DF que modela la PK declarada
--       (lote_id, deposito_id).
--
-- DF2: R -> D
--      "Cada responsable pertenece a un unico deposito." Esta es la DF que
--       introduce el problema: su lado izquierdo (R) es un solo atributo,
--       no las dos columnas de la PK.
--
-- No se postulan L -> D ni L -> R: un lote puede ser controlado desde varios
-- depositos (y por lo tanto por varios responsables), asi que esas DF no son
-- validas segun la regla de negocio.


-- =============================================================================
-- b) Clausuras y claves candidatas
-- =============================================================================
-- Universo de atributos: U = { L, D, R }
--
-- Clausura de {L, D}:
--   {L, D}+ = {L, D} -> aplico DF1 (agrego R) = {L, D, R} = U  => cubre todo
--   Subconjuntos propios: {L}+ = {L} (no cubre), {D}+ = {D} (no cubre)
--   => {L, D} es clave candidata (es superclave y ningun subconjunto lo es)
--
-- Clausura de {R}:
--   {R}+ = {R} -> aplico DF2 (agrego D) = {R, D}  => no cubre (falta L)
--   => {R} NO es clave candidata
--
-- Clausura de {L, R}:
--   {L, R}+ = {L, R} -> aplico DF2 (agrego D) = {L, R, D} = U  => cubre todo
--   Subconjuntos propios: {L}+ = {L} (no cubre), {R}+ = {R, D} (no cubre)
--   => {L, R} es clave candidata
--
-- Conjunto de claves candidatas: { {L, D} , {L, R} }
-- Atributos primos (estan en alguna clave candidata): L, D, R -- los tres.
-- Atributos no primos: ninguno.


-- =============================================================================
-- c) Verificacion de BCNF
-- =============================================================================
-- Definicion: un esquema esta en BCNF si, para TODA DF no trivial X -> Y,
-- X es superclave del esquema.
--
--   DF          | Determinante | Es superclave?
--   ------------|--------------|----------------------------------
--   {L,D} -> R  | {L, D}       | Si  ({L,D}+ = U)
--   R -> D      | {R}          | No  ({R}+ = {R,D} != U)
--
-- Como existe una DF (R -> D) cuyo determinante NO es superclave,
-- control_lote_almacen NO esta en BCNF.
--
-- La dependencia violatoria es ResponsableControlID -> DepositoID: R es
-- parte de una clave candidata ({L,R}), pero por si solo no alcanza para
-- determinar todos los atributos del esquema (le falta L).


-- =============================================================================
-- d) Anomalias sobre la instancia de ejemplo
-- =============================================================================
-- Instancia de referencia:
--   lote_id | deposito_id | responsable_control_id
--   501     | 30          | 801
--   502     | 30          | 801
--   503     | 31          | 802
--
-- ANOMALIA DE INSERCION:
-- Se contrata al responsable 803 y se lo asigna al deposito 32 como dato
-- maestro de personal, pero todavia no tiene ningun lote asignado para
-- controlar. Como lote_id es parte de la PK y no puede ser NULL, es
-- imposible registrar "803 pertenece al deposito 32" sin inventar un
-- lote_id ficticio. El dato queda fuera del sistema hasta que exista un
-- lote real.
--
-- ANOMALIA DE BORRADO:
-- Si el lote 503 es el unico que intervino el deposito 31, borrar la fila
-- (503, 31, 802) para dar de baja ese control tambien borra el unico
-- registro que prueba que el responsable 802 pertenece al deposito 31. Se
-- pierde un dato maestro de personal como efecto secundario de borrar un
-- hecho operativo.
--
-- ANOMALIA DE ACTUALIZACION:
-- El responsable 801 aparece en dos filas (lotes 501 y 502, mismo deposito
-- 30). Si 801 pasa a trabajar en el deposito 33, hay que actualizar
-- deposito_id = 33 en las DOS filas. Si por error solo se actualiza una,
-- la base queda inconsistente: la misma persona figura perteneciendo a dos
-- depositos distintos, lo cual viola la regla de negocio.


-- =============================================================================
-- e) Descomposicion sin perdida - script SQL
-- =============================================================================
-- Se aplica el algoritmo visto en clase sobre la DF violatoria R -> D:
--   R1 = atributos de la DF violatoria: { R, D }  -> tabla responsable_deposito
--   R2 = esquema original sin el atributo determinado, mas el determinante:
--        { L, R } -> tabla control_lote

BEGIN;

-- Tablas maestras minimas (se asumen existentes segun la consigna; se crean
-- aqui solo para que el script sea autocontenido y se pueda ejecutar solo).
CREATE TABLE IF NOT EXISTS lote (
    id_lote     BIGINT PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS deposito (
    id_deposito BIGINT PRIMARY KEY
);

-- -----------------------------------------------------------------------------
-- R1: responsable_deposito
-- Captura la DF: responsable_control_id -> deposito_id
-- Un responsable pertenece a exactamente un deposito.
-- -----------------------------------------------------------------------------
CREATE TABLE responsable_deposito (
    responsable_control_id BIGINT NOT NULL
        REFERENCES usuario(id_usuario),
    deposito_id             BIGINT NOT NULL
        REFERENCES deposito(id_deposito),
    PRIMARY KEY (responsable_control_id)
    -- La PK es justamente lo que garantiza la DF responsable -> deposito.
);

-- -----------------------------------------------------------------------------
-- R2: control_lote
-- Captura la clave candidata alternativa detectada en (b): { L, R }
-- -----------------------------------------------------------------------------
CREATE TABLE control_lote (
    lote_id                 BIGINT NOT NULL
        REFERENCES lote(id_lote),
    responsable_control_id  BIGINT NOT NULL
        REFERENCES responsable_deposito(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);

-- -----------------------------------------------------------------------------
-- Vista de compatibilidad: reconstruye la relacion original uniendo R1 y R2
-- por el atributo en comun (responsable_control_id).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_control_lote_almacen AS
SELECT
    cl.lote_id,
    rd.deposito_id,
    cl.responsable_control_id
FROM control_lote cl
JOIN responsable_deposito rd
  ON cl.responsable_control_id = rd.responsable_control_id;


-- =============================================================================
-- f) Justificacion de "sin perdida" y migracion de datos
-- =============================================================================
-- El teorema de Heath dice que una descomposicion R -> {R1, R2} es sin
-- perdida si el atributo (o conjunto) comun a R1 y R2 es superclave de al
-- menos uno de los dos esquemas.
--
-- El atributo comun es responsable_control_id. En R1 (responsable_deposito)
-- es la clave primaria, o sea que es superclave de R1. Se cumple la
-- condicion del teorema: la union R1 JOIN R2 reconstruye exactamente la
-- relacion original, sin filas de mas ni de menos.

-- Paso 1: poblar las tablas maestras con los IDs que aparecen en el ejemplo
INSERT INTO lote (id_lote) VALUES (501), (502), (503)
ON CONFLICT DO NOTHING;

INSERT INTO deposito (id_deposito) VALUES (30), (31)
ON CONFLICT DO NOTHING;

-- Los responsables 801 y 802 se asumen ya existentes en la tabla usuario del
-- proyecto. Si tu base de prueba no los tiene, insertalos primero, por
-- ejemplo:
-- INSERT INTO usuario (nombre, apellido, mail, contrasena)
-- VALUES ('Resp', '801', 'resp801@foodstore.com', 'hash_demo'),
--        ('Resp', '802', 'resp802@foodstore.com', 'hash_demo');
-- y usa los id_usuario generados en vez de 801/802 mas abajo.

-- Paso 2: poblar R1 - un registro por responsable
INSERT INTO responsable_deposito (responsable_control_id, deposito_id) VALUES
    (801, 30),
    (802, 31);

-- Paso 3: poblar R2 - un registro por (lote, responsable)
INSERT INTO control_lote (lote_id, responsable_control_id) VALUES
    (501, 801),
    (502, 801),
    (503, 802);

-- Verificacion: la vista debe devolver exactamente la instancia original
SELECT * FROM v_control_lote_almacen ORDER BY lote_id;
-- Resultado esperado:
--   lote_id | deposito_id | responsable_control_id
--   501     | 30          | 801
--   502     | 30          | 801
--   503     | 31          | 802

ROLLBACK;
-- Cambiar a COMMIT solo despues de validar el resultado de la verificacion
-- de arriba (protocolo_seguridad.md, Paso 2).

-- -----------------------------------------------------------------------------
-- Efecto sobre las anomalias (ya resuelto en el esquema descompuesto):
-- - Insercion: ahora se puede registrar a 803 en el deposito 32 sin tener
--   ningun lote, insertando solo en responsable_deposito.
-- - Borrado: borrar un lote de control_lote no borra el dato maestro del
--   responsable, que vive aparte en responsable_deposito.
-- - Actualizacion: cambiar el deposito de 801 es una sola fila en
--   responsable_deposito (su PK), no puede quedar inconsistente entre filas.
-- -----------------------------------------------------------------------------

Declaración de Uso de IA (DUIA) - Parte 1: Integridad Versionada


| Herramienta | OpenCode (modelo Gemini 2.5 Pro vía Google AI Studio) |
| Spec o prompt utilizado | "Basándote en mi esquema, redacta un script SQL llamado 01_restricciones_integridad.sql que contenga dos sentencias ALTER TABLE con CHECK 
constraints para las siguientes reglas: 1. En la tabla producto, no permitir disponible = TRUE si el stock es igual a 0. 2. En la tabla detalle_pedido, asegurar que subtotal sea exactamente igual a cantidad * precio_unitario. No modifiques el archivo de esquema original." |
| Qué generó | El archivo 01_restricciones_integridad.sql conteniendo dos sentencias ALTER TABLE con sus correspondientes restricciones declarativas (chk_stock_disponible y chk_subtotal_calculado). |
| Qué se aceptó | Se aceptó la lógica completa de las sentencias ALTER TABLE y las expresiones de validación dentro de cada bloque CHECK. |
| Qué se modificó o descartó | Se ajustaron manualmente los nombres de los constraints (chk_stock_disponible y chk_subtotal_calculado) para mantener la convención de nomenclatura estándar definida en el esquema del proyecto. |
| Verificación realizada | Se ejecuto el script dentro de una transacción en PostgreSQL (BEGIN). Se probaron INSERT válidos y luego INSERT inválidos (ej. un producto con stock = 0 y disponible = TRUE, y un detalle con subtotal inconsistente). El motor rechazó correctamente las inserciones inválidas mediante el error de CHECK constraint. Finalmente se aplicó ROLLBACK para verificar la inocuidad y COMMIT en la base definitiva. |
# Procedimiento Almacenado: `desglose_perdidas`

## Descripción

El procedimiento `desglose_perdidas` calcula y genera métricas relacionadas con las pérdidas y recursos disponibles en plantas solares, basándose en las proyecciones de generación y lecturas reales. El procedimiento permite agrupar los resultados por periodos diarios, semanales o mensuales según el parámetro de entrada.

## Parámetros de Entrada

- **_plantas (VARCHAR(1024))**: Cadena que contiene los identificadores de las plantas (separados por comas) para las cuales se realizarán los cálculos.
- **_fecha_inicio (DATE)**: Fecha de inicio del periodo para el cual se realizarán los cálculos.
- **_fecha_fin (DATE)**: Fecha de fin del periodo para el cual se realizarán los cálculos.
- **_agrupacion (VARCHAR(10))**: Tipo de agrupación para los resultados (`'diaria'`, `'semanal'` o `'mensual'`).

## Proceso

1. **Eliminación de Tablas Temporales**:
   - Se eliminan las tablas temporales `metricos_test` y `desglose_perdidas` si ya existen, para garantizar que se creen nuevas tablas.

2. **Creación de Tabla Temporal `desglose_perdidas`**:
   - Se calcula el desglose de las pérdidas basado en los valores teóricos, lecturas reales y factores de ajuste como soiling, indisponibilidad y curtailment.
   - Los cálculos incluyen:
     - **`resource`**: Recursos disponibles ajustados.
     - **`indeterminado`**: Pérdidas que no se pueden categorizar.
     - Ajustes de indisponibilidad, soiling, curtailment y AOP basados en valores teóricos y proyectados.

3. **Creación de Tabla Temporal `metricos_test`**:
   - Se utiliza una CTE (expresión de tabla común) para realizar cálculos detallados sobre métricas diarias.
   - Las métricas se agrupan por el tipo de periodo especificado en el parámetro `_agrupacion` (diario, semanal o mensual).

4. **Actualización de Métricas**:
   - Los valores calculados (limpieza, curtailment, indisponibilidad, indeterminado, cumplimiento ajustado) se ajustan y convierten a porcentajes respecto al total de generación.

5. **Selección de Resultados Finales**:
   - Los resultados ajustados se seleccionan de la tabla `metricos_test`.

## Resultados

El procedimiento devolverá un conjunto de resultados que incluye las siguientes columnas:

- **periodo**: Fecha correspondiente al periodo (diario, semanal o mensual) según el parámetro `_agrupacion`.
- **cleanliness**: Porcentaje de limpieza ajustado, basado en las diferencias entre los valores proyectados y reales.
- **curtailment**: Porcentaje de curtailment ajustado, indicando la generación perdida debido a limitaciones operativas.
- **unavailability**: Porcentaje de indisponibilidad ajustado, representando el tiempo que las plantas no estuvieron operativas.
- **undetermined**: Porcentaje de pérdidas indeterminadas ajustadas, que agrupan pérdidas no categorizadas.
- **cumplimiento_adj**: Porcentaje de cumplimiento ajustado, que refleja el rendimiento de la planta considerando los factores de ajuste.
- **resource**: Porcentaje de recursos disponibles ajustados.
- **suma_total**: Suma total de las métricas calculadas, utilizada para normalizar los resultados.

## Consultas de Ejemplo

Para llamar al procedimiento, se puede usar el siguiente comando SQL:

```sql
CALL Solarity.desglose_perdidas('1,2,3', '2024-01-01', '2024-12-31', 'semanal');

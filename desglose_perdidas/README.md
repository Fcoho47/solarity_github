# Procedimiento Almacenado: `gdp_semanal`

## Descripción

El procedimiento `gdp_semanal` calcula y genera métricas semanales relacionadas con la generación de energía de plantas solares. Este procedimiento toma como entrada una lista de plantas y devuelve métricas ajustadas que se basan en diversas variables relacionadas con la generación, pérdidas y otros factores.

## Parámetros de Entrada

- **_plantas (VARCHAR(255))**: Cadena que contiene los identificadores de las plantas (separados por comas) para las cuales se desean calcular las métricas semanales.

## Proceso

1. **Eliminación de Tablas Temporales**: Se eliminan las tablas temporales `metricos` y `desglose_perdidas` si ya existen, para garantizar que se creen nuevas tablas.

2. **Creación de Tabla Temporal `desglose_perdidas`**:
   - Se calcula el desglose de las pérdidas a partir de la proyección de generación y las lecturas de las plantas.
   - Se realizan cálculos para determinar la cantidad de recursos disponibles, pérdidas por indisponibilidad, soiling, y curtailment, ajustando estos valores según los parámetros de entrada.

3. **Actualización de la Tabla `desglose_perdidas`**:
   - Se agrega una columna `total` que se actualiza con el total de generación menos las pérdidas.

4. **Creación de Tabla Temporal `metricos`**:
   - Se utiliza una expresión de tabla común (CTE) para calcular varias métricas diarias, incluyendo limpieza, curtailment, indisponibilidad e indeterminado.
   - Se agrupan las métricas por semana.

5. **Actualización de Métricas**:
   - Se actualizan las métricas de la tabla `metricos` dividiendo por la suma total para obtener porcentajes ajustados.

6. **Selección de Resultados Finales**:
   - Se seleccionan y devuelven todos los resultados de la tabla `metricos`.

## Resultados

El procedimiento devolverá un conjunto de resultados que incluye las siguientes columnas:

- **semana**: La fecha correspondiente al inicio de la semana (lunes) en que se calcularon las métricas.
  
- **cleanliness**: Porcentaje de limpieza ajustado de la planta, calculado como la diferencia entre el soiling real y el soiling proyectado, dividido por el AOP ajustado. Este valor indica la eficiencia de la limpieza en la generación de energía.

- **curtailment**: Porcentaje de curtailment ajustado, que refleja la cantidad de generación que no se pudo realizar debido a limitaciones operativas, calculado en relación al AOP ajustado.

- **unavailability**: Porcentaje de indisponibilidad ajustado, que representa el tiempo en que la planta no estuvo operativa, ajustado según los valores teóricos de generación.

- **undetermined**: Porcentaje de pérdidas indeterminadas ajustadas, que engloba las pérdidas que no se pueden categorizar en los tipos previamente definidos.

- **cumplimiento_adj**: Porcentaje de cumplimiento ajustado, que mide el rendimiento general de la planta en comparación con las expectativas de generación, ajustado por los factores de pérdidas.


## Consultas de Ejemplo

Para llamar al procedimiento, se puede usar el siguiente comando SQL:

```sql
CALL Solarity.gdp_semanal('1,2,3');

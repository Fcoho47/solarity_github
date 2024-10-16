# Documentación del Procedimiento Almacenado: `test_calcularGeneracionTotal`

## Descripción General

El procedimiento almacenado `test_calcularGeneracionTotal` se encarga de calcular las métricas de generación de energía real y proyectada para un conjunto de plantas solares en un rango de fechas especificado. Actualiza una tabla temporal con los valores calculados y devuelve el total de la energía proyectada como un valor de salida.

### Características Principales:
- **Cálculo de Generación**: Calcula la generación total real y proyectada de energía para cada planta.
- **Cálculo de Factores de Planta (FP)**: Estima el Factor de Planta tanto proyectado como generado para cada planta.
- **Cálculo de Energía Incidente POA**: Evalúa la energía incidente sobre el plano del array (Plane of Array).
- **Cumplimiento y PR**: Calcula el nivel de cumplimiento de radiación y el ratio de rendimiento (PR).
- **Manejo de Fechas**: Ajusta el inicio efectivo de la generación si una planta tiene una fecha de inicio posterior al inicio del reporte.

## Parámetros de Entrada

| Nombre del Parámetro         | Tipo de Dato     | Descripción                                                                                 |
|------------------------------|------------------|---------------------------------------------------------------------------------------------|
| `_inicio`                    | `DATETIME`       | Fecha y hora de inicio para el rango de datos del cálculo.                                   |
| `_fin`                       | `DATETIME`       | Fecha y hora de fin para el rango de datos del cálculo.                                      |
| `_energiaProyectadaTotal`     | `DECIMAL(15,3)`  | Valor de salida, que almacenará la energía proyectada total acumulada.                       |

## Descripción de Variables Internas

| Variable                        | Tipo de Dato            | Descripción                                                                                   |
|----------------------------------|-------------------------|-----------------------------------------------------------------------------------------------|
| `planta_id`                      | `INT`                   | Identificador de la planta procesada por el cursor.                                            |
| `planta_potencia`                | `INT`                   | Potencia instalada de la planta en kW.                                                         |
| `planta_inicioGeneracion`        | `DATE`                  | Fecha de inicio de la generación de la planta.                                                 |
| `planta_api`                     | `VARCHAR(64)`           | API asociada a la planta.                                                                      |
| `inicioEfectivo`                 | `DATE`                  | Fecha de inicio efectiva, ajustada según la fecha de inicio de generación de la planta.         |
| `periodoDias`                    | `INT`                   | Número de días del período a procesar.                                                         |
| `temp_generacionTotal`           | `DECIMAL(15,3)`         | Almacena la generación total de energía real de la planta.                                     |
| `temp_generacionProyectada`      | `DECIMAL(15,3)`         | Almacena la generación proyectada de energía de la planta para el período.                     |
| `temp_generacionProyectadaTotal` | `DECIMAL(15,3)`         | Suma acumulada de la generación proyectada total.                                              |
| `temp_fpProyectado`              | `FLOAT`                 | Factor de planta proyectado, calculado según la potencia de la planta.                         |
| `temp_fpGenerado`                | `FLOAT`                 | Factor de planta generado, calculado según los datos reales de generación.                     |
| `temp_generacionTeorica`         | `DECIMAL(15,3)`         | Generación teórica calculada en condiciones ideales.                                           |
| `temp_energiaIncidentePOA`       | `DECIMAL(15,3)`         | Energía incidente sobre el plano del array (POA).                                              |
| `temp_cumplimientoRadiacion`     | `FLOAT`                 | Cumplimiento en función de la radiación teórica y real.                                        |
| `temp_cumplimiento`              | `FLOAT`                 | Nivel de cumplimiento entre la generación real y la proyectada.                                |
| `temp_PR`                        | `FLOAT`                 | Ratio de rendimiento (PR), relación entre la energía real y la energía incidente POA.           |
| `temp_energiaFaltante`           | `FLOAT`                 | Energía faltante si la planta no alcanza su generación proyectada.                             |
| `temp_energiaProyectadaTotal`    | `FLOAT`                 | Suma acumulada de la energía proyectada faltante.                                              |
| `fin_cursor`                     | `INT`                   | Variable para indicar si el cursor ha llegado al final.                                        |

## Descripción del Procedimiento

1. **Inicialización del Cursor**: Se inicializa un cursor que selecciona las plantas que serán procesadas desde la tabla temporal `tmp_reporte_operaciones`.

2. **Cálculo por Planta**:
    - **Corrección de Fechas**: Se ajusta el `inicioEfectivo` si la planta tiene una fecha de inicio posterior a la fecha `_inicio` proporcionada.
    - **Generación Total**: Se calcula la generación total de energía de la planta utilizando la tabla `lecturaGeneracionPlanta`.
    - **Generación Proyectada**: Se calcula la generación proyectada utilizando la tabla `proyeccionGeneracion`.
    - **Generación Proyectada Total**: Suma la generación proyectada total acumulada para todas las plantas procesadas.
    - **Factores de Planta**: Calcula el Factor de Planta proyectado y generado en función de la potencia instalada y la generación.
    - **Generación Teórica y Energía POA**: Calcula la generación teórica y la energía incidente en el array (POA) utilizando proyecciones.
    - **Cumplimiento y PR**: Calcula el nivel de cumplimiento (real vs proyectado) y el ratio de rendimiento (PR) basado en la energía incidente POA.

3. **Actualización de la Tabla Temporal**: Para cada planta procesada, se actualiza la tabla temporal `tmp_reporte_operaciones` con los valores calculados de generación, cumplimiento, factores de planta, y otros indicadores.

4. **Cálculo de Energía Faltante**: Si la generación proyectada es mayor que la real, se acumula la diferencia como energía faltante, y se actualiza la variable `temp_energiaProyectadaTotal`.

5. **Asignación del Resultado Final**: Al finalizar el proceso, la variable de salida `_energiaProyectadaTotal` se actualiza con el valor acumulado de la generación proyectada total.


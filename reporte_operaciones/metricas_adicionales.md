# Documentación del Procedimiento Almacenado: `calcularMetricasAdicionales`

## Descripción General

El procedimiento almacenado `calcularMetricasAdicionales` tiene como objetivo calcular métricas adicionales relacionadas con la disponibilidad, la potencia afectada y la indisponibilidad de las plantas solares en un período de tiempo determinado. Los resultados se utilizan para actualizar la tabla temporal `tmp_reporte_operaciones` con información detallada sobre el rendimiento y la operación de cada planta.

### Características Principales:
- **Cálculo de Disponibilidad**: Calcula la disponibilidad de los equipos para cada planta, junto con las cotas superior e inferior de la disponibilidad.
- **Cálculo de Potencia AC y Potencia Afectada**: Determina la potencia AC y la potencia afectada por problemas de generación y comunicación.
- **Cálculo de Indisponibilidad**: Calcula la indisponibilidad de la planta con base en las cotas de disponibilidad.
- **Verificación de Datos Presentes**: Evalúa si hay datos suficientes de generación en el período evaluado.
- **Actualización de Métricas Adicionales**: Actualiza métricas como la disponibilidad, potencia afectada, días de operación, y el impacto de la indisponibilidad en la operación.

## Parámetros de Entrada

| Nombre del Parámetro | Tipo de Dato  | Descripción                                                |
|----------------------|---------------|------------------------------------------------------------|
| `_inicio`            | `DATETIME`    | Fecha y hora de inicio del período a calcular.              |
| `_fin`               | `DATETIME`    | Fecha y hora de fin del período a calcular.                 |

## Descripción de Variables Internas

| Variable                         | Tipo de Dato        | Descripción                                                                                         |
|-----------------------------------|---------------------|-----------------------------------------------------------------------------------------------------|
| `planta_id`                       | `INT`               | Identificador de la planta procesada.                                                                |
| `planta_potencia`                 | `FLOAT`             | Potencia instalada de la planta en kW.                                                               |
| `planta_inicioGeneracion`         | `DATE`              | Fecha de inicio de la generación de la planta.                                                       |
| `planta_api`                      | `VARCHAR(64)`       | API asociada a la planta.                                                                            |
| `inicioEfectivo`                  | `DATE`              | Fecha efectiva ajustada para el inicio de la generación.                                              |
| `periodoDias`                     | `INT`               | Número de días que cubre el período de tiempo especificado.                                           |
| `temp_disponibilidad`             | `FLOAT`             | Disponibilidad de los equipos para la planta durante el período evaluado.                             |
| `temp_cotaInferiorDisp`           | `FLOAT`             | Cota inferior de la disponibilidad estimada.                                                          |
| `temp_cotaSuperioDisp`            | `FLOAT`             | Cota superior de la disponibilidad estimada.                                                          |
| `temp_errorDisponibilidad`        | `FLOAT`             | Error de disponibilidad, calculado como la diferencia entre las cotas.                               |
| `temp_potenciaACvar`              | `FLOAT`             | Potencia AC total de la planta.                                                                      |
| `temp_potenciaAfectadaGeneracion` | `FLOAT`             | Potencia afectada por incidentes de generación.                                                      |
| `temp_potenciaAfectadaComunicacion`| `FLOAT`             | Potencia afectada por problemas de comunicación.                                                     |
| `temp_dataPresente`               | `FLOAT`             | Proporción de datos de generación presentes en el período.                                           |
| `aporteIndispPlanta`              | `FLOAT`             | Aporte de la planta a la indisponibilidad total.                                                     |
| `aporteIndisponibilidad`          | `FLOAT`             | Suma acumulada de la indisponibilidad durante el período.                                             |

## Descripción del Procedimiento

1. **Inicialización del Cursor**: Se abre un cursor que selecciona las plantas que serán procesadas desde la tabla `tmp_reporte_operaciones`.

2. **Cálculo por Planta**:
    - **Corrección de Fechas**: Ajusta el `inicioEfectivo` si la planta tiene una fecha de inicio posterior al `_inicio` especificado.
    - **Cálculo de Disponibilidad y Cotas**: Calcula la disponibilidad, cotas superior e inferior, y el error de disponibilidad de los equipos utilizando la tabla `disponibilidadEquipo`.
    - **Cálculo de Potencia AC**: Suma la potencia AC reportada para la planta en la tabla `potencia_ac_plantas`.
    - **Cálculo de Potencia Afectada**: Suma la potencia afectada por incidentes de generación y comunicación reportados en `zammad.tickets_activos`.
    - **Verificación de Datos Presentes**: Evalúa la cantidad de datos de generación presentes durante el período evaluado en la tabla `lecturaGeneracionPlanta`.
    - **Cálculo de Aporte a la Indisponibilidad**: Calcula el aporte de la planta a la indisponibilidad total utilizando las cotas de disponibilidad.

3. **Actualización de la Tabla Temporal**: Los valores calculados para disponibilidad, potencia afectada, indisponibilidad, días de operación, y otros indicadores son actualizados en la tabla temporal `tmp_reporte_operaciones`.

4. **Cierre del Cursor**: Una vez procesadas todas las plantas, se cierra el cursor.


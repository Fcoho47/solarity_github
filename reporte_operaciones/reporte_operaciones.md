# Documentación del Procedimiento Almacenado: `test_ReporteOperaciones`

## Descripción General

El procedimiento almacenado `test_ReporteOperaciones`, parte de la base de datos `Solarity`, genera reportes operacionales basados en criterios de filtrado y agrupamiento especificados. Calcula métricas de generación de energía para plantas solares, proporcionando reportes detallados ya sea por cliente o por planta. El procedimiento procesa y agrega datos relacionados con la generación de energía, métricas de cumplimiento y disponibilidad.

### Características Principales:
- **Agrupamiento Personalizado**: Soporta la agrupación de los resultados por `cliente` o por `planta`.
- **Filtrado por Rango de Fechas**: Permite generar reportes en base a un rango de fechas especificado (`_inicio` hasta `_fin`).
- **Selección de Plantas Personalizada**: Filtra los datos basados en una lista de plantas especificada.
- **Filtrado de Incidencias**: Aplica un filtrado personalizado para plantas con ciertos incidentes.
- **Cálculo de Impacto y Disponibilidad**: Calcula métricas relacionadas con el cumplimiento, la disponibilidad y el impacto en la generación.

## Parámetros de Entrada

| Nombre del Parámetro | Tipo de Dato      | Descripción                                                                                          |
|----------------------|-------------------|------------------------------------------------------------------------------------------------------|
| `_agrupamiento`       | `VARCHAR(32)`     | Especifica cómo agrupar el reporte: ya sea por `'cliente'` o por `'planta'`.                          |
| `_inicio`             | `DATETIME`        | Fecha y hora de inicio para el rango de datos del reporte.                                            |
| `_fin`                | `DATETIME`        | Fecha y hora de fin para el rango de datos del reporte.                                               |
| `_plantas`            | `VARCHAR(1024)`   | Una lista de identificadores de plantas (en formato de texto) a incluir en el reporte.                |
| `_filtroIncidencias`  | `VARCHAR(64)`     | Filtra las incidencias de las plantas. Si el valor es `'Todas'`, no se aplica filtro.                 |

## Descripción de Variables Internas

| Variable               | Tipo de Dato            | Descripción                                                                                              |
|------------------------|-------------------------|----------------------------------------------------------------------------------------------------------|
| `energiaFaltante`       | `FLOAT`                 | Variable para calcular la energía faltante.                                                               |
| `energiaProyectadaTotal`| `DECIMAL(15,3)`         | Variable para almacenar el valor de la energía proyectada total durante el cálculo.                        |
| `defaultSoilingLevel`   | `FLOAT`                 | Nivel de suciedad por defecto en los paneles solares (0.075 o 7.5%).                                       |
| `_finCorregido`         | `DATE`                  | Fecha de fin corregida, que ajusta el valor de `_fin` si es mayor o igual a la fecha actual.               |
| `filtroIncidencias`     | `VARCHAR(64)`           | Filtro interno para las incidencias; se define como 1 si `_filtroIncidencias` es `'Todas'`, 0 en caso contrario.|

## Descripción del Procedimiento

1. **Creación de Tabla Temporal**: Se llama al procedimiento `test_crearTablaTemporalInsertarDatos` para crear una tabla temporal que almacenará los datos de las plantas especificadas en el parámetro `_plantas`.
  
2. **Cálculo de Generación Total**: Utiliza el procedimiento `test_calcularGeneracionTotal` para calcular las métricas de generación de energía dentro del rango de fechas.

3. **Cálculo de Métricas Adicionales**: Llama a `test_calcularMetricasAdicionales` para calcular métricas adicionales como el factor de planta y la radiación incidente.

4. **Generación del Reporte**: Dependiendo del valor de `_agrupamiento`, se generará uno de los siguientes reportes:
   - **Por Cliente**: Agrupa los datos por cliente y calcula la potencia total instalada, la generación real y proyectada, el factor de planta (FP), el cumplimiento, el impacto del incumplimiento, y el porcentaje de datos presentes.
   - **Por Planta**: Muestra información detallada por planta, incluyendo latitud, longitud, potencia instalada, generación real, teórica y proyectada, el cumplimiento, el ratio de rendimiento (PR), la energía incidente, el nivel de disponibilidad y otros indicadores relacionados.

### Reporte por Cliente

Si el valor de `_agrupamiento` es `'cliente'`, el procedimiento genera un reporte con las siguientes columnas:

| Columna                    | Descripción                                                                                |
|----------------------------|--------------------------------------------------------------------------------------------|
| `Cliente`                   | Nombre del cliente.                                                                        |
| `Cantidad de plantas`       | Número de plantas asociadas al cliente.                                                    |
| `Potencia total (kWp)`      | Potencia total instalada de las plantas en kilovatios pico.                                 |
| `Generación real`           | Generación real de energía.                                                                |
| `Generación proyectada`     | Generación proyectada de energía.                                                          |
| `FP proyectado`             | Factor de planta proyectado.                                                               |
| `FP generado`               | Factor de planta generado.                                                                 |
| `Cumplimiento`              | Relación entre la generación real y la generación proyectada (cumplimiento de objetivos).   |
| `Impacto incumplimiento`    | Impacto relativo de no alcanzar la generación proyectada.                                   |
| `% de Datos`                | Porcentaje de datos presentes en los sistemas de monitoreo.                                 |

### Reporte por Planta

Si el valor de `_agrupamiento` es `'planta'`, el reporte incluirá columnas más detalladas:

| Columna                        | Descripción                                                                                |
|---------------------------------|--------------------------------------------------------------------------------------------|
| `Planta`                        | Nombre de la planta.                                                                       |
| `Cliente`                       | Cliente asociado a la planta.                                                              |
| `API`                           | API asociada con la planta.                                                                |
| `Planta ID`                     | Identificador de la planta.                                                                |
| `Latitud`                       | Latitud de la ubicación de la planta.                                                      |
| `Longitud`                      | Longitud de la ubicación de la planta.                                                     |
| `Potencia (kWp)`                | Potencia instalada de la planta en kilovatios pico.                                         |
| `Generación real`               | Generación real de la planta.                                                              |
| `Generación teórica`            | Generación teórica de la planta, en base a condiciones ideales.                            |
| `Generación proyectada`         | Generación proyectada de la planta.                                                        |
| `FP proyectado`                 | Factor de planta proyectado.                                                               |
| `FP generado`                   | Factor de planta generado.                                                                 |
| `Cumplimiento`                  | Cumplimiento de generación en relación a lo proyectado.                                     |
| `Cumpl. Radiación`              | Cumplimiento con respecto a los niveles de radiación.                                       |
| `Performance Ratio (PR)`        | Relación de rendimiento de la planta.                                                      |
| `Energía POA`                   | Energía incidente en el plano del array (POA: Plane of Array).                              |
| `Delta radiación`               | Diferencia entre la radiación teórica y la generación proyectada ajustada por suciedad.     |
| `% de Datos`                    | Porcentaje de datos disponibles.                                                           |
| `Nivel Cumplimiento`            | Clasificación del nivel de cumplimiento (porcentaje).                                       |
| `Nivel de Disponibilidad`       | Clasificación del nivel de disponibilidad (porcentaje).                                     |
| `Impacto incumplimiento`        | Impacto del incumplimiento en la generación proyectada.                                     |
| `Impacto indisponibilidad`      | Impacto de la indisponibilidad en la operación.                                             |
| `Disponibilidad`                | Disponibilidad promedio de la planta.                                                      |
| `Disponibilidad Ajustada`       | Disponibilidad ajustada.                                                                   |
| `Disponibilidad Estimada`       | Disponibilidad estimada.                                                                   |
| `Error Disponibilidad`          | Margen de error en la disponibilidad.                                                      |
| `Potencia AC`                   | Potencia en corriente alterna (AC) de la planta.                                            |
| `Potencia afectada Gx`          | Potencia afectada por la generación.                                                       |
| `Potencia afectada Comms`       | Potencia afectada por fallos de comunicación.                                              |
| `Indisponibilidad`              | Nivel de indisponibilidad de la planta.                                                    |
| `Días en operación`             | Cantidad de días que la planta ha estado en operación.                                      |
| `Aporte disp. pot. tiempo`      | Contribución de la disponibilidad en función del tiempo.                                   |
| `Aporte error disp. pot. tiempo`| Contribución del error en la disponibilidad en función del tiempo.                         |

## Consideraciones Finales

- El procedimiento maneja la corrección automática de la fecha de fin (`_fin`) si es mayor o igual a la fecha actual, ajustándola a un segundo antes de la fecha actual.
- Utiliza tablas temporales para almacenar los datos de generación antes de hacer los cálculos finales.
- Los cálculos están optimizados para reflejar los indicadores clave de rendimiento (KPI) como el cumplimiento de la generación, impacto por indisponibilidad, y el rendimiento de la planta.

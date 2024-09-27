# Documentación: `reporte_disponibilidad_filtrado`

## Descripción

El procedimiento almacenado `reporte_disponibilidad_filtrado` genera un reporte filtrado de la disponibilidad ajustada de equipos para una planta específica. El reporte está basado en la potencia nominal de los equipos, ajustada por la potencia total de la planta.

## Parámetros de entrada

- **`p_id_planta` (INT)**: Identificador único de la planta. El reporte solo incluirá datos de la planta correspondiente a este ID.

## Tablas Temporales Utilizadas

1. **`temp_potencia_nom`**: Esta tabla almacena la potencia nominal de los equipos de la planta filtrada y calcula la proporción de cada equipo respecto a la potencia total de la planta.
   
   - **Columnas**:
     - `ID` (INT): Identificador del equipo.
     - `id_planta` (INT): Identificador de la planta.
     - `Pot. Nom. (kW)` (FLOAT): Potencia nominal del equipo en kW.
     - `Div. Pot. Nom.` (FLOAT): Proporción de la potencia nominal del equipo respecto a la potencia total de la planta.

2. **`reporte_disponibilidad`**: Almacena la disponibilidad diaria de los equipos, junto con una versión ajustada que se obtiene multiplicando la disponibilidad por la proporción de la potencia nominal.

   - **Columnas**:
     - `id_equipo` (INT): Identificador del equipo.
     - `id_planta` (INT): Identificador de la planta.
     - `fecha` (DATE): Fecha de la disponibilidad.
     - `disponibilidad` (FLOAT): Disponibilidad del equipo en la fecha dada.
     - `disponibilidad_ajustada` (FLOAT): Disponibilidad ajustada por la proporción de la potencia nominal.

3. **`suma_disponibilidad`**: Agrega la disponibilidad ajustada por fecha para obtener la disponibilidad total de la planta.

   - **Columnas**:
     - `id_planta` (INT): Identificador de la planta.
     - `fecha` (DATE): Fecha de la disponibilidad.
     - `suma_disponibilidad` (FLOAT): Suma de las disponibilidades ajustadas de todos los equipos.

## Funcionalidad

1. **Eliminar tablas temporales existentes**: Si las tablas temporales `temp_potencia_nom`, `reporte_disponibilidad`, y `suma_disponibilidad` ya existen, se eliminan al comienzo para evitar conflictos.

2. **Cálculo de la potencia nominal ajustada**:
   - Se crea la tabla `temp_potencia_nom` que almacena los equipos de la planta, junto con su potencia nominal.
   - Se calcula la proporción de la potencia nominal de cada equipo respecto a la suma total de potencias de la planta.

3. **Generación del reporte de disponibilidad**:
   - Se multiplica la disponibilidad de cada equipo por su proporción de potencia y se almacena en `reporte_disponibilidad`.

4. **Suma de la disponibilidad ajustada**:
   - Se agrupan los datos por fecha y se suman las disponibilidades ajustadas para generar un reporte total diario, almacenado en `suma_disponibilidad`.

5. **Resultado**:
   - Se devuelve un conjunto de datos que contiene la fecha y la suma de la disponibilidad ajustada para la planta filtrada.

## Ejemplo de uso

```sql
CALL Solarity.reporte_disponibilidad_filtrado(1);
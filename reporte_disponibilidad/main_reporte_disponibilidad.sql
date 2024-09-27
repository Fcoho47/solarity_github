CREATE DEFINER=`solarity`@`%` PROCEDURE `Solarity`.`reporte_disponibilidad_filtrado`(IN p_id_planta INT)
BEGIN
    -- Eliminar tablas temporales si existen
    DROP TEMPORARY TABLE IF EXISTS temp_potencia_nom;
    DROP TEMPORARY TABLE IF EXISTS reporte_disponibilidad;
    DROP TEMPORARY TABLE IF EXISTS suma_disponibilidad;
 
    -- Crear la tabla temporal para almacenar los datos necesarios
    CREATE TEMPORARY TABLE temp_potencia_nom (
        ID INT,
        id_planta INT,
        `Pot. Nom. (kW)` FLOAT,
        `Div. Pot. Nom.` FLOAT
    );
 
    -- Insertar los resultados de la consulta en la tabla temporal, filtrando por id_planta
    INSERT INTO temp_potencia_nom (ID, id_planta, `Pot. Nom. (kW)`)
    SELECT
        e.id AS `ID`,
        e.id_planta AS `id_planta`,
        ce.valor / 1000.0 AS `Pot. Nom. (kW)`
    FROM equipo e
    LEFT JOIN caracteristicaEquipo ce ON ce.id_equipo = e.id
    JOIN planta p ON p.id = e.id_planta
    WHERE p.inicioGeneracion IS NOT NULL
      AND e.activo = 1
      AND e.id_tipo IN (2, 5)
      AND e.id_planta = p_id_planta
    GROUP BY e.id;
 
    -- Actualizar la tabla temporal con los resultados de la división
    UPDATE temp_potencia_nom tpn
    JOIN (
        SELECT id_planta, SUM(`Pot. Nom. (kW)`) AS total_potencia
        FROM temp_potencia_nom
        GROUP BY id_planta
    ) sub ON tpn.id_planta = sub.id_planta
    SET tpn.`Div. Pot. Nom.` = tpn.`Pot. Nom. (kW)` / sub.total_potencia;
 
    -- Crear la tabla temporal para almacenar los datos de disponibilidad
    CREATE TEMPORARY TABLE reporte_disponibilidad (
        id_equipo INT,
        id_planta INT,
        fecha DATE,
        disponibilidad FLOAT,
        disponibilidad_ajustada FLOAT
    );
 
    -- Seleccionar, multiplicar y almacenar los datos en la tabla temporal, filtrando por id_planta
    INSERT INTO reporte_disponibilidad (id_equipo, id_planta, fecha, disponibilidad, disponibilidad_ajustada)
    SELECT
        t1.id_equipo AS id_equipo,
        t1.id_planta AS id_planta,
        t1.fecha AS fecha,
        t1.disponibilidad AS disponibilidad,
        t1.disponibilidad * t2.`Div. Pot. Nom.` AS disponibilidad_ajustada
    FROM disponibilidadEquipo t1
    INNER JOIN temp_potencia_nom t2
    ON t1.id_equipo = t2.ID
    AND t1.id_planta = t2.id_planta
    WHERE t1.id_planta = p_id_planta;
 
    -- Crear una nueva tabla temporal para almacenar los datos agregados
    CREATE TEMPORARY TABLE suma_disponibilidad (
        id_planta INT,
        fecha DATE,
        suma_disponibilidad FLOAT
    );
 
    -- Agrupar por fecha y sumar los valores de disponibilidad
    INSERT INTO suma_disponibilidad (id_planta, fecha, suma_disponibilidad)
    SELECT
        id_planta,
        fecha,
        SUM(disponibilidad_ajustada) AS suma_disponibilidad
    FROM reporte_disponibilidad
    GROUP BY fecha;
 
    -- Seleccionar los datos filtrados según el parámetro
    SELECT fecha, suma_disponibilidad
    FROM suma_disponibilidad
    ORDER BY fecha ASC;
 
END
















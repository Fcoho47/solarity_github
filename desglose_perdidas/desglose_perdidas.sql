CREATE DEFINER=`root`@`localhost` PROCEDURE `Solarity`.`desglose_perdidas`(
    IN _plantas VARCHAR(1024),
    IN _fecha_inicio DATE,
    IN _fecha_fin DATE,
    IN _agrupacion VARCHAR(10)  -- 'diaria', 'semanal', o 'mensual'
)
BEGIN
    -- Eliminar las tablas temporales si ya existen
    DROP TEMPORARY TABLE IF EXISTS metricos_test;
    DROP TEMPORARY TABLE IF EXISTS desglose_perdidas;

    -- Crear la tabla temporal desglose_perdidas
    CREATE TEMPORARY TABLE desglose_perdidas AS
    SELECT *,

        -- Calculamos resource
        (COALESCE(valorTeorico, 0) - COALESCE(AOP, 0) - COALESCE(soiling_ppto, 0) - COALESCE(unavailable_ppto, 0) - COALESCE(curtailment_ppto, 0)) AS resource,

        -- Calculamos indeterminado
        (COALESCE(valorTeorico, 0) - (COALESCE(unavailable, 0) + COALESCE(soiling, 0) + COALESCE(clipping, 0)) - COALESCE(valor_lectura, 0)) AS indeterminado,
        
        -- Calculamos el unavailable ajustado
        COALESCE(
                (COALESCE(unavailable_ppto, 0) / NULLIF(AOP + soiling_ppto, 0)) * valorTeorico,
                0
                    ) AS PPTO_adj_unavailable,

        -- Calculamos el soiling ajustado
        COALESCE(
                (COALESCE(soiling_ppto, 0) / NULLIF(AOP + soiling_ppto + unavailable_ppto + curtailment_ppto, 0)) * valorTeorico, 
                0
                    ) AS PPTO_adj_soiling,

        -- Calculamos el curtailment ajustado
        COALESCE(
                (COALESCE(curtailment_ppto, 0) / NULLIF(AOP + soiling_ppto + unavailable_ppto + curtailment_ppto, 0)) * valorTeorico, 
                0
                    ) AS PPTO_adj_curtailment,

        -- Calculamos el AOP ajustado
        valorTeorico - (
        (COALESCE(soiling_ppto, 0) / COALESCE(NULLIF(AOP + soiling_ppto + unavailable_ppto + curtailment_ppto, 0), 1)) * valorTeorico +
        (COALESCE(unavailable_ppto, 0) / COALESCE(NULLIF(AOP + soiling_ppto, 0), 1)) * valorTeorico +
        (COALESCE(curtailment_ppto, 0) / COALESCE(NULLIF(AOP + soiling_ppto + unavailable_ppto + curtailment_ppto, 0), 1)) * valorTeorico
        ) AS PPTO_adj_AOP,

        -- Calculamos las pérdidas totales
        AOP + soiling_ppto + unavailable_ppto + curtailment_ppto AS AOP_losses

    FROM (
        SELECT 
            pg.id_planta, 
            pg.fecha, 
            pg.valor * 1000 AS AOP, 
            pg.soiling * 1000 AS soiling_ppto, 
            pg.indisponibilidad * 1000 AS unavailable_ppto, 
            pg.curtailment * 1000 AS curtailment_ppto, 
            greatest(pg.valorTeorico * 1000, ifnull(lgp.valor, 0)) AS valorTeorico,
            pdp.incidencia * 1000 AS unavailable,
            pdp.soiling * 1000 AS soiling,
            pdp.clipping * 1000 AS clipping,

            lgp.valor AS valor_lectura
        FROM 
            proyeccionGeneracion pg
        LEFT JOIN 
            lecturaGeneracionPlanta lgp
        ON 
            pg.id_planta = lgp.id_planta 
            AND pg.fecha = lgp.fecha
        LEFT JOIN
            perdidasDiariasPlanta pdp
        ON
            pg.id_planta = pdp.id_planta
            AND pg.fecha = pdp.fecha
        WHERE
            FIND_IN_SET(pg.id_planta, _plantas)
            AND pg.valorTeorico IS NOT NULL
            AND pg.fecha BETWEEN _fecha_inicio AND _fecha_fin
    ) AS subquery;

    -- Utilizar CTE para cálculos y crear una tabla temporal metricos
    CREATE TEMPORARY TABLE metricos_test AS
    WITH CTE_metrico AS (
        SELECT
            -- Seleccionamos columnas necesarias
            fecha,
            id_planta,
            PPTO_adj_AOP AS adj_AOP,
            AOP_losses,

            -- Cálculo de pérdidas diarias
            soiling - PPTO_adj_soiling AS daily_cleanliness,
            clipping - PPTO_adj_curtailment AS daily_curtailment,
            unavailable - PPTO_adj_unavailable AS daily_unavailability,
            indeterminado AS daily_undetermined,

            -- Cálculo de resource
            resource  AS daily_resource
            
        FROM desglose_perdidas
    )
    SELECT
        -- Modificar la agrupación según el nuevo parámetro
        CASE 
            WHEN _agrupacion = 'mensual' THEN STR_TO_DATE(DATE_FORMAT(fecha, '%Y-%m-01'), '%Y-%m-%d')
            WHEN _agrupacion = 'diaria' THEN fecha
            ELSE STR_TO_DATE(DATE_FORMAT(DATE_SUB(fecha, INTERVAL WEEKDAY(fecha) DAY), '%Y-%m-%d'), '%Y-%m-%d') 
        END AS periodo,

        -- Sumar las pérdidas diarias
        SUM(daily_cleanliness)*(-1) AS cleanliness,
        SUM(daily_curtailment)*(-1) AS curtailment,
        SUM(daily_unavailability)*(-1) AS unavailability,
        SUM(daily_undetermined)*(-1) AS undetermined,
        SUM(adj_AOP) AS cumplimiento_adj,
        SUM(daily_resource)/SUM(AOP_losses) AS resource,
        SUM(daily_cleanliness) + SUM(daily_curtailment) + SUM(daily_unavailability) + SUM(daily_undetermined) + SUM(adj_AOP) AS suma_total
            
    FROM CTE_metrico
    GROUP BY periodo;

    -- Actualizar los valores de la tabla dividiendo por la suma total
    UPDATE metricos_test
    SET 
        cleanliness = ROUND( (cleanliness * 100)/cumplimiento_adj, 2),
        curtailment = ROUND( (curtailment * 100)/cumplimiento_adj, 2),
        unavailability = ROUND( (unavailability*100)/cumplimiento_adj, 2),
        undetermined = ROUND( (undetermined * 100)/cumplimiento_adj, 2),
        cumplimiento_adj = ROUND( (cumplimiento_adj * 100)/suma_total, 2),
        resource = ROUND(resource*100, 2);

    -- Seleccionar los resultados finales
    SELECT * FROM metricos_test;

END
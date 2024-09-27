CREATE DEFINER=root@localhost PROCEDURE Solarity.desglose_perdidas_test(
    IN planta_id INT,
    IN agrupar_por_semana BOOLEAN -- Parámetro para indicar si agrupar por semana
)
BEGIN
    -- Eliminar las tablas temporales si ya existen
    DROP TEMPORARY TABLE IF EXISTS metricos;
    DROP TEMPORARY TABLE IF EXISTS desglose_perdidas;

    -- Crear la tabla temporal desglose_perdidas
    CREATE TEMPORARY TABLE desglose_perdidas AS
    SELECT *,
        (COALESCE(valorTeorico, 0) - COALESCE(AOP, 0) - COALESCE(soiling_ppto, 0) - COALESCE(unavailable_ppto, 0) - COALESCE(curtailment_ppto, 0)) AS resource,
        (COALESCE(valorTeorico, 0) - (COALESCE(unavailable, 0) + COALESCE(soiling, 0) + COALESCE(clipping, 0)) - COALESCE(valor_lectura, 0)) AS indeterminado
    FROM (
        SELECT 
            -- Obtener valores desde tabla proyeccionGeneracion
            pg.id_planta, 
            pg.fecha, 
            pg.valor * 1000 AS AOP, 
            pg.soiling * 1000 AS soiling_ppto, 
            pg.indisponibilidad * 1000 AS unavailable_ppto, 
            pg.curtailment * 1000 AS curtailment_ppto, 
            pg.valorTeorico * 1000 AS valorTeorico,
            
            -- Obtener valores desde tabla perdidasDiariasPlanta
            pdp.incidencia * 1000 AS unavailable,
            pdp.soiling * 1000 AS soiling,
            pdp.clipping * 1000 AS clipping,
            
            -- Obtener valores desde tabla lecturaGeneracion
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
            pg.id_planta = planta_id 
            AND pg.valorTeorico IS NOT NULL
    ) AS subquery;

    -- Crear la tabla temporal metricos para almacenar los resultados finales de todas las métricas
    CREATE TEMPORARY TABLE metricos AS
    SELECT 
        fecha,
        -- Calcular cada métrica y manejar división por cero
        (COALESCE(resource, 0) / NULLIF((COALESCE(AOP, 0) + COALESCE(soiling_ppto, 0) + COALESCE(unavailable_ppto, 0) + COALESCE(curtailment_ppto, 0)), 0)) * 100 AS resource_pct,
        (COALESCE(indeterminado, 0) / NULLIF(COALESCE(valorTeorico, 0), 0)) * 100 AS undetermined_pct,
        (COALESCE(clipping, 0) / NULLIF(COALESCE(valorTeorico, 0), 0)) * 100 AS curtailment_pct,
        (COALESCE(soiling, 0) / NULLIF(COALESCE(valorTeorico, 0), 0)) * 100 AS soiling_pct,
        (COALESCE(unavailable, 0) / NULLIF(COALESCE(valorTeorico, 0), 0)) * 100 AS unavailable_pct
    FROM desglose_perdidas;

    -- Verificar si se agrupa por semana
    IF agrupar_por_semana THEN
        SELECT 
            -- Calcular el lunes de la semana correspondiente
            DATE_FORMAT(DATE_SUB(fecha, INTERVAL WEEKDAY(fecha) DAY), '%Y-%m-%d') AS semana_inicio,
            SUM(resource_pct) AS resource_pct_sum,
            SUM(undetermined_pct) AS undetermined_pct_sum,
            SUM(curtailment_pct) AS curtailment_pct_sum,
            SUM(soiling_pct) AS soiling_pct_sum,
            SUM(unavailable_pct) AS unavailable_pct_sum
        FROM 
            metricos
        GROUP BY 
            DATE_SUB(fecha, INTERVAL WEEKDAY(fecha) DAY);
    ELSE
        -- Si no se agrupa por semana, devolver la tabla metricos original
        SELECT * FROM metricos;
    END IF;

END;

CREATE DEFINER=`root`@`localhost` PROCEDURE `Solarity`.`gdp_semanal`(
    IN _plantas VARCHAR(255) -- Cadena de identificadores de plantas separados por comas
)
BEGIN
    -- Eliminar las tablas temporales si ya existen
    DROP TEMPORARY TABLE IF EXISTS metricos;
    DROP TEMPORARY TABLE IF EXISTS desglose_perdidas;

    -- Crear la tabla temporal desglose_perdidas
    CREATE TEMPORARY TABLE desglose_perdidas AS
    SELECT *,
    (COALESCE(valorTeorico, 0) - COALESCE(AOP, 0) - COALESCE(soiling_ppto, 0) - COALESCE(unavailable_ppto, 0) - COALESCE(curtailment_ppto, 0)) AS resource,
    (COALESCE(valorTeorico, 0) - (COALESCE(unavailable, 0) + COALESCE(soiling, 0) + COALESCE(clipping, 0)) - COALESCE(valor_lectura, 0)) AS indeterminado,
    
    (COALESCE(unavailable_ppto, 0) / COALESCE(NULLIF(AOP + soiling_ppto, 0), 1)) * valorTeorico AS PPTO_adj_unavailable,
    (COALESCE(curtailment_ppto, 0) / COALESCE(NULLIF(AOP + soiling_ppto + unavailable_ppto + curtailment_ppto, 0), 1)) * valorTeorico AS PPTO_adj_curtailment,
    (COALESCE(soiling_ppto, 0) / COALESCE(NULLIF(AOP + soiling_ppto + unavailable_ppto + curtailment_ppto, 0), 1)) * valorTeorico AS PPTO_adj_soiling,

    -- Recalcular el valor en vez de referenciar las columnas calculadas
    valorTeorico - (
        (COALESCE(soiling_ppto, 0) / COALESCE(NULLIF(AOP + soiling_ppto + unavailable_ppto + curtailment_ppto, 0), 1)) * valorTeorico +
        (COALESCE(unavailable_ppto, 0) / COALESCE(NULLIF(AOP + soiling_ppto, 0), 1)) * valorTeorico +
        (COALESCE(curtailment_ppto, 0) / COALESCE(NULLIF(AOP + soiling_ppto + unavailable_ppto + curtailment_ppto, 0), 1)) * valorTeorico
    ) AS PPTO_adj_AOP

    FROM (*
        SELECT 
            pg.id_planta, 
            pg.fecha, 
            pg.valor * 1000 AS AOP, 
            pg.soiling * 1000 AS soiling_ppto, 
            pg.indisponibilidad * 1000 AS unavailable_ppto, 
            pg.curtailment * 1000 AS curtailment_ppto, 
            pg.valorTeorico * 1000 AS valorTeorico,

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
    ) AS subquery;

    -- Crear la tabla temporal metricos, agrupando por semana y calculando porcentajes
    CREATE TEMPORARY TABLE metricos AS
    SELECT 
        DATE_SUB(fecha, INTERVAL WEEKDAY(fecha) DAY) AS semana, -- Calcular el inicio de la semana

        SUM(valorTeorico) AS suma_valorTeorico,
        SUM(resource) AS suma_resource,
        SUM(indeterminado) AS suma_indeterminado,
        SUM(clipping) AS suma_clipping,
        SUM(soiling) AS suma_soiling,
        SUM(unavailable) AS suma_unavailable,

        (SUM(resource) / NULLIF(SUM(valorTeorico), 0)) * 100 AS resource_pct,
        (SUM(indeterminado) / NULLIF(SUM(valorTeorico), 0)) * 100 AS undetermined_pct,
        (SUM(clipping) / NULLIF(SUM(valorTeorico), 0)) * 100 AS curtailment_pct,
        (SUM(soiling) / NULLIF(SUM(valorTeorico), 0)) * 100 AS soiling_pct,
        (SUM(unavailable) / NULLIF(SUM(valorTeorico), 0)) * 100 AS unavailable_pct
    FROM desglose_perdidas
    GROUP BY semana;

    -- Devolver los resultados
    SELECT * FROM metricos;

END
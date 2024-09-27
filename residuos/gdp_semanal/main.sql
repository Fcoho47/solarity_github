CREATE DEFINER=root@localhost PROCEDURE Solarity.generar_desglose_perdidas(
    IN planta_id INT
)
BEGIN
    -- Eliminar las tablas temporales si ya existen
    DROP TEMPORARY TABLE IF EXISTS metricos;
    DROP TEMPORARY TABLE IF EXISTS desglose_perdidas;

    -- Crear la tabla temporal desglose_perdidas
    CREATE TEMPORARY TABLE desglose_perdidas AS
    SELECT *,
        (COALESCE(valorTeorico, 0) - COALESCE(AOP, 0) - COALESCE(soiling_ppto, 0) - COALESCE(unavailable_ppto, 0) - COALESCE(curtailment_ppto, 0)) AS resource,
        (COALESCE(valorTeorico, 0) - (COALESCE(unavailable, 0) + COALESCE(soiling, 0) + COALESCE(clipping, 0)) - COALESCE(valor_lectura)) AS indeterminado
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

    SELECT * FROM metricos;

END;
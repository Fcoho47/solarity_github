
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
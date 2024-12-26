CREATE DEFINER=`root`@`localhost` PROCEDURE `Solarity`.`ReporteOperaciones`(
    IN _agrupamiento VARCHAR(32), 
    IN _inicio DATETIME, 
    IN _fin DATETIME, 
    IN _plantas VARCHAR(1024),
    IN _filtroIncidencias VARCHAR(64)
)
BEGIN
    -- Definir variables útiles
    DECLARE energiaFaltante FLOAT DEFAULT 0;
    DECLARE energiaProyectadaTotal DECIMAL(15,3) DEFAULT 0; -- Variable para capturar el valor de salida
    DECLARE defaultSoilingLevel FLOAT DEFAULT 0.075;
    DECLARE _finCorregido DATE DEFAULT IF(_fin >= CURRENT_DATE(), DATE_SUB(CURRENT_DATE(), INTERVAL 1 SECOND), _fin);
    DECLARE filtroIncidencias VARCHAR(64) DEFAULT IF (_filtroIncidencias = 'Todas', 1, 0);
    DECLARE aporteIndisponibilidad FLOAT DEFAULT 0;

    -- Crear tabla temporal
    CALL crear_insert_init(_plantas);

    -- Calcular los métricas de generación
    CALL calcularGeneracionTotal(_inicio, _finCorregido, energiaProyectadaTotal);
     
     -- Calcular las métricas de disponibilidad
    CALL calcularMetricasAdicionales(_inicio, _finCorregido, aporteIndisponibilidad);

    -- Generar reporte final
    IF _agrupamiento = 'cliente' THEN
        SELECT
            cliente as "Cliente",
            COUNT(1) as "Cantidad de plantas",
            SUM(potencia)/1000 as "Potencia total (kWp)",
            SUM(generacion_real) as "Generación real",
            SUM(generacion_proyectada) as "Generación proyectada",
            AVG(fp_proyectado) as "FP proyectado",
            AVG(fp_generado) as "FP generado",
            SUM(generacion_real)/SUM(generacion_proyectada) as "Cumplimiento",
            (SUM(generacion_proyectada) - SUM(generacion_real)) / energiaProyectadaTotal as "Impacto incumplimiento",
            AVG(data_presente) as "% de Datos"
        FROM tmp_reporte_operaciones
        GROUP BY cliente ORDER BY cliente;
    ELSE
        SELECT
            planta as "Planta",
            cliente as "Cliente",
            API,
            id_planta as "Planta ID",
            latitud as "Latitud",
            longitud as "Longitud",
            potencia/1000 as "Potencia (kWp)",
            generacion_real as "Generación real",
            generacion_teorica AS "Generación teórica",
            generacion_proyectada as "Generación proyectada",
            COALESCE(aporte_denominador_capacity_factor, 0) AS "Generación para Factor Planta",
            fp_proyectado as "FP proyectado",
            fp_generado as "FP generado",
            cumplimiento as "Cumplimiento",
            cumplimiento_radiacion as "Cumpl. Radiación",
            PR as "Performance Ratio",
            energia_incidente_poa AS "Energía POA",
            (generacion_teorica*(1-defaultSoilingLevel))/generacion_proyectada_total - 1 AS "Delta radiación",
            data_presente as "% de Datos",
            CASE
                WHEN cumplimiento >= 0.95 THEN "> 95 %"
                WHEN cumplimiento >= 0.85 THEN "> 85 %"
                ELSE "< 85 %"
            END AS "Nivel Cumplimiento",
            CASE
                WHEN cotaInferiorDisp >= 0.95 THEN "> 95 %"
                WHEN cotaInferiorDisp >= 0.85 THEN "> 85 %"
                ELSE "< 85 %"
            END AS "Nivel de Disponibilidad",
            100 * (generacion_proyectada - generacion_real) / energiaProyectadaTotal as "Impacto incumplimiento",
            impacto_indisponibilidad/aporteIndisponibilidad as "Impacto indisponibilidad",
            (cotaInferiorDisp + cotaSuperioDisp)/2 as "Disponibilidad",
            cotaInferiorDisp as "Disponibilidad Ajustada",
            cotaSuperioDisp as "Disponibilidad Estimada",
            (cotaSuperioDisp - cotaInferiorDisp)/2  as "Error Disponibilidad",
            potencia_ac as "Potencia AC",
            potencia_afectada_gx as "Potencia afectada Gx",
            potencia_afectada_comms as "Potencia afectada Comms",
            indisponibilidad as "Indisponibilidad",
            dias_operacion AS "Dias en operacion",
            aporteDispPotenciaTiempo AS "Aporte disp. pot. tiempo",
            aporteErrorDispPotenciaTiempo AS "Aporte error disp. pot. tiempo"
        FROM tmp_reporte_operaciones
        ORDER BY cliente;
    END IF;
END
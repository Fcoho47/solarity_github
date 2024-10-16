CREATE DEFINER=`root`@`localhost` PROCEDURE `Solarity`.`test_calcularMetricasAdicionales`(
    IN _inicio DATETIME, 
    IN _fin DATETIME
)
BEGIN
	-- Definición de variables
    DECLARE fin_cursor INT DEFAULT 0;
    DECLARE planta_id INT;
    DECLARE planta_potencia FLOAT;
    DECLARE planta_inicioGeneracion DATE;
    DECLARE planta_api VARCHAR(64);
    DECLARE inicioEfectivo DATE DEFAULT _inicio;
    DECLARE periodoDias INT DEFAULT DATEDIFF(_fin, _inicio) + 1;

    DECLARE temp_disponibilidad FLOAT;
    DECLARE temp_cotaInferiorDisp FLOAT;
    DECLARE temp_cotaSuperioDisp FLOAT;
    DECLARE temp_errorDisponibilidad FLOAT;

    DECLARE temp_potenciaACvar FLOAT;
    DECLARE temp_potenciaAfectadaGeneracion FLOAT;
    DECLARE temp_potenciaAfectadaComunicacion FLOAT;

    DECLARE temp_dataPresente FLOAT DEFAULT 0;

    DECLARE aporteIndispPlanta FLOAT DEFAULT 0;
    DECLARE aporteIndisponibilidad FLOAT DEFAULT 0;


    -- Define el cursor
    DECLARE cursor_plantas CURSOR FOR 
        SELECT id_planta, potencia, inicio_generacion, API 
        FROM tmp_reporte_operaciones;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin_cursor = 1;

    -- Abre el cursor
    OPEN cursor_plantas;

    -- Bucle para procesar cada planta
    loop_cursor: LOOP
        FETCH cursor_plantas INTO planta_id, planta_potencia, planta_inicioGeneracion, planta_api;
        IF fin_cursor THEN LEAVE loop_cursor; END IF;

        -- Corrección de fechas
        IF planta_inicioGeneracion > _inicio THEN
            SET inicioEfectivo = planta_inicioGeneracion;
            SET periodoDias = DATEDIFF(_fin, inicioEfectivo) + 1;
        END IF;

        IF planta_inicioGeneracion >= _fin THEN
            SET periodoDias = 0;
        END IF;

        -- Cálculo de disponibilidad y cotas
        SELECT
            SUM(ce.valor * de.disponibilidad_ajustada) / SUM(ce.valor),
            SUM(ce.valor * IFNULL(de.disponibilidad_ajustada, 0)) / SUM(ce.valor),
            SUM(ce.valor * IFNULL(de.disponibilidad_ajustada, 1)) / SUM(ce.valor)
        INTO temp_disponibilidad, temp_cotaInferiorDisp, temp_cotaSuperioDisp
        FROM disponibilidadEquipo de
        INNER JOIN equipo e ON e.id = de.id_equipo
        INNER JOIN caracteristicaEquipo ce ON ce.id_equipo = e.id
        WHERE
            de.fecha >= inicioEfectivo AND de.fecha <= _fin
            AND de.periodo_no_accionable IN (0, 1)
            AND e.id_planta = planta_id
            AND e.activo = 1;

        -- Error de disponibilidad
        SET temp_errorDisponibilidad = (temp_cotaSuperioDisp - temp_cotaInferiorDisp) / 2;

        -- Potencia AC
        SELECT SUM(potencia) INTO temp_potenciaACvar 
        FROM potencia_ac_plantas 
        WHERE id_planta = planta_id;

        -- Potencia afectada por generación y comunicación
        SELECT SUM(ta.compromised_power) INTO temp_potenciaAfectadaGeneracion 
        FROM zammad.tickets_activos ta 
        WHERE ta.plant_identifier = planta_id AND ta.`type` IN ('gx', 'grid-incidence');

        SELECT SUM(ta.compromised_power) INTO temp_potenciaAfectadaComunicacion 
        FROM zammad.tickets_activos ta 
        WHERE ta.plant_identifier = planta_id AND ta.`type` IN ('comms', 'grid-incidence');

        -- Verificar si hay datos presentes
        IF (periodoDias > 0) THEN
            SELECT COUNT(1)/periodoDias INTO temp_dataPresente
            FROM lecturaGeneracionPlanta
            WHERE id_planta = planta_id AND fecha >= inicioEfectivo AND fecha <= _fin; 
        ELSE
            SELECT 1 INTO temp_dataPresente;
        END IF;

        IF (periodoDias > 0) THEN
            SET aporteIndispPlanta = (1 - (temp_cotaSuperioDisp + temp_cotaInferiorDisp)/2.0)*planta_potencia*periodoDias;
        END IF;

        IF (temp_cotaInferiorDisp IS NOT NULL) THEN
            SET aporteIndisponibilidad = aporteIndisponibilidad + planta_potencia*periodoDias;
        END IF;

        -- Actualizar la tabla temporal con las métricas adicionales
        UPDATE tmp_reporte_operaciones
        SET
            disponibilidad = temp_disponibilidad,
            cotaInferiorDisp = temp_cotaInferiorDisp,
            cotaSuperioDisp = temp_cotaSuperioDisp,
            errorDisponibilidad = temp_errorDisponibilidad,
            potencia_ac = temp_potenciaACvar,
            potencia_afectada_gx = temp_potenciaAfectadaGeneracion,
            potencia_afectada_comms = temp_potenciaAfectadaComunicacion,
            indisponibilidad = 1 - temp_disponibilidad,
            dias_operacion = periodoDias,
            aporteDispPotenciaTiempo = periodoDias * planta_potencia * (temp_cotaSuperioDisp + temp_cotaInferiorDisp) / (2 * 1000),
            aporteErrorDispPotenciaTiempo = periodoDias * planta_potencia * (temp_cotaSuperioDisp - temp_cotaInferiorDisp) / (2 * 1000),
            aporte_denominador_capacity_factor = periodoDias * 24 * temp_potenciaACvar,
            data_presente = temp_dataPresente, 
            impacto_indisponibilidad = 100 * (aporteIndispPlanta / aporteIndisponibilidad)
        WHERE id_planta = planta_id;

    END LOOP;

    CLOSE cursor_plantas;
END
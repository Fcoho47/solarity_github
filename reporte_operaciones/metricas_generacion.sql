CREATE DEFINER=`root`@`localhost` PROCEDURE `Solarity`.`test_calcularGeneracionTotal`(
    IN _inicio DATETIME, 
    IN _fin DATETIME,
    OUT _energiaProyectadaTotal DECIMAL(15,3)
)
BEGIN
	-- Define variables 
    DECLARE fin_cursor INT DEFAULT 0;
    DECLARE planta_id INT;
    DECLARE planta_potencia INT DEFAULT 0;
    DECLARE planta_inicioGeneracion DATE DEFAULT _inicio;
    DECLARE planta_api VARCHAR(64) DEFAULT "";
   
    DECLARE inicioEfectivo DATE DEFAULT _inicio;
    DECLARE periodoDias INT DEFAULT DATEDIFF(_fin,_inicio)+1;
   
    DECLARE temp_generacionTotal DECIMAL(15,3);
    DECLARE temp_generacionProyectada DECIMAL(15,3);
    DECLARE temp_generacionProyectadaTotal DECIMAL(15,3) DEFAULT 0;

    DECLARE temp_fpProyectado FLOAT;
    DECLARE temp_fpGenerado FLOAT;

    DECLARE temp_generacionTeorica DECIMAL(15,3);
    DECLARE temp_energiaIncidentePOA DECIMAL(15,3);

    DECLARE temp_cumplimientoRadiacion FLOAT;
    DECLARE temp_cumplimiento FLOAT;

    DECLARE temp_PR FLOAT;

    DECLARE temp_energiaFaltante FLOAT DEFAULT 0;
    DECLARE temp_energiaProyectadaTotal FLOAT DEFAULT 0;

    -- Define el cursor
    DECLARE cursor_plantas CURSOR FOR 
        SELECT id_planta,potencia,inicio_generacion,API FROM tmp_reporte_operaciones;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin_cursor = 1;

    OPEN cursor_plantas;

    -- Bucle para procesar cada planta
    loop_cursor: LOOP
        FETCH cursor_plantas INTO planta_id, planta_potencia, planta_inicioGeneracion, planta_api;
        IF fin_cursor THEN LEAVE loop_cursor; END IF;
       
        -- Correción de fechas
        IF(planta_inicioGeneracion > _inicio) THEN
			SET inicioEfectivo = planta_inicioGeneracion;
            SET periodoDias = DATEDIFF(_fin,inicioEfectivo)+1;
        END IF;
       
        IF (planta_inicioGeneracion >= _fin) THEN
        	SET periodoDias = 0;
    	END IF;

        -- Cálculo de generación total
        SELECT COALESCE(SUM(valor), 0) INTO temp_generacionTotal 
        FROM lecturaGeneracionPlanta 
        WHERE id_planta = planta_id AND fecha >= inicioEfectivo AND fecha <= _fin;
       
        -- Cálculo de generación proyectada
        SELECT SUM(valor)*1000 INTO temp_generacionProyectada FROM proyeccionGeneracion pg
    	WHERE id_planta = planta_id AND fecha IN (
            SELECT fecha FROM lecturaGeneracionPlanta
        	WHERE id_planta = planta_id AND fecha >= inicioEfectivo AND fecha <= _fin);
        
        -- Cálculo de generación proyectada total
        SELECT SUM(valor)*1000 INTO temp_generacionProyectadaTotal
        FROM proyeccionGeneracion pg
        WHERE id_planta = planta_id AND fecha >= inicioEfectivo AND fecha <= _fin;
        
        -- Cálculo de factores de planta
        SELECT IF(planta_potencia IS NULL OR planta_potencia=0, NULL, AVG(valor*1000/planta_potencia/24)) INTO temp_fpProyectado
        FROM proyeccionGeneracion 
        WHERE id_planta = planta_id AND fecha >= inicioEfectivo AND fecha <= _fin;

        SELECT IF(planta_potencia IS NULL OR planta_potencia=0, NULL, AVG(valor/planta_potencia/24)) INTO temp_fpGenerado
        FROM lecturaGeneracionPlanta 
        WHERE id_planta = planta_id AND fecha >= inicioEfectivo AND fecha <= _fin;

        -- Calcular generación teórica
        SELECT SUM(valorTeorico)*1000 INTO temp_generacionTeorica 
        FROM proyeccionGeneracion pg 
        WHERE id_planta = planta_id AND fecha >= inicioEfectivo AND fecha <= _fin;

        -- Calcular energía incidente POA
        SELECT SUM(pg.energiaIncidentePOA)*1000 INTO temp_energiaIncidentePOA 
        FROM proyeccionGeneracion pg 
        WHERE id_planta = planta_id AND fecha >= inicioEfectivo AND fecha <= _fin;

        -- Calcular cumplimiento de radiación
        IF (temp_generacionTeorica IS NOT NULL) THEN
            SELECT IF (temp_generacionTeorica=0, NULL, (temp_generacionTotal/temp_generacionTeorica)) INTO temp_cumplimientoRadiacion;
        ELSE
            SELECT NULL INTO temp_cumplimientoRadiacion;
        END IF;

        -- Calcular cumplimiento
        SELECT IF(temp_generacionProyectada=0, NULL, (temp_generacionTotal/temp_generacionProyectada)) INTO temp_cumplimiento;

        -- Calcular PR
        IF (temp_energiaIncidentePOA IS NOT NULL) THEN
            SELECT IF (temp_energiaIncidentePOA=0, NULL, (temp_generacionTotal/temp_energiaIncidentePOA)) INTO temp_PR;
        ELSE
            SELECT NULL INTO temp_PR;
        END IF;

        -- Calcular energía faltante
        IF (temp_generacionProyectada IS NOT NULL AND temp_generacionTotal IS NOT NULL) THEN                    
            IF (temp_generacionProyectada > temp_generacionTotal) THEN
                SET temp_energiaProyectadaTotal = temp_energiaProyectadaTotal + temp_generacionProyectada;
                SET temp_energiaFaltante = temp_energiaFaltante + (temp_generacionProyectada - temp_generacionTotal);
            END IF;
        END IF;
        

        -- Actualiza la tabla temporal con el valor calculado
        UPDATE tmp_reporte_operaciones
    	SET
    		generacion_real = temp_generacionTotal,
        	generacion_proyectada = temp_generacionProyectada,
        	generacion_proyectada_total = temp_generacionProyectadaTotal,
            fp_Proyectado = temp_fpProyectado,
            fp_Generado = temp_fpGenerado,
            generacion_teorica = temp_generacionTeorica,
            energia_incidente_poa = temp_energiaIncidentePOA,
            cumplimiento_radiacion = temp_cumplimientoRadiacion,
            cumplimiento = temp_cumplimiento,
            PR = temp_PR

        WHERE id_planta = planta_id;

    END LOOP;

    -- Asigna el valor calculado a la variable de salida
    SET _energiaProyectadaTotal = temp_energiaProyectadaTotal;

    CLOSE cursor_plantas;
END
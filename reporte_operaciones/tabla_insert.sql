CREATE DEFINER=`root`@`localhost` PROCEDURE `Solarity`.`test_crearTablaTemporalInsertarDatos`(
    IN _plantas VARCHAR(1024)
)
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_reporte_operaciones;
        
    CREATE TEMPORARY TABLE tmp_reporte_operaciones(
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        planta VARCHAR(256) NOT NULL,
        cliente VARCHAR(256) NOT NULL,
        API VARCHAR(64),
        id_planta INT NOT NULL,
        latitud FLOAT,
        longitud FLOAT,
        potencia FLOAT,
        inicio_generacion DATE,
        generacion_real DECIMAL(15,3),
        generacion_proyectada DECIMAL(15,3),
        generacion_proyectada_total DECIMAL(15,3),
        generacion_teorica DECIMAL(15,3),
        energia_incidente_poa DECIMAL(15,3),
        fp_proyectado FLOAT,
        fp_generado FLOAT,
        cumplimiento FLOAT,
        data_presente FLOAT,
        disponibilidad FLOAT,
        cotaInferiorDisp FLOAT,
        cotaSuperioDisp FLOAT,
        errorDisponibilidad FLOAT,
        cumplimiento_radiacion FLOAT,
        PR FLOAT,
        potencia_ac FLOAT,
        potencia_afectada_comms FLOAT,
        potencia_afectada_gx FLOAT,
        aporte_indisponibilidad FLOAT,
        indisponibilidad FLOAT,
        dias_operacion INT,
        aporteDispPotenciaTiempo FLOAT,
        aporteErrorDispPotenciaTiempo FLOAT,
        aporte_denominador_capacity_factor FLOAT,
        delta_ghi FLOAT
    );

    INSERT INTO tmp_reporte_operaciones
    SELECT
        NULL,
        planta.nombre,
        COALESCE(cliente.nombre, 'Sin definir'),
        API,
        planta.id,
        latitud,
        longitud,
        potencia,
        inicioGeneracion,
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    FROM planta
    LEFT JOIN cliente ON planta.id_cliente = cliente.id
    WHERE 
        ((_plantas = 'Todas' AND planta.subEtapa = 'Operación') 
        OR (_plantas <> 'Todas' AND FIND_IN_SET(planta.id, _plantas)))
        AND planta.inicioGeneracion IS NOT NULL;
END
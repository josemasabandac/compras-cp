
  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "PK_CORP_APROBACION" as

    -- =========================================================================
    -- fn_agregar_comentario: Función privada para añadir una entrada al JSON
    --                        de bitácora en la columna COMENTARIOS.
    -- =========================================================================
    function fn_agregar_comentario (
        p_comentarios_actual IN CLOB,
        p_usuario            IN VARCHAR2,
        p_comentario         IN VARCHAR2,
        p_accion             IN VARCHAR2
    ) return CLOB is
        v_comentario_sanitizado varchar2(4000);
        v_nuevo_item            varchar2(4000);
        v_json_result           clob;
    begin
        v_comentario_sanitizado := replace(replace(replace(nvl(p_comentario, ''), '\', '\\'), '"', '\"'), chr(10), '\n');
        v_nuevo_item := '{"fecha":"' || to_char(systimestamp, 'YYYY-MM-DD"T"HH24:MI:SS.FF3') ||
                        '","usuario":"' || p_usuario ||
                        '","comentario":"' || v_comentario_sanitizado ||
                        '","accion":"' || p_accion || '"}';

        if p_comentarios_actual is null or length(trim(p_comentarios_actual)) = 0 then
            v_json_result := '[' || v_nuevo_item || ']';
        else
            v_json_result := trim(p_comentarios_actual);
            if substr(v_json_result, -1) = ']' then
                v_json_result := substr(v_json_result, 1, length(v_json_result) - 1);
                if length(v_json_result) > 1 then
                    v_json_result := v_json_result || ',' || v_nuevo_item || ']';
                else
                    v_json_result := '[' || v_nuevo_item || ']';
                end if;
            else
                v_json_result := '[' || v_nuevo_item || ']';
            end if;
        end if;

        return v_json_result;
    end fn_agregar_comentario;

    -- =========================================================================
    -- fn_actualizar_usuarios_aprobacion: Actualiza los estados en el JSON
    --                                    USUARIOSAPROBACION al aprobar o rechazar.
    -- =========================================================================
    function fn_actualizar_usuarios_aprobacion (
        p_usuarios_json IN VARCHAR2,
        p_usuario       IN VARCHAR2,
        p_accion        IN VARCHAR2
    ) return VARCHAR2 is
        v_arr        json_array_t;
        v_obj        json_object_t;
        v_usr        varchar2(100);
        v_estado     varchar2(50);
        v_encontro   boolean := false;
        v_siguiente  boolean := false;
        v_fecha_str  varchar2(30);
    begin
        if p_usuarios_json is null then
            return null;
        end if;

        v_fecha_str := to_char(systimestamp, 'YYYY-MM-DD HH24:MI:SS');
        v_arr := json_array_t.parse(p_usuarios_json);

        for i in 0 .. v_arr.get_size - 1 loop
            v_obj := treat(v_arr.get(i) as json_object_t);
            v_usr := v_obj.get_string('usuario');
            v_estado := v_obj.get_string('estado');

            if not v_encontro then
                if upper(v_usr) = upper(p_usuario) or (v_estado = 'EN PROCESO' and not v_encontro) then
                    if p_accion = 'APROBAR' then
                        v_obj.put('estado', 'APROBADO');
                        v_obj.put('fechaaprobacion', v_fecha_str);
                        v_encontro := true;
                        v_siguiente := true;
                    elsif p_accion = 'RECHAZAR' then
                        v_obj.put('estado', 'RECHAZADO');
                        v_obj.put('fechaaprobacion', v_fecha_str);
                        v_encontro := true;
                        v_siguiente := false;
                    end if;
                end if;
            elsif v_siguiente and v_estado = 'PENDIENTE' then
                v_obj.put('estado', 'EN PROCESO');
                v_siguiente := false;
            end if;
        end loop;

        return v_arr.to_string;
    exception
        when others then
            return p_usuarios_json;
    end fn_actualizar_usuarios_aprobacion;

    -- =========================================================================
    -- fn_obtener_ultimo_comentario: Función privada para extraer el último
    --                               comentario de texto registrado en el JSON.
    -- =========================================================================
    function fn_obtener_ultimo_comentario (
        p_comentarios IN CLOB,
        p_fallback    IN VARCHAR2 DEFAULT NULL
    ) return VARCHAR2 is
        v_arr        json_array_t;
        v_obj        json_object_t;
        v_comentario varchar2(4000);
    begin
        if p_comentarios is null or length(trim(p_comentarios)) = 0 then
            return p_fallback;
        end if;

        v_arr := json_array_t.parse(p_comentarios);
        if v_arr.get_size > 0 then
            v_obj := treat(v_arr.get(v_arr.get_size - 1) as json_object_t);
            v_comentario := v_obj.get_string('comentario');
            return nvl(v_comentario, p_fallback);
        end if;

        return p_fallback;
    exception
        when others then
            return nvl(substr(to_char(p_comentarios), 1, 4000), p_fallback);
    end fn_obtener_ultimo_comentario;

    -- =========================================================================
    -- sp_enviar_aprobacion: Inserta registro de snapshot en T_CORP_APROBACIONES
    -- =========================================================================
    procedure sp_enviar_aprobacion (
        p_compania          IN VARCHAR2,
        p_codmodulo         IN VARCHAR2,
        p_tipoorden         IN VARCHAR2 DEFAULT NULL,
        p_numeroorden       IN VARCHAR2 DEFAULT NULL,
        p_tipodocumento     IN VARCHAR2 DEFAULT NULL,
        p_numerodocumento   IN VARCHAR2 DEFAULT NULL,
        p_tipoproceso       IN VARCHAR2 DEFAULT NULL,
        p_numeroproceso     IN VARCHAR2 DEFAULT NULL,
        p_confidencial      IN VARCHAR2 DEFAULT 'N',
        p_descripcion1      IN VARCHAR2 DEFAULT NULL,
        p_descripcion2      IN VARCHAR2 DEFAULT NULL,
        p_descripcion3      IN VARCHAR2 DEFAULT NULL,
        p_descripcion4      IN VARCHAR2 DEFAULT NULL,
        p_descripcion5      IN VARCHAR2 DEFAULT NULL,
        p_idrutaaprobacion  IN NUMBER,
        p_idflujoaprobacion IN NUMBER,
        p_usuarioinicia     IN VARCHAR2 DEFAULT NULL,
        p_usuarioalterno    IN VARCHAR2 DEFAULT NULL,
        p_fechainicio       IN TIMESTAMP DEFAULT NULL,
        p_fechalimite       IN TIMESTAMP DEFAULT NULL,
        p_prioridad         IN VARCHAR2 DEFAULT 'MEDIA',
        p_etiqueta1         IN VARCHAR2 DEFAULT NULL,
        p_etiqueta2         IN VARCHAR2 DEFAULT NULL,
        p_etiqueta3         IN VARCHAR2 DEFAULT NULL,
        p_etiqueta4         IN VARCHAR2 DEFAULT NULL,
        p_etiqueta5         IN VARCHAR2 DEFAULT NULL,
        p_comentario        IN CLOB DEFAULT NULL,
        p_moneda            IN VARCHAR2 DEFAULT NULL,
        p_montototal        IN NUMBER DEFAULT NULL,
        p_detallemontos     IN CLOB DEFAULT NULL,
        p_objeto0           IN CLOB DEFAULT NULL,
        p_objeto1           IN CLOB DEFAULT NULL,
        p_objeto2           IN CLOB DEFAULT NULL,
        p_objeto3           IN CLOB DEFAULT NULL,
        p_objeto4           IN CLOB DEFAULT NULL,
        p_objeto5           IN CLOB DEFAULT NULL,
        p_objeto6           IN CLOB DEFAULT NULL,
        p_objeto7           IN CLOB DEFAULT NULL,
        p_objeto8           IN CLOB DEFAULT NULL,
        p_objeto9           IN CLOB DEFAULT NULL,
        o_estato_exito      OUT NUMBER,
        o_respuesta         OUT VARCHAR2,
        o_termina           OUT NUMBER
    ) as
        v_confidencial        varchar2(1);
        v_fechainicio         timestamp;
        v_prioridad           varchar2(20);
        v_comentario          clob;
        v_comentario_resuelto clob;
        v_usuariosaprobacion  varchar2(2000);
        v_usuarioactual       varchar2(25);
        v_usuarioinicia       varchar2(25);
        v_entidad_clase       varchar2(200);
        v_entidad_id          varchar2(200);
        v_modulo_flujo        varchar2(20);
        v_cia_flujo           varchar2(20);
        v_flujo_estado        varchar2(20);
        v_estado_snapshot     varchar2(20);
    begin
        v_log_app := 'PK_CORP_APROBACION';
        v_log_dsc := 'sp_enviar_aprobacion';
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        -- Validar parámetros obligatorios
        if p_idrutaaprobacion is null or p_idflujoaprobacion is null then
            o_estato_exito := 0;
            o_respuesta := 'p_idrutaaprobacion y p_idflujoaprobacion son obligatorios y no pueden ser nulos';
            v_log_msg := 'Error de validacion: ' || o_respuesta;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
            return;
        end if;

        o_estato_exito := 1;
        o_respuesta := 'Procesado exitosamente';

        v_confidencial := nvl(p_confidencial, 'N');
        v_fechainicio  := nvl(p_fechainicio, systimestamp);
        v_prioridad    := nvl(p_prioridad, 'MEDIA');

        -- Descubrir aprobador actual, usuario iniciador, estado del flujo y metadatos desde VT_FLUJO_APROBACION
        begin
            select max(usuarioactual), max(entidad_clase), max(entidad_id), max(codmodulo), max(compania), max(usuarioiniciador), max(flujo_estado)
              into v_usuarioactual, v_entidad_clase, v_entidad_id, v_modulo_flujo, v_cia_flujo, v_usuarioinicia, v_flujo_estado
              from data.vt_flujo_aprobacion
             where idflujo = p_idflujoaprobacion;
        exception
            when others then
                v_usuarioactual := null;
                v_entidad_clase := null;
                v_entidad_id    := null;
                v_modulo_flujo  := null;
                v_cia_flujo     := null;
                v_usuarioinicia := null;
                v_flujo_estado  := null;
        end;

        v_usuarioinicia := nvl(p_usuarioinicia, nvl(v_usuarioinicia, 'SISTEMA'));

        -- Determinar si el flujo fue auto-aprobado (creador = único aprobador)
        if v_flujo_estado = 'APROBADO' then
            v_estado_snapshot := 'APROBADO';
            o_termina := 1;
        else
            v_estado_snapshot := 'EN RUTA';
            o_termina := 0;
        end if;

        -- Generar JSON de usuarios de aprobación a partir de la ruta
        declare
            v_orden_actual number;
        begin
            if v_estado_snapshot = 'APROBADO' then
                -- Flujo auto-aprobado: todos los usuarios nacen APROBADO con fecha
                select '[' || listagg(
                    '{"usuario":"' || q.codigousuario ||
                    '","orden":' || q.orden ||
                    ',"estado":"APROBADO"' ||
                    ',"fechaaprobacion":"' || to_char(v_fechainicio, 'YYYY-MM-DD HH24:MI:SS') || '"}',
                    ','
                ) within group (order by q.orden) || ']'
                  into v_usuariosaprobacion
                  from (
                      select rd.codigousuario, rd.orden
                        from data.t_admi_rutadetalle rd
                       where rd.id_ruta = p_idrutaaprobacion
                  ) q;
            else
                -- Flujo normal: sincronizar con el aprobador actual activo
                begin
                    select min(rd.orden)
                      into v_orden_actual
                      from data.t_admi_rutadetalle rd
                     where rd.id_ruta = p_idrutaaprobacion
                       and upper(trim(rd.codigousuario)) = upper(trim(v_usuarioactual));
                exception
                    when others then
                        v_orden_actual := null;
                end;

                select '[' || listagg(
                    '{"usuario":"' || q.codigousuario ||
                    '","orden":' || q.orden ||
                    ',"estado":"' || case
                                       when v_orden_actual is not null and q.orden < v_orden_actual then 'APROBADO'
                                       when v_orden_actual is not null and q.orden = v_orden_actual then 'EN PROCESO'
                                       when v_orden_actual is not null and q.orden > v_orden_actual then 'PENDIENTE'
                                       when q.fila = 1 then 'EN PROCESO'
                                       else 'PENDIENTE'
                                     end || '"' ||
                    ',"fechaaprobacion":' || case
                                               when v_orden_actual is not null and q.orden < v_orden_actual
                                               then '"' || to_char(v_fechainicio, 'YYYY-MM-DD HH24:MI:SS') || '"'
                                               else 'null'
                                             end || '}',
                    ','
                ) within group (order by q.orden) || ']'
                  into v_usuariosaprobacion
                  from (
                      select rd.codigousuario,
                             rd.orden,
                             row_number() over (order by rd.orden) as fila
                        from data.t_admi_rutadetalle rd
                       where rd.id_ruta = p_idrutaaprobacion
                         -- Excluir al usuario iniciador si es el primer aprobador en una ruta multi-aprobador
                         and not (
                             upper(trim(rd.codigousuario)) = upper(trim(v_usuarioinicia))
                             and rd.orden = (select min(rd_sub.orden) from data.t_admi_rutadetalle rd_sub where rd_sub.id_ruta = p_idrutaaprobacion)
                             and (select count(*) from data.t_admi_rutadetalle rd_cnt where rd_cnt.id_ruta = p_idrutaaprobacion) > 1
                         )
                  ) q;
            end if;
        exception
            when no_data_found then
                v_usuariosaprobacion := null;
            when others then
                v_usuariosaprobacion := null;
        end;

        v_log_msg := 'JSON usuariosaprobacion generado: ' || length(v_usuariosaprobacion) || ' bytes, flujo_estado: ' || v_flujo_estado || ', o_termina: ' || o_termina;
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

        -- Resolver comentario inicial (Parámetro directo > T_COMENTARIO > Fallback por defecto)
        if p_comentario is not null and length(trim(p_comentario)) > 0 then
            v_comentario_resuelto := trim(p_comentario);
        else
            begin
                select zcontenido
                  into v_comentario_resuelto
                  from (
                      select zcontenido
                        from data.t_comentario
                       where tipocomentario = 'MOTIVO_INICIO_FLUJO'
                         and codmodulo      = v_modulo_flujo
                         and codempresa     = v_cia_flujo
                         and claseobjeto    = v_entidad_clase
                         and idobjeto = v_entidad_id
                       order by id desc
                  )
                 where rownum = 1;
            exception
                when others then
                    v_comentario_resuelto := null;
            end;
        end if;

        v_comentario := fn_agregar_comentario(
            p_comentarios_actual => null,
            p_usuario            => nvl(p_usuarioinicia, 'SISTEMA'),
            p_comentario         => nvl(v_comentario_resuelto, 'Inicio de flujo de aprobación'),
            p_accion             => 'INICIO'
        );

        insert into data.T_CORP_APROBACIONES (
            compania, codmodulo, tipoorden, numeroorden, tipodocumento,
            numerodocumento, tipoproceso, numeroproceso, confidencial,
            descripcion1, descripcion2, descripcion3, descripcion4, descripcion5,
            estado, idrutaaprobacion, idflujoaprobacion,
            usuarioinicia, usuarioactual, usuarioalterno,
            fechainicio, fechalimite, prioridad,
            etiqueta1, etiqueta2, etiqueta3, etiqueta4, etiqueta5,
            comentarios, moneda, montototal, detallemontos, usuariosaprobacion,
            objeto0, objeto1, objeto2, objeto3, objeto4,
            objeto5, objeto6, objeto7, objeto8, objeto9
        ) VALUES (
            p_compania, p_codmodulo, p_tipoorden, p_numeroorden, p_tipodocumento,
            p_numerodocumento, p_tipoproceso, p_numeroproceso, v_confidencial,
            p_descripcion1, p_descripcion2, p_descripcion3, p_descripcion4, p_descripcion5,
            v_estado_snapshot, p_idrutaaprobacion, p_idflujoaprobacion,
            v_usuarioinicia, v_usuarioactual, p_usuarioalterno,
            v_fechainicio, p_fechalimite, v_prioridad,
            p_etiqueta1, p_etiqueta2, p_etiqueta3, p_etiqueta4, p_etiqueta5,
            v_comentario, p_moneda, p_montototal, p_detallemontos, v_usuariosaprobacion,
            p_objeto0, p_objeto1, p_objeto2, p_objeto3, p_objeto4,
            p_objeto5, p_objeto6, p_objeto7, p_objeto8, p_objeto9
        );

        v_log_msg := 'Termina: Aprobación registrada en T_CORP_APROBACIONES';
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

    EXCEPTION
        WHEN OTHERS THEN
            o_estato_exito := 0;
            o_respuesta := 'Error en sp_enviar_aprobacion: ' || SQLERRM;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, o_respuesta, v_log_obs, null);
    end sp_enviar_aprobacion;

    -- =========================================================================
    -- sp_enviar_aprobacion (Sobrecarga para retrocompatibilidad)
    -- =========================================================================
    procedure sp_enviar_aprobacion (
        p_compania          IN VARCHAR2,
        p_codmodulo         IN VARCHAR2,
        p_tipoorden         IN VARCHAR2 DEFAULT NULL,
        p_numeroorden       IN VARCHAR2 DEFAULT NULL,
        p_tipodocumento     IN VARCHAR2 DEFAULT NULL,
        p_numerodocumento   IN VARCHAR2 DEFAULT NULL,
        p_tipoproceso       IN VARCHAR2 DEFAULT NULL,
        p_numeroproceso     IN VARCHAR2 DEFAULT NULL,
        p_confidencial      IN VARCHAR2 DEFAULT 'N',
        p_descripcion1      IN VARCHAR2 DEFAULT NULL,
        p_descripcion2      IN VARCHAR2 DEFAULT NULL,
        p_descripcion3      IN VARCHAR2 DEFAULT NULL,
        p_descripcion4      IN VARCHAR2 DEFAULT NULL,
        p_descripcion5      IN VARCHAR2 DEFAULT NULL,
        p_idrutaaprobacion  IN NUMBER,
        p_idflujoaprobacion IN NUMBER,
        p_usuarioinicia     IN VARCHAR2 DEFAULT NULL,
        p_usuarioalterno    IN VARCHAR2 DEFAULT NULL,
        p_fechainicio       IN TIMESTAMP DEFAULT NULL,
        p_fechalimite       IN TIMESTAMP DEFAULT NULL,
        p_prioridad         IN VARCHAR2 DEFAULT 'MEDIA',
        p_etiqueta1         IN VARCHAR2 DEFAULT NULL,
        p_etiqueta2         IN VARCHAR2 DEFAULT NULL,
        p_etiqueta3         IN VARCHAR2 DEFAULT NULL,
        p_etiqueta4         IN VARCHAR2 DEFAULT NULL,
        p_etiqueta5         IN VARCHAR2 DEFAULT NULL,
        p_comentario        IN CLOB DEFAULT NULL,
        p_moneda            IN VARCHAR2 DEFAULT NULL,
        p_montototal        IN NUMBER DEFAULT NULL,
        p_detallemontos     IN CLOB DEFAULT NULL,
        p_objeto0           IN CLOB DEFAULT NULL,
        p_objeto1           IN CLOB DEFAULT NULL,
        p_objeto2           IN CLOB DEFAULT NULL,
        p_objeto3           IN CLOB DEFAULT NULL,
        p_objeto4           IN CLOB DEFAULT NULL,
        p_objeto5           IN CLOB DEFAULT NULL,
        p_objeto6           IN CLOB DEFAULT NULL,
        p_objeto7           IN CLOB DEFAULT NULL,
        p_objeto8           IN CLOB DEFAULT NULL,
        p_objeto9           IN CLOB DEFAULT NULL,
        o_estato_exito      OUT NUMBER,
        o_respuesta         OUT VARCHAR2
    ) as
        v_dummy_termina number;
    begin
        sp_enviar_aprobacion(
            p_compania          => p_compania,
            p_codmodulo         => p_codmodulo,
            p_tipoorden         => p_tipoorden,
            p_numeroorden       => p_numeroorden,
            p_tipodocumento     => p_tipodocumento,
            p_numerodocumento   => p_numerodocumento,
            p_tipoproceso       => p_tipoproceso,
            p_numeroproceso     => p_numeroproceso,
            p_confidencial      => p_confidencial,
            p_descripcion1      => p_descripcion1,
            p_descripcion2      => p_descripcion2,
            p_descripcion3      => p_descripcion3,
            p_descripcion4      => p_descripcion4,
            p_descripcion5      => p_descripcion5,
            p_idrutaaprobacion  => p_idrutaaprobacion,
            p_idflujoaprobacion => p_idflujoaprobacion,
            p_usuarioinicia     => p_usuarioinicia,
            p_usuarioalterno    => p_usuarioalterno,
            p_fechainicio       => p_fechainicio,
            p_fechalimite       => p_fechalimite,
            p_prioridad         => p_prioridad,
            p_etiqueta1         => p_etiqueta1,
            p_etiqueta2         => p_etiqueta2,
            p_etiqueta3         => p_etiqueta3,
            p_etiqueta4         => p_etiqueta4,
            p_etiqueta5         => p_etiqueta5,
            p_comentario        => p_comentario,
            p_moneda            => p_moneda,
            p_montototal        => p_montototal,
            p_detallemontos     => p_detallemontos,
            p_objeto0           => p_objeto0,
            p_objeto1           => p_objeto1,
            p_objeto2           => p_objeto2,
            p_objeto3           => p_objeto3,
            p_objeto4           => p_objeto4,
            p_objeto5           => p_objeto5,
            p_objeto6           => p_objeto6,
            p_objeto7           => p_objeto7,
            p_objeto8           => p_objeto8,
            p_objeto9           => p_objeto9,
            o_estato_exito      => o_estato_exito,
            o_respuesta         => o_respuesta,
            o_termina           => v_dummy_termina
        );
    end sp_enviar_aprobacion;

    -- =========================================================================
    -- sp_aprobar_mesa: Registra intención de aprobación (solo UPDATE, sin lógica de dominio)
    -- =========================================================================
    procedure sp_aprobar_mesa (
        p_compania      IN  VARCHAR2,
        p_usuario       IN  VARCHAR2,
        p_id_aprobacion IN  NUMBER,
        p_comentario    IN  VARCHAR2 DEFAULT NULL,
        o_respuesta     OUT VARCHAR2,
        o_estado_exito  OUT NUMBER
    ) as
        v_estado_actual      varchar2(50);
        v_comentarios_actual clob;
        v_nuevos_comentarios clob;
        v_usuarios_actual    varchar2(2000);
        v_nuevos_usuarios    varchar2(2000);
    begin
        v_log_app := 'PK_CORP_APROBACION.sp_aprobar_mesa';
        v_log_dsc := 'p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id_aprobacion: ' || p_id_aprobacion;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        -- Validar que el registro existe y está EN RUTA
        begin
            select estado, comentarios, usuariosaprobacion
              into v_estado_actual, v_comentarios_actual, v_usuarios_actual
              from data.t_corp_aprobaciones
             where id = p_id_aprobacion;
        exception
            when no_data_found then
                o_estado_exito := 0;
                o_respuesta := 'Registro de aprobación no encontrado: ' || p_id_aprobacion;
                return;
        end;

        if v_estado_actual <> 'EN RUTA' then
            o_estado_exito := 0;
            o_respuesta := 'El registro no se encuentra en estado EN RUTA (estado actual: ' || v_estado_actual || ')';
            return;
        end if;

        v_nuevos_comentarios := fn_agregar_comentario(
            p_comentarios_actual => v_comentarios_actual,
            p_usuario            => p_usuario,
            p_comentario         => nvl(p_comentario, 'Aprobado desde Mesa de Trabajo'),
            p_accion             => 'APROBAR'
        );

        v_nuevos_usuarios := fn_actualizar_usuarios_aprobacion(
            p_usuarios_json => v_usuarios_actual,
            p_usuario       => p_usuario,
            p_accion        => 'APROBAR'
        );

        -- Encolar: marcar como PENDIENTE_APROBAR, registrar comentarios y actualizar lista de usuarios
        update data.t_corp_aprobaciones
           set estado             = 'PENDIENTE_APROBAR',
               comentarios        = v_nuevos_comentarios,
               usuariosaprobacion = v_nuevos_usuarios
         where id = p_id_aprobacion;

        o_estado_exito := 1;
        o_respuesta := 'Solicitud de aprobación registrada exitosamente';

        v_log_msg := 'Termina: encolado como PENDIENTE_APROBAR por ' || p_usuario;
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            o_estado_exito := 0;
            o_respuesta := 'Error en sp_aprobar_mesa: ' || sqlerrm;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, o_respuesta, v_log_obs, null);
    end sp_aprobar_mesa;

    -- =========================================================================
    -- sp_rechazar_mesa: Registra intención de rechazo (solo UPDATE, sin lógica de dominio)
    -- =========================================================================
    procedure sp_rechazar_mesa (
        p_compania      IN  VARCHAR2,
        p_usuario       IN  VARCHAR2,
        p_id_aprobacion IN  NUMBER,
        p_comentario    IN  VARCHAR2 DEFAULT NULL,
        o_respuesta     OUT VARCHAR2,
        o_estado_exito  OUT NUMBER
    ) as
        v_estado_actual      varchar2(50);
        v_comentarios_actual clob;
        v_nuevos_comentarios clob;
        v_usuarios_actual    varchar2(2000);
        v_nuevos_usuarios    varchar2(2000);
    begin
        v_log_app := 'PK_CORP_APROBACION.sp_rechazar_mesa';
        v_log_dsc := 'p_compania: ' || p_compania || ', p_usuario: ' || p_usuario || ', p_id_aprobacion: ' || p_id_aprobacion;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        -- Validar que el registro existe y está EN RUTA
        begin
            select estado, comentarios, usuariosaprobacion
              into v_estado_actual, v_comentarios_actual, v_usuarios_actual
              from data.t_corp_aprobaciones
             where id = p_id_aprobacion;
        exception
            when no_data_found then
                o_estado_exito := 0;
                o_respuesta := 'Registro de aprobación no encontrado: ' || p_id_aprobacion;
                return;
        end;

        if v_estado_actual <> 'EN RUTA' then
            o_estado_exito := 0;
            o_respuesta := 'El registro no se encuentra en estado EN RUTA (estado actual: ' || v_estado_actual || ')';
            return;
        end if;

        v_nuevos_comentarios := fn_agregar_comentario(
            p_comentarios_actual => v_comentarios_actual,
            p_usuario            => p_usuario,
            p_comentario         => nvl(p_comentario, 'Rechazado desde Mesa de Trabajo'),
            p_accion             => 'RECHAZAR'
        );

        v_nuevos_usuarios := fn_actualizar_usuarios_aprobacion(
            p_usuarios_json => v_usuarios_actual,
            p_usuario       => p_usuario,
            p_accion        => 'RECHAZAR'
        );

        -- Encolar: marcar como PENDIENTE_RECHAZAR, registrar comentarios y actualizar lista de usuarios
        update data.t_corp_aprobaciones
           set estado             = 'PENDIENTE_RECHAZAR',
               comentarios        = v_nuevos_comentarios,
               usuariosaprobacion = v_nuevos_usuarios
         where id = p_id_aprobacion;

        o_estado_exito := 1;
        o_respuesta := 'Solicitud de rechazo registrada exitosamente';

        v_log_msg := 'Termina: encolado como PENDIENTE_RECHAZAR por ' || p_usuario;
        pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            o_estado_exito := 0;
            o_respuesta := 'Error en sp_rechazar_mesa: ' || sqlerrm;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, o_respuesta, v_log_obs, null);
    end sp_rechazar_mesa;

    -- =========================================================================
    -- sp_procesar_cola: Worker en segundo plano o procesamiento puntual.
    -- Procesa registros PENDIENTE_APROBAR y PENDIENTE_RECHAZAR.
    -- Si p_id es provisto, procesa únicamente ese registro puntual.
    -- Diseñado para ser invocado por DBMS_SCHEDULER o bajo demanda.
    -- =========================================================================
    procedure sp_procesar_cola (
        p_id in number default null
    ) as
        v_exito              number;
        v_termina            number;
        v_opcion             varchar2(20);
        v_estado_final       varchar2(50);
        v_resp_dominio       varchar2(4000);
        v_exito_dominio      number;
        v_dominio            varchar2(100);
        v_usr_siguiente      varchar2(50);
        v_comentarios_actual clob;
        v_comentario_usuario varchar2(4000);
        v_num_oc             number;
        v_tipo_oc            varchar2(50);
    begin
        v_log_app := 'PK_CORP_APROBACION.sp_procesar_cola';
        v_log_dsc := case when p_id is not null
                          then 'Procesamiento de cola puntual (ID: ' || p_id || ')'
                          else 'Inicio de procesamiento general de cola'
                     end;
        v_log_msg := 'Inicia';
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        for r in (
            select id, compania, codmodulo, etiqueta1, etiqueta2, etiqueta3, etiqueta4, etiqueta5,
                   tipoproceso, numeroproceso, numeroorden, tipodocumento, numerodocumento,
                   idrutaaprobacion, idflujoaprobacion, usuarioinicia, usuarioactual, usuarioalterno,
                   comentarios, estado
              from data.t_corp_aprobaciones
             where estado in ('PENDIENTE_APROBAR', 'PENDIENTE_RECHAZAR')
               and (p_id is null or id = p_id)
             order by id
        ) loop
            begin
                -- Determinar la acción
                if r.estado = 'PENDIENTE_APROBAR' then
                    v_opcion := 'APROBAR';
                else
                    v_opcion := 'RECHAZAR';
                end if;

                -- Extraer el último comentario registrado por el usuario
                v_comentario_usuario := fn_obtener_ultimo_comentario(
                    p_comentarios => r.comentarios,
                    p_fallback    => v_opcion || ' desde Mesa de Trabajo por ' || r.usuarioactual
                );

                v_log_msg := 'Procesando ID ' || r.id || ' (' || v_opcion || ') usuario: ' || r.usuarioactual;
                pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

                -- 1. Invocar el motor de flujos
                v_exito := 0;
                v_termina := 0;
                data.pk_corp_flujoaprobacion.sp_gestionflujo(
                    p_opcion     => v_opcion,
                    p_idflujo    => r.idflujoaprobacion,
                    p_usuario    => r.usuarioactual,
                    p_comentario => v_comentario_usuario,
                    p_exito      => v_exito,
                    p_termina    => v_termina
                );

                if nvl(v_exito, 0) = 0 then
                    -- Error en el motor de flujos
                    v_comentarios_actual := fn_agregar_comentario(
                        p_comentarios_actual => r.comentarios,
                        p_usuario            => 'SISTEMA',
                        p_comentario         => 'Error en flujo: ' || nvl(data.pk_corp_flujoaprobacion.g_mensaje, 'Sin detalle'),
                        p_accion             => 'ERROR_FLUJO'
                    );

                    update data.t_corp_aprobaciones
                       set estado      = 'ERROR_FLUJO',
                           comentarios = v_comentarios_actual
                     where id = r.id;
                    commit;

                    v_log_msg := 'ERROR_FLUJO en ID ' || r.id || ': ' || nvl(data.pk_corp_flujoaprobacion.g_mensaje, 'Sin mensaje');
                    pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
                    continue;
                end if;

                -- 2. Evaluar si la ruta terminó
                if nvl(v_termina, 0) = 0 then
                    -- Aún quedan aprobadores, devolver a EN RUTA y actualizar al siguiente aprobador
                    begin
                        select usuarioactual
                          into v_usr_siguiente
                          from data.vt_flujo_aprobacion
                         where idflujo = r.idflujoaprobacion
                           and detalle_estado = 'EN_PROCESO';
                    exception
                        when others then
                            v_usr_siguiente := null;
                    end;

                    v_comentarios_actual := fn_agregar_comentario(
                        p_comentarios_actual => r.comentarios,
                        p_usuario            => 'SISTEMA',
                        p_comentario         => 'Avanzó al siguiente aprobador',
                        p_accion             => 'SIGUIENTE_PASO'
                    );

                    update data.t_corp_aprobaciones
                       set estado        = 'EN RUTA',
                           usuarioactual = v_usr_siguiente,
                           comentarios   = v_comentarios_actual
                     where id = r.id;
                    commit;

                    v_log_msg := 'ID ' || r.id || ': flujo avanzó al siguiente aprobador (' || v_usr_siguiente || '), devuelto a EN RUTA';
                    pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);
                    continue;
                end if;

                -- 3. Fin de ruta (v_termina = 1): ejecutar SP de dominio
                v_dominio := upper(trim(r.etiqueta1));

                v_log_msg := 'ID ' || r.id || ': fin de ruta, ejecutando dominio (' || v_dominio || '/' || r.etiqueta2 || ')';
                pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

                v_exito_dominio := 0;
                v_resp_dominio := null;

                if r.estado = 'PENDIENTE_APROBAR' then
                    -- Despachar aprobación al paquete de dominio
                    if r.codmodulo = 'COMP' then
                        case v_dominio
                            when 'PRODUCTOS_ALTERNOS' then
                                data.pk_comp_productosalternos.sp_aprobar(
                                    p_compania     => r.compania,
                                    p_usuario      => r.usuarioactual,
                                    p_id           => to_number(r.numeroproceso),
                                    o_respuesta    => v_resp_dominio,
                                    o_estado_exito => v_exito_dominio
                                );
                            when 'PROVEEDORES' then
                                data.pk_corp_librodirecciones.sp_aprobar(
                                    p_compania      => r.compania,
                                    p_usuario       => r.usuarioactual,
                                    p_id_proveedor  => to_number(r.numeroproceso),
                                    o_respuesta     => v_resp_dominio,
                                    o_estato_exito  => v_exito_dominio
                                );
                            when 'NEGOCIACIONES' then
                                data.pk_comp_negociacion_v2.sp_aprobar(
                                    p_compania       => r.compania,
                                    p_usuario        => r.usuarioactual,
                                    p_id_negociacion => to_number(regexp_substr(r.numeroproceso, '^[0-9]+')),
                                    p_comentario     => v_comentario_usuario,
                                    o_respuesta      => v_resp_dominio,
                                    o_estato_exito   => v_exito_dominio
                                );
                            when 'RUTAS' then
                                data.pk_comp_gestion_rutas.sp_aprobar(
                                    p_compania     => r.compania,
                                    p_usuario      => r.usuarioactual,
                                    p_id_ruta_comp => to_number(r.numeroproceso),
                                    p_comentario   => v_comentario_usuario,
                                    o_respuesta    => v_resp_dominio,
                                    o_estato_exito => v_exito_dominio
                                );
                            when 'ORDENES_COMPRA' then
                                data.pk_comp_ordenescompra_v2.sp_generar_oc_erp(
                                    p_compania     => r.compania,
                                    p_numero       => to_number(regexp_substr(r.numeroproceso, '^[0-9]+')),
                                    p_usuario      => r.usuarioactual,
                                    p_numeroorden  => v_num_oc,
                                    p_tipoorden    => v_tipo_oc,
                                    o_respuesta    => v_resp_dominio,
                                    o_estato_exito => v_exito_dominio
                                );
                                if nvl(v_exito_dominio, 0) = 1 then
                                    begin
                                        data.pk_comp_ordenescompra_v2.sp_notificaruta(r.compania, v_num_oc, 1);
                                    exception
                                        when others then null;
                                    end;
                                end if;
                            else
                                v_resp_dominio := 'Dominio de aprobación no soportado: ' || v_dominio;
                                v_exito_dominio := 0;
                        end case;
                    else
                        v_resp_dominio := 'Módulo corporativo no soportado: ' || r.codmodulo;
                        v_exito_dominio := 0;
                    end if;
                    v_estado_final := case when nvl(v_exito_dominio, 0) = 1 then 'APROBADO' else 'ERROR_DOMINIO' end;

                else -- PENDIENTE_RECHAZAR
                    if r.codmodulo = 'COMP' then
                        -- Despachar rechazo al paquete de dominio
                        case v_dominio
                            when 'PRODUCTOS_ALTERNOS' then
                                data.pk_comp_productosalternos.sp_rechazar(
                                    p_compania     => r.compania,
                                    p_usuario      => r.usuarioactual,
                                    p_id           => to_number(r.numeroproceso),
                                    o_respuesta    => v_resp_dominio,
                                    o_estado_exito => v_exito_dominio
                                );
                            when 'PROVEEDORES' then
                                data.pk_corp_librodirecciones.sp_rechazar(
                                    p_compania      => r.compania,
                                    p_usuario       => r.usuarioactual,
                                    p_id_proveedor  => to_number(r.numeroproceso),
                                    o_respuesta     => v_resp_dominio,
                                    o_estato_exito  => v_exito_dominio
                                );
                            when 'NEGOCIACIONES' then
                                data.pk_comp_negociacion_v2.sp_rechazar(
                                    p_compania       => r.compania,
                                    p_usuario        => r.usuarioactual,
                                    p_id_negociacion => to_number(regexp_substr(r.numeroproceso, '^[0-9]+')),
                                    p_comentario     => v_comentario_usuario,
                                    o_respuesta      => v_resp_dominio,
                                    o_estato_exito   => v_exito_dominio
                                );
                            when 'RUTAS' then
                                data.pk_comp_gestion_rutas.sp_rechazar(
                                    p_compania     => r.compania,
                                    p_usuario      => r.usuarioactual,
                                    p_id_ruta_comp => to_number(r.numeroproceso),
                                    p_comentario   => v_comentario_usuario,
                                    o_respuesta    => v_resp_dominio,
                                    o_estato_exito => v_exito_dominio
                                );
                            when 'ORDENES_COMPRA' then
                                data.pk_comp_ordenescompra_v2.sp_cancelaroclinea(
                                    p_numero      => to_number(regexp_substr(r.numeroproceso, '^[0-9]+')),
                                    p_tipo        => 'ORDEN_COMPRA',
                                    p_compania    => r.compania,
                                    p_lineas      => null,
                                    p_numeroorden => v_num_oc,
                                    p_tipoorden   => v_tipo_oc,
                                    p_mensaje     => v_resp_dominio
                                );
                                if upper(nvl(v_resp_dominio, 'EXITO')) not like '%ERROR%' then
                                    v_exito_dominio := 1;
                                    begin
                                        data.pk_comp_ordenescompra_v2.sp_notificaruta(r.compania, to_number(regexp_substr(r.numeroproceso, '^[0-9]+')), -1);
                                    exception
                                        when others then null;
                                    end;
                                else
                                    v_exito_dominio := 0;
                                end if;
                            else
                                v_resp_dominio := 'Dominio de aprobación no soportado: ' || v_dominio;
                                v_exito_dominio := 0;
                        end case;
                    else
                        v_resp_dominio := 'Módulo corporativo no soportado: ' || r.codmodulo;
                        v_exito_dominio := 0;
                    end if;

                    v_estado_final := case when nvl(v_exito_dominio, 0) = 1 then 'RECHAZADO' else 'ERROR_DOMINIO' end;
                end if;

                -- 4. Registrar comentario de cierre y actualizar estado final
                v_comentarios_actual := fn_agregar_comentario(
                    p_comentarios_actual => r.comentarios,
                    p_usuario            => 'SISTEMA',
                    p_comentario         => 'Resultado: ' || nvl(v_resp_dominio, v_estado_final),
                    p_accion             => v_estado_final
                );

                update data.t_corp_aprobaciones
                   set estado      = v_estado_final,
                       comentarios = v_comentarios_actual
                 where id = r.id;
                commit;

                v_log_msg := 'ID ' || r.id || ' -> ' || v_estado_final || ': ' || nvl(v_resp_dominio, 'OK');
                pk_commons.sp_apex_log(v_log_app, 4, v_log_dsc, v_log_msg, v_log_obs, null);

            exception
                when others then
                    -- Error inesperado en este registro, no detiene el resto de la cola
                    rollback;
                    begin
                        v_comentarios_actual := fn_agregar_comentario(
                            p_comentarios_actual => r.comentarios,
                            p_usuario            => 'SISTEMA',
                            p_comentario         => 'Error inesperado: ' || sqlerrm,
                            p_accion             => 'ERROR_DOMINIO'
                        );

                        update data.t_corp_aprobaciones
                           set estado      = 'ERROR_DOMINIO',
                               comentarios = v_comentarios_actual
                         where id = r.id;
                        commit;
                    exception
                        when others then null;
                    end;

                    v_log_msg := 'Error inesperado procesando ID ' || r.id || ': ' || sqlerrm;
                    pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
            end;
        end loop;

        v_log_msg := 'Termina procesamiento de cola';
        pk_commons.sp_apex_log(v_log_app, 9, v_log_dsc, v_log_msg, v_log_obs, null);
    end sp_procesar_cola;

    -- =========================================================================
    -- sp_html_flujo_aprobacion: Genera el HTML del Stepper y Timeline para Modal
    -- =========================================================================
    procedure sp_html_flujo_aprobacion (
        p_id_aprobacion in number,
        o_html          out clob
    ) as
        v_rec           data.t_corp_aprobaciones%rowtype;
        v_usr_arr       json_array_t;
        v_usr_obj       json_object_t;
        v_com_arr       json_array_t;
        v_com_obj       json_object_t;
        v_total_pasos   number := 0;
    begin
        begin
            select * into v_rec from data.t_corp_aprobaciones where id = p_id_aprobacion;
        exception
            when no_data_found then
                o_html := '<div style="padding:24px;text-align:center;color:#64748b;font-size:13px;">No se encontró información del flujo de aprobación para el registro ' || p_id_aprobacion || '.</div>';
                return;
        end;

        dbms_lob.createtemporary(o_html, true);
        dbms_lob.append(o_html, '
        <style>
            .flujo-comentario-cuerpo p { margin: 0 0 6px 0; }
            .flujo-comentario-cuerpo p:last-child { margin-bottom: 0; }
            .flujo-comentario-cuerpo ul, .flujo-comentario-cuerpo ol { margin: 4px 0 6px 18px; padding: 0; }
        </style>
        <div class="flujo-modal-container" style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;padding:6px;color:#333;">');

        -- 1. Resumen Header
        dbms_lob.append(o_html, '
        <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;padding:12px 16px;margin-bottom:16px;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:8px;">
            <div>
                <div style="font-size:14.5px;font-weight:700;color:#0f172a;">' || apex_escape.html(v_rec.descripcion1) || '</div>
                <div style="font-size:12px;color:#64748b;margin-top:2px;">' || apex_escape.html(v_rec.descripcion2) || ' &bull; Iniciado por <b>' || apex_escape.html(v_rec.usuarioinicia) || '</b> (' || to_char(v_rec.fechainicio, 'YYYY-MM-DD HH24:MI') || ')</div>
            </div>
            <div>
                <span style="display:inline-block;padding:3px 10px;border-radius:12px;font-size:11px;font-weight:700;background:#e0f2fe;color:#0369a1;text-transform:uppercase;">' || apex_escape.html(nvl(v_rec.descripcion5, v_rec.estado)) || '</span>
            </div>
        </div>');

        -- 2. Stepper de Aprobadores (incluyendo paso inicial del Solicitante/Iniciador)
        if v_rec.usuariosaprobacion is not null or v_rec.usuarioinicia is not null then
            begin
                if v_rec.usuariosaprobacion is not null then
                    v_usr_arr := json_array_t.parse(v_rec.usuariosaprobacion);
                    v_total_pasos := v_usr_arr.get_size;
                end if;

                if v_total_pasos > 0 or v_rec.usuarioinicia is not null then
                    dbms_lob.append(o_html, '
                    <div style="margin-bottom:20px;">
                        <div style="font-size:12px;font-weight:700;color:#475569;text-transform:uppercase;letter-spacing:0.5px;margin-bottom:12px;display:flex;align-items:center;gap:6px;">
                            <span class="fa fa-sitemap" style="color:#0284c7;"></span> Ruta de Aprobación
                        </div>
                        <div style="display:flex;align-items:flex-start;position:relative;padding:10px 0;overflow-x:auto;">');

                    -- 2.1. Paso Inicial: Usuario Solicitante / Iniciador
                    if v_rec.usuarioinicia is not null then
                        dbms_lob.append(o_html, '
                        <div style="display:flex;flex-direction:column;align-items:center;min-width:110px;text-align:center;padding:0 4px;">
                            <div style="width:34px;height:34px;border-radius:50%;background:#16a34a;color:#fff;display:flex;align-items:center;justify-content:center;font-size:14px;margin-bottom:6px;">
                                <span class="fa fa-paper-plane"></span>
                            </div>
                            <div style="font-size:12px;font-weight:700;color:#0f172a;max-width:100px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" title="' || apex_escape.html(v_rec.usuarioinicia) || '">' || apex_escape.html(v_rec.usuarioinicia) || '</div>
                            <div style="margin-top:3px;"><span style="font-size:10px;font-weight:600;padding:1px 6px;border-radius:8px;background:#dcfce7;color:#15803d;">INICIADO</span></div>
                            ' || case when v_rec.fechainicio is not null then '<div style="font-size:10px;color:#94a3b8;margin-top:2px;">' || to_char(v_rec.fechainicio, 'MM-DD HH24:MI') || '</div>' end || '
                        </div>');

                        if v_total_pasos > 0 then
                            dbms_lob.append(o_html, '<div style="flex:1;height:3px;background:#16a34a;margin-top:16px;min-width:20px;"></div>');
                        end if;
                    end if;

                    -- 2.2. Pasos de la Ruta de Aprobadores
                    for i in 0 .. v_total_pasos - 1 loop
                        v_usr_obj := treat(v_usr_arr.get(i) as json_object_t);
                        declare
                            v_usr_nombre  varchar2(100) := v_usr_obj.get_string('usuario');
                            v_usr_orden   number := v_usr_obj.get_number('orden');
                            v_usr_estado  varchar2(50) := upper(nvl(v_usr_obj.get_string('estado'), 'PENDIENTE'));
                            v_usr_fecha   varchar2(50) := v_usr_obj.get_string('fechaaprobacion');

                            v_bg_color    varchar2(20) := '#94a3b8';
                            v_icon_class  varchar2(50) := 'fa fa-clock-o';
                            v_badge_bg    varchar2(20) := '#f1f5f9';
                            v_badge_color varchar2(20) := '#475569';
                            v_border_css  varchar2(50) := '';
                        begin
                            if v_usr_estado = 'APROBADO' then
                                v_bg_color := '#16a34a';
                                v_icon_class := 'fa fa-check';
                                v_badge_bg := '#dcfce7';
                                v_badge_color := '#15803d';
                            elsif v_usr_estado = 'EN PROCESO' then
                                v_bg_color := '#0284c7';
                                v_icon_class := 'fa fa-refresh fa-spin';
                                v_badge_bg := '#e0f2fe';
                                v_badge_color := '#0369a1';
                                v_border_css := 'box-shadow: 0 0 0 4px rgba(2,132,199,0.2);';
                            elsif v_usr_estado = 'RECHAZADO' then
                                v_bg_color := '#dc2626';
                                v_icon_class := 'fa fa-times';
                                v_badge_bg := '#fee2e2';
                                v_badge_color := '#b91c1c';
                            end if;

                            if i > 0 then
                                dbms_lob.append(o_html, '<div style="flex:1;height:3px;background:' || case when v_usr_estado in ('APROBADO','EN PROCESO') then '#0284c7' else '#cbd5e1' end || ';margin-top:16px;min-width:20px;"></div>');
                            end if;

                            dbms_lob.append(o_html, '
                            <div style="display:flex;flex-direction:column;align-items:center;min-width:110px;text-align:center;padding:0 4px;">
                                <div style="width:34px;height:34px;border-radius:50%;background:' || v_bg_color || ';color:#fff;display:flex;align-items:center;justify-content:center;font-size:14px;margin-bottom:6px;' || v_border_css || '">
                                    <span class="' || v_icon_class || '"></span>
                                </div>
                                <div style="font-size:12px;font-weight:700;color:#0f172a;max-width:100px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" title="' || apex_escape.html(v_usr_nombre) || '">' || apex_escape.html(v_usr_nombre) || '</div>
                                <div style="margin-top:3px;"><span style="font-size:10px;font-weight:600;padding:1px 6px;border-radius:8px;background:' || v_badge_bg || ';color:' || v_badge_color || ';">' || v_usr_estado || '</span></div>
                                ' || case when v_usr_fecha is not null then '<div style="font-size:10px;color:#94a3b8;margin-top:2px;">' || substr(v_usr_fecha, 6, 11) || '</div>' end || '
                            </div>');
                        end;
                    end loop;

                    dbms_lob.append(o_html, '</div></div>');
                end if;
            exception
                when others then
                    dbms_lob.append(o_html, '<div style="color:#ef4444;font-size:12px;">Error al procesar aprobadores: ' || sqlerrm || '</div>');
            end;
        end if;

        -- 3. Timeline de Comentarios / Bitácora
        dbms_lob.append(o_html, '
        <div>
            <div style="font-size:12px;font-weight:700;color:#475569;text-transform:uppercase;letter-spacing:0.5px;margin-bottom:12px;display:flex;align-items:center;gap:6px;">
                <span class="fa fa-comments" style="color:#0284c7;"></span> Bitácora y Comentarios
            </div>');

        if v_rec.comentarios is not null then
            begin
                v_com_arr := json_array_t.parse(v_rec.comentarios);
                if v_com_arr.get_size > 0 then
                    dbms_lob.append(o_html, '<div style="position:relative;padding-left:20px;border-left:2px solid #e2e8f0;margin-left:8px;">');

                    for j in 0 .. v_com_arr.get_size - 1 loop
                        v_com_obj := treat(v_com_arr.get(j) as json_object_t);
                        declare
                            v_com_usr     varchar2(100) := v_com_obj.get_string('usuario');
                            v_com_accion  varchar2(50)  := upper(nvl(v_com_obj.get_string('accion'), 'COMENTARIO'));
                            v_com_fecha   varchar2(50)  := v_com_obj.get_string('fecha');
                            v_com_texto   varchar2(4000):= v_com_obj.get_string('comentario');

                            v_dot_color   varchar2(20) := '#0284c7';
                            v_badge_bg    varchar2(20) := '#f1f5f9';
                            v_badge_color varchar2(20) := '#334155';
                        begin
                            if v_com_accion = 'INICIO' then
                                v_dot_color := '#0284c7';
                                v_badge_bg := '#e0f2fe';
                                v_badge_color := '#0369a1';
                            elsif v_com_accion = 'APROBAR' then
                                v_dot_color := '#16a34a';
                                v_badge_bg := '#dcfce7';
                                v_badge_color := '#15803d';
                            elsif v_com_accion = 'RECHAZAR' then
                                v_dot_color := '#dc2626';
                                v_badge_bg := '#fee2e2';
                                v_badge_color := '#b91c1c';
                            end if;

                            dbms_lob.append(o_html, '
                            <div style="position:relative;margin-bottom:14px;">
                                <div style="position:absolute;left:-26px;top:4px;width:12px;height:12px;border-radius:50%;background:' || v_dot_color || ';border:2px solid #fff;box-shadow:0 0 0 1px #cbd5e1;"></div>
                                <div style="background:#fff;border:1px solid #e2e8f0;border-radius:6px;padding:10px 12px;box-shadow:0 1px 2px rgba(0,0,0,0.03);">
                                    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;gap:8px;">
                                        <div style="font-size:12px;font-weight:700;color:#0f172a;">
                                            <span class="fa fa-user-circle" style="color:#64748b;margin-right:4px;"></span>' || apex_escape.html(v_com_usr) || '
                                            <span style="margin-left:6px;font-size:10px;font-weight:600;padding:1px 6px;border-radius:6px;background:' || v_badge_bg || ';color:' || v_badge_color || ';">' || v_com_accion || '</span>
                                        </div>
                                        <div style="font-size:11px;color:#94a3b8;">' || substr(v_com_fecha, 1, 19) || '</div>
                                    </div>
                                    <div class="flujo-comentario-cuerpo" style="font-size:12.5px;color:#334155;line-height:1.45;word-break:break-word;">' || v_com_texto || '</div>
                                </div>
                            </div>');
                        end;
                    end loop;

                    dbms_lob.append(o_html, '</div>');
                else
                    dbms_lob.append(o_html, '<div style="color:#94a3b8;font-size:12px;font-style:italic;">No hay comentarios registrados.</div>');
                end if;
            exception
                when others then
                    dbms_lob.append(o_html, '<div style="color:#ef4444;font-size:12px;">Error al procesar comentarios: ' || sqlerrm || '</div>');
            end;
        else
            dbms_lob.append(o_html, '<div style="color:#94a3b8;font-size:12px;font-style:italic;">No hay comentarios registrados.</div>');
        end if;

        dbms_lob.append(o_html, '</div></div>');
    end sp_html_flujo_aprobacion;

    -- =========================================================================
    -- sp_sincronizar_aprobacion: Sincroniza el estado de DATA.T_CORP_APROBACIONES
    --                            a partir del estado en DATA.VT_FLUJO_APROBACION.
    -- =========================================================================
    procedure sp_sincronizar_aprobacion (
        p_compania          in  varchar2 default null,
        p_usuario           in  varchar2,
        p_id_aprobacion     in  number default null,
        p_idflujoaprobacion in  number default null,
        p_accion            in  varchar2,
        p_comentario        in  varchar2 default null,
        o_termina           out number,
        o_respuesta         out varchar2,
        o_estato_exito      out number
    ) as
        v_accion             varchar2(20);
        v_flujo_estado       varchar2(50);
        v_usr_siguiente      varchar2(50);
        v_comentarios_actual clob;
        v_usuarios_json      varchar2(2000);
        v_estado_final       varchar2(50);
        v_idflujo            number;
        v_cont_encontrados   number := 0;
        v_comentario_resuelto varchar2(4000);
    begin
        v_log_app := 'PK_CORP_APROBACION';
        v_log_dsc := 'sp_sincronizar_aprobacion';
        v_log_msg := 'Inicia con usuario: ' || p_usuario || ', accion: ' || p_accion || ', id_aprob: ' || p_id_aprobacion || ', idflujo: ' || p_idflujoaprobacion;
        pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, v_log_msg, v_log_obs, null);

        o_termina      := 1;
        o_estato_exito := 0;
        o_respuesta    := null;
        v_accion       := upper(trim(p_accion));

        if p_id_aprobacion is null and p_idflujoaprobacion is null then
            o_respuesta := 'Debe especificar p_id_aprobacion o p_idflujoaprobacion.';
            o_estato_exito := 0;
            v_log_msg := 'Error de validacion: ' || o_respuesta;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
            return;
        end if;

        for r in (
            select id, idflujoaprobacion, comentarios, usuariosaprobacion, estado, usuarioactual
              from data.t_corp_aprobaciones
             where ((p_id_aprobacion is not null and id = p_id_aprobacion)
                or (p_id_aprobacion is null and p_idflujoaprobacion is not null and idflujoaprobacion = p_idflujoaprobacion))
               and estado in ('EN RUTA', 'PENDIENTE_APROBAR', 'PENDIENTE_RECHAZAR')
        ) loop
            v_cont_encontrados := v_cont_encontrados + 1;
            v_idflujo := nvl(r.idflujoaprobacion, p_idflujoaprobacion);

            -- Consultar estado real del flujo en VT_FLUJO_APROBACION
            begin
                select max(flujo_estado)
                  into v_flujo_estado
                  from data.vt_flujo_aprobacion
                 where idflujo = v_idflujo;
            exception
                when others then
                    v_flujo_estado := null;
            end;

            -- Autodescubrimiento de comentario si no se recibe explícitamente
            v_comentario_resuelto := trim(p_comentario);
            if v_comentario_resuelto is null or length(v_comentario_resuelto) = 0 then
                begin
                    select to_char(comentario)
                      into v_comentario_resuelto
                      from (
                          select comentario
                            from data.vt_flujo_aprobacion
                           where idflujo = v_idflujo
                             and upper(usuario) = upper(p_usuario)
                             and comentario is not null
                           order by iddetalle desc
                      )
                     where rownum = 1;
                exception
                    when others then
                        v_comentario_resuelto := null;
                end;
            end if;

            v_log_msg := 'Registro ID ' || r.id || ' flujo ' || v_idflujo || ' estado_flujo: ' || v_flujo_estado;
            pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);

            if v_flujo_estado = 'EN_PROCESO' then
                -- Paso intermedio: la ruta continúa
                begin
                    select usuarioactual
                      into v_usr_siguiente
                      from data.vt_flujo_aprobacion
                     where idflujo = v_idflujo
                       and detalle_estado = 'EN_PROCESO'
                       and rownum = 1;
                exception
                    when others then
                        v_usr_siguiente := null;
                end;

                v_comentarios_actual := fn_agregar_comentario(
                    p_comentarios_actual => r.comentarios,
                    p_usuario            => p_usuario,
                    p_comentario         => v_comentario_resuelto,
                    p_accion             => v_accion
                );

                v_usuarios_json := fn_actualizar_usuarios_aprobacion(
                    p_usuarios_json => r.usuariosaprobacion,
                    p_usuario       => p_usuario,
                    p_accion        => v_accion
                );

                update data.t_corp_aprobaciones
                   set estado             = 'EN RUTA',
                       usuarioactual      = v_usr_siguiente,
                       comentarios        = v_comentarios_actual,
                       usuariosaprobacion = v_usuarios_json
                 where id = r.id;

                o_termina      := 0;
                o_estato_exito := 1;
                o_respuesta    := 'Flujo en proceso. Avanzó al siguiente aprobador: ' || v_usr_siguiente;

                v_log_msg := 'ID ' || r.id || ' actualizado EN RUTA con siguiente aprobador: ' || v_usr_siguiente;
                pk_commons.sp_apex_log(v_log_app, 2, v_log_dsc, v_log_msg, v_log_obs, null);

            elsif v_flujo_estado in ('APROBADO', 'RECHAZADO') or v_accion = 'RECHAZAR' then
                -- Fin de ruta: aprobado o rechazado
                if v_flujo_estado = 'RECHAZADO' or v_accion = 'RECHAZAR' then
                    v_estado_final := 'RECHAZADO';
                else
                    v_estado_final := 'APROBADO';
                end if;

                v_comentarios_actual := fn_agregar_comentario(
                    p_comentarios_actual => r.comentarios,
                    p_usuario            => p_usuario,
                    p_comentario         => v_comentario_resuelto,
                    p_accion             => v_accion
                );

                v_usuarios_json := fn_actualizar_usuarios_aprobacion(
                    p_usuarios_json => r.usuariosaprobacion,
                    p_usuario       => p_usuario,
                    p_accion        => v_accion
                );

                update data.t_corp_aprobaciones
                   set estado             = v_estado_final,
                       comentarios        = v_comentarios_actual,
                       usuariosaprobacion = v_usuarios_json
                 where id = r.id;

                o_termina      := 1;
                o_estato_exito := 1;
                o_respuesta    := 'Flujo finalizado con estado ' || v_estado_final;

                v_log_msg := 'ID ' || r.id || ' finalizado con estado ' || v_estado_final;
                pk_commons.sp_apex_log(v_log_app, 3, v_log_dsc, v_log_msg, v_log_obs, null);

            else
                -- Estado no reconocido o nulo en VT_FLUJO_APROBACION
                v_comentarios_actual := fn_agregar_comentario(
                    p_comentarios_actual => r.comentarios,
                    p_usuario            => 'SISTEMA',
                    p_comentario         => 'Error al determinar estado de flujo: ' || nvl(v_flujo_estado, 'NULL'),
                    p_accion             => 'ERROR_FLUJO'
                );

                update data.t_corp_aprobaciones
                   set estado      = 'ERROR_FLUJO',
                       comentarios = v_comentarios_actual
                 where id = r.id;

                o_termina      := 1;
                o_estato_exito := 0;
                o_respuesta    := 'No se pudo determinar el estado del flujo de aprobacion.';

                v_log_msg := 'ERROR_FLUJO en ID ' || r.id || ' flujo ' || v_idflujo;
                pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
            end if;
        end loop;

        -- Idempotencia: si no se encontró registro EN RUTA, retornar éxito silencioso
        if v_cont_encontrados = 0 then
            o_termina      := 1;
            o_estato_exito := 1;
            o_respuesta    := 'Registro no encontrado en estado EN RUTA (posiblemente ya procesado).';
            v_log_msg      := o_respuesta;
            pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, v_log_msg, v_log_obs, null);
        end if;

        v_log_msg := 'Termina con o_termina: ' || o_termina || ', o_estato_exito: ' || o_estato_exito;
        pk_commons.sp_apex_log(v_log_app, 4, v_log_dsc, v_log_msg, v_log_obs, null);
    exception
        when others then
            o_termina      := 1;
            o_estato_exito := 0;
            o_respuesta    := 'Error inesperado en sp_sincronizar_aprobacion: ' || sqlerrm;
            v_log_msg      := o_respuesta;
            pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, v_log_msg, v_log_obs, null);
    end sp_sincronizar_aprobacion;

    -------------------------------------------------------------------------
    -- FUNCIONES DE RENDERIZADO UI DE TARJETAS HTML CORPORATIVAS
    -------------------------------------------------------------------------

    function f_base_css return varchar2 is
    begin
        return
          '*{box-sizing:border-box;}'||
          'body{font-family:Arial,sans-serif;font-size:13px;color:#333;margin:0;padding:16px;background:#f4f6f9;}'||
          '.card{background:#fff;border:1px solid #e0e0e0;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,.08);max-width:960px;margin:auto;overflow:hidden;}'||
          '.card-header{background:#008744;color:#fff;padding:16px 20px;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px;}'||
          '.card-header h2{margin:0;font-size:16px;font-weight:bold;display:flex;align-items:center;gap:8px;letter-spacing:.3px;}'||
          '.card-meta{font-size:11px;color:rgba(255,255,255,.85);margin-top:4px;}'||
          '.header-badges{display:flex;gap:8px;align-items:center;flex-wrap:wrap;}'||
          '.card-body{padding:20px;}'||

          /* Tabs Navigation */
          '.tabs-nav{display:flex;background:#f8f9fa;border-bottom:1px solid #e0e0e0;margin:0;padding:0;list-style:none;flex-wrap:wrap;}'||
          '.tab-btn{display:flex;flex-direction:row;align-items:center;justify-content:center;gap:5px;padding:10px 14px;font-size:11px;font-weight:bold;color:#666;cursor:pointer;transition:all .2s;text-transform:uppercase;letter-spacing:.5px;flex:1 1 auto;text-align:center;border-bottom:3px solid transparent;background:transparent;}'||
          '.tab-btn i{font-size:12px;color:#94a3b8;margin:0;}'||
          '.tab-btn:hover{color:#008744;background:rgba(0,135,68,.04);}'||
          '.tab-btn:hover i{color:#64748b;}'||
          '.tab-btn.active{color:#008744;border-bottom:3px solid #008744;background:transparent;}'||
          '.tab-btn.active i{color:#64748b;}'||
          '.tab-content{display:none;padding:20px;animation:fadeEffect .3s;}'||
          '.tab-content.active{display:block;}'||
          '@keyframes fadeEffect{from{opacity:0;}to{opacity:1;}}'||

          /* Secciones y Tablas */
          '.section{margin-bottom:18px;padding:4px 0;}'||
          '.section h3{margin:0 0 12px;font-size:12px;font-weight:bold;text-transform:uppercase;color:#008744;letter-spacing:.8px;padding-bottom:6px;border-bottom:1px solid #e0e0e0;display:flex;align-items:center;}'||
          '.section h3 i{margin-right:8px;font-size:14px;color:#008744;}'||
          'table{width:100%;border-collapse:collapse;}'||
          '.lbl{width:35%;font-weight:bold;padding:8px 10px 8px 0;color:#555;vertical-align:top;border-bottom:1px solid #f0f0f0;font-size:12px;}'||
          '.val{padding:8px 0;vertical-align:top;border-bottom:1px solid #f0f0f0;color:#222;font-size:12px;}'||
          'tr:last-child .lbl, tr:last-child .val{border-bottom:none;}'||
          '.grid-2{display:grid;grid-template-columns:1fr 1fr;gap:20px;}'||

          /* Tablas Internas */
          '.inner{width:100%;border-collapse:collapse;font-size:12px;margin-top:4px;border:1px solid #e0e0e0;border-radius:4px;overflow:hidden;}'||
          '.inner th{background:#e8f5e9;color:#008744;padding:8px 10px;text-align:left;font-weight:bold;font-size:11px;text-transform:uppercase;border-bottom:1px solid #c8e6c9;}'||
          '.inner td{padding:7px 10px;border-bottom:1px solid #f0f0f0;}'||
          '.inner tr:nth-child(even){background:#fafafa;}'||

          /* Bitacora */
          '.bitacora{display:flex;flex-direction:column;gap:8px;}'||
          '.bitem{background:#fafafa;border-left:3px solid #008744;padding:10px 14px;border-radius:0 6px 6px 0;border-top:1px solid #f0f0f0;border-right:1px solid #f0f0f0;border-bottom:1px solid #f0f0f0;}'||
          '.bmeta{display:flex;gap:16px;margin-bottom:4px;font-size:11px;color:#888;}'||
          '.busr{font-weight:bold;color:#008744;}'||
          '.btxt{font-size:13px;color:#333;}'||

          /* Alertas y Chips */
          '.alert-box{border-radius:6px;padding:12px 16px;font-size:12px;margin:16px 0;display:flex;align-items:center;gap:10px;}'||
          '.alert-danger{background:#ffebee;border:1px solid #ffcdd2;color:#b71c1c;}'||
          '.alert-info{background:#e0f2f1;border:1px solid #b2dfdb;color:#004d40;}'||
          '.alert-success{background:#e8f5e9;border:1px solid #c8e6c9;color:#2e7d32;}'||
          '.alert-warning{background:#fff8e1;border:1px solid #ffe082;color:#b78103;}'||
          '.alert-ocas{background:#fff3e0;border:1px solid #ffe0b2;border-radius:6px;padding:10px 14px;font-size:12px;color:#e65100;margin-top:6px;}'||
          '.tipo-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:10px;}'||
          '.tipo-chip{background:#e8f5e9;border:1px solid #c8e6c9;border-radius:6px;padding:10px 14px;font-size:12px;display:flex;align-items:center;gap:8px;}'||
          '.tipo-chip .chip-label{font-weight:bold;color:#008744;font-size:11px;text-transform:uppercase;}'||
          '.tipo-chip .chip-value{color:#333;}'||
          '.empty-msg{color:#999;font-style:italic;font-size:12px;padding:10px 0;}'||

          /* Footer */
          '.footer{font-size:11px;color:#888;padding:12px 20px;border-top:1px solid #eee;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:8px;}'||
          '.footer-sys{color:#aaa;}'||
          '@media(max-width:768px){'||
            '.card-header{flex-direction:column;align-items:flex-start;}'||
            '.grid-2{grid-template-columns:1fr;gap:10px;}'||
            '.lbl{width:100%;display:block;padding-bottom:2px;}'||
            '.val{display:block;padding-bottom:8px;}'||
            'tr{display:block;margin-bottom:6px;}'||
            '.tipo-grid{grid-template-columns:1fr;}'||
          '}';
    end f_base_css;

    function f_tabs_script return varchar2 is
    begin
        return
        '<script type="text/javascript">'||
          '(function() {'||
            'window.openTab = function(evt, tabId) {'||
              'var i, tabcontent, tablinks;'||
              'tabcontent = document.getElementsByClassName("tab-content");'||
              'for (i = 0; i < tabcontent.length; i++) { tabcontent[i].style.display = "none"; tabcontent[i].className = tabcontent[i].className.replace(" active", ""); }'||
              'tablinks = document.getElementsByClassName("tab-btn");'||
              'for (i = 0; i < tablinks.length; i++) { tablinks[i].className = tablinks[i].className.replace(" active", ""); }'||
              'var targetTab = document.getElementById(tabId);'||
              'if(targetTab) { targetTab.style.display = "block"; targetTab.className += " active"; }'||
              'if(evt && evt.currentTarget) { evt.currentTarget.className += " active"; }'||
            '}'||
          '})();'||
        '</script>';
    end f_tabs_script;

    function f_badge_estado (
        p_estado     in varchar2,
        p_solo_icono in boolean default true
    ) return varchar2 is
        v_color varchar2(20);
        v_icon  varchar2(30);
    begin
        case p_estado
            when 'ACTIVO'    then v_color := '#008744'; v_icon := 'fa-check-circle';
            when 'EN RUTA'   then v_color := '#0070ba'; v_icon := 'fa-truck';
            when 'ENRUTA'    then v_color := '#0070ba'; v_icon := 'fa-truck';
            when 'APROBADO'  then v_color := '#008744'; v_icon := 'fa-check';
            when 'RECHAZADO' then v_color := '#d32f2f'; v_icon := 'fa-times-circle';
            when 'PENDIENTE' then v_color := '#f57c00'; v_icon := 'fa-clock-o';
            when 'INGRESADO' then v_color := '#7b1fa2'; v_icon := 'fa-pencil';
            when 'INACTIVO'  then v_color := '#616161'; v_icon := 'fa-ban';
            else                  v_color := '#555555'; v_icon := 'fa-info-circle';
        end case;
        if p_solo_icono then
            return '<span title="'||nvl(p_estado, chr(8212))||'" style="background:#ffffff;color:'||v_color||';width:26px;height:26px;border-radius:50%;'||
                   'font-size:12px;font-weight:bold;box-shadow:0 1px 3px rgba(0,0,0,.12);display:inline-flex;align-items:center;justify-content:center;cursor:help;">'||
                   '<i class="fa '||v_icon||'"></i></span>';
        else
            return '<span style="background:#ffffff;color:'||v_color||';padding:4px 14px;border-radius:20px;'||
                   'font-size:11px;font-weight:bold;letter-spacing:.4px;box-shadow:0 1px 3px rgba(0,0,0,.12);display:inline-flex;align-items:center;gap:6px;">'||
                   '<i class="fa '||v_icon||'"></i> '||nvl(p_estado, chr(8212))||'</span>';
        end if;
    end f_badge_estado;

    function f_badge_pill (
        p_label in varchar2,
        p_icono in varchar2 default null,
        p_color in varchar2 default null
    ) return varchar2 is
        v_label_norm varchar2(100);
        v_color      varchar2(30);
        v_icon       varchar2(50);
    begin
        if p_label is null then
            return null;
        end if;

        v_label_norm := translate(upper(trim(p_label)), 'ÁÉÍÓÚ', 'AEIOU');

        case
            when v_label_norm in ('ACTUALIZACION', 'MODIFICACION', 'EDICION') then
                v_color := '#e65100';
                v_icon  := 'fa-pencil';
            when v_label_norm in ('INACTIVACION', 'ELIMINACION', 'DESACTIVACION', 'ANULACION') then
                v_color := '#d32f2f';
                v_icon  := 'fa-ban';
            when v_label_norm in ('REACTIVACION', 'ACTIVACION', 'REAPERTURA') then
                v_color := '#00897b';
                v_icon  := 'fa-refresh';
            when v_label_norm in ('CREACION', 'ALTA', 'NUEVO') then
                v_color := '#008744';
                v_icon  := 'fa-plus-circle';
            else
                v_color := '#555555';
                v_icon  := 'fa-tag';
        end case;

        v_color := nvl(p_color, v_color);
        v_icon  := nvl(p_icono, v_icon);

        return '<span style="background:#ffffff;color:'||v_color||';padding:4px 14px;border-radius:20px;'||
               'font-size:11px;font-weight:bold;letter-spacing:.4px;box-shadow:0 1px 3px rgba(0,0,0,.12);display:inline-flex;align-items:center;gap:6px;">'||
               '<i class="fa '||v_icon||'"></i> '||p_label||'</span>';
    end f_badge_pill;

    function f_header_html (
        p_titulo      in varchar2,
        p_icono       in varchar2 default 'fa-file-text-o',
        p_meta        in varchar2 default null,
        p_badges_html in varchar2 default null
    ) return varchar2 is
        v_res varchar2(4000);
    begin
        v_res :=
        '<div class="card-header">'||
          '<div>'||
            '<h2><i class="fa '||nvl(p_icono, 'fa-file-text-o')||'"></i> '||p_titulo||'</h2>';
        if p_meta is not null then
            v_res := v_res || '<div class="card-meta">'||p_meta||'</div>';
        end if;
        v_res := v_res || '</div>';
        if p_badges_html is not null then
            v_res := v_res || '<div class="header-badges">'||p_badges_html||'</div>';
        end if;
        v_res := v_res || '</div>';
        return v_res;
    end f_header_html;

    function f_footer_html (
        p_usercrea in varchar2 default null,
        p_fechcrea in date     default null,
        p_usermodi in varchar2 default null,
        p_fechmodi in date     default null
    ) return varchar2 is
        v_res varchar2(4000);
    begin
        v_res :=
        '<div class="footer">'||
          '<span class="footer-sys">Generado automáticamente por el Sistema de Compras</span>'||
          '<span>'||
            'Generado: '||to_char(sysdate, 'DD/MM/YYYY HH24:MI');
        if p_usercrea is not null then
            v_res := v_res || ' &nbsp;&middot;&nbsp; Creado por: '||p_usercrea;
            if p_fechcrea is not null then
                v_res := v_res || ' ('||to_char(p_fechcrea, 'DD/MM/YYYY')||')';
            end if;
        end if;
        if p_usermodi is not null then
            v_res := v_res || ' &nbsp;&middot;&nbsp; Modificado: '||p_usermodi;
            if p_fechmodi is not null then
                v_res := v_res || ' ('||to_char(p_fechmodi, 'DD/MM/YYYY HH24:MI')||')';
            end if;
        end if;
        v_res := v_res || '</span></div>';
        return v_res;
    end f_footer_html;

    function f_card_inicio (
        p_titulo            in varchar2,
        p_icono             in varchar2 default 'fa-file-text-o',
        p_meta              in varchar2 default null,
        p_badges_html       in varchar2 default null,
        p_incluye_tabscript in boolean  default true
    ) return clob is
        v_res clob;
    begin
        v_res :=
        '<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">'||
        '<meta name="viewport" content="width=device-width, initial-scale=1.0">'||
        '<style>'|| f_base_css ||'</style>';
        if p_incluye_tabscript then
            v_res := v_res || f_tabs_script;
        end if;
        v_res := v_res || '</head><body><div class="card">'||
                 f_header_html(p_titulo, p_icono, p_meta, p_badges_html);
        return v_res;
    end f_card_inicio;

    function f_card_fin (
        p_usercrea in varchar2 default null,
        p_fechcrea in date     default null,
        p_usermodi in varchar2 default null,
        p_fechmodi in date     default null
    ) return varchar2 is
    begin
        return f_footer_html(p_usercrea, p_fechcrea, p_usermodi, p_fechmodi) || '</div></body></html>';
    end f_card_fin;

    function f_row (
        p_label in varchar2,
        p_valor in varchar2
    ) return varchar2 is
    begin
        if p_valor is not null then
            return '<tr><td class="lbl">'|| htf.escape_sc(p_label) ||'</td><td class="val">'|| htf.escape_sc(p_valor) ||'</td></tr>';
        end if;
        return null;
    end f_row;

    function f_row_html (
        p_label      in varchar2,
        p_html_valor in varchar2
    ) return varchar2 is
    begin
        if p_html_valor is not null then
            return '<tr><td class="lbl">'|| htf.escape_sc(p_label) ||'</td><td class="val">'|| p_html_valor ||'</td></tr>';
        end if;
        return null;
    end f_row_html;

    function f_tab_btn (
        p_id_tab      in varchar2,
        p_label       in varchar2,
        p_icono       in varchar2 default 'fa-folder-o',
        p_active      in boolean  default false,
        p_badge_count in number   default null,
        p_badge_color in varchar2 default '#008744',
        p_icono_pos   in varchar2 default 'AFTER'
    ) return varchar2 is
        v_res varchar2(1000);
    begin
        v_res := '<div class="tab-btn' || case when p_active then ' active' else '' end || '" onclick="openTab(event, ''' || p_id_tab || ''')">';
        if upper(trim(nvl(p_icono_pos, 'AFTER'))) = 'AFTER' then
            v_res := v_res || '<span style="display:inline-flex;align-items:center;gap:5px;">' || p_label || '<i class="fa ' || nvl(p_icono, 'fa-folder-o') || '" style="font-size:12px;margin:0;"></i></span>';
        else
            v_res := v_res || '<i class="fa ' || nvl(p_icono, 'fa-folder-o') || '"></i>' || p_label;
        end if;
        if p_badge_count is not null and p_badge_count > 0 then
            v_res := v_res || ' <span style="background:' || nvl(p_badge_color, '#008744') || ';color:#fff;padding:1px 6px;border-radius:10px;font-size:9.5px;margin-left:4px;">' || p_badge_count || '</span>';
        end if;
        v_res := v_res || '</div>';
        return v_res;
    end f_tab_btn;

    function f_alert (
        p_mensaje in varchar2,
        p_tipo    in varchar2 default 'info',
        p_icono   in varchar2 default null
    ) return varchar2 is
        v_class varchar2(30);
        v_ico   varchar2(30);
    begin
        case lower(trim(p_tipo))
            when 'danger'  then v_class := 'alert-danger';  v_ico := nvl(p_icono, 'fa-exclamation-circle');
            when 'warning' then v_class := 'alert-warning'; v_ico := nvl(p_icono, 'fa-warning');
            when 'success' then v_class := 'alert-success'; v_ico := nvl(p_icono, 'fa-check-circle');
            else                v_class := 'alert-info';    v_ico := nvl(p_icono, 'fa-info-circle');
        end case;
        return '<div class="alert-box ' || v_class || '"><i class="fa ' || v_ico || '"></i> ' || p_mensaje || '</div>';
    end f_alert;

    function f_error_html (
        p_mensaje in varchar2
    ) return clob is
    begin
        return '<!DOCTYPE html><html><body style="font-family:Arial,sans-serif;padding:20px;background:#f4f6f9;">'||
               '<div class="card" style="max-width:600px;margin:auto;background:#fff;border:1px solid #ffcdd2;border-radius:8px;padding:20px;box-shadow:0 2px 6px rgba(0,0,0,.08);">'||
               '<p style="color:#d32f2f;font-size:14px;margin:0;display:flex;align-items:center;gap:8px;">'||
               '<i class="fa fa-exclamation-triangle" style="font-size:18px;"></i> '|| htf.escape_sc(p_mensaje) ||'</p>'||
               '</div></body></html>';
    end f_error_html;

    function f_chip (
        p_label in varchar2,
        p_valor in varchar2
    ) return varchar2 is
    begin
        if p_valor is not null then
            return '<div class="tipo-chip"><span class="chip-label">' || htf.escape_sc(p_label) || '</span><span class="chip-value">' || htf.escape_sc(p_valor) || '</span></div>';
        end if;
        return null;
    end f_chip;

end pk_corp_aprobacion;
/

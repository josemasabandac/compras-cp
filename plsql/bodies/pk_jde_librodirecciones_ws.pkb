
  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "PK_JDE_LIBRODIRECCIONES_WS" as
    v_exito varchar(7):=';Exito|';
    v_error varchar(7):=';Error|';



    procedure sp_gestionar_proveedor (p_sistema varchar2, p_metodo_ws varchar2, p_opcion number, p_identificador number, p_resultado out varchar2);

    function f_procesar_response (p_tramaclob in clob, p_metodo_ws in varchar2) return varchar2;
    function f_get_json_param(p_tramajson in clob, p_etiqueta varchar2) return clob ;
    function f_get_xml_param(p_tramaclob in clob,p_xpath varchar2,p_etiqueta varchar2, p_tipo varchar2 default 'WSJDE') return varchar2 ;
    function f_get_xml_tag(p_id number,p_campo varchar2,p_parametroxml varchar2,p_accion char default '1') return varchar2;
    function f_set_tabs(p_numero number,salto number default 0) return varchar2 ;

     procedure sp_jde_creacionproveedor (p_id number, p_mensaje out varchar2)
     as
     begin
        sp_jde_gestionproveedorws (p_id, 1,p_mensaje );
     end sp_jde_creacionproveedor ;


/*
    **proposito: llamar al procedimiento para la ejecucion del servicio web de supliers de jde
    **parametros:
    **  P_ID:   identificador de la tabla T_JDE_F0401Z
    */
    procedure sp_jde_gestionproveedorws (p_id number, p_opcion number , p_mensaje out varchar2)AS
        v_aban8 number;
        v_sql varchar2(900);
        v_sqlres varchar2(900);
        v_codigojde number;
        v_identificacion varchar(20);
        v_estadoetapa varchar2(20);
        v_contador number;
        v_mensaje clob;
        v_actionws clob;
    begin
        delete from t_tmp_b;
        select count(1) into v_contador from t_jde_f0401z where id = p_id;
        if nvl(v_contador, 0) = 0 then
            p_mensaje := 'No existen datos en la tabla t_jde_f0401z para el Identificador: ' || p_id;
            return;
        elsif v_contador > 1 then
            p_mensaje := ';ERROR|Existen múltiples registros en staging (t_jde_f0401z) para el ID ' || p_id || '. Contacte al Administrador.';
            return;
        end if;

        select  codigojde,   identificacion
        into    v_codigojde, v_identificacion
        from    t_jde_f0401z
        where   id = p_id;
        v_contador  :=0;
        v_aban8:=v_codigojde;
        if (trim(v_aban8) is null) then
            v_sql:='select aban8 from f0101@jdedtadl  where   /*ABAT1in (''PL'',''PE'') and*/  trim(abtax)='''||v_identificacion||''' and rownum = 1';
            begin
                execute immediate v_sql into v_aban8;
            exception when others then
                v_aban8:=null;
            end ;
        end if;
        if (p_opcion=1)then
            select count(1) into v_contador  from f0101@jdedtadl where  aban8= v_aban8;
            if (nvl(v_contador,0)>0)then
                p_mensaje:=';ERROR|Registro existente en Libro de Direcciones';
                if (v_codigojde is  null) then
                    v_sql := 'update T_JDE_F0401Z SET CODIGOJDE='||v_aban8||'   WHERE id = '||p_id;
                    execute immediate v_sql ;
                end if;
                return;
            end if;
            v_contador  :=0;
            select count(1) into v_contador  from f0401@jdedtadl where  a6an8= v_aban8;
            if (nvl(v_contador,0)>0)then
                p_mensaje:=';ERROR|Registro existente en Maestro de Proveedores';
                return;
            end if;
        end if;
        v_contador  :=0;
        begin
            v_actionws:=
            case p_opcion
                when 1 then 'processSupplier'
                when 2 then 'processSupplierEdit'
                when 3 then 'processSupplierBorra'
            end;
            sp_gestionar_proveedor('APEX', v_actionws,p_opcion, p_id ,v_mensaje );

            v_contador:= instr(v_mensaje,v_exito);
            if (v_contador>0)then
                begin
                    select to_char(campo3) into v_aban8 from table(pk_commons.f_split2tablev2(v_mensaje,'|',';')) where to_char(campo2)='entityId' and rownum = 1;
                exception when others then
                    v_aban8:='';
                end;
                 begin
                    select campo3 into v_mensaje from table(pk_commons.f_split2tablev2(v_mensaje,'|',';')) where to_char(campo1)='Exito' and rownum = 1;
                    v_mensaje:= v_exito||
                        case p_opcion
                            when 1 then 'Se ha generado correctamente la dirección:'||v_mensaje
                            when 2 then 'Se ha cambiado correctamente la dirección:'||v_mensaje
                            when 3 then 'Se ha eliminado correctamente la dirección:'||v_mensaje
                        end;
                exception when others then
                    --DBMS_OUTPUT.PUT_LINE('sqlerrm:'||sqlerrm);
                   null;
                end;
                if (v_aban8 is not null) then
                    v_sql := 'update T_JDE_F0401Z SET CODIGOJDE='||v_aban8||',estadoetapa =''COMPLETADO''  WHERE id = '||p_id; execute immediate v_sql ;
                end if;
            else
                if(trim(v_mensaje) is not null) then
                    begin
                        select listagg(upper(campo3), ' | ') within group (order by id) into v_mensaje
                        from table(pk_commons.f_split2tablev2(v_mensaje,'|',';'))
                        where to_char(campo1)='Error';
                    exception when others then
                        null;
                    end;
                end if;
                v_mensaje:=v_error||v_mensaje;
            end if;
            p_mensaje:=v_mensaje;
            return;
        -- exception when others then
        --     --p_mensaje:=v_error||'Ha ocurrido un error en la llamada al webservices de jde: [UNIT:'|| $$plsql_unit ||'],  [at line:' || $$plsql_line || '] - '||sqlerrm;
        --     raise_application_error(-20002, (dbms_utility.format_error_stack));
        end;
    end sp_jde_gestionproveedorws;

    procedure sp_gestionar_proveedor (p_sistema varchar2, p_metodo_ws varchar2, p_opcion number, p_identificador number, p_resultado out varchar2)as
        v_aban8 number;
        v_queryfield varchar2(100);
        v_campoproceso varchar2(25);
        v_csim varchar2(1) := chr(39);
        v_dblink varchar2(30);
        v_exist number;
        v_header2v varchar2(50);
        v_header3v varchar2(100);
        v_headers1 varchar2(500);
        v_headers2 varchar2(500);
        v_headers3 varchar2(500);
        v_message clob;
        v_noresponse clob;
        v_xmlparameter varchar2(50);
        v_pass varchar2(30);
        v_tramaclob clob;
        v_separatorvalues varchar2(1) := ',';
        v_sql varchar2(2000);
        v_sqlres clob;
        v_readingtable varchar2(30);
        v_typews varchar2(15);
        v_sendingstring clob;
        v_url varchar2(1000);
        v_user varchar2(30);
        v_valida varchar2(3999);
        v_eserror number;
        v_esexito number;
        v_contador number;
        v_nombrecomercial  varchar2(40);
    begin
        if (p_metodo_ws='processSupplierBorra' )then
            select count(1) into v_contador from f0101@jdedtadl  where aban8= p_identificador;
            if (v_contador=0)then
                return;
            end if;
        end if;
        /*OBTENER DATOS PRINCIPALES QUE DEBEN SER FIJOS PARA LEER LOS DATOS CORRESPONDIENTES AL CODIGO O BATCH DEL PROCESO  */
        select tabla_lectura, campo_proceso, tipo_ws  into v_readingtable, v_campoproceso, v_typews from t_jde_urltrama_ws where sistema = p_sistema and nombre = p_metodo_ws;
        /* SELCCIONA EL DBLINK CORREPONDIENTE EN CASO DE PERTENECER A OTRO SISTEMA*/
        select pk_apex_item.f_dblink( p_sistema => p_sistema ) into v_dblink from dual;
        if v_dblink is not null then  v_dblink := '@'|| v_dblink; end if;

        delete from t_tmp_a;
        v_sql :='insert into t_tmp_a (flag,num01,txt01,clob1,txt02,clob2,clob3,clob4,txt05,txt06)
        select ''wsdl'' flag, id,wsdl,tramaenvio,tabla_lectura,parametrosenvio,campostabla,apex_header,campo_validacion,tipo_ws from t_jde_urltrama_ws where sistema = '||v_csim||p_sistema||v_csim||' and nombre = '||v_csim||p_metodo_ws||v_csim||' order by id asc';
        execute immediate v_sql;
        --select * from t_tmp_a
        for ws in ( select num01 id,txt01 wsdl,clob1 tramaenvio,upper(txt02) tabla_lectura,clob2 parametrosenvio,clob3 campostabla,clob4 apex_header,txt05 campo_validacion,txt06 tipo_ws from t_tmp_a where flag = 'wsdl')--ejmc
        loop--ejmc
            /* INICIA EN TIPO DE WS SOAP*/
            v_sendingstring := ws.tramaenvio;
            /* SEPARA CADA CAMPO REFERENTE A LA TABLA PARA LA CONSULTA DE LOS VALORES PARA EL REEMPLAZO */
            for campo in(   select filacampo,filaxml,parametros,parametroxml
                            from (select id filacampo, upper(item)  parametros   from table(pk_commons.f_dividirtexto(ws.campostabla, v_separatorvalues)))    paramcampo inner join
                                 (select id filaxml  , (item)       parametroxml from table(pk_commons.f_dividirtexto(ws.parametrosenvio, v_separatorvalues)))paramxml   on filacampo=filaxml
                                    where parametros<>'_VACIO'
                                 )
            loop
                v_xmlparameter := campo.parametroxml;
                begin
                    --VERIFICA QUE EL CAMPO EXISTA EN LA TABLA DE LECTURA
                    v_sql := 'select count(1) from all_tab_columns' || v_dblink || ' where table_name = ' ||v_csim||ws.tabla_lectura||v_csim||' and column_name ='||v_csim||campo.parametros||v_csim;
                    execute immediate v_sql into v_exist;
                    if v_exist > 0 then--SI EXISTE SE DETERMINA QUE DEBE LEER EL VALOR DESDE LA TABLA PARA ENVIAR EN EL WS
                        v_queryfield:= case
                                            when lower(campo.parametros) = 'razonsocial'        then  'substr(razonsocial,1,40)'
                                            when lower(campo.parametros) = 'actividadeconomica' then  'substr(actividadeconomica,1,40)'
                                            else       campo.parametros
                                        end;
                        v_sql := 'select ('|| v_queryfield || ') from ' || ws.tabla_lectura || v_dblink || ' where '||v_campoproceso||' = '||p_identificador;
                        begin execute immediate v_sql into v_sqlres; exception when others then dbms_output.put_line('SQLERRM:'||sqlerrm); end;
                        if (lower(campo.parametros) = 'nombrecomercial' ) then v_nombrecomercial :=v_sqlres; end if;
                        if (trim(v_sqlres) is not null)then
                            v_sendingstring:= replace(v_sendingstring, '<'|| v_xmlparameter ||'/>','<'|| v_xmlparameter ||'>' || v_sqlres || '</'|| v_xmlparameter||'>'  )  ;
                        end if;
                    else
                        --SI NO EXISTE SE DEBE TOMAR COMO UN VALOR LITERAL Y REEMPLAZARLO EN LA TRAMA
--                        if(p_opcion =4)then
--                            v_sqlres:=to_char(p_identificador);
--                            v_sendingstring:=  replace(v_sendingstring, '<'|| v_xmlparameter ||'/>','<'|| v_xmlparameter ||'>' || v_sqlres || '</'|| v_xmlparameter||'>');
--                        else

                        v_sqlres:= f_get_xml_tag(p_identificador,campo.parametros,campo.parametroxml,p_opcion);
--                        v_sqlres:= case
--                                        when upper(campo.parametros) in( '_CERO','_DOS','MONEDA')  then f_get_xml_tag(p_identificador,campo.parametros,p_opcion)
--                                        when upper(campo.parametros) = '_PUNTO' then (f_set_esp(campo.parametros,1))
--                                        when upper(campo.parametros)=upper(campo.parametroxml) then  f_get_xml_tag(p_identificador,campo.parametroxml,p_opcion)
--                                    end ;

                                v_sendingstring:=  replace(v_sendingstring, '<'|| v_xmlparameter ||'/>',case when (upper(campo.parametros)=upper(campo.parametroxml)) then v_sqlres else '<'|| v_xmlparameter ||'>' || v_sqlres || '</'|| v_xmlparameter||'>'end);
--                        end if;
                    end if;
                end;
            end loop;
            /* OBTENER EL VALOR DEL USUARIO Y CONTRASEÃ‘A PARA EL ENVIO AL WS*/
            begin
                select trim(valor), trim (valor2) into v_user, v_pass from t_corp_udc where id_cabecera = 'JDE_WS' and id_tabla = '1';
            exception when no_data_found then
                null;
            end;
            -- CAMBIO DE USER
            select item into v_headers1 from pk_commons.f_dividirtexto(ws.apex_header,'|') where id=1;
            select item into v_headers2 from pk_commons.f_dividirtexto(ws.apex_header,'|') where id=2;
            select item into v_headers3 from pk_commons.f_dividirtexto(ws.apex_header,'|') where id=3;

            v_sendingstring:= replace(v_sendingstring, '#USERNAME#', v_user )  ;
            -- CAMBIO DE PASS
            v_sendingstring:= replace(v_sendingstring, '#PASSWORD#', v_pass )  ;
            /* SEPARA EL PARAMETROS DE HEADER PARA EL WS*/
            v_header2v := v_headers2 ;
            /* COMPLETA LA DIRECCION DEL HEADER 3*/
            v_header3v := v_headers1|| v_headers2||'/'||v_headers3;
            apex_web_service.g_request_headers(1).name := 'Content-Type';
            apex_web_service.g_request_headers(1).value := 'application/xml';
            apex_web_service.g_request_headers(2).name := 'BSSV';
            apex_web_service.g_request_headers(2).value := v_header2v;
            apex_web_service.g_request_headers(3).name := 'BSSVrequest';
            apex_web_service.g_request_headers(3).value :=  v_header3v;
            /* OBTENER EL VALOR DE LA URL DE WS DE REPORTES */

            dbms_output.put_line('v_header2v:'||v_header2v);
            dbms_output.put_line('v_header3v:'||v_header3v);


            select valor into v_url from t_corp_udc where id_cabecera='JDE_WS' and id_tabla ='5';
            dbms_output.put_line('v_url:'||v_url);
            v_tramaclob := apex_web_service.make_rest_request(
                    p_url => v_url,--||'/ssss',
                    p_http_method => 'POST',
                    p_body => v_sendingstring
            );
             dbms_output.put_line('v_sendingstring:'||v_sendingstring);
             dbms_output.put_line('v_tramaclob:'||v_tramaclob);

            if(p_metodo_ws in ('processSupplier','processSupplierEdita'))then
                v_valida:=f_procesar_response (v_tramaclob, p_metodo_ws);
            else
                return;
            end if;
             --DBMS_OUTPUT.PUT_LINE('v_valida:'||v_valida);
            delete from t_tmp_a;
            insert into t_tmp_a (num01, txt01,txt02,clob1)
                select id, campo1, campo2,  campo3 from table(pk_commons.f_split2tablev2(v_valida,'|',';'));
            select count(1) into v_eserror from (select id, campo1, campo2,  campo3 from table(pk_commons.f_split2tablev2(v_valida,'|',';'))) where to_char(campo1)='Error';
            select count(1) into v_esexito from (select id, campo1, campo2,  campo3 from table(pk_commons.f_split2tablev2(v_valida,'|',';'))) where to_char(campo1)='Exito';

            begin
                select  to_number(to_char(campo3)) into v_aban8 from (select id, campo1, campo2,  campo3 from table(pk_commons.f_split2tablev2(v_valida,'|',';'))) where to_char(campo2)='entityId';
            exception when others then
                v_aban8:=null;
            end;

            if (v_eserror>0)then
                v_valida:=replace(v_valida,v_exito||'entityId|'||v_aban8,'');
            end if;
            if (p_metodo_ws ='processSupplier')then
                if (v_eserror>0)then
                    begin
                        if (v_aban8 is not null) then   sp_gestionar_proveedor('APEX', 'processSupplierBorra',4, to_number(v_aban8) ,v_noresponse );end if;
                    exception when others then
                        null;
                    end;
                    --DBMS_OUTPUT.PUT_LINE('borrado2:'||v_aban8);
                else
                    if (v_aban8 is not null) then
                        v_sql := 'update ' || ws.tabla_lectura || v_dblink || ' SET CODIGOJDE='||v_aban8||'  WHERE '||v_campoproceso||' = '||p_identificador;
                        execute immediate v_sql ;
                        update f0101@jdedtadl set abdc =v_nombrecomercial where aban8=v_aban8;
                        --DBMS_OUTPUT.PUT_LINE('actualizado:'||v_aban8);
                    end if;
                end if;

            elsif (p_metodo_ws in ('processSupplierBorra','processSupplierEdita'))then
                dbms_output.put_line('borrado:'||v_aban8);
            end if;

            p_resultado:=v_valida;
        end loop;
    end sp_gestionar_proveedor;

    function f_procesar_response (p_tramaclob in clob, p_metodo_ws in varchar2) return varchar2 as
        v_separatorvalues varchar2(1):= ',';
        v_jsonexito varchar2(20);
        v_jsonresul clob;
        v_tramaclob clob:=p_tramaclob;
        v_paramrecepcion varchar2(1900);
        v_etiqueta varchar2(1240);
        v_textorespon varchar2(1240);
        v_salida  varchar2(3999);
        v_xpath  varchar2(3999);
        v_ejecuta  number:=0;
    begin

        v_jsonexito :=f_get_json_param(v_tramaclob,'exito');
        v_jsonresul :=f_get_json_param(v_tramaclob,'resultado');
        if nvl(v_jsonexito,'false')<>'true' then
            v_salida := (v_error||v_jsonresul);
            return v_salida;
        end if;

        -- Capturar SOAP Fault si JDE rechazó con excepción
        if instr(v_jsonresul, '<faultstring>') > 0 then
            declare
                v_i1 number := instr(v_jsonresul, '<faultstring>') + length('<faultstring>');
                v_i2 number := instr(v_jsonresul, '</faultstring>') - v_i1;
                v_fault varchar2(4000);
            begin
                if v_i2 > 0 then
                    v_fault := substr(v_jsonresul, v_i1, v_i2);
                    v_fault := replace(v_fault, '&#xd;', ' ');
                    v_fault := replace(v_fault, chr(10), ' ');
                    v_fault := replace(v_fault, chr(13), ' ');
                    v_fault := regexp_replace(v_fault, '\s+', ' ');
                    v_salida := v_error || 'fault|' || trim(v_fault);
                    return v_salida;
                end if;
            end;
        end if;

        select parametrosrecepcion  into v_paramrecepcion from t_jde_urltrama_ws where nombre = p_metodo_ws;
        for paramxml in (select id fila,  (item)  parametros   from table(pk_commons.f_dividirtexto(v_paramrecepcion, v_separatorvalues)))
        loop
            v_etiqueta:=paramxml.parametros;
            v_etiqueta:=replace (v_etiqueta, '[', '');
            v_etiqueta:=replace (v_etiqueta, ']', '');
            v_etiqueta:=trim(v_etiqueta);
            v_xpath:=
                case
                    when v_etiqueta = ('message')    then  '/e1MessageList/e1Messages'
                    when trim(lower(v_etiqueta)) = ('entityid')   then  '/entity'
                end;
            v_ejecuta:=
                case
                    when v_etiqueta = ('message')    then 1
                    when trim(lower(v_etiqueta)) = ('entityid')   then  1
                    else 0
                end;
            if (v_ejecuta=1)then
                v_textorespon:=null;
                v_textorespon := f_get_xml_param(v_jsonresul,v_xpath,v_etiqueta,'WSJDE');
                v_textorespon:=trim(lower(v_textorespon));
                if (v_textorespon is not null)then
                    v_salida:=  v_salida||
                                case v_etiqueta
                                when 'message' then v_error||paramxml.parametros||'|'||v_textorespon
                                else                v_exito||paramxml.parametros||'|'||v_textorespon
                                end;
                end if;
            end if;
            v_ejecuta:= 1;
        end loop;

        return v_salida;
    end f_procesar_response;

    function f_get_json_param(p_tramajson in clob, p_etiqueta varchar2) return clob as
    begin
     return json_value(p_tramajson, '$.'||p_etiqueta);
    end f_get_json_param;

    function f_get_xml_param(p_tramaclob in clob,p_xpath varchar2,p_etiqueta varchar2, p_tipo varchar2 default 'WSJDE') return varchar2 as
        v_tramaclob clob:=p_tramaclob;
        v_tramaclob2 clob:=p_tramaclob;
        v_xpath varchar2(2000):=p_xpath;
        v_retorno varchar2(3999);
        v_index1 number;
        v_index2 number;
        v_sql varchar2(3999);
        l_xml xmltype;
    begin
        if (p_tipo ='WSJDE')then
            v_index1:=instr(v_tramaclob,'<S:Body>')+length('<S:Body>');
            v_index2:=instr(v_tramaclob,'</S:Body>')-v_index1;
            v_tramaclob:=substr(v_tramaclob,v_index1, v_index2);
            v_index1:=instr(v_tramaclob,'>')+1;
            v_index2:=instr(v_tramaclob,'</ns2:processSupplierResponse>')-v_index1;
            v_tramaclob:='<Body>'||substr(v_tramaclob,v_index1, v_index2)||'</Body>';
            if (substr(v_xpath,1,1)='/') then v_xpath:=substr(v_xpath,2);end if;
            v_xpath:= '/Body/'||p_xpath;
            v_tramaclob:='<Body></Body>';
            if (trim(v_tramaclob)='<Body></Body>')then
                v_index1:=instr(v_tramaclob2,'<'||p_etiqueta||'>')+length('<'||p_etiqueta||'>');
                v_index2:=instr(v_tramaclob2,'</'||p_etiqueta||'>')-v_index1;
                v_tramaclob:='<Body><'||p_etiqueta||'>'||substr(v_tramaclob2,v_index1, v_index2)||'</'||p_etiqueta||'></Body>';
                v_xpath:='/Body/'||p_etiqueta;
            end if;
        end if;
        v_xpath:=replace(v_xpath,'//','/');
        v_sql:='SELECT cadena FROM XMLTABLE('''||v_xpath||''' PASSING  xmltype('''||v_tramaclob||''') COLUMNS cadena VARCHAR2(3999) PATH ''/'||p_etiqueta||''') xt where rownum=1';
--        IF (p_etiqueta='entityId')THEN
--            L_XML:=xmltype(v_tramaclob);
--            --DBMS_OUTPUT.PUT_LINE(L_XML.getCLOBVal()  );
--        END IF;
        execute immediate v_sql into v_retorno ;
        v_retorno:=replace(v_retorno,'0 - 0, 0, 0',' ');
        v_retorno:=replace(v_retorno,'  -  ,  ,  ',' ');
        v_retorno:=replace(v_retorno,' . . . . ',':');
        v_retorno:=replace(v_retorno,'. . ',':');
        v_retorno:=replace(v_retorno,chr(10)||' ','');
        v_retorno:=trim(v_retorno);
        return v_retorno;
    exception when others then
        v_retorno:='';
        return v_retorno;
    end f_get_xml_param;

    function f_get_xml_tag(p_id number,p_campo varchar2,p_parametroxml varchar2,p_accion char default '1') return varchar2
    as
        v_texto varchar(900):=' ';
        v_return clob:=' ';

        v_tageaddresses varchar(900);
        v_tagphonumbers varchar(900);
        v_tageaddresses2 varchar(900);
        v_tagphonumbers2 varchar(900);
        v_tagrelatedaddress varchar(900);

        v_telefono varchar2(900);
        v_contacto varchar2(900);
        v_celular varchar2(900);
        v_tab1 number;
        v_tab2 number;
    begin
        v_tab1 :=6;
        v_tab2 :=v_tab1+1;
        v_tageaddresses:=f_set_tabs(v_tab1,1)||'<electronicAddresses>'
                    ||f_set_tabs(v_tab2,1)||'<actionType>_actionType_</actionType>'
                    ||f_set_tabs(v_tab2,1)||'<contactId>_contactId_</contactId>'
                    ||f_set_tabs(v_tab2,1)||'<electronicAddress>_electronicAddress_</electronicAddress>'
                    ||f_set_tabs(v_tab2,1)||'<electronicAddressClassificationCode>_electronicAddressClassificationCode_</electronicAddressClassificationCode>'
                    ||f_set_tabs(v_tab2,1)||'<electronicAddressLineNumber>_electronicAddressLineNumber_</electronicAddressLineNumber>'
                    ||f_set_tabs(v_tab2,1)||'<electronicAddressTypeCode>_electronicAddressTypeCode_</electronicAddressTypeCode>'
                    ||f_set_tabs(v_tab2,1)||'<messageIndicatorCode>_messageIndicatorCode_</messageIndicatorCode>'
                    ||f_set_tabs(v_tab1,1)||'</electronicAddresses>';
         v_tagphonumbers:=f_set_tabs(v_tab1,1)||'<phoneNumbers>'
                        ||f_set_tabs(v_tab2,1)||'<actionType>_actionType_</actionType>'
                        ||f_set_tabs(v_tab2,1)||'<contactId>_contactId_</contactId>'
                        ||f_set_tabs(v_tab2,1)||'<areaCode>_areaCode_</areaCode>'
                        ||f_set_tabs(v_tab2,1)||'<phoneLineNumber>_phoneLineNumber_</phoneLineNumber>'
                        ||f_set_tabs(v_tab2,1)||'<phoneNumber>_phoneNumber_</phoneNumber>'
                        ||f_set_tabs(v_tab2,1)||'<phoneTypeCode>_phoneTypeCode_</phoneTypeCode>'
                        ||f_set_tabs(v_tab1,1)||'</phoneNumbers>';
        v_tagrelatedaddress:=f_set_tabs(v_tab1,1)||'<_relatedAddress_>'
                        ||f_set_tabs(v_tab2,1)||'<entityId/>'
                        ||f_set_tabs(v_tab2,1)||'<entityLongId/>'
                        ||f_set_tabs(v_tab2,1)||'<entityTaxId/>'
                        ||f_set_tabs(v_tab1,1)||'</_relatedAddress_>';
        if (upper(p_campo)='ELECTRONICADDRESSES')then
            begin
                select emailpedido||'|'||emailretencion||';CRE' into v_texto from t_jde_f0401z where id = p_id;
            exception when others then
                v_texto := null;
            end;
            for mails in (  select id,
                            case when instr(item, ';') >0 then substr(item,1,instr(item, ';')-1) else item end item,
                            case when instr(item, ';') >0 then substr(item,instr(item, ';')+1) else ' ' end tipo,
                            case when instr(item, ';') >0 then '0' else '1' end indi
                            from table( pk_commons.f_dividirtexto(v_texto, '|' ))
                          )
            loop
                v_tageaddresses2:=v_tageaddresses;
                v_tageaddresses2:=replace(v_tageaddresses2,'_actionType_',p_accion);
                v_tageaddresses2:=replace(v_tageaddresses2,'_contactId_','0');
                v_tageaddresses2:=replace(v_tageaddresses2,'_electronicAddress_',mails.item);
                v_tageaddresses2:=replace(v_tageaddresses2,'_electronicAddressClassificationCode_',mails.tipo);
                v_tageaddresses2:=replace(v_tageaddresses2,'_electronicAddressLineNumber_',mails.id);
                v_tageaddresses2:=replace(v_tageaddresses2,'_electronicAddressTypeCode_','E');
                v_tageaddresses2:=replace(v_tageaddresses2,'_messageIndicatorCode_',mails.indi);
                v_return:=trim(v_return)||v_tageaddresses2;
            end loop;
            return f_set_tabs(5,1)||'<!--Zero or more repetitions:-->'||trim(v_return);
        elsif (upper(p_campo)='PHONENUMBERS')then
            begin
                select contacto,telefono,celular into v_contacto,v_telefono,v_celular from t_jde_f0401z where id = p_id;
            exception when others then
                v_contacto := null; v_telefono := null; v_celular := null;
            end;
            for phones in (select flag,p_id p_id, row_number() over(order by flag, tipo desc)fila, nombres, contacto, codecount, numero, tipo
                            from ( select 'phone'flag ,id,v_contacto nombres,'CONTACTO' contacto,regexp_replace(substr(item,1,instr(item ,')')),'\(|\)|\+','')codecount,substr(item,instr(item ,')')+1)numero,trim('      OFI ') tipo
                                   from table(pk_commons.f_dividirtexto(v_telefono,'|'))
                                   where item is not null
                                 -- union all
                                 -- select 'phone',id,campo1 nombres, campo2 cargo,regexp_replace(substr(campo3,1,instr(campo3 ,')')),'\(|\)|\+','') codecount,
                                 -- substr(campo3,instr(campo3 ,')')+1)numero,trim(' CEL ') tipo
                                 -- from table(pk_commons.f_split2table(v_celular, '|',';') )
                                   )
                          )
            loop
                v_tagphonumbers2:=v_tagphonumbers;
                v_tagphonumbers2:=replace(v_tagphonumbers2,'_actionType_',p_accion);
                v_tagphonumbers2:=replace(v_tagphonumbers2,'_contactId_','');
                v_tagphonumbers2:=replace(v_tagphonumbers2,'_areaCode_',phones.codecount);
                v_tagphonumbers2:=replace(v_tagphonumbers2,'_phoneLineNumber_',phones.fila);
                v_tagphonumbers2:=replace(v_tagphonumbers2,'_phoneNumber_',phones.numero);
                v_tagphonumbers2:=replace(v_tagphonumbers2,'_phoneTypeCode_',phones.tipo);
                v_return:=trim(v_return)||v_tagphonumbers2;
            end loop;
            return f_set_tabs(5,1)||'<!--Zero or more repetitions:-->'||trim(v_return);
        elsif (upper(p_campo)in ('RELATEDADDRESS1','RELATEDADDRESS2','RELATEDADDRESS3','RELATEDADDRESS4','RELATEDADDRESS5','RELATEDADDRESS6'))then
             v_texto:=replace(v_tagrelatedaddress,'_relatedAddress_',p_parametroxml);
             v_return:=trim(v_return)||f_set_tabs(v_tab1,1)||v_texto;
        elsif ( upper(p_campo)='YEARCOMPANYFOUNDED' )     then
            begin
                select to_char(fechaconstitucion,'YYYY') into v_texto from t_jde_f0401z where id = p_id;
            exception when others then
                v_texto := null;
            end;
            if (v_texto is null)then
                return trim(v_return)||f_set_tabs(v_tab1,1)||'<'||p_parametroxml||'/>';
            else
                return trim(v_return)||f_set_tabs(v_tab1,1)||'<'||p_parametroxml||'>'||v_texto||'</'||p_parametroxml||'>';
            end if;
        elsif ( upper(p_campo)='GLOFFSETCODE' )     then
            begin
                select  case trim(tipoproveedor)
                            when 'PL' then 'PLOC'
                            when 'PE' then 'PEXT'
                            when 'E' then 'AEMP'   else '    '
                        end into v_texto from t_jde_f0401z where id = p_id;
            exception when others then
                v_texto := '    ';
            end;
            return trim(v_return)||f_set_tabs(v_tab1,1)||'<'||p_parametroxml||'>'||v_texto||'</'||p_parametroxml||'>';
        elsif ( upper(p_campo)='STATECODE' ) then
            begin
                select trim(drky) into v_texto
                from data.t_corp_states
                inner join t_jde_f0401z on state_code=provincia and country_code =pais
                inner join vt_jde_udc on translate(upper(trim(drdl01)), 'ÁÉÍÓÚÜÑ', 'AEIOUUN') = translate(upper(trim(state_name)), 'ÁÉÍÓÚÜÑ', 'AEIOUUN')
                where id = p_id and drsy='00' and drrt='S' and rownum=1;
            exception
                when others then
                    v_texto := null;
            end;
            if v_texto is null then
                return trim(v_return)||f_set_tabs(v_tab1,1)||'<'||p_parametroxml||'/>';
            else
                return trim(v_return)||f_set_tabs(v_tab1,1)||'<'||p_parametroxml||'>'||v_texto||'</'||p_parametroxml||'>';
            end if;
        elsif ( upper(p_campo)='DATEEFFECTIVE' ) then
            begin
                select to_char(pk_commons.f_g2jde(fechaconstitucion)) into v_texto
                from t_jde_f0401z where id = p_id;
            exception when others then
                v_texto := null;
            end;
            return trim(v_return)||f_set_tabs(v_tab1)||'<'||p_parametroxml||'>'||v_texto||'</'||p_parametroxml||'>';

        elsif ( upper(p_campo)='ENTITYID' and p_accion = '1') then
            return trim(v_return)||f_set_tabs(v_tab1)||'<'||p_campo||'/>';

        elsif ( upper(p_campo)='ENTITYID' and p_accion in('2','3')) then
            begin
                select to_char(codigojde) into v_texto
                from t_jde_f0401z where id = p_id;
            exception when others then
                v_texto := null;
            end;
            v_texto:=' ';
            return trim(v_return)||f_set_tabs(v_tab1)||'<'||p_parametroxml||'>'||v_texto||'</'||p_parametroxml||'>';

        elsif ( upper(p_campo)='ENTITYID' and p_accion ='4') then
            v_texto :=p_id;
            return trim(v_return)||f_set_tabs(v_tab1)||'<'||p_parametroxml||'>'||v_texto||'</'||p_parametroxml||'>';
        elsif ( upper(p_campo)='_PUNTO') then
            v_texto :='.';
            return trim(v_return)||v_texto;
        elsif ( upper(p_campo)='POSTALCODE') then
            v_texto :='170812';
            return trim(v_return)||f_set_tabs(v_tab1)||'<'||p_parametroxml||'>'||v_texto||'</'||p_parametroxml||'>';
        elsif ( upper(p_campo)='MONEDA') then
            v_texto :='USD';
           return trim(v_return)||v_texto;
        elsif ( upper(p_campo)='PRENOTECODE') then
            v_texto :='P';
        elsif ( upper(p_campo)='_CERO') then
            v_texto :='0';
            return trim(v_return)||v_texto;
        elsif ( upper(p_campo) in ('SPECIALINSTRUCTION4','SPECIALINSTRUCTION5')) then
            v_texto :='A';
            return trim(v_return)||f_set_tabs(v_tab1)||'<'||p_parametroxml||'>'||v_texto||'</'||p_parametroxml||'>';
        else
            v_texto:= case upper(p_campo)
                when('ACTIONTYPE')then case when p_accion='4' then 3 else p_accion end
                when('MINIMUMCHECKAMOUNTCODE')then'1'
--                when('SPECIALINSTRUCTION4')then'A'
--                when('SPECIALINSTRUCTION5')then'A'
--                when('POSTALCODE')then '170812'
--                when('PRENOTECODE')then'P'
--                when('_CERO' )then '0'
--                when('MONEDA')then 'USD'
                end;
            return trim(v_return)||f_set_tabs(v_tab1,1)||'<'||p_parametroxml||'>'||v_texto||'</'||p_parametroxml||'>';
        end if;
        return v_return;
    end f_get_xml_tag;

    function f_set_tabs(p_numero number,salto number default 0) return varchar2 as
    r_ret varchar2(100);
    begin
        r_ret :=case salto when 1 then chr(10) else ' ' end || lpad(' ',p_numero,chr(9));
        return r_ret ;
    end f_set_tabs;

end pk_jde_librodirecciones_ws;
/

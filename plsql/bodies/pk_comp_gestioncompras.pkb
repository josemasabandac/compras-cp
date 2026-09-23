
  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "PK_COMP_GESTIONCOMPRAS" as
	-----------------------
	-- F U N C I O N E S --
	-----------------------
	/*
	** Propósito: Busca en las negociaciones si el producto tiene cab_tipo='FM' sin importar la vigencia  CASO 27000
	** Parámetros:
	**	P_CODIGOCORTOPRODUCTO          NUMBER: Entrada.
	*/
    function f_puede_reservar(p_codigocortoproducto number) return number as
	v_count number;
    begin
		select count(1) into v_count
		from vt_comp_negociaciondet
		where 1 = 1
			and det_codproducto = p_codigocortoproducto
			and cab_tipoprecio = 'FM';

        return case when v_count > 0 then 1 else 0 end;
    end f_puede_reservar;

	function f_tieneanticipo (p_compania varchar2, p_tipoorden varchar2,p_numeroorden number) return number as
	begin
		v_compania := p_compania;
		begin
			select idcab into v_aux_nm1
			from data.vt_comp_anticipos
			where compania = v_compania and tipoorden = p_tipoorden and ordencompra = p_numeroorden;

			exception when others then v_aux_nm1 := -1;
		end;
		return v_aux_nm1;
	end f_tieneanticipo;

	function f_ultimacompra (p_compania varchar2, p_proveedor varchar2, p_producto varchar2) return varchar2 as
	v_codigocorto	number;
	v_resultado		varchar2(4000);
	v_registro		number;
	v_proveedor		varchar2(50);
	v_producto		varchar2(50);
	begin
		v_compania	:= trim(p_compania);
		v_proveedor	:= trim(p_proveedor);
		v_producto	:= trim(p_producto);
		if v_compania is null or v_proveedor is null or v_producto is null then
			return '{"exito":0,"error":"v_compania is null or v_proveedor is null or v_producto is null"}';
		else
			if v_compania = '00001' then
				select max(a.id) into v_registro
				from data.t_comp_prodto_proveedr_gestion a
				inner join f4311@jdedtadl on pddoco = documento_oc and pddcto = documentotipo_oc and pdlnid = (linea*1000)
				left join data.vt_comp_negociacion b on a.det_id = b.det_id
				where 1 = 1
					and a.compania = v_compania
					and pdan8 = to_number(v_proveedor)
					and codigocortoproducto = (select imitm from f4101@jdedtadl where trim(imlitm) = v_producto)
					and not (pdlttr = '980' and pdnxtr = '999');

				-- return '{"dato":"v_compania = '||v_compania||', v_proveedor = '||v_proveedor||', v_producto = '||v_producto||', v_registro = '||v_registro||'"}';

				if v_registro is null then
					select max(a.id) into v_registro
					from data.t_comp_prodto_proveedr_gestion a
					inner join f4311@jdedtadl on pddoco = documento_oc and pddcto = documentotipo_oc and pdlnid = (linea*1000)
					left join data.vt_comp_negociacion b on a.det_id = b.det_id
					where 1 = 1
						and a.compania = v_compania
						-- and pdan8 = v_proveedor
						and codigocortoproducto = (select imitm from f4101@jdedtadl where trim(imlitm) = v_producto)
						and not (pdlttr = '980' and pdnxtr = '999');
				end if;

				if v_registro is null then
					return '{"exito":0,"error":"No se encontró una compra válida"}';
				end if;

				begin
					select json_object(
						'exito' value 1,
						'goc_id' value goc_id,
						'compania' value compania,
						'pddcto' value pddcto,
						'pddoco' value pddoco,
						'pdlnid' value pdlnid,
						'qtyorg' value qtyorg,
						'qtyman' value qtyman,
						'prcman' value prcman,
						'pdoorn' value pdoorn,
						'pdocto' value pdocto,
						'pdogno' value pdogno,
						'goc_fecha' value goc_fecha,
						'pdan8' value pdan8,
						'pditm' value pditm,
						'pdlitm' value pdlitm,
						'neg_id' value neg_id,
						'cab_id' value cab_id,
						'det_id' value det_id,
						'neg_vigenciadesde' value to_char(neg_vigenciadesde,'dd/mm/yyyy'),
						'neg_vigenciahasta' value to_char(neg_vigenciahasta,'dd/mm/yyyy')
					) as resultado_json into v_resultado from (
						select a.id goc_id
							, a.compania
							, pddcto
							, pddoco
							, pdlnid
							, a.cantidad qtyorg
							, a.cantidad_manual qtyman
							, a.preciounitario prcman
							, pdoorn
							, pdocto
							, pdogno
							, to_char(a.fecha_procesado,'dd/mm/yyyy') goc_fecha
							, pdan8
							, pditm
							, trim(pdlitm) pdlitm
							, lpad(b.neg_id,5,'0') neg_id
							, lpad(b.cab_id,5,'0') cab_id
							, lpad(b.det_id,8,'0') det_id
							, b.neg_vigenciadesde
							, b.neg_vigenciahasta
						from data.t_comp_prodto_proveedr_gestion a
						inner join f4311@jdedtadl on pddoco = documento_oc and pddcto = documentotipo_oc and pdlnid = (linea*1000)
						left join data.vt_comp_negociacion b on a.det_id = b.det_id
						where a.id = v_registro
					) a;

					return v_resultado;

					exception when others then return '{"exito":0,"error":"' || replace(sqlerrm, '"', '''') || '"}';
				end;
			else
				return '{"exito":0,"error":"v_compania = '||v_compania||'"}';
			end if;
		end if;
	end f_ultimacompra;

	function f_gestionporun (p_compania varchar2, p_unidadnegocio varchar2, p_usuario varchar2) return number as
	v_corp_udc	data.t_corp_udc%rowtype;
	v_retorno	number;

	v_tiene_global_user		number	:= 0;
	v_tiene_global_all		number	:= 0;
	v_tiene_un_explicito	number := 0;
	v_tiene_confidencial	number := 0;
	begin
		v_compania		:= upper(trim(p_compania));
		v_unidadnegocio	:= upper(trim(p_unidadnegocio));
		v_usuario		:= upper(trim(p_usuario));

		select case when count(*) > 0 then 1 else 0 end into v_retorno
		from data.t_corp_udc
		where 1 = 1
			and id_cabecera = 'COMP_USCMP'
			and activo = 1
			and trim(upper(id_tabla)) = v_compania
			and trim(upper(descripcion)) = 'ADMINISTRADOR'
			and trim(upper(valor2)) = v_usuario;

		if v_retorno = 1 then
			return 1;
		end if;

		select case when count(*) > 0 then 1 else 0 end
		into v_tiene_global_user
		from data.t_corp_udc
		where id_cabecera = 'COMP_USCMP'
		and activo = 1
		and trim(upper(id_tabla)) = v_compania
		and trim(upper(valor)) = '*'
		and trim(upper(valor2)) = v_usuario;

		select case when count(*) > 0 then 1 else 0 end
		into v_tiene_global_all
		from data.t_corp_udc
		where id_cabecera = 'COMP_USCMP'
		and activo = 1
		and trim(upper(id_tabla)) = v_compania
		and trim(upper(valor)) = '*'
		and trim(upper(valor2)) = '*';

		select case when count(*) > 0 then 1 else 0 end
		into v_tiene_un_explicito
		from data.t_corp_udc
		where id_cabecera = 'COMP_USCMP'
		and activo = 1
		and trim(upper(id_tabla)) = v_compania
		and trim(upper(valor)) = v_unidadnegocio
		and trim(upper(valor2)) = v_usuario;

		select case when count(*) > 0 then 1 else 0 end
		into v_tiene_confidencial
		from data.t_corp_udc
		where id_cabecera = 'COMP_USCMP'
		and activo = 1
		and trim(upper(id_tabla)) = v_compania
		and trim(upper(valor)) = 'CONFIDENCIAL'
		and trim(upper(valor2)) = v_usuario;

		if v_unidadnegocio = 'CONFIDENCIAL' then
			if v_tiene_un_explicito = 1 or v_tiene_confidencial = 1 then
				return 1;
			else
				return 0;
			end if;
		else
			if v_tiene_un_explicito = 1 then
				return 1;
			elsif v_tiene_global_user = 1 then
				return 1;
			elsif v_tiene_global_all = 1 then
				return 1;
			else
				return 0;
			end if;
		end if;
	end f_gestionporun;

	---------------------------------
	-- P R O C E D I M I E N T O S --
	---------------------------------
	/*
	** Propósito:	Toma todos los items de la F43011 y los añade a la OC borrador
	** Parámetros:
    **  P_DOCUMENTOTIPO VARCHAR2: Entrada. tipo de documento: H1, H2, H3
    **  P_DOCUMENTO     NUMBER: Entrada. numero de documento
    **  P_USUARIO       VARCHAR2: Entrada. La persona que está gestionando la OC
    **  P_COMPANIA      VARCHAR2: Entrada. Código de la empresa.

    **  SET SERVEROUTPUT ON
	*/
    PROCEDURE SP_AGREGA_ITEMS_OC_BORRADOR (P_DOCUMENTOTIPO VARCHAR2, P_DOCUMENTO NUMBER, P_USUARIO VARCHAR2, P_COMPANIA VARCHAR2)
    AS
    BEGIN
        MERGE INTO T_COMP_F4311_GESTION GESTION
        USING (
            SELECT LINEA, DOCUMENTOTIPO, DOCUMENTO, CODIGOCORTOPRODUCTO, BODEGA, REQUISITOR, ESTADO_SIG
            from vt_comp_f4311
            where 1 = 1
                and estado_sig <> '999' and documentotipo = p_documentotipo and documento = p_documento
                and codigoproducto not like 'S___                     '
            ORDER BY LINEA
        ) SRC
        ON
        (
            GESTION.LINEA         = SRC.LINEA
                AND
            GESTION.DOCUMENTOTIPO = SRC.DOCUMENTOTIPO
                AND
            GESTION.DOCUMENTO     = SRC.DOCUMENTO
        )
        WHEN NOT MATCHED THEN
            INSERT
                (ID, COMPANIA, USUARIO, REQUISITOR,
                LINEA, DOCUMENTOTIPO, DOCUMENTO, CODIGOCORTOPRODUCTO, BODEGA,
                FECHA_REGISTRO)
            VALUES
                (PK_COMMONS.F_SECUENCIA('T_COMP_F4311_GESTION'), P_COMPANIA, P_USUARIO, SRC.REQUISITOR,
                SRC.LINEA, SRC.DOCUMENTOTIPO, SRC.DOCUMENTO, SRC.CODIGOCORTOPRODUCTO, SRC.BODEGA,
                sysdate);

        SP_LOG('SP_AGREGA_ITEMS_OC_BORRADOR', P_DOCUMENTOTIPO||'-'||P_DOCUMENTO||'-'||P_USUARIO);
        -- Genero los registros de gestión individual
        IF P_DOCUMENTOTIPO = 'H2' THEN
            SP_AGREGA_PPGESTION_H2      (P_USUARIO, P_COMPANIA);
        ELSE
            SP_AGRUPA_PRODUCTOS_BORRADOR(P_USUARIO, P_COMPANIA);
        END IF;
    END;

	/*
	** Propósito:	Elimina un item BORRADOR seleccionado de la tabla T_COMP_F4311_GESTION
	** Parámetros:
    **  P_DOCUMENTOTIPO VARCHAR2: Entrada. tipo de documento: H1, H2, H3
    **  P_DOCUMENTO     NUMBER: Entrada. numero de documento
    **  P_LINEA         NUMBER: Entrada. El número de línea a eliminar.
    **  P_USUARIO       VARCHAR2: Entrada. La persona que está gestionando la OC
	*/
    PROCEDURE SP_ELIMINA_ITEM_OC_BORRADOR (P_DOCUMENTOTIPO VARCHAR2, P_DOCUMENTO NUMBER, P_LINEA NUMBER, P_USUARIO VARCHAR2, P_COMPANIA VARCHAR2)
    AS
    BEGIN
        DELETE FROM
            T_COMP_F4311_GESTION
        WHERE
            DOCUMENTOTIPO = P_DOCUMENTOTIPO
                AND
            DOCUMENTO     = P_DOCUMENTO
                AND
            LINEA         = P_LINEA
                AND
            COMPANIA      = P_COMPANIA
                AND
            USUARIO       = P_USUARIO
                AND
            FECHA_PROCESADO IS NULL;

        SP_LOG('SP_ELIMINA_ITEM_OC_BORRADOR', 'TIPO='||P_DOCUMENTOTIPO||' DOC='||P_DOCUMENTO||' LINEA='||P_LINEA||' '||P_USUARIO);
        -- Genero las agrupaciones de productos
        SP_AGRUPA_PRODUCTOS_BORRADOR(P_USUARIO, P_COMPANIA);
    END;

	/*
	** Propósito:	Elimina todos los items BORRADOR.
	** Parámetros:
    **  P_USUARIO       VARCHAR2: Entrada. La persona que está gestionando la OC
	*/
    PROCEDURE SP_ELIMINA_ITEMS_OC_BORRADOR (P_USUARIO VARCHAR2, P_COMPANIA VARCHAR2)
    AS
    BEGIN
        DELETE FROM
            T_COMP_F4311_GESTION
        WHERE
            COMPANIA     = P_COMPANIA
                AND
            USUARIO      = P_USUARIO
                AND
            FECHA_PROCESADO IS NULL;

        SP_LOG('SP_ELIMINA_ITEMS_OC_BORRADOR', P_USUARIO);
        -- Genero las agrupaciones de productos
        SP_AGRUPA_PRODUCTOS_BORRADOR(P_USUARIO, P_COMPANIA);
    END;

	/*
	** Propósito:	Agrupa los items por producto para gestionar la cantidad de los productos.
	** Parámetros:
    **  P_USUARIO       VARCHAR2: Entrada. La persona que está gestionando la OC
	*/
    PROCEDURE SP_AGRUPA_PRODUCTOS_BORRADOR (P_USUARIO VARCHAR2, P_COMPANIA VARCHAR2)
    AS
        V_COUNT           NUMBER;
        V_ID              NUMBER;
        V_CANTIDAD        NUMBER;
        V_CANTIDAD_MANUAL NUMBER;
        V_BODEGATIPO      VARCHAR2(5);
        V_UNIDADMEDIDA    VARCHAR2(20);
        V_DESCRIPCION1    VARCHAR2(30);
        V_DESCRIPCION2    VARCHAR2(30);
    BEGIN
        SP_LOG('SP_AGRUPA_PRODUCTOS_BORRADOR', 'Inicio USUARIO='||P_USUARIO||' COMPANIA='||P_COMPANIA);

        -- ELIMINO LOS PRODUCTOS NO SELECCIONADOS
        DELETE FROM T_COMP_PRODTO_PROVEEDR_GESTION
        WHERE
            COMPANIA    = P_COMPANIA
                AND
            USUARIO     = P_USUARIO
                AND
            FECHA_PROCESADO IS NULL
                AND
            CON_REQUISICION = 1
                AND
            CODIGOCORTOPRODUCTO NOT IN (
                SELECT
                    DISTINCT GESTION.CODIGOCORTOPRODUCTO
                FROM
                    T_COMP_F4311_GESTION GESTION
                WHERE
                    COMPANIA        = P_COMPANIA
                        AND
                    GESTION.USUARIO = P_USUARIO
                        AND
                    GESTION.FECHA_PROCESADO IS NULL
            );

        -- AGREGO LOS PRODUCTOS SELECCIONADOS A LA GESTIÓN
        FOR AGRUPADO IN (
            SELECT
                F4311.COMPANIA                AS COMPANIA,
                F4311.DOCUMENTOTIPO           AS DOCUMENTOTIPO,
                F4311.CODIGOCORTOPRODUCTO     AS CODIGOCORTOPRODUCTO,
                GESTION.BODEGA                AS BODEGA,
                SUM(F4311.CANTIDAD)           AS CANTIDAD,
                MAX(GESTION.REQUISITOR)       AS REQUISITOR
            FROM
                T_COMP_F4311_GESTION  GESTION,
                VT_COMP_F4311         F4311
            WHERE
                F4311.LINEA         = GESTION.LINEA
                    AND
                F4311.DOCUMENTOTIPO = GESTION.DOCUMENTOTIPO
                    AND
                F4311.DOCUMENTO     = GESTION.DOCUMENTO
                    AND
                F4311.COMPANIA      = P_COMPANIA
                    AND
                GESTION.USUARIO     = P_USUARIO
                    AND
                GESTION.FECHA_PROCESADO IS NULL
            GROUP BY
                F4311.COMPANIA, F4311.DOCUMENTOTIPO, F4311.CODIGOCORTOPRODUCTO, GESTION.BODEGA
        )
        LOOP
            -- Busco por si ya existe
            SELECT COUNT(1)
            INTO   V_COUNT
            FROM   T_COMP_PRODTO_PROVEEDR_GESTION PPGESTION
            WHERE  PPGESTION.TIPO_REQUISICION    = AGRUPADO.DOCUMENTOTIPO
                        AND
                   PPGESTION.CODIGOCORTOPRODUCTO = AGRUPADO.CODIGOCORTOPRODUCTO
                        AND
                   PPGESTION.BODEGA    = AGRUPADO.BODEGA
                        AND
                   PPGESTION.COMPANIA  = P_COMPANIA
                        AND
                   PPGESTION.USUARIO   = P_USUARIO
                        AND
                   PPGESTION.FECHA_PROCESADO IS NULL;

            IF V_COUNT = 0 THEN
                -- NO EXISTE.
                SELECT IMUOM3, IMDSC1, IMDSC2 INTO V_UNIDADMEDIDA, V_DESCRIPCION1, V_DESCRIPCION2 FROM F4101@JDEDTADL WHERE IMITM = AGRUPADO.CODIGOCORTOPRODUCTO;
                SELECT MCSTYL INTO V_BODEGATIPO   FROM F0006@JDEDTADL WHERE TRIM(MCMCU) = TRIM (AGRUPADO.BODEGA);

                -- Se inserta.
                PK_COMMONS.SP_SECUENCIA('T_COMP_PRODTO_PROVEEDR_GESTION', V_ID);
                INSERT INTO T_COMP_PRODTO_PROVEEDR_GESTION
                    (ID, COMPANIA, USUARIO,
                    CODIGOCORTOPRODUCTO, UNIDADMEDIDA, TIPO_REQUISICION, BODEGA,
                    CON_REQUISICION, BODEGATIPO, CANTIDAD, DESCRIPCION1, DESCRIPCION2,  RESERVA, FECHA_REGISTRO)
                VALUES
                    (V_ID, AGRUPADO.COMPANIA, P_USUARIO,
                    AGRUPADO.CODIGOCORTOPRODUCTO, V_UNIDADMEDIDA, AGRUPADO.DOCUMENTOTIPO, AGRUPADO.BODEGA,
                    1, V_BODEGATIPO, AGRUPADO.CANTIDAD, V_DESCRIPCION1, V_DESCRIPCION2, 0,       SYSDATE);

                -- Le intento poner una negociación por default
                SP_COLOCA_NEGOCIACION_DEFAULT(V_ID, AGRUPADO.CODIGOCORTOPRODUCTO, AGRUPADO.CANTIDAD );

                -- Pre-establezco el email
                UPDATE T_COMP_PRODTO_PROVEEDR_GESTION SET EMAILS=(SELECT EMAIL FROM VT_CORP_USUARIO WHERE NOMBREUSUARIO=P_USUARIO) WHERE ID=V_ID;

                -- Log
                SP_LOG('SP_AGRUPA_PRODUCTOS_BORRADOR', 'INSERTA ID='||V_ID||' CANTIDAD='||AGRUPADO.CANTIDAD||' TIPO='||AGRUPADO.DOCUMENTOTIPO||' CODIGOCORTOPRODUCTO='||AGRUPADO.CODIGOCORTOPRODUCTO||' BODEGA='||AGRUPADO.BODEGA);
            ELSE
                -- YA EXISTE. Debo conocer la cantidad con la que existe.
                SELECT ID,   CANTIDAD,   CANTIDAD_MANUAL
                INTO   V_ID, V_CANTIDAD, V_CANTIDAD_MANUAL
                FROM   T_COMP_PRODTO_PROVEEDR_GESTION PPGESTION
                WHERE  PPGESTION.TIPO_REQUISICION    = AGRUPADO.DOCUMENTOTIPO
                            AND
                       PPGESTION.CODIGOCORTOPRODUCTO = AGRUPADO.CODIGOCORTOPRODUCTO
                            AND
                       PPGESTION.BODEGA    = AGRUPADO.BODEGA
                            AND
                       PPGESTION.COMPANIA  = P_COMPANIA
                            AND
                       PPGESTION.USUARIO   = P_USUARIO
                            AND
                       PPGESTION.FECHA_PROCESADO IS NULL;

                -- OJO: Borro la negociación que tenga cuando la nueva cantidad sea diferente a la anterior cantidad
                IF NVL(V_CANTIDAD_MANUAL, V_CANTIDAD) <> AGRUPADO.CANTIDAD THEN
                    -- La cantidad es diferente, se debe borrar la negociación
                    SP_DEL_PPGESTION_NEGOCIACION(V_ID);
                    UPDATE T_COMP_PRODTO_PROVEEDR_GESTION GESTION
                    SET
                        GESTION.FECHA_REGISTRO          = SYSDATE,
                        GESTION.CANTIDAD                = AGRUPADO.CANTIDAD
                    WHERE ID=V_ID;
                    -- Log
                    SP_LOG('SP_AGRUPA_PRODUCTOS_BORRADOR', 'AGRUPA ID='||V_ID||' CANTIDAD='||AGRUPADO.CANTIDAD||AGRUPADO.DOCUMENTOTIPO||' CODIGOCORTOPRODUCTO='||AGRUPADO.CODIGOCORTOPRODUCTO||' BODEGA='||AGRUPADO.BODEGA);
                    -- Le intento poner una negociación por default
                    SP_COLOCA_NEGOCIACION_DEFAULT(V_ID, AGRUPADO.CODIGOCORTOPRODUCTO, AGRUPADO.CANTIDAD );
                END IF;
            END IF;

            -- Lo ato al T_COMP_F4311_GESTION
            UPDATE T_COMP_F4311_GESTION SET ID_PPGESTION = V_ID
            WHERE COMPANIA=P_COMPANIA AND DOCUMENTOTIPO=AGRUPADO.DOCUMENTOTIPO AND CODIGOCORTOPRODUCTO=AGRUPADO.CODIGOCORTOPRODUCTO AND TRIM(BODEGA) = TRIM(AGRUPADO.BODEGA)
                        AND
                  USUARIO=P_USUARIO AND FECHA_PROCESADO IS NULL;

            -- Agrupo los comentarios
            SP_AGRUPA_COMENTARIOS(V_ID);

        END LOOP;

    END;

	/*
	** Propósito:	Toma los comentarios de las requisiciones y los agrupa en
    **  la línea de getión para posterior edición por parte del usuario.
    **
	** Parámetros:
    **  P_PPGESTIONID NUMBER: Entrada. Para buscar en T_COMP_F4311_GESTION
    **                        los comprobantes de donde tomar los comentarios.
	*/
    PROCEDURE SP_AGRUPA_COMENTARIOS(P_PPGESTIONID NUMBER)
    AS
        V_COMENTARIOS_PROVEEDOR CLOB := '';
        V_COMENTARIOS_APROBADOR CLOB := '';
    BEGIN
        FOR LINEA IN (
            SELECT COMPANIA, DOCUMENTOTIPO, DOCUMENTO, LINEA FROM T_COMP_F4311_GESTION WHERE ID_PPGESTION = P_PPGESTIONID
        )
        LOOP
            V_COMENTARIOS_PROVEEDOR := V_COMENTARIOS_PROVEEDOR||PK_COMP_ORDENESCOMPRA.F_COMENTARIO@JDEDTADL(
                p_compania    => LINEA.COMPANIA,
                p_tipooc      => LINEA.DOCUMENTOTIPO,
                p_ordencompra => LINEA.DOCUMENTO,
                p_tipo        => 'P',
                p_linea       => LINEA.LINEA
            );
            V_COMENTARIOS_APROBADOR := V_COMENTARIOS_APROBADOR||PK_COMP_ORDENESCOMPRA.F_COMENTARIO@JDEDTADL(
                p_compania    => LINEA.COMPANIA,
                p_tipooc      => LINEA.DOCUMENTOTIPO,
                p_ordencompra => LINEA.DOCUMENTO,
                p_tipo        => 'A',
                p_linea       => LINEA.LINEA
            );
        END LOOP;

        UPDATE T_COMP_PRODTO_PROVEEDR_GESTION
        SET
            COMENTARIO_PROVEEDOR = DBMS_LOB.SUBSTR(V_COMENTARIOS_PROVEEDOR, 1500, 1),
            COMENTARIO_APROBADOR = DBMS_LOB.SUBSTR(V_COMENTARIOS_APROBADOR, 4000, 1)
        WHERE ID = P_PPGESTIONID;
    END;

	/*
	** Propósito:	Agrega todos los H2 para gestionarlos de uno en uno.
    **  Genera una relación UNO a UNO entre T_COMP_F4311_GESTION y T_COMP_PRODTO_PROVEEDR_GESTION
	** Parámetros:
    **  P_USUARIO       VARCHAR2: Entrada. La persona que está gestionando la OC
	*/
    PROCEDURE SP_AGREGA_PPGESTION_H2 (P_USUARIO VARCHAR2, P_COMPANIA VARCHAR2)
    AS
        V_ID              NUMBER;
        V_BODEGATIPO      VARCHAR2(5);
        V_UNIDADMEDIDA    VARCHAR2(20);
        V_DESCRIPCION1    VARCHAR2(30);
        V_DESCRIPCION2    VARCHAR2(30);
    BEGIN
        -- AGREGO LOS PRODUCTOS SELECCIONADOS A LA GESTIÓN
        FOR ORIGEN IN (
            SELECT
                GESTION.ID                    AS ID,
                F4311.COMPANIA                AS COMPANIA,
                F4311.DOCUMENTOTIPO           AS DOCUMENTOTIPO,
                F4311.CODIGOCORTOPRODUCTO     AS CODIGOCORTOPRODUCTO,
                F4311.DESCRIPCION             AS DESCRIPCION,
                F4311.DESCRIPCION1            AS DESCRIPCION1,
                F4311.DESCRIPCION2            AS DESCRIPCION2,
                GESTION.BODEGA                AS BODEGA,
                F4311.CANTIDAD                AS CANTIDAD,
                F4311.REQUISITOR              AS REQUISITOR,
                F4311.DESTINO                 AS DESTINO
            FROM
                T_COMP_F4311_GESTION  GESTION,
                VT_COMP_F4311         F4311
            WHERE
                F4311.LINEA         = GESTION.LINEA
                    AND
                F4311.DOCUMENTOTIPO = GESTION.DOCUMENTOTIPO
                    AND
                F4311.DOCUMENTO     = GESTION.DOCUMENTO
                    AND
                F4311.COMPANIA      = P_COMPANIA
                    AND
                GESTION.USUARIO     = P_USUARIO
                    AND
                GESTION.ID_PPGESTION IS NULL
                    AND
                GESTION.FECHA_PROCESADO IS NULL
            ORDER BY F4311.LINEA
        )
        LOOP

            SELECT IMUOM3,         IMDSC1,         IMDSC2
            INTO   V_UNIDADMEDIDA, V_DESCRIPCION1, V_DESCRIPCION2
            FROM   F4101@JDEDTADL WHERE IMITM = ORIGEN.CODIGOCORTOPRODUCTO;
            SELECT MCSTYL INTO V_BODEGATIPO   FROM F0006@JDEDTADL WHERE TRIM(MCMCU) = TRIM (ORIGEN.BODEGA);

            -- Se inserta.
            PK_COMMONS.SP_SECUENCIA('T_COMP_PRODTO_PROVEEDR_GESTION', V_ID);
            INSERT INTO T_COMP_PRODTO_PROVEEDR_GESTION
                (ID, COMPANIA, USUARIO,
                CODIGOCORTOPRODUCTO, UNIDADMEDIDA, TIPO_REQUISICION, BODEGA, REQUISITOR, DESTINO,
                CON_REQUISICION, BODEGATIPO, CANTIDAD, DESCRIPCION1, DESCRIPCION2,  RESERVA,
                FECHA_COMPROMISO, FECHA_REGISTRO)
            VALUES
                (V_ID, ORIGEN.COMPANIA, P_USUARIO,
                ORIGEN.CODIGOCORTOPRODUCTO, V_UNIDADMEDIDA, ORIGEN.DOCUMENTOTIPO, ORIGEN.BODEGA, ORIGEN.REQUISITOR, ORIGEN.DESTINO,
                1, V_BODEGATIPO, ORIGEN.CANTIDAD, SUBSTR(ORIGEN.DESCRIPCION1, 0, 30), SUBSTR(ORIGEN.DESCRIPCION2, 0, 30), 0,
                SYSDATE+1, SYSDATE);

            -- Lo ato al T_COMP_F4311_GESTION
            UPDATE T_COMP_F4311_GESTION SET ID_PPGESTION = V_ID WHERE ID = ORIGEN.ID;

            -- Agrupo los comentarios
            SP_AGRUPA_COMENTARIOS(V_ID);

            -- Pre-establezco el email
            UPDATE T_COMP_PRODTO_PROVEEDR_GESTION SET EMAILS=(SELECT EMAIL FROM VT_CORP_USUARIO WHERE NOMBREUSUARIO=P_USUARIO) WHERE ID=V_ID;

            -- Log
            SP_LOG('SP_AGREGA_H2_BORRADOR', 'ID='||V_ID||' TIPO='||ORIGEN.DOCUMENTOTIPO||' CODIGOCORTOPRODUCTO='||ORIGEN.CODIGOCORTOPRODUCTO||' BODEGA='||ORIGEN.BODEGA);

        END LOOP;
    END;

	/*
	** Propósito: Elimina una gestión H2.
    **   Elimina en dos tablas T_COMP_F4311_GESTION y T_COMP_PRODTO_PROVEEDR_GESTION
	** Parámetros:
    **  P_PPGESTIONID     NUMBER: Entrada. ID que vamos a eliminar.
	*/
    PROCEDURE SP_ELIMINA_PPGESTION_H2   (P_PPGESTIONID NUMBER)
    AS
    BEGIN
        DELETE FROM T_COMP_PRODTO_PROVEEDR_GESTION WHERE ID = P_PPGESTIONID;
        DELETE FROM T_COMP_F4311_GESTION           WHERE ID_PPGESTION = P_PPGESTIONID;

        -- LOG
        SP_LOG('SP_ELIMINA_PPGESTION_H2', 'P_PPGESTIONID='||P_PPGESTIONID);
    END;

	/*
	** Propósito:	Elimina toda la gestión H2.
	** Parámetros:
    **  P_USUARIO       VARCHAR2: Entrada. La persona que está gestionando la OC
	*/
    PROCEDURE SP_ELIMINA_ITEMS_H2 (P_USUARIO VARCHAR2, P_COMPANIA VARCHAR2)
    AS
    BEGIN
        FOR PPGESTION IN (
            SELECT ID
            FROM T_COMP_PRODTO_PROVEEDR_GESTION
            WHERE
                COMPANIA     = P_COMPANIA
                    AND
                USUARIO      = P_USUARIO
                    AND
                FECHA_PROCESADO IS NULL
        )
        LOOP
            SP_ELIMINA_PPGESTION_H2(PPGESTION.ID);
        END LOOP;

        SP_LOG('SP_ELIMINA_ITEMS_H2', P_USUARIO);
    END;

	/*
	** Propósito: Establece la negociación a un grupo de PPGESTION para un determinado producto.
	** Parámetros:
    **  P_CODIGOCORTOPRODUCTO NUMBER: Producto que vamos a buscar en VT_COMP_PENDIENTE_GENERAR_OC.
    **  P_DET_ID              NUMBER: Negociación seleccionada.
	*/
    PROCEDURE SP_SET_GRUPO_PPGESTION_NEGCION (P_CODIGOCORTOPRODUCTO NUMBER, P_DET_ID NUMBER, P_USUARIO VARCHAR2, P_COMPANIA VARCHAR2)
    AS
    BEGIN
        -- Log de lo que he recibido
        SP_LOG('SP_SET_PPGESTION_NEG_GRUPO', 'Inicio CODIGOCORTOPRODUCTO='||P_CODIGOCORTOPRODUCTO||' DET_ID='||P_DET_ID);

        FOR ORG IN (
            SELECT
                ID
            FROM
                VT_COMP_PENDIENTE_GENERAR_OC
            WHERE
                COMPANIA      = P_COMPANIA
                    AND
                USUARIO       = P_USUARIO
                    AND
                FECHA_PROCESADO IS NULL
                    AND
                CODIGOCORTOPRODUCTO = P_CODIGOCORTOPRODUCTO
        )
        LOOP
            SP_SET_PPGESTION_NEGOCIACION(ORG.ID, P_DET_ID);
        END LOOP;
    END;

	/*
	** Propósito: Elimina la negociación a un grupo de PPGESTION para un determinado producto.
	** Parámetros:
    **  P_CODIGOCORTOPRODUCTO NUMBER: Producto que vamos a buscar en VT_COMP_PENDIENTE_GENERAR_OC.
	*/
    PROCEDURE SP_DEL_GRUPO_PPGESTION_NEGCION (P_CODIGOCORTOPRODUCTO NUMBER, P_USUARIO VARCHAR2, P_COMPANIA VARCHAR2)
    AS
    BEGIN
        -- Log de lo que he recibido
        SP_LOG('SP_DEL_GRUPO_PPGESTION_NEGCION', 'Inicio CODIGOCORTOPRODUCTO='||P_CODIGOCORTOPRODUCTO);

        FOR ORG IN (
            SELECT
                ID
            FROM
                VT_COMP_PENDIENTE_GENERAR_OC
            WHERE
                COMPANIA      = P_COMPANIA
                    AND
                USUARIO       = P_USUARIO
                    AND
                FECHA_PROCESADO IS NULL
                    AND
                CODIGOCORTOPRODUCTO = P_CODIGOCORTOPRODUCTO
        )
        LOOP
            SP_DEL_PPGESTION_NEGOCIACION(ORG.ID);
        END LOOP;
    END;

	/*
	** Propósito: Establece la negociación en un producto seleccionado PPGESTION
	** Parámetros:
    **  P_PPGESTIONID NUMBER: Gestión de producto proveedor a ser establecida T_COMP_PRODTO_PROVEEDR_GESTION.
    **  P_DET_ID      NUMBER: Negociación seleccionada.
	*/
    PROCEDURE SP_SET_PPGESTION_NEGOCIACION (P_PPGESTIONID NUMBER, P_DET_ID NUMBER)
    AS
        V_PRECIO              NUMBER;
        V_VERSION             VARCHAR2(10);
        V_TIPO_OC             VARCHAR2(10);
        V_TIPO_REQUISICION    VARCHAR2(5);
        V_BODEGATIPO          VARCHAR2(10);
        V_CODIGOCORTOPRODUCTO VARCHAR2(10);
        V_CODPROVEEDOR        NUMBER;
        V_PROVEEDORTIPO       VARCHAR2(10);
        V_PRODUCTOTIPO        VARCHAR2(10);
        V_CODPRODUCTOPRV      VARCHAR2(50);
        V_TIEMPOENTREGA       NUMBER;
        V_FORMAPAGO           VARCHAR2(10);
        V_INCOTERM            VARCHAR2(10);
        V_MODO_AGRUPADO       VARCHAR2(40);
        V_FECHA_COMPROMISO    DATE;
    BEGIN
        -- Info de la gestión
        SELECT TIPO_REQUISICION,   BODEGATIPO,   CODIGOCORTOPRODUCTO,   MODO_AGRUPADO
        INTO   V_TIPO_REQUISICION, V_BODEGATIPO, V_CODIGOCORTOPRODUCTO, V_MODO_AGRUPADO
        FROM   T_COMP_PRODTO_PROVEEDR_GESTION
        WHERE  ID = P_PPGESTIONID;

        -- Info de la negociación.
        SELECT DET_PRECIO, DET_CODPROVEEDOR, DET_CODPRODUCTOPRV, DET_TIEMPOENTREGA, DET_FORMAPAGO, DET_INCOTERM
        INTO   V_PRECIO,   V_CODPROVEEDOR,   V_CODPRODUCTOPRV,   V_TIEMPOENTREGA,   V_FORMAPAGO,   V_INCOTERM
        FROM   vt_comp_negociacionsel
        WHERE  DET_ID = P_DET_ID;

        -- Fecha de compromiso
        V_FECHA_COMPROMISO := NVL(V_TIEMPOENTREGA, 1) + SYSDATE;

        -- Tipo de proveedor
        SELECT TIPO
        INTO   V_PROVEEDORTIPO
        FROM   vt_jde_maestroproveedor
        WHERE  codigoproveedor=V_CODPROVEEDOR;

        -- Tipo de producto
        SELECT IMGLPT
        INTO   V_PRODUCTOTIPO
        FROM   F4101@JDEDTADL
        WHERE  IMITM=V_CODIGOCORTOPRODUCTO;

        -- Determino la vesión para JDE
        SP_CONSULTA_VERSION(V_PRODUCTOTIPO, V_PROVEEDORTIPO, V_VERSION, V_TIPO_OC);

        -- Establece la negociación seleccionada
        UPDATE
            T_COMP_PRODTO_PROVEEDR_GESTION  GESTION
        SET
            GESTION.DET_ID                  = P_DET_ID,
            GESTION.CODIGOPRODUCTOPROVEEDOR = V_CODPRODUCTOPRV,
            GESTION.FORMAPAGO               = NVL(V_FORMAPAGO, '---'),
            GESTION.INCOTERM                = NVL(V_INCOTERM,  '---'),
            GESTION.PROVEEDORTIPO           = V_PROVEEDORTIPO,
            GESTION.PRODUCTOTIPO            = V_PRODUCTOTIPO,
            GESTION.PRECIOUNITARIO          = V_PRECIO,
            GESTION.VERSION                 = V_VERSION,
            GESTION.TIPO_OC                 = V_TIPO_OC,

            GESTION.FECHA_COMPROMISO        = V_FECHA_COMPROMISO,
            GESTION.MODO_AGRUPADO           = DECODE(V_MODO_AGRUPADO, NULL, NULL, TO_CHAR(V_FECHA_COMPROMISO, 'YYYY/MM/DD')),

            GESTION.FECHA_REG_NEGOCIACION   = SYSDATE
        WHERE
            ID = P_PPGESTIONID;

        SP_LOG('SP_SET_PPGESTION_NEGOCIACION', 'ID='||P_PPGESTIONID||' DET_ID='||P_DET_ID||' PRECIO='||V_PRECIO||' VERSION='||V_VERSION||' FORMAPAGO='||V_FORMAPAGO||' INCOTERM='||V_INCOTERM||' PROVEEDORTIPO='||V_PROVEEDORTIPO);
    END;

	/*
	** Propósito: Elimina la negociación en un producto seleccionado PPGESTION
	** Parámetros:
    **  P_PPGESTIONID     NUMBER: Entrada. PPGESTION que vamos a afectar.
	*/
    PROCEDURE SP_DEL_PPGESTION_NEGOCIACION (P_PPGESTIONID NUMBER)
    AS
    BEGIN
        UPDATE
            T_COMP_PRODTO_PROVEEDR_GESTION GESTION
        SET
            GESTION.DET_ID                  = NULL,
            GESTION.CODIGOPRODUCTOPROVEEDOR = NULL,
            GESTION.PROVEEDORTIPO           = NULL,
            GESTION.PRECIOUNITARIO          = NULL,
            GESTION.VERSION                 = NULL,
            GESTION.FECHA_REG_NEGOCIACION   = NULL
        WHERE
            ID = P_PPGESTIONID;

        SP_LOG('SP_DEL_PPGESTION_NEGOCIACION', 'ID='||P_PPGESTIONID);
    END;

	/*
	** Propósito: Pone la cantidad (ingresada a mano), los emails y la fecha compromiso en un producto seleccionado PPGESTION
	** Parámetros:
    **  P_PPGESTIONID  NUMBER: Entrada. PPGESTION que vamos a afectar.
    **  P_CANTIDAD     NUMBER: Entrada. Cantidad que vamos a establecer.
    **  P_EMAILS       VARCHAR: Entrada. Emails que vamos a establecer.
    **  P_FECHA_COMPROMISO DATE: Entrada. Fecha compromiso que vamos a establecer.
    **  P_MODO_AGRUPADO    NUMBER : Si es 1 se debe forzar a colocar el AGRUPADOR
	*/
    procedure sp_set_ppgestion_cant_emails (
		p_ppgestionid number
		, p_cantidad_manual number
		, p_justificacion varchar2
		, p_emails varchar2
		, p_fecha_compromiso date
		, p_modo_agrupado number
	) as
        v_cantsolicita        number;
        v_cantordenada_org    number;
        v_cantidad            number;
    begin
        v_cantidad := p_cantidad_manual;

        select cantsolicita, cantordenada
        into   v_cantsolicita, v_cantordenada_org
        from   data.t_comp_ordencompraextdet
        where  id = p_ppgestionid;

        update data.t_comp_ordencompraextdet
        set    cantordenada = v_cantidad,
               fechacomp    = p_fecha_compromiso,
               obscantidad  = p_justificacion
        where  id = p_ppgestionid;

        if nvl(v_cantidad, v_cantsolicita) <> nvl(v_cantordenada_org, v_cantsolicita) then
            sp_del_ppgestion_negociacion(p_ppgestionid);
        end if;
    end sp_set_ppgestion_cant_emails;

	procedure sp_establece_parametros (
		p_compania				varchar2
		, p_opcion				varchar2
		, p_proceso				number
		, valor1				varchar2 default null
		, valor2				varchar2 default null
		, valor3				varchar2 default null
		, valor4				varchar2 default null
		, valor5				varchar2 default null
		, p_respuesta			out number
	) as
	begin
		null;
	end sp_establece_parametros;

	/*
	** Propósito: Actualiza los comentarios de proveedor y aprobador en T_COMP_ORDENCOMPRAEXTDET.
	** Parámetros:
    */
    PROCEDURE SP_SET_PPGESTION_COMENTARIOS (P_PPGESTIONID NUMBER, P_COMENTARIO_PROVEEDOR VARCHAR2, P_COMENTARIO_APROBADOR CLOB)
    AS
    BEGIN
        UPDATE data.t_comp_ordencompraextdet
        SET
            obsproveedor = P_COMENTARIO_PROVEEDOR,
            obsaprobador = P_COMENTARIO_APROBADOR
        WHERE ID = P_PPGESTIONID;
    END;

	/*
	** Propósito: Establece los valores ingresados manualmente para una PPGESTION
	** Parámetros:
    **  P_PPGESTIONID      NUMBER:   Entrada. PPGESTION que vamos a afectar.
    **  P_CODPROVEEDOR     NUMBER:   Entrada. AN8 del proveedor.
    **  P_CANTIDAD         NUMBER:   Entrada. Cantidad que vamos a establecer.
    **  P_JUSTIFICACION    VARCHAR2: Entrada. Justificación cuando se cambia la cantidad.
    **  P_FECHA_COMPROMISO DATE:     Entrada. Fecha compromiso que vamos a establecer.
    **  P_PRECIO_UNITARIO  NUMBER:   Entrada. Precio al que se va a comprar.
    **  P_DESCRIPCION1     VARCHAR2: Entrada. Se coloca en la línea de la OC. Máximo 30 caracteres.
    **  P_DESCRIPCION2     VARCHAR2: Entrada. Se coloca en la línea de la OC. Máximo 30 caracteres.
	*/

	procedure sp_set_ppgestion_detalles (
		p_ppgestionid			number
		, p_codproveedor		number
		, p_cantidad_manual		number
		, p_justificacion		varchar2
		, p_fecha_compromiso	date
		, p_precio_unitario		number
		, p_descripcion1		varchar2
		, p_descripcion2		varchar2
	) as
	v_version             varchar2(10);
	v_tipo_oc             varchar2(10);
	v_tipo_requisicion    varchar2(5);
	v_bodegatipo          varchar2(10);
	v_codigocortoproducto varchar2(10);
	v_proveedortipo       varchar2(10);
	v_productotipo        varchar2(10);
	v_cantidad_org        number;
	v_cantidad_manual_org number;
	v_cantidad            number;
	v_con_requisicion     number;
    begin
        -- Log de lo que llega
        SP_LOG('SP_SET_PPGESTION_DETALLES', 'ID='||P_PPGESTIONID||' PROVEEDOR='||P_CODPROVEEDOR||' CANTIDAD_MANUAL='||P_CANTIDAD_MANUAL||' FECHA_COMPROMISO='||P_FECHA_COMPROMISO||' PRECIO_UNITARIO='||P_PRECIO_UNITARIO);

        V_CANTIDAD := P_CANTIDAD_MANUAL;

        -- Info de la gestión
        select tipo_requisicion,   bodegatipo,   codigocortoproducto
        into   v_tipo_requisicion, v_bodegatipo, v_codigocortoproducto
        from   t_comp_prodto_proveedr_gestion
        where  id = p_ppgestionid;

        -- Tipo de proveedor
        select tipo
        into   v_proveedortipo
        from   vt_jde_maestroproveedor
        where  codigoproveedor = p_codproveedor;


        -- Tipo de producto
        select imglpt
        into   v_productotipo
        from   f4101@jdedtadl
        where  imitm = v_codigocortoproducto;

        -- Determino la vesión para JDE
        SP_CONSULTA_VERSION(V_PRODUCTOTIPO, V_PROVEEDORTIPO, V_VERSION, V_TIPO_OC);

        -- Recupero la cantidad orginal y la cantidad manual
        select cantidad,       cantidad_manual,       con_requisicion
        into   v_cantidad_org, v_cantidad_manual_org, v_con_requisicion
        from   t_comp_prodto_proveedr_gestion
        where  id = p_ppgestionid;

        -- Si la cantidad manual es la misma que la requerida, entonces no hay cantidad manual.
        IF V_CANTIDAD = V_CANTIDAD_ORG THEN
            V_CANTIDAD := NULL;
        END IF;

        -- Establece los cambios
        UPDATE
            T_COMP_PRODTO_PROVEEDR_GESTION  GESTION
        SET
            GESTION.CODPROVEEDOR          = P_CODPROVEEDOR,
            GESTION.PROVEEDORTIPO         = V_PROVEEDORTIPO,
            GESTION.PRODUCTOTIPO          = V_PRODUCTOTIPO,
            GESTION.PRECIOUNITARIO        = P_PRECIO_UNITARIO,
            GESTION.VERSION               = V_VERSION,
            GESTION.TIPO_OC               = V_TIPO_OC,
            GESTION.FECHA_REG_NEGOCIACION = SYSDATE,

            GESTION.CANTIDAD_MANUAL       = V_CANTIDAD,
            GESTION.JUSTIFICACION         = P_JUSTIFICACION,
            GESTION.FECHA_COMPROMISO      = P_FECHA_COMPROMISO,

            GESTION.DESCRIPCION1          = P_DESCRIPCION1,
            GESTION.DESCRIPCION2          = P_DESCRIPCION2
        WHERE
            ID = P_PPGESTIONID;

        -- En caso de compras sin requisición la cantidad manual es la misma que la requerida.
        IF V_CON_REQUISICION=0 THEN
            UPDATE
                T_COMP_PRODTO_PROVEEDR_GESTION
            SET
                CANTIDAD         = P_CANTIDAD_MANUAL,
                CANTIDAD_MANUAL  = P_CANTIDAD_MANUAL,
                FECHA_COMPROMISO = P_FECHA_COMPROMISO
            WHERE
                ID = P_PPGESTIONID;
        END IF;

        SP_LOG('SP_SET_PPGESTION_DETALLES', 'ID='||P_PPGESTIONID||' CON_REQUISICION='||V_CON_REQUISICION||' PROVEEDORTIPO='||V_PROVEEDORTIPO||' PRODUCTOTIPO='||V_PRODUCTOTIPO||' VERSION='||V_VERSION);
    END;


	/*
	** Propósito: Agrega un nuevo producto para comprar sin requisición PPGESTION
	** Parámetros:
    **  P_TIPO_REQUISICION     VARCHAR: Entrada. H1, H2, H3
    **  P_CODIGOCORTOPRODUCTO  NUMBER:  Entrada. Producto seleccionado.
    **  P_BODEGA               VARCHAR: Entrada. Bodega que hace la requisisción.
    **  P_CANTIDAD             NUMBER:  Entrada. Cantidad que vamos a establecer.
    **  P_DUPLICADO            NUMBER:  Entrada. 1=Permite duplicar el CODIGOCORTOPRODUCTO. 0=NO permite
    **  P_USUARIO              VARCHAR: Entrada. Usuario comprador.
    **
    **  P_ID                   NUMBER:  Salida. ID del registro generado
	*/
    PROCEDURE SP_AGREGAR_SIN_REQUISICION (P_TIPO_REQUISICION VARCHAR2, P_CODIGOCORTOPRODUCTO NUMBER, P_BODEGA VARCHAR, P_CANTIDAD NUMBER, P_DUPLICADO NUMBER, P_USUARIO VARCHAR2, P_COMPANIA VARCHAR2,
              P_ID OUT NUMBER)
    AS
        V_COUNT        NUMBER;
        V_UNIDADMEDIDA VARCHAR2(20);
        V_BODEGATIPO   VARCHAR2(5);
    BEGIN
        -- Log de lo que he recibido
        SP_LOG('SP_AGREGAR_SIN_REQUISICION', 'Inicio TIPO='||P_TIPO_REQUISICION||' CODIGOCORTOPRODUCTO='||P_CODIGOCORTOPRODUCTO||' BODEGA='||P_BODEGA||' CANTIDAD='||P_CANTIDAD);

        IF P_TIPO_REQUISICION IS NULL THEN
            raise_application_error(-20000, 'En "Buscar Requisiciones" debe seleccionar el tipo de requisición.');
        END IF;

        -- Verifico si ya existe
        IF P_DUPLICADO = 1 THEN
            V_COUNT := 0;
        ELSE
            SELECT COUNT(1)
            INTO   V_COUNT
            FROM   T_COMP_PRODTO_PROVEEDR_GESTION
            WHERE
                TIPO_REQUISICION    = P_TIPO_REQUISICION
                    AND
                TRIM(BODEGA)        = TRIM(P_BODEGA)
                    AND
                CODIGOCORTOPRODUCTO = P_CODIGOCORTOPRODUCTO
                    AND
                USUARIO             = P_USUARIO
                    AND
                COMPANIA            = P_COMPANIA
                    AND
                FECHA_PROCESADO     IS NULL;      -- Pendiente de generar OC
        END IF;

        IF V_COUNT = 0 THEN
            -- Completo la información
            SELECT IMUOM3 INTO V_UNIDADMEDIDA FROM F4101@JDEDTADL WHERE IMITM       = P_CODIGOCORTOPRODUCTO;
            SELECT MCSTYL INTO V_BODEGATIPO   FROM F0006@JDEDTADL WHERE TRIM(MCMCU) = TRIM (P_BODEGA);

            -- Se inserta.
            PK_COMMONS.SP_SECUENCIA('T_COMP_PRODTO_PROVEEDR_GESTION', P_ID);
            INSERT INTO T_COMP_PRODTO_PROVEEDR_GESTION
                (ID, COMPANIA, USUARIO,
                CODIGOCORTOPRODUCTO, UNIDADMEDIDA, TIPO_REQUISICION, BODEGA,
                CON_REQUISICION, BODEGATIPO, CANTIDAD, CANTIDAD_MANUAL, RESERVA, FECHA_REGISTRO)
            VALUES
                (P_ID, P_COMPANIA, P_USUARIO,
                P_CODIGOCORTOPRODUCTO, V_UNIDADMEDIDA, P_TIPO_REQUISICION, P_BODEGA,
                0, V_BODEGATIPO, P_CANTIDAD, P_CANTIDAD, 0, SYSDATE);

            -- LOG del insertado
            SP_LOG('SP_AGREGAR_SIN_REQUISICION', 'Insertado ID='||P_ID);
        ELSE
            -- No se puede duplicar
            SP_LOG('SP_AGREGAR_SIN_REQUISICION', 'ERROR ya existe');
            raise_application_error(-20000, 'Ya existe este producto. Cambie la cantidad del existente.');
        END IF;
    END;


	/*
	** Propósito: Elimina un producto sin requisición
	** Parámetros:
    **  P_PPGESTIONID     NUMBER: Entrada. PPGESTION que vamos a eliminar.
	*/
    PROCEDURE SP_ELIMINA_SIN_REQUISICION   (P_PPGESTIONID NUMBER)
    AS
    BEGIN
        DELETE FROM T_COMP_PRODTO_PROVEEDR_GESTION WHERE ID = P_PPGESTIONID;

        -- LOG
        SP_LOG('SP_ELIMINA_SIN_REQUISICION', 'P_PPGESTIONID='||P_PPGESTIONID);
    END;

	/*
	** Propósito: Intercambia el campo RESERVA entre 0 y 1
	** Parámetros:
    **  P_PPGESTIONID     NUMBER: Entrada. PPGESTION que vamos a swithear.
	*/
        PROCEDURE SP_SWITCH_RESERVA            (P_PPGESTIONID NUMBER)
    AS
        V_CODIGOCORTOPRODUCTO NUMBER;
        V_CANTIDAD            NUMBER;
        V_RESERVA             NUMBER;
        V_DET_ID              NUMBER;
    BEGIN
        -- Hago el cambio
        UPDATE T_COMP_PRODTO_PROVEEDR_GESTION
        SET RESERVA = (RESERVA*-1)+1
        WHERE ID=P_PPGESTIONID;

        -- Recupero información para intentar poner una negociación
        SELECT CODIGOCORTOPRODUCTO,   NVL(CANTIDAD_MANUAL, CANTIDAD), RESERVA,   DET_ID
        INTO   V_CODIGOCORTOPRODUCTO, V_CANTIDAD,                     V_RESERVA, V_DET_ID
        FROM   T_COMP_PRODTO_PROVEEDR_GESTION
        WHERE  ID=P_PPGESTIONID;

        -- Mando a poner negociación solo si es de reserva y no tiene una negociación
        IF V_RESERVA=1 AND V_DET_ID IS NULL THEN
            SP_COLOCA_NEGOCIACION_DEFAULT(P_PPGESTIONID,  V_CODIGOCORTOPRODUCTO, V_CANTIDAD);
        END IF;
        SP_LOG('SP_SWITCH_RESERVA', 'PPGESTIONID='||P_PPGESTIONID||' RESERVA='||V_RESERVA||' DET_ID='||V_DET_ID||' CODIGOCORTOPRODUCTO='||V_CODIGOCORTOPRODUCTO||' CANTIDAD='||V_CANTIDAD);
    END;

	/*
	** Propósito: Consulta en T_CORP_UDC la versión que se debe usar en base a:
    **  tipo de producto y el tipo de proveedor
	** Parámetros:
    **  P_TIPO_PRODUCTO  VARCHAR2: Entrada. IN10, IN13, IN40
    **  P_TIPO_PROVEEDOR VARCHAR2: Entrada. PEXR, PEXT, PLOC, PLOR
    **
    **  P_VERSION        VARCHAR2: Salida. La versión que corresponde o null si no se encuentra: ERP004, ERP0046
    **  P_TIPO_DOC       VARCHAR2: BN, BM, CN, CM. Se usa para determinar por adelantado la ruta de aprobación de la OC: T_ADMI_RUTA.TIPO2
	*/
    procedure sp_consulta_version (p_tipo_producto varchar2, p_tipo_proveedor varchar2, p_version out varchar2, p_tipo_doc out varchar2) as
    begin
		v_log_app := 'pk_comp_gestioncompras.sp_consulta_version';
		v_log_dsc := 'Parámetros: p_tipo_producto: '||p_tipo_producto||', p_tipo_proveedor: '||p_tipo_proveedor;

        p_version := null; p_tipo_doc := null;

        begin   -- Aquí se debe mejorar para comprar todos los servicios
			select trim(valor), trim(valor2)
			into   p_tipo_doc, p_version
			from   t_corp_udc
			where 1 = 1
				and activo = '1'
				and trim(id_cabecera) = 'VERSION_OC'
				and id_tabla = trim(p_tipo_producto)||'-'||trim(p_tipo_proveedor);
			v_log_msg := '(query)';

            exception when others then
				if substr(trim(p_tipo_producto),1,1) = 'S' then
					-- Servicios
					if trim(p_tipo_proveedor) = 'PLOC' or trim(p_tipo_proveedor) = 'PLOR' then
						p_version :='ERP0012'; p_tipo_doc:='CN';
					end if;

					if trim(p_tipo_proveedor) = 'PEXT' or trim(p_tipo_proveedor) = 'PEXR' then
						p_version :='ERP0024'; p_tipo_doc:='BN';
					end if; v_log_msg := '(servicios)';
				end if;

				if substr(trim(p_tipo_producto),1,2) = 'AT' then
					-- Activos Fijos
					if trim(p_tipo_proveedor) = 'PLOC' or trim(p_tipo_proveedor) = 'PLOR' then
						p_version :='ERP0046'; p_tipo_doc:='CN';
					end if;

					if trim(p_tipo_proveedor) = 'PEXT' or trim(p_tipo_proveedor) = 'PEXR' then
						p_version :='ERP0024'; p_tipo_doc:='BN';
					end if; v_log_msg := '(activos)';
				end if;
		end;
		v_log_obs := 'p_tipo_doc: '||p_tipo_doc||', p_version: '||p_version;
		data.pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,v_log_obs,null);
	end sp_consulta_version;

	/*
	** Propósito: Invoca los WSs para la generación de las OCs por tipo, bodeega y proveedor.
	** Parámetros:
    **  P_TIPO           VARCHAR2: Entrada. H1, H2, H3
    **  P_CODBODEGAORG   VARCHAR2: Entrada. Código de la bodega ORIGEN
    **  P_CODBODEGADST   VARCHAR2: Entrada. Código de la bodega DESTINO
    **  P_CODPROVEEDOR   NUMBER:   Entrada. AN8 del proveedor.
    **  P_RESERVA        NUMBER:   1=Es una OC de reserva
    **  P_MODO_AGRUPADO  VARCHAR2: Entrada. Caso 28059. Se usa para agrupar las líneas OC por fecha compromiso.
    **
    **  P_USUARIO        VARCHAR2: Entrada. La persona que va a crear la OC
    **  P_COMPANIA       VARCHAR2: Entrada. Código de la empresa.
    **
    **  P_DOCUMENTOTIPO  VARCHAR2: Salida. Tipo de OC generada: CN, CM, BM, BN
    **  P_DOCUMENTO      VARCHAR2: Salida. Número de OC generada.
	*/
    PROCEDURE SP_GENERA_OC  (
                    P_TIPO VARCHAR2,
                    P_CODBODEGAORG VARCHAR2,
                    P_CODBODEGADST VARCHAR2,
                    P_CODPROVEEDOR NUMBER,
                    P_RESERVA NUMBER,
                    P_MODO_AGRUPADO VARCHAR2,

                    P_USUARIO VARCHAR2,
                    P_COMPANIA VARCHAR2,
                    ----------------------
                    P_DOCUMENTOTIPO_OC OUT VARCHAR2,  P_DOCUMENTO_OC OUT NUMBER)
    AS
        V_PASO             VARCHAR2(500) := 'INICIO';
        V_CODERP           NUMBER;
        V_LINEA            NUMBER        := 0;
        V_FECHAJDE         NUMBER;
        V_PRECIOUNITARIO   NUMBER;
        V_NOW              TIMESTAMP     := SYSDATE;
        V_DETALLE_TRUNC    VARCHAR2(2000);
    BEGIN
        P_DOCUMENTOTIPO_OC := NULL;
        P_DOCUMENTO_OC     := NULL;

        -- Log de lo que recibo
        SP_LOG('SP_GENERA_OC', 'Inicio TIPO="'||P_TIPO||'" BODEGA="'||P_CODBODEGAORG||'" PROVEEDOR='||P_CODPROVEEDOR||' RESERVA='||P_RESERVA||' AGRUPADO='||P_MODO_AGRUPADO||' USUARIO='||P_USUARIO||' COMP='||P_COMPANIA);

        -- A los productos en BORRADOR los agrupo por: tipo, bodega, proveedor para genera una OC por cada grupo.
        -- Genero una OC por cada uno de estos.
        FOR CABECERA IN(
            SELECT
                TIPO_REQUISICION               AS TIPO_REQUISICION,
                CODBODEGA                      AS CODBODEGA,
                CODPROVEEDOR                   AS CODPROVEEDOR,
                MODO_AGRUPADO                  AS MODO_AGRUPADO,

                VERSION                        AS VERSION,
                RESERVA                        AS RESERVA,
                FORMAPAGO                      AS FORMAPAGO,
                INCOTERM                       AS INCOTERM,

                SUM(ROUND(NVL(PRECIOTOTAL,4))) AS MONTO,
                COUNT(1)                       AS CANT_PROD,
                MAX(FECHA_COMPROMISO)          AS FECHA_COMPROMISO
            FROM
                VT_COMP_PENDIENTE_GENERAR_OC
            WHERE
                TIPO_REQUISICION = P_TIPO
                    AND
                TRIM(CODBODEGA)  = TRIM(P_CODBODEGAORG)
                    AND
                CODPROVEEDOR     = P_CODPROVEEDOR
                    AND
                RESERVA          = P_RESERVA
                    AND
                USUARIO          = P_USUARIO
                    AND
                COMPANIA         = P_COMPANIA
                    AND
                CODPROVEEDOR     IS NOT NULL   -- Tiene negociación
                    AND
                FECHA_COMPROMISO IS NOT NULL   -- Tiene fecha compromiso
                    AND
                FECHA_PROCESADO  IS NULL       -- Pendiente de generar OC
                    AND
                (P_MODO_AGRUPADO IS NULL OR MODO_AGRUPADO = P_MODO_AGRUPADO)
            GROUP BY
                COMPANIA,
                TIPO_REQUISICION,
                CODBODEGA,
                VERSION,
                CODPROVEEDOR,
                DET_CODPROVEEDOR,
                RESERVA,
                FORMAPAGO,
                INCOTERM,  -- GROUP
                MODO_AGRUPADO
        )
        LOOP
            -- Log de lo que voy a hacer
            SP_LOG('SP_GENERA_OC', 'Cabecera VERSION='||CABECERA.VERSION||' MONTO='||CABECERA.MONTO||' FECHA_COMPROMISO='||CABECERA.FECHA_COMPROMISO||' INCOTERM='||CABECERA.INCOTERM||' FORMAPAGO='||CABECERA.FORMAPAGO);

            BEGIN
                -- Recuppero el CODERP del comprador
                V_PASO := 'Recupera CODERP para '||P_USUARIO;
                SELECT CODERP INTO V_CODERP FROM VT_CORP_USUARIO WHERE NOMBREUSUARIO = P_USUARIO;

                EXCEPTION WHEN OTHERS THEN
                    SP_LOG('SP_GENERA_OC', 'ERROR '||V_PASO||' SQLCODE: '||SQLCODE||' SQLERRM: '||SQLERRM||' TRACE: '||DBMS_UTILITY.format_error_backtrace);
                    raise_application_error(-20000,'Al parecer no tiene AN8 '||P_USUARIO);
            END;

            -- Log de lo que voy a hacer
            SP_LOG('SP_GENERA_OC', 'sp_crearorden_cab compania='||p_compania||' VERSION='||CABECERA.VERSION||' CODBODEGAORG='||TRIM(P_CODBODEGAORG)||' CODERP='||V_CODERP||' CODBODEGADST='||TRIM(P_CODBODEGADST)||' CODPROVEEDOR='||P_CODPROVEEDOR||' FECHA_COMPROMISO='||CABECERA.FECHA_COMPROMISO);

            BEGIN
                -- Generación de la cabecera
                V_PASO := 'pk_jde_compras_ws.sp_crearorden_cab';
                pk_jde_compras_ws.sp_crearorden_cab(
                    p_compania,               -- compania
                    CABECERA.VERSION,         -- versión
                    TRIM(P_CODBODEGAORG),     -- bodega
                    V_CODERP,                 -- comprador AN8
                    TRIM(P_CODBODEGADST),     -- envia destino
                    P_CODPROVEEDOR,           -- proveedor
                    CABECERA.FECHA_COMPROMISO -- fecha prometida
                );

                -- A los productos en BORRADOR los busco por: tipo, bodega, proveedor para genera una LINEA por cada grupo.
                -- Generación de los detalles
                V_PASO := 'pk_jde_compras_ws.sp_crearorden_det';
                FOR DETALLE IN (
                    SELECT
                        ID,
                        TIPO_REQUISICION,
                        CON_REQUISICION,
                        NVL(CANTIDAD_MANUAL, CANTIDAD) AS CANTIDAD,
                        UNIDADMEDIDA,
                        FECHA_COMPROMISO,
                        NVL(PRECIOUNITARIOEXTERNO, PRECIOUNITARIO)  AS PRECIOUNITARIO,
                        PRECIOTOTAL,
                        CODIGOCORTOPRODUCTO
                    FROM
                        VT_COMP_PENDIENTE_GENERAR_OC
                    WHERE                -- COMPANIA, TIPO_REQUISICION, CODBODEGA, VERSION, CODPROVEEDOR, DET_CODPROVEEDOR, RESERVA, MODO_AGRUPADO, FORMAPAGO, INCOTERM  -- GROUP
                        COMPANIA         = P_COMPANIA
                            AND
                        TIPO_REQUISICION = P_TIPO
                            AND
                        TRIM(CODBODEGA)  = TRIM(P_CODBODEGAORG)
                            AND
                        CODPROVEEDOR     = P_CODPROVEEDOR
                            AND
                        RESERVA          = P_RESERVA
                            AND
                        (CABECERA.FORMAPAGO is null or FORMAPAGO = CABECERA.FORMAPAGO)
                            AND
                        (CABECERA.INCOTERM  is null or INCOTERM  = CABECERA.INCOTERM)
                            AND
                        USUARIO          = P_USUARIO
                            AND
                        CODPROVEEDOR     IS NOT NULL   -- Tiene negociación
                            AND
                        FECHA_COMPROMISO IS NOT NULL   -- Tiene fecha compromiso
                            AND
                        FECHA_PROCESADO  IS NULL       -- Pendiente de generar OC
                            AND
                        (P_MODO_AGRUPADO IS NULL OR MODO_AGRUPADO = P_MODO_AGRUPADO)
                    ORDER BY ID
                )
                LOOP
                    V_LINEA := V_LINEA+1;
                    V_PASO  := 'pk_jde_compras_ws.sp_crearorden_det ID='||DETALLE.ID||' LINEA='||V_LINEA;

                    -- El precio debe ser 0.0001 cuando es una OC de RESERVA CASO 27000
                    V_PRECIOUNITARIO := CASE
                                            WHEN CABECERA.RESERVA=0
                                                THEN DETALLE.PRECIOUNITARIO
                                                ELSE 0.0001
                                        END;
                    pk_jde_compras_ws.sp_crearorden_det(
                        p_compania,                  -- compania
                        DETALLE.CODIGOCORTOPRODUCTO, -- codigocorto del producto
                        DETALLE.CANTIDAD,            -- cantidad a comprar del producto
                        DETALLE.UNIDADMEDIDA,        -- unidad de medida
                        V_PRECIOUNITARIO,            -- precio unitario
                        NULL,                        -- reqnumero
                        NULL,                        -- reqtipo
                        V_CODERP,                    -- comprador AN8
                        V_LINEA                      -- linea: 1000, 2000, 3000
                    );
                    UPDATE T_COMP_PRODTO_PROVEEDR_GESTION SET LINEA = V_LINEA WHERE ID = DETALLE.ID;
                END LOOP; -- Generación de los detalles

                -- Hasta aqui se deja las líneas registradas
                COMMIT;

                -- FINALMENTE creación de la OC
                V_PASO := 'pk_jde_compras_ws.sp_crearorden';
                pk_jde_compras_ws.sp_crearorden();

                -- Recupero el resultado de JDE
                P_DOCUMENTOTIPO_OC	:= pk_jde_compras_ws.g_tipo;
                P_DOCUMENTO_OC	    := pk_jde_compras_ws.g_numero;
                SP_LOG( 'SP_GENERA_OC', V_PASO||' TIPO='||P_DOCUMENTOTIPO_OC||' DOCUMENTO='||P_DOCUMENTO_OC||' LINEA='||V_LINEA);

                EXCEPTION WHEN OTHERS THEN
                    SP_LOG('SP_GENERA_OC', 'ERROR '||V_PASO||' SQLCODE: '||SQLCODE||' SQLERRM: '||SQLERRM||' TRACE: '||DBMS_UTILITY.format_error_backtrace);
                    raise_application_error(-20000,'ERROR '||V_PASO||' '||SQLERRM||' '||DBMS_UTILITY.format_error_backtrace);
            END; -- Generación de la OC

            -- Control de error desde JDE
            IF P_DOCUMENTO_OC IS NULL OR P_DOCUMENTOTIPO_OC IS NULL THEN
                G_TRAMA := pk_jde_compras_ws.g_trama;
                SP_RECUPERA_ERROR_XML(pk_jde_compras_ws.g_trama, V_DETALLE_TRUNC);
                raise_application_error(-20000,'ERROR '||V_DETALLE_TRUNC);
            END IF;

            -- ACCIONES posterior a la generación
            BEGIN
                SP_POST_GENERA_OC(
                    P_TIPO,
                    P_CODBODEGAORG,
                    P_CODPROVEEDOR,
                    CABECERA.RESERVA,
                    CABECERA.MODO_AGRUPADO,
                    CABECERA.FORMAPAGO,
                    CABECERA.INCOTERM,
                    P_USUARIO,
                    P_COMPANIA,
                    V_NOW,
                    P_DOCUMENTOTIPO_OC,
                    P_DOCUMENTO_OC
                );
            EXCEPTION WHEN OTHERS THEN
                SP_LOG('SP_POST_GENERA_OC', 'ERROR SQLCODE: '||SQLCODE||' SQLERRM: '||SQLERRM||' TRACE: '||DBMS_UTILITY.format_error_backtrace);
                raise_application_error(-20000,'ERROR '||V_PASO||' '||SQLERRM||' '||DBMS_UTILITY.format_error_backtrace);
            END;

        END LOOP; -- LOOP COMPANIA, TIPO_REQUISICION, CODBODEGA, VERSION, CODPROVEEDOR, DET_CODPROVEEDOR, RESEVRA, FORMAPAGO, INCOTERM para genera una OC por cada grupo.

    END;

	/*
	** Propósito: Ejecuta varias acciones posteriores a la generación de la OC.
	** Parámetros:
    **  P_TIPO           VARCHAR2: Entrada. H1, H2, H3
    **  P_CODBODEGAORG   VARCHAR2: Entrada. Código de la bodega ORIGEN
    **  P_CODPROVEEDOR   NUMBER:   Entrada. AN8 del proveedor.
    **  P_RESERVA        NUMBER:   1=Es una OC de reserva
    **  P_MODO_AGRUPADO  VARCHAR2: Entrada. Caso 28059. Se usa para agrupar las líneas OC por fecha compromiso.
    **
    **  P_USUARIO        VARCHAR2: Entrada. La persona que va a crear la OC
    **  P_COMPANIA       VARCHAR2: Entrada. Código de la empresa.
    **
    **  P_DOCUMENTOTIPO  VARCHAR2: Salida. Tipo de OC generada: CN, CM, BM, BN
    **  P_DOCUMENTO      VARCHAR2: Salida. Número de OC generada.
	*/
    PROCEDURE SP_POST_GENERA_OC (
                       P_TIPO VARCHAR2,
                       P_CODBODEGAORG VARCHAR2,
                       P_CODPROVEEDOR NUMBER,
                       P_RESERVA NUMBER,
                       P_MODO_AGRUPADO  VARCHAR2,
                       P_FORMAPAGO VARCHAR2,
                       P_INCOTERM VARCHAR2,
                       P_USUARIO VARCHAR2,
                       P_COMPANIA VARCHAR2,
                       P_NOW TIMESTAMP,
                       P_DOCUMENTOTIPO_OC VARCHAR2,
                       P_DOCUMENTO_OC NUMBER)
    AS
        V_PASO             VARCHAR2(500) := 'SP_POST_GENERA_OC';
        V_FECHAJDE         NUMBER;
        V_RES_COPIA        NUMBER;
    BEGIN
        -- Log de lo que recibo
        SP_LOG('SP_POST_GENERA_OC', 'Inicio TIPO="'||P_TIPO||'" BODEGA="'||P_CODBODEGAORG||'" PROVEEDOR='||P_CODPROVEEDOR||' RESERVA='||P_RESERVA||' FORMAPAGO='||P_FORMAPAGO||' INCOTERM='||P_INCOTERM||' USUARIO='||P_USUARIO||' COMP='||P_COMPANIA||' NOW='||P_NOW||' DOCUMENTOTIPO_OC='||P_DOCUMENTOTIPO_OC||' DOCUMENTO_OC='||P_DOCUMENTO_OC);

        IF P_DOCUMENTO_OC IS NOT NULL AND P_DOCUMENTOTIPO_OC IS NOT NULL THEN

            -- Acutalizo los registros de gestión con el resultado
            BEGIN
                V_PASO := 'UPDATE de registros con OC '||P_DOCUMENTOTIPO_OC||' '||P_DOCUMENTO_OC;

                -- A los productos en BORRADOR los busco NUEVAMENTE por: tipo, bodega, proveedor para hacer updates de uno en uno.
                FOR DETALLE_P2 IN (
                    SELECT ID, LINEA, CODIGOCORTOPRODUCTO, FECHA_COMPROMISO, CON_REQUISICION, REQUISITOR, DESTINO, DESCRIPCION1, DESCRIPCION2, DET_INCOTERM
                    FROM
                        VT_COMP_PENDIENTE_GENERAR_OC
                    WHERE
                        COMPANIA         = P_COMPANIA
                            AND
                        TIPO_REQUISICION = P_TIPO
                            AND
                        TRIM(CODBODEGA)  = TRIM(P_CODBODEGAORG)
                            AND
                        CODPROVEEDOR     = P_CODPROVEEDOR
                            AND
                        RESERVA          = P_RESERVA
                            AND
                        (P_FORMAPAGO is null or FORMAPAGO = P_FORMAPAGO)
                           AND
                        (P_INCOTERM  is null or INCOTERM  = P_INCOTERM)
                            AND
                        USUARIO          = P_USUARIO
                            AND
                        CODPROVEEDOR     IS NOT NULL   -- Tiene negociación
                            AND
                        FECHA_COMPROMISO IS NOT NULL   -- Tiene fecha compromiso
                            AND
                        FECHA_PROCESADO  IS NULL       -- Pendiente de generar OC
                            AND
                        (P_MODO_AGRUPADO IS NULL OR MODO_AGRUPADO = P_MODO_AGRUPADO)
                    ORDER BY ID
                )
                LOOP
                    -- Log de la iteración
                    SP_LOG('SP_POST_GENERA_OC', 'DETALLE_P2 PPGESTION ID='||DETALLE_P2.ID);

                    -- UPDATE de T_COMP_PRODTO_PROVEEDR_GESTION
                    V_PASO := 'UPDATE de T_COMP_PRODTO_PROVEEDR_GESTION con OC '||P_DOCUMENTOTIPO_OC||' '||P_DOCUMENTO_OC||' ID='||DETALLE_P2.ID||' LINEA='||DETALLE_P2.LINEA;
                    UPDATE T_COMP_PRODTO_PROVEEDR_GESTION G
                    SET
                        G.DOCUMENTOTIPO_OC = P_DOCUMENTOTIPO_OC, G.DOCUMENTO_OC=P_DOCUMENTO_OC, G.FECHA_PROCESADO=P_NOW,
                        G.PRECIOUNITARIO = CASE WHEN P_RESERVA=1 THEN NULL ELSE G.PRECIOUNITARIO END -- Si es de reserva no se tiene precio final
                    WHERE  ID = DETALLE_P2.ID;

                    -- UPDATE fechas y descripciones de la OC
                    V_FECHAJDE := PK_COMMONS.F_G2JDE(DETALLE_P2.FECHA_COMPROMISO);
                    V_PASO := 'UPDATE fechas y descripciones F4311 ID='||DETALLE_P2.ID||' '||P_DOCUMENTOTIPO_OC||' '||P_DOCUMENTO_OC||' LINEA='||DETALLE_P2.LINEA||' FECHA='||V_FECHAJDE;
                    UPDATE F4311@jdedtadl JDEOC
                    SET
                        JDEOC.pddgl  = pdpddj,
						JDEOC.PDFRTH = DETALLE_P2.DET_INCOTERM,
                        JDEOC.PDOPDJ = V_FECHAJDE,            -- FECHA_COMPROMISO
                        JDEOC.PDDSC1 = DETALLE_P2.DESCRIPCION1,
                        JDEOC.PDDSC2 = DETALLE_P2.DESCRIPCION2
                    WHERE  pddcto = P_DOCUMENTOTIPO_OC AND pddoco = P_DOCUMENTO_OC AND PDLNID = DETALLE_P2.LINEA*1000;

                    -- UPDATE requisitor y destino OC
                    IF P_TIPO = 'H2' THEN
                        V_PASO := 'UPDATE requisitor y destino en F4311 ID='||DETALLE_P2.ID||' '||P_DOCUMENTOTIPO_OC||' '||P_DOCUMENTO_OC||' LINEA='||DETALLE_P2.LINEA||' FECHA='||V_FECHAJDE;
                        UPDATE F4311@jdedtadl JDEOC
                        SET
                            JDEOC.PDAN8  = P_CODPROVEEDOR,    -- REQUISITOR es el PROVEEDOR
                            JDEOC.PDSHAN = DETALLE_P2.DESTINO -- DESTINO
                        WHERE  pddcto = P_DOCUMENTOTIPO_OC AND pddoco = P_DOCUMENTO_OC AND PDLNID = DETALLE_P2.LINEA*1000;
                    END IF;

                    -- CREO las fechas F4305
                    PK_COMP_GESTIONCOMPRAS.SP_FECHA_COPIA(P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC, '1', P_COMPANIA);
                    PK_COMP_GESTIONCOMPRAS.SP_FECHA_COPIA(P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC, '2', P_COMPANIA);
                    PK_COMP_GESTIONCOMPRAS.SP_FECHA_COPIA(P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC, '3', P_COMPANIA);

                    -- Si es de RESERVA se coloca el estado 240 280 CASO 2700
                    IF P_RESERVA = 1 THEN
                        SP_ESTADO_CAMBIA(P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC, DETALLE_P2.LINEA, '240', '280');
                    END IF;

                    IF DETALLE_P2.CON_REQUISICION = 1 THEN
                        -- ACTUALIZACIONES que aplican solo si se hizo con requisición
                        V_PASO := 'UPDATE de T_COMP_F4311_GESTION con OC '||P_DOCUMENTOTIPO_OC||' '||P_DOCUMENTO_OC||' ID='||DETALLE_P2.ID||' LINEA='||DETALLE_P2.LINEA;
                        SP_LOG('SP_POST_GENERA_OC', V_PASO);
                        -- Pongo el documento generado en la requisiciones gestionadas T_COMP_F4311_GESTION
                        UPDATE T_COMP_F4311_GESTION
                        SET    DOCUMENTOTIPO_OC = P_DOCUMENTOTIPO_OC, DOCUMENTO_OC=P_DOCUMENTO_OC, FECHA_PROCESADO=P_NOW
                        WHERE  ID_PPGESTION = DETALLE_P2.ID;

                        -- Actualización de las requisiciones en JDE relacionadas con este producto
                        SP_CIERRA_REQUISICION(P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC, DETALLE_P2.CODIGOCORTOPRODUCTO);
                    ELSE
                        -- ACTUALIZACIONES que aplican solo si NO TIENE requisisión
                        V_PASO := 'UPDATE de pddsc1, pddsc2 en F4311 ID='||DETALLE_P2.ID||' '||P_DOCUMENTOTIPO_OC||' '||P_DOCUMENTO_OC||' LINEA='||DETALLE_P2.LINEA||' FECHA='||V_FECHAJDE;
                        SP_LOG('SP_POST_GENERA_OC', V_PASO);
                        -- Se coloca el producto en la descripción de la OC
                        UPDATE F4311@jdedtadl
                        SET    (pddsc1, pddsc2) = (SELECT imdsc1, imdsc2 from f4101@jdedtadl where imitm = DETALLE_P2.CODIGOCORTOPRODUCTO)
                        WHERE  pddcto = P_DOCUMENTOTIPO_OC AND pddoco = P_DOCUMENTO_OC AND PDLNID = DETALLE_P2.LINEA*1000
                                AND EXISTS (SELECT imdsc1, imdsc2 from f4101@jdedtadl where imitm = DETALLE_P2.CODIGOCORTOPRODUCTO);
                    END IF;
                END LOOP; -- Itero los T_COMP_PRODTO_PROVEEDR_GESTION gestionados DETALLE_P2

            EXCEPTION WHEN OTHERS THEN
                SP_LOG('SP_POST_GENERA_OC', 'ERROR '||V_PASO||' SQLCODE: '||SQLCODE||' SQLERRM: '||SQLERRM||' TRACE: '||DBMS_UTILITY.format_error_backtrace);
                raise_application_error(-20000,'ERROR '||V_PASO||' '||SQLERRM);
            END; -- Acutalizo los registros de gestión con el resultado

            -- Coloco en la OC la requisición
            SP_COLOCA_REQ_INTO_OC(P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC);

            -- Coloco la FORMAPAGO e INCOTERM en la OC
            IF P_TIPO <> 'H2' THEN
                UPDATE f4301@jdedtadl
                SET
                    phptc  = P_FORMAPAGO,
                    phfrth = P_INCOTERM
                WHERE phdcto=P_DOCUMENTOTIPO_OC AND phdoco=P_DOCUMENTO_OC;
            END IF;

            -- Las tipo H2 deben copiar los objetos de costo
            IF P_TIPO = 'H2' THEN
                SP_COPIA_OBJS_COSTO_F4311T(P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC);
            END IF;

            -- Copio los comentarios
            PK_COMP_ORDENESCOMPRA.SP_COMENTARIOS@JDEDTADL(P_COMPANIA, P_USUARIO, P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC, V_RES_COPIA);
            SP_LOG('SP_POST_GENERA_OC', 'PK_COMP_ORDENESCOMPRA.SP_COMENTARIOS resultado '||V_RES_COPIA);

            -- FLUJO de aprobación
            IF P_RESERVA = 0 THEN -- Las OC de RESERVA no van a flujo de aprob CASO 2700
                SP_FLUJOENVIAR_OC (P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC);
            END IF;

            -- Las OC de RESERVA se notifican al supevisor
            IF P_RESERVA = 1 THEN
                SP_NOTIFICA_OC_RESERVA(P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC, P_USUARIO);
            END IF;

        ELSE
            raise_application_error(-20000,'ERROR SP_POST_GENERA_OC RECIBIDO NULL');
        END IF;  -- IF P_DOCUMENTO_OC IS NOT NULL AND P_DOCUMENTOTIPO_OC IS NOT NULL

    END;

	/*
	** Propósito: Graba los comentarios en la F564310 para la OC generada
	** Parámetros:
    **  P_DOCUMENTOTIPO_OC     VARCHAR2: Entrada. Tipo de OC generada.
    **  P_DOCUMENTO_OC         NUMBER:   Entrada. Número de documento de la OC generada.
    **  P_COMENTARIO_CABECERA  VARCHAR2: Comentario para poner en la cabecera de la OC.
	*/
    PROCEDURE SP_ESTABLECE_COMENTARIOS(P_COMPANIA VARCHAR2, P_DOCUMENTOTIPO_OC VARCHAR2, P_DOCUMENTO_OC NUMBER, P_COMENTARIO_CABECERA VARCHAR2)
    AS
    BEGIN
        -- Log de lo que recibo
        SP_LOG('SP_ESTABLECE_COMENTARIOS', 'DOCUMENTOTIPO_OC='||P_DOCUMENTOTIPO_OC||' DOCUMENTO_OC='||P_DOCUMENTO_OC);

        -- Coloco el comentario de las líneas
        FOR LINEA IN (
            SELECT LINEA, COMENTARIO_PROVEEDOR, COMENTARIO_APROBADOR
            FROM   T_COMP_PRODTO_PROVEEDR_GESTION GESTION
            WHERE  DOCUMENTOTIPO_OC=P_DOCUMENTOTIPO_OC AND DOCUMENTO_OC=P_DOCUMENTO_OC
        )
        LOOP
            pk_comp_ordenescompra.sp_comentario@jdedtadl(
                P_COMPANIA,
                P_DOCUMENTOTIPO_OC,
                P_DOCUMENTO_OC,
                LINEA.LINEA,
                LINEA.COMENTARIO_APROBADOR,
                LINEA.COMENTARIO_PROVEEDOR
            );
        END LOOP;

        -- Coloco el comentario de la cabecera
        pk_comp_ordenescompra.sp_comentario@jdedtadl(
            P_COMPANIA,
            P_DOCUMENTOTIPO_OC,
            P_DOCUMENTO_OC,
            0,
            P_COMENTARIO_CABECERA,
            'N/A dcueva'
        );

    END;

	/*
	** Propósito: Reactiva una OC de reserva.
    **            Coloca en JDE el precio actual en cada línea.
    **            Cambia el estado a 220-240.
    **            Envía a flujo de aprobación.
	** Parámetros:
    **  P_DOCUMENTOTIPO_OC VARCHAR2: Entrada. Tipo de OC generada.
    **  P_DOCUMENTO_OC       NUMBER: Entrada. Número de documento de la OC generada.
	*/
    PROCEDURE SP_REACTIVA_RESERVA (P_DOCUMENTOTIPO_OC VARCHAR2, P_DOCUMENTO_OC NUMBER)
    AS
        P_FECHA_REACTIVA_RESERVA TIMESTAMP := SYSDATE;
        P_PHOTOT NUMBER := 0;
    BEGIN
        -- Log de lo que recibo
        SP_LOG('SP_REACTIVA_RESERVA', 'DOCUMENTOTIPO_OC='||P_DOCUMENTOTIPO_OC||' DOCUMENTO_OC='||P_DOCUMENTO_OC);

        -- Itero las líneas
        FOR LINEA IN (
            SELECT
                GST.ID,
                GST.LINEA,
                NVL(GST.CANTIDAD_MANUAL, GST.CANTIDAD) AS CANTIDAD,
                NEG.DET_PRECIO
            FROM
                T_COMP_PRODTO_PROVEEDR_GESTION  GST,
                vt_comp_negociacionsel NEG
            WHERE
                GST.DET_ID = NEG.DET_ID(+)
                    AND
                DOCUMENTOTIPO_OC = P_DOCUMENTOTIPO_OC
                    AND
                DOCUMENTO_OC     = P_DOCUMENTO_OC
        )
        LOOP
            -- Pongo el precio en la línea de la F4311
            UPDATE F4311@jdedtadl
            SET
                PDPRRC = LINEA.DET_PRECIO * 10000,
                PDAEXP = LINEA.DET_PRECIO * LINEA.CANTIDAD * 100,
                PDAOPN = LINEA.DET_PRECIO * LINEA.CANTIDAD * 100
            WHERE pddcto = P_DOCUMENTOTIPO_OC AND pddoco = P_DOCUMENTO_OC AND PDLNID = LINEA.LINEA*1000;

            -- Cambio el estado de la línea
            SP_ESTADO_CAMBIA (P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC, LINEA.LINEA, '220', '240');

            -- Marco la reactivación y actualizo el precio
            UPDATE T_COMP_PRODTO_PROVEEDR_GESTION
            SET
                PRECIOUNITARIO         = LINEA.DET_PRECIO,
                FECHA_REACTIVA_RESERVA = P_FECHA_REACTIVA_RESERVA
            WHERE ID = LINEA.ID;

            -- Voy sumando todos los valores individuales para poner el total en la cabecera
            P_PHOTOT := P_PHOTOT + (LINEA.DET_PRECIO * LINEA.CANTIDAD);
        END LOOP;

        -- Actualizo el monto en la cabecera
        UPDATE F4301@jdedtadl
        SET
            PHOTOT = P_PHOTOT * 100
        WHERE pHdcto = P_DOCUMENTOTIPO_OC AND pHdoco = P_DOCUMENTO_OC;

        -- Finalmente envío a flujo de aprobación
        SP_FLUJOENVIAR_OC (P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC);

    END;

	/*
	** Propósito: Afecta las requisiciones dada una OC generada.
	** Parámetros:
    **  P_DOCUMENTOTIPO_OC VARCHAR2: Entrada. Tipo de OC generada.
    **  P_DOCUMENTO_OC       NUMBER: Entrada. Número de documento de la OC generada.
	*/
    PROCEDURE SP_CIERRA_REQUISICION (P_DOCUMENTOTIPO_OC VARCHAR2, P_DOCUMENTO_OC NUMBER, P_CODIGOCORTOPRODUCTO NUMBER)
    AS
    BEGIN
        -- Itero los T_COMP_F4311_GESTION con la finalidad de obtener las requisiciones asociadas a la orden generada y el producto.
        FOR DETALLE IN (
            SELECT ID, LINEA, DOCUMENTOTIPO, DOCUMENTO
        FROM   T_COMP_F4311_GESTION
        WHERE
            DOCUMENTOTIPO_OC = P_DOCUMENTOTIPO_OC     AND DOCUMENTO_OC = P_DOCUMENTO_OC AND CODIGOCORTOPRODUCTO = P_CODIGOCORTOPRODUCTO
        )
        LOOP
            update F4311@jdedtadl x
            set    x.pdlttr = 130, x.pdnxtr = 999
            where
                x.pddoco = DETALLE.DOCUMENTO
                    AND
                x.pddcto = DETALLE.DOCUMENTOTIPO
                    AND
                x.PDLNID = DETALLE.LINEA
                    AND
                ((x.pdlttr = 110 and x.pdnxtr = 120) or (x.pdlttr = 100 and x.pdnxtr = 130));
            SP_LOG('SP_CIERRA_REQUISICION', 'DOCUMENTOTIPO_OC='||P_DOCUMENTOTIPO_OC||' DOCUMENTO_OC='||P_DOCUMENTO_OC||' CODIGOCORTOPRODUCTO='||P_CODIGOCORTOPRODUCTO||' -> pddoco='||DETALLE.DOCUMENTO|| ' pddcto='||DETALLE.DOCUMENTOTIPO||' PDLNID='||DETALLE.LINEA);

        END LOOP; -- Loop DETALLE
    END;

	/*
	** Propósito: Coloca en JDE en la OC generada la requisición asociada.
    **            Nota en caso de tener varias requisiciones para una OC,
    **            se toma solo una requisición.
	** Parámetros:
    **  P_DOCUMENTOTIPO_OC VARCHAR2: Entrada. Tipo de OC generada.
    **  P_DOCUMENTO_OC       NUMBER: Entrada. Número de documento de la OC generada.
	*/
    PROCEDURE SP_COLOCA_REQ_INTO_OC    (P_DOCUMENTOTIPO_OC VARCHAR2, P_DOCUMENTO_OC NUMBER)
    AS
    BEGIN
        -- DETALLES F4311@jdedtadl
        FOR INFO IN (
            SELECT
                R.DOCUMENTOTIPO AS DOCUMENTOTIPO,
                R.DOCUMENTO     AS DOCUMENTO,
                R.LINEA         AS LINEA,

                OC.LINEA        AS OC_LINEA,
                OC.COMPANIA     AS COMPANIA
            FROM
                T_COMP_F4311_GESTION           R,
                T_COMP_PRODTO_PROVEEDR_GESTION OC
            WHERE
                OC.ID = R.ID_PPGESTION
                    AND
                OC.DOCUMENTOTIPO_OC=P_DOCUMENTOTIPO_OC AND OC.DOCUMENTO_OC=P_DOCUMENTO_OC
            ORDER BY R.ID
        )
        LOOP
            UPDATE F4311@jdedtadl x
            SET
                PDOCTO = INFO.DOCUMENTOTIPO,
                PDOORN = INFO.DOCUMENTO,
                PDOGNO = INFO.LINEA
            WHERE
                x.pddoco = P_DOCUMENTO_OC
                    AND
                x.pddcto = P_DOCUMENTOTIPO_OC
                    AND
                x.PDLNID = INFO.OC_LINEA*1000;
            SP_LOG('SP_COLOCA_REQ_INTO_OC', 'DETALLE DOCUMENTOTIPO_OC='||P_DOCUMENTOTIPO_OC||' DOCUMENTO_OC='||P_DOCUMENTO_OC||' LINEA_OC='||INFO.OC_LINEA*1000||' <- '||INFO.DOCUMENTOTIPO|| ' '||INFO.DOCUMENTO||' '||INFO.LINEA||' afectadas='||SQL%ROWCOUNT);
        END LOOP;

        -- CABECERA F4301@jdedtadl
        FOR INFO IN (
            SELECT
                R.COMPANIA      AS COMPANIA,
                R.DOCUMENTOTIPO AS DOCUMENTOTIPO,
                R.DOCUMENTO     AS DOCUMENTO,
                R.LINEA         AS LINEA
            FROM
                T_COMP_F4311_GESTION R
            WHERE
                R.DOCUMENTOTIPO_OC=P_DOCUMENTOTIPO_OC AND R.DOCUMENTO_OC=P_DOCUMENTO_OC
            ORDER BY R.DOCUMENTO
        )
        LOOP
            UPDATE F4301@jdedtadl x
            SET
                PHOKCO = INFO.COMPANIA,
                PHOCTO = INFO.DOCUMENTOTIPO,
                PHOORN = INFO.DOCUMENTO
            WHERE
                x.phdoco = P_DOCUMENTO_OC
                    AND
                x.phdcto = P_DOCUMENTOTIPO_OC;
            SP_LOG('SP_COLOCA_REQ_INTO_OC', 'CABECERA DOCUMENTOTIPO_OC='||P_DOCUMENTOTIPO_OC||' DOCUMENTO_OC='||' <- '||INFO.COMPANIA|| ' '||INFO.DOCUMENTOTIPO||' '||INFO.DOCUMENTO||' afectadas='||SQL%ROWCOUNT);
        END LOOP;
    END;

	/*
	** Propósito: Determina si un PRODUCTO con una determinada CANTIDAD tiene UNA SOLA negociación disponible.
    ** De ser así se coloca esta negociación en el producto.
	** Parámetros:
    **  P_PPGESTIONID          NUMBER: Entrada. Producto/Proveedor que estamos gestionando y vamos a afectar de ser el caso.
    **  P_CODIGOCORTOPRODUCTO  NUMBER: Entrada. Producto que buscamos en las negociaociones.
    **  P_CANTIDAD             NUMBER: Entrada. Cantidad del producto que buscamos en las negociaociones.
	*/
    PROCEDURE SP_COLOCA_NEGOCIACION_DEFAULT(P_PPGESTIONID NUMBER, P_CODIGOCORTOPRODUCTO NUMBER, P_CANTIDAD NUMBER )
    AS
        V_COUNT   NUMBER;
        V_DET_ID  NUMBER;
        V_RESERVA NUMBER;
    BEGIN
        -- Determino si es de reserva
        SELECT RESERVA INTO V_RESERVA FROM T_COMP_PRODTO_PROVEEDR_GESTION WHERE ID = P_PPGESTIONID;

        -- Cuento cuantas negociaciones cumplen con lo requerido
        SELECT COUNT(1), MAX(DET_ID)
        INTO   V_COUNT,  V_DET_ID
        FROM   vt_comp_negociacionsel
        where
            DET_VIGENTE = 'SI' AND NEG_ESTADOFLUJO = 'APROBADO'  -- SOLO VIGENTES Y APROBADAS
                AND
            DET_CODPRODUCTO = P_CODIGOCORTOPRODUCTO
                AND
            (
                (NEG_TIPO = 'FJ')
                    OR
                (NEG_TIPO = 'ES' AND P_CANTIDAD BETWEEN DET_CANTDESDE AND DET_CANTHASTA)
            )
                AND
            (
                (V_RESERVA IS NULL OR V_RESERVA = 0)
                    OR
                (V_RESERVA = 1 AND DET_PUEDERESERVAR=1)
            );

        IF V_COUNT = 1 THEN
            PK_COMP_GESTIONCOMPRAS.SP_SET_PPGESTION_NEGOCIACION (P_PPGESTIONID, V_DET_ID);
            SP_LOG('SP_COLOCA_NEGOCIACION_DEFAULT', 'PPGESTIONID='||P_PPGESTIONID||' CODIGOCORTOPRODUCTO='||P_CODIGOCORTOPRODUCTO||' CANTIDAD='||P_CANTIDAD||' DET_ID='||V_DET_ID);
        END IF;

        EXCEPTION WHEN OTHERS THEN
            SP_LOG('SP_COLOCA_NEGOCIACION_DEFAULT', 'ERROR PPGESTIONID='||P_PPGESTIONID||' CODIGOCORTOPRODUCTO='||P_CODIGOCORTOPRODUCTO||' CANTIDAD='||P_CANTIDAD||' COUNT='||V_COUNT||' TRACE: '||DBMS_UTILITY.format_error_backtrace);

    END;

	/*
	** Propósito: Determina si un PRODUCTO con una determinada CANTIDAD tiene UNA SOLA negociación disponible para un determinado PROVEEDOR.
    ** De ser así se coloca esta negociación en el producto.
	** Parámetros:
    **  P_PPGESTIONID          NUMBER: Entrada. Producto/Proveedor que estamos gestionando y vamos a afectar de ser el caso.
    **  P_CODIGOCORTOPRODUCTO  NUMBER: Entrada. Producto que buscamos en las negociaociones.
    **  P_CANTIDAD             NUMBER: Entrada. Cantidad del producto que buscamos en las negociaociones.
    **  P_CODPROVEEDOR         NUMBER: Entrada. Código del proveedor a buscar.
	*/
    PROCEDURE SP_COLOCA_NEGOCIACION_DEFAULT_PROVEEDOR(P_PPGESTIONID NUMBER, P_CODIGOCORTOPRODUCTO NUMBER, P_CANTIDAD NUMBER, P_CODPROVEEDOR NUMBER)
    AS
        V_COUNT   NUMBER;
        V_DET_ID  NUMBER;
    BEGIN
        SELECT COUNT(1), MAX(DET_ID)
        INTO   V_COUNT,  V_DET_ID
        FROM   vt_comp_negociacionsel
        where
            DET_VIGENTE = 'SI' AND NEG_ESTADOFLUJO = 'APROBADO'  -- SOLO VIGENTES Y APROBADAS
                AND
            DET_CODPRODUCTO = P_CODIGOCORTOPRODUCTO
                AND
            (
                (NEG_TIPO = 'FJ')
                    OR
                (NEG_TIPO = 'ES' AND P_CANTIDAD BETWEEN DET_CANTDESDE AND DET_CANTHASTA)
            )
                AND
            DET_CODPROVEEDOR = P_CODPROVEEDOR;

        IF V_COUNT = 1 THEN
            PK_COMP_GESTIONCOMPRAS.SP_SET_PPGESTION_NEGOCIACION (P_PPGESTIONID, V_DET_ID);
            SP_LOG('SP_COLOCA_NEGOCIACION_DEFAULT_PROVEEDOR', 'PPGESTIONID='||P_PPGESTIONID||' CODIGOCORTOPRODUCTO='||P_CODIGOCORTOPRODUCTO||' CODPROVEEDOR='||P_CODPROVEEDOR||' CANTIDAD='||P_CANTIDAD||' DET_ID='||V_DET_ID);
        END IF;

        EXCEPTION WHEN OTHERS THEN
            SP_LOG('SP_COLOCA_NEGOCIACION_DEFAULT_PROVEEDOR', 'ERROR PPGESTIONID='||P_PPGESTIONID||' CODIGOCORTOPRODUCTO='||P_CODIGOCORTOPRODUCTO||' CANTIDAD='||P_CANTIDAD||' COUNT='||V_COUNT||' CODPROVEEDOR='||P_CODPROVEEDOR||' TRACE: '||DBMS_UTILITY.format_error_backtrace);

    END;

	/*
	** Propósito: Inserta un producto para ser comprado desde un módulo externo.
	** Parámetros:
    **  P_TIPO                 VARCHAR2: Entrada. H1, H2, H3.
    **  P_CODBODEGA            VARCHAR2: Entrada. Código de la bodega.
    **  P_DET_ID               NUMBER:   Entrada. Negociación seleccionada. De aquí se obtiene el CODIGOCORTOPRODUCTO, CODPROVEEDOR y PRECIOUNITARIO
    **  P_CANTIDAD             NUMBER:   Entrada. Cantidad que vamos a comprar del producto.
    **  P_PRECIOUNITARIO       NUMBER:   Entrada. Si es NULL se toma el valor de DET_ID.
    **  P_FECHA_COMPROMISO     DATE:     Entrada. Fecha compromiso de entrega del producto.
    **  P_DESCRIPCION1         VARCHAR2: Entrada. Se coloca en la línea de la OC. Máximo 30 caracteres.
    **  P_DESCRIPCION2         VARCHAR2: Entrada. Se coloca en la línea de la OC. Máximo 30 caracteres.
    **
    **  P_USUARIO              VARCHAR2: Entrada. La persona que va a crear la OC
    **  P_COMPANIA             VARCHAR2: Entrada. Código de la empresa.
    **  P_MODULOEXTERNO        VARCHAR2: Entrada. 'COMP_REC', 'PROY'
    **
    **  P_PPGESTIONID          NUMBER:   Salida. ID secuencial del producto insertado.
    */
    PROCEDURE SP_AGREGA_COMPRA_EXTERNA (
        P_TIPO             VARCHAR2,
        P_CODBODEGA        VARCHAR,
        P_CANTIDAD         NUMBER,
        P_DET_ID           NUMBER,
        P_PRECIOUNITARIO   NUMBER,
        P_FECHA_COMPROMISO DATE,
        P_DESCRIPCION1     VARCHAR2,
        P_DESCRIPCION2     VARCHAR2,

        P_USUARIO          VARCHAR2,
        P_COMPANIA         VARCHAR2,
        P_MODULOEXTERNO    VARCHAR2,

        P_PPGESTIONID      OUT NUMBER
    )
    AS
        V_CODIGOCORTOPRODUCTO  NUMBER;
        V_CODPROVEEDOR         NUMBER;
        V_PRECIOUNITARIO       NUMBER;
        V_VERSION              VARCHAR2(30);
        V_TIPO_OC              VARCHAR2(10);
    BEGIN
        -- Log de lo que que he recibido y validación
        SP_LOG('SP_AGREGA_COMPRA_EXTERNA', 'Inicio TIPO="'||P_TIPO||'" BODEGA="'||P_CODBODEGA||'" CANTIDAD='||P_CANTIDAD||' DET_ID='||P_DET_ID||' PRECIOUNITARIO='||P_PRECIOUNITARIO||' FECHA_COMPROMISO='||P_FECHA_COMPROMISO||' USUARIO='||P_USUARIO ||' COMPANIA='||P_COMPANIA||' MODULOEXTERNO='||P_MODULOEXTERNO);
        IF P_TIPO IS NULL OR P_TIPO NOT IN ('H1','H2','H3') THEN
            SP_LOG('SP_AGREGA_COMPRA_EXTERNA', 'ERROR P_TIPO IS NULL OR P_TIPO NOT H1,H2,H3');
            raise_application_error(-20000,'Debe enviar P_TIPO: H1, H2, H3');
        END IF;
        IF P_CODBODEGA IS NULL THEN
            SP_LOG('SP_AGREGA_COMPRA_EXTERNA', 'ERROR P_CODBODEGA IS NULL');
            raise_application_error(-20000,'Debe enviar P_CODBODEGA');
        END IF;
        IF P_CANTIDAD IS NULL OR P_CANTIDAD <= 0 THEN
            SP_LOG('SP_AGREGA_COMPRA_EXTERNA', 'ERROR P_CANTIDAD IS NULL OR P_CANTIDAD <= 0');
            raise_application_error(-20000,'Debe enviar una P_CANTIDAD aceptable');
        END IF;
        IF P_DET_ID IS NULL THEN
            SP_LOG('SP_AGREGA_COMPRA_EXTERNA', 'ERROR P_DET_ID IS NULL');
            raise_application_error(-20000,'Debe enviar una negociación P_DET_ID');
        END IF;
        IF P_FECHA_COMPROMISO IS NULL THEN
            SP_LOG('SP_AGREGA_COMPRA_EXTERNA', 'ERROR P_FECHA_COMPROMISO IS NULL');
            raise_application_error(-20000,'Debe enviar P_FECHA_COMPROMISO');
        END IF;
        IF P_USUARIO IS NULL THEN
            SP_LOG('SP_AGREGA_COMPRA_EXTERNA', 'ERROR P_USUARIO IS NULL');
            raise_application_error(-20000,'Debe enviar P_USUARIO');
        END IF;
        IF P_COMPANIA IS NULL THEN
            SP_LOG('SP_AGREGA_COMPRA_EXTERNA', 'ERROR P_COMPANIA IS NULL');
            raise_application_error(-20000,'Debe enviar P_COMPANIA');
        END IF;
        IF P_MODULOEXTERNO IS NULL THEN
            SP_LOG('SP_AGREGA_COMPRA_EXTERNA', 'ERROR P_MODULOEXTERNO IS NULL');
            raise_application_error(-20000,'Debe enviar P_MODULOEXTERNO una identificación del módulo responsable');
        END IF;

        -- Recupero la info del detalle de la negociación
        SELECT DET_CODPRODUCTO,       DET_CODPROVEEDOR, DET_PRECIO
        INTO   V_CODIGOCORTOPRODUCTO, V_CODPROVEEDOR,   V_PRECIOUNITARIO
        FROM   vt_comp_negociacionsel
        WHERE  DET_ID = P_DET_ID;
        SP_LOG('SP_AGREGA_COMPRA_EXTERNA', 'Negociación CODIGOCORTOPRODUCTO="'||V_CODIGOCORTOPRODUCTO||'" CODPROVEEDOR="'||V_CODPROVEEDOR||'" PRECIOUNITARIO='||V_PRECIOUNITARIO);

        --Inserto el producto SIN REQUISICIÓN
        SP_AGREGAR_SIN_REQUISICION(
            P_TIPO,               -- P_TIPO_REQUISICION VARCHAR2
            V_CODIGOCORTOPRODUCTO,-- P_CODIGOCORTOPRODUCTO NUMBER
            P_CODBODEGA,          -- P_BODEGA VARCHAR
            P_CANTIDAD,           -- P_CANTIDAD NUMBER
            1,                    -- P_DUPLICADO NUMBER
            P_USUARIO,            -- P_USUARIO VARCHAR2
            P_COMPANIA,           -- P_COMPANIA VARCHAR2
            P_PPGESTIONID         -- P_ID OUT NUMBER
        );
        SP_LOG('SP_AGREGA_COMPRA_EXTERNA', 'PPGESTIONID='||P_PPGESTIONID||' TIPO='||P_TIPO);

        -- Le pongo la negociación
        SP_SET_PPGESTION_NEGOCIACION(
            P_PPGESTIONID, -- P_PPGESTIONID NUMBER
            P_DET_ID       -- P_DET_ID NUMBER
        );

        -- Le pongo la descripción
        UPDATE T_COMP_PRODTO_PROVEEDR_GESTION
        SET DESCRIPCION1=SUBSTR(P_DESCRIPCION1,1,30), DESCRIPCION2=SUBSTR(P_DESCRIPCION2,1,30)
        WHERE ID = P_PPGESTIONID;

        -- Valido que se haya obtenido una versión JDE
        SELECT VERSION, TIPO_OC INTO V_VERSION, V_TIPO_OC FROM T_COMP_PRODTO_PROVEEDR_GESTION WHERE ID = P_PPGESTIONID;
        IF V_VERSION IS NULL THEN
            raise_application_error(-20000,'No se puede obtener una VERSIÓN a partir de la información proporcionada');
        END IF;

        -- Valido que tenga ruta de aprobación
        -- TODO

        -- Le pongo la fecha compromiso
        SP_SET_PPGESTION_CANT_EMAILS (
            P_PPGESTIONID,     -- P_PPGESTIONID NUMBER
            P_CANTIDAD,        -- P_CANTIDAD_MANUAL NUMBER
            NULL,              -- P_JUSTIFICACION
            NULL,              -- P_EMAILS VARCHAR2
            P_FECHA_COMPROMISO,-- P_FECHA_COMPROMISO DATE
            0                  -- Los externos no tienen MODO AGRUPADO
        );

        -- Información extra al ser de un módulo externo
        UPDATE T_COMP_PRODTO_PROVEEDR_GESTION
        SET
            CANTIDAD_MANUAL       = P_CANTIDAD,
            PRECIOUNITARIOEXTERNO = P_PRECIOUNITARIO,
            MODULOEXTERNO         = P_MODULOEXTERNO,
            OBSERVACION           = 'EXTERNO'
        WHERE ID=P_PPGESTIONID;

    END;

	/*
	** Propósito: Genera la OC para los productos insertados con SP_AGREGA_COMPRA_EXTERNA
	** Parámetros:
    **  P_TIPO                 VARCHAR2: Entrada. H1, H2, H3
    **  P_CODBODEGA            VARCHAR2: Entrada. Código de la bodega
    **  P_CODPROVEEDOR         NUMBER:   Entrada. Proveedor al que se compra
    **
    **  P_USUARIO              VARCHAR2: Entrada. Quién está comprando.
    **  P_COMPANIA             VARCHAR2: Entrada.
    **  P_MODULOEXTERNO        VARCHAR2: Entrada. Identificación del módulo en 10 carcteres.
    **
    **  P_DOCUMENTOTIPO_OC     VARCHAR2: Salida. Tipo de OC generada.
    **  P_DOCUMENTO_OC         NUMBER:   Salida. Número de OC generada.
    */
    PROCEDURE SP_GENERA_OC_COMPRA_EXTERNA (
        P_TIPO             VARCHAR2,
        P_CODBODEGAORG     VARCHAR,
        P_CODBODEGADST     VARCHAR,
        P_CODPROVEEDOR     NUMBER,

        P_USUARIO          VARCHAR2,
        P_COMPANIA         VARCHAR2,
        P_MODULOEXTERNO    VARCHAR2,

        P_DOCUMENTOTIPO_OC OUT VARCHAR2,  P_DOCUMENTO_OC OUT NUMBER
    )
    AS
        V_LINEAS    NUMBER;
    BEGIN
        -- Log de lo que que he recibido y validación
        SP_LOG('SP_GENERA_OC_COMPRA_EXTERNA', 'Inicio TIPO="'||P_TIPO||'" BODEGA="'||P_CODBODEGAORG||'" CODPROVEEDOR='||P_CODPROVEEDOR||' USUARIO='||P_USUARIO ||' COMPANIA='||P_COMPANIA||' MODULOEXTERNO='||P_MODULOEXTERNO);
        IF P_TIPO IS NULL OR P_TIPO NOT IN ('H1','H2','H3') THEN
            SP_LOG('SP_GENERA_OC_COMPRA_EXTERNA', 'ERROR P_TIPO IS NULL OR P_TIPO NOT H1,H2,H3');
            raise_application_error(-20000,'Debe enviar P_TIPO: H1, H2, H3');
        END IF;
        IF P_CODBODEGAORG IS NULL THEN
            SP_LOG('SP_GENERA_OC_COMPRA_EXTERNA', 'ERROR P_CODBODEGAORG IS NULL');
            raise_application_error(-20000,'Debe enviar P_CODBODEGAORG');
        END IF;
        IF P_CODPROVEEDOR IS NULL THEN
            SP_LOG('SP_GENERA_OC_COMPRA_EXTERNA', 'ERROR P_CODPROVEEDOR IS NULL');
            raise_application_error(-20000,'Debe enviar el proveedor P_CODPROVEEDOR');
        END IF;
        IF P_USUARIO IS NULL THEN
            SP_LOG('SP_GENERA_OC_COMPRA_EXTERNA', 'ERROR P_USUARIO IS NULL');
            raise_application_error(-20000,'Debe enviar P_USUARIO');
        END IF;
        IF P_COMPANIA IS NULL THEN
            SP_LOG('SP_GENERA_OC_COMPRA_EXTERNA', 'ERROR P_COMPANIA IS NULL');
            raise_application_error(-20000,'Debe enviar P_COMPANIA');
        END IF;
        IF P_MODULOEXTERNO IS NULL THEN
            SP_LOG('SP_GENERA_OC_COMPRA_EXTERNA', 'ERROR P_MODULOEXTERNO IS NULL');
            raise_application_error(-20000,'Debe enviar P_MODULOEXTERNO una identificación del módulo responsable');
        END IF;

        -- Verifico que haya algo por hacer
        SELECT COUNT(1) INTO V_LINEAS FROM VT_COMP_PENDIENTE_GENERAR_OC
        WHERE TIPO_REQUISICION=P_TIPO AND CODBODEGA=P_CODBODEGAORG AND CODPROVEEDOR=P_CODPROVEEDOR AND USUARIO=P_USUARIO AND COMPANIA=P_COMPANIA AND MODULOEXTERNO=P_MODULOEXTERNO
                AND
              DET_ID IS NOT NULL AND FECHA_COMPROMISO IS NOT NULL;
        IF V_LINEAS = 0 THEN
            raise_application_error(-20000,'No se encuentran productos a comprar. Debe establecer negociación y fecha compromiso');
        END IF;

        -- Mando a generar la OC
        SP_GENERA_OC(
            P_TIPO,         -- P_TIPO VARCHAR2
            P_CODBODEGAORG, -- P_CODBODEGAORG VARCHAR2
            P_CODBODEGADST, -- P_CODBODEGADST VARCHAR2
            P_CODPROVEEDOR, -- P_CODPROVEEDOR NUMBER
            0,              -- P_RESERVA
            NULL,           -- MODO agrupado

            P_USUARIO,      -- P_USUARIO VARCHAR2
            P_COMPANIA,     -- P_COMPANIA VARCHAR2

            P_DOCUMENTOTIPO_OC, -- P_DOCUMENTOTIPO_OC OUT VARCHAR2,
            P_DOCUMENTO_OC      -- P_DOCUMENTO_OC OUT NUMBER
        );
        SP_LOG('SP_GENERA_OC_COMPRA_EXTERNA', 'Fin DOCUMENTOTIPO_OC="'||P_DOCUMENTOTIPO_OC||'" DOCUMENTO_OC="'||P_DOCUMENTO_OC);

    END;

	/*
	** Propósito: Toma la gestión de una OC y la genera nuevamente para generar una nueva OC.
	** Parámetros:
    **  P_DOCUMENTOTIPO_OC VARCHAR2: Entrada. CM, CN, BN, etc.
    **  P_DOCUMENTO_OC     NUMBER:   Entrada. Número de documento.
    **  P_USUARIO          VARCHAR2: Entrada. La persona que está duplicando la gestión.
    */
    PROCEDURE SP_DUPLICA_GESTION_OC(P_DOCUMENTOTIPO_OC VARCHAR2, P_DOCUMENTO_OC NUMBER, P_USUARIO VARCHAR2, P_COMPANIA VARCHAR2)
    AS
        V_PPGESTIONID  NUMBER;
    BEGIN
        -- Log de lo que ha llegado
        SP_LOG('SP_DUPLICA_GESTION_OC', 'Inicio DOCUMENTOTIPO_OC='||P_DOCUMENTOTIPO_OC||' DOCUMENTO_OC='||P_DOCUMENTO_OC||' USUARIO='||P_USUARIO);

        -- Itero las líneas de esa OC
        FOR ORIGINAL IN (SELECT * FROM T_COMP_PRODTO_PROVEEDR_GESTION WHERE DOCUMENTOTIPO_OC=P_DOCUMENTOTIPO_OC AND DOCUMENTO_OC=P_DOCUMENTO_OC ORDER BY ID)
        LOOP
            BEGIN
                SP_AGREGAR_SIN_REQUISICION(
                   ORIGINAL.TIPO_REQUISICION,
                   ORIGINAL.CODIGOCORTOPRODUCTO,
                   ORIGINAL.BODEGA,
                   ORIGINAL.CANTIDAD,
                   0,
                   P_USUARIO,
                   P_COMPANIA,

                   V_PPGESTIONID
                );
                UPDATE T_COMP_PRODTO_PROVEEDR_GESTION SET OBSERVACION='DUPLICADO DE ID='||ORIGINAL.ID;
                SP_COLOCA_NEGOCIACION_DEFAULT(V_PPGESTIONID, ORIGINAL.CODIGOCORTOPRODUCTO, ORIGINAL.CANTIDAD);
                SP_LOG('SP_DUPLICA_GESTION_OC', 'DUPLICADO NEW='||V_PPGESTIONID||' ORG='||ORIGINAL.ID);
            EXCEPTION WHEN OTHERS THEN
                SP_LOG('SP_DUPLICA_GESTION_OC', 'ERROR ID='||ORIGINAL.ID||' SQLERRM: '||SQLERRM||' TRACE: '||DBMS_UTILITY.format_error_backtrace);
            END;
        END LOOP;
    END;

	/*
	** Propósito: Inserta una linea en JDE F4305.
	** Parámetros:
    **  P_DOCUMENTOTIPO VARCHAR2: Entrada. CM, CN, BN, etc.
    **  P_DOCUMENTO     NUMBER:   Entrada. Número de documento.
    **  P_UDC           VARCHAR2: Entrada. Columna F4305.PLLGTY a insertar.
    **  P_FECHAJDE      NUMBER:   Entrada. Fecha en formato JDE a colocar en la columna F4305.PLISSU
    */
    PROCEDURE SP_FECHA_INSERTA (P_DOCUMENTOTIPO VARCHAR2, P_DOCUMENTO NUMBER, P_UDC VARCHAR2, P_FECHAJDE NUMBER, P_COMPANIA VARCHAR2)
    AS
        V_PLUKID  NUMBER;
        V_PLUPMJ  NUMBER;
        V_LABEL   VARCHAR2(100);
    BEGIN
        -- Log de lo que ha llegado.
        SP_LOG('SP_FECHA_INSERTA', 'Inicio DOCUMENTOTIPO='||P_DOCUMENTOTIPO||' DOCUMENTO='||P_DOCUMENTO||' UDC='||P_UDC||' FECHAJDE='||P_FECHAJDE);

        SELECT PK_COMMONS.F_G2JDE(SYSDATE) INTO V_PLUPMJ FROM DUAL;

        -- Recupero el label
        SELECT DRDL01 INTO V_LABEL FROM VT_JDE_UDCJDE WHERE DRSY='00' AND DRRT='LG' AND DRKY=P_UDC;

        -- Genero la secuencia
        pk_comp_ordenescompra.sp_seqf4305(V_PLUKID);

        -- Inserto
        INSERT INTO F4305@jdedtadl
        (PLUKID,   PLDCTO,          PLDOCO,      PLLGTY, PLDL01,  PLISSU,     PLKCOO,     PLSFXO,   PLAN8,   PLLOGH, PLLGNO,  PLPAYE, PLEXPR, PLREQR, PLDEJ, PLANCR, PLCONO, PLU, PLUSD1, PLUPMT, PLUSER,       PLJOBN,       PLUPMJ,   PLMCU,  PLOMCU, PLSTSC,  PLEXR, PLRPT1, PLRPT2, PLRPT3, PLSBCD,  PLUM, PLCO, PLPID) VALUES
        (V_PLUKID, P_DOCUMENTOTIPO, P_DOCUMENTO, P_UDC,  V_LABEL, P_FECHAJDE, P_COMPANIA, '000',        0,   '01',        0,  'N',         0,      0,     0,      0,      0,   0,      0,      0, 'SISTEMAS  ', 'APEXCOMP  ', V_PLUPMJ, '    ', '    ', ' ',     '   ', '   ',  '  ',   '  ',   ' ',     ' ',  ' ',  ' ') ;

        -- Log de lo que hice
        SP_LOG('SP_FECHA_INSERTA', 'INSERTADO PLUKID='||V_PLUKID||' LABEL='||V_LABEL);
    END;

	/*
	** Propósito: Dada una OC busca sus requisiciones asociadas y:,
    **     a. Si las tiene, busca dentro de ellas la máxima fecha.
    **     b. Si no tiene, busca la máxima fecha compromiso.
	** Parámetros:
    **  P_DOCUMENTOTIPO VARCHAR2: Entrada. CM, CN, BN, etc.
    **  P_DOCUMENTO     NUMBER:   Entrada. Número de documento.
    **  P_UDC           VARCHAR2: Entrada. Columna F4305.PLLGTY a buscar.
    */
    PROCEDURE SP_FECHA_COPIA (P_DOCUMENTOTIPO_OC VARCHAR2, P_DOCUMENTO_OC NUMBER, P_UDC VARCHAR2, P_COMPANIA VARCHAR2)
    AS
        V_COUNT       NUMBER;
        V_FECHAMAXIMA NUMBER;
    BEGIN
        -- Log de lo que ha llegado.
        SP_LOG('SP_FECHA_COPIA', 'Inicio DOCUMENTOTIPO_OC='||P_DOCUMENTOTIPO_OC||' DOCUMENTO_OC='||P_DOCUMENTO_OC||' UDC='||P_UDC);

        -- Determino si ya tiene la fecha en F4305.
        SELECT COUNT(1), MAX(PLISSU)
        INTO   V_COUNT, V_FECHAMAXIMA
        FROM   F4305@jdedtadl FECHA
        WHERE
            FECHA.PLDCTO = P_DOCUMENTOTIPO_OC
                AND
            FECHA.PLDOCO = P_DOCUMENTO_OC
                AND
            FECHA.PLKCOO = P_COMPANIA
                AND
            FECHA.PLLGTY = P_UDC;

        IF V_COUNT = 0 THEN
            -- No existe la fecha entonces se debe copiar tomando
            -- una fecha en las requsiciones o la fecha compromiso
            BEGIN
                -- Busco la fecha máxima en las requisiciones asociadas.
                SELECT MAX(PLISSU) AS FECHA
                INTO   V_FECHAMAXIMA
                FROM
                    T_COMP_F4311_GESTION GESTION,
                    F4305@jdedtadl       FECHA
                WHERE
                    -- Busco la OC en la gestión
                    GESTION.DOCUMENTOTIPO_OC = P_DOCUMENTOTIPO_OC
                        AND
                    GESTION.DOCUMENTO_OC     = P_DOCUMENTO_OC
                        AND
                    GESTION.COMPANIA         = P_COMPANIA
                        AND
                    -- Join de la requisición con las fechas JDE F4305
                    GESTION.DOCUMENTOTIPO = FECHA.PLDCTO
                        AND
                    GESTION.DOCUMENTO     = FECHA.PLDOCO
                        AND
                    GESTION.COMPANIA      = FECHA.PLKCOO
                        AND
                    -- Fecha en particular a buscar
                    FECHA.PLLGTY = P_UDC
                GROUP BY DOCUMENTOTIPO_OC, DOCUMENTO_OC, COMPANIA, PLLGTY;
                SP_LOG('SP_FECHA_COPIA', 'Se recupera desde requisiciones la fecha='||V_FECHAMAXIMA);
            EXCEPTION WHEN NO_DATA_FOUND THEN
                -- No hay requisisciones asociadas o no tienen la fecha (P_UDC) que se busca.
                -- Buscamos la fecha máxima de las fecha de compromiso.
                SELECT PK_COMMONS.F_G2JDE( MAX(FECHA_COMPROMISO) )
                INTO   V_FECHAMAXIMA
                FROM   T_COMP_PRODTO_PROVEEDR_GESTION
                WHERE  DOCUMENTOTIPO_OC = P_DOCUMENTOTIPO_OC AND DOCUMENTO_OC = P_DOCUMENTO_OC;
                SP_LOG('SP_FECHA_COPIA', 'Se recupera desde la fecha compromiso la fecha='||V_FECHAMAXIMA);
            END;

            -- Con la fecha obtenida mando a crear
            SP_FECHA_INSERTA (P_DOCUMENTOTIPO_OC, P_DOCUMENTO_OC, P_UDC, V_FECHAMAXIMA, P_COMPANIA);

        ELSE
            SP_LOG('SP_FECHA_COPIA', 'Ya tiene fecha='||V_FECHAMAXIMA ||' no se hace nada.');
        END IF;

    END;

	/*
	** Propósito: Hace UPDATE los objetos de costo desde la H2 hacia la OC:
    **       H2 F4311T -> OC F4311T
	** Parámetros:
    **  P_DOCUMENTOTIPO VARCHAR2: Entrada. CM, CN, BN, etc.
    **  P_DOCUMENTO     NUMBER:   Entrada. Número de documento.
    */
    PROCEDURE SP_COPIA_OBJS_COSTO_F4311T(P_DOCUMENTOTIPO_OC VARCHAR2, P_DOCUMENTO_OC NUMBER)
    AS
    BEGIN
        -- Log de lo que ha llegado.
        SP_LOG('SP_COPIA_OBJS_COSTO_F4311T_V2', 'Inicio DOCUMENTOTIPO_OC='||P_DOCUMENTOTIPO_OC||' DOCUMENTO_OC='||P_DOCUMENTO_OC);

        FOR DTA IN (
            WITH
                -- Recupero los objetos de costo (F4311T) de las H2 que fueron gestionadas y los enumero
                W_GESTION AS(
                    SELECT
                        ROW_NUMBER() OVER (ORDER BY GST.LINEA) AS NUM,
                        GST.LINEA,
                        GST.DOCUMENTOTIPO,
                        GST.DOCUMENTO,
                        REQ.PDLNID, REQ.PDABT1, REQ.PDABR1, REQ.PDABT2, REQ.PDABR2, REQ.PDABT3, REQ.PDABR3, REQ.PDABT4, REQ.PDABR4
                    FROM
                        T_COMP_F4311_GESTION GST,
                        F4311T@JDEDTADL      REQ
                    WHERE REQ.PDLNID=GST.LINEA AND REQ.PDDCTO=GST.DOCUMENTOTIPO AND REQ.PDDOCO=GST.DOCUMENTO
                            AND
                          GST.DOCUMENTOTIPO_OC = P_DOCUMENTOTIPO_OC AND GST.DOCUMENTO_OC = P_DOCUMENTO_OC
                            AND
                          GST.DOCUMENTOTIPO = 'H2'
                    ORDER BY GST.LINEA
                ),
                -- Listo las líneas F4311T de la OC que fueron generadas y las enumero
                -- Se supone que estas líneas siempre son en la misma cantidad o menos
                -- que las líneas H2 debido a la agrupación.
                W_F4311T_OC AS(
                    SELECT
                        ROW_NUMBER() OVER (ORDER BY PDLNID) AS NUM,
                        PDLNID,
                        PDDCTO,
                        PDDOCO
                    FROM F4311T@JDEDTADL
                    WHERE
                        PDDCTO=P_DOCUMENTOTIPO_OC AND PDDOCO=P_DOCUMENTO_OC
                    ORDER BY PDLNID
                )
                -- Hago JOIN de ambas por su numeración
                SELECT
                    GST.LINEA         AS ORG_LINEA,
                    GST.DOCUMENTOTIPO AS ORG_TIPO,
                    GST.DOCUMENTO     AS ORG_DOC,
                    GST.PDLNID        AS ORG_PDLNID,
                    GST.PDABT1        AS ORG_PDABT1,
                    GST.PDABR1        AS ORG_PDABR1,
                    GST.PDABT2        AS ORG_PDABT2,
                    GST.PDABR2        AS ORG_PDABR2,
                    GST.PDABT3        AS ORG_PDABT3,
                    GST.PDABR3        AS ORG_PDABR3,
                    GST.PDABT4        AS ORG_PDABT4,
                    GST.PDABR4        AS ORG_PDABR4,
                    -------------------------------
                    DST.PDLNID  AS DST_LINEA,
                    DST.PDDCTO  AS DST_TIPO,
                    DST.PDDOCO  AS DST_DOC
                FROM
                    W_F4311T_OC  DST,
                    W_GESTION    GST
                WHERE
                    DST.NUM = GST.NUM
        )
        LOOP
            -- Hago el UPDATE de los objetos de costo de la OC
            UPDATE F4311T@JDEDTADL DST
            SET
                PDABT1 = DTA.ORG_PDABT1,
                PDABR1 = DTA.ORG_PDABR1,
                PDABT2 = DTA.ORG_PDABT2,
                PDABR2 = DTA.ORG_PDABR2,
                PDABT3 = DTA.ORG_PDABT3,
                PDABR3 = DTA.ORG_PDABR3,
                PDABT4 = DTA.ORG_PDABT4,
                PDABR4 = DTA.ORG_PDABR4
            WHERE
                DST.PDLNID=DTA.DST_LINEA AND DST.PDDCTO=P_DOCUMENTOTIPO_OC AND DST.PDDOCO=P_DOCUMENTO_OC;
            SP_LOG('SP_COPIA_OBJS_COSTO_F4311T_V2', 'UPDATE DTA.DST_LINEAD='||DTA.DST_LINEA||' rows='||TO_Char(SQL%ROWCOUNT));
        END LOOP;

    EXCEPTION WHEN OTHERS THEN
        SP_LOG('SP_COPIA_OBJS_COSTO_F4311T_V2', 'ERROR DOCUMENTOTIPO_OC="'||P_DOCUMENTOTIPO_OC||'" DOCUMENTO_OC='||P_DOCUMENTO_OC||' '||SQLERRM);
    END;

	/*
	** Propósito: Hace UPDATE los objetos de costo en la F43121T
    **       OC F4311T -> OC F43121T
	** Parámetros:
    **  P_DOCUMENTOTIPO VARCHAR2: Entrada. CM, CN, BN, etc.
    **  P_DOCUMENTO     NUMBER:   Entrada. Número de documento.
    */
    PROCEDURE SP_COPIA_OBJS_COSTO_F43121T(P_DOCUMENTOTIPO_OC VARCHAR2, P_DOCUMENTO_OC NUMBER)
    AS
    BEGIN
        -- Log de lo que ha llegado.
        SP_LOG('SP_COPIA_OBJS_COSTO_F43121T', 'Inicio DOCUMENTOTIPO_OC='||P_DOCUMENTOTIPO_OC||' DOCUMENTO_OC='||P_DOCUMENTO_OC);

        FOR ORG IN (
            SELECT *
            FROM   F4311T@JDEDTADL
            WHERE  PDDCTO=P_DOCUMENTOTIPO_OC AND PDDOCO=P_DOCUMENTO_OC
        )
        LOOP
            UPDATE F43121T@JDEDTADL
            SET
                PRABT1 = ORG.PDABT1,
                PRABR1 = ORG.PDABR1,
                PRABT2 = ORG.PDABT2,
                PRABR2 = ORG.PDABR2,
                PRABT3 = ORG.PDABT3,
                PRABR3 = ORG.PDABR3,
                PRABT4 = ORG.PDABT4,
                PRABR4 = ORG.PDABR4
            WHERE
                PRLNID = ORG.PDLNID AND PRDCTO=P_DOCUMENTOTIPO_OC AND PRDOCO=P_DOCUMENTO_OC;
            SP_LOG('SP_COPIA_OBJS_COSTO_F43121T', 'UPDATE PDLNID='||ORG.PDLNID||' rows='||TO_Char(SQL%ROWCOUNT));
        END LOOP;

    EXCEPTION WHEN OTHERS THEN
        SP_LOG('SP_COPIA_OBJS_COSTO_F43121T', 'ERROR DOCUMENTOTIPO_OC="'||P_DOCUMENTOTIPO_OC||'" DOCUMENTO_OC='||P_DOCUMENTO_OC||' '||SQLERRM);
    END;

	/*
	** Propósito: Cambia una determinada fecha en JDE F4305.
	** Parámetros:
    **  P_DOCUMENTOTIPO VARCHAR2: Entrada. CM, CN, BN, etc.
    **  P_DOCUMENTO     NUMBER:   Entrada. Número de documento.
    **  P_UDC           VARCHAR2: Entrada. Columna F4305.PLLGTY a buscar.
    **
    **  P_FECHAJDE      NUMBER:   Entrada. Fecha en formato JDE a colocar en la columna F4305.PLISSU
    */
    PROCEDURE SP_FECHA_CAMBIA (P_DOCUMENTOTIPO VARCHAR2, P_DOCUMENTO NUMBER, P_UDC VARCHAR2, P_FECHAJDE NUMBER, P_COMPANIA VARCHAR2)
    AS
        V_FECHA_ANTERIOR NUMBER;
        V_LABEL          VARCHAR2(100);
    BEGIN
        -- Log de lo que ha llegado.
        SP_LOG('SP_FECHA_CAMBIA', 'Inicio DOCUMENTOTIPO='||P_DOCUMENTOTIPO||' DOCUMENTO='||P_DOCUMENTO||' UDC='||P_UDC||' FECHAJDE='||P_FECHAJDE);

        -- Busco la fecha que tiene al momento.
        SELECT PLISSU, PLDL01
        INTO   V_FECHA_ANTERIOR, V_LABEL
        FROM   F4305@jdedtadl
        WHERE  PLDCTO=P_DOCUMENTOTIPO AND PLDOCO=P_DOCUMENTO AND PLLGTY=P_UDC AND PLKCOO=P_COMPANIA;

        -- Hago el update.
        UPDATE F4305@jdedtadl
        SET    PLISSU = P_FECHAJDE
        WHERE PLDCTO=P_DOCUMENTOTIPO AND PLDOCO=P_DOCUMENTO AND PLLGTY=P_UDC AND PLKCOO=P_COMPANIA;

        -- Log de lo que hice
        SP_LOG('SP_FECHA_CAMBIA', 'CAMBIADO A '||P_FECHAJDE||' ANTERIOR PLISSU='||V_FECHA_ANTERIOR||' PLDL01='||V_LABEL);
    END;


	/*
	** Propósito: Cambia el estado de una LINEA en F4311@JDEDTADL.
	** Parámetros:
    **  P_DOCUMENTOTIPO VARCHAR2: Entrada. CM, CN, BN, etc.
    **  P_DOCUMENTO     NUMBER:   Entrada. Número de documento.
    **  P_ESTADO_ANT    NCHAR:    Entrada. A colocar en PDLTTR
    **  P_ESTADO_SIG    NCHAR:    Entrada. A colocar en PDNXTR
    **
    */
    PROCEDURE SP_ESTADO_CAMBIA (P_DOCUMENTOTIPO VARCHAR2, P_DOCUMENTO NUMBER, P_LINEA NUMBER, P_ESTADO_ANT NCHAR, P_ESTADO_SIG NCHAR)
    AS
    BEGIN
        -- Log de lo que ha llegado.
        SP_LOG('SP_ESTADO_CAMBIA', 'Inicio DOCUMENTOTIPO='||P_DOCUMENTOTIPO||' DOCUMENTO='||P_DOCUMENTO||' LINEA='||P_LINEA||' ESTADO_ANT='||P_ESTADO_ANT||' ESTADO_SIG='||P_ESTADO_SIG);
        UPDATE F4311@JDEDTADL
        SET
            PDLTTR = P_ESTADO_ANT,
            PDNXTR = P_ESTADO_SIG
        WHERE PDDCTO = P_DOCUMENTOTIPO AND PDDOCO = P_DOCUMENTO AND PDLNID = P_LINEA*1000;
    END;

	/*
	** Propósito: Inicia un flujo de aprobación estandar para una determinada OC.
	** Parámetros:
    **  P_DOCUMENTOTIPO_OC    VARCHAR2: Entrada. CM, CN, BN, etc.
    **  P_DOCUMENTO_OC        NUMBER:   Entrada. Número de documento.
    */
    PROCEDURE SP_FLUJOENVIAR_OC(P_DOCUMENTOTIPO_OC VARCHAR2, P_DOCUMENTO_OC NUMBER)
    AS
        V_EXITO          VARCHAR(1000);
        V_REQUISITOR     NUMBER;
        V_REQUISITOR_USR VARCHAR2(100);
    BEGIN
        -- Log de lo que que he recibido
        SP_LOG('SP_FLUJOENVIAR_OC', 'Inicio DOCUMENTOTIPO_OC="'||P_DOCUMENTOTIPO_OC||'" DOCUMENTO_OC='||P_DOCUMENTO_OC);

        -- Recupero información para construir la ruta
        FOR RUTA IN (
            WITH
                W_DATA_OC AS (
					SELECT
                        DOCUMENTOTIPO_OC AS DOCUMENTOTIPO_OC,
                        CODBODEGA        AS CODBODEGA,
                        CODPROVEEDOR     AS CODPROVEEDOR,
                        DET_CODPROVEEDOR AS DET_CODPROVEEDOR,

                        USUARIO          AS USUARIO,
                        COMPANIA         AS COMPANIA,

                        COUNT(1)         AS CANTIDAD
                    FROM
                        VT_COMP_PENDIENTE_GENERAR_OC
                    WHERE
                        DOCUMENTOTIPO_OC=P_DOCUMENTOTIPO_OC AND DOCUMENTO_OC=P_DOCUMENTO_OC
                    GROUP BY
                        CODPROVEEDOR, DET_CODPROVEEDOR, USUARIO, COMPANIA, RESERVA, INCOTERM, FORMAPAGO, DOCUMENTOTIPO_OC, CODBODEGA, MODO_AGRUPADO
                )
                SELECT
                    DATA_OC.DET_CODPROVEEDOR  AS OBJETODESCRIPCION,
                    DATA_OC.USUARIO           AS USUARIO,
                    DATA_OC.COMPANIA          AS COMPANIA,

                    RUTA.TIPO1,
                    RUTA.TIPO2
                FROM
                    W_DATA_OC                           DATA_OC,
                    VT_COMP_RUTA_APROBACION_CONFIGURADA RUTA
                WHERE
                    TRIM(DATA_OC.CODBODEGA) = RUTA.CODBODEGA
                        AND
                    DATA_OC.DOCUMENTOTIPO_OC=RUTA.TIPO2
                        AND
                    ROWNUM <= 1        --- Por si acaso se dupliquen las rutas en JDE
        )
        LOOP
            -- Log de lo que que voy a hacer
            SP_LOG('SP_FLUJOENVIAR_OC', 'Ruta TIPO1='||RUTA.TIPO1||' TIPO2='||RUTA.TIPO2);

            -- Determino el requisitor
            BEGIN
                SELECT MAX(REQUISITOR) INTO V_REQUISITOR     FROM T_COMP_F4311_GESTION WHERE DOCUMENTOTIPO_OC=P_DOCUMENTOTIPO_OC AND DOCUMENTO_OC=P_DOCUMENTO_OC AND REQUISITOR IS NOT NULL;
                SELECT NOMBREUSUARIO   INTO V_REQUISITOR_USR FROM VT_CORP_USUARIO WHERE CODERP=V_REQUISITOR;
            EXCEPTION WHEN OTHERS THEN
                V_REQUISITOR_USR := RUTA.USUARIO;
                SP_LOG('SP_FLUJOENVIAR_OC', 'Sin requisitor '||SQLERRM);
            END;

            -- Envio la orden a flujo de aprobacion estandar
            pk_corp_flujoaprobacion.sp_flujoenviar(
                p_id					=> P_DOCUMENTO_OC
                , p_objeto				=> P_DOCUMENTOTIPO_OC
                , p_objetodescripcion	=> RUTA.OBJETODESCRIPCION
                , p_usuario				=> V_REQUISITOR_USR
                , p_modulo				=> 'COMP'
                , p_compania			=> RUTA.COMPANIA
                , p_codigopagina		=> 'COMPP101'
                , p_tipo1				=> RUTA.TIPO1
                , p_tipo2				=> RUTA.TIPO2

                , p_exito				=> V_EXITO
            );
            -- Log del resultado
            SP_LOG('SP_FLUJOENVIAR_OC', 'EXITO='||V_EXITO);

            -- Verifico si fue exitoso
            if V_EXITO = 0 then
                raise_application_error(-20000,'Error al enviar a flujo: '||V_EXITO);
            end if;

        END LOOP;

        SP_LOG('SP_FLUJOENVIAR_OC', 'Fin DOCUMENTOTIPO_OC="'||P_DOCUMENTOTIPO_OC||'" DOCUMENTO_OC='||P_DOCUMENTO_OC);
    END;

	/*
	** Propósito: Notifica al supervisor que un OC de reserva ha sido generada
	** Parámetros:
    **  P_DOCUMENTOTIPO_OC    VARCHAR2: Entrada. CM, CN, BN, etc.
    **  P_DOCUMENTO_OC        NUMBER:   Entrada. Número de documento.
    **  P_USUARIO             VARCHAR2: Entrada. CM, CN, BN, etc.
    */
    PROCEDURE SP_NOTIFICA_OC_RESERVA(P_DOCUMENTOTIPO_OC VARCHAR2, P_DOCUMENTO_OC NUMBER, P_USUARIO VARCHAR2)
    AS
        V_USUARIO_CEDULA    VARCHAR2(50);
        V_SUPERVISOR_CEDULA VARCHAR2(50);
        V_SUPERVISOR_EMAIL  VARCHAR2(50);
        V_BODY              CLOB;
        V_BODYHTML          CLOB;
    BEGIN
        -- Log de lo que que he recibido
        SP_LOG('SP_NOTIFICA_OC_RESERVA', 'Inicio DOCUMENTOTIPO_OC="'||P_DOCUMENTOTIPO_OC||'" DOCUMENTO_OC='||P_DOCUMENTO_OC|| ' USUARIO='||P_USUARIO);
        -- Determino la cédula del usuario
        SELECT NUMEROIDENTIFICACION INTO V_USUARIO_CEDULA FROM VT_CORP_USUARIO WHERE NOMBREUSUARIO=P_USUARIO;
        -- Determino la cédula del supervisor
        V_SUPERVISOR_CEDULA := pk_commons.f_cedula_supervisor(V_USUARIO_CEDULA);
        -- Determino el email del supervisor
        SELECT EMAIL INTO V_SUPERVISOR_EMAIL FROM VT_CORP_USUARIO WHERE NUMEROIDENTIFICACION = V_SUPERVISOR_CEDULA;
        -- Hago la composición del email;
        V_BODY := '<html lang="es" ><head><meta charset="utf-8"><meta http-equiv="X-UA-Compatible" content="IE=edge"></head><body>';
        V_BODY := V_BODY||'Estimad@ usuari@:<br/><br/>';
        V_BODY := V_BODY||'Se le comunica que el usuario '||P_USUARIO||' ha generado una OC de reserva:<br/>';
        V_BODY := V_BODY||'<strong>Tipo:</strong> '||P_DOCUMENTOTIPO_OC||'<br/>';
        V_BODY := V_BODY||'<strong>Documento:</strong> '||P_DOCUMENTO_OC||'<br/>';
        V_BODY := V_BODY||'<br/>';
        V_BODY := V_BODY||'Pariticular que se pone en su conocimiento para los fines pertinentes<br/><br/>Att.<br/>Módulo de compras.';
        -- Control del ambiente de prueba
        IF (NOT PK_CORP_COMMONS.F_ISPRODUCCION) THEN
            V_BODY := V_BODY||'<hr><div>'||V_SUPERVISOR_EMAIL||'</div>';
            V_SUPERVISOR_EMAIL := 'dcueva@zaimella.com,pruebas.zaimella@gmail.com';
        END IF;
        V_BODY := V_BODY||'</body></html>';
        -- Envío el email
        PK_COMMONS.sp_apex_correohtml(V_BODY, V_BODYHTML);
        PK_COMMONS.sp_apex_correo(
            'COMP',
            'notificacion@zaimella.com',
            V_SUPERVISOR_EMAIL,
            null,
            null,
            'Módulo de compras : OC de reserva generada '||P_DOCUMENTOTIPO_OC||' '||P_DOCUMENTO_OC,
            V_BODYHTML
        );

    EXCEPTION WHEN OTHERS THEN
        SP_LOG('SP_NOTIFICA_OC_RESERVA', 'ERROR DOCUMENTOTIPO_OC="'||P_DOCUMENTOTIPO_OC||'" DOCUMENTO_OC='||P_DOCUMENTO_OC||' '||SQLERRM||' : '||DBMS_UTILITY.format_error_backtrace);
    END;

	/*
	** Propósito: Procesa el XML de error retornado por JDE
	** Parámetros:
    **  P_TRAMA       CLOB: Entrada.
    **  P_DETALLE     VARCHAR2: Salida.
	*/
    PROCEDURE SP_RECUPERA_ERROR_XML (P_TRAMA CLOB, P_DETALLE OUT VARCHAR2)
    AS
    BEGIN
        P_DETALLE := DBMS_LOB.SUBSTR(P_TRAMA, 1500, 1);
        P_DETALLE := replace(P_DETALLE, '&#xd;', ' ');
        P_DETALLE := regexp_replace(P_DETALLE, '<.*?>');
    EXCEPTION WHEN OTHERS THEN
        P_DETALLE := 'ERROR='||SQLERRM;
    END;

	/*
	** Propósito: Log propietario. Tiene la virtud de grabar el log a pesar de un posible rollback.
	** Parámetros:
    **  P_PROCESO          VARCHAR2: Entrada.
    **  P_DESCRIPCION      VARCHAR2: Entrada.
	*/
    PROCEDURE SP_LOG  (P_PROCESO VARCHAR2, P_DESCRIPCION VARCHAR2) AS PRAGMA AUTONOMOUS_TRANSACTION;
        v_session_id  NUMBER;
    BEGIN
        SELECT SYS_CONTEXT('USERENV', 'SID') INTO v_session_id FROM DUAL;
        PK_COMMONS.SP_APEX_LOG('COMP',
                               v_session_id,
                               P_PROCESO,
                               NULL,
                               P_DESCRIPCION,
                               NULL
                              );
        COMMIT;
    END;

    /*
    ** Coloca un valor en la columna MODO_AGRUPADO
    ** Para agrupar las líneas OC por fecha compromiso
    ** y generar varias OC por fecha compromiso
    */
    PROCEDURE SP_MODO_AGRUPADO_ON(P_USUARIO VARCHAR2, P_COMPANIA VARCHAR2)
    AS
    BEGIN
        -- Log de lo que que he recibido
        SP_LOG('SP_MODO_AGRUPADO_ON', 'Inicio USUARIO='||P_USUARIO);
        FOR PPGESTION IN (
            SELECT *
            FROM T_COMP_PRODTO_PROVEEDR_GESTION
            WHERE
                COMPANIA     = P_COMPANIA
                    AND
                USUARIO      = P_USUARIO
                    AND
                FECHA_PROCESADO IS NULL
        )
        LOOP
            UPDATE  T_COMP_PRODTO_PROVEEDR_GESTION
            SET MODO_AGRUPADO = TO_CHAR(NVL(FECHA_COMPROMISO, SYSDATE+2), 'YYYY/MM/DD')
            WHERE ID = PPGESTION.ID;
            SP_DEL_PPGESTION_NEGOCIACION(PPGESTION.ID);
        END LOOP;
    END;

    /*
    ** Pone null en la columna MODO_AGRUPADO
    ** para permitir que se agrupen las líneas en una sola OC
    */
    PROCEDURE SP_MODO_AGRUPADO_OFF(P_USUARIO VARCHAR2, P_COMPANIA VARCHAR2)
    AS
    BEGIN
        UPDATE  T_COMP_PRODTO_PROVEEDR_GESTION
        SET MODO_AGRUPADO = NULL
        WHERE
            COMPANIA     = P_COMPANIA
                AND
            USUARIO      = P_USUARIO
                AND
            FECHA_PROCESADO IS NULL;
    END;

    /*
    ** Genera una nueva T_COMP_PRODTO_PROVEEDR_GESTION a partir de
    ** una existente.
    ** Se usa para el modo agrupado.
    */
    PROCEDURE SP_DUPLICA_PPGESTION(P_PPGESTIONID NUMBER)
    AS
        V_ID   NUMBER;
    BEGIN
        -- Log de lo que ha llegado.
        SP_LOG('SP_DUPLICA_PPGESTION', 'Inicio P_PPGESTIONID='||P_PPGESTIONID);

        PK_COMMONS.SP_SECUENCIA('T_COMP_PRODTO_PROVEEDR_GESTION', V_ID);
        INSERT INTO T_COMP_PRODTO_PROVEEDR_GESTION
               (ID, COMPANIA, USUARIO,
               CODIGOCORTOPRODUCTO, UNIDADMEDIDA, TIPO_REQUISICION, BODEGA, REQUISITOR, DESTINO,
               CON_REQUISICION, BODEGATIPO, CANTIDAD, CANTIDAD_MANUAL, JUSTIFICACION,
               DESCRIPCION1, DESCRIPCION2,  RESERVA, FECHA_REGISTRO,
               COMENTARIO_PROVEEDOR, COMENTARIO_APROBADOR,
               MODO_AGRUPADO, FECHA_COMPROMISO)
        SELECT V_ID, COMPANIA, USUARIO,
               CODIGOCORTOPRODUCTO, UNIDADMEDIDA, TIPO_REQUISICION, BODEGA, REQUISITOR, DESTINO,
               CON_REQUISICION, BODEGATIPO, CANTIDAD, CANTIDAD_MANUAL, JUSTIFICACION,
               DESCRIPCION1, DESCRIPCION2,  RESERVA, SYSDATE,
               COMENTARIO_PROVEEDOR, COMENTARIO_APROBADOR,
               TO_CHAR(NVL(FECHA_COMPROMISO, SYSDATE+2), 'YYYY/MM/DD'), FECHA_COMPROMISO
        FROM T_COMP_PRODTO_PROVEEDR_GESTION WHERE ID = P_PPGESTIONID;

        SP_LOG('SP_DUPLICA_PPGESTION', 'Resultado V_ID='||V_ID||' rcount='||SQL%ROWCOUNT);
    END;

	PROCEDURE SP_NOTIFICAR (
		p_compania		in varchar2,
		p_usuario		in varchar2,
		p_ordencompra	in number,
		p_tipoorden		in varchar2,
		p_opcion		in varchar2,
		p_respuesta		out number
	) as
	v_mensaje	clob;
	v_ordencompra		number;
	v_tipoorden			varchar2(5);
	v_opcion			varchar2(50);
	v_comp_anticipos	data.vt_comp_anticipos%rowtype;
	v_comp_anticiposdet	data.t_comp_anticiposdet%rowtype;
	begin
		v_log_app		:= 'pk_comp_gestioncompras.sp_notificar';
		v_compania		:= p_compania;
		v_usuario		:= p_usuario;
		v_opcion		:= p_opcion;
		v_ordencompra	:= p_ordencompra;
		v_tipoorden		:= p_tipoorden;

		v_mensaje := '<html><head>
							<style type="text/css">body{font-family: Arial,Helvetica,sans-serif;
							font-size:10pt; margin:30px; background-color:#ffffff;}
							span.sig{font-style:italic;font-weight:bold;color:#811919;}}
							</style>
							</head><meta charset="UTF-8"><body>'||utl_tcp.crlf;

		if v_opcion = 'ANTICIPO_APROBADO' then
			begin
				select * into v_comp_anticipos from data.vt_comp_anticipos where idcab = v_ordencompra;

				exception when others then p_respuesta := -1; return;
			end;

			v_cor_sub := 'COMP - Solicitud de Pago Anticipado para la OC '||v_comp_anticipos.tipoorden||'-'||v_comp_anticipos.ordencompra;
			v_cor_des := 'tesoreria@zaimella.com,contabilidad@zaimella.com';
			v_cor_ccp := pk_commons.f_correousuario(v_comp_anticipos.usercrea);

			v_mensaje := v_mensaje || '<h3>Se ha aprobado una Solicitud de Pago Anticipado</h3>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p><strong>Proveedor</strong>: '||v_comp_anticipos.codproveedor||'-'||v_comp_anticipos.proveedor||'</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p><strong>Tipo de Anticipo</strong>: '||v_comp_anticipos.tipoanticipo||'</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p><strong>Solicitado por</strong>: '||pk_commons.f_nombreusuario(v_comp_anticipos.usuarioiniciador)||'</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p><strong>Cantidad Pagos</strong>: '||v_comp_anticipos.cantidadpagos||'</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p><strong>Primer Pago</strong>: '||v_comp_anticipos.primerpago||'</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p><strong>Último Pago</strong>: '||v_comp_anticipos.ultimopago||'</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p><strong>Monto Total</strong>: '||to_char(v_comp_anticipos.montototal,'FML999G999G999G999G990D00')||'</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p><strong>Justificación</strong>: '||v_comp_anticipos.justificacion||'</p>'||utl_tcp.crlf;
		elsif v_opcion = 'PAGO_ANTICIPO' then
			begin
				select * into v_comp_anticiposdet from data.t_comp_anticiposdet where id = v_ordencompra;

				exception when others then p_respuesta := -1; return;
			end;

			begin
				select * into v_comp_anticipos from data.vt_comp_anticipos where idcab = v_comp_anticiposdet.idcab;

				exception when others then p_respuesta := -2; return;
			end;
			v_cor_sub := 'COMP - Pago '||lpad(v_comp_anticiposdet.idpago,2,'0')||' realizado de la Orden '||v_comp_anticipos.tipoorden||'-'||v_comp_anticipos.ordencompra;
			v_cor_ccp := 'tesoreria@zaimella.com';
			v_cor_des := pk_commons.f_correousuario(v_comp_anticiposdet.usercrea);

			v_mensaje := v_mensaje || '<h3>Se ha realizado un pago con la siguiente información:</h3>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p><strong>Proveedor</strong>: '||v_comp_anticipos.codproveedor||'-'||v_comp_anticipos.proveedor||'</p>'||utl_tcp.crlf;
			v_mensaje := v_mensaje || '<p><strong>Monto Pagado</strong>: '||to_char(v_comp_anticiposdet.montopagado,'FML999G999G999G999G990D00')||'</p>'||utl_tcp.crlf;
			if v_comp_anticiposdet.observacionini is not null then
				v_mensaje := v_mensaje || '<p><strong>Observación Inicial</strong>: '||v_comp_anticiposdet.observacionini||'</p>'||utl_tcp.crlf;
			end if;

			if v_comp_anticiposdet.observacionfin is not null then
				v_mensaje := v_mensaje || '<p><strong>Observación Final</strong>: '||v_comp_anticiposdet.observacionfin||'</p>'||utl_tcp.crlf;
			end if;

			v_mensaje := v_mensaje || '<p><strong>Fecha</strong>: '||to_char(v_comp_anticiposdet.fechmodi,'dd/mm/yyyy hh24:mi')||'</p>'||utl_tcp.crlf;
		end if;
		v_mensaje := v_mensaje || '</body>'||utl_tcp.crlf;
		v_mensaje := v_mensaje || '</html>'||utl_tcp.crlf;

		data.pk_commons.sp_apex_correohtml(v_mensaje,v_mensaje);
		-- v_cor_des := 'ddelacruz@zaimella.com'; v_cor_ccp := null;

		data.pk_commons.sp_apex_correo(
			p_aplicacion		=> v_log_app
			, p_remitente		=> v_cor_rem
			, p_para			=> v_cor_des
			, p_concopia		=> v_cor_ccp
			, p_concopiaoculta	=> null
			, p_asunto			=> v_cor_sub
			, p_contenido		=> v_mensaje
		);
	end sp_notificar;

	-- ============================================================
	--  sp_informacionproducto
	--  Paquete : data.pk_comp_gestioncompras
	--  Fecha   : 2026-02-19
	-- ------------------------------------------------------------
	--  Propósito:
	--    Calcula y devuelve en formato JSON la información de
	--    inventario, consumo y costos de un producto asociado a
	--    una orden de compra.
	--
	--  Parámetros de entrada:
	--    p_compania      Código de compañía (filtra pdkcoo en JDE)
	--    p_bodega        Código de bodega SIN padding (trim aplicado por el llamador)
	--    p_tipoorden     Tipo de documento (ej: 'CT', 'CN', 'BN')
	--    p_numeroorden   Número de orden de compra
	--    p_producto      Código corto de producto (pditm, numérico)
	--
	--  Parámetro de salida:
	--    p_respuesta     JSON con la información del producto.
	--                    Retorna NULL si no se localiza el detalle.
	--
	--  Fuentes de datos:
	--    data.vt_comp_ordencompradet   Detalle de OC (f4311 + f4101 + f0101 + f0006)
	--    f42119@jdedtadl              Histórico ventas (consumo CT/VF) — sin vista disponible
	--    f4211@jdedtadl               Ventas abiertas (consumo DS)     — sin vista disponible
	--    f41021@jdedtadl              Stock por bodega                 — sin vista disponible
	--    f4102@jdedtadl               Reglas de acopio (mín/máx)       — sin vista disponible
	--
	--  Observaciones de implementación:
	--    [A] vt_comp_ordencompradet aplica trim(pdlitm) y trim(pdmcu).
	--        Al comparar pdlitm contra sdlitm (f42119/f4211) e iblitm (f4102),
	--        que conservan padding en JDE, se aplica trim() en ambos extremos.
	--        Esto inhibe índices en esas columnas; aceptable porque la consulta
	--        siempre está acotada a un único producto.
	--    [B] pdaddj en la vista ya es DATE (pasó por data.pk_commons.f_jde2g).
	--        ultimafecha se almacena como DATE en el record, no como NUMBER.
	--    [C] pdprrc, pduorg, pdpqor, pduopn ya vienen divididos por su factor
	--        en la vista. No se re-aplica la división.
	--    [D] Opción B: el procedimiento solo construye y devuelve el JSON.
	--        El UPDATE sobre infoproducto es responsabilidad del llamador.
	--    [E] El JSON almacena valores numéricos sin formateo. El formateo
	--        visual queda en la página 103.
	-- ============================================================


	-- ------------------------------------------------------------
	--  [1/2]  SPEC
	--  Agregar la siguiente declaración dentro del spec del paquete
	--  data.pk_comp_gestioncompras, antes del END final.
	-- ------------------------------------------------------------
	procedure sp_informacionproducto (
		p_compania		in	varchar2
		, p_bodega		in	varchar2
		, p_tipoorden	in	varchar2
		, p_numeroorden	in	number
		, p_producto	in	number
		, p_respuesta	out	clob
	) is
		/*
			Record en memoria para acumular valores intermedios.
			No genera objetos de base de datos adicionales.
			ultimafecha es DATE porque la vista aplica data.pk_commons.f_jde2g
			sobre pdaddj antes de exponerlo (observación [B]).
		*/
		type t_infoproducto is record (
			producto			varchar2(200)
			, codigoproducto	varchar2(40)	-- pdlitm trimmed desde la vista; ver [A]
			, stock				number
			, stocktransito		number
			, consumopromedio	number
			, cantidad			number
			, cantidadpedida	number
			, precio			number
			, ultimoprecio		number
			, ultimafecha		date
			, cantidadmaxima	number
			, cantidadminima	number
			, dias				number
			, fechainicio		number			-- JDE numérico: YYYYDDD - 1900000
			, fechafin			number
			, codtipoproducto	varchar2(10)	-- tipo de producto: IN10 = Materia Prima
		);
		v_info t_infoproducto;
	begin
		v_log_app := 'pk_comp_gestioncompras.sp_informacionproducto';
		v_log_dsc := 'p_compania: '||p_compania||', p_bodega: '||p_bodega||', p_tipoorden: '||p_tipoorden||', p_numeroorden: '||p_numeroorden||', p_producto: '||p_producto;
		-- ----------------------------------------------------------
		--  1. Días de análisis según bodega
		--     Reproduce el decode(phmcu,...) de la vista original.
		--     Se calcula desde p_bodega para evitar una consulta
		--     remota adicional al header de la OC.
		-- ----------------------------------------------------------
		v_info.dias := case p_bodega
			when '17001' then 180
			when '17007' then 180
			when '17020' then 42
			else 20
		end;

		-- ----------------------------------------------------------
		--  2. Ventana de fechas en formato JDE numérico
		--     Requerido para los filtros sddrqj en f42119 y f4211,
		--     que conservan las fechas como NUMBER.
		-- ----------------------------------------------------------
		v_info.fechainicio	:= to_number(to_char(sysdate - v_info.dias, 'YYYYDDD') - 1900000);
		v_info.fechafin		:= to_number(to_char(sysdate, 'YYYYDDD') - 1900000);

		-- ----------------------------------------------------------
		--  3. Datos del detalle de la orden de compra
		--     Fuente: data.vt_comp_ordencompradet
		--     - pdkcoo filtra por compañía (p_compania).
		--     - pdmcu ya trimmed en la vista ¿ comparación directa con p_bodega.
		--     - pdlitm ya trimmed en la vista ¿ se almacena limpio para uso
		--       interno en los pasos 4 y 8 (observación [A]).
		--     - pdprrc, pduorg, pdpqor ya divididos (observación [C]).
		-- ----------------------------------------------------------
		select d.pdlitm
			, d.imdsc1
			, d.pdprrc
			, d.pduorg
			, d.pdpqor
			, d.imglpt
		into v_info.codigoproducto
			, v_info.producto
			, v_info.precio
			, v_info.cantidad
			, v_info.cantidadpedida
			, v_info.codtipoproducto
		from data.vt_comp_ordencompradet d
		where 1 = 1
			and d.pdkcoo	= p_compania
			and d.pddoco	= p_numeroorden
			and d.pddcto	= p_tipoorden
			and d.pditm		= p_producto
			and d.pdmcu		= p_bodega
			and rownum		= 1;

		v_log_msg := 'v_info.codigoproducto: '||v_info.codigoproducto||', v_info.producto: '||v_info.producto;

		-- ----------------------------------------------------------
		--  4. Consumo promedio
		--     Fuente: f42119 / f4211 directamente (sin vista disponible).
		--     trim(sdlitm) necesario por diferencia de padding (observación [A]).
		--     Bifurcación IF/ELSE permite planes de ejecución independientes
		--     por rama, a diferencia de la subconsulta correlacionada original.
		-- ----------------------------------------------------------
		-- 4. Consumo promedio
		if v_info.codtipoproducto = 'IN10' then
			-- Materia Prima: consumo desde Kardex de movimientos (f4111)
			select round(nvl(sum(abs(f.iltrqt)) / 10000, 0) / v_info.dias, 4)
			into v_info.consumopromedio
			from f4111@jdedtadl f
			where 1 = 1
				and f.ilitm		= p_producto
				and (
					f.ildct in ('IM', 'EZ', 'I5')
					or (f.ildct = 'IT' and f.ilmcu = '       17004')
				)
				and f.iltrdj	between v_info.fechainicio and v_info.fechafin;
		elsif p_tipoorden = 'CT' then
			-- Producto terminado tipo CT: histórico de ventas cerradas
			select round(nvl(sum(sdsoqs / 10000), 0) / v_info.dias, 4)
			into v_info.consumopromedio
			from f42119@jdedtadl
			where 1 = 1
				and sddcto			= 'VF'
				and trim(sdlitm)	= v_info.codigoproducto
				and sddrqj			between v_info.fechainicio and v_info.fechafin
				and sdlttr			= 620
				and sdnxtr			= 999;
		else
			-- Resto: órdenes de venta abiertas
			select round(nvl(sum(sdsoqs / 10000), 0) / v_info.dias, 4)
			into v_info.consumopromedio
			from f4211@jdedtadl
			where 1 = 1
				and sddcto			= 'DS'
				and trim(sdlitm)	= v_info.codigoproducto
				and sddrqj			between v_info.fechainicio and v_info.fechafin
				and sdlttr			= 620
				and sdnxtr			= 999;
		end if;

		-- ----------------------------------------------------------
		--  5. Stock actual
		--     Fuente: f41021 directamente (sin vista disponible).
		--     liitm es numérico ¿ comparación directa con p_producto sin trim.
		--     Bodegas excluidas: 17023, 17025, 17002 (tránsito/cuarentena).
		--     rownum = 1: comportamiento heredado de la vista original.
		-- ----------------------------------------------------------
		begin
			select decode(lipqoh, 0, 0, lipqoh / 10000)
			into v_info.stock
			from f41021@jdedtadl
			where 1 = 1
				and liitm	= p_producto
				and lipqoh	> 0
				and limcu	not in ('       17023', '       17025', '       17002')
				and rownum	= 1;
		exception
			when no_data_found then v_info.stock := 0;
		end;

		-- ----------------------------------------------------------
		--  6. Stock en tránsito
		--     Fuente: data.vt_comp_ordencompradet
		--     - pditm numérico ¿ comparación directa sin necesidad de pdlitm.
		--     - pduopn ya dividido en la vista (observación [C]).
		--     - pdmcu ya trimmed en la vista ¿ comparación directa con p_bodega.
		--     Estados de tránsito heredados de la vista original.
		-- ----------------------------------------------------------
		select nvl(sum(d.pduopn), 0)
		into v_info.stocktransito
		from data.vt_comp_ordencompradet d
		where 1 = 1
			and d.pditm		= p_producto
			and d.pddcto	in ('CN','BN','CM','BM')
			and d.pdmcu		= p_bodega
			and (
				(d.pdlttr = 280 and d.pdnxtr = 400)
				or (d.pdlttr = 240 and d.pdnxtr = 280)
				or (d.pdlttr = 400 and d.pdnxtr = 400)
			);

		-- ----------------------------------------------------------
		--  7. Último precio y fecha de compra
		--     Fuente: data.vt_comp_ordencompradet
		--     - pditm filtra en la subconsulta interna para evitar
		--       full scan sobre todos los ítems al hacer el GROUP BY.
		--     - pdaddj ya es DATE en la vista; se asigna directo al
		--       campo DATE del record (observación [B]).
		--     - pdaddj is not null reemplaza pdaddj > 0 del original,
		--       porque data.pk_commons.f_jde2g(0) retorna null.
		--     - pdprrc ya dividido en la vista (observación [C]).
		-- ----------------------------------------------------------
		begin
			select a.pdprrc
				, a.pdaddj
			into v_info.ultimoprecio
				, v_info.ultimafecha
			from data.vt_comp_ordencompradet a
			inner join (
				select pdlitm
					, pddcto
					, max(pddoco) as pddoco
				from data.vt_comp_ordencompradet x
				where 1 = 1
					and x.pditm		= p_producto
					and (x.pdlttr	= 400 or x.pdlttr = 385)
					and x.pdnxtr	= 999
					and x.pdaddj	is not null
					and x.pddcto	in ('BM', 'OI', 'CB', 'CE', 'CM', 'CN', 'CT')
				group by x.pdlitm, x.pddcto
			) b on a.pdlitm = b.pdlitm
				and a.pddoco = b.pddoco
				and a.pddcto = b.pddcto
			where 1 = 1
				and a.pditm = p_producto
				and (
					a.pddcto = p_tipoorden
					or (p_tipoorden in ('CN', 'BN') and a.pddcto in ('CN', 'OI'))
				)
				and rownum = 1;

			exception
				when no_data_found then
					v_info.ultimoprecio	:= 0;
					v_info.ultimafecha	:= null;
		end;

		-- ----------------------------------------------------------
		--  8. Cantidades de acopio máximo y mínimo
		--     Fuente: f4102 directamente (sin vista disponible).
		--     trim(iblitm) necesario por diferencia de padding (observación [A]).
		--     Las tres bodegas del IN son regla de negocio fija heredada
		--     de la vista original.
		-- ----------------------------------------------------------
		begin
			select ibrqmx / 10000
				, ibrqmn / 10000
			into v_info.cantidadmaxima
				, v_info.cantidadminima
			from f4102@jdedtadl
			where 1 = 1
				and trim(iblitm)	= v_info.codigoproducto
				and ibmcu			in ('       17001', '       17007', '       17020')
				and rownum			= 1;

			exception
				when no_data_found then
					v_info.cantidadmaxima	:= 0;
					v_info.cantidadminima	:= 0;
		end;

		-- ----------------------------------------------------------
		--  9. Construcción del JSON
		--     - Numéricos sin formateo; el formateo visual queda
		--       en la página 103 (observación [E]).
		--     - ultimafecha: to_char sobre DATE directo, o null.
		--     - replace en producto escapa comillas dobles para
		--       no generar JSON inválido.
		--     - ultimafechasalida: sysdate como referencia de cuándo
		--       se calculó la información.
		-- ----------------------------------------------------------
		-- ============================================================
		--  Corrección definitiva: paso 9 de sp_informacionproducto
		--  Problema  : to_char con 'TM9' respeta igualmente el NLS de
		--              sesión. La única forma de forzar punto como
		--              separador decimal es pasar el tercer argumento
		--              NLS_NUMERIC_CHARACTERS explícitamente.
		--  Solución  : to_char(valor, 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
		--              Esto sobreescribe el NLS de sesión en esa llamada
		--              puntual, sin alterar la configuración global.
		-- ============================================================

		-- 9. Construcción del JSON
		p_respuesta :=
			'{'
			|| '"producto":'                 || '"' || replace(v_info.producto, '"', '\"') || '"'
			|| ',"codigoproducto":'          || '"' || v_info.codigoproducto || '"'
			|| ',"codigocortoproducto":'     || to_char(p_producto,                                                                                          'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
			|| ',"stock":'                   || to_char(nvl(v_info.stock, 0),                                                                                'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
			|| ',"stocktransito":'           || to_char(nvl(v_info.stocktransito, 0),                                                                        'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
			|| ',"consumopromedio_diario":'  || to_char(nvl(v_info.consumopromedio, 0),                                                                      'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
			|| ',"consumopromedio_mensual":' || to_char(round(nvl(v_info.consumopromedio, 0) * 30, 4),                                                       'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
			|| ',"diasinventario":'          || to_char(
												round(
													nvl(v_info.stock, 0)
													/ case when nvl(v_info.consumopromedio, 0) = 0 then 1 else v_info.consumopromedio end
												, 2)
												, 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
			|| ',"ultimoprecio":'            || to_char(nvl(v_info.ultimoprecio, 0),                                                                         'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
			|| ',"ultimafecha":'             || case
												when v_info.ultimafecha is not null
												then '"' || to_char(v_info.ultimafecha, 'DD/MM/YYYY') || '"'
												else 'null'
											end
			|| ',"stocksimulado":'           || to_char(
												nvl(v_info.cantidad, 0) + nvl(v_info.stock, 0) + nvl(v_info.stocktransito, 0)
												, 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
			|| ',"diasinventariosim":'       || to_char(
												round(
													(nvl(v_info.cantidadpedida, 0) + nvl(v_info.stock, 0))
													/ case when nvl(v_info.consumopromedio, 0) = 0 then 1 else v_info.consumopromedio end
												, 2)
												, 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
			|| ',"variacionprecio":'         || case
												when nvl(v_info.ultimoprecio, 0) = 0 then '0'
												else to_char(
													round(
														100 * (nvl(v_info.precio, 0) - v_info.ultimoprecio) / v_info.ultimoprecio
													, 4)
													, 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
											end
			|| ',"cantidadmaxima":'          || to_char(nvl(v_info.cantidadmaxima, 0),                                                                      'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
			|| ',"cantidadminima":'          || to_char(nvl(v_info.cantidadminima, 0),                                                                       'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
			|| ',"ultimasalida":0'
			|| ',"ultimafechasalida":"'      || to_char(sysdate, 'DD/MM/YYYY HH24:MI:SS') || '"'
			|| '}';

		data.pk_commons.sp_apex_log(v_log_app,0,v_log_dsc,v_log_msg,v_log_obs,p_respuesta);

		exception
			when no_data_found then p_respuesta := null; data.pk_commons.sp_apex_log(v_log_app,-1,v_log_dsc,v_log_msg,v_log_obs,p_respuesta);
			when others then raise;
	end sp_informacionproducto;

	/*
		sp_kpi_historial_cantidad
		-------------------------
		Propósito:
			Genera la información de métricas (Stock Actual, Stock en Tránsito,
			Consumo Promedio Mensual, Días de Stock) e historial de órdenes de compra
			para el modal de Cantidad en la Mesa de Trabajo (Página 290).
		Parámetros:
			p_compania   IN  código de compañía
			p_producto   IN  código o id del producto
			p_proveedor  IN  código de proveedor (opcional)
			p_respuesta  OUT respuesta en formato JSON
	*/
	procedure sp_kpi_historial_cantidad (
		p_compania		in	varchar2
		, p_producto	in	varchar2
		, p_proveedor	in	varchar2 default null
		, p_respuesta	out	clob
	) is
		v_imitm				number;
		v_imlitm			varchar2(50);
		v_imdsc1			varchar2(200);
		v_imglpt			varchar2(10);
		v_imuom1			varchar2(10);
		v_descproveedor		varchar2(250);

		v_dias				number := 180;
		v_fechainicio		number;
		v_fechafin			number;

		v_stock				number := 0;
		v_stocktransito		number := 0;
		v_consumo_diario	number := 0;
		v_consumo_mensual	number := 0;
		v_dias_stock		number := 0;

		v_json_historial	clob := '';
		v_row_count			number := 0;
	begin
		v_log_app := 'pk_comp_gestioncompras.sp_kpi_historial_cantidad';
		v_log_dsc := 'p_compania: '||p_compania||', p_producto: '||p_producto||', p_proveedor: '||p_proveedor;
		data.pk_commons.sp_apex_log(v_log_app, 0, v_log_dsc, 'Inicia', v_log_obs, null);

		-- 1. Resolver producto
		begin
			select imitm, trim(imlitm), trim(imdsc1), trim(imglpt), trim(imuom1)
			into v_imitm, v_imlitm, v_imdsc1, v_imglpt, v_imuom1
			from f4101@jdedtadl
			where trim(imlitm) = trim(p_producto)
			   or imitm = case when regexp_like(p_producto, '^[0-9]+$') then to_number(p_producto) else -1 end
			and rownum = 1;
		exception
			when no_data_found then
				p_respuesta := '{"status":"EMPTY","producto":"","codigoproducto":"'||p_producto||'","proveedor":"","udm":"","stock_actual":0,"consumo_mensual":0,"dias_stock":0,"stock_transito":0,"historial":[]}';
				data.pk_commons.sp_apex_log(v_log_app, 1, v_log_dsc, 'Producto no encontrado', v_log_obs, p_respuesta);
				return;
		end;

		-- 2. Resolver proveedor si aplica
		if p_proveedor is not null then
			begin
				select trim(abalph)
				into v_descproveedor
				from f0101@jdedtadl
				where aban8 = case when regexp_like(p_proveedor, '^[0-9]+$') then to_number(p_proveedor) else -1 end
				and rownum = 1;
			exception
				when no_data_found then
					v_descproveedor := p_proveedor;
			end;
		end if;

		-- 3. Fechas para consumo
		v_fechainicio := to_number(to_char(sysdate - v_dias, 'YYYYDDD') - 1900000);
		v_fechafin    := to_number(to_char(sysdate, 'YYYYDDD') - 1900000);

		-- 4. Stock actual
		begin
			select nvl(sum(decode(lipqoh, 0, 0, lipqoh / 10000)), 0)
			into v_stock
			from f41021@jdedtadl
			where liitm = v_imitm
			  and lipqoh > 0
			  and limcu not in ('       17023', '       17025', '       17002');
		exception
			when others then
				v_stock := 0;
		end;

		-- 5. Consumo promedio
		begin
			if v_imglpt = 'IN10' then
				select round(nvl(sum(abs(f.iltrqt)) / 10000, 0) / v_dias, 4)
				into v_consumo_diario
				from f4111@jdedtadl f
				where f.ilitm = v_imitm
				  and (f.ildct in ('IM', 'EZ', 'I5') or (f.ildct = 'IT' and f.ilmcu = '       17004'))
				  and f.iltrdj between v_fechainicio and v_fechafin;
			else
				select round(nvl(sum(sdsoqs / 10000), 0) / v_dias, 4)
				into v_consumo_diario
				from f42119@jdedtadl
				where trim(sdlitm) = v_imlitm
				  and sddrqj between v_fechainicio and v_fechafin
				  and sdlttr = 620 and sdnxtr = 999;
			end if;
		exception
			when others then
				v_consumo_diario := 0;
		end;

		v_consumo_mensual := round(nvl(v_consumo_diario, 0) * 30, 2);

		if nvl(v_consumo_diario, 0) > 0 then
			v_dias_stock := round(v_stock / v_consumo_diario, 1);
		else
			v_dias_stock := 0;
		end if;

		-- 6. Stock en tránsito
		begin
			select nvl(sum(d.pduopn), 0)
			into v_stocktransito
			from data.vt_comp_ordencompradet d
			where d.pditm = v_imitm
			  and (
			      (d.pdlttr = 280 and d.pdnxtr = 400)
			      or (d.pdlttr = 240 and d.pdnxtr = 280)
			      or (d.pdlttr = 400 and d.pdnxtr = 400)
			      or (d.pdlttr = 220 and d.pdnxtr in (240, 400))
			  );
		exception
			when others then
				v_stocktransito := 0;
		end;

		-- 7. Historial de órdenes de compra
		for r in (
			select
				to_char(d.pdtrdj, 'Mon YYYY', 'NLS_DATE_LANGUAGE=SPANISH') as periodo,
				d.pddcto || '-' || d.pddoco as nro_oc,
				d.pduorg as cantidad,
				nvl(trim(d.pduom), v_imuom1) as udm,
				case
					when d.pdnxtr = 999 or d.pdlttr >= 400 then 'Recibido'
					when d.pdlttr in (980, 999) then 'Cancelado'
					else 'Pendiente'
				end as estado,
				case
					when d.pdnxtr < 999 and d.pdlttr not in (980, 999) then 'true'
					else 'false'
				end as es_pendiente
			from data.vt_comp_ordencompradet d
			where d.pditm = v_imitm
			order by d.pdtrdj desc
			fetch first 12 rows only
		) loop
			if v_row_count > 0 then
				v_json_historial := v_json_historial || ',';
			end if;

			v_json_historial := v_json_historial || '{'
				|| '"periodo":"' || r.periodo || '"'
				|| ',"nro_oc":"' || r.nro_oc || '"'
				|| ',"cantidad":' || to_char(nvl(r.cantidad, 0), 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
				|| ',"udm":"' || r.udm || '"'
				|| ',"estado":"' || r.estado || '"'
				|| ',"es_pendiente":' || r.es_pendiente
				|| '}';

			v_row_count := v_row_count + 1;
		end loop;

		-- 8. Construcción del JSON final
		p_respuesta := '{'
			|| '"status":"SUCCESS"'
			|| ',"producto":"' || replace(v_imdsc1, '"', '\"') || '"'
			|| ',"codigoproducto":"' || v_imlitm || '"'
			|| ',"proveedor":"' || replace(v_descproveedor, '"', '\"') || '"'
			|| ',"udm":"' || v_imuom1 || '"'
			|| ',"stock_actual":' || to_char(nvl(v_stock, 0), 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
			|| ',"consumo_mensual":' || to_char(nvl(v_consumo_mensual, 0), 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
			|| ',"dias_stock":' || to_char(nvl(v_dias_stock, 0), 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
			|| ',"stock_transito":' || to_char(nvl(v_stocktransito, 0), 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')
			|| ',"historial":[' || v_json_historial || ']'
			|| '}';

		data.pk_commons.sp_apex_log(v_log_app, 9, v_log_dsc, 'Termina', v_log_obs, p_respuesta);
	exception
		when others then
			p_respuesta := '{"status":"ERROR","message":"' || apex_escape.json(sqlerrm) || '"}';
			data.pk_commons.sp_apex_log(v_log_app, -1, v_log_dsc, sqlerrm, v_log_obs, p_respuesta);
	end sp_kpi_historial_cantidad;
end pk_comp_gestioncompras;
/

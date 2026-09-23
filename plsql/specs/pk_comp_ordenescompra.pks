
  CREATE OR REPLACE EDITIONABLE PACKAGE "PK_COMP_ORDENESCOMPRA" as
	/*
		Administracion de Ordenes de Compras
		@date		30/04/2019
		@author		jbalcazar
		@modified	24/08/2022
	*/

	g_modulo	varchar(4) := 'COMP';
	g_compania	varchar(5) := '00001';
	g_trama		clob;

	function f_buscarsolicitante(p_numero number, p_tipo varchar) return varchar;

	function f_descripcionorden(p_numero number, p_tipo varchar) return varchar;
	function f_descripcionordenv2(p_numero number, p_tipo varchar) return varchar;

	function f_descripcionlinea(p_numero number, p_tipo varchar,p_linea number) return varchar;

	function f_descripcionporlinea(p_numero number, p_tipo varchar,p_linea number) return varchar;

    function f_decirpcionproductoprv(p_number number,p_tipo varchar2,p_codproducto number) return varchar2;

	function f_estadoorden(p_numero number, p_tipo varchar) return varchar;

	function f_observacionocreporte (p_tipo varchar2) return varchar2;

    function f_condicionentregaorden (p_tipo VARCHAR2) return VARCHAR2;

	function f_fechasembarquereporteoc (p_orden number,p_tipo  varchar2) return varchar2;

	function f_informacion_empresa return varchar2;

	procedure sp_reemplazoobs (
		p_compania		in varchar2
		, p_numeroorden	in number
		, p_tipo		in varchar2
		, p_ingreso		in varchar2
		, p_salida		out varchar2
	);

	procedure sp_notificaocvencimiento;

	procedure sp_rutas_jde_apex (
		p_usuario		varchar
	);

	procedure sp_seqf4305 (
		p_valor			out number
	);

	procedure sp_enviarorden (
		p_numero		number
		, p_tipo		varchar
		, p_compania	varchar
		, p_area		varchar
	);

	procedure sp_rechazarlinea (
		p_numero		number
		, p_tipo		varchar
		, p_compania	varchar
		, p_lineas		varchar default null
	);

	procedure sp_aprobarorden (
		p_numero		number
		, p_tipo		varchar
		, p_compania	varchar
	);

	procedure sp_rechazarcostoproveedor (
		p_numero		number
		, p_compania	varchar
	);

	procedure sp_aprobarcostoproveedor (
		p_numero		number
		, p_compania	varchar
	);

	procedure sp_cancelaroclinea (
		p_numero		number
		, p_tipo		varchar
		, p_compania	varchar
		, p_lineas		varchar default null
		, p_numeroorden	out number
		, p_tipoorden	out varchar2
		, p_mensaje		out varchar2
	);

	procedure sp_insertaorden (
		p_compania			in varchar2
		, p_requisicion		in number
		, p_requisiciontipo	in varchar2
		, p_version			in varchar2 default null
		, p_numeroorden		out number
		, p_tipoorden		out varchar2
		, p_mensaje			out varchar2
	);

	procedure sp_notificaruta (
		p_compania		varchar
		, p_orden		number
		, p_tipo		varchar
		, p_opcion		number
	);
end pk_comp_ordenescompra;
/

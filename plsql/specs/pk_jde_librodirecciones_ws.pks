
  CREATE OR REPLACE EDITIONABLE PACKAGE "PK_JDE_LIBRODIRECCIONES_WS" as
        /*
        **proposito: insertar en tablas f0101z2,  F0401Z1 para que se ejecute en la interoperabilidad
        **parametros:
        **  P_ID:   identificador de la tabla del aspirante proveedor
        */

        procedure sp_jde_creacionproveedor (p_id number, p_mensaje out varchar2);

            procedure sp_jde_gestionproveedorws (p_id number, p_opcion number , p_mensaje out varchar2);

end pk_jde_librodirecciones_ws;
/

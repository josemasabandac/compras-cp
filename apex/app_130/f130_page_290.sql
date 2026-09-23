prompt --application/set_environment
set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback
--------------------------------------------------------------------------------
--
-- Oracle APEX export file
--
-- You should run this script using a SQL client connected to the database as
-- the owner (parsing schema) of the application or as a database user with the
-- APEX_ADMINISTRATOR_ROLE role.
--
-- This export file has been automatically generated. Modifying this file is not
-- supported by Oracle and can lead to unexpected application and/or instance
-- behavior now or in the future.
--
-- NOTE: Calls to apex_application_install override the defaults below.
--
--------------------------------------------------------------------------------
begin
wwv_flow_imp.import_begin (
 p_version_yyyy_mm_dd=>'2024.05.31'
,p_release=>'24.1.3'
,p_default_workspace_id=>1282803584972340
,p_default_application_id=>130
,p_default_id_offset=>0
,p_default_owner=>'DATA'
);
end;
/
 
prompt APPLICATION 130 - Compras
--
-- Application Export:
--   Application:     130
--   Name:            Compras
--   Date and Time:   14:44 Wednesday September 23, 2026
--   Exported By:     DATA
--   Flashback:       0
--   Export Type:     Page Export
--   Manifest
--     PAGE: 290
--   Manifest End
--   Version:         24.1.3
--   Instance ID:     800138191179969
--

begin
null;
end;
/
prompt --application/pages/delete_00290
begin
wwv_flow_imp_page.remove_page (p_flow_id=>wwv_flow.g_flow_id, p_page_id=>290);
end;
/
prompt --application/pages/page_00290
begin
wwv_flow_imp_page.create_page(
 p_id=>290
,p_name=>unistr('Gesti\00F3n Compras - Mesa de trabajo')
,p_alias=>unistr('GESTI\00D3N-COMPRAS-MESA-DE-TRABAJO')
,p_step_title=>unistr('Gesti\00F3n Compras - Mesa de trabajo')
,p_warn_on_unsaved_changes=>'N'
,p_autocomplete_on_off=>'OFF'
,p_javascript_code_onload=>wwv_flow_string.join(wwv_flow_t_varchar2(
'// Evaluar scripts inyectados al refrescar la region de informacion',
'$(''#infirmacion'').on(''apexafterrefresh'', function() {',
'    $(this).find(''script'').each(function() {',
'        $.globalEval(this.textContent || this.innerHTML || '''');',
'    });',
'});',
'',
'// Obtener el contenedor o region objetivo',
'function getTargetMesaRegion($elem) {',
'    if ($elem && $elem.length) {',
'        var $r = $elem.closest(''#reporte_prod_alt, #reporte_rutas, #reporte_proveedores, #reporte_negociaciones, #reporte_ocs, .a-IRR-region, .a-IRR-tableContainer, .t-Region'');',
'        if ($r.length) return $r;',
'        var $tbl = $elem.closest(''table'');',
'        if ($tbl.length) return $tbl;',
'    }',
'    var $active = $(''#reporte_prod_alt, #reporte_rutas, #reporte_proveedores, #reporte_negociaciones, #reporte_ocs'').filter('':visible'');',
'    if ($active.length) return $active;',
'    var $visTable = $(''.a-IRR-table:visible'').first();',
'    if ($visTable.length) return $visTable.closest(''#reporte_prod_alt, #reporte_rutas, #reporte_proveedores, #reporte_negociaciones, #reporte_ocs, .a-IRR-region, .t-Region'');',
'    return $(document);',
'}',
'',
'// Inyectar o asegurar la barra de atajos de teclado de forma permanente',
'function asegurarBarraAtajos() {',
'    if ($(''#mesa-shortcuts-bar'').length > 0) return;',
'    var barHtml = ''<div id="mesa-shortcuts-bar" class="mesa-shortcuts-bar">'' +',
'        ''<span class="shortcut-item"><kbd>&uarr;</kbd> <kbd>&darr;</kbd> Navegar</span>'' +',
'        ''<span class="shortcut-item"><kbd>Enter</kbd> Ver detalle</span>'' +',
'        ''<span class="shortcut-item"><kbd>Space</kbd> Seleccionar</span>'' +',
'        ''<span class="shortcut-item"><kbd>A</kbd> Aprobar visible</span>'' +',
unistr('        ''<span class="shortcut-item"><kbd>Esc</kbd> Limpiar selecci\00F3n</span>'' +'),
'        ''</div>'';',
'',
unistr('    // Colocar inmediatamente antes del contenedor de subregiones (justo debajo de la barra de pesta\00F1as y arriba de las tablas)'),
'    var $tabsItems = $(''.t-TabsRegion-items, div.t-TabsRegion-items'').first();',
'    if ($tabsItems.length > 0) {',
'        $tabsItems.before(barHtml);',
'        return;',
'    }',
'    ',
'    var $tabsRegion = $(''.t-TabsRegion, .apex-tabs-region'').first();',
'    if ($tabsRegion.length > 0) {',
'        $tabsRegion.prepend(barHtml);',
'    }',
'}',
'',
'// Inyectar o asegurar la barra flotante de seleccion multiple exclusivamente en la region de OCs',
'function asegurarBarraSticky() {',
'    if ($(''#barra-seleccion-multiple'').length === 0 && $(''#reporte_ocs'').length > 0) {',
'        var barHtml = ''<div id="barra-seleccion-multiple" class="mesa-sticky-bar" style="display:none;">'' +',
'            ''<div class="mesa-sticky-left">'' +',
'                ''<span class="mesa-sticky-badge" id="lbl-cant-seleccionadas">0</span>'' +',
'                ''<span class="mesa-sticky-text">seleccionadas</span>'' +',
'                ''<span class="mesa-sticky-monto" id="lbl-monto-seleccionadas">$ 0.00</span>'' +',
'            ''</div>'' +',
'            ''<div class="mesa-sticky-right">'' +',
unistr('                ''<button type="button" class="mesa-btn-accion btn-analisis-lote" id="btn-sticky-analisis"><span class="fa fa-bar-chart" style="margin-right:4px;"></span> An\00E1lisis</button>'' +'),
'                ''<button type="button" class="mesa-btn-accion btn-aprobar-lote" id="btn-sticky-aprobar"><span class="fa fa-check"></span> Aprobar</button>'' +',
'                ''<button type="button" class="mesa-btn-accion btn-rechazar-lote" id="btn-sticky-rechazar"><span class="fa fa-times"></span> Rechazar</button>'' +',
unistr('                ''<button type="button" class="mesa-btn-cerrar" id="btn-sticky-limpiar" title="Limpiar selecci\00F3n"><span class="fa fa-times"></span></button>'' +'),
'            ''</div>'' +',
'        ''</div>'';',
'        $(''#reporte_ocs'').prepend(barHtml);',
'    }',
'}',
'asegurarBarraSticky();',
'asegurarBarraAtajos();',
'',
'// Limpiar prefijo Compania de los encabezados de agrupacion del reporte',
'function limpiarPrefijoCompania() {',
'    $(''.a-IRR-header--group, .a-IRR-controlBreak, td.a-IRR-header--group, th.a-IRR-header--group, .a-IRR-table .a-IRR-header--group'').each(function() {',
'        var $el = $(this);',
'        var changed = false;',
'        $el.contents().each(function() {',
'            if (this.nodeType === 3) {',
'                var val = this.nodeValue;',
unistr('                if (/Compa\00F1?[i\00ED]a:\005Cs*/i.test(val) || /Compania:\005Cs*/i.test(val)) {'),
unistr('                    this.nodeValue = val.replace(/Compa\00F1?[i\00ED]a:\005Cs*/gi, '''').replace(/Compania:\005Cs*/gi, '''');'),
'                    changed = true;',
'                }',
'            }',
'        });',
'        if (!changed) {',
'            var txt = $el.text().trim();',
unistr('            if (/^Compa\00F1?[i\00ED]a:\005Cs*/i.test(txt) || /^Compania:\005Cs*/i.test(txt)) {'),
unistr('                $el.text(txt.replace(/^Compa\00F1?[i\00ED]a:\005Cs*/gi, '''').replace(/^Compania:\005Cs*/gi, ''''));'),
'            }',
'        }',
'    });',
'}',
'limpiarPrefijoCompania();',
'setTimeout(limpiarPrefijoCompania, 150);',
'setTimeout(limpiarPrefijoCompania, 500);',
unistr('// Enfocar visualmente una fila con el cursor (sin modificar selecci\00F3n)'),
'function enfocarFila($row, $region) {',
'    if (!$row || $row.length === 0) return;',
'    $region = $region || getTargetMesaRegion($row);',
'    $region.find(''tr'').removeClass(''fila-enfocada'');',
'    $row.addClass(''fila-enfocada'');',
'    if ($row[0] && typeof $row[0].scrollIntoView === ''function'') {',
'        $row[0].scrollIntoView({ block: ''nearest'', behavior: ''smooth'' });',
'    }',
'}',
'',
'// Seleccionar exclusivamente una fila y sincronizar detalle',
'var _refreshInfoTimer = null;',
'function refreshInfoDebounced() {',
'    if (_refreshInfoTimer) clearTimeout(_refreshInfoTimer);',
'    _refreshInfoTimer = setTimeout(function() {',
'        if (apex.region("infirmacion")) {',
'            apex.region("infirmacion").refresh();',
'        } else {',
'            $(''#infirmacion'').trigger(''apexrefresh'');',
'        }',
'    }, 200);',
'}',
'function seleccionarFilaExclusiva($row, $region) {',
'    if (!$row || $row.length === 0) return;',
'    if ($row.hasClass(''a-IRR-header--group'') || $row.hasClass(''a-IRR-no-data-found'') || $row.is(''thead tr, th'') || $row.closest(''thead'').length > 0) return;',
'    $region = $region || getTargetMesaRegion($row);',
'    enfocarFila($row, $region);',
'    var $thisChk = $row.find(''.chk-aprobacion:not(:disabled)'');',
'    ',
'    // Desmarcar todos los checkboxes de la region',
'    $region.find(''.chk-aprobacion'').prop(''checked'', false);',
'    $region.find(''tr'').removeClass(''fila-seleccionada'');',
'    ',
'    // Marcar unicamente esta fila',
'    $row.addClass(''fila-seleccionada'');',
'    if ($thisChk.length > 0) {',
'        $thisChk.prop(''checked'', true);',
'        actualizarSeleccionMesa($thisChk);',
'    } else {',
'        var rawId = $row.find(''input[type="checkbox"]'').val()',
'              || $row.find(''td[headers*="324449584566451205"], td[headers*="ID"]'').text().trim()',
'              || $row.find(''td'').eq(1).text().trim();',
'        if (rawId && /^[0-9]+(,[0-9]+)*$/.test(rawId.trim())) {',
'            apex.item("P290_ID_SELECCIONADO").setValue(rawId.trim());',
'            $(''#barra-seleccion-multiple'').slideUp(150);',
'            $(''#APROBAR, #RECHAZAR'').hide();',
'        }',
'    }',
'    ',
'    // Desplazar a la vista si esta fuera de pantalla',
'    if ($row[0] && typeof $row[0].scrollIntoView === ''function'') {',
'        $row[0].scrollIntoView({ block: ''nearest'', behavior: ''smooth'' });',
'    }',
'    ',
'    // Refrescar el panel de detalle',
'    refreshInfoDebounced();',
'}',
'',
'// Actualizar seleccion en la region actual (barra flotante exclusiva de OCs)',
'function actualizarSeleccionMesa($elem) {',
'    var $region = getTargetMesaRegion($elem);',
'    var isOCs = ($region.attr(''id'') === ''reporte_ocs'' || $region.closest(''#reporte_ocs'').length > 0);',
'    ',
'    var $allCheckboxes = $region.find(''.chk-aprobacion'');',
'    var $checked = $region.find(''.chk-aprobacion:checked:not(:disabled)'');',
'    var $allAvailable = $region.find(''.chk-aprobacion:not(:disabled)'');',
'    ',
'    // Sincronizar estilos visuales de fila',
'    $allCheckboxes.each(function() {',
'        if ($(this).is('':checked'')) {',
'            $(this).closest(''tr'').addClass(''fila-seleccionada'');',
'        } else {',
'            $(this).closest(''tr'').removeClass(''fila-seleccionada'');',
'        }',
'    });',
'    ',
'    // Sincronizar el checkbox de la cabecera de la tabla actual',
'    if ($allAvailable.length > 0) {',
'        var allChecked = ($checked.length === $allAvailable.length && $allAvailable.length > 0);',
'        $region.find(''.chk-all-aprobaciones, #chk-todos-aprobaciones'').prop(''checked'', allChecked);',
'    }',
'    ',
'    var cant = $checked.length;',
'    if (cant > 0) {',
'        var ids = [];',
'        var totalMonto = 0;',
'        $checked.each(function() {',
'            var val = $(this).val() || $(this).data(''id'');',
'            if (val) ids.push(val);',
'            if (isOCs) {',
'                var attrMonto = $(this).attr(''data-monto'');',
'                var m = parseFloat(attrMonto);',
'                if (isNaN(m)) {',
'                    var $row = $(this).closest(''tr'');',
'                    var cardMonto = $row.find(''.compra-card-amount'').attr(''data-monto'');',
'                    m = parseFloat(cardMonto);',
'                }',
'                if (isNaN(m)) {',
'                    var $row = $(this).closest(''tr'');',
'                    var rawMonto = $row.find(''.compra-card-amount'').text() || $row.find(''td[headers*="MONTOTOTAL"]'').text() || '''';',
'                    var cleanMonto = rawMonto.replace(/[^0-9.]/g, '''');',
'                    m = parseFloat(cleanMonto);',
'                }',
'                if (!isNaN(m)) {',
'                    totalMonto += m;',
'                }',
'            }',
'        });',
'        ',
'        apex.item("P290_ID_SELECCIONADO").setValue(ids.join('',''));',
'',
'        // Botones Aprobar/Rechazar sobre la region de informacion solo cuando hay exactamente 1 seleccionado',
'        if (cant === 1) {',
'            $(''#APROBAR, #RECHAZAR'').show();',
'        } else {',
'            $(''#APROBAR, #RECHAZAR'').hide();',
'        }',
'        ',
'        if (isOCs && cant > 1) {',
'            asegurarBarraSticky();',
'            $(''#lbl-cant-seleccionadas'').text(cant);',
'            $(''#lbl-monto-seleccionadas'').text(''$ '' + totalMonto.toLocaleString(''en-US'', { minimumFractionDigits: 2, maximumFractionDigits: 2 }));',
'            $(''#barra-seleccion-multiple'').slideDown(150);',
'        } else {',
'            $(''#barra-seleccion-multiple'').slideUp(150);',
'        }',
'    } else {',
'        apex.item("P290_ID_SELECCIONADO").setValue("");',
'        if (isOCs) {',
'            $(''#barra-seleccion-multiple'').slideUp(150);',
'        } else {',
'            $(''#barra-seleccion-multiple'').hide();',
'        }',
'        $(''#APROBAR, #RECHAZAR'').hide();',
'    }',
'}',
'',
'// Limpiar seleccion',
'function limpiarDetalleMesa() {',
'    apex.item("P290_ID_SELECCIONADO").setValue("");',
'    $("#APROBAR, #RECHAZAR").hide();',
'    $(''#barra-seleccion-multiple'').slideUp(150);',
'    $(".a-IRR-table tr").removeClass("fila-seleccionada fila-enfocada");',
'    $(''.chk-aprobacion'').prop(''checked'', false);',
'    $(''.chk-all-aprobaciones, #chk-todos-aprobaciones'').prop(''checked'', false);',
'    if (apex.region("infirmacion")) {',
'        apex.region("infirmacion").refresh();',
'    } else {',
'        $(''#infirmacion'').trigger(''apexrefresh'');',
'    }',
'}',
'',
'// Seleccionar/deseleccionar todos los checkboxes de la region donde se hizo clic',
'$(document).on(''change'', ''#chk-todos-aprobaciones, .chk-all-aprobaciones'', function() {',
'    var isChecked = $(this).is('':checked'');',
'    var $region = getTargetMesaRegion($(this));',
'    $region.find(''.chk-aprobacion:not(:disabled)'').prop(''checked'', isChecked);',
'    $region.find(''.chk-aprobacion'').each(function() {',
'        if ($(this).is('':checked'')) {',
'            $(this).closest(''tr'').addClass(''fila-seleccionada'');',
'        } else {',
'            $(this).closest(''tr'').removeClass(''fila-seleccionada'');',
'        }',
'    });',
'    actualizarSeleccionMesa($region);',
'    refreshInfoDebounced();',
'});',
'',
'// Checkbox individual de fila en cualquier region',
'$(document).on(''change'', ''.chk-aprobacion'', function() {',
'    if ($(this).is('':checked'')) {',
'        $(this).closest(''tr'').addClass(''fila-seleccionada'');',
'    } else {',
'        $(this).closest(''tr'').removeClass(''fila-seleccionada'');',
'    }',
'    actualizarSeleccionMesa($(this));',
'    refreshInfoDebounced();',
'});',
'',
'// Clic en la fila de OCs (fuera de controles): selecciona unicamente esa fila y desmarca las demas',
'$(document).on(''click'', ''#reporte_ocs .a-IRR-table tbody tr'', function(e) {',
'    var $tr = $(this);',
'    if ($tr.hasClass(''a-IRR-header--group'') || $tr.hasClass(''a-IRR-no-data-found'') || $tr.is(''.a-IRR-header--group, .a-IRR-controlBreak'') || $tr.closest(''thead'').length > 0) {',
'        return;',
'    }',
'    if ($(e.target).is(''input, button, a, kbd'') || $(e.target).closest(''.btn-flujo-modal, .chk-aprobacion, .chk-all-aprobaciones, td:first-child, .a-IRR-headerLink, th'').length > 0) {',
'        return;',
'    }',
'    var $region = getTargetMesaRegion($tr);',
'    seleccionarFilaExclusiva($tr, $region);',
'});',
'',
'// Al cambiar de pestana en el Tabs Region',
'function limpiarTodasLasSelecciones() {',
'    $(''.chk-aprobacion, .chk-all-aprobaciones, #chk-todos-aprobaciones'').prop(''checked'', false);',
'    $(''.a-IRR-table tr'').removeClass(''fila-seleccionada fila-enfocada'');',
'    apex.item("P290_ID_SELECCIONADO").setValue("");',
'    $(''#APROBAR, #RECHAZAR'').hide();',
'    $(''#barra-seleccion-multiple'').hide();',
'    refreshInfoDebounced();',
'}',
'$(document).on(''click'', ''.t-Tabs-item, .t-Tabs-link, .t-TabsRegion-items a, .apex-rds li a, [role=\"tab\"]'', function() {',
'    setTimeout(limpiarTodasLasSelecciones, 200);',
'});',
'$(document).on(''apexaftershow'', ''#reporte_prod_alt, #reporte_rutas, #reporte_proveedores, #reporte_negociaciones, #reporte_ocs'', function() {',
'    limpiarTodasLasSelecciones();',
'    limpiarPrefijoCompania();',
'    setTimeout(limpiarPrefijoCompania, 100);',
'});',
'',
'// Al refrescar cualquier reporte interactivo',
'$(document).on(''apexafterrefresh'', ''.a-IRR-region, #reporte_prod_alt, #reporte_rutas, #reporte_proveedores, #reporte_negociaciones, #reporte_ocs'', function() {',
'    asegurarBarraAtajos();',
'    actualizarSeleccionMesa($(this));',
'    limpiarPrefijoCompania();',
'    setTimeout(limpiarPrefijoCompania, 100);',
'});',
'',
'// Manejador de Atajos de Teclado Global',
'$(document).on(''keydown'', function(e) {',
'    // 1. No interceptar cuando el usuario esta escribiendo en campos de entrada / buscador',
'    if ($(e.target).is(''input, textarea, select, [contenteditable]'') || $(e.target).closest(''.a-IRR-search, .a-IRR-dialog, .ui-dialog'').length > 0) {',
'        return;',
'    }',
'    ',
'    // 2. No interceptar si hay un dialogo modal visible',
'    if ($(''.ui-dialog:visible'').length > 0) {',
'        return;',
'    }',
'    ',
'    var $region = getTargetMesaRegion();',
'    var $table = $region.find(''.a-IRR-table tbody'');',
'    var $rows = $table.find(''tr'').filter(function() {',
'        return $(this).find(''td'').length > 0 && !$(this).hasClass(''a-IRR-no-data-found'');',
'    });',
'    ',
'    if ($rows.length === 0) return;',
'    ',
'    var $focusedRow = $rows.filter(''.fila-enfocada'');',
'    var currentIndex = -1;',
'    if ($focusedRow.length > 0) {',
'        currentIndex = $rows.index($focusedRow.first());',
'    } else {',
'        var $selectedRows = $rows.filter(''.fila-seleccionada'');',
'        if ($selectedRows.length > 0) {',
'            currentIndex = $rows.index($selectedRows.last());',
'        }',
'    }',
'    ',
'    // Tecla Escape (Limpiar seleccion)',
'    if (e.key === ''Escape'' || e.keyCode === 27) {',
'        e.preventDefault();',
'        limpiarDetalleMesa();',
'        return;',
'    }',
'    ',
'    // Tecla A o a (Aprobar)',
'    if (e.key === ''a'' || e.key === ''A'' || e.keyCode === 65) {',
'        if ($(''#btn-sticky-aprobar'').is('':visible'') || $(''#APROBAR'').is('':visible'')) {',
'            e.preventDefault();',
'            ejecutarValidacionAprobar();',
'            return;',
'        }',
'    }',
'    ',
'    // Tecla R o r (Rechazar)',
'    if (e.key === ''r'' || e.key === ''R'' || e.keyCode === 82) {',
'        if ($(''#btn-sticky-rechazar'').is('':visible'') || $(''#RECHAZAR'').is('':visible'')) {',
'            e.preventDefault();',
'            ejecutarValidacionRechazar();',
'            return;',
'        }',
'    }',
'    ',
'    // Flecha Abajo (Navegar foco siguiente sin seleccionar)',
'    if (e.key === ''ArrowDown'' || e.keyCode === 40) {',
'        e.preventDefault();',
'        var nextIndex = (currentIndex < $rows.length - 1) ? currentIndex + 1 : 0;',
'        var $nextRow = $rows.eq(nextIndex);',
'        enfocarFila($nextRow, $region);',
'        return;',
'    }',
'    ',
'    // Flecha Arriba (Navegar foco anterior sin seleccionar)',
'    if (e.key === ''ArrowUp'' || e.keyCode === 38) {',
'        e.preventDefault();',
'        var prevIndex = (currentIndex > 0) ? currentIndex - 1 : $rows.length - 1;',
'        var $prevRow = $rows.eq(prevIndex);',
'        enfocarFila($prevRow, $region);',
'        return;',
'    }',
'    ',
'    // Tecla Espacio (Alternar Checkbox de la fila enfocada)',
'    if (e.key === '' '' || e.keyCode === 32 || e.code === ''Space'') {',
'        e.preventDefault();',
'        var $targetRow = ($focusedRow.length > 0) ? $focusedRow.first() : ((currentIndex >= 0) ? $rows.eq(currentIndex) : $rows.first());',
'        enfocarFila($targetRow, $region);',
'        var $chk = $targetRow.find(''.chk-aprobacion:not(:disabled)'');',
'        if ($chk.length > 0) {',
'            $chk.prop(''checked'', !$chk.prop(''checked''));',
'            if ($chk.is('':checked'')) {',
'                $targetRow.addClass(''fila-seleccionada'');',
'            } else {',
'                $targetRow.removeClass(''fila-seleccionada'');',
'            }',
'            actualizarSeleccionMesa($chk);',
'            refreshInfoDebounced();',
'        }',
'        return;',
'    }',
'    ',
'    // Tecla Enter (Ver detalle de la fila enfocada)',
'    if (e.key === ''Enter'' || e.keyCode === 13) {',
'        e.preventDefault();',
'        var $targetRow = ($focusedRow.length > 0) ? $focusedRow.first() : ((currentIndex >= 0) ? $rows.eq(currentIndex) : $rows.first());',
'        seleccionarFilaExclusiva($targetRow, $region);',
'        return;',
'    }',
'});',
'',
'// Botones de la barra flotante',
'$(document).on(''click'', ''#btn-sticky-ver-detalle'', function() {',
'    if (apex.region("infirmacion")) {',
'        apex.region("infirmacion").refresh();',
'    } else {',
'        $(''#infirmacion'').trigger(''apexrefresh'');',
'    }',
'});',
'',
'// Abrir modal gestionando el estado de carga mediante clase CSS (sin alterar el DOM de APEX)',
'function abrirModalConCarga(modalId) {',
'    var $modal = $(''#'' + modalId);',
'    $modal.addClass(''modal-cargando'');',
'',
'    $modal.one(''apexafterrefresh'', function() {',
'        $modal.removeClass(''modal-cargando'');',
'    });',
'',
'    // Fallback de seguridad',
'    setTimeout(function() {',
'        $modal.removeClass(''modal-cargando'');',
'    }, 8000);',
'',
'    openModal(modalId);',
'    apex.region(modalId).refresh();',
'}',
'',
'$(document).on(''click'', ''#btn-sticky-analisis'', function(e) {',
'    e.stopPropagation();',
'    var ids = apex.item("P290_ID_SELECCIONADO").getValue();',
'    if (ids) {',
'        abrirModalConCarga("modal_analisis_resumen");',
'    }',
'});',
'',
'function ejecutarValidacionAprobar() {',
'    var totalLines = $(''.chk-linea-oc:not(:disabled)'').length;',
'    var unchecked = [];',
'    $(''.chk-linea-oc:not(:disabled):not(:checked)'').each(function() {',
'        var v = $(this).val();',
'        if (v) { unchecked.push(v); }',
'    });',
'    var checkedCount = totalLines - unchecked.length;',
'',
'    if (totalLines > 0 && checkedCount === 0) {',
unistr('        apex.message.alert("Debe seleccionar al menos una l\00EDnea para aprobar, valide y vuelva a intentar.");'),
'        return;',
'    }',
'',
'    if (unchecked.length === 0) {',
'        apex.item("P290_LINEAS_RECHAZAR").setValue("");',
'        apex.item("P290_ACCION").setValue("");',
'        var $btn = $(''#MODAL_APROBAR_107'');',
'        if ($btn.length) {',
'            $btn[0].click();',
'        }',
'        return;',
'    }',
'',
'    apex.item("P290_LINEAS_RECHAZAR").setValue(unchecked.join(","));',
'    apex.item("P290_ACCION").setValue("APRUEBA_PARCIAL");',
'',
'    apex.server.process("GET_DIALOG_URL_286", {',
'        pageItems: ["P290_LINEAS_RECHAZAR"]',
'    }, {',
'        dataType: "text",',
'        success: function(pData) {',
'            if (pData) { eval(pData); }',
'        }',
'    });',
'}',
'',
'$(document).on(''click'', ''#APROBAR, #btn-sticky-aprobar'', function(e) {',
'    e.preventDefault();',
'    ejecutarValidacionAprobar();',
'});',
'',
'function ejecutarValidacionRechazar() {',
'    var totalLines = $(''.chk-linea-oc:not(:disabled)'').length;',
'    var checked = [];',
'    $(''.chk-linea-oc:not(:disabled):checked'').each(function() {',
'        var v = $(this).val();',
'        if (v) { checked.push(v); }',
'    });',
'    var checkedCount = checked.length;',
'',
'    if (totalLines > 0 && checkedCount === 0) {',
unistr('        apex.message.alert("Debe seleccionar al menos una l\00EDnea para rechazar, valide y vuelva a intentar.");'),
'        return;',
'    }',
'',
'    if (totalLines === 0 || checkedCount === totalLines) {',
'        apex.item("P290_LINEAS_RECHAZAR").setValue("");',
'        apex.item("P290_ACCION").setValue("");',
'        var $btn = $(''#MODAL_RECHAZAR_107'');',
'        if ($btn.length) {',
'            $btn[0].click();',
'        }',
'        return;',
'    }',
'',
'    apex.item("P290_LINEAS_RECHAZAR").setValue(checked.join(","));',
'    apex.item("P290_ACCION").setValue("RECHAZO_PARCIAL");',
'',
'    apex.server.process("GET_DIALOG_URL_286", {',
'        pageItems: ["P290_LINEAS_RECHAZAR"]',
'    }, {',
'        dataType: "text",',
'        success: function(pData) {',
'            if (pData) { eval(pData); }',
'        }',
'    });',
'}',
'',
'$(document).on(''click'', ''#RECHAZAR, #btn-sticky-rechazar'', function(e) {',
'    e.preventDefault();',
'    ejecutarValidacionRechazar();',
'});',
'',
'$(document).on(''click'', ''#btn-sticky-limpiar'', function() {',
'    limpiarDetalleMesa();',
'});',
'',
'// Seleccionar/deseleccionar todas las lineas de la tabla de detalle de OCs',
'$(document).on(''change'', ''#chk-todos-lineas-oc, .chk-todos-lineas-oc'', function() {',
'    var isChecked = $(this).is('':checked'');',
'    var $tbl = $(this).closest(''table'');',
'    if ($tbl.length > 0) {',
'        $tbl.find(''.chk-linea-oc:not(:disabled)'').prop(''checked'', isChecked);',
'    } else {',
'        $(''.chk-linea-oc:not(:disabled)'').prop(''checked'', isChecked);',
'    }',
'});',
'',
'// Abrir modal de flujo y comentarios',
'$(document).on(''click'', ''.btn-flujo-modal'', function(e) {',
'    e.stopPropagation();',
'    var idRegistro = $(this).data(''id'');',
'    if (idRegistro) {',
'        apex.item("P290_ID_SELECCIONADO").setValue(idRegistro);',
'        abrirModalConCarga("modal_info_ruta");',
'    }',
'});',
'',
'// Abrir modal de historial de compras',
'$(document).on(''click'', ''.btn-historial-modal'', function(e) {',
'    e.stopPropagation();',
'    var $btn = $(this);',
'    var codProd = $btn.data(''producto'');',
'    var descProd = $btn.data(''descproducto'') || '''';',
'    var codProv = $btn.data(''proveedor'');',
'    var descProv = $btn.data(''descproveedor'') || '''';',
'    var cia = $btn.data(''compania'') || ''00001'';',
'    var idAprob = $btn.data(''id-aprobacion'') || $btn.closest(''tr'').data(''id-aprobacion'') || '''';',
'',
'    if (codProd && codProv) {',
'        apex.item("P290_HIST_COMPANIA").setValue(cia);',
'        apex.item("P290_HIST_PRODUCTO").setValue(codProd);',
'        apex.item("P290_HIST_DESCPRODUCTO").setValue(descProd);',
'        apex.item("P290_HIST_PROVEEDOR").setValue(codProv);',
'        apex.item("P290_HIST_DESCPROVEEDOR").setValue(descProv);',
'        apex.item("P290_HIST_ID_APROBACION").setValue(idAprob);',
'',
'        abrirModalConCarga("modal_historico_compra");',
'    }',
'});',
'',
'// Abrir modal de KPI Cantidad',
'$(document).on(''click'', ''.kpi-link-cantidad'', function(e) {',
'    e.stopPropagation();',
'    var $link = $(this);',
'    var codProd = $link.data(''producto'');',
'    var descProd = $link.data(''descproducto'') || '''';',
'    var codProv = $link.data(''proveedor'');',
'    var descProv = $link.data(''descproveedor'') || '''';',
'    var cia = $link.data(''compania'') || ''00001'';',
'    var idAprob = $link.data(''id-aprobacion'') || $link.closest(''tr'').data(''id-aprobacion'') || '''';',
'',
'    if (codProd) {',
'        apex.item("P290_HIST_COMPANIA").setValue(cia);',
'        apex.item("P290_HIST_PRODUCTO").setValue(codProd);',
'        apex.item("P290_HIST_DESCPRODUCTO").setValue(descProd);',
'        apex.item("P290_HIST_PROVEEDOR").setValue(codProv || '''');',
'        apex.item("P290_HIST_DESCPROVEEDOR").setValue(descProv || '''');',
'        apex.item("P290_HIST_ID_APROBACION").setValue(idAprob);',
'',
'        abrirModalConCarga("modal_kpi_cantidad");',
'    }',
'});',
'',
'// Abrir modal de KPI Precio',
'$(document).on(''click'', ''.kpi-link-precio'', function(e) {',
'    e.stopPropagation();',
'    var $link = $(this);',
'    var codProd = $link.data(''producto'');',
'    var descProd = $link.data(''descproducto'') || '''';',
'    var codProv = $link.data(''proveedor'');',
'    var descProv = $link.data(''descproveedor'') || '''';',
'    var cia = $link.data(''compania'') || ''00001'';',
'    var idAprob = $link.data(''id-aprobacion'') || $link.closest(''tr'').data(''id-aprobacion'') || '''';',
'',
'    if (codProd) {',
'        apex.item("P290_HIST_COMPANIA").setValue(cia);',
'        apex.item("P290_HIST_PRODUCTO").setValue(codProd);',
'        apex.item("P290_HIST_DESCPRODUCTO").setValue(descProd);',
'        apex.item("P290_HIST_PROVEEDOR").setValue(codProv || '''');',
'        apex.item("P290_HIST_DESCPROVEEDOR").setValue(descProv || '''');',
'        apex.item("P290_HIST_ID_APROBACION").setValue(idAprob);',
'',
'        abrirModalConCarga("modal_kpi_precio");',
'    }',
'});',
'',
'// Abrir modal de KPI Valor (Stock e Indicadores)',
'$(document).on(''click'', ''.kpi-link-valor'', function(e) {',
'    e.stopPropagation();',
'    var $link = $(this);',
'    var codProd = $link.data(''producto'');',
'    var descProd = $link.data(''descproducto'') || '''';',
'    var codProv = $link.data(''proveedor'');',
'    var descProv = $link.data(''descproveedor'') || '''';',
'    var cia = $link.data(''compania'') || ''00001'';',
'    var idAprob = $link.data(''id-aprobacion'') || $link.closest(''tr'').data(''id-aprobacion'') || '''';',
'',
'    if (codProd) {',
'        apex.item("P290_HIST_COMPANIA").setValue(cia);',
'        apex.item("P290_HIST_PRODUCTO").setValue(codProd);',
'        apex.item("P290_HIST_DESCPRODUCTO").setValue(descProd);',
'        apex.item("P290_HIST_PROVEEDOR").setValue(codProv || '''');',
'        apex.item("P290_HIST_DESCPROVEEDOR").setValue(descProv || '''');',
'        apex.item("P290_HIST_ID_APROBACION").setValue(idAprob);',
'',
'        abrirModalConCarga("modal_kpi_valor");',
'    }',
'});'))
,p_inline_css=>wwv_flow_string.join(wwv_flow_t_varchar2(
'/* Barra flotante de seleccion multiple corporativa (Paleta Corporativa PK_CORP_APROBACION) */',
'.mesa-sticky-bar {',
'    position: sticky;',
'    top: 0;',
'    z-index: 100;',
'    display: flex;',
'    align-items: center;',
'    justify-content: space-between;',
'    background: #008744;',
'    color: #ffffff;',
'    padding: 8px 16px;',
'    border-radius: 6px;',
'    margin-bottom: 8px;',
'    box-shadow: 0 4px 12px rgba(0, 135, 68, 0.25);',
'    transition: all 0.2s ease;',
'}',
'.mesa-sticky-left {',
'    display: flex;',
'    align-items: center;',
'    gap: 10px;',
'}',
'.mesa-sticky-badge {',
'    background-color: #ffffff;',
'    color: #008744;',
'    font-size: 12px;',
'    font-weight: 700;',
'    padding: 2px 10px;',
'    border-radius: 12px;',
'    min-width: 24px;',
'    text-align: center;',
'    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);',
'}',
'.mesa-sticky-text {',
'    font-size: 13px;',
'    color: rgba(255, 255, 255, 0.9);',
'    font-weight: 600;',
'}',
'.mesa-sticky-monto {',
'    font-size: 15px;',
'    font-weight: 700;',
'    color: #ffffff;',
'    letter-spacing: 0.3px;',
'    margin-left: 6px;',
'    background: rgba(255, 255, 255, 0.18);',
'    padding: 2px 10px;',
'    border-radius: 4px;',
'}',
'.mesa-sticky-right {',
'    display: flex;',
'    align-items: center;',
'    gap: 8px;',
'}',
'.mesa-btn-accion {',
'    border: none;',
'    cursor: pointer;',
'    font-size: 12px;',
'    font-weight: 600;',
'    padding: 6px 14px;',
'    border-radius: 4px;',
'    display: inline-flex;',
'    align-items: center;',
'    gap: 5px;',
'    transition: all 0.15s ease;',
'}',
'.mesa-btn-accion:active {',
'    transform: scale(0.97);',
'}',
'.btn-ver-detalle {',
'    background-color: #ffffff;',
'    color: #008744;',
'    border: 1px solid #c8e6c9;',
'}',
'.btn-ver-detalle:hover {',
'    background-color: #e8f5e9;',
'    color: #005a2e;',
'}',
'.btn-aprobar-lote {',
'    background-color: #1b5e20;',
'    color: #ffffff;',
'    border: 1px solid #144517;',
'}',
'.btn-aprobar-lote:hover {',
'    background-color: #144517;',
'}',
'.btn-rechazar-lote {',
'    background-color: #c62828;',
'    color: #ffffff;',
'    border: 1px solid #8e0000;',
'}',
'.btn-rechazar-lote:hover {',
'    background-color: #8e0000;',
'}',
'.mesa-btn-cerrar {',
'    background: transparent;',
'    border: none;',
'    color: rgba(255, 255, 255, 0.85);',
'    font-size: 15px;',
'    cursor: pointer;',
'    padding: 4px 8px;',
'    border-radius: 4px;',
'    transition: all 0.15s ease;',
'}',
'.mesa-btn-cerrar:hover {',
'    color: #ffffff;',
'    background-color: rgba(255, 255, 255, 0.2);',
'}',
'',
'/* Barra de Atajos de Teclado */',
'.mesa-shortcuts-bar {',
'    display: flex;',
'    align-items: center;',
'    gap: 16px;',
'    padding: 6px 14px;',
'    background-color: #f8fafc;',
'    border: 1px solid #e2e8f0;',
'    border-radius: 6px;',
'    margin-bottom: 8px;',
'    font-size: 11.5px;',
'    color: #64748b;',
'    user-select: none;',
'    flex-wrap: wrap;',
'}',
'.mesa-shortcuts-bar .shortcut-item {',
'    display: inline-flex;',
'    align-items: center;',
'    gap: 5px;',
'}',
'.mesa-shortcuts-bar kbd {',
'    display: inline-block;',
'    padding: 2px 6px;',
'    font-size: 11px;',
'    font-family: inherit;',
'    font-weight: 600;',
'    line-height: 1.2;',
'    color: #334155;',
'    background-color: #ffffff;',
'    border: 1px solid #cbd5e1;',
'    border-radius: 4px;',
'    box-shadow: 0 1px 1px rgba(0,0,0,0.06);',
'}',
'.btn-flujo-modal { background-color: #f1f8f4; color: #008744; border: 1px solid #c8e6c9; font-size: 10.5px; font-weight: 600; padding: 1px 7px; border-radius: 4px; cursor: pointer; display: inline-flex; align-items: center; gap: 4px; transition: all '
||'0.15s ease; vertical-align: middle; }',
'.btn-flujo-modal:hover { background-color: #e8f5e9; border-color: #008744; color: #005a2e; }',
'.btn-historial-modal { background-color: #f8fafc; color: #475569; border: 1px solid #cbd5e1; font-size: 11px; padding: 2px 6px; border-radius: 4px; cursor: pointer; display: inline-flex; align-items: center; justify-content: center; margin-left: 6px;'
||' transition: all 0.15s ease; vertical-align: middle; }',
'.btn-analisis-lote { background: #1e293b !important; color: #ffffff !important; border: 1px solid #475569 !important; border-radius: 6px !important; font-weight: 600 !important; font-size: 12px !important; padding: 5px 14px !important; cursor: pointe'
||'r !important; display: inline-flex !important; align-items: center !important; gap: 4px !important; transition: all 0.15s ease !important; margin-right: 8px !important; vertical-align: middle !important; }',
'.btn-analisis-lote:hover { background: #334155 !important; border-color: #94a3b8 !important; color: #ffffff !important; }',
'.ui-dialog:has(#modal_info_ruta) { width: 70vw !important; max-width: 70vw !important; min-width: 500px !important; }',
'.ui-dialog:has(#modal_historico_compra), .ui-dialog:has(#modal_kpi_cantidad), .ui-dialog:has(#modal_kpi_precio), .ui-dialog:has(#modal_kpi_valor), .ui-dialog:has(#modal_analisis_resumen) { width: 65vw !important; max-width: 65vw !important; min-width'
||': 480px !important; }',
'',
'/* Evitar que spinners de regiones de fondo se muestren por encima del overlay modal */',
'.ui-widget-overlay { z-index: 9000 !important; }',
'.ui-dialog { z-index: 9001 !important; }',
'body:has(.ui-dialog:visible) #infirmacion .u-Processing,',
'body:has(.ui-dialog:visible) #infirmacion .apex_spinner,',
'body:has(.ui-widget-overlay) #infirmacion .u-Processing,',
'body:has(.ui-widget-overlay) #infirmacion .apex_spinner,',
'body:has(.ui-dialog:visible) .u-Processing-spinner:not(.ui-dialog *),',
'body:has(.ui-widget-overlay) .u-Processing-spinner:not(.ui-dialog *) {',
'    display: none !important;',
'}',
'',
'/* Ocultar suavemente el contenido viejo del modal durante la carga sin destruir nodos del DOM */',
'.modal-cargando .t-DialogRegion-body > * {',
'    opacity: 0 !important;',
'    pointer-events: none !important;',
'}',
'',
'.kpi-hdr-arrow { font-size: 11px; opacity: 0.7; vertical-align: baseline; }',
'.kpi-cell-link { color: #0284c7 !important; text-decoration: underline dotted #0284c7 !important; font-weight: 600 !important; cursor: pointer !important; }',
'.kpi-cell-link:hover { color: #0369a1 !important; text-decoration: underline solid #0369a1 !important; }',
'.a-IRR-table tbody tr { cursor: pointer; transition: background 0.15s ease; }',
'.a-IRR-table tr.fila-enfocada, .a-IRR-table tr.fila-enfocada td { background-color: #f0f9ff !important; outline: 1.5px solid #0284c7 !important; outline-offset: -1.5px; }',
'.a-IRR-table tr.fila-seleccionada, .a-IRR-table tr.fila-seleccionada td { background-color: #e8f5e9 !important; }',
'.a-IRR-table tr.fila-seleccionada.fila-enfocada, .a-IRR-table tr.fila-seleccionada.fila-enfocada td { background-color: #e0f2fe !important; outline: 2px solid #0284c7 !important; outline-offset: -2px; }',
'.aprobacion-card { background: transparent !important; padding: 0 !important; margin: 0 !important; }',
'',
'/* Ocultar barra de chips / filtros nativos del IR */',
'.a-IRR-controlsContainer {',
'    display: none !important;',
'}',
'',
'/* Cabecera limpia: transparente y con solo el checkbox visible */',
'.a-IRR-table thead,',
'.a-IRR-table thead tr,',
'.a-IRR-table thead th,',
'.a-IRR-table thead td,',
'.a-IRR-tableContainer thead,',
'.a-IRR-tableContainer thead tr,',
'.a-IRR-tableContainer thead th,',
'.a-IRR-table th,',
'.a-IRR-header,',
'.a-IRR-headerLink {',
'    background: transparent !important;',
'    background-color: transparent !important;',
'    border: none !important;',
'    box-shadow: none !important;',
'}',
'.a-IRR-table thead th:not(:first-child),',
'.a-IRR-table thead th:not(:first-child) *,',
'.a-IRR-table thead th:not(:first-child) .a-IRR-headerLink {',
'    display: table-cell !important;',
'    visibility: hidden !important;',
'    border: none !important;',
'    background: transparent !important;',
'    background-color: transparent !important;',
'    padding: 0 !important;',
'    height: 0 !important;',
'    pointer-events: none !important;',
'}',
'.a-IRR-table thead th:first-child {',
'    width: 38px !important;',
'    min-width: 38px !important;',
'    max-width: 42px !important;',
'    text-align: center !important;',
'    padding: 4px 2px !important;',
'    background: transparent !important;',
'    border: none !important;',
'}',
'',
'/* Agrupador por Compania Estilizado */',
'.a-IRR-table tr.a-IRR-header--group {',
'    display: table-row !important;',
'}',
'.a-IRR-table tr.a-IRR-header--group td,',
'.a-IRR-table tr.a-IRR-header--group th,',
'.a-IRR-table td.a-IRR-header--group,',
'.a-IRR-table th.a-IRR-header--group,',
'.a-IRR-table .a-IRR-header--group,',
'.a-IRR-table .a-IRR-controlBreak {',
'    display: table-cell !important;',
'    background: #f8fafc !important;',
'    border-left: 4px solid #008744 !important;',
'    border-top: 1px solid #e2e8f0 !important;',
'    border-bottom: 1px solid #e2e8f0 !important;',
'    border-right: none !important;',
'    color: #0f172a !important;',
'    font-weight: 700 !important;',
'    font-size: 13px !important;',
'    padding: 8px 12px !important;',
'    text-align: left !important;',
'    letter-spacing: 0.3px;',
'    visibility: visible !important;',
'    opacity: 1 !important;',
'}',
'.a-IRR-header-groupLabel,',
'.a-IRR-table .a-IRR-header-groupLabel {',
'    display: none !important;',
'}',
'',
'/* Custom Row-Card Styles (Compact & Sin bordes verticales de columnas) */',
'#reporte_prod_alt .a-IRR-table,',
'#reporte_rutas .a-IRR-table,',
'#reporte_proveedores .a-IRR-table,',
'#reporte_negociaciones .a-IRR-table,',
'#reporte_ocs .a-IRR-table {',
'    border: none !important;',
'    border-collapse: collapse !important;',
'    box-shadow: none !important;',
'}',
'#reporte_prod_alt .a-IRR-tableContainer,',
'#reporte_rutas .a-IRR-tableContainer,',
'#reporte_proveedores .a-IRR-tableContainer,',
'#reporte_negociaciones .a-IRR-tableContainer,',
'#reporte_ocs .a-IRR-tableContainer {',
'    border: none !important;',
'}',
'#reporte_prod_alt .a-IRR-table td,',
'#reporte_rutas .a-IRR-table td,',
'#reporte_proveedores .a-IRR-table td,',
'#reporte_negociaciones .a-IRR-table td,',
'#reporte_ocs .a-IRR-table td {',
'    padding: 6px 8px !important;',
'    vertical-align: middle !important;',
'    border-left: none !important;',
'    border-right: none !important;',
'    border-top: none !important;',
'    border-bottom: 1px solid #f1f5f9 !important;',
'}',
'#reporte_prod_alt .a-IRR-table tr,',
'#reporte_rutas .a-IRR-table tr,',
'#reporte_proveedores .a-IRR-table tr,',
'#reporte_negociaciones .a-IRR-table tr,',
'#reporte_ocs .a-IRR-table tr {',
'    height: auto !important;',
'    border: none !important;',
'}',
'',
'/* Columna de Checkbox compacta sin borde lateral */',
'.a-IRR-table th:first-child,',
'.a-IRR-table td:first-child,',
'.a-IRR-table th[id*="SELECCION"],',
'.a-IRR-table td[headers*="SELECCION"] {',
'    width: 38px !important;',
'    min-width: 38px !important;',
'    max-width: 42px !important;',
'    padding: 4px 2px !important;',
'    text-align: center !important;',
'    border-right: none !important;',
'}',
'.chk-aprobacion, .chk-all-aprobaciones {',
'    cursor: pointer;',
'    margin: 0 !important;',
'    display: inline-block;',
'    vertical-align: middle;',
'}',
'',
'.compra-card-row {',
'    display: flex;',
'    align-items: center;',
'    justify-content: space-between;',
'    padding: 2px 0;',
'    width: 100%;',
'    box-sizing: border-box;',
'    gap: 12px;',
'}',
'.compra-card-main {',
'    display: flex;',
'    flex-direction: column;',
'    gap: 2px;',
'    flex: 1;',
'    min-width: 0;',
'}',
'.compra-card-title {',
'    font-size: 13.5px;',
'    font-weight: 700;',
'    color: #0f172a;',
'    line-height: 1.2;',
'}',
'.compra-card-subtitle {',
'    font-size: 11.5px;',
'    color: #64748b;',
'    line-height: 1.2;',
'}',
'.compra-card-tags {',
'    display: flex;',
'    align-items: center;',
'    gap: 4px;',
'    flex-wrap: wrap;',
'    margin-top: 1px;',
'}',
'.compra-badge {',
'    display: inline-flex;',
'    align-items: center;',
'    gap: 3px;',
'    font-size: 10.5px;',
'    font-weight: 600;',
'    padding: 1px 6px;',
'    border-radius: 4px;',
'    line-height: 1.25;',
'}',
'.badge-categoria {',
'    background-color: #e0f2fe;',
'    color: #0369a1;',
'}',
'.badge-subcategoria {',
'    background-color: #f8fafc;',
'    color: #475569;',
'    border: 1px solid #cbd5e1;',
'    text-transform: uppercase;',
'    font-size: 9.5px;',
'    font-weight: 700;',
'}',
'.badge-intencion {',
'    background-color: #fef3c7;',
'    color: #92400e;',
'    border: 1px solid #fde68a;',
'}',
'.badge-creacion {',
'    background-color: #f0fdf4;',
'    color: #166534;',
'    border: 1px solid #bbf7d0;',
'}',
'.badge-inactivacion {',
'    background-color: #fef2f2;',
'    color: #991b1b;',
'    border: 1px solid #fecaca;',
'}',
'.badge-reactivacion {',
'    background-color: #eff6ff;',
'    color: #1e40af;',
'    border: 1px solid #bfdbfe;',
'}',
'.badge-usuario {',
'    background-color: #f3e8ff;',
'    color: #6b21a8;',
'    border: 1px solid #d8b4fe;',
'}',
'.compra-card-right {',
'    display: flex;',
'    flex-direction: column;',
'    align-items: flex-end;',
'    justify-content: center;',
'    gap: 1px;',
'    text-align: right;',
'    min-width: 120px;',
'    flex-shrink: 0;',
'}',
'.compra-card-amount {',
'    font-size: 14px;',
'    font-weight: 700;',
'    color: #0f172a;',
'    letter-spacing: -0.2px;',
'}',
'.compra-card-currency {',
'    font-size: 10px;',
'    color: #94a3b8;',
'    font-weight: 600;',
'    text-transform: uppercase;',
'}',
'.compra-card-antiguedad {',
'    font-size: 10.5px;',
'    color: #94a3b8;',
'    margin-bottom: 1px;',
'}',
'.compra-status-pill {',
'    display: inline-flex;',
'    align-items: center;',
'    gap: 4px;',
'    padding: 2px 8px;',
'    border-radius: 10px;',
'    font-size: 10.5px;',
'    font-weight: 700;',
'}',
'.status-pendiente {',
'    background-color: #fffbeb;',
'    color: #b45309;',
'    border: 1px solid #fde68a;',
'}',
'.status-dot {',
'    width: 5px;',
'    height: 5px;',
'    background-color: #d97706;',
'    border-radius: 50%;',
'    display: inline-block;',
'}'))
,p_page_template_options=>'#DEFAULT#'
,p_page_component_map=>'25'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(318093000447815539)
,p_plug_name=>'Parametros'
,p_region_template_options=>'#DEFAULT#:t-Form--large:t-Form--stretchInputs:t-Form--leftLabels'
,p_plug_template=>wwv_flow_imp.id(296121421643169165)
,p_plug_display_sequence=>50
,p_location=>null
,p_plug_column_width=>'style="display:none"'
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(326371495863427050)
,p_plug_name=>'Contenedor'
,p_region_template_options=>'#DEFAULT#:t-Form--large:t-Form--stretchInputs:t-Form--leftLabels'
,p_plug_template=>wwv_flow_imp.id(296121421643169165)
,p_plug_display_sequence=>10
,p_location=>null
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(280271272655322022)
,p_plug_name=>unistr('Informaci\00F3n')
,p_region_name=>'infirmacion'
,p_parent_plug_id=>wwv_flow_imp.id(326371495863427050)
,p_region_template_options=>'#DEFAULT#'
,p_plug_template=>wwv_flow_imp.id(295608822663037671)
,p_plug_display_sequence=>40
,p_plug_new_grid_row=>false
,p_plug_display_point=>'SUB_REGIONS'
,p_location=>null
,p_function_body_language=>'PLSQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    v_resultado CLOB := ''<div style="padding:40px; text-align:center; color:#777; font-weight:500;">'' ||',
'                            ''<span class="fa fa-mouse-pointer" style="font-size:24px; color:#ccc; display:block; margin-bottom:10px;"></span>'' ||',
unistr('                            ''Seleccione un registro de la lista para cargar su informaci\00F3n.'' ||'),
'                        ''</div>'';',
'    v_cont number := 0;',
'    v_es_oc number := 0;',
'    v_cant_ids number := 0;',
'    v_primer_id number := null;',
'BEGIN',
'    IF :P290_ID_SELECCIONADO IS NOT NULL THEN',
'        SELECT count(*)',
'          INTO v_cant_ids',
'          FROM TABLE(apex_string.split(:P290_ID_SELECCIONADO, '',''))',
'         WHERE TRIM(column_value) IS NOT NULL',
'           AND REGEXP_LIKE(TRIM(column_value), ''^[0-9]+$'');',
'',
'        IF v_cant_ids > 0 THEN',
'            SELECT count(*)',
'              INTO v_es_oc',
'              FROM data.t_corp_aprobaciones a',
'             WHERE a.id IN (',
'                 SELECT TO_NUMBER(TRIM(column_value))',
'                 FROM TABLE(apex_string.split(:P290_ID_SELECCIONADO, '',''))',
'                 WHERE TRIM(column_value) IS NOT NULL',
'                   AND REGEXP_LIKE(TRIM(column_value), ''^[0-9]+$'')',
'             )',
'             AND a.codmodulo = ''COMP''',
'             AND a.tipoproceso = ''ORDCP''',
'             AND a.etiqueta1 = ''ORDENES_COMPRA'';',
'',
'            IF v_es_oc > 0 THEN',
'                DATA.PK_COMP_ORDENESCOMPRA_V2.sp_html_orden_compra_consolidada(',
'                    p_lista_ids => :P290_ID_SELECCIONADO,',
'                    p_usuario   => :APP_USER,',
'                    p_compania  => :G_COMPANIA,',
'                    o_html      => v_resultado',
'                );',
'            ELSIF v_cant_ids = 1 THEN',
'                SELECT TO_NUMBER(TRIM(column_value))',
'                  INTO v_primer_id',
'                  FROM TABLE(apex_string.split(:P290_ID_SELECCIONADO, '',''))',
'                 WHERE TRIM(column_value) IS NOT NULL',
'                   AND REGEXP_LIKE(TRIM(column_value), ''^[0-9]+$'')',
'                   AND ROWNUM = 1;',
'',
'                SELECT count(id) into v_cont',
'                FROM t_corp_aprobaciones',
'                WHERE id = v_primer_id;',
'',
'                if v_cont > 0 then ',
'                    SELECT objeto1 into v_resultado',
'                    FROM t_corp_aprobaciones',
'                    WHERE id = v_primer_id;',
'                end if;',
'            ELSE',
'                v_resultado := ''<div style="padding:40px; text-align:center; color:#475569;">'' ||',
'                                    ''<span class="fa fa-info-circle" style="font-size:32px; color:#3b82f6; display:block; margin-bottom:12px;"></span>'' ||',
'                                    ''<strong style="font-size:15px;">'' || v_cant_ids || '' registros seleccionados</strong>'' ||',
unistr('                                    ''<p style="color:#64748b; font-size:13px; margin-top:8px;">La vista previa individual no est\00E1 disponible para selecci\00F3n m\00FAltiple en esta pesta\00F1a.</p>'' ||'),
'                                ''</div>'';',
'            END IF;',
'',
'            -- Sanitize: strip full-document tags that pollute APEX global styles',
'            v_resultado := REGEXP_REPLACE(v_resultado, ''<(!DOCTYPE|/?html|/?head|/?meta)[^>]*>'', '''', 1, 0, ''i'');',
'            -- Scope body CSS selector to .aprobacion-card so it does not override page body',
'            v_resultado := REPLACE(v_resultado, ''body{'', ''.aprobacion-card{'');',
'            -- Scope global * and table selectors to avoid overriding APEX styles',
'            v_resultado := REPLACE(v_resultado, ''*{box-sizing'', ''.aprobacion-card *{box-sizing'');',
'            v_resultado := REPLACE(v_resultado, ''table{width'', ''.aprobacion-card table{width'');',
'            -- Replace <body> / </body> tags with a scoped wrapper div',
'            v_resultado := REGEXP_REPLACE(v_resultado, ''<body[^>]*>'', ''<div class="aprobacion-card">'', 1, 0, ''i'');',
'            v_resultado := REPLACE(v_resultado, ''</body>'', ''</div>'');',
'        END IF;',
'    END IF;',
'',
'    RETURN v_resultado;',
'END;'))
,p_lazy_loading=>false
,p_plug_source_type=>'NATIVE_DYNAMIC_CONTENT'
,p_ajax_items_to_submit=>'P290_ID_SELECCIONADO'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(320776818448241926)
,p_plug_name=>'Listas'
,p_parent_plug_id=>wwv_flow_imp.id(326371495863427050)
,p_region_template_options=>'#DEFAULT#:js-useLocalStorage:t-TabsRegion-mod--fillLabels:t-TabsRegion-mod--pill:t-TabsRegion-mod--small'
,p_plug_template=>wwv_flow_imp.id(295637154502037690)
,p_plug_display_sequence=>20
,p_plug_display_point=>'SUB_REGIONS'
,p_location=>null
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(320776936700241927)
,p_plug_name=>'Rutas'
,p_region_name=>'reporte_rutas'
,p_parent_plug_id=>wwv_flow_imp.id(320776818448241926)
,p_region_template_options=>'#DEFAULT#'
,p_component_template_options=>'#DEFAULT#'
,p_plug_template=>wwv_flow_imp.id(295629242996037685)
,p_plug_display_sequence=>40
,p_plug_display_point=>'SUB_REGIONS'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'select case when a.USUARIOACTUAL = :APP_USER then',
'         APEX_ITEM.CHECKBOX2(',
'           p_idx => 1,',
'           p_value => a.ID,',
'           p_attributes => ''class="chk-aprobacion" data-id="'' || a.ID || ''"''',
'         )',
'       else',
'         APEX_ITEM.CHECKBOX2(',
'           p_idx => 1,',
'           p_value => a.ID,',
'           p_attributes => ''disabled="disabled" class="chk-aprobacion-disabled"''',
'         )',
'       end AS SELECCION,',
'       a.ID,',
'       ''<div class="compra-card-row" data-id="'' || a.ID || ''">'' ||',
'         ''<div class="compra-card-main">'' ||',
'           ''<div class="compra-card-title">'' || apex_escape.html(nvl(a.DESCRIPCION1, ''CONFIGURACION RUTA #'' || a.NUMEROPROCESO)) || ''</div>'' ||',
'           ''<div class="compra-card-subtitle">'' || apex_escape.html(nvl(a.DESCRIPCION2, ''ID Proceso: '' || a.NUMEROPROCESO)) || ''</div>'' ||',
'           ''<div class="compra-card-tags">'' ||',
'             case',
'               when a.DESCRIPCION3 is not null then',
'                 regexp_replace(',
'                   apex_escape.html(a.DESCRIPCION3),',
'                   ''([^|]+)(\|?)'',',
'                   ''<span class="compra-badge badge-subcategoria">\1</span>''',
'                 )',
'             end ||',
'             case when a.USUARIOACTUAL is not null then ''<span class="compra-badge badge-usuario"><span class="fa fa-user"></span> Turno: '' || apex_escape.html(a.USUARIOACTUAL) || ''</span>'' end ||',
'             ''<button type="button" class="btn-flujo-modal" data-id="'' || a.ID || ''" title="Ver Ruta y Comentarios"><span class="fa fa-sitemap"></span> Flujo</button>'' ||',
'           ''</div>'' ||',
'         ''</div>'' ||',
'         ''<div class="compra-card-right">'' ||',
'           ''<div class="compra-card-amount">'' || ''RUTA-'' || a.NUMEROPROCESO || ''</div>'' ||',
'           ''<div class="compra-card-currency">'' || nvl(a.CODMODULO, ''COMP'') || ''</div>'' ||',
unistr('           ''<div class="compra-card-antiguedad">'' || trunc(sysdate - cast(a.FECHCREA as date)) || ''d antig\00FCedad</div>'' ||'),
'           ''<div class="compra-status-pill status-pendiente"><span class="status-dot"></span> '' || a.ESTADO || ''</div>'' ||',
'         ''</div>'' ||',
'       ''</div>'' AS CARD_HTML,',
'       a.USERCREA,',
'       a.FECHCREA,',
'       a.USERMODI,',
'       a.FECHMODI,',
'       a.COMPANIA,',
'       a.CODMODULO,',
'       a.TIPOPROCESO,',
'       a.NUMEROPROCESO,',
'       a.DESCRIPCION1,',
'       a.DESCRIPCION2,',
'       a.DESCRIPCION3,',
'       a.DESCRIPCION4,',
'       a.DESCRIPCION5,',
'       a.ESTADO,',
'       a.IDRUTAAPROBACION,',
'       a.IDFLUJOAPROBACION,',
'       a.USUARIOINICIA,',
'       a.USUARIOALTERNO,',
'       a.USUARIOACTUAL,',
'       case when a.USUARIOACTUAL = :APP_USER then 1 else 0 end as PUEDE_GESTIONAR,',
'       a.MONEDA,',
'       a.MONTOTOTAL',
'  from T_CORP_APROBACIONES a',
' where',
'   a.ETIQUETA1 = ''RUTAS''',
'   and a.ESTADO = ''EN RUTA''',
'   and ((a.USUARIOACTUAL = :APP_USER AND :P290_ESTADO = 1) or :P290_ESTADO = 2)'))
,p_plug_source_type=>'NATIVE_IR'
,p_ajax_items_to_submit=>'P290_ESTADO'
,p_prn_content_disposition=>'ATTACHMENT'
,p_prn_units=>'MILLIMETERS'
,p_prn_paper_size=>'A4'
,p_prn_width=>297
,p_prn_height=>210
,p_prn_orientation=>'HORIZONTAL'
,p_prn_page_header_font_color=>'#000000'
,p_prn_page_header_font_family=>'Helvetica'
,p_prn_page_header_font_weight=>'normal'
,p_prn_page_header_font_size=>'12'
,p_prn_page_footer_font_color=>'#000000'
,p_prn_page_footer_font_family=>'Helvetica'
,p_prn_page_footer_font_weight=>'normal'
,p_prn_page_footer_font_size=>'12'
,p_prn_header_bg_color=>'#EEEEEE'
,p_prn_header_font_color=>'#000000'
,p_prn_header_font_family=>'Helvetica'
,p_prn_header_font_weight=>'bold'
,p_prn_header_font_size=>'10'
,p_prn_body_bg_color=>'#FFFFFF'
,p_prn_body_font_color=>'#000000'
,p_prn_body_font_family=>'Helvetica'
,p_prn_body_font_weight=>'normal'
,p_prn_body_font_size=>'10'
,p_prn_border_width=>.5
,p_prn_page_header_alignment=>'CENTER'
,p_prn_page_footer_alignment=>'CENTER'
,p_prn_border_color=>'#666666'
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(320777058880241928)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_owner=>'MFERRIN'
,p_internal_uid=>320777058880241928
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320777177521241929)
,p_db_column_name=>'SELECCION'
,p_display_order=>10
,p_column_identifier=>'A'
,p_column_label=>'<input type="checkbox" id="chk-todos-aprobaciones" class="chk-all-aprobaciones" title="Seleccionar todos">'
,p_allow_sorting=>'N'
,p_allow_filtering=>'N'
,p_allow_highlighting=>'N'
,p_allow_ctrl_breaks=>'N'
,p_allow_aggregations=>'N'
,p_allow_computations=>'N'
,p_allow_charting=>'N'
,p_allow_group_by=>'N'
,p_allow_pivot=>'N'
,p_allow_hide=>'N'
,p_column_type=>'STRING'
,p_display_text_as=>'WITHOUT_MODIFICATION'
,p_column_alignment=>'CENTER'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320777177521241900)
,p_db_column_name=>'CARD_HTML'
,p_display_order=>15
,p_column_identifier=>'CRD_RUT'
,p_column_label=>'&nbsp;'
,p_allow_sorting=>'N'
,p_allow_filtering=>'N'
,p_allow_highlighting=>'N'
,p_allow_ctrl_breaks=>'N'
,p_allow_aggregations=>'N'
,p_allow_computations=>'N'
,p_allow_charting=>'N'
,p_allow_group_by=>'N'
,p_allow_pivot=>'N'
,p_allow_hide=>'N'
,p_column_type=>'STRING'
,p_display_text_as=>'WITHOUT_MODIFICATION'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320777200279241930)
,p_db_column_name=>'ID'
,p_display_order=>20
,p_column_identifier=>'B'
,p_column_label=>'Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320777371455241931)
,p_db_column_name=>'USERCREA'
,p_display_order=>30
,p_column_identifier=>'C'
,p_column_label=>'Usercrea'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320777448627241932)
,p_db_column_name=>'FECHCREA'
,p_display_order=>40
,p_column_identifier=>'D'
,p_column_label=>'Fechcrea'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320777515668241933)
,p_db_column_name=>'USERMODI'
,p_display_order=>50
,p_column_identifier=>'E'
,p_column_label=>'Usermodi'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320777638358241934)
,p_db_column_name=>'FECHMODI'
,p_display_order=>60
,p_column_identifier=>'F'
,p_column_label=>'Fechmodi'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320777770918241935)
,p_db_column_name=>'COMPANIA'
,p_display_order=>70
,p_column_identifier=>'G'
,p_column_label=>'Compania'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320777851878241936)
,p_db_column_name=>'CODMODULO'
,p_display_order=>80
,p_column_identifier=>'H'
,p_column_label=>'Codmodulo'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320777960505241937)
,p_db_column_name=>'TIPOPROCESO'
,p_display_order=>90
,p_column_identifier=>'I'
,p_column_label=>'Tipoproceso'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320778069078241938)
,p_db_column_name=>'NUMEROPROCESO'
,p_display_order=>100
,p_column_identifier=>'J'
,p_column_label=>'Numeroproceso'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320778125744241939)
,p_db_column_name=>'DESCRIPCION1'
,p_display_order=>110
,p_column_identifier=>'K'
,p_column_label=>'Descripcion 1'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320778245904241940)
,p_db_column_name=>'DESCRIPCION2'
,p_display_order=>120
,p_column_identifier=>'L'
,p_column_label=>'Descripcion 2'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320778358426241941)
,p_db_column_name=>'DESCRIPCION3'
,p_display_order=>130
,p_column_identifier=>'M'
,p_column_label=>'Descripcion 3'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320778431664241942)
,p_db_column_name=>'DESCRIPCION4'
,p_display_order=>140
,p_column_identifier=>'N'
,p_column_label=>'Descripcion 4'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320778533586241943)
,p_db_column_name=>'DESCRIPCION5'
,p_display_order=>150
,p_column_identifier=>'O'
,p_column_label=>'Descripcion 5'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320778623842241944)
,p_db_column_name=>'ESTADO'
,p_display_order=>160
,p_column_identifier=>'P'
,p_column_label=>'Estado'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320778743456241945)
,p_db_column_name=>'IDRUTAAPROBACION'
,p_display_order=>170
,p_column_identifier=>'Q'
,p_column_label=>'Idrutaaprobacion'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320778813182241946)
,p_db_column_name=>'IDFLUJOAPROBACION'
,p_display_order=>180
,p_column_identifier=>'R'
,p_column_label=>'Idflujoaprobacion'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320778972962241947)
,p_db_column_name=>'USUARIOINICIA'
,p_display_order=>190
,p_column_identifier=>'S'
,p_column_label=>'Usuarioinicia'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320779037869241948)
,p_db_column_name=>'USUARIOALTERNO'
,p_display_order=>200
,p_column_identifier=>'T'
,p_column_label=>'Usuarioalterno'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320779106727241949)
,p_db_column_name=>'USUARIOACTUAL'
,p_display_order=>210
,p_column_identifier=>'U'
,p_column_label=>'Usuarioactual'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320779275804241950)
,p_db_column_name=>'PUEDE_GESTIONAR'
,p_display_order=>220
,p_column_identifier=>'V'
,p_column_label=>'Puede Gestionar'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331136795996670301)
,p_db_column_name=>'MONEDA'
,p_display_order=>230
,p_column_identifier=>'W'
,p_column_label=>'Moneda'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331136876038670302)
,p_db_column_name=>'MONTOTOTAL'
,p_display_order=>240
,p_column_identifier=>'X'
,p_column_label=>'Montototal'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(331149747817670933)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'3311498'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'SELECCION:CARD_HTML:'
,p_sort_column_1=>'ID'
,p_sort_direction_1=>'DESC'
,p_sort_column_2=>'0'
,p_sort_direction_2=>'ASC'
,p_sort_column_3=>'0'
,p_sort_direction_3=>'ASC'
,p_sort_column_4=>'0'
,p_sort_direction_4=>'ASC'
,p_sort_column_5=>'0'
,p_sort_direction_5=>'ASC'
,p_sort_column_6=>'0'
,p_sort_direction_6=>'ASC'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(324449336739451203)
,p_plug_name=>'Maestro Alterno Productos'
,p_region_name=>'reporte_prod_alt'
,p_parent_plug_id=>wwv_flow_imp.id(320776818448241926)
,p_region_template_options=>'#DEFAULT#'
,p_component_template_options=>'#DEFAULT#'
,p_plug_template=>wwv_flow_imp.id(295629242996037685)
,p_plug_display_sequence=>50
,p_plug_display_point=>'SUB_REGIONS'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'select case when a.USUARIOACTUAL = :APP_USER then',
'         APEX_ITEM.CHECKBOX2(',
'           p_idx => 1,',
'           p_value => a.ID,',
'           p_attributes => ''class="chk-aprobacion" data-id="'' || a.ID || ''"''',
'         )',
'       else',
'         APEX_ITEM.CHECKBOX2(',
'           p_idx => 1,',
'           p_value => a.ID,',
'           p_attributes => ''disabled="disabled" class="chk-aprobacion-disabled"''',
'         )',
'       end AS SELECCION,',
'       a.ID,',
'       ''<div class="compra-card-row" data-id="'' || a.ID || ''">'' ||',
'         ''<div class="compra-card-main">'' ||',
'           ''<div class="compra-card-title">'' || apex_escape.html(nvl(a.DESCRIPCION1, ''PRODUCTO ALTERNO #'' || a.NUMEROPROCESO)) || ''</div>'' ||',
'           ''<div class="compra-card-subtitle">'' || apex_escape.html(nvl(a.DESCRIPCION2, ''ID Proceso: '' || a.NUMEROPROCESO)) || ''</div>'' ||',
'           ''<div class="compra-card-tags">'' ||',
'             case when a.DESCRIPCION3 is not null then ''<span class="compra-badge badge-categoria">'' || apex_escape.html(a.DESCRIPCION3) || ''</span>'' end ||',
'             case when a.DESCRIPCION4 is not null then ''<span class="compra-badge badge-subcategoria">'' || apex_escape.html(a.DESCRIPCION4) || ''</span>'' end ||',
'             case',
unistr('               when upper(a.DESCRIPCION5) = ''CREACION'' then ''<span class="compra-badge badge-creacion"><span class="fa fa-plus-circle"></span> Creaci\00F3n</span>'''),
unistr('               when upper(a.DESCRIPCION5) = ''INACTIVACION'' then ''<span class="compra-badge badge-inactivacion"><span class="fa fa-ban"></span> Inactivaci\00F3n</span>'''),
unistr('               when upper(a.DESCRIPCION5) = ''REACTIVACION'' then ''<span class="compra-badge badge-reactivacion"><span class="fa fa-refresh"></span> Reactivaci\00F3n</span>'''),
'               when a.DESCRIPCION5 is not null then ''<span class="compra-badge badge-intencion">'' || apex_escape.html(a.DESCRIPCION5) || ''</span>''',
'             end ||',
'             case when a.USUARIOACTUAL is not null then ''<span class="compra-badge badge-usuario"><span class="fa fa-user"></span> Turno: '' || apex_escape.html(a.USUARIOACTUAL) || ''</span>'' end ||',
'             ''<button type="button" class="btn-flujo-modal" data-id="'' || a.ID || ''" title="Ver Ruta y Comentarios"><span class="fa fa-sitemap"></span> Flujo</button>'' ||',
'           ''</div>'' ||',
'         ''</div>'' ||',
'         ''<div class="compra-card-right">'' ||',
'           ''<div class="compra-card-amount">'' ||',
'             case',
'               when a.MONTOTOTAL is not null and a.MONTOTOTAL >= 1000000 then ''$'' || trim(to_char(a.MONTOTOTAL/1000000, ''FM999G990D00'')) || ''M''',
'               when a.MONTOTOTAL is not null then ''$ '' || trim(to_char(a.MONTOTOTAL, ''FM999G999G990D00''))',
'               else ''ALTRN-'' || a.NUMEROPROCESO',
'             end ||',
'           ''</div>'' ||',
'           ''<div class="compra-card-currency">'' || nvl(a.MONEDA, ''COMPRAS'') || ''</div>'' ||',
unistr('           ''<div class="compra-card-antiguedad">'' || trunc(sysdate - cast(a.FECHCREA as date)) || ''d antig\00FCedad</div>'' ||'),
'           ''<div class="compra-status-pill status-pendiente"><span class="status-dot"></span> '' || a.ESTADO || ''</div>'' ||',
'         ''</div>'' ||',
'       ''</div>'' AS CARD_HTML,',
'       a.USERCREA,',
'       a.FECHCREA,',
'       a.USERMODI,',
'       a.FECHMODI,',
'       a.COMPANIA,',
'       a.CODMODULO,',
'       a.TIPOPROCESO,',
'       a.NUMEROPROCESO,',
'       a.DESCRIPCION1,',
'       a.DESCRIPCION2,',
'       a.DESCRIPCION3,',
'       a.DESCRIPCION4,',
'       a.DESCRIPCION5,',
'       a.ESTADO,',
'       a.IDRUTAAPROBACION,',
'       a.IDFLUJOAPROBACION,',
'       a.USUARIOINICIA,',
'       a.USUARIOALTERNO,',
'       a.USUARIOACTUAL,',
'       case when a.USUARIOACTUAL = :APP_USER then 1 else 0 end as PUEDE_GESTIONAR,',
'       a.MONEDA,',
'       a.MONTOTOTAL',
'  from T_CORP_APROBACIONES a',
' where',
'   a.ETIQUETA1 = ''PRODUCTOS_ALTERNOS''',
'   and a.ESTADO = ''EN RUTA''',
'   and ((a.USUARIOACTUAL = :APP_USER AND :P290_ESTADO = 1) or :P290_ESTADO = 2)'))
,p_plug_source_type=>'NATIVE_IR'
,p_ajax_items_to_submit=>'P290_ESTADO'
,p_plug_display_condition_type=>'NEVER'
,p_prn_content_disposition=>'ATTACHMENT'
,p_prn_units=>'MILLIMETERS'
,p_prn_paper_size=>'A4'
,p_prn_width=>297
,p_prn_height=>210
,p_prn_orientation=>'HORIZONTAL'
,p_prn_page_header_font_color=>'#000000'
,p_prn_page_header_font_family=>'Helvetica'
,p_prn_page_header_font_weight=>'normal'
,p_prn_page_header_font_size=>'12'
,p_prn_page_footer_font_color=>'#000000'
,p_prn_page_footer_font_family=>'Helvetica'
,p_prn_page_footer_font_weight=>'normal'
,p_prn_page_footer_font_size=>'12'
,p_prn_header_bg_color=>'#EEEEEE'
,p_prn_header_font_color=>'#000000'
,p_prn_header_font_family=>'Helvetica'
,p_prn_header_font_weight=>'bold'
,p_prn_header_font_size=>'10'
,p_prn_body_bg_color=>'#FFFFFF'
,p_prn_body_font_color=>'#000000'
,p_prn_body_font_family=>'Helvetica'
,p_prn_body_font_weight=>'normal'
,p_prn_body_font_size=>'10'
,p_prn_border_width=>.5
,p_prn_page_header_alignment=>'CENTER'
,p_prn_page_footer_alignment=>'CENTER'
,p_prn_border_color=>'#666666'
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(324449489224451204)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_owner=>'MFERRIN'
,p_internal_uid=>324449489224451204
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324449500000451200)
,p_db_column_name=>'SELECCION'
,p_display_order=>5
,p_column_identifier=>'AA'
,p_column_label=>'<input type="checkbox" id="chk-todos-aprobaciones" class="chk-all-aprobaciones" title="Seleccionar todos">'
,p_allow_sorting=>'N'
,p_allow_filtering=>'N'
,p_allow_highlighting=>'N'
,p_allow_ctrl_breaks=>'N'
,p_allow_aggregations=>'N'
,p_allow_computations=>'N'
,p_allow_charting=>'N'
,p_allow_group_by=>'N'
,p_allow_pivot=>'N'
,p_allow_hide=>'N'
,p_column_type=>'STRING'
,p_display_text_as=>'WITHOUT_MODIFICATION'
,p_column_alignment=>'CENTER'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324449500000451201)
,p_db_column_name=>'CARD_HTML'
,p_display_order=>8
,p_column_identifier=>'CRD'
,p_column_label=>'&nbsp;'
,p_allow_sorting=>'N'
,p_allow_filtering=>'N'
,p_allow_highlighting=>'N'
,p_allow_ctrl_breaks=>'N'
,p_allow_aggregations=>'N'
,p_allow_computations=>'N'
,p_allow_charting=>'N'
,p_allow_group_by=>'N'
,p_allow_pivot=>'N'
,p_allow_hide=>'N'
,p_column_type=>'STRING'
,p_display_text_as=>'WITHOUT_MODIFICATION'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324449584566451205)
,p_db_column_name=>'ID'
,p_display_order=>10
,p_column_identifier=>'A'
,p_column_label=>'Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324449645408451206)
,p_db_column_name=>'USERCREA'
,p_display_order=>20
,p_column_identifier=>'B'
,p_column_label=>'Usercrea'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324449701295451207)
,p_db_column_name=>'FECHCREA'
,p_display_order=>30
,p_column_identifier=>'C'
,p_column_label=>'Fechcrea'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324449822458451208)
,p_db_column_name=>'USERMODI'
,p_display_order=>40
,p_column_identifier=>'D'
,p_column_label=>'Usermodi'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324449905175451209)
,p_db_column_name=>'FECHMODI'
,p_display_order=>50
,p_column_identifier=>'E'
,p_column_label=>'Fechmodi'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324450063452451210)
,p_db_column_name=>'COMPANIA'
,p_display_order=>60
,p_column_identifier=>'F'
,p_column_label=>'Compania'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324450185019451211)
,p_db_column_name=>'CODMODULO'
,p_display_order=>70
,p_column_identifier=>'G'
,p_column_label=>'Codmodulo'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324450239069451212)
,p_db_column_name=>'TIPOPROCESO'
,p_display_order=>80
,p_column_identifier=>'H'
,p_column_label=>'Tipoproceso'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324450355817451213)
,p_db_column_name=>'NUMEROPROCESO'
,p_display_order=>90
,p_column_identifier=>'I'
,p_column_label=>'Numeroproceso'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324450469263451214)
,p_db_column_name=>'DESCRIPCION1'
,p_display_order=>100
,p_column_identifier=>'J'
,p_column_label=>'Descripcion 1'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324450469263451220)
,p_db_column_name=>'DESCRIPCION2'
,p_display_order=>101
,p_column_identifier=>'R'
,p_column_label=>'Descripcion 2'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324450469263451221)
,p_db_column_name=>'DESCRIPCION3'
,p_display_order=>102
,p_column_identifier=>'S'
,p_column_label=>'Descripcion 3'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324450469263451222)
,p_db_column_name=>'DESCRIPCION4'
,p_display_order=>103
,p_column_identifier=>'T'
,p_column_label=>'Descripcion 4'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324450469263451223)
,p_db_column_name=>'DESCRIPCION5'
,p_display_order=>104
,p_column_identifier=>'U'
,p_column_label=>'Descripcion 5'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324450564138451215)
,p_db_column_name=>'ESTADO'
,p_display_order=>110
,p_column_identifier=>'K'
,p_column_label=>'Estado'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324450687300451216)
,p_db_column_name=>'IDRUTAAPROBACION'
,p_display_order=>120
,p_column_identifier=>'L'
,p_column_label=>'Idrutaaprobacion'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324450705442451217)
,p_db_column_name=>'IDFLUJOAPROBACION'
,p_display_order=>130
,p_column_identifier=>'M'
,p_column_label=>'Idflujoaprobacion'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324450883404451218)
,p_db_column_name=>'USUARIOINICIA'
,p_display_order=>140
,p_column_identifier=>'N'
,p_column_label=>'Usuarioinicia'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(324450997473451219)
,p_db_column_name=>'USUARIOALTERNO'
,p_display_order=>150
,p_column_identifier=>'O'
,p_column_label=>'Usuarioalterno'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320776726212241925)
,p_db_column_name=>'USUARIOACTUAL'
,p_display_order=>160
,p_column_identifier=>'V'
,p_column_label=>'Usuarioactual'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(320776800000241926)
,p_db_column_name=>'PUEDE_GESTIONAR'
,p_display_order=>170
,p_column_identifier=>'W'
,p_column_label=>'Puede Gestionar'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(329641692467628116)
,p_db_column_name=>'MONEDA'
,p_display_order=>180
,p_column_identifier=>'AB'
,p_column_label=>'Moneda'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(329641749992628117)
,p_db_column_name=>'MONTOTOTAL'
,p_display_order=>190
,p_column_identifier=>'AC'
,p_column_label=>'Montototal'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(324807676992590469)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'3248077'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'SELECCION:CARD_HTML:'
,p_sort_column_1=>'ID'
,p_sort_direction_1=>'DESC'
,p_sort_column_2=>'0'
,p_sort_direction_2=>'ASC'
,p_sort_column_3=>'0'
,p_sort_direction_3=>'ASC'
,p_sort_column_4=>'0'
,p_sort_direction_4=>'ASC'
,p_sort_column_5=>'0'
,p_sort_direction_5=>'ASC'
,p_sort_column_6=>'0'
,p_sort_direction_6=>'ASC'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(331136982864670303)
,p_plug_name=>'Proveedores'
,p_region_name=>'reporte_proveedores'
,p_parent_plug_id=>wwv_flow_imp.id(320776818448241926)
,p_region_template_options=>'#DEFAULT#'
,p_component_template_options=>'#DEFAULT#'
,p_plug_template=>wwv_flow_imp.id(295629242996037685)
,p_plug_display_sequence=>30
,p_plug_display_point=>'SUB_REGIONS'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'select case when a.USUARIOACTUAL = :APP_USER then',
'         APEX_ITEM.CHECKBOX2(',
'           p_idx => 1,',
'           p_value => a.ID,',
'           p_attributes => ''class="chk-aprobacion" data-id="'' || a.ID || ''"''',
'         )',
'       else',
'         APEX_ITEM.CHECKBOX2(',
'           p_idx => 1,',
'           p_value => a.ID,',
'           p_attributes => ''disabled="disabled" class="chk-aprobacion-disabled"''',
'         )',
'       end AS SELECCION,',
'       a.ID,',
'       ''<div class="compra-card-row" data-id="'' || a.ID || ''">'' ||',
'         ''<div class="compra-card-main">'' ||',
'           ''<div class="compra-card-title">'' || apex_escape.html(nvl(a.DESCRIPCION1, ''PROVEEDOR #'' || a.NUMEROPROCESO)) || ''</div>'' ||',
'           ''<div class="compra-card-subtitle">'' || apex_escape.html(nvl(a.DESCRIPCION2, ''ID Proceso: '' || a.NUMEROPROCESO)) || ''</div>'' ||',
'           ''<div class="compra-card-tags">'' ||',
'             case when a.DESCRIPCION3 is not null then ''<span class="compra-badge badge-categoria">'' || apex_escape.html(a.DESCRIPCION3) || ''</span>'' end ||',
'             case when a.DESCRIPCION4 is not null then ''<span class="compra-badge badge-subcategoria">'' || apex_escape.html(a.DESCRIPCION4) || ''</span>'' end ||',
'             case',
unistr('               when upper(a.DESCRIPCION5) = ''CREACION'' then ''<span class="compra-badge badge-creacion"><span class="fa fa-plus-circle"></span> Creaci\00F3n</span>'''),
unistr('               when upper(a.DESCRIPCION5) = ''INACTIVACION'' then ''<span class="compra-badge badge-inactivacion"><span class="fa fa-ban"></span> Inactivaci\00F3n</span>'''),
unistr('               when upper(a.DESCRIPCION5) = ''REACTIVACION'' then ''<span class="compra-badge badge-reactivacion"><span class="fa fa-refresh"></span> Reactivaci\00F3n</span>'''),
unistr('               when upper(a.DESCRIPCION5) = ''ACTUALIZACION'' then ''<span class="compra-badge badge-intencion"><span class="fa fa-pencil"></span> Actualizaci\00F3n</span>'''),
'               when a.DESCRIPCION5 is not null then ''<span class="compra-badge badge-intencion">'' || apex_escape.html(a.DESCRIPCION5) || ''</span>''',
'             end ||',
'             case when a.USUARIOACTUAL is not null then ''<span class="compra-badge badge-usuario"><span class="fa fa-user"></span> Turno: '' || apex_escape.html(a.USUARIOACTUAL) || ''</span>'' end ||',
'             ''<button type="button" class="btn-flujo-modal" data-id="'' || a.ID || ''" title="Ver Ruta y Comentarios"><span class="fa fa-sitemap"></span> Flujo</button>'' ||',
'           ''</div>'' ||',
'         ''</div>'' ||',
'         ''<div class="compra-card-right">'' ||',
'           ''<div class="compra-card-amount">'' ||',
'             case',
'               when a.MONTOTOTAL is not null and a.MONTOTOTAL >= 1000000 then ''$'' || trim(to_char(a.MONTOTOTAL/1000000, ''FM999G990D00'')) || ''M''',
'               when a.MONTOTOTAL is not null then ''$ '' || trim(to_char(a.MONTOTOTAL, ''FM999G999G990D00''))',
'               else ''PRV-'' || a.NUMEROPROCESO',
'             end ||',
'           ''</div>'' ||',
'           ''<div class="compra-card-currency">'' || nvl(a.MONEDA, ''COMPRAS'') || ''</div>'' ||',
unistr('           ''<div class="compra-card-antiguedad">'' || trunc(sysdate - cast(a.FECHCREA as date)) || ''d antig\00FCedad</div>'' ||'),
'           ''<div class="compra-status-pill status-pendiente"><span class="status-dot"></span> '' || a.ESTADO || ''</div>'' ||',
'         ''</div>'' ||',
'       ''</div>'' AS CARD_HTML,',
'       a.USERCREA,',
'       a.FECHCREA,',
'       a.USERMODI,',
'       a.FECHMODI,',
'       a.COMPANIA,',
'       a.CODMODULO,',
'       a.TIPOPROCESO,',
'       a.NUMEROPROCESO,',
'       a.DESCRIPCION1,',
'       a.DESCRIPCION2,',
'       a.DESCRIPCION3,',
'       a.DESCRIPCION4,',
'       a.DESCRIPCION5,',
'       a.ESTADO,',
'       a.IDRUTAAPROBACION,',
'       a.IDFLUJOAPROBACION,',
'       a.USUARIOINICIA,',
'       a.USUARIOALTERNO,',
'       a.USUARIOACTUAL,',
'       case when a.USUARIOACTUAL = :APP_USER then 1 else 0 end as PUEDE_GESTIONAR,',
'       a.MONEDA,',
'       a.MONTOTOTAL',
'  from T_CORP_APROBACIONES a',
' where',
'   a.ETIQUETA1 = ''PROVEEDORES''',
'   and a.ESTADO = ''EN RUTA''',
'   and ((a.USUARIOACTUAL = :APP_USER AND :P290_ESTADO = 1) or :P290_ESTADO = 2)'))
,p_plug_source_type=>'NATIVE_IR'
,p_ajax_items_to_submit=>'P290_ESTADO'
,p_prn_content_disposition=>'ATTACHMENT'
,p_prn_units=>'MILLIMETERS'
,p_prn_paper_size=>'A4'
,p_prn_width=>297
,p_prn_height=>210
,p_prn_orientation=>'HORIZONTAL'
,p_prn_page_header_font_color=>'#000000'
,p_prn_page_header_font_family=>'Helvetica'
,p_prn_page_header_font_weight=>'normal'
,p_prn_page_header_font_size=>'12'
,p_prn_page_footer_font_color=>'#000000'
,p_prn_page_footer_font_family=>'Helvetica'
,p_prn_page_footer_font_weight=>'normal'
,p_prn_page_footer_font_size=>'12'
,p_prn_header_bg_color=>'#EEEEEE'
,p_prn_header_font_color=>'#000000'
,p_prn_header_font_family=>'Helvetica'
,p_prn_header_font_weight=>'bold'
,p_prn_header_font_size=>'10'
,p_prn_body_bg_color=>'#FFFFFF'
,p_prn_body_font_color=>'#000000'
,p_prn_body_font_family=>'Helvetica'
,p_prn_body_font_weight=>'normal'
,p_prn_body_font_size=>'10'
,p_prn_border_width=>.5
,p_prn_page_header_alignment=>'CENTER'
,p_prn_page_footer_alignment=>'CENTER'
,p_prn_border_color=>'#666666'
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(331137033264670304)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_owner=>'MFERRIN'
,p_internal_uid=>331137033264670304
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331137195996670305)
,p_db_column_name=>'SELECCION'
,p_display_order=>10
,p_column_identifier=>'A'
,p_column_label=>'<input type="checkbox" id="chk-todos-aprobaciones" class="chk-all-aprobaciones" title="Seleccionar todos">'
,p_allow_sorting=>'N'
,p_allow_filtering=>'N'
,p_allow_highlighting=>'N'
,p_allow_ctrl_breaks=>'N'
,p_allow_aggregations=>'N'
,p_allow_computations=>'N'
,p_allow_charting=>'N'
,p_allow_group_by=>'N'
,p_allow_pivot=>'N'
,p_allow_hide=>'N'
,p_column_type=>'STRING'
,p_display_text_as=>'WITHOUT_MODIFICATION'
,p_column_alignment=>'CENTER'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331137195996670999)
,p_db_column_name=>'CARD_HTML'
,p_display_order=>15
,p_column_identifier=>'CRD_PRV'
,p_column_label=>'&nbsp;'
,p_allow_sorting=>'N'
,p_allow_filtering=>'N'
,p_allow_highlighting=>'N'
,p_allow_ctrl_breaks=>'N'
,p_allow_aggregations=>'N'
,p_allow_computations=>'N'
,p_allow_charting=>'N'
,p_allow_group_by=>'N'
,p_allow_pivot=>'N'
,p_allow_hide=>'N'
,p_column_type=>'STRING'
,p_display_text_as=>'WITHOUT_MODIFICATION'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331137234504670306)
,p_db_column_name=>'ID'
,p_display_order=>20
,p_column_identifier=>'B'
,p_column_label=>'Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331137392490670307)
,p_db_column_name=>'USERCREA'
,p_display_order=>30
,p_column_identifier=>'C'
,p_column_label=>'Usercrea'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331137400585670308)
,p_db_column_name=>'FECHCREA'
,p_display_order=>40
,p_column_identifier=>'D'
,p_column_label=>'Fechcrea'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331137551214670309)
,p_db_column_name=>'USERMODI'
,p_display_order=>50
,p_column_identifier=>'E'
,p_column_label=>'Usermodi'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331137628942670310)
,p_db_column_name=>'FECHMODI'
,p_display_order=>60
,p_column_identifier=>'F'
,p_column_label=>'Fechmodi'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331137766567670311)
,p_db_column_name=>'COMPANIA'
,p_display_order=>70
,p_column_identifier=>'G'
,p_column_label=>'Compania'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331137826329670312)
,p_db_column_name=>'CODMODULO'
,p_display_order=>80
,p_column_identifier=>'H'
,p_column_label=>'Codmodulo'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331137914310670313)
,p_db_column_name=>'TIPOPROCESO'
,p_display_order=>90
,p_column_identifier=>'I'
,p_column_label=>'Tipoproceso'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331138081161670314)
,p_db_column_name=>'NUMEROPROCESO'
,p_display_order=>100
,p_column_identifier=>'J'
,p_column_label=>'Numeroproceso'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331138114960670315)
,p_db_column_name=>'DESCRIPCION1'
,p_display_order=>110
,p_column_identifier=>'K'
,p_column_label=>'Descripcion 1'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331138201363670316)
,p_db_column_name=>'DESCRIPCION2'
,p_display_order=>120
,p_column_identifier=>'L'
,p_column_label=>'Descripcion 2'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331138375177670317)
,p_db_column_name=>'DESCRIPCION3'
,p_display_order=>130
,p_column_identifier=>'M'
,p_column_label=>'Descripcion 3'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331138490981670318)
,p_db_column_name=>'DESCRIPCION4'
,p_display_order=>140
,p_column_identifier=>'N'
,p_column_label=>'Descripcion 4'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331138515797670319)
,p_db_column_name=>'DESCRIPCION5'
,p_display_order=>150
,p_column_identifier=>'O'
,p_column_label=>'Descripcion 5'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331138684764670320)
,p_db_column_name=>'ESTADO'
,p_display_order=>160
,p_column_identifier=>'P'
,p_column_label=>'Estado'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331138700205670321)
,p_db_column_name=>'IDRUTAAPROBACION'
,p_display_order=>170
,p_column_identifier=>'Q'
,p_column_label=>'Idrutaaprobacion'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331138803423670322)
,p_db_column_name=>'IDFLUJOAPROBACION'
,p_display_order=>180
,p_column_identifier=>'R'
,p_column_label=>'Idflujoaprobacion'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331138903363670323)
,p_db_column_name=>'USUARIOINICIA'
,p_display_order=>190
,p_column_identifier=>'S'
,p_column_label=>'Usuarioinicia'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331139027185670324)
,p_db_column_name=>'USUARIOALTERNO'
,p_display_order=>200
,p_column_identifier=>'T'
,p_column_label=>'Usuarioalterno'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331139183226670325)
,p_db_column_name=>'USUARIOACTUAL'
,p_display_order=>210
,p_column_identifier=>'U'
,p_column_label=>'Usuarioactual'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331139231441670326)
,p_db_column_name=>'PUEDE_GESTIONAR'
,p_display_order=>220
,p_column_identifier=>'V'
,p_column_label=>'Puede Gestionar'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331139308618670327)
,p_db_column_name=>'MONEDA'
,p_display_order=>230
,p_column_identifier=>'W'
,p_column_label=>'Moneda'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331139431692670328)
,p_db_column_name=>'MONTOTOTAL'
,p_display_order=>240
,p_column_identifier=>'X'
,p_column_label=>'Montototal'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(331172482516706394)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'3311725'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'SELECCION:CARD_HTML'
,p_sort_column_1=>'ID'
,p_sort_direction_1=>'DESC'
,p_sort_column_2=>'0'
,p_sort_direction_2=>'ASC'
,p_sort_column_3=>'0'
,p_sort_direction_3=>'ASC'
,p_sort_column_4=>'0'
,p_sort_direction_4=>'ASC'
,p_sort_column_5=>'0'
,p_sort_direction_5=>'ASC'
,p_sort_column_6=>'0'
,p_sort_direction_6=>'ASC'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(331139517401670329)
,p_plug_name=>'Negociaciones'
,p_region_name=>'reporte_negociaciones'
,p_parent_plug_id=>wwv_flow_imp.id(320776818448241926)
,p_region_template_options=>'#DEFAULT#'
,p_component_template_options=>'#DEFAULT#'
,p_plug_template=>wwv_flow_imp.id(295629242996037685)
,p_plug_display_sequence=>20
,p_plug_display_point=>'SUB_REGIONS'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'select case when a.USUARIOACTUAL = :APP_USER then',
'         APEX_ITEM.CHECKBOX2(',
'           p_idx => 1,',
'           p_value => a.ID,',
'           p_attributes => ''class="chk-aprobacion" data-id="'' || a.ID || ''"''',
'         )',
'       else',
'         APEX_ITEM.CHECKBOX2(',
'           p_idx => 1,',
'           p_value => a.ID,',
'           p_attributes => ''disabled="disabled" class="chk-aprobacion-disabled"''',
'         )',
'       end AS SELECCION,',
'       a.ID,',
'       ''<div class="compra-card-row" data-id="'' || a.ID || ''">'' ||',
'         ''<div class="compra-card-main">'' ||',
'           ''<div class="compra-card-title">'' || apex_escape.html(nvl(a.DESCRIPCION1, ''NEGOCIACION #'' || a.NUMEROPROCESO)) || ''</div>'' ||',
'           ''<div class="compra-card-subtitle">'' || apex_escape.html(nvl(a.DESCRIPCION2, ''ID Proceso: '' || a.NUMEROPROCESO)) || ''</div>'' ||',
'           ''<div class="compra-card-tags">'' ||',
'             case when a.DESCRIPCION3 is not null then ''<span class="compra-badge badge-categoria">'' || apex_escape.html(a.DESCRIPCION3) || ''</span>'' end ||',
'             case when a.DESCRIPCION4 is not null then ''<span class="compra-badge badge-subcategoria">'' || apex_escape.html(a.DESCRIPCION4) || ''</span>'' end ||',
'             case',
'               when upper(a.DESCRIPCION5) = ''NEGOCIACION'' then ''<span class="compra-badge badge-intencion"><span class="fa fa-handshake-o"></span> Negociaci'' || chr(243) || ''n</span>''',
'               when a.DESCRIPCION5 is not null then ''<span class="compra-badge badge-intencion">'' || apex_escape.html(a.DESCRIPCION5) || ''</span>''',
'             end ||',
'             case when a.USUARIOACTUAL is not null then ''<span class="compra-badge badge-usuario"><span class="fa fa-user"></span> Turno: '' || apex_escape.html(a.USUARIOACTUAL) || ''</span>'' end ||',
'             ''<button type="button" class="btn-flujo-modal" data-id="'' || a.ID || ''" title="Ver Ruta y Comentarios"><span class="fa fa-sitemap"></span> Flujo</button>'' ||',
'           ''</div>'' ||',
'         ''</div>'' ||',
'         ''<div class="compra-card-right">'' ||',
'           ''<div class="compra-card-amount">'' || ''NEG-'' || a.NUMEROPROCESO || ''</div>'' ||',
'           ''<div class="compra-card-antiguedad">'' || trunc(sysdate - cast(a.FECHCREA as date)) || ''d antig'' || chr(252) || ''edad</div>'' ||',
'           ''<div class="compra-status-pill status-pendiente"><span class="status-dot"></span> '' || a.ESTADO || ''</div>'' ||',
'         ''</div>'' ||',
'       ''</div>'' AS CARD_HTML,',
'       a.USERCREA,',
'       a.FECHCREA,',
'       a.USERMODI,',
'       a.FECHMODI,',
'       a.COMPANIA,',
'       a.CODMODULO,',
'       a.TIPOPROCESO,',
'       a.NUMEROPROCESO,',
'       a.DESCRIPCION1,',
'       a.DESCRIPCION2,',
'       a.DESCRIPCION3,',
'       a.DESCRIPCION4,',
'       a.DESCRIPCION5,',
'       a.ESTADO,',
'       a.IDRUTAAPROBACION,',
'       a.IDFLUJOAPROBACION,',
'       a.USUARIOINICIA,',
'       a.USUARIOALTERNO,',
'       a.USUARIOACTUAL,',
'       case when a.USUARIOACTUAL = :APP_USER then 1 else 0 end as PUEDE_GESTIONAR,',
'       a.MONEDA,',
'       a.MONTOTOTAL',
'  from T_CORP_APROBACIONES a',
' where',
'   a.ETIQUETA1 = ''NEGOCIACIONES''',
'   and a.ESTADO = ''EN RUTA''',
'   and ((a.USUARIOACTUAL = :APP_USER AND :P290_ESTADO = 1) or :P290_ESTADO = 2)'))
,p_plug_source_type=>'NATIVE_IR'
,p_ajax_items_to_submit=>'P290_ESTADO'
,p_prn_content_disposition=>'ATTACHMENT'
,p_prn_units=>'MILLIMETERS'
,p_prn_paper_size=>'A4'
,p_prn_width=>297
,p_prn_height=>210
,p_prn_orientation=>'HORIZONTAL'
,p_prn_page_header_font_color=>'#000000'
,p_prn_page_header_font_family=>'Helvetica'
,p_prn_page_header_font_weight=>'normal'
,p_prn_page_header_font_size=>'12'
,p_prn_page_footer_font_color=>'#000000'
,p_prn_page_footer_font_family=>'Helvetica'
,p_prn_page_footer_font_weight=>'normal'
,p_prn_page_footer_font_size=>'12'
,p_prn_header_bg_color=>'#EEEEEE'
,p_prn_header_font_color=>'#000000'
,p_prn_header_font_family=>'Helvetica'
,p_prn_header_font_weight=>'bold'
,p_prn_header_font_size=>'10'
,p_prn_body_bg_color=>'#FFFFFF'
,p_prn_body_font_color=>'#000000'
,p_prn_body_font_family=>'Helvetica'
,p_prn_body_font_weight=>'normal'
,p_prn_body_font_size=>'10'
,p_prn_border_width=>.5
,p_prn_page_header_alignment=>'CENTER'
,p_prn_page_footer_alignment=>'CENTER'
,p_prn_border_color=>'#666666'
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(331139622041670330)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_owner=>'MFERRIN'
,p_internal_uid=>331139622041670330
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331139770655670331)
,p_db_column_name=>'SELECCION'
,p_display_order=>10
,p_column_identifier=>'A'
,p_column_label=>'<input type="checkbox" id="chk-todos-aprobaciones" class="chk-all-aprobaciones" title="Seleccionar todos">'
,p_allow_sorting=>'N'
,p_allow_filtering=>'N'
,p_allow_highlighting=>'N'
,p_allow_ctrl_breaks=>'N'
,p_allow_aggregations=>'N'
,p_allow_computations=>'N'
,p_allow_charting=>'N'
,p_allow_group_by=>'N'
,p_allow_pivot=>'N'
,p_allow_hide=>'N'
,p_column_type=>'STRING'
,p_display_text_as=>'WITHOUT_MODIFICATION'
,p_column_alignment=>'CENTER'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331151899999701605)
,p_db_column_name=>'CARD_HTML'
,p_display_order=>15
,p_column_identifier=>'CRD_NEG'
,p_column_label=>'&nbsp;'
,p_allow_sorting=>'N'
,p_allow_filtering=>'N'
,p_allow_highlighting=>'N'
,p_allow_ctrl_breaks=>'N'
,p_allow_aggregations=>'N'
,p_allow_computations=>'N'
,p_allow_charting=>'N'
,p_allow_group_by=>'N'
,p_allow_pivot=>'N'
,p_allow_hide=>'N'
,p_column_type=>'STRING'
,p_display_text_as=>'WITHOUT_MODIFICATION'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331139855559670332)
,p_db_column_name=>'ID'
,p_display_order=>20
,p_column_identifier=>'B'
,p_column_label=>'Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331139952337670333)
,p_db_column_name=>'USERCREA'
,p_display_order=>30
,p_column_identifier=>'C'
,p_column_label=>'Usercrea'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331140000225670334)
,p_db_column_name=>'FECHCREA'
,p_display_order=>40
,p_column_identifier=>'D'
,p_column_label=>'Fechcrea'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331140188345670335)
,p_db_column_name=>'USERMODI'
,p_display_order=>50
,p_column_identifier=>'E'
,p_column_label=>'Usermodi'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331140287658670336)
,p_db_column_name=>'FECHMODI'
,p_display_order=>60
,p_column_identifier=>'F'
,p_column_label=>'Fechmodi'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331140374447670337)
,p_db_column_name=>'COMPANIA'
,p_display_order=>70
,p_column_identifier=>'G'
,p_column_label=>'Compania'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331140478900670338)
,p_db_column_name=>'CODMODULO'
,p_display_order=>80
,p_column_identifier=>'H'
,p_column_label=>'Codmodulo'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331140533440670339)
,p_db_column_name=>'TIPOPROCESO'
,p_display_order=>90
,p_column_identifier=>'I'
,p_column_label=>'Tipoproceso'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331140665670670340)
,p_db_column_name=>'NUMEROPROCESO'
,p_display_order=>100
,p_column_identifier=>'J'
,p_column_label=>'Numeroproceso'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331140728541670341)
,p_db_column_name=>'DESCRIPCION1'
,p_display_order=>110
,p_column_identifier=>'K'
,p_column_label=>'Descripcion 1'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331140872465670342)
,p_db_column_name=>'DESCRIPCION2'
,p_display_order=>120
,p_column_identifier=>'L'
,p_column_label=>'Descripcion 2'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331140983152670343)
,p_db_column_name=>'DESCRIPCION3'
,p_display_order=>130
,p_column_identifier=>'M'
,p_column_label=>'Descripcion 3'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331141043670670344)
,p_db_column_name=>'DESCRIPCION4'
,p_display_order=>140
,p_column_identifier=>'N'
,p_column_label=>'Descripcion 4'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331141134620670345)
,p_db_column_name=>'DESCRIPCION5'
,p_display_order=>150
,p_column_identifier=>'O'
,p_column_label=>'Descripcion 5'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331141293570670346)
,p_db_column_name=>'ESTADO'
,p_display_order=>160
,p_column_identifier=>'P'
,p_column_label=>'Estado'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331141396832670347)
,p_db_column_name=>'IDRUTAAPROBACION'
,p_display_order=>170
,p_column_identifier=>'Q'
,p_column_label=>'Idrutaaprobacion'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331141455698670348)
,p_db_column_name=>'IDFLUJOAPROBACION'
,p_display_order=>180
,p_column_identifier=>'R'
,p_column_label=>'Idflujoaprobacion'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331141505374670349)
,p_db_column_name=>'USUARIOINICIA'
,p_display_order=>190
,p_column_identifier=>'S'
,p_column_label=>'Usuarioinicia'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331141662349670350)
,p_db_column_name=>'USUARIOALTERNO'
,p_display_order=>200
,p_column_identifier=>'T'
,p_column_label=>'Usuarioalterno'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331151434989701601)
,p_db_column_name=>'USUARIOACTUAL'
,p_display_order=>210
,p_column_identifier=>'U'
,p_column_label=>'Usuarioactual'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331151511449701602)
,p_db_column_name=>'PUEDE_GESTIONAR'
,p_display_order=>220
,p_column_identifier=>'V'
,p_column_label=>'Puede Gestionar'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331151639819701603)
,p_db_column_name=>'MONEDA'
,p_display_order=>230
,p_column_identifier=>'W'
,p_column_label=>'Moneda'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(331151790154701604)
,p_db_column_name=>'MONTOTOTAL'
,p_display_order=>240
,p_column_identifier=>'X'
,p_column_label=>'Montototal'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(331173030997706397)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'3311731'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'SELECCION:CARD_HTML:'
,p_sort_column_1=>'ID'
,p_sort_direction_1=>'DESC'
,p_sort_column_2=>'0'
,p_sort_direction_2=>'ASC'
,p_sort_column_3=>'0'
,p_sort_direction_3=>'ASC'
,p_sort_column_4=>'0'
,p_sort_direction_4=>'ASC'
,p_sort_column_5=>'0'
,p_sort_direction_5=>'ASC'
,p_sort_column_6=>'0'
,p_sort_direction_6=>'ASC'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(332841308848783637)
,p_plug_name=>'Orden de Compra'
,p_region_name=>'reporte_ocs'
,p_parent_plug_id=>wwv_flow_imp.id(320776818448241926)
,p_region_template_options=>'#DEFAULT#'
,p_component_template_options=>'#DEFAULT#'
,p_plug_template=>wwv_flow_imp.id(295629242996037685)
,p_plug_display_sequence=>10
,p_plug_display_point=>'SUB_REGIONS'
,p_query_type=>'SQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'select case when a.USUARIOACTUAL = :APP_USER then',
'         APEX_ITEM.CHECKBOX2(',
'           p_idx => 1,',
'           p_value => LISTAGG(a.ID, '','') WITHIN GROUP (ORDER BY to_number(regexp_substr(a.NUMEROPROCESO, ''^[0-9]+''))),',
'           p_attributes => ''class="chk-aprobacion" data-id="'' || LISTAGG(a.ID, '','') WITHIN GROUP (ORDER BY to_number(regexp_substr(a.NUMEROPROCESO, ''^[0-9]+''))) || ''" data-monto="'' || replace(to_char(sum(nvl(a.MONTOTOTAL, 0))), '','', ''.'') || ''"''',
'         )',
'       else',
'         APEX_ITEM.CHECKBOX2(',
'           p_idx => 1,',
'           p_value => LISTAGG(a.ID, '','') WITHIN GROUP (ORDER BY to_number(regexp_substr(a.NUMEROPROCESO, ''^[0-9]+''))),',
'           p_attributes => ''disabled="disabled" class="chk-aprobacion-disabled"''',
'         )',
'       end AS SELECCION,',
'       LISTAGG(a.ID, '','') WITHIN GROUP (ORDER BY to_number(regexp_substr(a.NUMEROPROCESO, ''^[0-9]+''))) AS ID,',
'       ''<div class="compra-card-row" data-id="'' || LISTAGG(a.ID, '','') WITHIN GROUP (ORDER BY to_number(regexp_substr(a.NUMEROPROCESO, ''^[0-9]+''))) || ''">'' ||',
'         ''<div class="compra-card-main">'' ||',
'           ''<div class="compra-card-title">'' || apex_escape.html(nvl(a.DESCRIPCION1, ''PROVEEDOR'')) || ''</div>'' ||',
'           ''<div class="compra-card-subtitle">'' ||',
'             case when count(distinct a.ID) = 1 then ''1 Orden de Compra: OC #'' || max(a.NUMEROPROCESO)',
'                  else count(distinct a.ID) || '' '' || chr(211) || ''rdenes agrupadas (OCs: '' || LISTAGG(a.NUMEROPROCESO, '', '') WITHIN GROUP (ORDER BY to_number(regexp_substr(a.NUMEROPROCESO, ''^[0-9]+''))) || '')''',
'             end ||',
'           ''</div>'' ||',
'           ''<div class="compra-card-tags">'' ||',
'             ''<span class="compra-badge badge-intencion"><span class="fa fa-shopping-cart"></span> '' || count(distinct a.ID) || '' Solicitud'' || case when count(distinct a.ID) > 1 then ''es'' else '''' end || ''</span>'' ||',
'             case when a.USUARIOACTUAL is not null then ''<span class="compra-badge badge-usuario"><span class="fa fa-user"></span> Turno: '' || apex_escape.html(a.USUARIOACTUAL) || ''</span>'' end ||',
'             ''<span class="compra-badge badge-categoria"><span class="fa fa-cubes"></span> '' ||',
'               (select count(*) from data.t_comp_ordencompraextdet det where det.codagrupacion in (select x.numeroproceso from data.t_corp_aprobaciones x where x.descripcion1 = a.descripcion1 and x.usuarioactual = a.usuarioactual and x.estado = ''EN R'
||'UTA'' and x.codmodulo = ''COMP'' and x.tipoproceso = ''ORDCP'' and x.etiqueta1 = ''ORDENES_COMPRA'')) || '' '' || chr(205) || ''tems</span>'' ||',
'             case when count(distinct a.ID) = 1 then ''<button type="button" class="btn-flujo-modal" data-id="'' || max(a.ID) || ''" title="Ver Ruta y Comentarios"><span class="fa fa-sitemap"></span> Flujo</button>'' end ||',
'           ''</div>'' ||',
'         ''</div>'' ||',
'         ''<div class="compra-card-right">'' ||',
'           ''<div class="compra-card-amount" data-monto="'' || replace(to_char(sum(nvl(a.MONTOTOTAL, 0))), '','', ''.'') || ''">'' || to_char(sum(nvl(a.MONTOTOTAL, 0)), ''FML999,999,990.00'') || ''</div>'' ||',
'           ''<div class="compra-card-antiguedad">'' || trunc(sysdate - cast(min(a.FECHCREA) as date)) || ''d antig'' || chr(252) || ''edad</div>'' ||',
'           ''<div class="compra-status-pill status-pendiente"><span class="status-dot"></span> EN RUTA</div>'' ||',
'         ''</div>'' ||',
'       ''</div>'' AS CARD_HTML,',
'       max(a.USERCREA) as USERCREA,',
'       min(a.FECHCREA) as FECHCREA,',
'       max(a.USERMODI) as USERMODI,',
'       max(a.FECHMODI) as FECHMODI,',
'       max(a.COMPANIA) as COMPANIA,',
'       max(a.CODMODULO) as CODMODULO,',
'       max(a.TIPOPROCESO) as TIPOPROCESO,',
'       LISTAGG(a.NUMEROPROCESO, '', '') WITHIN GROUP (ORDER BY to_number(regexp_substr(a.NUMEROPROCESO, ''^[0-9]+''))) as NUMEROPROCESO,',
'       a.DESCRIPCION1,',
'       max(a.DESCRIPCION2) as DESCRIPCION2,',
'       max(a.DESCRIPCION3) as DESCRIPCION3,',
'       max(a.DESCRIPCION4) as DESCRIPCION4,',
'       max(a.DESCRIPCION5) as DESCRIPCION5,',
'       ''EN RUTA'' as ESTADO,',
'       max(a.IDRUTAAPROBACION) as IDRUTAAPROBACION,',
'       max(a.IDFLUJOAPROBACION) as IDFLUJOAPROBACION,',
'       max(a.USUARIOINICIA) as USUARIOINICIA,',
'       max(a.USUARIOALTERNO) as USUARIOALTERNO,',
'       a.USUARIOACTUAL,',
'       case when a.USUARIOACTUAL = :APP_USER then 1 else 0 end as PUEDE_GESTIONAR,',
'       max(a.MONEDA) as MONEDA,',
'       sum(nvl(a.MONTOTOTAL, 0)) as MONTOTOTAL',
'  from T_CORP_APROBACIONES a',
' where',
'   a.CODMODULO = ''COMP''',
'   and a.TIPOPROCESO = ''ORDCP''',
'   and a.ETIQUETA1 = ''ORDENES_COMPRA''',
'   and a.ESTADO = ''EN RUTA''',
'   and ((a.USUARIOACTUAL = :APP_USER AND :P290_ESTADO = 1) or :P290_ESTADO = 2)',
' group by a.DESCRIPCION1, a.USUARIOACTUAL'))
,p_plug_source_type=>'NATIVE_IR'
,p_ajax_items_to_submit=>'P290_ESTADO'
,p_prn_content_disposition=>'ATTACHMENT'
,p_prn_units=>'MILLIMETERS'
,p_prn_paper_size=>'A4'
,p_prn_width=>297
,p_prn_height=>210
,p_prn_orientation=>'HORIZONTAL'
,p_prn_page_header_font_color=>'#000000'
,p_prn_page_header_font_family=>'Helvetica'
,p_prn_page_header_font_weight=>'normal'
,p_prn_page_header_font_size=>'12'
,p_prn_page_footer_font_color=>'#000000'
,p_prn_page_footer_font_family=>'Helvetica'
,p_prn_page_footer_font_weight=>'normal'
,p_prn_page_footer_font_size=>'12'
,p_prn_header_bg_color=>'#EEEEEE'
,p_prn_header_font_color=>'#000000'
,p_prn_header_font_family=>'Helvetica'
,p_prn_header_font_weight=>'bold'
,p_prn_header_font_size=>'10'
,p_prn_body_bg_color=>'#FFFFFF'
,p_prn_body_font_color=>'#000000'
,p_prn_body_font_family=>'Helvetica'
,p_prn_body_font_weight=>'normal'
,p_prn_body_font_size=>'10'
,p_prn_border_width=>.5
,p_prn_page_header_alignment=>'CENTER'
,p_prn_page_footer_alignment=>'CENTER'
,p_prn_border_color=>'#666666'
);
wwv_flow_imp_page.create_worksheet(
 p_id=>wwv_flow_imp.id(332841434151783638)
,p_max_row_count=>'1000000'
,p_pagination_type=>'ROWS_X_TO_Y'
,p_pagination_display_pos=>'BOTTOM_RIGHT'
,p_report_list_mode=>'TABS'
,p_lazy_loading=>false
,p_show_detail_link=>'N'
,p_show_notify=>'Y'
,p_download_formats=>'CSV:HTML:XLSX:PDF'
,p_enable_mail_download=>'Y'
,p_owner=>'MFERRIN'
,p_internal_uid=>332841434151783638
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(332841599879783639)
,p_db_column_name=>'SELECCION'
,p_display_order=>10
,p_column_identifier=>'A'
,p_column_label=>'<input type="checkbox" id="chk-todos-aprobaciones" class="chk-all-aprobaciones" title="Seleccionar todos">'
,p_allow_sorting=>'N'
,p_allow_filtering=>'N'
,p_allow_highlighting=>'N'
,p_allow_ctrl_breaks=>'N'
,p_allow_aggregations=>'N'
,p_allow_computations=>'N'
,p_allow_charting=>'N'
,p_allow_group_by=>'N'
,p_allow_pivot=>'N'
,p_allow_hide=>'N'
,p_column_type=>'STRING'
,p_display_text_as=>'WITHOUT_MODIFICATION'
,p_column_alignment=>'CENTER'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(332841655474783640)
,p_db_column_name=>'CARD_HTML'
,p_display_order=>20
,p_column_identifier=>'B'
,p_column_label=>'&nbsp;'
,p_allow_sorting=>'N'
,p_allow_filtering=>'N'
,p_allow_highlighting=>'N'
,p_allow_ctrl_breaks=>'N'
,p_allow_aggregations=>'N'
,p_allow_computations=>'N'
,p_allow_charting=>'N'
,p_allow_group_by=>'N'
,p_allow_pivot=>'N'
,p_allow_hide=>'N'
,p_column_type=>'STRING'
,p_display_text_as=>'WITHOUT_MODIFICATION'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(332841798502783641)
,p_db_column_name=>'ID'
,p_display_order=>30
,p_column_identifier=>'C'
,p_column_label=>'Id'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(332841882101783642)
,p_db_column_name=>'USERCREA'
,p_display_order=>40
,p_column_identifier=>'D'
,p_column_label=>'Usercrea'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(332841969117783643)
,p_db_column_name=>'FECHCREA'
,p_display_order=>50
,p_column_identifier=>'E'
,p_column_label=>'Fechcrea'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(332842009198783644)
,p_db_column_name=>'USERMODI'
,p_display_order=>60
,p_column_identifier=>'F'
,p_column_label=>'Usermodi'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(332842161579783645)
,p_db_column_name=>'FECHMODI'
,p_display_order=>70
,p_column_identifier=>'G'
,p_column_label=>'Fechmodi'
,p_column_type=>'DATE'
,p_heading_alignment=>'LEFT'
,p_tz_dependent=>'N'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(332842288725783646)
,p_db_column_name=>'COMPANIA'
,p_display_order=>80
,p_column_identifier=>'H'
,p_column_label=>'Compania'
,p_column_type=>'STRING'
,p_display_text_as=>'LOV_ESCAPE_SC'
,p_heading_alignment=>'LEFT'
,p_rpt_named_lov=>wwv_flow_imp.id(437771641866730384)
,p_rpt_show_filter_lov=>'1'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(332842319747783647)
,p_db_column_name=>'CODMODULO'
,p_display_order=>90
,p_column_identifier=>'I'
,p_column_label=>'Codmodulo'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(332842475538783648)
,p_db_column_name=>'TIPOPROCESO'
,p_display_order=>100
,p_column_identifier=>'J'
,p_column_label=>'Tipoproceso'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(332842557086783649)
,p_db_column_name=>'NUMEROPROCESO'
,p_display_order=>110
,p_column_identifier=>'K'
,p_column_label=>'Numeroproceso'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(332842636924783650)
,p_db_column_name=>'DESCRIPCION1'
,p_display_order=>120
,p_column_identifier=>'L'
,p_column_label=>'Descripcion 1'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(334448363355441601)
,p_db_column_name=>'DESCRIPCION2'
,p_display_order=>130
,p_column_identifier=>'M'
,p_column_label=>'Descripcion 2'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(334448428782441602)
,p_db_column_name=>'DESCRIPCION3'
,p_display_order=>140
,p_column_identifier=>'N'
,p_column_label=>'Descripcion 3'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(334448508168441603)
,p_db_column_name=>'DESCRIPCION4'
,p_display_order=>150
,p_column_identifier=>'O'
,p_column_label=>'Descripcion 4'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(334448670875441604)
,p_db_column_name=>'DESCRIPCION5'
,p_display_order=>160
,p_column_identifier=>'P'
,p_column_label=>'Descripcion 5'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(334448781287441605)
,p_db_column_name=>'ESTADO'
,p_display_order=>170
,p_column_identifier=>'Q'
,p_column_label=>'Estado'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(334448813627441606)
,p_db_column_name=>'IDRUTAAPROBACION'
,p_display_order=>180
,p_column_identifier=>'R'
,p_column_label=>'Idrutaaprobacion'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(334448947091441607)
,p_db_column_name=>'IDFLUJOAPROBACION'
,p_display_order=>190
,p_column_identifier=>'S'
,p_column_label=>'Idflujoaprobacion'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(334449042391441608)
,p_db_column_name=>'USUARIOINICIA'
,p_display_order=>200
,p_column_identifier=>'T'
,p_column_label=>'Usuarioinicia'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(334449171491441609)
,p_db_column_name=>'USUARIOALTERNO'
,p_display_order=>210
,p_column_identifier=>'U'
,p_column_label=>'Usuarioalterno'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(334449200067441610)
,p_db_column_name=>'USUARIOACTUAL'
,p_display_order=>220
,p_column_identifier=>'V'
,p_column_label=>'Usuarioactual'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(334449337621441611)
,p_db_column_name=>'PUEDE_GESTIONAR'
,p_display_order=>230
,p_column_identifier=>'W'
,p_column_label=>'Puede Gestionar'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(334449483852441612)
,p_db_column_name=>'MONEDA'
,p_display_order=>240
,p_column_identifier=>'X'
,p_column_label=>'Moneda'
,p_column_type=>'STRING'
,p_heading_alignment=>'LEFT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_column(
 p_id=>wwv_flow_imp.id(334449557251441613)
,p_db_column_name=>'MONTOTOTAL'
,p_display_order=>250
,p_column_identifier=>'Y'
,p_column_label=>'Montototal'
,p_column_type=>'NUMBER'
,p_heading_alignment=>'RIGHT'
,p_column_alignment=>'RIGHT'
,p_use_as_row_header=>'N'
);
wwv_flow_imp_page.create_worksheet_rpt(
 p_id=>wwv_flow_imp.id(335747132660362121)
,p_application_user=>'APXWS_DEFAULT'
,p_report_seq=>10
,p_report_alias=>'3357472'
,p_status=>'PUBLIC'
,p_is_default=>'Y'
,p_report_columns=>'SELECCION:CARD_HTML:COMPANIA:'
,p_break_on=>'COMPANIA'
,p_break_enabled_on=>'COMPANIA'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(326370942757427045)
,p_plug_name=>'Filtros'
,p_parent_plug_id=>wwv_flow_imp.id(326371495863427050)
,p_region_template_options=>'#DEFAULT#:t-Form--large:t-Form--stretchInputs:t-Form--leftLabels'
,p_plug_template=>wwv_flow_imp.id(296121421643169165)
,p_plug_display_sequence=>10
,p_plug_display_point=>'SUB_REGIONS'
,p_location=>null
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(318093111836815540)
,p_plug_name=>'Botones'
,p_parent_plug_id=>wwv_flow_imp.id(326370942757427045)
,p_region_template_options=>'#DEFAULT#'
,p_plug_template=>wwv_flow_imp.id(295608822663037671)
,p_plug_display_sequence=>20
,p_plug_new_grid_row=>false
,p_location=>null
,p_attributes=>wwv_flow_t_plugin_attributes(wwv_flow_t_varchar2(
  'expand_shortcuts', 'N',
  'output_as', 'HTML')).to_clob
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(332837917744783603)
,p_plug_name=>unistr('Informaci\00F3n de Ruta y Comentarios')
,p_region_name=>'modal_info_ruta'
,p_region_template_options=>'#DEFAULT#:js-dialog-size960x720'
,p_plug_template=>wwv_flow_imp.id(295627185797037684)
,p_plug_display_sequence=>60
,p_plug_display_point=>'REGION_POSITION_04'
,p_location=>null
,p_function_body_language=>'PLSQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    v_html CLOB;',
'    v_id NUMBER;',
'BEGIN',
'    IF :P290_ID_SELECCIONADO IS NOT NULL THEN',
'        IF INSTR(:P290_ID_SELECCIONADO, '','') > 0 THEN',
'            v_id := TO_NUMBER(SUBSTR(:P290_ID_SELECCIONADO, 1, INSTR(:P290_ID_SELECCIONADO, '','') - 1));',
'        ELSE',
'            v_id := TO_NUMBER(:P290_ID_SELECCIONADO);',
'        END IF;',
'        DATA.PK_CORP_APROBACION.sp_html_flujo_aprobacion(v_id, v_html);',
'        RETURN v_html;',
'    ELSE',
'        RETURN ''<div style="padding:24px;text-align:center;color:#64748b;font-size:13px;">Seleccione un registro para visualizar el flujo.</div>'';',
'    END IF;',
'EXCEPTION',
'    WHEN OTHERS THEN',
unistr('        RETURN ''<div style="padding:24px;text-align:center;color:#64748b;font-size:13px;">No se pudo cargar el flujo de aprobaci\00F3n.</div>'';'),
'END;'))
,p_lazy_loading=>false
,p_plug_source_type=>'NATIVE_DYNAMIC_CONTENT'
,p_ajax_items_to_submit=>'P290_ID_SELECCIONADO'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(332837917744783610)
,p_plug_name=>'Historial de Compra'
,p_region_name=>'modal_historico_compra'
,p_region_template_options=>'#DEFAULT#:js-dialog-size960x720'
,p_plug_template=>wwv_flow_imp.id(295627185797037684)
,p_plug_display_sequence=>70
,p_plug_display_point=>'REGION_POSITION_04'
,p_location=>null
,p_function_body_language=>'PLSQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    v_html CLOB;',
'BEGIN',
'    IF :P290_HIST_PRODUCTO IS NOT NULL AND :P290_HIST_PROVEEDOR IS NOT NULL THEN',
'        DATA.PK_COMP_ORDENESCOMPRA_V2.sp_html_historico_compra(',
'            p_compania      => :P290_HIST_COMPANIA,',
'            p_codproducto   => :P290_HIST_PRODUCTO,',
'            p_codproveedor  => :P290_HIST_PROVEEDOR,',
'            p_descproducto  => :P290_HIST_DESCPRODUCTO,',
'            p_descproveedor => :P290_HIST_DESCPROVEEDOR,',
'            o_html          => v_html',
'        );',
'        RETURN v_html;',
'    ELSE',
unistr('        RETURN ''<div style="padding:24px;text-align:center;color:#64748b;font-size:13px;">Seleccione una l\00EDnea para consultar el historial de compra.</div>'';'),
'    END IF;',
'END;'))
,p_lazy_loading=>false
,p_plug_source_type=>'NATIVE_DYNAMIC_CONTENT'
,p_ajax_items_to_submit=>'P290_HIST_COMPANIA,P290_HIST_PRODUCTO,P290_HIST_DESCPRODUCTO,P290_HIST_PROVEEDOR,P290_HIST_DESCPROVEEDOR'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(332837917744783611)
,p_plug_name=>'KPI Historial de Cantidad'
,p_region_name=>'modal_kpi_cantidad'
,p_region_template_options=>'#DEFAULT#:js-dialog-size960x720'
,p_plug_template=>wwv_flow_imp.id(295627185797037684)
,p_plug_display_sequence=>75
,p_plug_display_point=>'REGION_POSITION_04'
,p_location=>null
,p_function_body_language=>'PLSQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    v_html CLOB;',
'BEGIN',
'    IF :P290_HIST_PRODUCTO IS NOT NULL THEN',
'        DATA.PK_COMP_ORDENESCOMPRA_V2.sp_html_kpi_cantidad(',
'            p_compania      => :P290_HIST_COMPANIA,',
'            p_codproducto   => :P290_HIST_PRODUCTO,',
'            p_descproducto  => :P290_HIST_DESCPRODUCTO,',
'            p_codproveedor  => :P290_HIST_PROVEEDOR,',
'            p_descproveedor => :P290_HIST_DESCPROVEEDOR,',
'            p_id_aprobacion => coalesce(:P290_HIST_ID_APROBACION, :P290_ID_SELECCIONADO),',
'            o_html          => v_html',
'        );',
'        RETURN v_html;',
'    ELSE',
unistr('        RETURN ''<div style="padding:24px;text-align:center;color:#64748b;font-size:13px;">Seleccione una l\00EDnea para consultar el historial de cantidad.</div>'';'),
'    END IF;',
'END;'))
,p_lazy_loading=>false
,p_plug_source_type=>'NATIVE_DYNAMIC_CONTENT'
,p_ajax_items_to_submit=>'P290_HIST_COMPANIA,P290_HIST_PRODUCTO,P290_HIST_DESCPRODUCTO,P290_HIST_PROVEEDOR,P290_HIST_DESCPROVEEDOR,P290_HIST_ID_APROBACION,P290_ID_SELECCIONADO'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(332837917744783612)
,p_plug_name=>unistr('KPI Evoluci\00F3n de Precio')
,p_region_name=>'modal_kpi_precio'
,p_region_template_options=>'#DEFAULT#:js-dialog-size960x720'
,p_plug_template=>wwv_flow_imp.id(295627185797037684)
,p_plug_display_sequence=>76
,p_plug_display_point=>'REGION_POSITION_04'
,p_location=>null
,p_function_body_language=>'PLSQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    v_html CLOB;',
'BEGIN',
'    IF :P290_HIST_PRODUCTO IS NOT NULL THEN',
'        DATA.PK_COMP_ORDENESCOMPRA_V2.sp_html_kpi_precio(',
'            p_compania      => :P290_HIST_COMPANIA,',
'            p_codproducto   => :P290_HIST_PRODUCTO,',
'            p_descproducto  => :P290_HIST_DESCPRODUCTO,',
'            p_codproveedor  => :P290_HIST_PROVEEDOR,',
'            p_descproveedor => :P290_HIST_DESCPROVEEDOR,',
'            o_html          => v_html',
'        );',
'        RETURN v_html;',
'    ELSE',
unistr('        RETURN ''<div style="padding:24px;text-align:center;color:#64748b;font-size:13px;">Seleccione una l\00EDnea para consultar la evoluci\00F3n de precio.</div>'';'),
'    END IF;',
'END;'))
,p_lazy_loading=>false
,p_plug_source_type=>'NATIVE_DYNAMIC_CONTENT'
,p_ajax_items_to_submit=>'P290_HIST_COMPANIA,P290_HIST_PRODUCTO,P290_HIST_DESCPRODUCTO,P290_HIST_PROVEEDOR,P290_HIST_DESCPROVEEDOR'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(332837917744783613)
,p_plug_name=>'KPI Stock e Indicadores (Valor)'
,p_region_name=>'modal_kpi_valor'
,p_region_template_options=>'#DEFAULT#:js-dialog-size960x720'
,p_plug_template=>wwv_flow_imp.id(295627185797037684)
,p_plug_display_sequence=>77
,p_plug_display_point=>'REGION_POSITION_04'
,p_location=>null
,p_function_body_language=>'PLSQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    v_html CLOB;',
'BEGIN',
'    IF :P290_HIST_PRODUCTO IS NOT NULL THEN',
'        DATA.PK_COMP_ORDENESCOMPRA_V2.sp_html_kpi_valor(',
'            p_compania      => :P290_HIST_COMPANIA,',
'            p_codproducto   => :P290_HIST_PRODUCTO,',
'            p_descproducto  => :P290_HIST_DESCPRODUCTO,',
'            p_codproveedor  => :P290_HIST_PROVEEDOR,',
'            p_descproveedor => :P290_HIST_DESCPROVEEDOR,',
'            o_html          => v_html',
'        );',
'        RETURN v_html;',
'    ELSE',
unistr('        RETURN ''<div style="padding:24px;text-align:center;color:#64748b;font-size:13px;">Seleccione una l\00EDnea para consultar stock e indicadores.</div>'';'),
'    END IF;',
'END;'))
,p_lazy_loading=>false
,p_plug_source_type=>'NATIVE_DYNAMIC_CONTENT'
,p_ajax_items_to_submit=>'P290_HIST_COMPANIA,P290_HIST_PRODUCTO,P290_HIST_DESCPRODUCTO,P290_HIST_PROVEEDOR,P290_HIST_DESCPROVEEDOR'
);
wwv_flow_imp_page.create_page_plug(
 p_id=>wwv_flow_imp.id(332837917744783614)
,p_plug_name=>unistr('Resumen de Aprobaci\00F3n')
,p_region_name=>'modal_analisis_resumen'
,p_region_template_options=>'#DEFAULT#:js-dialog-size960x720'
,p_plug_template=>wwv_flow_imp.id(295627185797037684)
,p_plug_display_sequence=>78
,p_plug_display_point=>'REGION_POSITION_04'
,p_location=>null
,p_function_body_language=>'PLSQL'
,p_plug_source=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    v_html CLOB;',
'BEGIN',
'    IF :P290_ID_SELECCIONADO IS NOT NULL THEN',
'        DATA.PK_COMP_ORDENESCOMPRA_V2.sp_html_analisis_resumen(',
'            p_compania => :G_COMPANIA,',
'            p_usuario  => :APP_USER,',
'            p_ids      => :P290_ID_SELECCIONADO,',
'            o_html     => v_html',
'        );',
'        RETURN v_html;',
'    ELSE',
unistr('        RETURN ''<div style="padding:24px;text-align:center;color:#64748b;font-size:13px;">Seleccione al menos una orden de compra para ver el an\00E1lisis.</div>'';'),
'    END IF;',
'END;'))
,p_lazy_loading=>false
,p_plug_source_type=>'NATIVE_DYNAMIC_CONTENT'
,p_ajax_items_to_submit=>'P290_ID_SELECCIONADO'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(280271600000000001)
,p_button_sequence=>10
,p_button_plug_id=>wwv_flow_imp.id(318093111836815540)
,p_button_name=>'APROBAR'
,p_button_static_id=>'APROBAR'
,p_button_action=>'DEFINED_BY_DA'
,p_button_template_options=>'#DEFAULT#:t-Button--success:t-Button--stretch'
,p_button_template_id=>wwv_flow_imp.id(295682663716037726)
,p_button_is_hot=>'Y'
,p_button_image_alt=>'Aprobar'
,p_icon_css_classes=>'fa-check'
,p_button_cattributes=>'style="display:none;"'
,p_grid_new_row=>'Y'
,p_grid_column_span=>6
,p_grid_column=>1
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(280271600000000002)
,p_button_sequence=>30
,p_button_plug_id=>wwv_flow_imp.id(318093111836815540)
,p_button_name=>'RECHAZAR'
,p_button_static_id=>'RECHAZAR'
,p_button_action=>'DEFINED_BY_DA'
,p_button_template_options=>'#DEFAULT#:t-Button--danger:t-Button--stretch'
,p_button_template_id=>wwv_flow_imp.id(295682663716037726)
,p_button_image_alt=>'Rechazar'
,p_icon_css_classes=>'fa-times'
,p_button_cattributes=>'style="display:none;"'
,p_grid_new_row=>'N'
,p_grid_column_span=>6
,p_grid_column=>7
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(280271600000000010)
,p_button_sequence=>5
,p_button_plug_id=>wwv_flow_imp.id(318093111836815540)
,p_button_name=>'COMENTARIOS_APROBADOR'
,p_button_static_id=>'COMENTARIOS_APROBADOR'
,p_button_action=>'REDIRECT_PAGE'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>wwv_flow_imp.id(295682663716037726)
,p_button_image_alt=>'Comentarios Aprobador'
,p_button_position=>'NEXT'
,p_button_redirect_url=>'f?p=&APP_ID.:286:&SESSION.::&DEBUG.:286:P286_LINEAS,P286_USUARIO:&P290_LINEAS_RECHAZAR.,&APP_USER.'
,p_button_cattributes=>'style="display:none;"'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(280271600000000021)
,p_button_sequence=>20
,p_button_plug_id=>wwv_flow_imp.id(318093111836815540)
,p_button_name=>'MODAL_APROBAR_107'
,p_button_static_id=>'MODAL_APROBAR_107'
,p_button_action=>'REDIRECT_APP'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>wwv_flow_imp.id(295682663716037726)
,p_button_image_alt=>'Modal Aprobar 107'
,p_button_position=>'NEXT'
,p_button_redirect_url=>'f?p=100:107:&SESSION.::&DEBUG.:107:G_VALOR1:0'
,p_button_cattributes=>'style="display:none;"'
);
wwv_flow_imp_page.create_page_button(
 p_id=>wwv_flow_imp.id(280271600000000022)
,p_button_sequence=>40
,p_button_plug_id=>wwv_flow_imp.id(318093111836815540)
,p_button_name=>'MODAL_RECHAZAR_107'
,p_button_static_id=>'MODAL_RECHAZAR_107'
,p_button_action=>'REDIRECT_APP'
,p_button_template_options=>'#DEFAULT#'
,p_button_template_id=>wwv_flow_imp.id(295682663716037726)
,p_button_image_alt=>'Modal Rechazar 107'
,p_button_position=>'NEXT'
,p_button_redirect_url=>'f?p=100:107:&SESSION.::&DEBUG.:107:G_VALOR1:1'
,p_button_cattributes=>'style="display:none;"'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(280271474096322024)
,p_name=>'P290_ID_SELECCIONADO'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(318093000447815539)
,p_prompt=>'Id Seleccionado'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>30
,p_field_template=>wwv_flow_imp.id(295681930575037725)
,p_item_template_options=>'#DEFAULT#'
,p_attribute_01=>'N'
,p_attribute_02=>'N'
,p_attribute_04=>'TEXT'
,p_attribute_05=>'BOTH'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(318093500447815544)
,p_name=>'P290_COMENTARIO'
,p_item_sequence=>20
,p_item_plug_id=>wwv_flow_imp.id(318093000447815539)
,p_prompt=>'Comentario'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>2000
,p_field_template=>wwv_flow_imp.id(295681930575037725)
,p_item_template_options=>'#DEFAULT#'
,p_attribute_01=>'N'
,p_attribute_02=>'N'
,p_attribute_04=>'TEXT'
,p_attribute_05=>'BOTH'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(318093500447815551)
,p_name=>'P290_HIST_COMPANIA'
,p_item_sequence=>30
,p_item_plug_id=>wwv_flow_imp.id(318093000447815539)
,p_prompt=>'Hist Cia'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>30
,p_field_template=>wwv_flow_imp.id(295681930575037725)
,p_item_template_options=>'#DEFAULT#'
,p_attribute_01=>'N'
,p_attribute_02=>'N'
,p_attribute_04=>'TEXT'
,p_attribute_05=>'BOTH'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(318093500447815552)
,p_name=>'P290_HIST_PRODUCTO'
,p_item_sequence=>40
,p_item_plug_id=>wwv_flow_imp.id(318093000447815539)
,p_prompt=>'Hist Producto'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>50
,p_field_template=>wwv_flow_imp.id(295681930575037725)
,p_item_template_options=>'#DEFAULT#'
,p_attribute_01=>'N'
,p_attribute_02=>'N'
,p_attribute_04=>'TEXT'
,p_attribute_05=>'BOTH'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(318093500447815553)
,p_name=>'P290_HIST_DESCPRODUCTO'
,p_item_sequence=>50
,p_item_plug_id=>wwv_flow_imp.id(318093000447815539)
,p_prompt=>'Hist Desc Producto'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>250
,p_field_template=>wwv_flow_imp.id(295681930575037725)
,p_item_template_options=>'#DEFAULT#'
,p_attribute_01=>'N'
,p_attribute_02=>'N'
,p_attribute_04=>'TEXT'
,p_attribute_05=>'BOTH'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(318093500447815554)
,p_name=>'P290_HIST_PROVEEDOR'
,p_item_sequence=>60
,p_item_plug_id=>wwv_flow_imp.id(318093000447815539)
,p_prompt=>'Hist Proveedor'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>50
,p_field_template=>wwv_flow_imp.id(295681930575037725)
,p_item_template_options=>'#DEFAULT#'
,p_attribute_01=>'N'
,p_attribute_02=>'N'
,p_attribute_04=>'TEXT'
,p_attribute_05=>'BOTH'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(318093500447815555)
,p_name=>'P290_HIST_DESCPROVEEDOR'
,p_item_sequence=>70
,p_item_plug_id=>wwv_flow_imp.id(318093000447815539)
,p_prompt=>'Hist Desc Proveedor'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>250
,p_field_template=>wwv_flow_imp.id(295681930575037725)
,p_item_template_options=>'#DEFAULT#'
,p_attribute_01=>'N'
,p_attribute_02=>'N'
,p_attribute_04=>'TEXT'
,p_attribute_05=>'BOTH'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(318093500447815556)
,p_name=>'P290_HIST_ID_APROBACION'
,p_item_sequence=>80
,p_item_plug_id=>wwv_flow_imp.id(318093000447815539)
,p_prompt=>'Hist Id Aprobacion'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>30
,p_field_template=>wwv_flow_imp.id(295681930575037725)
,p_item_template_options=>'#DEFAULT#'
,p_attribute_01=>'N'
,p_attribute_02=>'N'
,p_attribute_04=>'TEXT'
,p_attribute_05=>'BOTH'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(318093500447815557)
,p_name=>'P290_LINEAS_RECHAZAR'
,p_item_sequence=>90
,p_item_plug_id=>wwv_flow_imp.id(318093000447815539)
,p_prompt=>'Lineas Rechazar'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>4000
,p_field_template=>wwv_flow_imp.id(295681930575037725)
,p_item_template_options=>'#DEFAULT#'
,p_attribute_01=>'N'
,p_attribute_02=>'N'
,p_attribute_04=>'TEXT'
,p_attribute_05=>'BOTH'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(318093500447815558)
,p_name=>'P290_ACCION'
,p_item_sequence=>100
,p_item_plug_id=>wwv_flow_imp.id(318093000447815539)
,p_prompt=>'Accion'
,p_display_as=>'NATIVE_TEXT_FIELD'
,p_cSize=>30
,p_field_template=>wwv_flow_imp.id(295681930575037725)
,p_item_template_options=>'#DEFAULT#'
,p_attribute_01=>'N'
,p_attribute_02=>'N'
,p_attribute_04=>'TEXT'
,p_attribute_05=>'BOTH'
);
wwv_flow_imp_page.create_page_item(
 p_id=>wwv_flow_imp.id(326371092615427046)
,p_name=>'P290_ESTADO'
,p_item_sequence=>10
,p_item_plug_id=>wwv_flow_imp.id(326370942757427045)
,p_item_default=>'1'
,p_prompt=>'Estado'
,p_display_as=>'NATIVE_SELECT_LIST'
,p_named_lov=>'LOV_UDC_ESTADOMESA'
,p_lov=>'SELECT DESCRIPCION, ID_TABLA FROM T_CORP_UDC WHERE id_cabecera=''ESTADOMESA'' ORDER BY id_tabla;'
,p_cHeight=>1
,p_colspan=>6
,p_field_template=>wwv_flow_imp.id(295681930575037725)
,p_item_template_options=>'#DEFAULT#'
,p_lov_display_extra=>'NO'
,p_attribute_01=>'NONE'
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(280271094629322020)
,p_name=>'SeleccionFila'
,p_event_sequence=>10
,p_triggering_element_type=>'JQUERY_SELECTOR'
,p_triggering_element=>'#reporte_prod_alt .a-IRR-table tbody tr td, #reporte_rutas .a-IRR-table tbody tr td, #reporte_proveedores .a-IRR-table tbody tr td, #reporte_negociaciones .a-IRR-table tbody tr td'
,p_bind_type=>'live'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'click'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(280271173654322021)
,p_event_id=>wwv_flow_imp.id(280271094629322020)
,p_event_result=>'TRUE'
,p_action_sequence=>20
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attribute_01=>wwv_flow_string.join(wwv_flow_t_varchar2(
'// 1. Si el clic fue en un checkbox, su celda contenedora o un boton modal, no ejecutar seleccion individual',
'if (this.browserEvent && (',
'    $(this.browserEvent.target).is(''input, button, a'') || ',
'    $(this.browserEvent.target).closest(''.btn-flujo-modal, .btn-historial-modal, .chk-aprobacion, .chk-all-aprobaciones, td:has(input[type="checkbox"])'').length > 0',
')) {',
'    return;',
'}',
'',
'// 2. Si hay checkboxes seleccionados en OCs (o mas de 1 en general), no sobreescribir la seleccion',
'var $container = $(this.triggeringElement).closest(''#reporte_prod_alt, #reporte_rutas, #reporte_proveedores, #reporte_negociaciones, #reporte_ocs, .a-IRR-region, .a-IRR-tableContainer, .t-Region'');',
'var isOCs = ($container.attr(''id'') === ''reporte_ocs'' || $container.closest(''#reporte_ocs'').length > 0);',
'var cantSeleccionadas = $container.find(''.chk-aprobacion:checked:not(:disabled)'').length;',
'if ((isOCs && cantSeleccionadas > 0) || cantSeleccionadas > 1) {',
'    return;',
'}',
'',
'// 3. Obtener la fila actual donde se hizo clic',
'var $row = $(this.triggeringElement).closest(''tr'');',
'',
'// 4. Marcar visualmente la fila seleccionada',
'$(''.a-IRR-table tr'').removeClass(''fila-seleccionada'');',
'$row.addClass(''fila-seleccionada'');',
'',
'// 5. Obtener el ID del registro de forma infalible',
'var ID_registro = $row.find(''input[type="checkbox"]'').val()',
'               || $row.find(''td[headers*="324449584566451205"], td[headers*="ID"]'').text().trim()',
'               || $row.find(''td'').eq(1).text().trim();',
'',
'if (ID_registro) {',
'    // Guarda el ID en el item oculto',
'    apex.item("P290_ID_SELECCIONADO").setValue(ID_registro);',
'',
'    // 6. Mostrar botones Aprobar/Rechazar solo si puede gestionar',
'    var puedeGestionar = $row.find(''input[type="checkbox"]:not(:disabled)'').length > 0;',
'    if (puedeGestionar) {',
'        $(''#APROBAR, #RECHAZAR'').show();',
'    } else {',
'        $(''#APROBAR, #RECHAZAR'').hide();',
'    }',
'}'))
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(280271542666322025)
,p_event_id=>wwv_flow_imp.id(280271094629322020)
,p_event_result=>'TRUE'
,p_action_sequence=>40
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_REFRESH'
,p_affected_elements_type=>'REGION'
,p_affected_region_id=>wwv_flow_imp.id(280271272655322022)
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(284867083152719494)
,p_name=>'Ocultar Barra'
,p_event_sequence=>20
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'ready'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(284867455906719495)
,p_event_id=>wwv_flow_imp.id(284867083152719494)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attribute_01=>wwv_flow_string.join(wwv_flow_t_varchar2(
'$(".t-Button.t-Button--icon.t-Button--header.t-Button--headerTree.is-active").click();',
'$(''#APROBAR, #RECHAZAR'').hide();'))
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(280271700000000003)
,p_name=>'APROBAR_APROBACION'
,p_event_sequence=>30
,p_triggering_element_type=>'BUTTON'
,p_triggering_button_id=>wwv_flow_imp.id(280271600000000021)
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'apexafterclosedialog'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(280271700000000004)
,p_event_id=>wwv_flow_imp.id(280271700000000003)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attribute_01=>wwv_flow_string.join(wwv_flow_t_varchar2(
'if (this.data) {',
'    var comentario = this.data.G_COMENTARIO || "";',
'    apex.item("P290_COMENTARIO").setValue(comentario);',
'    apex.page.submit({',
'        request: "APROBAR",',
'        showWait: true',
'    });',
'}'))
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(280271700000000005)
,p_name=>'RECHAZAR_APROBACION'
,p_event_sequence=>40
,p_triggering_element_type=>'BUTTON'
,p_triggering_button_id=>wwv_flow_imp.id(280271600000000022)
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'apexafterclosedialog'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(280271700000000006)
,p_event_id=>wwv_flow_imp.id(280271700000000005)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attribute_01=>wwv_flow_string.join(wwv_flow_t_varchar2(
'if (this.data) {',
'    var comentario = this.data.G_COMENTARIO || "";',
'    apex.item("P290_COMENTARIO").setValue(comentario);',
'    apex.page.submit({',
'        request: "RECHAZAR",',
'        showWait: true',
'    });',
'}'))
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(280271700000000011)
,p_name=>'Dialog Closed: Comentarios Aprobador'
,p_event_sequence=>45
,p_triggering_element_type=>'BUTTON'
,p_triggering_button_id=>wwv_flow_imp.id(280271600000000010)
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'apexafterclosedialog'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(280271700000000012)
,p_event_id=>wwv_flow_imp.id(280271700000000011)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_name=>'Actualizar estado Rechazo'
,p_action=>'NATIVE_EXECUTE_PLSQL_CODE'
,p_attribute_01=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    v_num_ord    NUMBER;',
'    v_tip_ord    VARCHAR2(200);',
'    v_msg_cancel VARCHAR2(4000);',
'BEGIN',
'    IF :P290_ACCION IN (''APRUEBA_PARCIAL'', ''RECHAZO_PARCIAL'') AND :P290_LINEAS_RECHAZAR IS NOT NULL THEN',
'        FOR r IN (',
'            SELECT numeroproceso',
'              FROM data.t_corp_aprobaciones',
'             WHERE id IN (',
'                 SELECT TO_NUMBER(TRIM(column_value))',
'                   FROM TABLE(apex_string.split(:P290_ID_SELECCIONADO, '',''))',
'                  WHERE TRIM(column_value) IS NOT NULL',
'                    AND REGEXP_LIKE(TRIM(column_value), ''^[0-9]+$'')',
'             )',
'        ) LOOP',
'            DATA.PK_COMP_ORDENESCOMPRA_V2.SP_CANCELAROCLINEA(',
'                P_NUMERO      => TO_NUMBER(r.numeroproceso),',
'                P_TIPO        => ''ORDCP'',',
'                P_COMPANIA    => NVL(:G_COMPANIA, ''00001''),',
'                P_LINEAS      => :P290_LINEAS_RECHAZAR,',
'                P_NUMEROORDEN => v_num_ord,',
'                P_TIPOORDEN   => v_tip_ord,',
'                P_MENSAJE     => v_msg_cancel',
'            );',
'        END LOOP;',
'    END IF;',
'END;'))
,p_attribute_02=>'P290_ACCION,P290_LINEAS_RECHAZAR,P290_ID_SELECCIONADO,G_COMPANIA'
,p_attribute_05=>'PLSQL'
,p_wait_for_result=>'Y'
,p_client_condition_type=>'IN_LIST'
,p_client_condition_element=>'P290_ACCION'
,p_client_condition_expression=>'APRUEBA_PARCIAL,RECHAZO_PARCIAL'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(280271700000000013)
,p_event_id=>wwv_flow_imp.id(280271700000000011)
,p_event_result=>'TRUE'
,p_action_sequence=>20
,p_execute_on_page_init=>'N'
,p_name=>'Refrescar Detalle'
,p_action=>'NATIVE_REFRESH'
,p_affected_elements_type=>'REGION'
,p_affected_region_id=>wwv_flow_imp.id(280271272655322022)
,p_client_condition_type=>'IN_LIST'
,p_client_condition_element=>'P290_ACCION'
,p_client_condition_expression=>'APRUEBA_PARCIAL,RECHAZO_PARCIAL'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(280271700000000014)
,p_event_id=>wwv_flow_imp.id(280271700000000011)
,p_event_result=>'TRUE'
,p_action_sequence=>30
,p_execute_on_page_init=>'N'
,p_name=>'Abrir Dialogo Aprobar'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attribute_01=>wwv_flow_string.join(wwv_flow_t_varchar2(
'var $btn = $(''#MODAL_APROBAR_107'');',
'if ($btn.length) {',
'    $btn[0].click();',
'}'))
,p_client_condition_type=>'IN_LIST'
,p_client_condition_element=>'P290_ACCION'
,p_client_condition_expression=>'APRUEBA_PARCIAL'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(280271700000000015)
,p_event_id=>wwv_flow_imp.id(280271700000000011)
,p_event_result=>'TRUE'
,p_action_sequence=>40
,p_execute_on_page_init=>'N'
,p_name=>'Limpiar Estado Rechazo Parcial'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attribute_01=>wwv_flow_string.join(wwv_flow_t_varchar2(
'apex.item("P290_LINEAS_RECHAZAR").setValue("");',
'apex.item("P290_ACCION").setValue("");'))
,p_client_condition_type=>'IN_LIST'
,p_client_condition_element=>'P290_ACCION'
,p_client_condition_expression=>'RECHAZO_PARCIAL'
);
wwv_flow_imp_page.create_page_da_event(
 p_id=>wwv_flow_imp.id(326371128219427047)
,p_name=>'EstadoFiltro'
,p_event_sequence=>50
,p_triggering_element_type=>'ITEM'
,p_triggering_element=>'P290_ESTADO'
,p_bind_type=>'bind'
,p_execution_type=>'IMMEDIATE'
,p_bind_event_type=>'change'
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(326371204142427048)
,p_event_id=>wwv_flow_imp.id(326371128219427047)
,p_event_result=>'TRUE'
,p_action_sequence=>10
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_REFRESH'
,p_affected_elements_type=>'REGION'
,p_affected_region_id=>wwv_flow_imp.id(324449336739451203)
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(334449600553441614)
,p_event_id=>wwv_flow_imp.id(326371128219427047)
,p_event_result=>'TRUE'
,p_action_sequence=>20
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_REFRESH'
,p_affected_elements_type=>'REGION'
,p_affected_region_id=>wwv_flow_imp.id(320776936700241927)
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(334449759753441615)
,p_event_id=>wwv_flow_imp.id(326371128219427047)
,p_event_result=>'TRUE'
,p_action_sequence=>30
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_REFRESH'
,p_affected_elements_type=>'REGION'
,p_affected_region_id=>wwv_flow_imp.id(331136982864670303)
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(334449892856441616)
,p_event_id=>wwv_flow_imp.id(326371128219427047)
,p_event_result=>'TRUE'
,p_action_sequence=>40
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_REFRESH'
,p_affected_elements_type=>'REGION'
,p_affected_region_id=>wwv_flow_imp.id(331139517401670329)
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(334449942955441617)
,p_event_id=>wwv_flow_imp.id(326371128219427047)
,p_event_result=>'TRUE'
,p_action_sequence=>50
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_REFRESH'
,p_affected_elements_type=>'REGION'
,p_affected_region_id=>wwv_flow_imp.id(332841308848783637)
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(326371300000427049)
,p_event_id=>wwv_flow_imp.id(326371128219427047)
,p_event_result=>'TRUE'
,p_action_sequence=>60
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_JAVASCRIPT_CODE'
,p_attribute_01=>wwv_flow_string.join(wwv_flow_t_varchar2(
'apex.item("P290_ID_SELECCIONADO").setValue("");',
'$("#APROBAR, #RECHAZAR").hide();',
'$(".a-IRR-table tr").removeClass("fila-seleccionada");'))
);
wwv_flow_imp_page.create_page_da_action(
 p_id=>wwv_flow_imp.id(326371400000427050)
,p_event_id=>wwv_flow_imp.id(326371128219427047)
,p_event_result=>'TRUE'
,p_action_sequence=>70
,p_execute_on_page_init=>'N'
,p_action=>'NATIVE_REFRESH'
,p_affected_elements_type=>'REGION'
,p_affected_region_id=>wwv_flow_imp.id(280271272655322022)
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(280271800000000007)
,p_process_sequence=>10
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Aprobar'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    v_respuesta      varchar2(4000);',
'    v_estado_exito   number;',
'    v_errores        varchar2(4000);',
'    v_codagrupacion  varchar2(50);',
'    v_codmodulo      varchar2(10);',
'    v_tipoproceso    varchar2(10);',
'    v_etiqueta1      varchar2(50);',
'    v_lineas_oc      varchar2(4000);',
'    v_num_oc         number;',
'    v_tipo_oc        varchar2(10);',
'    v_resp_cancel    varchar2(4000);',
'    v_cant_activas   number;',
'BEGIN',
'    FOR r IN (',
'        SELECT TO_NUMBER(TRIM(column_value)) AS id_aprob',
'        FROM TABLE(apex_string.split(:P290_ID_SELECCIONADO, '',''))',
'        WHERE TRIM(column_value) IS NOT NULL',
'          AND REGEXP_LIKE(TRIM(column_value), ''^[0-9]+$'')',
'    ) LOOP',
'        BEGIN',
'            SELECT numeroproceso, codmodulo, tipoproceso, etiqueta1',
'              INTO v_codagrupacion, v_codmodulo, v_tipoproceso, v_etiqueta1',
'              FROM data.t_corp_aprobaciones',
'             WHERE id = r.id_aprob;',
'        EXCEPTION',
'            WHEN NO_DATA_FOUND THEN',
'                v_codagrupacion := NULL;',
'                v_codmodulo     := NULL;',
'                v_tipoproceso   := NULL;',
'                v_etiqueta1     := NULL;',
'        END;',
'',
'        IF v_codmodulo = ''COMP'' AND v_tipoproceso = ''ORDCP'' THEN',
unistr('            -- 1. Cancelar l\00EDneas desmarcadas para esta agrupaci\00F3n'),
'            IF :P290_LINEAS_RECHAZAR IS NOT NULL AND v_codagrupacion IS NOT NULL THEN',
'                SELECT LISTAGG(d.id, '','') WITHIN GROUP (ORDER BY d.id)',
'                  INTO v_lineas_oc',
'                  FROM data.t_comp_ordencompraextdet d',
'                 WHERE d.codagrupacion = v_codagrupacion',
'                   AND d.estado = ''EN RUTA''',
'                   AND d.id IN (',
'                       SELECT TO_NUMBER(TRIM(column_value))',
'                         FROM TABLE(apex_string.split(:P290_LINEAS_RECHAZAR, '',''))',
'                        WHERE TRIM(column_value) IS NOT NULL',
'                          AND REGEXP_LIKE(TRIM(column_value), ''^[0-9]+$'')',
'                   );',
'',
'                IF v_lineas_oc IS NOT NULL THEN',
'                    data.pk_comp_ordenescompra_v2.sp_cancelaroclinea(',
'                        p_numero      => TO_NUMBER(REGEXP_SUBSTR(v_codagrupacion, ''^[0-9]+'')),',
'                        p_tipo        => ''ORDEN_COMPRA'',',
'                        p_compania    => NVL(:G_COMPANIA, ''00001''),',
'                        p_lineas      => v_lineas_oc,',
'                        p_numeroorden => v_num_oc,',
'                        p_tipoorden   => v_tipo_oc,',
'                        p_mensaje     => v_resp_cancel',
'                    );',
'                END IF;',
'            END IF;',
'',
unistr('            -- 2. Evaluar l\00EDneas restantes en EN RUTA'),
'            SELECT COUNT(*)',
'              INTO v_cant_activas',
'              FROM data.t_comp_ordencompraextdet d',
'             WHERE d.codagrupacion = v_codagrupacion',
'               AND d.estado = ''EN RUTA'';',
'',
unistr('            -- 3. Enrutamiento din\00E1mico'),
'            IF v_cant_activas > 0 THEN',
'                data.pk_corp_aprobacion.sp_aprobar_mesa(',
'                    p_compania      => :G_COMPANIA,',
'                    p_usuario       => :APP_USER,',
'                    p_id_aprobacion => r.id_aprob,',
'                    p_comentario    => :P290_COMENTARIO,',
'                    o_respuesta     => v_respuesta,',
'                    o_estado_exito  => v_estado_exito',
'                );',
'            ELSE',
'                data.pk_corp_aprobacion.sp_rechazar_mesa(',
'                    p_compania      => :G_COMPANIA,',
'                    p_usuario       => :APP_USER,',
'                    p_id_aprobacion => r.id_aprob,',
unistr('                    p_comentario    => NVL(:P290_COMENTARIO, ''Rechazo total por deselecci\00F3n de todas las l\00EDneas en Mesa de Trabajo''),'),
'                    o_respuesta     => v_respuesta,',
'                    o_estado_exito  => v_estado_exito',
'                );',
'            END IF;',
'        ELSE',
'            -- Otros tipos de aprobaciones que no son ODCs',
'            data.pk_corp_aprobacion.sp_aprobar_mesa(',
'                p_compania      => :G_COMPANIA,',
'                p_usuario       => :APP_USER,',
'                p_id_aprobacion => r.id_aprob,',
'                p_comentario    => :P290_COMENTARIO,',
'                o_respuesta     => v_respuesta,',
'                o_estado_exito  => v_estado_exito',
'            );',
'        END IF;',
'',
'        IF NVL(v_estado_exito, 0) = 0 THEN',
'            v_errores := v_errores || v_respuesta || ''; '';',
'        END IF;',
'    END LOOP;',
'',
'    IF v_errores IS NOT NULL THEN',
'        apex_error.add_error(',
'            p_message          => v_errores,',
'            p_display_location => apex_error.c_inline_in_notification',
'        );',
'    ELSE',
'        :P290_ID_SELECCIONADO := NULL;',
'        :P290_COMENTARIO      := NULL;',
'    END IF;',
'    :P290_LINEAS_RECHAZAR := NULL;',
'    :P290_ACCION := NULL;',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when=>':REQUEST = ''APROBAR'' AND NOT APEX_ERROR.HAVE_ERRORS_OCCURRED'
,p_process_when_type=>'EXPRESSION'
,p_process_when2=>'PLSQL'
,p_process_success_message=>'Registro aprobado exitosamente.'
,p_internal_uid=>280271800000000007
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(280271800000000008)
,p_process_sequence=>20
,p_process_point=>'AFTER_SUBMIT'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Rechazar'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    v_respuesta varchar2(4000);',
'    v_estado_exito number;',
'    v_errores varchar2(4000);',
'BEGIN',
'    FOR r IN (',
'        SELECT TO_NUMBER(column_value) AS id_aprob',
'        FROM TABLE(apex_string.split(:P290_ID_SELECCIONADO, '',''))',
'        WHERE TRIM(column_value) IS NOT NULL',
'    ) LOOP',
'        data.pk_corp_aprobacion.sp_rechazar_mesa(',
'            p_compania      => :G_COMPANIA,',
'            p_usuario       => :APP_USER,',
'            p_id_aprobacion => r.id_aprob,',
'            p_comentario    => :P290_COMENTARIO,',
'            o_respuesta     => v_respuesta,',
'            o_estado_exito  => v_estado_exito',
'        );',
'        IF NVL(v_estado_exito, 0) = 0 THEN',
'            v_errores := v_errores || v_respuesta || ''; '';',
'        END IF;',
'    END LOOP;',
'',
'    IF v_errores IS NOT NULL THEN',
'        apex_error.add_error(',
'            p_message          => v_errores,',
'            p_display_location => apex_error.c_inline_in_notification',
'        );',
'    ELSE',
'        :P290_ID_SELECCIONADO := NULL;',
'        :P290_COMENTARIO := NULL;',
'    END IF;',
'    :P290_LINEAS_RECHAZAR := NULL;',
'    :P290_ACCION := NULL;',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_error_display_location=>'INLINE_IN_NOTIFICATION'
,p_process_when=>':REQUEST = ''RECHAZAR'' AND NOT APEX_ERROR.HAVE_ERRORS_OCCURRED'
,p_process_when_type=>'EXPRESSION'
,p_process_when2=>'PLSQL'
,p_process_success_message=>'Registro rechazado.'
,p_internal_uid=>280271800000000008
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(331151983471701606)
,p_process_sequence=>10
,p_process_point=>'BEFORE_HEADER'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'Limpia'
,p_process_sql_clob=>':P290_ID_SELECCIONADO := null;'
,p_process_clob_language=>'PLSQL'
,p_internal_uid=>331151983471701606
);
wwv_flow_imp_page.create_page_process(
 p_id=>wwv_flow_imp.id(280271800000000020)
,p_process_sequence=>30
,p_process_point=>'ON_DEMAND'
,p_process_type=>'NATIVE_PLSQL'
,p_process_name=>'GET_DIALOG_URL_286'
,p_process_sql_clob=>wwv_flow_string.join(wwv_flow_t_varchar2(
'DECLARE',
'    v_url VARCHAR2(4000);',
'BEGIN',
'    v_url := APEX_PAGE.GET_URL(',
'        p_page               => 286,',
'        p_items              => ''P286_LINEAS,P286_USUARIO'',',
'        p_values             => ''\'' || :P290_LINEAS_RECHAZAR || ''\,'' || :APP_USER,',
'        p_triggering_element => ''$("#COMENTARIOS_APROBADOR")''',
'    );',
'    sys.htp.p(v_url);',
'END;'))
,p_process_clob_language=>'PLSQL'
,p_internal_uid=>280271800000000020
);
end;
/
prompt --application/end_environment
begin
wwv_flow_imp.import_end(p_auto_install_sup_obj => nvl(wwv_flow_application_install.get_auto_install_sup_obj, false)
);
commit;
end;
/
set verify on feedback on define on
prompt  ...done

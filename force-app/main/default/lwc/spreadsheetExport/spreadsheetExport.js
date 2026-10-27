// Shared, presentation-free helpers for building and downloading an Excel-openable file from an
// LWC. JS-only module (no template) - imported via `import ... from 'c/spreadsheetExport'` by any
// component that needs to export a grid, rather than each one duplicating this logic.
//
// Produces SpreadsheetML (the Excel 2003 XML workbook format): a single flat XML document, not a
// true zip-based .xlsx - generating a real .xlsx client-side would need a third-party ZIP-writing
// library bundled as a new Static Resource, more risk than a "download this grid" button is worth.
// SpreadsheetML opens directly in Excel as real cells/columns (not a text import); Excel may show a
// one-time "format and extension don't match" warning depending on version, which is expected and
// harmless - continuing opens the file normally.

function escapeXml(value) {
    const text = value === null || value === undefined ? '' : String(value);
    return text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&apos;');
}

function worksheetXml(sheetName, headers, rows) {
    const cellXml = (value) => '<Cell><Data ss:Type="String">' + escapeXml(value) + '</Data></Cell>';
    const rowXml = (cells) => '<Row>' + cells.map(cellXml).join('') + '</Row>';

    const headerRow =
        '<Row>' +
        headers.map((h) => '<Cell ss:StyleID="Header"><Data ss:Type="String">' + escapeXml(h) + '</Data></Cell>').join('') +
        '</Row>';
    const dataRows = rows.map((cells) => rowXml(cells)).join('');
    const safeSheetName = (sheetName || 'Sheet1').replace(/[\\/?*[\]:]/g, ' ').substring(0, 31);

    return '<Worksheet ss:Name="' + escapeXml(safeSheetName) + '"><Table>' + headerRow + dataRows + '</Table></Worksheet>';
}

/**
 * @param {string} sheetName - worksheet tab name (Excel truncates/rejects over 31 chars or
 *        certain characters, so this sanitizes and truncates for you).
 * @param {string[]} headers - column headers, rendered bold with a light shaded background.
 * @param {Array<Array<string|number>>} rows - one array of cell values per row, same order as headers.
 * @returns {string} a complete SpreadsheetML XML document with a single worksheet.
 */
export function buildSpreadsheetXml(sheetName, headers, rows) {
    return buildWorkbookXml([{ name: sheetName, headers, rows }]);
}

/**
 * Same as buildSpreadsheetXml, but for a workbook with multiple tabs - e.g. a "Summary" sheet
 * (the aggregate grid) plus a "Details" sheet (every underlying record), so a "download the whole
 * report" button can hand over both the numbers and the records behind them as separate tabs in
 * one file.
 * @param {Array<{name: string, headers: string[], rows: Array<Array<string|number>>}>} sheets
 * @returns {string} a complete SpreadsheetML XML document.
 */
export function buildWorkbookXml(sheets) {
    const worksheets = sheets.map((s) => worksheetXml(s.name, s.headers, s.rows)).join('');
    return (
        '<?xml version="1.0"?>' +
        '<?mso-application progid="Excel.Sheet"?>' +
        '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" ' +
        'xmlns:o="urn:schemas-microsoft-com:office:office" ' +
        'xmlns:x="urn:schemas-microsoft-com:office:excel" ' +
        'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">' +
        '<Styles><Style ss:ID="Header"><Font ss:Bold="1"/><Interior ss:Color="#EAF4FD" ss:Pattern="Solid"/></Style></Styles>' +
        worksheets +
        '</Workbook>'
    );
}

/** Turns arbitrary text into a safe file name segment (letters/digits/-/_ only). */
export function sanitizeFileNamePart(value) {
    return String(value || '').replace(/[^\w-]+/g, '_');
}

/**
 * Triggers a browser download of the given SpreadsheetML content.
 * A data: URI, not Blob/createObjectURL - Lightning Web Security has been observed to block or
 * silently no-op the Blob/object-URL download pattern from inside an LWC, while a plain data: URI
 * reliably triggers a save. The link must actually be attached to the page DOM before .click()
 * fires the download (a detached element's click didn't trigger one), so it's appended and
 * removed around the click rather than clicked directly.
 */
export function downloadSpreadsheet(xml, fileName) {
    const excelData = 'data:application/vnd.ms-excel;charset=utf-8,' + encodeURIComponent(xml);
    const link = document.createElement('a');
    link.setAttribute('href', excelData);
    link.setAttribute('download', fileName);
    link.setAttribute('target', '_self');
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}
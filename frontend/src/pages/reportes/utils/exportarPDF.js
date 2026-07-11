import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

/**
 * @param {object} opts
 * @param {string}   opts.titulo        - Nombre del reporte
 * @param {string}  [opts.subtitulo]    - Período u otro subtexto
 * @param {string[]} opts.columnas      - Cabeceras de la tabla
 * @param {any[][]}  opts.filas         - Filas de datos
 * @param {{label:string,valor:string|number}[]} [opts.totales] - Tarjetas resumen
 * @param {string}  [opts.nombreArchivo]
 * @param {string}  [opts.empresa]      - Nombre del negocio (de config)
 * @param {string}  [opts.generadoPor]  - Nombre del usuario que genera el PDF
 */
export function exportarPDF({ titulo, subtitulo, columnas, filas, totales, nombreArchivo, empresa, generadoPor }) {
  const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });
  const W = 297;
  const nombreEmpresa = empresa || 'RESTAURANTE';
  const ahora = new Date().toLocaleString('es-BO');

  // ── Header violeta ─────────────────────────────────────────
  doc.setFillColor(109, 40, 217);
  doc.rect(0, 0, W, 32, 'F');
  doc.setFillColor(124, 58, 237);
  doc.circle(270, -5, 30, 'F');
  doc.setFillColor(91, 33, 182);
  doc.circle(285, 37, 18, 'F');

  // Empresa (izquierda)
  doc.setTextColor(255, 255, 255);
  doc.setFontSize(16);
  doc.setFont('helvetica', 'bold');
  doc.text(nombreEmpresa.toUpperCase(), 14, 13);

  // Título del reporte
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  doc.text(titulo, 14, 22);

  // Metadatos (derecha)
  doc.setFontSize(8);
  doc.text(`Generado: ${ahora}`, W - 14, 11, { align: 'right' });
  if (generadoPor) doc.text(`Por: ${generadoPor}`, W - 14, 18, { align: 'right' });
  if (subtitulo)   doc.text(subtitulo, W - 14, 25, { align: 'right' });

  let y = 42;

  // ── Tarjetas resumen ───────────────────────────────────────
  if (totales && totales.length > 0) {
    const colW = (W - 28) / totales.length;
    totales.forEach((item, i) => {
      const x = 14 + i * colW;
      doc.setFillColor(245, 243, 255);
      doc.roundedRect(x, y, colW - 4, 15, 2, 2, 'F');
      doc.setTextColor(109, 40, 217);
      doc.setFontSize(7.5);
      doc.setFont('helvetica', 'normal');
      doc.text(item.label, x + 3, y + 6);
      doc.setFontSize(11);
      doc.setFont('helvetica', 'bold');
      doc.setTextColor(40, 40, 40);
      doc.text(String(item.valor), x + 3, y + 13);
    });
    y += 23;
  }

  // ── Tabla ──────────────────────────────────────────────────
  autoTable(doc, {
    head: [columnas],
    body: filas,
    startY: y,
    styles: { fontSize: 8, cellPadding: 2.5, overflow: 'linebreak' },
    headStyles: { fillColor: [109, 40, 217], textColor: 255, fontStyle: 'bold', fontSize: 8 },
    alternateRowStyles: { fillColor: [248, 245, 255] },
    margin: { left: 14, right: 14 },
    tableLineColor: [220, 210, 240],
    tableLineWidth: 0.1,
  });

  // ── Pie de página ──────────────────────────────────────────
  const pages = doc.internal.getNumberOfPages();
  for (let i = 1; i <= pages; i++) {
    doc.setPage(i);
    doc.setFontSize(7.5);
    doc.setTextColor(180, 180, 180);
    doc.text(`Página ${i} de ${pages}  ·  ${nombreEmpresa}  ·  Sistema de Gestión Restaurante`, W / 2, 207, { align: 'center' });
  }

  doc.save(nombreArchivo || 'reporte.pdf');
}

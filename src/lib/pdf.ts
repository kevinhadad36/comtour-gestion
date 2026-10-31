import { jsPDF } from 'jspdf';

export type PdfLine = {
  description: string;
  quantity?: number;
  unit?: string;
  unitPrice?: number;
  serviceFee?: number;
  total: number;
  currency?: string;
};

export type PdfDocument = {
  title: string;
  reference: string;
  companyName: string;
  address?: string;
  phone?: string;
  email?: string;
  logoData?: string;
  clientName?: string;
  clientContact?: string;
  date?: string;
  currency?: string;
  exchangeRate?: number;
  lines?: PdfLine[];
  summary?: Array<[string, string]>;
  clause?: string;
  filename?: string;
};

const navy: [number, number, number] = [16, 45, 69];
const teal: [number, number, number] = [16, 140, 145];
const muted: [number, number, number] = [99, 117, 134];
const money = (amount: number, currency = 'KMF') => `${new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 2 }).format(Number(amount || 0))} ${currency}`;
const cleanFilename = (name: string) => `${name.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-zA-Z0-9_-]+/g, '-').replace(/^-|-$/g, '') || 'document-comtour'}.pdf`;

export function downloadComTourPdf(data: PdfDocument) {
  const pdf = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4', compress: true });
  const width = pdf.internal.pageSize.getWidth();
  const height = pdf.internal.pageSize.getHeight();
  const left = 18;
  const right = width - 18;
  const contentWidth = right - left;
  let y = 20;

  pdf.setFillColor(...navy);
  pdf.rect(0, 0, width, 38, 'F');
  if (data.logoData) {
    try { pdf.addImage(data.logoData, data.logoData.includes('image/png') ? 'PNG' : 'JPEG', left, 8, 24, 20, undefined, 'FAST'); } catch { /* Logo absent or unsupported: keep the branded text header. */ }
  }
  pdf.setTextColor(255, 255, 255);
  pdf.setFont('helvetica', 'bold');
  pdf.setFontSize(16);
  pdf.text(data.companyName || 'Agence ComTour', data.logoData ? left + 29 : left, 16);
  pdf.setFont('helvetica', 'normal');
  pdf.setFontSize(8.5);
  const details = [data.address, data.phone, data.email].filter(Boolean).join(' · ');
  pdf.text(pdf.splitTextToSize(details || 'Moroni, Grande Comore, Union des Comores', contentWidth - (data.logoData ? 29 : 0)), data.logoData ? left + 29 : left, 24);
  pdf.setDrawColor(...teal);
  pdf.setLineWidth(1.2);
  pdf.line(left, 38, right, 38);
  y = 51;

  const addText = (text: string, options: { bold?: boolean; size?: number; color?: [number, number, number]; maxWidth?: number; gap?: number } = {}) => {
    const size = options.size ?? 10;
    pdf.setFont('helvetica', options.bold ? 'bold' : 'normal');
    pdf.setFontSize(size);
    pdf.setTextColor(...(options.color || navy));
    const lines = pdf.splitTextToSize(String(text || '—'), options.maxWidth ?? contentWidth);
    if (y + lines.length * (size * 0.45) > height - 22) { pdf.addPage(); y = 20; }
    pdf.text(lines, left, y);
    y += lines.length * (size * 0.45) + (options.gap ?? 4);
  };

  addText(data.title.toLocaleUpperCase('fr-FR'), { bold: true, size: 16, color: navy, gap: 7 });
  addText(`Référence : ${data.reference}    ·    Date : ${data.date || new Date().toLocaleDateString('fr-FR')}`, { size: 9, color: muted, gap: 7 });
  if (data.clientName || data.clientContact) {
    addText('CLIENT', { bold: true, size: 8, color: teal, gap: 2 });
    if (data.clientName) addText(data.clientName, { bold: true, size: 11, gap: 1 });
    if (data.clientContact) addText(data.clientContact, { size: 9, color: muted, gap: 6 });
  }
  if (data.exchangeRate) addText(`Devise : ${data.currency || 'KMF'}    ·    Taux EUR → KMF appliqué : ${data.exchangeRate}`, { size: 9, color: muted, gap: 5 });

  if (data.lines?.length) {
    const tableTop = y;
    pdf.setFillColor(239, 245, 247);
    pdf.roundedRect(left, tableTop - 5, contentWidth, 10, 2, 2, 'F');
    pdf.setFont('helvetica', 'bold');
    pdf.setFontSize(8);
    pdf.setTextColor(...navy);
    pdf.text('PRESTATION', left + 3, tableTop + 1);
    pdf.text('QTÉ', right - 51, tableTop + 1);
    pdf.text('PRIX UNIT.', right - 37, tableTop + 1);
    pdf.text('TOTAL', right - 3, tableTop + 1, { align: 'right' });
    y += 12;
    for (const line of data.lines) {
      const desc = pdf.splitTextToSize(line.description || 'Prestation', 82);
      const rowHeight = Math.max(9, desc.length * 4.4 + 2);
      if (y + rowHeight > height - 28) { pdf.addPage(); y = 20; }
      pdf.setDrawColor(225, 232, 236);
      pdf.line(left, y + rowHeight - 1, right, y + rowHeight - 1);
      pdf.setFont('helvetica', 'normal');
      pdf.setFontSize(8.5);
      pdf.setTextColor(...navy);
      pdf.text(desc, left + 3, y + 4);
      pdf.setTextColor(...muted);
      pdf.text(line.unit ? `${line.quantity ?? 1} ${line.unit}` : String(line.quantity ?? 1), right - 51, y + 4);
      pdf.text(money(line.unitPrice ?? line.total, line.currency || data.currency), right - 37, y + 4);
      pdf.setTextColor(...navy);
      pdf.setFont('helvetica', 'bold');
      pdf.text(money(line.total, line.currency || data.currency), right - 3, y + 4, { align: 'right' });
      if (line.serviceFee) {
        pdf.setFont('helvetica', 'normal');
        pdf.setFontSize(7.5);
        pdf.setTextColor(...muted);
        pdf.text(`Frais de service ComTour inclus : ${money(line.serviceFee, line.currency || data.currency)}`, left + 3, y + rowHeight - 3);
      }
      y += rowHeight;
    }
    y += 7;
  }

  if (data.summary?.length) {
    const summaryX = left + contentWidth * 0.38;
    for (const [label, value] of data.summary) {
      if (y + 9 > height - 24) { pdf.addPage(); y = 20; }
      pdf.setDrawColor(232, 237, 240);
      pdf.line(summaryX, y + 3, right, y + 3);
      pdf.setFont('helvetica', label.toLowerCase().includes('total') || label.toLowerCase().includes('résultat') ? 'bold' : 'normal');
      pdf.setFontSize(9);
      pdf.setTextColor(...navy);
      pdf.text(label, summaryX, y);
      pdf.text(value, right, y, { align: 'right' });
      y += 8;
    }
    y += 5;
  }

  if (data.clause) {
    addText('CONDITIONS COMMERCIALES', { bold: true, size: 8, color: teal, gap: 3 });
    addText(data.clause, { size: 8, color: muted, gap: 5 });
  }
  pdf.setFont('helvetica', 'normal');
  pdf.setFontSize(7.5);
  pdf.setTextColor(...muted);
  const pageCount = pdf.getNumberOfPages();
  for (let page = 1; page <= pageCount; page++) {
    pdf.setPage(page);
    pdf.line(left, height - 14, right, height - 14);
    pdf.text('COMTOUR GESTION · Moroni, Union des Comores', left, height - 9);
    pdf.text(`${page} / ${pageCount}`, right, height - 9, { align: 'right' });
  }
  pdf.save(cleanFilename(data.filename || `${data.title}-${data.reference}`));
}


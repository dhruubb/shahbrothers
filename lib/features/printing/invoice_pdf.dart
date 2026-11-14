import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';

/// A4 GST tax invoice as PDF (for preview, sharing on WhatsApp/email and
/// printing on regular printers).
class InvoicePdf {
  const InvoicePdf._();

  static pw.Font? _regular, _medium, _bold, _serif;

  static Future<void> _loadFonts() async {
    Future<pw.Font> load(String path) async => pw.Font.ttf(await rootBundle.load(path));
    _regular ??= await load('assets/fonts/Poppins-Regular.ttf');
    _medium ??= await load('assets/fonts/Poppins-Medium.ttf');
    _bold ??= await load('assets/fonts/Poppins-Bold.ttf');
    _serif ??= await load('assets/fonts/Lora-Bold.ttf');
  }

  static final _maroon = PdfColor.fromHex('#6E1423');
  static final _gold = PdfColor.fromHex('#B8893A');
  static final _cream = PdfColor.fromHex('#F7EFE2');
  static final _ink = PdfColor.fromHex('#2A1B1E');
  static final _muted = PdfColor.fromHex('#6F5E5A');
  static final _border = PdfColor.fromHex('#E9DDCB');

  static Future<Uint8List> build(Sale sale, AppSettings settings) async {
    await _loadFonts();
    final doc = pw.Document(title: 'Invoice ${sale.invoiceNumber}', author: settings.storeName);
    String m(int p) => Money.format(p, decimals: true);
    final half = _pct(sale.gstRate / 2);

    pw.Widget label(String t) => pw.Text(t.toUpperCase(),
        style: pw.TextStyle(font: _medium, fontSize: 7.5, color: _muted, letterSpacing: 0.8));

    pw.Widget totalRow(String l, String v, {bool strong = false, PdfColor? color}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(l, style: pw.TextStyle(font: strong ? _bold : _regular, fontSize: strong ? 12 : 9.5, color: color ?? _ink)),
            pw.Text(v, style: pw.TextStyle(font: strong ? _bold : _medium, fontSize: strong ? 12 : 9.5, color: color ?? _ink)),
          ]),
        );

    final cellStyle = pw.TextStyle(font: _regular, fontSize: 9, color: _ink);
    final headStyle = pw.TextStyle(font: _medium, fontSize: 8, color: PdfColors.white, letterSpacing: 0.4);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.copyWith(marginLeft: 36, marginRight: 36, marginTop: 32, marginBottom: 32),
      theme: pw.ThemeData.withFont(base: _regular, bold: _bold),
      footer: (ctx) => pw.Column(children: [
        pw.Container(height: 2, color: _gold),
        pw.SizedBox(height: 6),
        pw.Text(settings.invoiceFooter ?? 'Thank you for shopping with ${settings.storeName}!',
            textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8.5, color: _muted)),
        pw.SizedBox(height: 2),
        pw.Text('This is a computer-generated invoice. Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 7, color: _muted)),
      ]),
      build: (ctx) => [
        // Header band
        pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: pw.BoxDecoration(color: _maroon, borderRadius: pw.BorderRadius.circular(10)),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(settings.storeName, style: pw.TextStyle(font: _serif, fontSize: 24, color: PdfColors.white)),
                if (settings.tagline != null)
                  pw.Text(settings.tagline!, style: pw.TextStyle(fontSize: 8.5, color: _gold, letterSpacing: 1)),
                pw.SizedBox(height: 8),
                if (settings.address != null)
                  pw.Text(settings.address!, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white)),
                pw.Text(
                  [if (settings.phone != null) 'Ph: ${settings.phone}', if (settings.email != null) settings.email!].join('   '),
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white),
                ),
                if (settings.gstin != null)
                  pw.Text('GSTIN: ${settings.gstin}', style: pw.TextStyle(font: _medium, fontSize: 8.5, color: _gold)),
              ]),
            ),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(sale.isCancelled ? 'CANCELLED' : 'TAX INVOICE',
                  style: pw.TextStyle(font: _bold, fontSize: 11, color: sale.isCancelled ? PdfColors.red200 : _gold, letterSpacing: 1.5)),
              pw.SizedBox(height: 6),
              pw.Text(sale.invoiceNumber, style: pw.TextStyle(font: _bold, fontSize: 13, color: PdfColors.white)),
              pw.Text(Dates.dayTime(sale.createdAt), style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.white)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 16),
        // Parties
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(color: _cream, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                label('Billed to'),
                pw.SizedBox(height: 3),
                pw.Text(sale.customerName, style: pw.TextStyle(font: _bold, fontSize: 11)),
                if (sale.customerPhone.isNotEmpty)
                  pw.Text('+91 ${Validators.prettyPhone(sale.customerPhone)}', style: cellStyle),
              ]),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: _border), borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                label('Salesperson'),
                pw.Text(sale.salespersonName, style: pw.TextStyle(font: _medium, fontSize: 10)),
                pw.SizedBox(height: 4),
                label('Billed by'),
                pw.Text(sale.managerName, style: pw.TextStyle(font: _medium, fontSize: 10)),
              ]),
            ),
          ),
        ]),
        pw.SizedBox(height: 16),
        // Items
        pw.Table(
          border: pw.TableBorder(horizontalInside: pw.BorderSide(color: _border, width: 0.6)),
          columnWidths: const {
            0: pw.FixedColumnWidth(22),
            1: pw.FlexColumnWidth(4),
            2: pw.FixedColumnWidth(30),
            3: pw.FixedColumnWidth(70),
            4: pw.FixedColumnWidth(66),
            5: pw.FixedColumnWidth(76),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: _maroon),
              children: ['#', 'ITEM', 'QTY', 'RATE', 'DISCOUNT', 'AMOUNT']
                  .asMap()
                  .entries
                  .map((e) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: pw.Text(e.value, style: headStyle, textAlign: e.key >= 2 ? pw.TextAlign.right : pw.TextAlign.left),
                      ))
                  .toList(),
            ),
            for (var i = 0; i < sale.items.length; i++)
              pw.TableRow(children: [
                _cell('${i + 1}', cellStyle),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(sale.items[i].productName, style: pw.TextStyle(font: _medium, fontSize: 9)),
                    pw.Text(sale.items[i].productCode, style: pw.TextStyle(fontSize: 7.5, color: _muted)),
                  ]),
                ),
                _cell('${sale.items[i].quantity}', cellStyle, right: true),
                _cell(m(sale.items[i].unitPricePaise), cellStyle, right: true),
                _cell(sale.items[i].discountPaise == 0 ? '—' : '-${m(sale.items[i].discountPaise)}', cellStyle, right: true),
                _cell(m(sale.items[i].lineTotalPaise), cellStyle.copyWith(font: _medium), right: true),
              ]),
          ],
        ),
        pw.SizedBox(height: 14),
        // Totals + payments
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              label('Payment'),
              pw.SizedBox(height: 4),
              for (final p in sale.payments)
                pw.Text('${p.method.label}  ${m(p.amountPaise)}${p.reference == null ? '' : '  · ${p.reference}'}',
                    style: cellStyle),
              if (sale.notes != null) ...[
                pw.SizedBox(height: 10),
                label('Notes'),
                pw.Text(sale.notes!, style: cellStyle),
              ],
              if (sale.isCancelled && sale.cancelReason != null) ...[
                pw.SizedBox(height: 10),
                label('Cancelled'),
                pw.Text(sale.cancelReason!, style: cellStyle.copyWith(color: PdfColors.red800)),
              ],
            ]),
          ),
          pw.SizedBox(width: 24),
          pw.SizedBox(
            width: 220,
            child: pw.Column(children: [
              totalRow('Subtotal', m(sale.subtotalPaise)),
              if (sale.discountPaise > 0) totalRow('Discount', '-${m(sale.discountPaise)}'),
              totalRow('Taxable value', m(sale.taxablePaise)),
              totalRow('CGST @ $half%', m(sale.cgstPaise)),
              totalRow('SGST @ $half%', m(sale.sgstPaise)),
              if (sale.roundOffPaise != 0) totalRow('Round off', m(sale.roundOffPaise)),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: pw.BoxDecoration(color: _cream, borderRadius: pw.BorderRadius.circular(6)),
                child: totalRow('Total', m(sale.totalPaise), strong: true, color: _maroon),
              ),
            ]),
          ),
        ]),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _cell(String t, pw.TextStyle s, {bool right = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(t, style: s, textAlign: right ? pw.TextAlign.right : pw.TextAlign.left),
      );

  static String _pct(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
}

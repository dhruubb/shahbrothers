import 'dart:convert';

import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';

enum PaperWidth {
  mm58(32, '58 mm'),
  mm80(48, '80 mm');

  const PaperWidth(this.chars, this.label);
  final int chars;
  final String label;
}

/// Minimal ESC/POS command builder (no third-party dependency) that works
/// with standard 58/80 mm Bluetooth and network thermal printers.
class EscPosBuilder {
  EscPosBuilder(this.width) {
    _bytes.addAll(const [0x1B, 0x40]); // ESC @ initialise
    _bytes.addAll(const [0x1B, 0x74, 0x00]); // code page PC437
  }

  final PaperWidth width;
  final List<int> _bytes = [];

  int get cols => width.chars;
  List<int> get bytes => List.unmodifiable(_bytes);

  /// Thermal printers only reliably print ASCII.
  static String ascii(String s) {
    final replaced = s
        .replaceAll('₹', 'Rs.')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('×', 'x')
        .replaceAll('•', '*');
    return String.fromCharCodes(replaced.runes.map((r) => r >= 32 && r < 127 ? r : 0x3F));
  }

  void _cmd(List<int> c) => _bytes.addAll(c);

  void align(String a) => _cmd([0x1B, 0x61, a == 'center' ? 1 : (a == 'right' ? 2 : 0)]);
  void bold(bool on) => _cmd([0x1B, 0x45, on ? 1 : 0]);

  /// 1 = normal, 2 = double width + height
  void size(int s) => _cmd([0x1D, 0x21, s >= 2 ? 0x11 : 0x00]);

  void text(String s, {String align = 'left', bool bold = false, int size = 1}) {
    this.align(align);
    if (bold) this.bold(true);
    if (size > 1) this.size(size);
    _bytes.addAll(latin1.encode(ascii(s)));
    _bytes.add(0x0A);
    if (size > 1) this.size(1);
    if (bold) this.bold(false);
    if (align != 'left') this.align('left');
  }

  /// Word-wrapped text block.
  void wrapped(String s, {String align = 'left'}) {
    for (final line in wrap(ascii(s), cols)) {
      text(line, align: align);
    }
  }

  void divider([String ch = '-']) => text(ch * cols);

  /// Left text and right-aligned value on one line (left truncated if needed).
  void row(String left, String right, {bool bold = false}) {
    final r = ascii(right);
    final maxLeft = cols - r.length - 1;
    var l = ascii(left);
    if (l.length > maxLeft) l = maxLeft > 1 ? '${l.substring(0, maxLeft - 1)}.' : '';
    text(l + ' ' * (cols - l.length - r.length) + r, bold: bold);
  }

  void feed([int lines = 1]) => _cmd([0x1B, 0x64, lines.clamp(0, 10)]);
  void cut() => _cmd([0x1D, 0x56, 0x42, 0x00]); // partial cut with feed

  static List<String> wrap(String s, int width) {
    final words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final lines = <String>[];
    var current = '';
    for (var w in words) {
      while (w.length > width) {
        if (current.isNotEmpty) {
          lines.add(current);
          current = '';
        }
        lines.add(w.substring(0, width));
        w = w.substring(width);
      }
      if (current.isEmpty) {
        current = w;
      } else if (current.length + 1 + w.length <= width) {
        current = '$current $w';
      } else {
        lines.add(current);
        current = w;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines;
  }
}

/// Builds a GST receipt for [sale].
List<int> buildReceipt(Sale sale, AppSettings settings, PaperWidth width) {
  final b = EscPosBuilder(width);
  String amt(int paise) => Money.format(paise, decimals: true, withSymbol: false);

  b.text(settings.storeName.toUpperCase(), align: 'center', bold: true, size: 2);
  if (settings.tagline != null) b.text(settings.tagline!, align: 'center');
  if (settings.address != null) b.wrapped(settings.address!, align: 'center');
  if (settings.phone != null) b.text('Ph: ${settings.phone}', align: 'center');
  if (settings.gstin != null) b.text('GSTIN: ${settings.gstin}', align: 'center');
  b.divider('=');
  b.text(sale.isCancelled ? 'TAX INVOICE (CANCELLED)' : 'TAX INVOICE', align: 'center', bold: true);
  b.row('Invoice', sale.invoiceNumber);
  b.row('Date', Dates.dayTime(sale.createdAt));
  b.row('Customer', sale.customerName);
  if (sale.customerPhone.isNotEmpty) b.row('Mobile', Validators.prettyPhone(sale.customerPhone));
  b.row('Salesperson', sale.salespersonName);
  b.divider();
  b.row('Item', 'Amount', bold: true);
  b.divider();
  for (final i in sale.items) {
    b.wrapped('${i.productName} (${i.productCode})');
    b.row('  ${i.quantity} x ${amt(i.unitPricePaise)}', amt(i.grossPaise));
    if (i.discountPaise > 0) {
      final label = i.discountType == DiscountType.percent ? '  Disc ${_pct(i.discountValue)}%' : '  Discount';
      b.row(label, '-${amt(i.discountPaise)}');
    }
  }
  b.divider();
  b.row('Subtotal', amt(sale.subtotalPaise));
  if (sale.discountPaise > 0) b.row('Discount', '-${amt(sale.discountPaise)}');
  b.row('Taxable value', amt(sale.taxablePaise));
  final half = _pct(sale.gstRate / 2);
  b.row('CGST @ $half%', amt(sale.cgstPaise));
  b.row('SGST @ $half%', amt(sale.sgstPaise));
  if (sale.roundOffPaise != 0) b.row('Round off', amt(sale.roundOffPaise));
  b.divider('=');
  b.row('TOTAL', 'Rs. ${amt(sale.totalPaise)}', bold: true);
  b.divider('=');
  for (final p in sale.payments) {
    b.row('Paid by ${p.method.label}${p.reference == null ? '' : ' (${p.reference})'}', amt(p.amountPaise));
  }
  b.feed(1);
  if (settings.invoiceFooter != null) b.wrapped(settings.invoiceFooter!, align: 'center');
  b.text('Billed by ${sale.managerName}', align: 'center');
  b.feed(3);
  b.cut();
  return b.bytes;
}

/// Short test page for printer setup.
List<int> buildTestPage(AppSettings settings, PaperWidth width) {
  final b = EscPosBuilder(width);
  b.text(settings.storeName.toUpperCase(), align: 'center', bold: true, size: 2);
  b.text('Printer test', align: 'center');
  b.divider();
  b.row('Paper', width.label);
  b.row('Columns', '${width.chars}');
  b.row('Rupee sample', Money.ascii(1234500));
  b.divider();
  b.text('If this looks right, you are ready to print invoices.', align: 'center');
  b.feed(3);
  b.cut();
  return b.bytes;
}

String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/analytics.dart';
import '../../providers/providers.dart';
import '../dashboard/filter_bar.dart';

class _Report {
  _Report(this.sales, this.staff, this.products, this.range, this.salespersonName)
      : summary = Analytics.summarize(sales),
        bySalesperson = Analytics.bySalesperson(sales, staff),
        byCategory = Analytics.byCategory(sales, products),
        byPayment = Analytics.byPaymentMethod(sales),
        topProducts = Analytics.topProducts(sales, limit: 8),
        cancelled = sales.where((s) => s.isCancelled).toList() {
    final map = <DateTime, List<Sale>>{};
    for (final s in sales) {
      map.putIfAbsent(Dates.startOfDay(s.createdAt), () => []).add(s);
    }
    days = map.entries.map((e) => (day: e.key, summary: Analytics.summarize(e.value))).toList()
      ..sort((a, b) => b.day.compareTo(a.day));
  }

  final List<Sale> sales;
  final List<AppUser> staff;
  final List<Product> products;
  final DateRangeFilter range;
  final String? salespersonName;
  final SalesSummary summary;
  final List<SalespersonPerformance> bySalesperson;
  final List<BreakdownEntry> byCategory;
  final List<BreakdownEntry> byPayment;
  final List<BreakdownEntry> topProducts;
  final List<Sale> cancelled;
  late final List<({DateTime day, SalesSummary summary})> days;

  String get title => 'Sales report · ${Dates.day(range.start)} – ${Dates.day(range.lastDay)}'
      '${salespersonName == null ? '' : ' · $salespersonName'}';
}

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dashboardFilterProvider);
    final sales = ref.watch(dashboardSalesProvider);
    final staff = ref.watch(staffProvider).valueOrNull ?? const <AppUser>[];
    final products = ref.watch(productsProvider).valueOrNull ?? const <Product>[];
    final settings = ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
    final spName = staff.where((u) => u.id == filter.salespersonId).firstOrNull?.fullName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales reports'),
        actions: [
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: sales.valueOrNull == null
                ? null
                : () {
                    final report = _Report(sales.value!, staff, products, filter.range, spName);
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Report PDF')),
                        body: PdfPreview(
                          build: (_) => _buildPdf(report, settings),
                          canChangeOrientation: false,
                          canChangePageFormat: false,
                          canDebug: false,
                          pdfFileName: 'ShahBrothers-Sales-${Dates.isoDate(filter.range.start)}.pdf',
                        ),
                      ),
                    ));
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 4), child: DashboardFilterBar()),
          Expanded(
            child: AsyncView<List<Sale>>(
              value: sales,
              onRetry: () => ref.refreshData(),
              builder: (list) {
                final r = _Report(list, staff, products, filter.range, spName);
                final s = r.summary;
                return MaxWidth(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      Text(r.title, style: Theme.of(context).textTheme.bodySmall),
                      const SectionHeader('Summary', padding: EdgeInsets.fromLTRB(4, 12, 4, 8)),
                      _Table(rows: [
                        ('Gross revenue (incl. GST)', Money.format(s.revenuePaise, decimals: true)),
                        ('Net sales (taxable value)', Money.format(s.netSalesPaise, decimals: true)),
                        ('CGST + SGST collected', Money.format(s.gstPaise, decimals: true)),
                        ('Discounts given', Money.format(s.discountPaise, decimals: true)),
                        ('Bills', '${s.billCount}'),
                        ('Sarees sold', '${s.itemsSold}'),
                        ('Unique customers', '${s.customerCount}'),
                        ('Average bill', Money.format(s.averageBillPaise, decimals: false)),
                        ('Cancelled invoices', '${r.cancelled.length}'),
                      ]),
                      const SectionHeader('By salesperson'),
                      _Table(header: const ('Salesperson', 'Bills · Revenue'), rows: [
                        for (final p in r.bySalesperson)
                          (p.user.fullName, '${p.billCount} · ${Money.format(p.revenuePaise, decimals: false)}'),
                      ]),
                      const SectionHeader('By payment method'),
                      _Table(rows: [for (final e in r.byPayment) ('${e.label} (${e.count})', Money.format(e.valuePaise, decimals: false))]),
                      const SectionHeader('By category'),
                      _Table(rows: [for (final e in r.byCategory) ('${e.label} · ${e.count} pcs', Money.format(e.valuePaise, decimals: false))]),
                      const SectionHeader('Best-selling sarees'),
                      _Table(rows: [for (final e in r.topProducts) ('${e.label} · ${e.count}', Money.format(e.valuePaise, decimals: false))]),
                      const SectionHeader('Day-wise'),
                      _Table(header: const ('Date', 'Bills · Revenue'), rows: [
                        for (final d in r.days)
                          ('${Dates.weekday(d.day)}, ${Dates.day(d.day)}', '${d.summary.billCount} · ${Money.format(d.summary.revenuePaise, decimals: false)}'),
                      ]),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.rows, this.header});
  final List<(String, String)> rows;
  final (String, String)? header;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const AppCard(child: Text('No data for this period.', style: TextStyle(color: AppColors.inkMuted)));
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(children: [
              Expanded(child: Text(header!.$1.toUpperCase(), style: Theme.of(context).textTheme.labelSmall)),
              Text(header!.$2.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
            ]),
          ),
        for (var i = 0; i < rows.length; i++)
          Container(
            color: i.isOdd ? AppColors.cream.withValues(alpha: 0.5) : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(children: [
              Expanded(child: Text(rows[i].$1)),
              MoneyText(rows[i].$2, size: 14),
            ]),
          ),
      ]),
    );
  }
}

Future<Uint8List> _buildPdf(_Report r, AppSettings settings) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
  final serif = pw.Font.ttf(await rootBundle.load('assets/fonts/Lora-Bold.ttf'));
  final maroon = PdfColor.fromHex('#6E1423');
  final gold = PdfColor.fromHex('#B8893A');
  final cream = PdfColor.fromHex('#F7EFE2');
  String m(int p) => Money.format(p, decimals: false);

  pw.Widget table(String title, List<String> headers, List<List<String>> rows) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 14),
          pw.Text(title, style: pw.TextStyle(font: serif, fontSize: 13, color: maroon)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: maroon),
            cellStyle: const pw.TextStyle(fontSize: 9),
            oddRowDecoration: pw.BoxDecoration(color: cream),
            cellAlignments: {for (var i = 1; i < headers.length; i++) i: pw.Alignment.centerRight},
            border: null,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
        ],
      );

  final s = r.summary;
  final doc = pw.Document(title: r.title, author: settings.storeName);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
    header: (ctx) => pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: gold, width: 1.5))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(settings.storeName, style: pw.TextStyle(font: serif, fontSize: 18, color: maroon)),
        pw.Text('Generated ${Dates.dayTime(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
      ]),
    ),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
    ),
    build: (ctx) => [
      pw.SizedBox(height: 8),
      pw.Text(r.title, style: pw.TextStyle(font: bold, fontSize: 12)),
      table('Summary', ['Metric', 'Value'], [
        ['Gross revenue (incl. GST)', Money.format(s.revenuePaise, decimals: true)],
        ['Net sales (taxable value)', Money.format(s.netSalesPaise, decimals: true)],
        ['GST collected', Money.format(s.gstPaise, decimals: true)],
        ['Discounts', Money.format(s.discountPaise, decimals: true)],
        ['Bills', '${s.billCount}'],
        ['Sarees sold', '${s.itemsSold}'],
        ['Unique customers', '${s.customerCount}'],
        ['Average bill', m(s.averageBillPaise)],
        ['Cancelled invoices', '${r.cancelled.length}'],
      ]),
      table('By salesperson', ['Salesperson', 'Bills', 'Sarees', 'Net sales', 'Revenue', 'Share'], [
        for (final p in r.bySalesperson)
          [p.user.fullName, '${p.billCount}', '${p.itemsSold}', m(p.netSalesPaise), m(p.revenuePaise), '${p.sharePct.toStringAsFixed(1)}%'],
      ]),
      table('By payment method', ['Method', 'Payments', 'Amount'], [
        for (final e in r.byPayment) [e.label, '${e.count}', m(e.valuePaise)],
      ]),
      table('By category', ['Category', 'Pieces', 'Net value'], [
        for (final e in r.byCategory) [e.label, '${e.count}', m(e.valuePaise)],
      ]),
      table('Day-wise', ['Date', 'Bills', 'Sarees', 'Revenue'], [
        for (final d in r.days) [Dates.day(d.day), '${d.summary.billCount}', '${d.summary.itemsSold}', m(d.summary.revenuePaise)],
      ]),
      table('Invoices', ['Invoice', 'Date', 'Customer', 'Salesperson', 'Mode', 'Total'], [
        for (final x in r.sales)
          [
            x.invoiceNumber,
            Dates.dayShort(x.createdAt),
            x.customerName,
            x.salespersonName,
            x.isCancelled ? 'Cancelled' : x.paymentMode.label,
            m(x.totalPaise),
          ],
      ]),
    ],
  ));
  return doc.save();
}

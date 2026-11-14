import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/exceptions.dart';
import '../../domain/permissions.dart';
import '../../providers/providers.dart';
import '../printing/escpos.dart';
import '../printing/invoice_pdf.dart';
import '../printing/printer_service.dart';
import 'invoice_view.dart';

class InvoiceScreen extends ConsumerStatefulWidget {
  const InvoiceScreen({super.key, required this.saleId, this.justCreated = false});

  final String saleId;
  final bool justCreated;

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  bool _printing = false;

  Future<void> _thermalPrint(Sale sale, AppSettings settings) async {
    final service = ref.read(printerServiceProvider);
    final config = await service.load();
    if (!mounted) return;
    if (!config.isConfigured) {
      final go = await confirmDialog(context,
          title: 'No printer set up',
          message: 'Connect a Bluetooth or Wi-Fi thermal printer to print receipts. You can also share or print the PDF.',
          confirm: 'Set up printer');
      if (go && mounted) context.push('/settings/printer');
      return;
    }
    setState(() => _printing = true);
    try {
      await service.printBytes(config, buildReceipt(sale, settings, config.paper));
      if (mounted) showSnack(context, 'Sent to ${config.summary}');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _openPdf(Sale sale, AppSettings settings) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(sale.invoiceNumber)),
        body: PdfPreview(
          build: (_) => InvoicePdf.build(sale, settings),
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          pdfFileName: 'Invoice-${sale.invoiceNumber.replaceAll('/', '-')}.pdf',
        ),
      ),
    ));
  }

  Future<void> _cancel(Sale sale) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.ivory,
        surfaceTintColor: Colors.transparent,
        title: const Text('Cancel invoice?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${sale.invoiceNumber} will be marked cancelled, its stock returned, and it will no longer count in sales.'),
          const SizedBox(height: 14),
          AppTextField(controller: reason, label: 'Reason', hint: 'e.g. Customer returned the saree', autofocus: true),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel invoice'),
          ),
        ],
      ),
    );
    final text = reason.text;
    reason.dispose();
    if (ok != true) return;
    try {
      await ref.read(repositoryProvider).cancelSale(sale.id, text);
      ref.refreshData();
      if (mounted) showSnack(context, 'Invoice cancelled');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saleAsync = ref.watch(saleProvider(widget.saleId));
    final settingsAsync = ref.watch(settingsProvider);
    final user = ref.watch(currentUserProvider);
    final canPrint = user?.can(Permission.printInvoice) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(saleAsync.valueOrNull?.invoiceNumber ?? 'Invoice'),
        actions: [
          if (user?.can(Permission.cancelInvoice) ?? false)
            PopupMenuButton<String>(
              onSelected: (v) {
                final s = saleAsync.valueOrNull;
                if (v == 'cancel' && s != null) _cancel(s);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'cancel',
                  enabled: !(saleAsync.valueOrNull?.isCancelled ?? true),
                  child: const Text('Cancel invoice'),
                ),
              ],
            ),
        ],
      ),
      body: AsyncView<Sale?>(
        value: saleAsync,
        onRetry: () => ref.invalidate(saleProvider(widget.saleId)),
        builder: (sale) {
          if (sale == null) {
            return const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Invoice not available',
              message: 'It may have been removed, or you do not have access to it.',
            );
          }
          final settings = settingsAsync.valueOrNull ?? const AppSettings();
          return MaxWidth(
            width: 640,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (widget.justCreated)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(16)),
                    child: const Row(children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('Bill saved. Print the receipt or share the invoice with the customer.',
                            style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                InvoiceView(sale: sale, settings: settings),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: saleAsync.valueOrNull == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openPdf(saleAsync.value!, settingsAsync.valueOrNull ?? const AppSettings()),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF / Share'),
                    ),
                  ),
                  if (canPrint) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _printing
                            ? null
                            : () => _thermalPrint(saleAsync.value!, settingsAsync.valueOrNull ?? const AppSettings()),
                        icon: _printing
                            ? const SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ivory))
                            : const Icon(Icons.print_rounded),
                        label: const Text('Print'),
                      ),
                    ),
                  ],
                  if (widget.justCreated && (user?.can(Permission.createBill) ?? false)) ...[
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      tooltip: 'New bill',
                      onPressed: () => context.pushReplacement('/bill/new'),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ]),
              ),
            ),
    );
  }
}

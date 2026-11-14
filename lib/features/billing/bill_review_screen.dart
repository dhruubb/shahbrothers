import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/exceptions.dart';
import '../../providers/providers.dart';
import 'bill_controller.dart';
import 'invoice_view.dart';

/// Invoice preview before saving.
class BillReviewScreen extends ConsumerStatefulWidget {
  const BillReviewScreen({super.key});

  @override
  ConsumerState<BillReviewScreen> createState() => _BillReviewScreenState();
}

class _BillReviewScreenState extends ConsumerState<BillReviewScreen> {
  bool _saving = false;

  Future<void> _save(AppSettings settings) async {
    final draft = ref.read(billDraftProvider);
    final problems = draft.problems(settings.gstRate);
    if (problems.isNotEmpty) {
      showSnack(context, problems.first, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final sale = await ref.read(repositoryProvider).createSale(draft.toInput(settings.gstRate));
      if (!mounted) return;
      final router = GoRouter.of(context);
      final nav = Navigator.of(context);
      ref.read(billDraftProvider.notifier).reset();
      ref.refreshData();
      nav.popUntil((r) => r.isFirst);
      router.push('/invoice/${sale.id}?new=1');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, friendlyError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(billDraftProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final staff = ref.watch(staffProvider).valueOrNull ?? const <AppUser>[];
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Review bill')),
      body: AsyncView<AppSettings>(
        value: settingsAsync,
        builder: (settings) {
          if (draft.items.isEmpty) {
            return const EmptyState(icon: Icons.receipt_long_outlined, title: 'Nothing to review', message: 'Add sarees to the bill first.');
          }
          final t = draft.totals(settings.gstRate);
          final sp = staff.where((u) => u.id == draft.salespersonId).firstOrNull;
          final preview = Sale(
            id: '',
            invoiceNumber: '',
            customerId: draft.customer?.id ?? '',
            customerName: draft.customer?.name ?? draft.customerName.trim(),
            customerPhone: draft.customer?.phone ?? draft.customerPhone,
            salespersonId: draft.salespersonId ?? '',
            salespersonName: sp?.fullName ?? '',
            managerId: me?.id ?? '',
            managerName: me?.fullName ?? '',
            subtotalPaise: t.subtotalPaise,
            discountPaise: t.discountPaise,
            taxablePaise: t.taxablePaise,
            gstRate: settings.gstRate,
            cgstPaise: t.cgstPaise,
            sgstPaise: t.sgstPaise,
            gstPaise: t.gstPaise,
            roundOffPaise: t.roundOffPaise,
            totalPaise: t.totalPaise,
            paymentMode: draft.mode,
            status: SaleStatus.completed,
            createdAt: DateTime.now(),
            notes: draft.notes.trim().isEmpty ? null : draft.notes.trim(),
            items: [
              for (var i = 0; i < draft.items.length; i++)
                SaleItem(
                  productId: draft.items[i].productId,
                  productName: draft.items[i].productName,
                  productCode: draft.items[i].productCode,
                  quantity: draft.items[i].quantity,
                  unitPricePaise: draft.items[i].unitPricePaise,
                  discountType: draft.items[i].discountType,
                  discountValue: draft.items[i].discountValue,
                  discountPaise: t.lines[i].discountPaise,
                  lineTotalPaise: t.lines[i].netPaise,
                ),
            ],
            payments: draft.payments(t.totalPaise),
          );
          return MaxWidth(
            width: 640,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                InvoiceView(sale: preview, settings: settings, preview: true),
                const SizedBox(height: 14),
                Row(children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.inkMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'The invoice number is assigned when you save. Totals are re-checked by the server.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(onPressed: _saving ? null : () => context.pop(), child: const Text('Edit')),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _saving || settingsAsync.valueOrNull == null ? null : () => _save(settingsAsync.value!),
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ivory))
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(_saving
                    ? 'Saving…'
                    : 'Save ${Money.format(draft.totals(settingsAsync.valueOrNull?.gstRate ?? 5).totalPaise, decimals: false)}'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

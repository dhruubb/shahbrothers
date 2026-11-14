import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';

/// On-screen invoice, used for the pre-save preview and saved invoices.
class InvoiceView extends StatelessWidget {
  const InvoiceView({super.key, required this.sale, required this.settings, this.preview = false});

  final Sale sale;
  final AppSettings settings;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final half = _pct(sale.gstRate / 2);

    Widget row(String l, String v, {bool strong = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(
              child: Text(l,
                  style: TextStyle(
                      fontSize: strong ? 16 : 14,
                      fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                      color: color ?? (strong ? AppColors.ink : AppColors.inkMuted))),
            ),
            MoneyText(v, size: strong ? 20 : 14, weight: strong ? FontWeight.w700 : FontWeight.w600, color: color),
          ]),
        );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.maroon900.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            color: AppColors.maroon,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandMark(size: 44, onDark: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(settings.storeName,
                        style: const TextStyle(
                            fontFamily: AppTheme.serif, fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ivory)),
                    if (settings.address != null)
                      Text(settings.address!, style: const TextStyle(fontSize: 11.5, color: AppColors.goldLight, height: 1.3)),
                    if (settings.gstin != null)
                      Text('GSTIN ${settings.gstin}', style: const TextStyle(fontSize: 11.5, color: AppColors.goldLight)),
                  ]),
                ),
              ],
            ),
          ),
          const ZariBorder(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(preview ? 'INVOICE PREVIEW' : 'TAX INVOICE', style: t.labelSmall),
                    const SizedBox(height: 2),
                    Text(preview ? 'Number assigned on save' : sale.invoiceNumber,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: preview ? 14 : 16,
                            color: preview ? AppColors.inkMuted : AppColors.ink,
                            fontFeatures: AppTheme.tabular)),
                    Text(Dates.dayTime(sale.createdAt), style: t.bodySmall),
                  ]),
                ),
                if (sale.isCancelled) const Pill('Cancelled', tone: PillTone.danger, icon: Icons.block_rounded),
                if (!sale.isCancelled && !preview) Pill(sale.paymentMode.label, tone: PillTone.gold),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _party('Billed to', sale.customerName,
                      sale.customerPhone.isEmpty ? null : '+91 ${Validators.prettyPhone(sale.customerPhone)}'),
                ),
                const SizedBox(width: 12),
                Expanded(child: _party('Salesperson', sale.salespersonName, sale.managerName.isEmpty ? null : 'Billed by ${sale.managerName}')),
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.fromLTRB(18, 12, 18, 0), child: Divider()),
          for (var i = 0; i < sale.items.length; i++) _item(sale.items[i], i),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Divider()),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
            child: Column(children: [
              row('Subtotal', Money.format(sale.subtotalPaise)),
              if (sale.discountPaise > 0) row('Discount', '-${Money.format(sale.discountPaise)}', color: AppColors.success),
              row('Taxable value', Money.format(sale.taxablePaise)),
              row('CGST @ $half%', Money.format(sale.cgstPaise, decimals: true)),
              row('SGST @ $half%', Money.format(sale.sgstPaise, decimals: true)),
              if (sale.roundOffPaise != 0) row('Round off', Money.format(sale.roundOffPaise, decimals: true)),
            ]),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.goldPale, borderRadius: BorderRadius.circular(14)),
            child: row('Total', Money.format(sale.totalPaise, decimals: false), strong: true, color: AppColors.maroon),
          ),
          if (sale.payments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final p in sale.payments)
                    Pill(
                      '${p.method.label} ${Money.format(p.amountPaise)}${(p.reference ?? '').isEmpty ? '' : ' · ${p.reference}'}',
                      icon: switch (p.method) {
                        PaymentMethod.cash => Icons.payments_outlined,
                        PaymentMethod.upi => Icons.qr_code_2_rounded,
                        PaymentMethod.card => Icons.credit_card_rounded,
                      },
                    ),
                ],
              ),
            ),
          if (sale.notes != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Text('Note: ${sale.notes}', style: t.bodySmall),
            ),
          if (sale.isCancelled && sale.cancelReason != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(12)),
              child: Text(
                'Cancelled${sale.cancelledAt == null ? '' : ' on ${Dates.dayTime(sale.cancelledAt!)}'}: ${sale.cancelReason}',
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _party(String label, String name, String? sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10.5, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
          const SizedBox(height: 2),
          Text(name.isEmpty ? '—' : name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          if (sub != null) Text(sub, style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
        ],
      );

  Widget _item(SaleItem i, int index) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text('${index + 1}.', style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(i.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(
                  '${i.productCode} · ${i.quantity} × ${Money.format(i.unitPricePaise)}${i.discountPaise > 0 ? ' · ${i.discountLabel}' : ''}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            MoneyText(Money.format(i.lineTotalPaise), size: 14.5),
          ],
        ),
      );

  static String _pct(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
}

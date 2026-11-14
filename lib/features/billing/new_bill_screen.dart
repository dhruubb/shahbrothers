import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/billing_calculator.dart';
import '../../providers/providers.dart';
import 'add_item_sheet.dart';
import 'bill_controller.dart';

class NewBillScreen extends ConsumerStatefulWidget {
  const NewBillScreen({super.key});

  @override
  ConsumerState<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends ConsumerState<NewBillScreen> {
  late final TextEditingController _phone;
  late final TextEditingController _name;
  late final TextEditingController _reference;
  late final TextEditingController _cash;
  late final TextEditingController _notes;
  final List<TextEditingController> _splitCtrls = [];
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final d = ref.read(billDraftProvider);
    _phone = TextEditingController(text: d.customerPhone);
    _name = TextEditingController(text: d.customerName);
    _reference = TextEditingController(text: d.reference);
    _cash = TextEditingController(text: d.cashReceivedPaise == null ? '' : '${d.cashReceivedPaise! ~/ 100}');
    _notes = TextEditingController(text: d.notes);
    _syncSplitControllers(d);
  }

  void _syncSplitControllers(BillDraft d) {
    while (_splitCtrls.length < d.splits.length) {
      final p = d.splits[_splitCtrls.length];
      _splitCtrls.add(TextEditingController(text: p.amountPaise == 0 ? '' : _plain(p.amountPaise)));
    }
    while (_splitCtrls.length > d.splits.length) {
      _splitCtrls.removeLast().dispose();
    }
  }

  static String _plain(int paise) => paise % 100 == 0 ? '${paise ~/ 100}' : (paise / 100).toStringAsFixed(2);

  @override
  void dispose() {
    for (final c in [_phone, _name, _reference, _cash, _notes, ..._splitCtrls]) {
      c.dispose();
    }
    super.dispose();
  }

  BillDraftController get _ctrl => ref.read(billDraftProvider.notifier);

  Future<void> _close() async {
    final d = ref.read(billDraftProvider);
    if (d.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.ivory,
        surfaceTintColor: Colors.transparent,
        title: const Text('Leave this bill?'),
        content: const Text('You can keep it as a draft and continue later, or discard it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('Discard', style: TextStyle(color: AppColors.error))),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'keep'), child: const Text('Keep draft')),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'discard') _ctrl.reset();
    // Imperative pop: not blocked by the PopScope guarding this page.
    Navigator.of(context).pop();
  }

  Future<void> _addItem() async {
    final item = await showAddItemSheet(context);
    if (item != null) _ctrl.addItem(item);
  }

  Future<void> _editItem(int i) async {
    final item = await showAddItemSheet(context, initial: ref.read(billDraftProvider).items[i]);
    if (item != null) _ctrl.updateItem(i, item);
  }

  Future<void> _searchCustomer() async {
    final c = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const FractionallySizedBox(heightFactor: 0.85, child: _CustomerSearchSheet()),
    );
    if (c != null) {
      _ctrl.selectCustomer(c);
      _phone.text = c.phone;
      _name.text = c.name;
    }
  }

  void _review(double gstRate) {
    final problems = ref.read(billDraftProvider).problems(gstRate);
    if (problems.isNotEmpty) {
      setState(() => _showErrors = true);
      showSnack(context, problems.first, error: true);
      return;
    }
    context.push('/bill/review');
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(billDraftProvider);
    _syncSplitControllers(draft);
    final settings = ref.watch(settingsProvider);
    final gstRate = settings.valueOrNull?.gstRate ?? 5;
    final totals = draft.totals(gstRate);
    final problems = _showErrors ? draft.problems(gstRate) : const <String>[];

    return PopScope(
      canPop: draft.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: _close, tooltip: 'Close'),
          title: const Text('New bill'),
          actions: [
            if (!draft.isEmpty)
              TextButton(
                onPressed: () async {
                  if (await confirmDialog(context,
                      title: 'Clear bill?', message: 'Remove the customer, items and payment details?', confirm: 'Clear')) {
                    _ctrl.reset();
                    for (final c in [_phone, _name, _reference, _cash, _notes]) {
                      c.clear();
                    }
                    for (final c in _splitCtrls) {
                      c.clear();
                    }
                    setState(() => _showErrors = false);
                  }
                },
                child: const Text('Clear'),
              ),
          ],
        ),
        body: MaxWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _StepHeader(number: 1, title: 'Customer', done: draft.customer != null || (draft.customerName.isNotEmpty && Validators.isMobile(draft.customerPhone))),
              _customerSection(draft),
              _StepHeader(number: 2, title: 'Salesperson', done: draft.salespersonId != null),
              _salespersonSection(draft),
              _StepHeader(number: 3, title: 'Sarees', done: draft.items.isNotEmpty),
              _itemsSection(draft, totals),
              _StepHeader(number: 4, title: 'Payment', done: draft.items.isNotEmpty && draft.problems(gstRate).isEmpty),
              _paymentSection(draft, totals),
              const SizedBox(height: 12),
              AppTextField(
                controller: _notes,
                label: 'Notes (optional)',
                hint: 'Fall & pico, blouse stitching, delivery…',
                maxLines: 2,
                onChanged: _ctrl.setNotes,
              ),
              const SizedBox(height: 16),
              _SummaryCard(totals: totals, gstRate: gstRate),
              if (problems.isNotEmpty) ...[
                const SizedBox(height: 12),
                AppCard(
                  color: AppColors.errorBg,
                  borderColor: AppColors.errorBg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final p in problems)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                            const SizedBox(width: 8),
                            Expanded(child: Text(p, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w500))),
                          ]),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: _BottomBar(
          totalPaise: totals.totalPaise,
          itemCount: draft.items.fold(0, (s, i) => s + i.quantity),
          onReview: () => _review(gstRate),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ customer
  Widget _customerSection(BillDraft draft) {
    final customers = ref.watch(customersProvider).valueOrNull ?? const <Customer>[];
    final c = draft.customer;
    if (c != null) {
      final stats = ref.watch(customerStatsProvider).valueOrNull?[c.id];
      return AppCard(
        child: Row(
          children: [
            InitialsAvatar(c.initials, size: 44, highlight: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text('+91 ${Validators.prettyPhone(c.phone)}', style: const TextStyle(color: AppColors.inkMuted)),
                const SizedBox(height: 4),
                Pill(
                  stats == null || stats.purchaseCount == 0
                      ? 'Existing customer'
                      : 'Returning · ${stats.purchaseCount} visit${stats.purchaseCount == 1 ? '' : 's'} · ${Money.compact(stats.totalSpentPaise)}',
                  tone: PillTone.gold,
                  icon: Icons.favorite_border_rounded,
                ),
              ]),
            ),
            TextButton(
              onPressed: () {
                _ctrl.clearCustomer();
                _phone.clear();
                _name.clear();
              },
              child: const Text('Change'),
            ),
          ],
        ),
      );
    }

    final q = _phone.text.trim().isNotEmpty ? _phone.text.replaceAll(' ', '') : _name.text.trim().toLowerCase();
    final suggestions = q.length < 3
        ? const <Customer>[]
        : customers
            .where((x) => x.phone.contains(q) || x.name.toLowerCase().contains(q))
            .take(3)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _phone,
          label: 'Mobile number',
          prefixText: '+91 ',
          prefixIcon: Icons.phone_iphone_rounded,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          onChanged: (v) {
            _ctrl.editCustomer(phone: v, known: customers);
            final matched = ref.read(billDraftProvider).customer;
            if (matched != null) _name.text = matched.name;
            setState(() {});
          },
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _name,
          label: 'Customer name',
          prefixIcon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) {
            _ctrl.editCustomer(name: v, known: const []);
            setState(() {});
          },
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final s in suggestions)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: InitialsAvatar(s.initials, size: 32),
              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(Validators.prettyPhone(s.phone)),
              trailing: const Text('Select', style: TextStyle(color: AppColors.maroon, fontWeight: FontWeight.w600)),
              onTap: () {
                _ctrl.selectCustomer(s);
                _phone.text = s.phone;
                _name.text = s.name;
              },
            ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _searchCustomer,
            icon: const Icon(Icons.manage_search_rounded),
            label: const Text('Find existing customer'),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------- salesperson
  Widget _salespersonSection(BillDraft draft) {
    final people = ref.watch(salespeopleProvider);
    return people.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Could not load staff: $e'),
      data: (list) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final u in list)
            ChoiceChip(
              avatar: CircleAvatar(
                backgroundColor: draft.salespersonId == u.id ? AppColors.gold : AppColors.goldPale,
                child: Text(u.initials,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: draft.salespersonId == u.id ? AppColors.maroon900 : AppColors.maroon)),
              ),
              label: Text(u.fullName),
              selected: draft.salespersonId == u.id,
              showCheckmark: false,
              onSelected: (_) => _ctrl.setSalesperson(u.id),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- items
  Widget _itemsSection(BillDraft draft, BillTotals totals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < draft.items.length; i++)
          Dismissible(
            key: ObjectKey(draft.items[i]),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: AppColors.errorBg, borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            ),
            onDismissed: (_) => _ctrl.removeItem(i),
            child: AppCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              onTap: () => _editItem(i),
              child: Row(
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(draft.items[i].productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        '${draft.items[i].productCode} · ${Money.format(draft.items[i].unitPricePaise)} each',
                        style: const TextStyle(color: AppColors.inkMuted, fontSize: 12.5),
                      ),
                      if (i < totals.lines.length && totals.lines[i].discountPaise > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Pill(
                            draft.items[i].discountType == DiscountType.percent
                                ? '${_num(draft.items[i].discountValue)}% off · -${Money.format(totals.lines[i].discountPaise)}'
                                : '-${Money.format(totals.lines[i].discountPaise)} off',
                            tone: PillTone.success,
                          ),
                        ),
                    ]),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      MoneyText(i < totals.lines.length ? Money.format(totals.lines[i].netPaise) : '—', size: 15.5),
                      const SizedBox(height: 4),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        _miniBtn(Icons.remove_rounded,
                            draft.items[i].quantity > 1 ? () => _ctrl.setQuantity(i, draft.items[i].quantity - 1) : null),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text('${draft.items[i].quantity}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        _miniBtn(Icons.add_rounded, () => _ctrl.setQuantity(i, draft.items[i].quantity + 1)),
                      ]),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.inkSoft),
                    onPressed: () => _ctrl.removeItem(i),
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _addItem,
          icon: const Icon(Icons.add_rounded),
          label: Text(draft.items.isEmpty ? 'Add saree' : 'Add another saree'),
        ),
      ],
    );
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Widget _miniBtn(IconData icon, VoidCallback? onTap) => InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(shape: BoxShape.circle, color: onTap == null ? AppColors.cream : AppColors.maroon100),
          child: Icon(icon, size: 16, color: onTap == null ? AppColors.inkSoft : AppColors.maroon),
        ),
      );

  // ------------------------------------------------------------- payment
  Widget _paymentSection(BillDraft draft, BillTotals totals) {
    final total = totals.totalPaise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<PaymentMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: PaymentMode.cash, label: Text('Cash'), icon: Icon(Icons.payments_outlined, size: 18)),
            ButtonSegment(value: PaymentMode.upi, label: Text('UPI'), icon: Icon(Icons.qr_code_2_rounded, size: 18)),
            ButtonSegment(value: PaymentMode.card, label: Text('Card'), icon: Icon(Icons.credit_card_rounded, size: 18)),
            ButtonSegment(value: PaymentMode.split, label: Text('Split'), icon: Icon(Icons.call_split_rounded, size: 18)),
          ],
          selected: {draft.mode},
          onSelectionChanged: (s) {
            _ctrl.setMode(s.first);
            _reference.clear();
            _cash.clear();
          },
        ),
        const SizedBox(height: 12),
        switch (draft.mode) {
          PaymentMode.cash => _cashFields(draft, total),
          PaymentMode.upi => AppTextField(
              controller: _reference,
              label: 'UPI transaction ID (optional)',
              prefixIcon: Icons.tag_rounded,
              onChanged: _ctrl.setReference,
            ),
          PaymentMode.card => AppTextField(
              controller: _reference,
              label: 'Card last 4 digits (optional)',
              prefixIcon: Icons.credit_card_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              onChanged: (v) => _ctrl.setReference(v.isEmpty ? '' : 'XX$v'),
            ),
          PaymentMode.split => _splitFields(draft, total),
        },
      ],
    );
  }

  Widget _cashFields(BillDraft draft, int total) {
    final received = draft.cashReceivedPaise;
    final change = received == null ? null : received - total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _cash,
          label: 'Cash received (optional)',
          prefixText: '₹ ',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => _ctrl.setCashReceived(Money.parse(v)),
        ),
        if (change != null && total > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              change >= 0 ? 'Return change: ${Money.format(change)}' : 'Short by ${Money.format(-change)}',
              style: TextStyle(fontWeight: FontWeight.w700, color: change >= 0 ? AppColors.success : AppColors.error),
            ),
          ),
      ],
    );
  }

  Widget _splitFields(BillDraft draft, int total) {
    final remaining = total - draft.splitSum();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < draft.splits.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 112,
                  child: AppDropdown<PaymentMethod>(
                    label: 'Method',
                    value: draft.splits[i].method,
                    items: PaymentMethod.values,
                    itemLabel: (m) => m.label,
                    onChanged: (m) {
                      if (m != null) _ctrl.setSplit(i, draft.splits[i].copyWith(method: m));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppTextField(
                    controller: _splitCtrls[i],
                    label: 'Amount',
                    prefixText: '₹ ',
                    dense: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    onChanged: (v) => _ctrl.setSplit(i, draft.splits[i].copyWith(amountPaise: Money.parse(v) ?? 0)),
                    suffixIcon: IconButton(
                      tooltip: 'Fill remaining',
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
                      onPressed: () {
                        _ctrl.fillRemainder(i, total);
                        _splitCtrls[i].text = _plain(ref.read(billDraftProvider).splits[i].amountPaise);
                      },
                    ),
                  ),
                ),
                if (draft.splits.length > 2)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      _splitCtrls.removeAt(i).dispose();
                      _ctrl.removeSplit(i);
                    },
                  ),
              ],
            ),
          ),
        Row(
          children: [
            if (draft.splits.length < 3)
              TextButton.icon(onPressed: _ctrl.addSplit, icon: const Icon(Icons.add_rounded), label: const Text('Add method')),
            const Spacer(),
            Text(
              remaining == 0
                  ? 'Fully allocated'
                  : remaining > 0
                      ? '${Money.format(remaining)} left'
                      : '${Money.format(-remaining)} over',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: remaining == 0 ? AppColors.success : AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.number, required this.title, required this.done});
  final int number;
  final String title;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.maroon : AppColors.card,
            border: Border.all(color: done ? AppColors.maroon : AppColors.goldLight, width: 1.4),
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 16, color: AppColors.ivory)
              : Text('$number', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.maroon, fontSize: 13)),
        ),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
      ]),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totals, required this.gstRate});
  final BillTotals totals;
  final double gstRate;

  @override
  Widget build(BuildContext context) {
    Widget row(String l, int paise, {bool neg = false, bool decimals = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(l, style: const TextStyle(color: AppColors.inkMuted, fontWeight: FontWeight.w500))),
            MoneyText('${neg && paise > 0 ? '-' : ''}${Money.format(paise, decimals: decimals ? true : null)}', size: 14),
          ]),
        );
    final half = gstRate / 2;
    final halfLabel = half == half.roundToDouble() ? half.toStringAsFixed(0) : half.toStringAsFixed(2);
    return AppCard(
      child: Column(children: [
        row('Subtotal', totals.subtotalPaise),
        row('Discount', totals.discountPaise, neg: true),
        row('Taxable value', totals.taxablePaise),
        row('CGST @ $halfLabel%', totals.cgstPaise, decimals: true),
        row('SGST @ $halfLabel%', totals.sgstPaise, decimals: true),
        row('Round off', totals.roundOffPaise, decimals: true),
      ]),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.totalPaise, required this.itemCount, required this.onReview});
  final int totalPaise;
  final int itemCount;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      elevation: 12,
      shadowColor: AppColors.maroon900.withValues(alpha: 0.3),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(itemCount == 0 ? 'No items yet' : '$itemCount saree${itemCount == 1 ? '' : 's'} · incl. GST',
                        style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                    MoneyText(Money.format(totalPaise, decimals: false), size: 24, weight: FontWeight.w700, color: AppColors.maroon),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('Review bill'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerSearchSheet extends ConsumerStatefulWidget {
  const _CustomerSearchSheet();

  @override
  ConsumerState<_CustomerSearchSheet> createState() => _CustomerSearchSheetState();
}

class _CustomerSearchSheetState extends ConsumerState<_CustomerSearchSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final stats = ref.watch(customerStatsProvider).valueOrNull ?? const {};
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: AppTextField(
            hint: 'Search by name or mobile',
            prefixIcon: Icons.search_rounded,
            autofocus: true,
            dense: true,
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: AsyncView<List<Customer>>(
            value: customers,
            builder: (all) {
              final list = all
                  .where((c) => _q.isEmpty || c.name.toLowerCase().contains(_q) || c.phone.contains(_q.replaceAll(' ', '')))
                  .toList();
              if (list.isEmpty) {
                return const EmptyState(icon: Icons.person_search_rounded, title: 'No matching customers');
              }
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final c = list[i];
                  final s = stats[c.id];
                  return ListTile(
                    leading: InitialsAvatar(c.initials, size: 38),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${Validators.prettyPhone(c.phone)}${c.city == null ? '' : ' · ${c.city}'}'),
                    trailing: s == null ? null : Text('${s.purchaseCount} visits', style: const TextStyle(color: AppColors.inkMuted)),
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

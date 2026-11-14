import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/billing_calculator.dart';
import '../../domain/exceptions.dart';
import '../../providers/providers.dart';

/// Opens the add/edit saree sheet. Returns the line, or null if dismissed.
Future<SaleItemInput?> showAddItemSheet(BuildContext context, {SaleItemInput? initial}) {
  return showModalBottomSheet<SaleItemInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(heightFactor: 0.92, child: AddItemSheet(initial: initial)),
  );
}

class AddItemSheet extends ConsumerStatefulWidget {
  const AddItemSheet({super.key, this.initial});
  final SaleItemInput? initial;

  @override
  ConsumerState<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<AddItemSheet> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _price = TextEditingController();
  final _discount = TextEditingController();
  String? _productId;
  int _qty = 1;
  DiscountType _discountType = DiscountType.percent;
  bool _editing = false; // false = choosing from catalogue
  String _query = '';
  String? _category;
  String? _error;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _editing = true;
      _productId = i.productId;
      _name.text = i.productName;
      _code.text = i.productCode;
      _price.text = _plain(i.unitPricePaise);
      _qty = i.quantity;
      _discountType = i.discountType;
      _discount.text = i.discountValue == 0 ? '' : _num(i.discountValue);
    }
  }

  @override
  void dispose() {
    for (final c in [_search, _name, _code, _price, _discount]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _plain(int paise) => paise % 100 == 0 ? '${paise ~/ 100}' : (paise / 100).toStringAsFixed(2);
  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  void _pick(Product p) {
    setState(() {
      _productId = p.id;
      _name.text = p.name;
      _code.text = p.sku;
      _price.text = _plain(p.sellingPricePaise);
      _qty = 1;
      _discount.clear();
      _editing = true;
      _error = null;
    });
  }

  void _manual() {
    setState(() {
      _productId = null;
      _name.clear();
      _code.clear();
      _price.clear();
      _discount.clear();
      _qty = 1;
      _editing = true;
      _error = null;
    });
  }

  SaleItemInput? _build({bool strict = false}) {
    final price = Money.parse(_price.text);
    final discount = _discount.text.trim().isEmpty ? 0.0 : double.tryParse(_discount.text.trim());
    if (strict) {
      if (_name.text.trim().isEmpty) throw const ValidationException('Enter the saree name');
      if (price == null || price <= 0) throw const ValidationException('Enter a valid price');
      if (discount == null) throw const ValidationException('Enter a valid discount');
    }
    if (price == null || discount == null) return null;
    final item = SaleItemInput(
      productId: _productId,
      productName: _name.text.trim(),
      productCode: _code.text.trim().isEmpty ? 'MISC' : _code.text.trim().toUpperCase(),
      quantity: _qty,
      unitPricePaise: price,
      discountType: _discountType,
      discountValue: discount,
    );
    if (strict) BillingCalculator.line(item); // throws on bad discount
    return item;
  }

  void _submit() {
    try {
      Navigator.pop(context, _build(strict: true));
    } on ValidationException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _editing ? _editor(context) : _catalogue(context);
  }

  // ------------------------------------------------------------ catalogue
  Widget _catalogue(BuildContext context) {
    final products = ref.watch(productsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            Expanded(child: Text('Add saree', style: Theme.of(context).textTheme.titleLarge)),
            TextButton.icon(onPressed: _manual, icon: const Icon(Icons.edit_note_rounded), label: const Text('Enter manually')),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppTextField(
            controller: _search,
            hint: 'Search name, SKU or fabric',
            prefixIcon: Icons.search_rounded,
            dense: true,
            autofocus: false,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: AsyncView<List<Product>>(
            value: products,
            builder: (all) {
              final active = all.where((p) => p.isActive).toList();
              final cats = active.map((p) => p.category).toSet().toList()..sort();
              final list = active.where((p) {
                if (_category != null && p.category != _category) return false;
                if (_query.isEmpty) return true;
                return p.name.toLowerCase().contains(_query) ||
                    p.sku.toLowerCase().contains(_query) ||
                    (p.fabric ?? '').toLowerCase().contains(_query) ||
                    (p.color ?? '').toLowerCase().contains(_query);
              }).toList();
              return Column(
                children: [
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('All'),
                            selected: _category == null,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _category = null),
                          ),
                        ),
                        for (final c in cats)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c),
                              selected: _category == c,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _category = _category == c ? null : c),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No sarees found',
                            message: 'Try another search, or enter the item manually.',
                            action: 'Enter manually',
                            onAction: _manual,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16),
                            itemBuilder: (_, i) {
                              final p = list[i];
                              return ListTile(
                                onTap: () => _pick(p),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text('${p.sku} · ${p.category}${p.color == null ? '' : ' · ${p.color}'}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    MoneyText(Money.format(p.sellingPricePaise), size: 14.5),
                                    Text(p.stockQty <= 0 ? 'Out of stock' : '${p.stockQty} in stock',
                                        style: TextStyle(
                                            fontSize: 11.5, color: p.lowStock ? AppColors.warning : AppColors.inkMuted)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- editor
  Widget _editor(BuildContext context) {
    final preview = _build();
    LineAmounts? amounts;
    String? lineError;
    if (preview != null) {
      try {
        amounts = BillingCalculator.line(preview);
      } on ValidationException catch (e) {
        lineError = e.message;
      }
    }
    final isEdit = widget.initial != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 20, 8),
          child: Row(children: [
            if (!isEdit)
              IconButton(
                tooltip: 'Back to catalogue',
                onPressed: () => setState(() => _editing = false),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            else
              const SizedBox(width: 12),
            Expanded(child: Text(isEdit ? 'Edit item' : 'Item details', style: Theme.of(context).textTheme.titleLarge)),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              AppTextField(
                controller: _name,
                label: 'Saree name',
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: AppTextField(
                    controller: _code,
                    label: 'Product code',
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _price,
                    label: 'Unit price',
                    prefixText: '₹ ',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              Text('Quantity', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              _QtyStepper(value: _qty, onChanged: (v) => setState(() => _qty = v)),
              const SizedBox(height: 18),
              Text('Discount', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(children: [
                SegmentedButton<DiscountType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: DiscountType.percent, label: Text('%')),
                    ButtonSegment(value: DiscountType.amount, label: Text('₹')),
                  ],
                  selected: {_discountType},
                  onSelectionChanged: (s) => setState(() => _discountType = s.first),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _discount,
                    hint: _discountType == DiscountType.percent ? 'e.g. 10' : 'e.g. 500',
                    dense: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final v in _discountType == DiscountType.percent ? [5, 10, 15, 20] : [200, 500, 1000])
                  ActionChip(
                    label: Text(_discountType == DiscountType.percent ? '$v%' : '₹$v'),
                    onPressed: () => setState(() => _discount.text = '$v'),
                  ),
              ]),
              const SizedBox(height: 20),
              AppCard(
                color: AppColors.goldPale,
                borderColor: AppColors.goldLight,
                child: Column(children: [
                  _line('Amount', amounts == null ? '—' : Money.format(amounts.grossPaise)),
                  _line('Discount', amounts == null || amounts.discountPaise == 0 ? '—' : '-${Money.format(amounts.discountPaise)}'),
                  const Divider(height: 18),
                  _line('Line total', amounts == null ? '—' : Money.format(amounts.netPaise), strong: true),
                ]),
              ),
              if (lineError != null || _error != null) ...[
                const SizedBox(height: 12),
                Text(_error ?? lineError!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + MediaQuery.viewInsetsOf(context).bottom),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: Icon(isEdit ? Icons.check_rounded : Icons.add_rounded),
                label: Text(isEdit ? 'Update item' : 'Add to bill'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _line(String l, String v, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(l, style: TextStyle(fontWeight: strong ? FontWeight.w700 : FontWeight.w500))),
          MoneyText(v, size: strong ? 17 : 14.5, weight: strong ? FontWeight.w700 : FontWeight.w600,
              color: strong ? AppColors.maroon : null),
        ]),
      );
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, VoidCallback? onTap) => Material(
          color: onTap == null ? AppColors.cream : AppColors.maroon100,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, size: 20, color: onTap == null ? AppColors.inkSoft : AppColors.maroon),
            ),
          ),
        );
    return Row(children: [
      btn(Icons.remove_rounded, value > 1 ? () => onChanged(value - 1) : null),
      SizedBox(width: 56, child: Center(child: MoneyText('$value', size: 20, weight: FontWeight.w700))),
      btn(Icons.add_rounded, value < 99 ? () => onChanged(value + 1) : null),
    ]);
  }
}

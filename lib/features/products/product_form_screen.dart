import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/exceptions.dart';
import '../../providers/providers.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});
  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _fabric = TextEditingController();
  final _color = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '1');
  String _category = Product.categories.first;
  bool _active = true;
  Product? _original;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _sku, _fabric, _color, _desc, _price, _stock]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(Product p) {
    _original = p;
    _name.text = p.name;
    _sku.text = p.sku;
    _fabric.text = p.fabric ?? '';
    _color.text = p.color ?? '';
    _desc.text = p.description ?? '';
    _price.text = p.sellingPricePaise % 100 == 0 ? '${p.sellingPricePaise ~/ 100}' : (p.sellingPricePaise / 100).toStringAsFixed(2);
    _stock.text = '${p.stockQty}';
    _category = Product.categories.contains(p.category) ? p.category : 'Other';
    _active = p.isActive;
  }

  String _suggestSku(List<Product> all) {
    final prefix = _category.replaceAll(' ', '').toUpperCase().substring(0, 3);
    var n = all.where((p) => p.sku.startsWith('$prefix-')).length + 1;
    while (all.any((p) => p.sku == '$prefix-${n.toString().padLeft(3, '0')}')) {
      n++;
    }
    return '$prefix-${n.toString().padLeft(3, '0')}';
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final p = Product(
      id: _original?.id ?? '',
      sku: _sku.text.trim().toUpperCase(),
      name: _name.text.trim(),
      category: _category,
      fabric: _fabric.text.trim(),
      color: _color.text.trim(),
      description: _desc.text.trim(),
      sellingPricePaise: Money.parse(_price.text) ?? 0,
      stockQty: int.tryParse(_stock.text) ?? 0,
      isActive: _active,
    );
    try {
      await ref.read(repositoryProvider).saveProduct(p);
      ref.refreshData();
      if (!mounted) return;
      showSnack(context, _original == null ? 'Saree added to catalogue' : 'Saree updated');
      context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, friendlyError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.productId != null;
    final all = ref.watch(productsProvider).valueOrNull;
    if (editing && !_loaded) {
      final p = all?.where((x) => x.id == widget.productId).firstOrNull;
      if (p == null) return Scaffold(appBar: AppBar(), body: const LoadingView(blocks: 3));
      _load(p);
      _loaded = true;
    }

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit saree' : 'Add saree')),
      body: Form(
        key: _form,
        child: MaxWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              AppTextField(
                controller: _name,
                label: 'Saree name',
                textCapitalization: TextCapitalization.words,
                validator: (v) => Validators.required(v, 'Name'),
              ),
              const SizedBox(height: 12),
              AppDropdown<String>(
                label: 'Category',
                value: _category,
                items: Product.categories,
                onChanged: (v) => setState(() => _category = v ?? 'Other'),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _sku,
                label: 'SKU / product code',
                textCapitalization: TextCapitalization.characters,
                validator: (v) => Validators.required(v, 'SKU'),
                suffixIcon: editing || all == null
                    ? null
                    : TextButton(onPressed: () => setState(() => _sku.text = _suggestSku(all)), child: const Text('Suggest')),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: AppTextField(controller: _fabric, label: 'Fabric', textCapitalization: TextCapitalization.words)),
                const SizedBox(width: 12),
                Expanded(child: AppTextField(controller: _color, label: 'Colour', textCapitalization: TextCapitalization.words)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: AppTextField(
                    controller: _price,
                    label: 'Selling price',
                    prefixText: '₹ ',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    validator: (v) {
                      final p = Money.parse(v ?? '');
                      return p == null || p <= 0 ? 'Enter a valid price' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _stock,
                    label: 'In stock',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))],
                    validator: (v) => int.tryParse(v ?? '') == null ? 'Enter a number' : null,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              AppTextField(controller: _desc, label: 'Description (optional)', maxLines: 3),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: const Text('Available for billing'),
                subtitle: const Text('Turn off to hide discontinued designs from the billing catalogue.'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.ivory))
                    : Text(editing ? 'Save changes' : 'Add to catalogue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

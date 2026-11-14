import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/common.dart';
import '../../data/models/models.dart';
import '../../domain/permissions.dart';
import '../../providers/providers.dart';

/// Saree catalogue.
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key, this.standalone = false});

  /// True when pushed as a page (owner), false inside the manager tabs.
  final bool standalone;

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _q = '';
  String? _category;
  bool _lowStockOnly = false;

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final canEdit = ref.watch(currentUserProvider)?.can(Permission.manageProducts) ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Saree catalogue'), automaticallyImplyLeading: widget.standalone),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              heroTag: 'products-add',
              onPressed: () => context.push('/products/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add saree'),
            )
          : null,
      body: AsyncView<List<Product>>(
        value: products,
        onRetry: () => ref.refreshData(),
        builder: (all) {
          final cats = all.map((p) => p.category).toSet().toList()..sort();
          final list = all.where((p) {
            if (_category != null && p.category != _category) return false;
            if (_lowStockOnly && !p.lowStock) return false;
            if (_q.isEmpty) return true;
            return p.name.toLowerCase().contains(_q) ||
                p.sku.toLowerCase().contains(_q) ||
                (p.fabric ?? '').toLowerCase().contains(_q) ||
                (p.color ?? '').toLowerCase().contains(_q);
          }).toList();
          final stockValue = all.where((p) => p.isActive && p.stockQty > 0).fold<int>(0, (s, p) => s + p.stockQty * p.sellingPricePaise);
          final low = all.where((p) => p.isActive && p.lowStock).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: AppTextField(
                  hint: 'Search name, SKU, fabric or colour',
                  prefixIcon: Icons.search_rounded,
                  dense: true,
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                        label: Text('Low stock ($low)'),
                        selected: _lowStockOnly,
                        onSelected: (v) => setState(() => _lowStockOnly = v),
                      ),
                    ),
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
                        icon: Icons.checkroom_outlined,
                        title: all.isEmpty ? 'No sarees yet' : 'No matches',
                        action: canEdit && all.isEmpty ? 'Add saree' : null,
                        onAction: () => context.push('/products/new'),
                      )
                    : RefreshIndicator(
                        color: AppColors.maroon,
                        onRefresh: () async => ref.refreshData(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount: list.length + 1,
                          itemBuilder: (_, i) {
                            if (i == 0) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                                child: Text('${all.length} designs · stock value ${Money.compact(stockValue)} at selling price',
                                    style: Theme.of(context).textTheme.bodySmall),
                              );
                            }
                            final p = list[i - 1];
                            return AppCard(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                              onTap: canEdit ? () => context.push('/products/${p.id}/edit') : null,
                              child: Row(children: [
                                _Swatch(product: p),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(p.name,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: p.isActive ? AppColors.ink : AppColors.inkSoft),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text('${p.sku} · ${p.category}${p.fabric == null ? '' : ' · ${p.fabric}'}',
                                        style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
                                  ]),
                                ),
                                const SizedBox(width: 8),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  MoneyText(Money.format(p.sellingPricePaise), size: 15),
                                  const SizedBox(height: 4),
                                  if (!p.isActive)
                                    const Pill('Hidden', tone: PillTone.neutral)
                                  else
                                    Pill(
                                      p.stockQty <= 0 ? 'Out of stock' : '${p.stockQty} in stock',
                                      tone: p.stockQty <= 0 ? PillTone.danger : (p.lowStock ? PillTone.warning : PillTone.success),
                                    ),
                                ]),
                              ]),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Coloured monogram tile from the category (no product photos needed).
class _Swatch extends StatelessWidget {
  const _Swatch({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.chart;
    final c = colors[product.category.hashCode.abs() % colors.length];
    return Container(
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c, Color.lerp(c, Colors.black, 0.35)!],
        ),
      ),
      child: Stack(children: [
        const Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: Divider(color: AppColors.goldLight, thickness: 2, height: 2),
        ),
        Center(
          child: Text(
            product.category.substring(0, 1),
            style: const TextStyle(fontFamily: 'Lora', color: AppColors.ivory, fontWeight: FontWeight.w700, fontSize: 20),
          ),
        ),
      ]),
    );
  }
}

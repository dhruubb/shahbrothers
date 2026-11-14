import '../../core/utils/money.dart';

class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.sellingPricePaise,
    this.fabric,
    this.color,
    this.description,
    this.stockQty = 0,
    this.isActive = true,
  });

  final String id;
  final String sku;
  final String name;
  final String category;
  final String? fabric;
  final String? color;
  final String? description;
  final int sellingPricePaise;
  final int stockQty;
  final bool isActive;

  bool get isNew => id.isEmpty;
  bool get lowStock => stockQty <= 2;

  static const categories = [
    'Banarasi',
    'Kanjeevaram',
    'Paithani',
    'Patola',
    'Chanderi',
    'Bandhani',
    'Georgette',
    'Chiffon',
    'Cotton',
    'Linen',
    'Organza',
    'Tussar',
    'Kota Doria',
    'Mysore Silk',
    'Gadwal',
    'Ikat',
    'Designer',
    'Other',
  ];

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String? ?? '',
        sku: j['sku'] as String? ?? '',
        name: j['name'] as String? ?? '',
        category: j['category'] as String? ?? 'Other',
        fabric: j['fabric'] as String?,
        color: j['color'] as String?,
        description: j['description'] as String?,
        sellingPricePaise: Money.toPaise(j['selling_price'] as num?),
        stockQty: (j['stock_qty'] as num?)?.toInt() ?? 0,
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toWriteJson() => {
        'sku': sku.trim().toUpperCase(),
        'name': name.trim(),
        'category': category,
        'fabric': (fabric?.trim().isEmpty ?? true) ? null : fabric!.trim(),
        'color': (color?.trim().isEmpty ?? true) ? null : color!.trim(),
        'description': (description?.trim().isEmpty ?? true) ? null : description!.trim(),
        'selling_price': Money.toRupees(sellingPricePaise),
        'stock_qty': stockQty,
        'is_active': isActive,
      };

  Map<String, dynamic> toJson() => {'id': id, ...toWriteJson()};

  Product copyWith({String? id, int? stockQty}) => Product(
        id: id ?? this.id,
        sku: sku,
        name: name,
        category: category,
        fabric: fabric,
        color: color,
        description: description,
        sellingPricePaise: sellingPricePaise,
        stockQty: stockQty ?? this.stockQty,
        isActive: isActive,
      );
}

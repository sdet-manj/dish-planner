class DishIngredient {
  final int? id;
  final int dishId;
  final int ingredientId;
  final double qtyFor100;
  final String unit;

  // For display (joined data)
  final String? ingredientNameEn;
  final String? ingredientNameKn;
  final String? ingredientCategory; // dinasi, vegetable, dairy

  DishIngredient({
    this.id,
    required this.dishId,
    required this.ingredientId,
    required this.qtyFor100,
    required this.unit,
    this.ingredientNameEn,
    this.ingredientNameKn,
    this.ingredientCategory,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'dishId': dishId,
        'ingredientId': ingredientId,
        'qtyFor100': qtyFor100,
        'unit': unit,
      };

  factory DishIngredient.fromMap(Map<String, dynamic> map) => DishIngredient(
        id: map['id'],
        dishId: map['dishId'],
        ingredientId: map['ingredientId'],
        qtyFor100: (map['qtyFor100'] as num).toDouble(),
        unit: map['unit'],
        ingredientNameEn: map['ingredientNameEn'],
        ingredientNameKn: map['ingredientNameKn'],
        ingredientCategory: map['ingredientCategory'] ?? map['category'],
      );

  double getScaledQty(int people) => qtyFor100 * (people / 100);

  String getDisplayName(String lang) {
    final en = ingredientNameEn ?? '';
    final kn = ingredientNameKn ?? '';
    if (lang == 'EN') return en;
    if (lang == 'KN') return kn;
    return '$en / $kn';
  }

  Map<String, dynamic> toJson() => toMap();
  factory DishIngredient.fromJson(Map<String, dynamic> json) =>
      DishIngredient.fromMap(json);
}


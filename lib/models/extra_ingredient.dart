import 'ingredient.dart';

/// Represents an extra ingredient added directly to the plan (not part of a dish)
class ExtraIngredient {
  final Ingredient ingredient;
  final double qtyFor100;
  final String unit;
  int? overridePeople; // null means use global

  ExtraIngredient({
    required this.ingredient,
    required this.qtyFor100,
    required this.unit,
    this.overridePeople,
  });

  double getScaledQty(int globalPeople) {
    final effectivePeople = overridePeople ?? globalPeople;
    return qtyFor100 * (effectivePeople / 100);
  }

  int getEffectivePeople(int globalPeople) {
    return overridePeople ?? globalPeople;
  }

  bool get hasOverride => overridePeople != null;

  String getDisplayName() {
    return '${ingredient.nameKn} (${ingredient.nameEn})';
  }
}


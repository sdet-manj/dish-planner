import 'ingredient.dart';

/// Represents an extra ingredient added directly to the plan (not part of a dish)
class ExtraIngredient {
  final Ingredient ingredient;
  final double qtyFor100; // NOTE: Despite the name, baseline is 500 people in UI
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
    // Linear scaling from 500-person baseline
    return qtyFor100 * (effectivePeople / 500.0);
  }

  int getEffectivePeople(int globalPeople) {
    return overridePeople ?? globalPeople;
  }

  bool get hasOverride => overridePeople != null;

  String getDisplayName() {
    final nameEn = ingredient.nameEn;
    return nameEn != null && nameEn.isNotEmpty 
        ? '${ingredient.nameKn} ($nameEn)' 
        : ingredient.nameKn;
  }
}


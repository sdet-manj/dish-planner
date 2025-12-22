import 'dish.dart';
import 'dish_ingredient.dart';

class PlanItem {
  final Dish dish;
  final List<DishIngredient> ingredients;
  int? overridePeople; // null means use global

  PlanItem({
    required this.dish,
    required this.ingredients,
    this.overridePeople,
  });

  int getEffectivePeople(int globalPeople) {
    return overridePeople ?? globalPeople;
  }

  bool get hasOverride => overridePeople != null;
}


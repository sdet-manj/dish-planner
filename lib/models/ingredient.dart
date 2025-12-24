/// Ingredient categories
enum IngredientCategory {
  dinasi,    // ದಿನಸಿ - Groceries/Provisions (rice, dal, spices, etc.)
  vegetable, // ತರಕಾರಿ - Vegetables
  dairy,     // ಹಾಲು/ಮೊಸರು - Milk/Curd/Dairy products
}

extension IngredientCategoryExtension on IngredientCategory {
  String get displayName {
    switch (this) {
      case IngredientCategory.dinasi:
        return 'ದಿನಸಿ (Groceries)';
      case IngredientCategory.vegetable:
        return 'ತರಕಾರಿ (Vegetables)';
      case IngredientCategory.dairy:
        return 'ಹಾಲು/ಮೊಸರು (Milk/Curd)';
    }
  }

  String get nameKn {
    switch (this) {
      case IngredientCategory.dinasi:
        return 'ದಿನಸಿ';
      case IngredientCategory.vegetable:
        return 'ತರಕಾರಿ';
      case IngredientCategory.dairy:
        return 'ಹಾಲು/ಮೊಸರು';
    }
  }

  String get nameEn {
    switch (this) {
      case IngredientCategory.dinasi:
        return 'Groceries';
      case IngredientCategory.vegetable:
        return 'Vegetables';
      case IngredientCategory.dairy:
        return 'Milk/Curd';
    }
  }
}

class Ingredient {
  final int? id;
  final String nameEn;
  final String nameKn;
  final String defaultUnit;
  final IngredientCategory category;

  Ingredient({
    this.id,
    required this.nameEn,
    required this.nameKn,
    this.defaultUnit = 'kg',
    this.category = IngredientCategory.dinasi,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nameEn': nameEn,
        'nameKn': nameKn,
        'defaultUnit': defaultUnit,
        'category': category.name,
      };

  factory Ingredient.fromMap(Map<String, dynamic> map) => Ingredient(
        id: map['id'],
        nameEn: map['nameEn'],
        nameKn: map['nameKn'],
        defaultUnit: map['defaultUnit'] ?? 'kg',
        category: _categoryFromString(map['category']),
      );

  static IngredientCategory _categoryFromString(String? value) {
    if (value == null) return IngredientCategory.dinasi;
    switch (value) {
      case 'vegetable':
        return IngredientCategory.vegetable;
      case 'dairy':
        return IngredientCategory.dairy;
      default:
        return IngredientCategory.dinasi;
    }
  }

  Map<String, dynamic> toJson() => toMap();
  factory Ingredient.fromJson(Map<String, dynamic> json) =>
      Ingredient.fromMap(json);

  String getDisplayName(String lang) {
    if (lang == 'EN') return nameEn;
    if (lang == 'KN') return nameKn;
    return '$nameEn / $nameKn';
  }
}


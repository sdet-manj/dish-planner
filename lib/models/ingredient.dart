class Ingredient {
  final int? id;
  final String nameEn;
  final String nameKn;
  final String defaultUnit;

  Ingredient({
    this.id,
    required this.nameEn,
    required this.nameKn,
    this.defaultUnit = 'kg',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nameEn': nameEn,
        'nameKn': nameKn,
        'defaultUnit': defaultUnit,
      };

  factory Ingredient.fromMap(Map<String, dynamic> map) => Ingredient(
        id: map['id'],
        nameEn: map['nameEn'],
        nameKn: map['nameKn'],
        defaultUnit: map['defaultUnit'] ?? 'kg',
      );

  Map<String, dynamic> toJson() => toMap();
  factory Ingredient.fromJson(Map<String, dynamic> json) =>
      Ingredient.fromMap(json);

  String getDisplayName(String lang) {
    if (lang == 'EN') return nameEn;
    if (lang == 'KN') return nameKn;
    return '$nameEn / $nameKn';
  }
}


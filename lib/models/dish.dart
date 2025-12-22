class Dish {
  final int? id;
  final String nameEn;
  final String nameKn;

  Dish({
    this.id,
    required this.nameEn,
    required this.nameKn,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nameEn': nameEn,
        'nameKn': nameKn,
      };

  factory Dish.fromMap(Map<String, dynamic> map) => Dish(
        id: map['id'],
        nameEn: map['nameEn'],
        nameKn: map['nameKn'],
      );

  Map<String, dynamic> toJson() => toMap();
  factory Dish.fromJson(Map<String, dynamic> json) => Dish.fromMap(json);

  String getDisplayName(String lang) {
    if (lang == 'EN') return nameEn;
    if (lang == 'KN') return nameKn;
    return '$nameEn ($nameKn)';
  }
}


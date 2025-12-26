class Dish {
  final int? id;
  final String? nameEn; // Optional - English name
  final String nameKn; // Required - Kannada name
  final String? subCategory; // Optional: e.g., "Hesaru Bele" for Kosambari

  Dish({
    this.id,
    this.nameEn,
    required this.nameKn,
    this.subCategory,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nameEn': nameEn,
        'nameKn': nameKn,
        'subCategory': subCategory,
      };

  factory Dish.fromMap(Map<String, dynamic> map) => Dish(
        id: map['id'],
        nameEn: map['nameEn'],
        nameKn: map['nameKn'],
        subCategory: map['subCategory'],
      );

  Map<String, dynamic> toJson() => toMap();
  factory Dish.fromJson(Map<String, dynamic> json) => Dish.fromMap(json);

  String getDisplayName(String lang) {
    String baseName;
    if (lang == 'EN') {
      baseName = nameEn ?? nameKn;
    } else if (lang == 'KN') {
      baseName = nameKn;
    } else {
      baseName = nameEn != null && nameEn!.isNotEmpty ? '$nameKn ($nameEn)' : nameKn;
    }
    
    if (subCategory != null && subCategory!.isNotEmpty) {
      return '$baseName - $subCategory';
    }
    return baseName;
  }
  
  String getFullDisplayName() {
    final base = nameEn != null && nameEn!.isNotEmpty ? '$nameKn ($nameEn)' : nameKn;
    if (subCategory != null && subCategory!.isNotEmpty) {
      return '$base - $subCategory';
    }
    return base;
  }
}


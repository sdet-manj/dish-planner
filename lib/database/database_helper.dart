import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/ingredient.dart';
import '../models/dish.dart';
import '../models/dish_ingredient.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dish_planner.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nameEn TEXT NOT NULL,
        nameKn TEXT NOT NULL,
        defaultUnit TEXT DEFAULT 'kg'
      )
    ''');

    await db.execute('''
      CREATE TABLE dishes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nameEn TEXT NOT NULL,
        nameKn TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE dish_ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dishId INTEGER NOT NULL,
        ingredientId INTEGER NOT NULL,
        qtyFor100 REAL NOT NULL,
        unit TEXT NOT NULL,
        FOREIGN KEY (dishId) REFERENCES dishes (id) ON DELETE CASCADE,
        FOREIGN KEY (ingredientId) REFERENCES ingredients (id) ON DELETE CASCADE
      )
    ''');

    // Insert default ingredients
    await _insertDefaults(db);
  }

  Future _insertDefaults(Database db) async {
    final defaultIngredients = [
      {'nameEn': 'Rice', 'nameKn': 'ಅಕ್ಕಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Urad dal', 'nameKn': 'ಉದ್ದಿನ ಬೇಳೆ', 'defaultUnit': 'kg'},
      {'nameEn': 'Toor dal', 'nameKn': 'ತೊಗರಿ ಬೇಳೆ', 'defaultUnit': 'kg'},
      {'nameEn': 'Chana dal', 'nameKn': 'ಕಡಲೆ ಬೇಳೆ', 'defaultUnit': 'kg'},
      {'nameEn': 'Moong dal', 'nameKn': 'ಹೆಸರು ಬೇಳೆ', 'defaultUnit': 'kg'},
      {'nameEn': 'Salt', 'nameKn': 'ಉಪ್ಪು', 'defaultUnit': 'kg'},
      {'nameEn': 'Oil', 'nameKn': 'ಎಣ್ಣೆ', 'defaultUnit': 'L'},
      {'nameEn': 'Turmeric', 'nameKn': 'ಅರಿಶಿನ', 'defaultUnit': 'kg'},
      {'nameEn': 'Chilli powder', 'nameKn': 'ಖಾರದ ಪುಡಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Coriander powder', 'nameKn': 'ಕೊತ್ತಂಬರಿ ಪುಡಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Cumin powder', 'nameKn': 'ಜೀರಿಗೆ ಪುಡಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Garam masala', 'nameKn': 'ಗರಂ ಮಸಾಲೆ', 'defaultUnit': 'kg'},
      {'nameEn': 'Mustard seeds', 'nameKn': 'ಸಾಸಿವೆ', 'defaultUnit': 'kg'},
      {'nameEn': 'Cumin seeds', 'nameKn': 'ಜೀರಿಗೆ', 'defaultUnit': 'kg'},
      {'nameEn': 'Coriander leaves', 'nameKn': 'ಕೊತ್ತಂಬರಿ ಸೊಪ್ಪು', 'defaultUnit': 'kg'},
      {'nameEn': 'Onion', 'nameKn': 'ಈರುಳ್ಳಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Tomato', 'nameKn': 'ಟೊಮೆಟೊ', 'defaultUnit': 'kg'},
      {'nameEn': 'Potato', 'nameKn': 'ಆಲೂಗಡ್ಡೆ', 'defaultUnit': 'kg'},
      {'nameEn': 'Carrot', 'nameKn': 'ಗಜ್ಜರಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Beans', 'nameKn': 'ಬೀನ್ಸ್', 'defaultUnit': 'kg'},
      {'nameEn': 'Peas', 'nameKn': 'ಬಟಾಣಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Capsicum', 'nameKn': 'ದೊಣ್ಣೆ ಮೆಣಸಿನಕಾಯಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Brinjal', 'nameKn': 'ಬದನೆಕಾಯಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Drumstick', 'nameKn': 'ನುಗ್ಗೆಕಾಯಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Garlic', 'nameKn': 'ಬೆಳ್ಳುಳ್ಳಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Ginger', 'nameKn': 'ಶುಂಠಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Green chilli', 'nameKn': 'ಹಸಿ ಮೆಣಸಿನಕಾಯಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Ghee', 'nameKn': 'ತುಪ್ಪ', 'defaultUnit': 'kg'},
      {'nameEn': 'Butter', 'nameKn': 'ಬೆಣ್ಣೆ', 'defaultUnit': 'kg'},
      {'nameEn': 'Sugar', 'nameKn': 'ಸಕ್ಕರೆ', 'defaultUnit': 'kg'},
      {'nameEn': 'Jaggery', 'nameKn': 'ಬೆಲ್ಲ', 'defaultUnit': 'kg'},
      {'nameEn': 'Tamarind', 'nameKn': 'ಹುಣಸೆಹಣ್ಣು', 'defaultUnit': 'kg'},
      {'nameEn': 'Coconut', 'nameKn': 'ತೆಂಗಿನಕಾಯಿ', 'defaultUnit': 'pcs'},
      {'nameEn': 'Coconut milk', 'nameKn': 'ತೆಂಗಿನ ಹಾಲು', 'defaultUnit': 'L'},
      {'nameEn': 'Curry leaves', 'nameKn': 'ಕರಿಬೇವು', 'defaultUnit': 'kg'},
      {'nameEn': 'Fenugreek seeds', 'nameKn': 'ಮೆಂತ್ಯ', 'defaultUnit': 'kg'},
      {'nameEn': 'Asafoetida', 'nameKn': 'ಇಂಗು', 'defaultUnit': 'kg'},
      {'nameEn': 'Bay leaves', 'nameKn': 'ಬಿರಿಯಾನಿ ಎಲೆ', 'defaultUnit': 'kg'},
      {'nameEn': 'Cinnamon', 'nameKn': 'ದಾಲ್ಚಿನಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Cardamom', 'nameKn': 'ಏಲಕ್ಕಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Cloves', 'nameKn': 'ಲವಂಗ', 'defaultUnit': 'kg'},
      {'nameEn': 'Black pepper', 'nameKn': 'ಕಾಳು ಮೆಣಸು', 'defaultUnit': 'kg'},
      {'nameEn': 'Milk', 'nameKn': 'ಹಾಲು', 'defaultUnit': 'L'},
      {'nameEn': 'Curd', 'nameKn': 'ಮೊಸರು', 'defaultUnit': 'kg'},
      {'nameEn': 'Paneer', 'nameKn': 'ಪನೀರ್', 'defaultUnit': 'kg'},
      {'nameEn': 'Cashew', 'nameKn': 'ಗೋಡಂಬಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Raisins', 'nameKn': 'ಒಣ ದ್ರಾಕ್ಷಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Almonds', 'nameKn': 'ಬಾದಾಮಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Saffron', 'nameKn': 'ಕೇಸರಿ', 'defaultUnit': 'g'},
      {'nameEn': 'Wheat flour', 'nameKn': 'ಗೋಧಿ ಹಿಟ್ಟು', 'defaultUnit': 'kg'},
      {'nameEn': 'Besan', 'nameKn': 'ಕಡಲೆ ಹಿಟ್ಟು', 'defaultUnit': 'kg'},
      {'nameEn': 'Rava', 'nameKn': 'ರವೆ', 'defaultUnit': 'kg'},
      {'nameEn': 'Poha', 'nameKn': 'ಅವಲಕ್ಕಿ', 'defaultUnit': 'kg'},
      {'nameEn': 'Vermicelli', 'nameKn': 'ಶಾವಿಗೆ', 'defaultUnit': 'kg'},
      {'nameEn': 'Lemon', 'nameKn': 'ನಿಂಬೆಹಣ್ಣು', 'defaultUnit': 'pcs'},
      {'nameEn': 'Mint leaves', 'nameKn': 'ಪುದೀನ ಸೊಪ್ಪು', 'defaultUnit': 'kg'},
    ];
    for (var ing in defaultIngredients) {
      await db.insert('ingredients', ing);
    }
  }

  // ============ INGREDIENT CRUD ============
  Future<int> insertIngredient(Ingredient ing) async {
    final db = await database;
    return await db.insert('ingredients', ing.toMap());
  }

  Future<List<Ingredient>> getAllIngredients() async {
    final db = await database;
    final result = await db.query('ingredients', orderBy: 'nameEn ASC');
    return result.map((e) => Ingredient.fromMap(e)).toList();
  }

  Future<Ingredient?> getIngredientById(int id) async {
    final db = await database;
    final result = await db.query('ingredients', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Ingredient.fromMap(result.first);
  }

  Future<int> updateIngredient(Ingredient ing) async {
    final db = await database;
    return await db.update('ingredients', ing.toMap(),
        where: 'id = ?', whereArgs: [ing.id]);
  }

  Future<int> deleteIngredient(int id) async {
    final db = await database;
    return await db.delete('ingredients', where: 'id = ?', whereArgs: [id]);
  }

  // ============ DISH CRUD ============
  Future<int> insertDish(Dish dish) async {
    final db = await database;
    return await db.insert('dishes', dish.toMap());
  }

  Future<List<Dish>> getAllDishes() async {
    final db = await database;
    final result = await db.query('dishes', orderBy: 'nameEn ASC');
    return result.map((e) => Dish.fromMap(e)).toList();
  }

  Future<Dish?> getDishById(int id) async {
    final db = await database;
    final result = await db.query('dishes', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Dish.fromMap(result.first);
  }

  Future<int> updateDish(Dish dish) async {
    final db = await database;
    return await db.update('dishes', dish.toMap(),
        where: 'id = ?', whereArgs: [dish.id]);
  }

  Future<int> deleteDish(int id) async {
    final db = await database;
    await db.delete('dish_ingredients', where: 'dishId = ?', whereArgs: [id]);
    return await db.delete('dishes', where: 'id = ?', whereArgs: [id]);
  }

  // ============ DISH INGREDIENTS ============
  Future<int> insertDishIngredient(DishIngredient di) async {
    final db = await database;
    return await db.insert('dish_ingredients', di.toMap());
  }

  Future<List<DishIngredient>> getDishIngredients(int dishId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT di.*, i.nameEn as ingredientNameEn, i.nameKn as ingredientNameKn
      FROM dish_ingredients di
      JOIN ingredients i ON di.ingredientId = i.id
      WHERE di.dishId = ?
      ORDER BY i.nameEn ASC
    ''', [dishId]);
    return result.map((e) => DishIngredient.fromMap(e)).toList();
  }

  Future<int> updateDishIngredient(DishIngredient di) async {
    final db = await database;
    return await db.update('dish_ingredients', di.toMap(),
        where: 'id = ?', whereArgs: [di.id]);
  }

  Future<int> deleteDishIngredient(int id) async {
    final db = await database;
    return await db.delete('dish_ingredients', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearDishIngredients(int dishId) async {
    final db = await database;
    await db.delete('dish_ingredients', where: 'dishId = ?', whereArgs: [dishId]);
  }

  Future<void> saveDishIngredients(int dishId, List<DishIngredient> ingredients) async {
    final db = await database;
    await db.delete('dish_ingredients', where: 'dishId = ?', whereArgs: [dishId]);
    for (var di in ingredients) {
      await db.insert('dish_ingredients', {
        'dishId': dishId,
        'ingredientId': di.ingredientId,
        'qtyFor100': di.qtyFor100,
        'unit': di.unit,
      });
    }
  }

  Future<int> getDishIngredientCount(int dishId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM dish_ingredients WHERE dishId = ?',
        [dishId]);
    return result.first['count'] as int;
  }

  // ============ BACKUP / RESTORE ============
  Future<Map<String, dynamic>> exportAll() async {
    final ingredients = await getAllIngredients();
    final dishes = await getAllDishes();
    final db = await database;
    final diResult = await db.query('dish_ingredients');
    final dishIngredients =
        diResult.map((e) => DishIngredient.fromMap(e)).toList();

    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'dishes': dishes.map((e) => e.toJson()).toList(),
      'dishIngredients': dishIngredients.map((e) => e.toJson()).toList(),
    };
  }

  Future<void> importAll(Map<String, dynamic> data) async {
    final db = await database;
    await db.delete('dish_ingredients');
    await db.delete('dishes');
    await db.delete('ingredients');

    for (var ing in (data['ingredients'] as List)) {
      await db.insert('ingredients', Ingredient.fromJson(Map<String, dynamic>.from(ing)).toMap());
    }
    for (var dish in (data['dishes'] as List)) {
      await db.insert('dishes', Dish.fromJson(Map<String, dynamic>.from(dish)).toMap());
    }
    for (var di in (data['dishIngredients'] as List)) {
      await db.insert('dish_ingredients', DishIngredient.fromJson(Map<String, dynamic>.from(di)).toMap());
    }
  }
}


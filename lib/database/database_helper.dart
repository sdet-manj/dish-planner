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
    return await openDatabase(
      path, 
      version: 4, 
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add category column to ingredients table
      await db.execute('ALTER TABLE ingredients ADD COLUMN category TEXT DEFAULT "dinasi"');
      // Update existing ingredients with appropriate categories
      await _updateExistingCategories(db);
    }
    if (oldVersion < 3) {
      // Add subCategory column to dishes table
      await db.execute('ALTER TABLE dishes ADD COLUMN subCategory TEXT');
    }
    if (oldVersion < 4) {
      // Note: SQLite doesn't support ALTER COLUMN to make nullable
      // Existing data already has nameEn, so we just update model to allow null
      // New inserts can have null nameEn
    }
  }

  Future _updateExistingCategories(Database db) async {
    // Update vegetables (NOT including Onion and Garlic - they go to dinasi/groceries)
    final vegetables = ['Tomato', 'Potato', 'Carrot', 'Beans', 'Peas', 
                        'Capsicum', 'Brinjal', 'Drumstick', 'Ginger', 
                        'Green chilli', 'Coriander leaves', 'Curry leaves', 'Mint leaves', 'Lemon'];
    for (var veg in vegetables) {
      await db.execute('UPDATE ingredients SET category = ? WHERE nameEn = ?', ['vegetable', veg]);
    }
    
    // Update dairy - only Milk and Curd
    final dairy = ['Milk', 'Curd'];
    for (var d in dairy) {
      await db.execute('UPDATE ingredients SET category = ? WHERE nameEn = ?', ['dairy', d]);
    }
    
    // Ensure Onion, Garlic, Paneer, Ghee, Butter are in dinasi (groceries)
    final groceries = ['Onion', 'Garlic', 'Paneer', 'Ghee', 'Butter'];
    for (var g in groceries) {
      await db.execute('UPDATE ingredients SET category = ? WHERE nameEn = ?', ['dinasi', g]);
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nameEn TEXT,
        nameKn TEXT NOT NULL,
        defaultUnit TEXT DEFAULT 'kg',
        category TEXT DEFAULT 'dinasi'
      )
    ''');

    await db.execute('''
      CREATE TABLE dishes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nameEn TEXT,
        nameKn TEXT NOT NULL,
        subCategory TEXT
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
      // DINASI - Groceries/Provisions
      {'nameEn': 'Rice', 'nameKn': 'ಅಕ್ಕಿ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Urad dal', 'nameKn': 'ಉದ್ದಿನ ಬೇಳೆ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Toor dal', 'nameKn': 'ತೊಗರಿ ಬೇಳೆ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Chana dal', 'nameKn': 'ಕಡಲೆ ಬೇಳೆ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Moong dal', 'nameKn': 'ಹೆಸರು ಬೇಳೆ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Salt', 'nameKn': 'ಉಪ್ಪು', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Oil', 'nameKn': 'ಎಣ್ಣೆ', 'defaultUnit': 'L', 'category': 'dinasi'},
      {'nameEn': 'Turmeric', 'nameKn': 'ಅರಿಶಿನ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Chilli powder', 'nameKn': 'ಖಾರದ ಪುಡಿ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Coriander powder', 'nameKn': 'ಕೊತ್ತಂಬರಿ ಪುಡಿ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Cumin powder', 'nameKn': 'ಜೀರಿಗೆ ಪುಡಿ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Garam masala', 'nameKn': 'ಗರಂ ಮಸಾಲೆ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Mustard seeds', 'nameKn': 'ಸಾಸಿವೆ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Cumin seeds', 'nameKn': 'ಜೀರಿಗೆ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Sugar', 'nameKn': 'ಸಕ್ಕರೆ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Jaggery', 'nameKn': 'ಬೆಲ್ಲ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Tamarind', 'nameKn': 'ಹುಣಸೆಹಣ್ಣು', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Coconut', 'nameKn': 'ತೆಂಗಿನಕಾಯಿ', 'defaultUnit': 'pcs', 'category': 'dinasi'},
      {'nameEn': 'Coconut milk', 'nameKn': 'ತೆಂಗಿನ ಹಾಲು', 'defaultUnit': 'L', 'category': 'dinasi'},
      {'nameEn': 'Fenugreek seeds', 'nameKn': 'ಮೆಂತ್ಯ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Asafoetida', 'nameKn': 'ಇಂಗು', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Bay leaves', 'nameKn': 'ಬಿರಿಯಾನಿ ಎಲೆ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Cinnamon', 'nameKn': 'ದಾಲ್ಚಿನಿ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Cardamom', 'nameKn': 'ಏಲಕ್ಕಿ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Cloves', 'nameKn': 'ಲವಂಗ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Black pepper', 'nameKn': 'ಕಾಳು ಮೆಣಸು', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Cashew', 'nameKn': 'ಗೋಡಂಬಿ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Raisins', 'nameKn': 'ಒಣ ದ್ರಾಕ್ಷಿ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Almonds', 'nameKn': 'ಬಾದಾಮಿ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Saffron', 'nameKn': 'ಕೇಸರಿ', 'defaultUnit': 'g', 'category': 'dinasi'},
      {'nameEn': 'Wheat flour', 'nameKn': 'ಗೋಧಿ ಹಿಟ್ಟು', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Besan', 'nameKn': 'ಕಡಲೆ ಹಿಟ್ಟು', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Rava', 'nameKn': 'ರವೆ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Poha', 'nameKn': 'ಅವಲಕ್ಕಿ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Vermicelli', 'nameKn': 'ಶಾವಿಗೆ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      
      // GROCERIES - Onion, Garlic, Paneer, Ghee, Butter moved here
      {'nameEn': 'Onion', 'nameKn': 'ಈರುಳ್ಳಿ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Garlic', 'nameKn': 'ಬೆಳ್ಳುಳ್ಳಿ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Paneer', 'nameKn': 'ಪನೀರ್', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Ghee', 'nameKn': 'ತುಪ್ಪ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      {'nameEn': 'Butter', 'nameKn': 'ಬೆಣ್ಣೆ', 'defaultUnit': 'kg', 'category': 'dinasi'},
      
      // VEGETABLES
      {'nameEn': 'Tomato', 'nameKn': 'ಟೊಮೆಟೊ', 'defaultUnit': 'kg', 'category': 'vegetable'},
      {'nameEn': 'Potato', 'nameKn': 'ಆಲೂಗಡ್ಡೆ', 'defaultUnit': 'kg', 'category': 'vegetable'},
      {'nameEn': 'Carrot', 'nameKn': 'ಗಜ್ಜರಿ', 'defaultUnit': 'kg', 'category': 'vegetable'},
      {'nameEn': 'Beans', 'nameKn': 'ಬೀನ್ಸ್', 'defaultUnit': 'kg', 'category': 'vegetable'},
      {'nameEn': 'Peas', 'nameKn': 'ಬಟಾಣಿ', 'defaultUnit': 'kg', 'category': 'vegetable'},
      {'nameEn': 'Capsicum', 'nameKn': 'ದೊಣ್ಣೆ ಮೆಣಸಿನಕಾಯಿ', 'defaultUnit': 'kg', 'category': 'vegetable'},
      {'nameEn': 'Brinjal', 'nameKn': 'ಬದನೆಕಾಯಿ', 'defaultUnit': 'kg', 'category': 'vegetable'},
      {'nameEn': 'Drumstick', 'nameKn': 'ನುಗ್ಗೆಕಾಯಿ', 'defaultUnit': 'kg', 'category': 'vegetable'},
      {'nameEn': 'Ginger', 'nameKn': 'ಶುಂಠಿ', 'defaultUnit': 'kg', 'category': 'vegetable'},
      {'nameEn': 'Green chilli', 'nameKn': 'ಹಸಿ ಮೆಣಸಿನಕಾಯಿ', 'defaultUnit': 'kg', 'category': 'vegetable'},
      {'nameEn': 'Coriander leaves', 'nameKn': 'ಕೊತ್ತಂಬರಿ ಸೊಪ್ಪು', 'defaultUnit': 'kg', 'category': 'vegetable'},
      {'nameEn': 'Curry leaves', 'nameKn': 'ಕರಿಬೇವು', 'defaultUnit': 'kg', 'category': 'vegetable'},
      {'nameEn': 'Mint leaves', 'nameKn': 'ಪುದೀನ ಸೊಪ್ಪು', 'defaultUnit': 'kg', 'category': 'vegetable'},
      {'nameEn': 'Lemon', 'nameKn': 'ನಿಂಬೆಹಣ್ಣು', 'defaultUnit': 'pcs', 'category': 'vegetable'},
      
      // DAIRY - Only Milk and Curd
      {'nameEn': 'Milk', 'nameKn': 'ಹಾಲು', 'defaultUnit': 'L', 'category': 'dairy'},
      {'nameEn': 'Curd', 'nameKn': 'ಮೊಸರು', 'defaultUnit': 'kg', 'category': 'dairy'},
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
      SELECT di.*, i.nameEn as ingredientNameEn, i.nameKn as ingredientNameKn, i.category as ingredientCategory
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


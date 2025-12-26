import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/dish.dart';
import '../models/ingredient.dart';
import '../models/plan_item.dart';
import '../models/extra_ingredient.dart';
import 'masters_screen.dart';
import 'create_dish_screen.dart';
import 'preview_screen.dart';
import 'dishes_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  List<Dish> _allDishes = [];
  List<Ingredient> _allIngredients = [];
  List<PlanItem> _planItems = [];
  List<ExtraIngredient> _extraIngredients = [];
  int _globalPeople = 100;
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;

  // Controllers for text fields
  late TextEditingController _globalPeopleController;
  final Map<int, TextEditingController> _overrideControllers = {};
  final Map<int, TextEditingController> _extraOverrideControllers = {};

  @override
  void initState() {
    super.initState();
    _globalPeopleController = TextEditingController(text: _globalPeople.toString());
    _loadData();
  }

  @override
  void dispose() {
    _globalPeopleController.dispose();
    for (var controller in _overrideControllers.values) {
      controller.dispose();
    }
    for (var controller in _extraOverrideControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final dishes = await _db.getAllDishes();
    final ingredients = await _db.getAllIngredients();
    setState(() {
      _allDishes = dishes;
      _allIngredients = ingredients;
      _loading = false;
    });
  }

  TextEditingController _getOverrideController(int index, int? value) {
    if (!_overrideControllers.containsKey(index)) {
      _overrideControllers[index] = TextEditingController(text: value?.toString() ?? '');
    }
    return _overrideControllers[index]!;
  }

  TextEditingController _getExtraOverrideController(int index, int? value) {
    if (!_extraOverrideControllers.containsKey(index)) {
      _extraOverrideControllers[index] = TextEditingController(text: value?.toString() ?? '');
    }
    return _extraOverrideControllers[index]!;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _addDishesToPlan() async {
    final availableDishes = _allDishes
        .where((d) => !_planItems.any((p) => p.dish.id == d.id))
        .toList();

    if (availableDishes.isEmpty && _allDishes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No dishes available. Create one first.')),
      );
      return;
    }

    if (availableDishes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All dishes are already in the plan')),
      );
      return;
    }

    final selectedDishes = await showModalBottomSheet<List<Dish>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MultiDishPicker(
        dishes: availableDishes,
        onCreateNew: () async {
          Navigator.pop(context);
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateDishScreen()),
          );
          if (result == true) {
            await _loadData();
          }
        },
      ),
    );

    if (selectedDishes != null && selectedDishes.isNotEmpty) {
      for (var dish in selectedDishes) {
        final ingredients = await _db.getDishIngredients(dish.id!);
        if (ingredients.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${dish.nameEn} has no ingredients. Skipped.')),
          );
          continue;
        }
        setState(() {
          _planItems.add(PlanItem(dish: dish, ingredients: ingredients));
        });
      }
    }
  }

  Future<void> _addExtraIngredients() async {
    _allIngredients = await _db.getAllIngredients();

    if (!mounted) return;

    if (_allIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ingredients available. Add one first.')),
      );
      return;
    }

    final result = await showModalBottomSheet<List<ExtraIngredient>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ExtraIngredientPicker(
        ingredients: _allIngredients,
        existingExtras: _extraIngredients,
        onCreateNew: () async {
          Navigator.pop(context);
          _showAddIngredientDialog();
        },
      ),
    );

    if (result != null) {
      setState(() {
        // Replace entire list with the result (handles both add and remove)
        _extraIngredients.clear();
        _extraIngredients.addAll(result);
        _extraOverrideControllers.clear();
      });
    }
  }

  void _removeDish(int index) {
    setState(() {
      _overrideControllers.remove(index);
      _planItems.removeAt(index);
    });
  }

  void _removeExtraIngredient(int index) {
    setState(() {
      _extraOverrideControllers.remove(index);
      _extraIngredients.removeAt(index);
    });
  }

  void _toggleOverride(int index) {
    setState(() {
      if (_planItems[index].overridePeople != null) {
        _planItems[index].overridePeople = null;
        _overrideControllers[index]?.text = '';
      } else {
        _planItems[index].overridePeople = _globalPeople;
        _overrideControllers[index]?.text = _globalPeople.toString();
      }
    });
  }

  void _toggleExtraOverride(int index) {
    setState(() {
      if (_extraIngredients[index].overridePeople != null) {
        _extraIngredients[index].overridePeople = null;
        _extraOverrideControllers[index]?.text = '';
      } else {
        _extraIngredients[index].overridePeople = _globalPeople;
        _extraOverrideControllers[index]?.text = _globalPeople.toString();
      }
    });
  }

  void _setOverridePeople(int index, int people) {
    setState(() {
      _planItems[index].overridePeople = people;
    });
  }

  void _setExtraOverridePeople(int index, int people) {
    setState(() {
      _extraIngredients[index].overridePeople = people;
    });
  }

  // Button 1: Dishes List Preview (just dish names)
  void _goToDishesPreview() {
    if (_planItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one dish')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DishesPreviewScreen(
          planItems: _planItems,
          globalPeople: _globalPeople,
          selectedDate: _selectedDate,
        ),
      ),
    );
  }

  // Button 2: Ingredients List Preview (dish-wise & overall)
  void _goToIngredientsPreview() {
    if (_planItems.isEmpty && _extraIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one dish or ingredient')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          planItems: _planItems,
          extraIngredients: _extraIngredients,
          globalPeople: _globalPeople,
          selectedDate: _selectedDate,
        ),
      ),
    );
  }

  String _getDisplayName(String nameKn, String? nameEn) {
    return nameEn != null && nameEn.isNotEmpty ? '$nameKn ($nameEn)' : nameKn;
  }

  void _showAddIngredientDialog() {
    final enController = TextEditingController();
    final knController = TextEditingController();
    String unit = 'kg';
    IngredientCategory category = IngredientCategory.dinasi;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Ingredient\nಹೊಸ ದಿನಸಿ ಸೇರಿಸಿ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: knController,
                  decoration: const InputDecoration(
                    labelText: 'Name (ಕನ್ನಡ) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: enController,
                  decoration: const InputDecoration(
                    labelText: 'Name (English) - Optional',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<IngredientCategory>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Category (ವರ್ಗ)',
                    border: OutlineInputBorder(),
                  ),
                  items: IngredientCategory.values
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(c.displayName)))
                      .toList(),
                  onChanged: (v) {
                    setDialogState(() => category = v ?? IngredientCategory.dinasi);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: unit,
                  decoration: const InputDecoration(
                    labelText: 'Default Unit',
                    border: OutlineInputBorder(),
                  ),
                  items: ['kg', 'g', 'L', 'ml', 'pcs']
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) {
                    setDialogState(() => unit = v ?? 'kg');
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (knController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill Kannada name')),
                  );
                  return;
                }
                final nameEn = enController.text.trim();
                await _db.insertIngredient(Ingredient(
                  nameEn: nameEn.isNotEmpty ? nameEn : null,
                  nameKn: knController.text.trim(),
                  defaultUnit: unit,
                  category: category,
                ));
                Navigator.pop(context);
                await _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingredient added')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDishDialog() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateDishScreen()),
    );
    if (result == true) {
      await _loadData();
    }
  }

  String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final hasItems = _planItems.isNotEmpty || _extraIngredients.isNotEmpty;
    final dateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'ॐ',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MastersScreen()),
              );
              _loadData();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.teal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Text(
                    'ॐ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'ITEM LIST\nಅಡುಗೆ ಪಟ್ಟಿ',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu, color: Colors.teal),
              title: const Text('Add New Dish'),
              subtitle: const Text('ಹೊಸ ಡಿಶ್ ಸೇರಿಸಿ'),
              onTap: () {
                Navigator.pop(context);
                _showAddDishDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_shopping_cart, color: Colors.orange),
              title: const Text('Add New Ingredient'),
              subtitle: const Text('ಹೊಸ ದಿನಸಿ ಸೇರಿಸಿ'),
              onTap: () {
                Navigator.pop(context);
                _showAddIngredientDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.library_books, color: Colors.purple),
              title: const Text('Masters'),
              subtitle: const Text('Dishes & Ingredients List'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MastersScreen()),
                );
                _loadData();
              },
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Title section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: Colors.teal.shade50,
                  child: const Column(
                    children: [
                      Text(
                        'ITEM LIST',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      Text(
                        'ಅಡುಗೆ ಪಟ್ಟಿ',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
                // Input fields section
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Number of People
                      Row(
                        children: [
                          const Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('No. of People:',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                Text('(ಜನ)', style: TextStyle(fontSize: 14, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              controller: _globalPeopleController,
                              onChanged: (v) {
                                final val = int.tryParse(v);
                                if (val != null && val > 0) {
                                  setState(() => _globalPeople = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Date
                      Row(
                        children: [
                          const Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Date:',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                Text('(ದಿನಾಂಕ)', style: TextStyle(fontSize: 14, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: InkWell(
                              onTap: _selectDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  dateStr,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Select Dishes
                      InkWell(
                        onTap: _addDishesToPlan,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.teal),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.teal.shade50,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Select Dishes:',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    _planItems.isEmpty
                                        ? '(ITEM LIST)'
                                        : '${_planItems.length} dish${_planItems.length > 1 ? 'es' : ''} selected',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              const Icon(Icons.arrow_drop_down, color: Colors.teal, size: 30),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Add Extra Ingredients button
                      InkWell(
                        onTap: _addExtraIngredients,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.orange.shade50,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Add Extra Ingredients',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    _extraIngredients.isEmpty
                                        ? 'ಹೆಚ್ಚುವರಿ ದಿನಸಿ'
                                        : '${_extraIngredients.length} item${_extraIngredients.length > 1 ? 's' : ''} added',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              const Icon(Icons.add_circle_outline, color: Colors.orange, size: 28),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Selected items list
                Expanded(
                  child: !hasItems
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.restaurant_menu, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                'Select dishes or add ingredients',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            // Dishes section
                            if (_planItems.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Selected Dishes:',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                                ),
                              ),
                              ...List.generate(_planItems.length, (index) {
                                final item = _planItems[index];
                                final effectivePeople = item.getEffectivePeople(_globalPeople);
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    dense: true,
                                    title: Text(
                                      item.dish.getFullDisplayName(),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    subtitle: Text('For $effectivePeople people'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.close, size: 20),
                                      onPressed: () => _removeDish(index),
                                    ),
                                    onTap: () => _toggleOverride(index),
                                  ),
                                );
                              }),
                            ],
                            // Extra ingredients section
                            if (_extraIngredients.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'Extra Ingredients:',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                                ),
                              ),
                              ...List.generate(_extraIngredients.length, (index) {
                                final extra = _extraIngredients[index];
                                final scaledQty = extra.getScaledQty(_globalPeople);
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: Colors.orange.shade50,
                                  child: ListTile(
                                    dense: true,
                                    title: Text(
                                      extra.getDisplayName(),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    subtitle: Text('${_formatQty(scaledQty)} ${extra.unit}'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.close, size: 20),
                                      onPressed: () => _removeExtraIngredient(index),
                                    ),
                                  ),
                                );
                              }),
                            ],
                            const SizedBox(height: 100),
                          ],
                        ),
                ),
                // Bottom buttons - Two separate PDF options
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Button 1: Dishes List PDF
                      Expanded(
                        child: ElevatedButton(
                          onPressed: hasItems ? _goToDishesPreview : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.restaurant_menu),
                              SizedBox(height: 4),
                              Text('ITEM LIST PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('ಅಡುಗೆ ಪಟ್ಟಿ', style: TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Button 2: Ingredients List PDF
                      Expanded(
                        child: ElevatedButton(
                          onPressed: hasItems ? _goToIngredientsPreview : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.list_alt),
                              SizedBox(height: 4),
                              Text('Ingredients', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('ಸಾಮಾನು ಪಟ್ಟಿ', style: TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// Multi-select dish picker
class _MultiDishPicker extends StatefulWidget {
  final List<Dish> dishes;
  final VoidCallback onCreateNew;

  const _MultiDishPicker({
    required this.dishes,
    required this.onCreateNew,
  });

  @override
  State<_MultiDishPicker> createState() => _MultiDishPickerState();
}

class _MultiDishPickerState extends State<_MultiDishPicker> {
  final Set<int> _selectedIds = {};

  String _getDisplayName(String nameKn, String? nameEn) {
    return nameEn != null && nameEn.isNotEmpty ? '$nameKn ($nameEn)' : nameKn;
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds.addAll(widget.dishes.map((d) => d.id!));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Dishes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('ಡಿಶ್ ಆಯ್ಕೆಮಾಡಿ', style: TextStyle(color: Colors.grey)),
                  ],
                ),
                TextButton.icon(
                  onPressed: widget.onCreateNew,
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                TextButton(
                  onPressed: _selectAll,
                  child: const Text('Select All'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _deselectAll,
                  child: const Text('Deselect All'),
                ),
                const Spacer(),
                Text('${_selectedIds.length} selected',
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: widget.dishes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('No dishes available',
                            style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: widget.onCreateNew,
                          child: const Text('Create a dish'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    itemCount: widget.dishes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final dish = widget.dishes[index];
                      final isSelected = _selectedIds.contains(dish.id);
                      return ListTile(
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(dish.id!),
                          activeColor: Colors.teal,
                        ),
                        title: Text(dish.getFullDisplayName()),
                        onTap: () => _toggleSelection(dish.id!),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedIds.isEmpty
                    ? null
                    : () {
                        final selected = widget.dishes
                            .where((d) => _selectedIds.contains(d.id))
                            .toList();
                        Navigator.pop(context, selected);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _selectedIds.isEmpty
                      ? 'Select dishes to add'
                      : 'Add ${_selectedIds.length} dish${_selectedIds.length > 1 ? 'es' : ''}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extra ingredient picker
class _ExtraIngredientPicker extends StatefulWidget {
  final List<Ingredient> ingredients;
  final List<ExtraIngredient> existingExtras;
  final VoidCallback onCreateNew;

  const _ExtraIngredientPicker({
    required this.ingredients,
    required this.existingExtras,
    required this.onCreateNew,
  });

  @override
  State<_ExtraIngredientPicker> createState() => _ExtraIngredientPickerState();
}

class _ExtraIngredientPickerState extends State<_ExtraIngredientPicker> {
  final Map<int, _IngredientSelection> _selections = {};
  final Map<int, TextEditingController> _qtyControllers = {};

  @override
  void initState() {
    super.initState();
    for (var extra in widget.existingExtras) {
      _selections[extra.ingredient.id!] = _IngredientSelection(
        ingredient: extra.ingredient,
        qty: extra.qtyFor100,
        unit: extra.unit,
      );
      _qtyControllers[extra.ingredient.id!] = TextEditingController(
        text: extra.qtyFor100.toString(),
      );
    }
  }

  @override
  void dispose() {
    for (var controller in _qtyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _getDisplayName(String nameKn, String? nameEn) {
    return nameEn != null && nameEn.isNotEmpty ? '$nameKn ($nameEn)' : nameKn;
  }

  void _toggleSelection(Ingredient ingredient) {
    setState(() {
      if (_selections.containsKey(ingredient.id)) {
        _selections.remove(ingredient.id);
        _qtyControllers[ingredient.id]?.dispose();
        _qtyControllers.remove(ingredient.id);
      } else {
        _selections[ingredient.id!] = _IngredientSelection(
          ingredient: ingredient,
          qty: 1,
          unit: ingredient.defaultUnit,
        );
        _qtyControllers[ingredient.id!] = TextEditingController(text: '1');
      }
    });
  }

  void _updateQty(int id, double qty) {
    if (_selections.containsKey(id)) {
      setState(() {
        _selections[id]!.qty = qty;
      });
    }
  }

  void _updateUnit(int id, String unit) {
    if (_selections.containsKey(id)) {
      setState(() {
        _selections[id]!.unit = unit;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Extra Ingredients',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('ಹೆಚ್ಚುವರಿ ದಿನಸಿ', style: TextStyle(color: Colors.grey)),
                  ],
                ),
                TextButton.icon(
                  onPressed: widget.onCreateNew,
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Set quantity for 100 people',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: widget.ingredients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('No ingredients available',
                            style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: widget.onCreateNew,
                          child: const Text('Add an ingredient'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    itemCount: widget.ingredients.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final ingredient = widget.ingredients[index];
                      final isSelected = _selections.containsKey(ingredient.id);
                      final selection = _selections[ingredient.id];

                      return Column(
                        children: [
                          ListTile(
                            leading: Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleSelection(ingredient),
                              activeColor: Colors.orange,
                            ),
                            title: Text(_getDisplayName(ingredient.nameKn, ingredient.nameEn)),
                            onTap: () => _toggleSelection(ingredient),
                          ),
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
                              child: Row(
                                children: [
                                  const Text('Qty: '),
                                  SizedBox(
                                    width: 80,
                                    child: TextField(
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      ),
                                      controller: _qtyControllers[ingredient.id],
                                      onChanged: (v) {
                                        final val = double.tryParse(v);
                                        if (val != null && val > 0) {
                                          _updateQty(ingredient.id!, val);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  DropdownButton<String>(
                                    value: selection!.unit,
                                    items: ['kg', 'g', 'L', 'ml', 'pcs']
                                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        _updateUnit(ingredient.id!, v);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final extras = _selections.values
                      .map((s) => ExtraIngredient(
                            ingredient: s.ingredient,
                            qtyFor100: s.qty,
                            unit: s.unit,
                          ))
                      .toList();
                  Navigator.pop(context, extras);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selections.isEmpty ? Colors.grey : Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _selections.isEmpty
                      ? 'Clear All / Done'
                      : 'Save ${_selections.length} ingredient${_selections.length > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientSelection {
  final Ingredient ingredient;
  double qty;
  String unit;

  _IngredientSelection({
    required this.ingredient,
    required this.qty,
    required this.unit,
  });
}

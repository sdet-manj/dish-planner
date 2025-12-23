import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/dish.dart';
import '../models/ingredient.dart';
import '../models/plan_item.dart';
import 'masters_screen.dart';
import 'create_dish_screen.dart';
import 'preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  List<Dish> _allDishes = [];
  List<PlanItem> _planItems = [];
  int _globalPeople = 100;
  bool _loading = true;

  // Controllers for text fields to fix cursor position issue
  late TextEditingController _globalPeopleController;
  final Map<int, TextEditingController> _overrideControllers = {};

  @override
  void initState() {
    super.initState();
    _globalPeopleController = TextEditingController(text: _globalPeople.toString());
    _loadDishes();
  }

  @override
  void dispose() {
    _globalPeopleController.dispose();
    for (var controller in _overrideControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDishes() async {
    final dishes = await _db.getAllDishes();
    setState(() {
      _allDishes = dishes;
      _loading = false;
    });
  }

  TextEditingController _getOverrideController(int index, int? value) {
    if (!_overrideControllers.containsKey(index)) {
      _overrideControllers[index] = TextEditingController(text: value?.toString() ?? '');
    }
    return _overrideControllers[index]!;
  }

  Future<void> _addDishesToPlan() async {
    // Show multi-select dish picker
    final availableDishes = _allDishes
        .where((d) => !_planItems.any((p) => p.dish.id == d.id))
        .toList();

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
            await _loadDishes();
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
            SnackBar(
              content: Text('${dish.nameEn} has no ingredients. Skipped.'),
            ),
          );
          continue;
        }
        setState(() {
          _planItems.add(PlanItem(dish: dish, ingredients: ingredients));
        });
      }
    }
  }

  void _removeDish(int index) {
    setState(() {
      _overrideControllers.remove(index);
      _planItems.removeAt(index);
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

  void _setOverridePeople(int index, int people) {
    setState(() {
      _planItems[index].overridePeople = people;
    });
  }

  void _goToPreview() {
    if (_planItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one dish to the plan')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          planItems: _planItems,
          globalPeople: _globalPeople,
        ),
      ),
    );
  }

  // Helper to get display name in format: ಕನ್ನಡ (English)
  String _getDisplayName(String nameKn, String nameEn) {
    return '$nameKn ($nameEn)';
  }

  void _showAddIngredientDialog() {
    final enController = TextEditingController();
    final knController = TextEditingController();
    String unit = 'kg';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Ingredient'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: enController,
                  decoration: const InputDecoration(
                    labelText: 'Name (English)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: knController,
                  decoration: const InputDecoration(
                    labelText: 'Name (Kannada)',
                    border: OutlineInputBorder(),
                  ),
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
                if (enController.text.isEmpty || knController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill both names')),
                  );
                  return;
                }
                await _db.insertIngredient(Ingredient(
                  nameEn: enController.text.trim(),
                  nameKn: knController.text.trim(),
                  defaultUnit: unit,
                ));
                Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item List'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'masters') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MastersScreen()),
                );
                _loadDishes();
              } else if (value == 'add_ingredient') {
                _showAddIngredientDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'masters',
                child: Row(
                  children: [
                    Icon(Icons.library_books, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Masters (Dishes & Ingredients)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'add_ingredient',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Add Ingredient'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Global people input
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Number of People: ',
                              style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
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
                      const SizedBox(height: 4),
                      Text(
                        'Applies to all unless overridden',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Plan items
                Expanded(
                  child: _planItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.restaurant_menu,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text('No dishes added yet',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey[600])),
                              const SizedBox(height: 8),
                              Text('Tap + to add dishes',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey[500])),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 100),
                          itemCount: _planItems.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _planItems[index];
                            final effectivePeople =
                                item.getEffectivePeople(_globalPeople);
                            final controller = _getOverrideController(
                                index, item.overridePeople);
                            return ListTile(
                              title: Text(
                                _getDisplayName(item.dish.nameKn, item.dish.nameEn),
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('People: $effectivePeople'),
                                      const SizedBox(width: 16),
                                      GestureDetector(
                                        onTap: () => _toggleOverride(index),
                                        child: Row(
                                          children: [
                                            const Text('Override: '),
                                            Text(
                                              item.hasOverride ? 'ON' : 'OFF',
                                              style: TextStyle(
                                                color: item.hasOverride
                                                    ? Colors.teal
                                                    : Colors.grey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.hasOverride)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          const Text('Number of people: '),
                                          SizedBox(
                                            width: 80,
                                            child: TextField(
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 6),
                                              ),
                                              controller: controller,
                                              onChanged: (v) {
                                                final val = int.tryParse(v);
                                                if (val != null && val > 0) {
                                                  _setOverridePeople(
                                                      index, val);
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => _removeDish(index),
                              ),
                              isThreeLine: item.hasOverride,
                            );
                          },
                        ),
                ),
                // Preview button
                if (_planItems.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _goToPreview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Preview / PDF',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDishesToPlan,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
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

  // Helper to get display name in format: ಕನ್ನಡ (English)
  String _getDisplayName(String nameKn, String nameEn) {
    return '$nameKn ($nameEn)';
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
                const Text('Select Dishes',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: widget.onCreateNew,
                  icon: const Icon(Icons.add),
                  label: const Text('Create new'),
                ),
              ],
            ),
          ),
          // Select all / Deselect all buttons
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
                        title: Text(_getDisplayName(dish.nameKn, dish.nameEn)),
                        onTap: () => _toggleSelection(dish.id!),
                      );
                    },
                  ),
          ),
          // Add selected button
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

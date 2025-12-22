import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/dish.dart';
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
  String _lang = 'BOTH';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDishes();
  }

  Future<void> _loadDishes() async {
    final dishes = await _db.getAllDishes();
    setState(() {
      _allDishes = dishes;
      _loading = false;
    });
  }

  Future<void> _addDishToPlan() async {
    // Show dish picker
    final availableDishes = _allDishes
        .where((d) => !_planItems.any((p) => p.dish.id == d.id))
        .toList();

    if (availableDishes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All dishes are already in the plan')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Dish>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DishPicker(
        dishes: availableDishes,
        lang: _lang,
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

    if (selected != null) {
      final ingredients = await _db.getDishIngredients(selected.id!);
      if (ingredients.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selected.nameEn} has no ingredients. Add ingredients first.'),
            action: SnackBarAction(
              label: 'Add',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateDishScreen(editDish: selected),
                  ),
                );
                _loadDishes();
              },
            ),
          ),
        );
        return;
      }
      setState(() {
        _planItems.add(PlanItem(dish: selected, ingredients: ingredients));
      });
    }
  }

  void _removeDish(int index) {
    setState(() {
      _planItems.removeAt(index);
    });
  }

  void _toggleOverride(int index) {
    setState(() {
      if (_planItems[index].overridePeople != null) {
        _planItems[index].overridePeople = null;
      } else {
        _planItems[index].overridePeople = _globalPeople;
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
          lang: _lang,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan / PDF'),
        actions: [
          IconButton(
            icon: const Icon(Icons.library_books),
            tooltip: 'Masters',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MastersScreen()),
              );
              _loadDishes();
            },
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
                          const Text('People for all dishes: ',
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
                              controller: TextEditingController(
                                  text: _globalPeople.toString()),
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
                      const SizedBox(height: 12),
                      // Language toggle
                      Row(
                        children: [
                          _LangButton(
                            label: 'EN',
                            selected: _lang == 'EN',
                            onTap: () => setState(() => _lang = 'EN'),
                          ),
                          const SizedBox(width: 8),
                          _LangButton(
                            label: 'KN',
                            selected: _lang == 'KN',
                            onTap: () => setState(() => _lang = 'KN'),
                          ),
                          const SizedBox(width: 8),
                          _LangButton(
                            label: 'BOTH',
                            selected: _lang == 'BOTH',
                            onTap: () => setState(() => _lang = 'BOTH'),
                          ),
                        ],
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
                            return ListTile(
                              title: Text(
                                item.dish.getDisplayName(_lang),
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
                                            Text('Override: '),
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
                                          const Text('Override people: '),
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
                                              controller: TextEditingController(
                                                  text: item.overridePeople
                                                      .toString()),
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
        onPressed: _addDishToPlan,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.teal : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.teal),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.teal,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DishPicker extends StatelessWidget {
  final List<Dish> dishes;
  final String lang;
  final VoidCallback onCreateNew;

  const _DishPicker({
    required this.dishes,
    required this.lang,
    required this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
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
                const Text('Pick a dish',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: onCreateNew,
                  icon: const Icon(Icons.add),
                  label: const Text('Create new'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: dishes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('No dishes available',
                            style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: onCreateNew,
                          child: const Text('Create a dish'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    itemCount: dishes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final dish = dishes[index];
                      return ListTile(
                        title: Text(dish.getDisplayName(lang)),
                        onTap: () => Navigator.pop(context, dish),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


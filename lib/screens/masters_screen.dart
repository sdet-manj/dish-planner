import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/ingredient.dart';
import '../models/dish.dart';
import '../services/backup_service.dart';
import 'create_dish_screen.dart';

class MastersScreen extends StatefulWidget {
  const MastersScreen({super.key});

  @override
  State<MastersScreen> createState() => _MastersScreenState();
}

class _MastersScreenState extends State<MastersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = DatabaseHelper.instance;
  List<Ingredient> _ingredients = [];
  List<Dish> _dishes = [];
  String _lang = 'BOTH';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final ingredients = await _db.getAllIngredients();
    final dishes = await _db.getAllDishes();
    setState(() {
      _ingredients = ingredients;
      _dishes = dishes;
      _loading = false;
    });
  }

  void _showAddIngredientDialog() {
    final enController = TextEditingController();
    final knController = TextEditingController();
    String unit = 'kg';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                onChanged: (v) => unit = v ?? 'kg',
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
              _loadData();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditIngredientDialog(Ingredient ing) {
    final enController = TextEditingController(text: ing.nameEn);
    final knController = TextEditingController(text: ing.nameKn);
    String unit = ing.defaultUnit;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Ingredient'),
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
                onChanged: (v) => unit = v ?? 'kg',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Ingredient?'),
                  content: const Text(
                      'This will remove the ingredient from all dishes.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _db.deleteIngredient(ing.id!);
                Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          const Spacer(),
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
              await _db.updateIngredient(Ingredient(
                id: ing.id,
                nameEn: enController.text.trim(),
                nameKn: knController.text.trim(),
                defaultUnit: unit,
              ));
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup() async {
    final file = await BackupService.exportBackup();
    if (file != null) {
      await BackupService.shareBackup(file);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export backup')),
      );
    }
  }

  Future<void> _importBackup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Backup?'),
        content: const Text(
            'This will replace all current data with the backup data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await BackupService.importBackup();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup imported successfully')),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to import backup')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Masters'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') _exportBackup();
              if (value == 'import') _importBackup();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'export', child: Text('Export Backup')),
              const PopupMenuItem(value: 'import', child: Text('Import Backup')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ingredients'),
            Tab(text: 'Dishes'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Language toggle
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
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
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Ingredients tab
                      _ingredients.isEmpty
                          ? const Center(child: Text('No ingredients'))
                          : ListView.separated(
                              itemCount: _ingredients.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final ing = _ingredients[index];
                                return ListTile(
                                  title: Text(ing.getDisplayName(_lang)),
                                  subtitle: Text('Unit: ${ing.defaultUnit}'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _showEditIngredientDialog(ing),
                                );
                              },
                            ),
                      // Dishes tab
                      _dishes.isEmpty
                          ? const Center(child: Text('No dishes'))
                          : ListView.separated(
                              itemCount: _dishes.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final dish = _dishes[index];
                                return ListTile(
                                  title: Text(dish.getDisplayName(_lang)),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CreateDishScreen(editDish: dish),
                                      ),
                                    );
                                    _loadData();
                                  },
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddIngredientDialog();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateDishScreen()),
            ).then((_) => _loadData());
          }
        },
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


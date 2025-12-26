import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/dish.dart';
import '../models/ingredient.dart';
import '../models/dish_ingredient.dart';

class CreateDishScreen extends StatefulWidget {
  final Dish? editDish;

  const CreateDishScreen({super.key, this.editDish});

  @override
  State<CreateDishScreen> createState() => _CreateDishScreenState();
}

class _CreateDishScreenState extends State<CreateDishScreen> {
  final _db = DatabaseHelper.instance;
  final _nameEnController = TextEditingController();
  final _nameKnController = TextEditingController();
  final _subCategoryController = TextEditingController();
  List<Ingredient> _allIngredients = [];
  List<_SelectedIngredient> _selectedIngredients = [];
  bool _loading = true;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.editDish != null;
    if (_isEdit) {
      _nameEnController.text = widget.editDish!.nameEn;
      _nameKnController.text = widget.editDish!.nameKn;
      _subCategoryController.text = widget.editDish!.subCategory ?? '';
    }
    _loadData();
  }

  @override
  void dispose() {
    _nameEnController.dispose();
    _nameKnController.dispose();
    _subCategoryController.dispose();
    for (var si in _selectedIngredients) {
      si.qtyController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final ingredients = await _db.getAllIngredients();
    List<_SelectedIngredient> selected = [];

    if (_isEdit) {
      final dishIngs = await _db.getDishIngredients(widget.editDish!.id!);
      for (var di in dishIngs) {
        final ing = ingredients.firstWhere((i) => i.id == di.ingredientId);
        selected.add(_SelectedIngredient(
          ingredient: ing,
          qty: di.qtyFor100,
          unit: di.unit,
        ));
      }
    }

    setState(() {
      _allIngredients = ingredients;
      _selectedIngredients = selected;
      _loading = false;
    });
  }

  // Helper to get display name in format: ಕನ್ನಡ (English)
  String _getDisplayName(String nameKn, String nameEn) {
    return '$nameKn ($nameEn)';
  }

  void _addIngredient() async {
    final available = _allIngredients
        .where((i) => !_selectedIngredients.any((s) => s.ingredient.id == i.id))
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All ingredients are already added')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Ingredient>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _IngredientPicker(
        ingredients: available,
        onCreateNew: () async {
          Navigator.pop(context);
          await _showCreateIngredientDialog();
        },
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedIngredients.add(_SelectedIngredient(
          ingredient: selected,
          qty: 0,
          unit: selected.defaultUnit,
        ));
      });
    }
  }

  Future<void> _showCreateIngredientDialog() async {
    final enController = TextEditingController();
    final knController = TextEditingController();
    String unit = 'kg';
    IngredientCategory category = IngredientCategory.dinasi;

    final result = await showDialog<Ingredient>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Ingredient'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: knController,
                  decoration: const InputDecoration(
                    labelText: 'Name (Kannada) *',
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
                final id = await _db.insertIngredient(Ingredient(
                  nameEn: nameEn.isNotEmpty ? nameEn : null,
                  nameKn: knController.text.trim(),
                  defaultUnit: unit,
                  category: category,
                ));
                final newIng = Ingredient(
                  id: id,
                  nameEn: nameEn.isNotEmpty ? nameEn : null,
                  nameKn: knController.text.trim(),
                  defaultUnit: unit,
                  category: category,
                );
                Navigator.pop(context, newIng);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _loadData();
      setState(() {
        _selectedIngredients.add(_SelectedIngredient(
          ingredient: result,
          qty: 0,
          unit: result.defaultUnit,
        ));
      });
    }
  }

  void _removeIngredient(int index) {
    setState(() {
      _selectedIngredients[index].qtyController.dispose();
      _selectedIngredients.removeAt(index);
    });
  }

  void _updateQty(int index, double qty) {
    _selectedIngredients[index].qty = qty;
  }

  void _updateUnit(int index, String unit) {
    setState(() {
      _selectedIngredients[index].unit = unit;
    });
  }

  Future<void> _save() async {
    if (_nameKnController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill dish name in Kannada')),
      );
      return;
    }

    if (_selectedIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one ingredient')),
      );
      return;
    }

    for (var si in _selectedIngredients) {
      if (si.qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Please set quantity for ${si.ingredient.nameEn}')),
        );
        return;
      }
    }

    int dishId;
    final nameEn = _nameEnController.text.trim();
    final subCat = _subCategoryController.text.trim();
    
    if (_isEdit) {
      await _db.updateDish(Dish(
        id: widget.editDish!.id,
        nameEn: nameEn.isNotEmpty ? nameEn : null,
        nameKn: _nameKnController.text.trim(),
        subCategory: subCat.isNotEmpty ? subCat : null,
      ));
      dishId = widget.editDish!.id!;
    } else {
      dishId = await _db.insertDish(Dish(
        nameEn: nameEn.isNotEmpty ? nameEn : null,
        nameKn: _nameKnController.text.trim(),
        subCategory: subCat.isNotEmpty ? subCat : null,
      ));
    }

    final dishIngredients = _selectedIngredients
        .map((si) => DishIngredient(
              dishId: dishId,
              ingredientId: si.ingredient.id!,
              qtyFor100: si.qty,
              unit: si.unit,
            ))
        .toList();

    await _db.saveDishIngredients(dishId, dishIngredients);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _deleteDish() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Dish?'),
        content: const Text('This will permanently delete the dish.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteDish(widget.editDish!.id!);
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Dish' : 'New Dish'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteDish,
            ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameKnController,
                    decoration: const InputDecoration(
                      labelText: 'Dish name (Kannada) *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameEnController,
                    decoration: const InputDecoration(
                      labelText: 'Dish name (English) - Optional',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _subCategoryController,
                    decoration: const InputDecoration(
                      labelText: 'Sub-category (Optional)',
                      hintText: 'e.g., Hesaru Bele, Kadlebele',
                      border: OutlineInputBorder(),
                      helperText: 'Optional: Add variant/type if dish has sub-categories',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.teal),
                        SizedBox(width: 8),
                        Text('Baseline: 100 people',
                            style: TextStyle(color: Colors.teal)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ingredients',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: _addIngredient,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_selectedIngredients.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.restaurant,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text('No ingredients added',
                                style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _selectedIngredients.length,
                      itemBuilder: (context, index) {
                        final si = _selectedIngredients[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _getDisplayName(si.ingredient.nameKn, si.ingredient.nameEn),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _removeIngredient(index),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'Qty for 100 ppl',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        controller: si.qtyController,
                                        onChanged: (v) {
                                          final val = double.tryParse(v);
                                          if (val != null) {
                                            _updateQty(index, val);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 80,
                                      child: DropdownButtonFormField<String>(
                                        value: si.unit,
                                        decoration: const InputDecoration(
                                          labelText: 'Unit',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        items: ['kg', 'g', 'L', 'ml', 'pcs']
                                            .map((u) => DropdownMenuItem(
                                                value: u, child: Text(u)))
                                            .toList(),
                                        onChanged: (v) {
                                          if (v != null) {
                                            _updateUnit(index, v);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}

class _SelectedIngredient {
  final Ingredient ingredient;
  double qty;
  String unit;
  final TextEditingController qtyController;

  _SelectedIngredient({
    required this.ingredient,
    required this.qty,
    required this.unit,
  }) : qtyController = TextEditingController(text: qty > 0 ? qty.toString() : '');
}

class _IngredientPicker extends StatefulWidget {
  final List<Ingredient> ingredients;
  final VoidCallback onCreateNew;

  const _IngredientPicker({
    required this.ingredients,
    required this.onCreateNew,
  });

  @override
  State<_IngredientPicker> createState() => _IngredientPickerState();
}

class _IngredientPickerState extends State<_IngredientPicker> {
  String _search = '';

  // Helper to get display name in format: ಕನ್ನಡ (English)
  String _getDisplayName(String nameKn, String nameEn) {
    return '$nameKn ($nameEn)';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.ingredients
        .where((i) =>
            i.nameEn.toLowerCase().contains(_search.toLowerCase()) ||
            i.nameKn.contains(_search))
        .toList();

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
                const Text('Pick ingredient',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search ingredients...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final ing = filtered[index];
                return ListTile(
                  title: Text(_getDisplayName(ing.nameKn, ing.nameEn)),
                  subtitle: Text('Unit: ${ing.defaultUnit}'),
                  onTap: () => Navigator.pop(context, ing),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

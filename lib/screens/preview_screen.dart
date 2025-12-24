import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/plan_item.dart';
import '../models/extra_ingredient.dart';
import '../services/pdf_service.dart';

class PreviewScreen extends StatefulWidget {
  final List<PlanItem> planItems;
  final List<ExtraIngredient> extraIngredients;
  final int globalPeople;
  final DateTime? selectedDate;

  const PreviewScreen({
    super.key,
    required this.planItems,
    this.extraIngredients = const [],
    required this.globalPeople,
    this.selectedDate,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Helper to get display name in format: ಕನ್ನಡ (English)
  String _getDisplayName(String? nameKn, String? nameEn) {
    final kn = nameKn ?? '';
    final en = nameEn ?? '';
    return '$kn ($en)';
  }

  // Convert units: g→kg if >1000, ml→L if >1000
  Map<String, dynamic> _convertUnit(double qty, String unit) {
    double convertedQty = qty;
    String convertedUnit = unit;

    if (unit == 'g' && qty >= 1000) {
      convertedQty = qty / 1000;
      convertedUnit = 'kg';
    } else if (unit == 'ml' && qty >= 1000) {
      convertedQty = qty / 1000;
      convertedUnit = 'L';
    }

    return {'qty': convertedQty, 'unit': convertedUnit};
  }

  Map<String, _MergedIngredient> _getMergedIngredients() {
    final Map<String, _MergedIngredient> merged = {};

    // Merge from dishes
    for (var item in widget.planItems) {
      final effectivePeople = item.getEffectivePeople(widget.globalPeople);
      for (var ing in item.ingredients) {
        final qty = ing.getScaledQty(effectivePeople);
        final key = '${ing.ingredientId}_${ing.unit}';
        if (merged.containsKey(key)) {
          merged[key]!.totalQty += qty;
          merged[key]!.usedIn.add(item.dish.nameEn);
        } else {
          merged[key] = _MergedIngredient(
            nameEn: ing.ingredientNameEn ?? '',
            nameKn: ing.ingredientNameKn ?? '',
            unit: ing.unit,
            totalQty: qty,
            usedIn: [item.dish.nameEn],
          );
        }
      }
    }

    // Merge extra ingredients
    for (var extra in widget.extraIngredients) {
      final qty = extra.getScaledQty(widget.globalPeople);
      final key = '${extra.ingredient.id}_${extra.unit}';
      if (merged.containsKey(key)) {
        merged[key]!.totalQty += qty;
        if (!merged[key]!.usedIn.contains('Extra')) {
          merged[key]!.usedIn.add('Extra');
        }
      } else {
        merged[key] = _MergedIngredient(
          nameEn: extra.ingredient.nameEn,
          nameKn: extra.ingredient.nameKn,
          unit: extra.unit,
          totalQty: qty,
          usedIn: ['Extra'],
        );
      }
    }

    return merged;
  }

  Future<void> _generateDishWisePdf() async {
    setState(() => _generating = true);
    try {
      final file = await PdfService.generateDishWisePdf(
        planItems: widget.planItems,
        extraIngredients: widget.extraIngredients,
        globalPeople: widget.globalPeople,
      );
      await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename: file.path.split('/').last,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
    setState(() => _generating = false);
  }

  Future<void> _generateOverallPdf() async {
    setState(() => _generating = true);
    try {
      final file = await PdfService.generateOverallPdf(
        planItems: widget.planItems,
        extraIngredients: widget.extraIngredients,
        globalPeople: widget.globalPeople,
      );
      await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename: file.path.split('/').last,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
    setState(() => _generating = false);
  }

  Future<void> _generateBothPdfs() async {
    setState(() => _generating = true);
    try {
      final dishWiseFile = await PdfService.generateDishWisePdf(
        planItems: widget.planItems,
        extraIngredients: widget.extraIngredients,
        globalPeople: widget.globalPeople,
      );
      final overallFile = await PdfService.generateOverallPdf(
        planItems: widget.planItems,
        extraIngredients: widget.extraIngredients,
        globalPeople: widget.globalPeople,
      );

      // Show options
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('PDFs Ready',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.description),
                title: Text(dishWiseFile.path.split('/').last),
                trailing: TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Printing.sharePdf(
                      bytes: await dishWiseFile.readAsBytes(),
                      filename: dishWiseFile.path.split('/').last,
                    );
                  },
                  child: const Text('Share'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: Text(overallFile.path.split('/').last),
                trailing: TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await Printing.sharePdf(
                      bytes: await overallFile.readAsBytes(),
                      filename: overallFile.path.split('/').last,
                    );
                  },
                  child: const Text('Share'),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDFs: $e')),
      );
    }
    setState(() => _generating = false);
  }

  String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    // Round to 2 decimal places and remove trailing zeros
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final merged = _getMergedIngredients();
    final mergedList = merged.values.toList()
      ..sort((a, b) => a.nameEn.compareTo(b.nameEn));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Dish-wise'),
            Tab(text: 'Overall'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Dish-wise tab
                ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    // Dishes
                    ...widget.planItems.map((item) {
                      final effectivePeople =
                          item.getEffectivePeople(widget.globalPeople);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            color: Colors.teal[50],
                            child: Text(
                              '${_getDisplayName(item.dish.nameKn, item.dish.nameEn)} — $effectivePeople people',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...item.ingredients.map((ing) {
                            final rawQty = ing.getScaledQty(effectivePeople);
                            final converted = _convertUnit(rawQty, ing.unit);
                            final qty = converted['qty'] as double;
                            final unit = converted['unit'] as String;
                            return ListTile(
                              title: Text(_getDisplayName(
                                  ing.ingredientNameKn, ing.ingredientNameEn)),
                              trailing: Text(
                                '${_formatQty(qty)} $unit',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            );
                          }),
                          const Divider(),
                        ],
                      );
                    }),
                    // Extra ingredients section
                    if (widget.extraIngredients.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: Colors.orange[50],
                        child: Row(
                          children: [
                            const Icon(Icons.add_shopping_cart,
                                size: 20, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              'Extra Ingredients — ${widget.globalPeople} people',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...widget.extraIngredients.map((extra) {
                        final rawQty = extra.getScaledQty(widget.globalPeople);
                        final converted = _convertUnit(rawQty, extra.unit);
                        final qty = converted['qty'] as double;
                        final unit = converted['unit'] as String;
                        return ListTile(
                          title: Text(extra.getDisplayName()),
                          trailing: Text(
                            '${_formatQty(qty)} $unit',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
                // Overall tab
                ListView.separated(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: mergedList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final m = mergedList[index];
                    final converted = _convertUnit(m.totalQty, m.unit);
                    final qty = converted['qty'] as double;
                    final unit = converted['unit'] as String;
                    return ListTile(
                      title: Text(_getDisplayName(m.nameKn, m.nameEn)),
                      subtitle: Text('Used in: ${m.usedIn.join(", ")}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                      trailing: Text(
                        '${_formatQty(qty)} $unit',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Generate buttons
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
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _generating ? null : _generateDishWisePdf,
                        child: const Text('Dish-wise PDF'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _generating ? null : _generateOverallPdf,
                        child: const Text('Overall PDF'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _generating ? null : _generateBothPdfs,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _generating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Generate Both PDFs',
                            style: TextStyle(fontSize: 16)),
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

class _MergedIngredient {
  final String nameEn;
  final String nameKn;
  final String unit;
  double totalQty;
  List<String> usedIn;

  _MergedIngredient({
    required this.nameEn,
    required this.nameKn,
    required this.unit,
    required this.totalQty,
    required this.usedIn,
  });
}

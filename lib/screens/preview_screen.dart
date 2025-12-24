import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
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

  String _getDisplayName(String? nameKn, String? nameEn) {
    final kn = nameKn ?? '';
    final en = nameEn ?? '';
    return '$kn ($en)';
  }

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
            category: ing.ingredientCategory ?? 'dinasi',
            totalQty: qty,
            usedIn: [item.dish.nameEn],
          );
        }
      }
    }

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
          category: extra.ingredient.category.name,
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
        eventDate: widget.selectedDate,
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
        eventDate: widget.selectedDate,
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

  Widget _buildOverallTab(Map<String, _MergedIngredient> merged) {
    // Group by category
    final dinasiList = merged.values.where((m) => m.category == 'dinasi').toList()
      ..sort((a, b) => a.nameEn.compareTo(b.nameEn));
    final vegetableList = merged.values.where((m) => m.category == 'vegetable').toList()
      ..sort((a, b) => a.nameEn.compareTo(b.nameEn));
    final dairyList = merged.values.where((m) => m.category == 'dairy').toList()
      ..sort((a, b) => a.nameEn.compareTo(b.nameEn));

    Widget buildCategorySection(String titleEn, String titleKn, List<_MergedIngredient> items, MaterialColor color) {
      if (items.isEmpty) return const SizedBox.shrink();
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            color: color.withOpacity(0.2),
            child: Text(
              '$titleKn ($titleEn)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color.shade700,
              ),
            ),
          ),
          ...items.map((m) {
            final converted = _convertUnit(m.totalQty, m.unit);
            final qty = converted['qty'] as double;
            final unit = converted['unit'] as String;
            return ListTile(
              title: Text(_getDisplayName(m.nameKn, m.nameEn)),
              subtitle: Text('Used in: ${m.usedIn.join(", ")}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              trailing: Text(
                '${_formatQty(qty)} $unit',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            );
          }),
          const Divider(),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        buildCategorySection('Groceries', 'ದಿನಸಿ', dinasiList, Colors.teal),
        buildCategorySection('Vegetables', 'ತರಕಾರಿ', vegetableList, Colors.green),
        buildCategorySection('Milk/Curd', 'ಹಾಲು/ಮೊಸರು', dairyList, Colors.blue),
      ],
    );
  }

  void _showPdfOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Generate & Share PDF',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.list_alt, color: Colors.teal),
                title: const Text('Dish-wise PDF'),
                subtitle: const Text('Each dish with its ingredients'),
                onTap: () {
                  Navigator.pop(context);
                  _generateDishWisePdf();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.summarize, color: Colors.orange),
                title: const Text('Overall PDF'),
                subtitle: const Text('Combined ingredient list'),
                onTap: () {
                  Navigator.pop(context);
                  _generateOverallPdf();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('Generate Both PDFs'),
                subtitle: const Text('Dish-wise & Overall'),
                onTap: () async {
                  Navigator.pop(context);
                  setState(() => _generating = true);
                  try {
                    final dishWiseFile = await PdfService.generateDishWisePdf(
                      planItems: widget.planItems,
                      extraIngredients: widget.extraIngredients,
                      globalPeople: widget.globalPeople,
                      eventDate: widget.selectedDate,
                    );
                    final overallFile = await PdfService.generateOverallPdf(
                      planItems: widget.planItems,
                      extraIngredients: widget.extraIngredients,
                      globalPeople: widget.globalPeople,
                      eventDate: widget.selectedDate,
                    );

                    if (!mounted) return;
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('PDFs Ready!',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            ListTile(
                              leading: const Icon(Icons.description, color: Colors.teal),
                              title: Text(dishWiseFile.path.split('/').last),
                              trailing: ElevatedButton(
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
                              leading: const Icon(Icons.description, color: Colors.orange),
                              title: Text(overallFile.path.split('/').last),
                              trailing: ElevatedButton(
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
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                  setState(() => _generating = false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final merged = _getMergedIngredients();
    final mergedList = merged.values.toList()
      ..sort((a, b) => a.nameEn.compareTo(b.nameEn));
    
    final dateStr = widget.selectedDate != null
        ? DateFormat('dd/MM/yyyy').format(widget.selectedDate!)
        : DateFormat('dd/MM/yyyy').format(DateTime.now());

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
          // Date and People info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.teal.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Date (ದಿನಾಂಕ)',
                        style: TextStyle(fontSize: 12, color: Colors.teal)),
                    Text(dateStr,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(height: 30, width: 1, color: Colors.teal),
                Column(
                  children: [
                    const Text('People (ಜನ)',
                        style: TextStyle(fontSize: 12, color: Colors.teal)),
                    Text('${widget.globalPeople}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Dish-wise tab
                ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
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
                // Overall tab - grouped by category
                _buildOverallTab(merged),
              ],
            ),
          ),
          // Generate PDF button
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
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generating ? null : _showPdfOptions,
                icon: _generating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: const Text('Generate PDF', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
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
  final String category; // dinasi, vegetable, dairy
  double totalQty;
  List<String> usedIn;

  _MergedIngredient({
    required this.nameEn,
    required this.nameKn,
    required this.unit,
    required this.category,
    required this.totalQty,
    required this.usedIn,
  });
}

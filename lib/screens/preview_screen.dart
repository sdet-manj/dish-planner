import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/plan_item.dart';
import '../models/extra_ingredient.dart';
import '../services/pdf_service.dart';
import '../services/kannada_pdf_service.dart';

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
    double? originalQty; // Track original before rounding

    // Convert g to kg or ml to L ONLY if >= 1000
    if (unit == 'kg' && qty >= 1.0) {
      originalQty = qty;
      // Round to nearest 0.25 kg (250g increments) for easier shopping
      convertedQty = (qty * 4).ceil() / 4; // Round up to nearest 0.25
    } else if (unit == 'L' && qty >= 1.0) {
      originalQty = qty;
      // Round to nearest 0.25 L (250ml increments)
      convertedQty = (qty * 4).ceil() / 4;
    } else if (unit == 'pcs' && qty > 20) {
      originalQty = qty;
      // Round up to next 5 for pieces
      convertedQty = (qty / 5).ceil() * 5;
    }

    return {
      'qty': convertedQty, 
      'unit': convertedUnit,
      'original': originalQty, // Include original for preview display
      'rounded': originalQty != null && (originalQty - convertedQty).abs() > 0.01,
    };
  }

  Map<String, _MergedIngredient> _getMergedIngredients() {
    final Map<String, _MergedIngredient> merged = {};

    // Helper to normalize unit and quantity
    Map<String, dynamic> normalizeUnit(double qty, String unit) {
      if (unit == 'g') {
        return {'qty': qty / 1000, 'unit': 'kg'};
      } else if (unit == 'ml') {
        return {'qty': qty / 1000, 'unit': 'L'};
      }
      return {'qty': qty, 'unit': unit};
    }

    for (var item in widget.planItems) {
      final effectivePeople = item.getEffectivePeople(widget.globalPeople);
      for (var ing in item.ingredients) {
        final qty = ing.getScaledQty(effectivePeople);
        final normalized = normalizeUnit(qty, ing.unit);
        final normalizedQty = normalized['qty'] as double;
        final normalizedUnit = normalized['unit'] as String;
        
        final key = '${ing.ingredientId}_$normalizedUnit';
        if (merged.containsKey(key)) {
          merged[key]!.totalQty += normalizedQty;
          merged[key]!.usedIn.add(item.dish.nameEn ?? item.dish.nameKn);
        } else {
          merged[key] = _MergedIngredient(
            nameEn: ing.ingredientNameEn ?? '',
            nameKn: ing.ingredientNameKn ?? '',
            unit: normalizedUnit,
            category: ing.ingredientCategory ?? 'dinasi',
            totalQty: normalizedQty,
            usedIn: [item.dish.nameEn ?? item.dish.nameKn],
          );
        }
      }
    }

    for (var extra in widget.extraIngredients) {
      final qty = extra.getScaledQty(widget.globalPeople);
      final normalized = normalizeUnit(qty, extra.unit);
      final normalizedQty = normalized['qty'] as double;
      final normalizedUnit = normalized['unit'] as String;
      
      final key = '${extra.ingredient.id}_$normalizedUnit';
      if (merged.containsKey(key)) {
        merged[key]!.totalQty += normalizedQty;
        if (!merged[key]!.usedIn.contains('Extra')) {
          merged[key]!.usedIn.add('Extra');
        }
      } else {
        merged[key] = _MergedIngredient(
          nameEn: extra.ingredient.nameEn ?? '',
          nameKn: extra.ingredient.nameKn,
          unit: normalizedUnit,
          category: extra.ingredient.category.name,
          totalQty: normalizedQty,
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

  /// Generate Overall PDF with Kannada text
  Future<void> _generateKannadaPdf() async {
    setState(() => _generating = true);
    try {
      await KannadaPdfService.generateAndSharePdf(
        context: context,
        planItems: widget.planItems,
        extraIngredients: widget.extraIngredients,
        globalPeople: widget.globalPeople,
        eventDate: widget.selectedDate,
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
            final original = converted['original'] as double?;
            final wasRounded = converted['rounded'] as bool? ?? false;
            
            String displayQty = _formatQty(qty);
            if (wasRounded && original != null) {
              displayQty = '${_formatQty(original)} → $displayQty';
            }
            
            return ListTile(
              title: Text(_getDisplayName(m.nameKn, m.nameEn)),
              subtitle: Text('Used in: ${m.usedIn.join(", ")}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              trailing: Text(
                '$displayQty $unit',
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
                leading: const Icon(Icons.summarize, color: Colors.orange),
                title: const Text('ಸಾಮಾನು ಪಟ್ಟಿ (Kannada)'),
                subtitle: const Text('Combined ingredient list'),
                onTap: () {
                  Navigator.pop(context);
                  _generateKannadaPdf();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.list_alt, color: Colors.teal),
                title: const Text('Dish-wise PDF'),
                subtitle: const Text('Each dish with its ingredients'),
                onTap: () {
                  Navigator.pop(context);
                  _generateDishWisePdf();
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
            Tab(text: 'ಸಾಮಾನು ಪಟ್ಟಿ'),
            Tab(text: 'Dish-wise'),
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
                // Overall tab (ಸಾಮಾನು ಪಟ್ಟಿ) - grouped by category - FIRST
                _buildOverallTab(merged),
                // Dish-wise tab - SECOND
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
                              '${item.dish.getFullDisplayName()} — $effectivePeople people',
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
                            final original = converted['original'] as double?;
                            final wasRounded = converted['rounded'] as bool? ?? false;
                            
                            String displayQty = _formatQty(qty);
                            if (wasRounded && original != null) {
                              displayQty = '${_formatQty(original)} → $displayQty';
                            }
                            
                            return ListTile(
                              title: Text(_getDisplayName(
                                  ing.ingredientNameKn, ing.ingredientNameEn)),
                              trailing: Text(
                                '$displayQty $unit',
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
                        final original = converted['original'] as double?;
                        final wasRounded = converted['rounded'] as bool? ?? false;
                        
                        String displayQty = _formatQty(qty);
                        if (wasRounded && original != null) {
                          displayQty = '${_formatQty(original)} → $displayQty';
                        }
                        
                        return ListTile(
                          title: Text(extra.getDisplayName()),
                          trailing: Text(
                            '$displayQty $unit',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
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

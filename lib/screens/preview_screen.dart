import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/plan_item.dart';
import '../services/pdf_service.dart';

class PreviewScreen extends StatefulWidget {
  final List<PlanItem> planItems;
  final int globalPeople;

  const PreviewScreen({
    super.key,
    required this.planItems,
    required this.globalPeople,
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
            totalQty: qty,
            usedIn: [item.dish.nameEn],
          );
        }
      }
    }

    return merged;
  }

  Future<void> _generateDishWisePdf() async {
    setState(() => _generating = true);
    try {
      final file = await PdfService.generateDishWisePdf(
        planItems: widget.planItems,
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
        globalPeople: widget.globalPeople,
      );
      final overallFile = await PdfService.generateOverallPdf(
        planItems: widget.planItems,
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
    return qty.toStringAsFixed(2);
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
                ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: widget.planItems.length,
                  itemBuilder: (context, index) {
                    final item = widget.planItems[index];
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
                          final qty = ing.getScaledQty(effectivePeople);
                          return ListTile(
                            title: Text(_getDisplayName(ing.ingredientNameKn, ing.ingredientNameEn)),
                            trailing: Text(
                              '${_formatQty(qty)} ${ing.unit}',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          );
                        }),
                        const Divider(),
                      ],
                    );
                  },
                ),
                // Overall tab
                ListView.separated(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: mergedList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final m = mergedList[index];
                    return ListTile(
                      title: Text(_getDisplayName(m.nameKn, m.nameEn)),
                      subtitle: Text('Used in: ${m.usedIn.join(", ")}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      trailing: Text(
                        '${_formatQty(m.totalQty)} ${m.unit}',
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

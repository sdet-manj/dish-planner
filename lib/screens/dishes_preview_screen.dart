import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/plan_item.dart';
import '../services/kannada_pdf_service.dart';

/// Screen to preview selected dishes and generate PDF of dish list
class DishesPreviewScreen extends StatefulWidget {
  final List<PlanItem> planItems;
  final int globalPeople;
  final DateTime? selectedDate;

  const DishesPreviewScreen({
    super.key,
    required this.planItems,
    required this.globalPeople,
    this.selectedDate,
  });

  @override
  State<DishesPreviewScreen> createState() => _DishesPreviewScreenState();
}

class _DishesPreviewScreenState extends State<DishesPreviewScreen> {
  bool _generating = false;

  String _getDisplayName(String nameKn, String? nameEn) {
    return nameEn != null && nameEn.isNotEmpty ? '$nameKn ($nameEn)' : nameKn;
  }

  Future<void> _generateDishListPdf() async {
    setState(() => _generating = true);
    try {
      await KannadaPdfService.generateDishListPdf(
        context: context,
        planItems: widget.planItems,
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

  @override
  Widget build(BuildContext context) {
    final dateStr = widget.selectedDate != null
        ? DateFormat('dd/MM/yyyy').format(widget.selectedDate!)
        : DateFormat('dd/MM/yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dishes Preview'),
      ),
      body: Column(
        children: [
          // Header with date and people
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade100,
            child: Column(
              children: [
                const Text(
                  'ITEM LIST / ಅಡುಗೆ ಪಟ್ಟಿ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
                const SizedBox(height: 12),
                Row(
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
              ],
            ),
          ),
          // Dishes list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.planItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = widget.planItems[index];
                final effectivePeople = item.getEffectivePeople(widget.globalPeople);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                  ),
                  title: Text(
                    _getDisplayName(item.dish.nameKn, item.dish.nameEn),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text('For $effectivePeople people'),
                );
              },
            ),
          ),
          // Total dishes count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Total: ${widget.planItems.length} dishes',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                onPressed: _generating ? null : _generateDishListPdf,
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
                label: const Text('Generate Dish List PDF', style: TextStyle(fontSize: 16)),
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


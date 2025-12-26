import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import '../models/plan_item.dart';
import '../models/extra_ingredient.dart';

/// PDF service that renders Kannada correctly by capturing Flutter widgets as images
class KannadaPdfService {
  
  /// Generate Overall PDF with perfect Kannada - captures rows as images
  static Future<void> generateAndSharePdf({
    required BuildContext context,
    required List<PlanItem> planItems,
    List<ExtraIngredient> extraIngredients = const [],
    required int globalPeople,
    DateTime? eventDate,
    String? customSuffix,
  }) async {
    final selectedDate = eventDate ?? DateTime.now();
    final dateForFilename = DateFormat('dd-MMM-yyyy').format(selectedDate);
    final eventDateStr = DateFormat('dd/MM/yyyy').format(selectedDate);
    
    // Ask for custom filename suffix
    String? suffix = customSuffix;
    if (suffix == null) {
      suffix = await _showFilenameDialog(context, 'Ingredients_$dateForFilename');
      if (suffix == null) return; // User cancelled
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Merge all ingredients by category
      final Map<String, _MergedIngredient> merged = {};

      // From dishes
      for (var item in planItems) {
        final effectivePeople = item.getEffectivePeople(globalPeople);
        for (var ing in item.ingredients) {
          final qty = ing.getScaledQty(effectivePeople);
          final key = '${ing.ingredientId}_${ing.unit}';
          if (merged.containsKey(key)) {
            merged[key]!.totalQty += qty;
          } else {
            merged[key] = _MergedIngredient(
              nameEn: ing.ingredientNameEn ?? '',
              nameKn: ing.ingredientNameKn ?? '',
              unit: ing.unit,
              category: ing.ingredientCategory ?? 'dinasi',
              totalQty: qty,
            );
          }
        }
      }

      // From extra ingredients
      for (var extra in extraIngredients) {
        final qty = extra.getScaledQty(globalPeople);
        final key = '${extra.ingredient.id}_${extra.unit}';
        if (merged.containsKey(key)) {
          merged[key]!.totalQty += qty;
        } else {
          merged[key] = _MergedIngredient(
            nameEn: extra.ingredient.nameEn,
            nameKn: extra.ingredient.nameKn,
            unit: extra.unit,
            category: extra.ingredient.category.name,
            totalQty: qty,
          );
        }
      }

      // Group by category
      final groceriesList = merged.values.where((m) => m.category == 'dinasi').toList()
        ..sort((a, b) => a.nameEn.compareTo(b.nameEn));
      final vegetablesList = merged.values.where((m) => m.category == 'vegetable').toList()
        ..sort((a, b) => a.nameEn.compareTo(b.nameEn));
      final dairyList = merged.values.where((m) => m.category == 'dairy').toList()
        ..sort((a, b) => a.nameEn.compareTo(b.nameEn));

      final screenshotController = ScreenshotController();
      final pdf = pw.Document();
      
      // Capture helper - captures a small widget
      Future<Uint8List?> captureWidget(Widget widget) async {
        try {
          return await screenshotController.captureFromWidget(
            Material(color: Colors.white, child: widget),
            context: context,
            pixelRatio: 2.0,
            delay: const Duration(milliseconds: 20),
          );
        } catch (e) {
          debugPrint('Capture error: $e');
          return null;
        }
      }

      // Collect all row images for each category
      List<_PdfPageData> pages = [];
      List<pw.Widget> currentPageWidgets = [];
      int itemsOnCurrentPage = 0;
      const int maxItemsPerPage = 18;
      bool isFirstPage = true;

      // Capture header
      final headerBytes = await captureWidget(
        Container(
          width: 550,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ॐ', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                  const Text('ಸಾಮಾನು ಪಟ್ಟಿ / GROCERY LIST', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(thickness: 2),
              Text('ದಿನಾಂಕ (Date): $eventDateStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      );

      if (headerBytes != null) {
        currentPageWidgets.add(pw.Image(pw.MemoryImage(headerBytes)));
        currentPageWidgets.add(pw.SizedBox(height: 8));
      }

      // Process each category
      Future<void> processCategory(String title, List<_MergedIngredient> items, Color color) async {
        if (items.isEmpty) return;

        // Category header
        final categoryHeaderBytes = await captureWidget(
          Container(
            width: 550,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            color: color,
            child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        );

        // Table header
        final tableHeaderBytes = await captureWidget(
          Container(
            width: 550,
            color: Colors.grey[200],
            child: const Row(
              children: [
                Expanded(flex: 3, child: Padding(padding: EdgeInsets.all(6), child: Text('ಸಾಮಾನು / Ingredient', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                SizedBox(width: 70, child: Padding(padding: EdgeInsets.all(6), child: Text('ಪ್ರಮಾಣ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                SizedBox(width: 50, child: Padding(padding: EdgeInsets.all(6), child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
              ],
            ),
          ),
        );

        // Check if we need a new page before category
        if (itemsOnCurrentPage > maxItemsPerPage - 3) {
          pages.add(_PdfPageData(widgets: List.from(currentPageWidgets), isFirstPage: isFirstPage));
          currentPageWidgets = [];
          itemsOnCurrentPage = 0;
          isFirstPage = false;
        }

        if (categoryHeaderBytes != null) {
          currentPageWidgets.add(pw.Image(pw.MemoryImage(categoryHeaderBytes)));
        }
        if (tableHeaderBytes != null) {
          currentPageWidgets.add(pw.Image(pw.MemoryImage(tableHeaderBytes)));
        }
        itemsOnCurrentPage += 2;

        // Process each item
        for (var item in items) {
          final converted = _convertUnit(item.totalQty, item.unit);
          final rowBytes = await captureWidget(
            Container(
              width: 550,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 0.5))),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Padding(padding: const EdgeInsets.all(6), child: Text('${item.nameKn} (${item.nameEn})', style: const TextStyle(fontSize: 12)))),
                  SizedBox(width: 70, child: Padding(padding: const EdgeInsets.all(6), child: Text(_formatQty(converted['qty'] as double), style: const TextStyle(fontSize: 12)))),
                  SizedBox(width: 50, child: Padding(padding: const EdgeInsets.all(6), child: Text(converted['unit'] as String, style: const TextStyle(fontSize: 12)))),
                ],
              ),
            ),
          );

          if (rowBytes != null) {
            // Check if we need a new page
            if (itemsOnCurrentPage >= maxItemsPerPage) {
              pages.add(_PdfPageData(widgets: List.from(currentPageWidgets), isFirstPage: isFirstPage));
              currentPageWidgets = [];
              itemsOnCurrentPage = 0;
              isFirstPage = false;
              
              // Add continuation header
              final contHeaderBytes = await captureWidget(
                Container(
                  width: 550,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  color: color,
                  child: Text('$title (ಮುಂದುವರೆದಿದೆ)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              );
              if (contHeaderBytes != null) {
                currentPageWidgets.add(pw.Image(pw.MemoryImage(contHeaderBytes)));
              }
              if (tableHeaderBytes != null) {
                currentPageWidgets.add(pw.Image(pw.MemoryImage(tableHeaderBytes)));
              }
              itemsOnCurrentPage += 2;
            }

            currentPageWidgets.add(pw.Image(pw.MemoryImage(rowBytes)));
            itemsOnCurrentPage++;
          }
        }

        currentPageWidgets.add(pw.SizedBox(height: 12));
      }

      // Process all categories
      await processCategory('ದಿನಸಿ (Groceries)', groceriesList, const Color(0xFF009688));
      await processCategory('ತರಕಾರಿ (Vegetables)', vegetablesList, const Color(0xFF4CAF50));
      await processCategory('ಹಾಲು/ಮೊಸರು (Dairy)', dairyList, const Color(0xFF2196F3));

      // Add remaining widgets as last page
      if (currentPageWidgets.isNotEmpty) {
        pages.add(_PdfPageData(widgets: currentPageWidgets, isFirstPage: isFirstPage));
      }

      // Build PDF pages
      for (var page in pages) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (ctx) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: page.widgets,
            ),
          ),
        );
      }

      // Close loading dialog
      Navigator.of(context).pop();

      // Save and share
      final output = await getTemporaryDirectory();
      final filename = suffix.isNotEmpty 
          ? 'Ingredients_${dateForFilename}_$suffix.pdf'
          : 'Ingredients_$dateForFilename.pdf';
      final file = File('${output.path}/$filename');
      await file.writeAsBytes(await pdf.save());

      await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename: filename,
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
  }

  /// Generate Dish List PDF with proper Kannada rendering (for ItemList)
  static Future<void> generateDishListPdf({
    required BuildContext context,
    required List<PlanItem> planItems,
    required int globalPeople,
    DateTime? eventDate,
    String? customSuffix,
  }) async {
    final selectedDate = eventDate ?? DateTime.now();
    final dateForFilename = DateFormat('dd-MMM-yyyy').format(selectedDate);
    final eventDateStr = DateFormat('dd/MM/yyyy').format(selectedDate);
    
    // Ask for custom filename suffix
    String? suffix = customSuffix;
    if (suffix == null) {
      suffix = await _showFilenameDialog(context, 'ItemList_$dateForFilename');
      if (suffix == null) return; // User cancelled
    }

    final screenshotController = ScreenshotController();
    
    // Create the widget to capture
    final contentWidget = _buildDishListWidget(
      eventDateStr: eventDateStr,
      planItems: planItems,
      globalPeople: globalPeople,
    );

    // Capture widget as image
    Uint8List? imageBytes;
    try {
      imageBytes = await screenshotController.captureFromWidget(
        contentWidget,
        context: context,
        pixelRatio: 2.0,
        delay: const Duration(milliseconds: 100),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing content: $e')),
      );
      return;
    }

    if (imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to capture content')),
      );
      return;
    }

    // Create PDF with the captured image
    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context ctx) {
          return pw.Align(
            alignment: pw.Alignment.topCenter,
            child: pw.Image(image, fit: pw.BoxFit.contain),
          );
        },
      ),
    );

    // Save and share
    final output = await getTemporaryDirectory();
    final filename = suffix.isNotEmpty 
        ? 'ItemList_${dateForFilename}_$suffix.pdf'
        : 'ItemList_$dateForFilename.pdf';
    final file = File('${output.path}/$filename');
    await file.writeAsBytes(await pdf.save());

    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: filename,
    );
  }

  /// Show dialog to get custom filename suffix
  static Future<String?> _showFilenameDialog(BuildContext context, String defaultName) async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF Filename'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File: $defaultName.pdf',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text('Add extra text (optional):'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g., Temple, EventName',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Leave empty for: $defaultName.pdf',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Generate PDF'),
          ),
        ],
      ),
    );
  }

  /// Build the Dish List widget for PDF
  static Widget _buildDishListWidget({
    required String eventDateStr,
    required List<PlanItem> planItems,
    required int globalPeople,
  }) {
    return Material(
      color: Colors.white,
      child: Container(
        width: 595, // A4 width in points
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ॐ',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                const Text(
                  'ಅಡುಗೆ ಪಟ್ಟಿ / ITEM LIST',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(thickness: 2),
            const SizedBox(height: 10),
            
            // Date and People
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ದಿನಾಂಕ (Date): $eventDateStr',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'ಜನ (People): $globalPeople',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Plain dishes list
            ...planItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              
              // Check if override is on and different from global
              final hasOverride = item.overridePeople != null && item.overridePeople != globalPeople;
              final peopleText = hasOverride ? ' [${item.overridePeople} ಜನ]' : '';
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(
                  '${index + 1}. ${item.dish.nameKn} (${item.dish.nameEn})$peopleText',
                  style: const TextStyle(fontSize: 16),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  /// Build header widget for PDF
  static Widget _buildHeaderWidget({required String eventDateStr}) {
    return Material(
      color: Colors.white,
      child: Container(
        width: 550,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ॐ',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                const Text(
                  'ಸಾಮಾನು ಪಟ್ಟಿ / GROCERY LIST',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(thickness: 2),
            const SizedBox(height: 8),
            Text(
              'ದಿನಾಂಕ (Date): $eventDateStr',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a single category section widget for PDF
  static Widget _buildCategorySectionWidget(
    String title,
    List<_MergedIngredient> items,
    Color headerColor,
  ) {
    return Material(
      color: Colors.white,
      child: Container(
        width: 550,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              color: headerColor,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Table(
              border: TableBorder.all(color: Colors.grey[300]!),
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FixedColumnWidth(70),
                2: FixedColumnWidth(60),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey[200]),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('ಸಾಮಾನು / Ingredient', 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('ಪ್ರಮಾಣ', 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Unit', 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
                ...items.map((item) {
                  final converted = _convertUnit(item.totalQty, item.unit);
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          '${item.nameKn} (${item.nameEn})',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          _formatQty(converted['qty'] as double),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          converted['unit'] as String,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build the widget content for PDF (legacy - kept for compatibility)
  static Widget _buildPdfContentWidget({
    required String eventDateStr,
    required List<_MergedIngredient> groceriesList,
    required List<_MergedIngredient> vegetablesList,
    required List<_MergedIngredient> dairyList,
  }) {
    return Material(
      color: Colors.white,
      child: Container(
        width: 595, // A4 width in points
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ॐ',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                const Text(
                  'ಅಡುಗೆ ಪಟ್ಟಿ / GROCERY LIST',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(thickness: 2),
            const SizedBox(height: 10),
            
            // Date
            Text(
              'ದಿನಾಂಕ (Date): $eventDateStr',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            
            const Text(
              'ಒಟ್ಟು ಸಾಮಾನುಗಳು / Overall Ingredients',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 10),
            
            // Groceries
            if (groceriesList.isNotEmpty) ...[
              _buildCategorySection(
                'ದಿನಸಿ (Groceries)',
                groceriesList,
                const Color(0xFF009688),
              ),
              const SizedBox(height: 12),
            ],
            
            // Vegetables
            if (vegetablesList.isNotEmpty) ...[
              _buildCategorySection(
                'ತರಕಾರಿ (Vegetables)',
                vegetablesList,
                const Color(0xFF4CAF50),
              ),
              const SizedBox(height: 12),
            ],
            
            // Dairy
            if (dairyList.isNotEmpty) ...[
              _buildCategorySection(
                'ಹಾಲು/ಮೊಸರು (Milk/Curd)',
                dairyList,
                const Color(0xFF2196F3),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _buildCategorySection(
    String title,
    List<_MergedIngredient> items,
    Color headerColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: headerColor,
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        Table(
          border: TableBorder.all(color: Colors.grey[300]!),
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FixedColumnWidth(70),
            2: FixedColumnWidth(60),
          },
          children: [
            // Header row
            TableRow(
              decoration: BoxDecoration(color: Colors.grey[200]),
              children: const [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('ಸಾಮಾನು / Ingredient', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('ಪ್ರಮಾಣ', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Unit', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
            // Data rows
            ...items.map((item) {
              final converted = _convertUnit(item.totalQty, item.unit);
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '${item.nameKn} (${item.nameEn})',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _formatQty(converted['qty'] as double),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      converted['unit'] as String,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  static Map<String, dynamic> _convertUnit(double qty, String unit) {
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

  static String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }
}

class _MergedIngredient {
  final String nameEn;
  final String nameKn;
  final String unit;
  final String category;
  double totalQty;

  _MergedIngredient({
    required this.nameEn,
    required this.nameKn,
    required this.unit,
    required this.category,
    required this.totalQty,
  });
}

class _PageSection {
  final Uint8List bytes;
  final bool isFirstOfCategory;

  _PageSection({
    required this.bytes,
    this.isFirstOfCategory = false,
  });
}

class _CategoryData {
  final String title;
  final List<_MergedIngredient> items;
  final PdfColor color;

  _CategoryData({
    required this.title,
    required this.items,
    required this.color,
  });
}

class _PdfPageData {
  final List<pw.Widget> widgets;
  final bool isFirstPage;

  _PdfPageData({
    required this.widgets,
    this.isFirstPage = false,
  });
}

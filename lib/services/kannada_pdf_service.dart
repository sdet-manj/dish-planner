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
  
  /// Generate Overall PDF using native Flutter rendering via Printing.layoutPdf
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

    final filename = suffix.isNotEmpty 
        ? 'Ingredients_${dateForFilename}_$suffix.pdf'
        : 'Ingredients_$dateForFilename.pdf';

    // Use Printing.layoutPdf for native Flutter rendering with proper Kannada
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        // Build all category items as a flat list for pagination
        List<_MergedIngredient> allItems = [];
        List<String> itemCategories = [];
        
        for (var item in groceriesList) {
          allItems.add(item);
          itemCategories.add('groceries');
        }
        for (var item in vegetablesList) {
          allItems.add(item);
          itemCategories.add('vegetables');
        }
        for (var item in dairyList) {
          allItems.add(item);
          itemCategories.add('dairy');
        }

        // Load Kannada font
        final kannadaFont = await PdfGoogleFonts.notoSansKannadaRegular();
        final kannadaFontBold = await PdfGoogleFonts.notoSansKannadaBold();

        final pdf = pw.Document();
        
        // Build content with proper categories
        final allCategories = <_CategoryData>[];
        if (groceriesList.isNotEmpty) {
          allCategories.add(_CategoryData(title: 'Groceries (ದಿನಸಿ)', items: groceriesList, color: PdfColors.teal));
        }
        if (vegetablesList.isNotEmpty) {
          allCategories.add(_CategoryData(title: 'Vegetables (ತರಕಾರಿ)', items: vegetablesList, color: PdfColors.green));
        }
        if (dairyList.isNotEmpty) {
          allCategories.add(_CategoryData(title: 'Dairy (ಹಾಲು/ಮೊಸರು)', items: dairyList, color: PdfColors.blue));
        }

        pdf.addPage(
          pw.MultiPage(
            pageFormat: format,
            margin: const pw.EdgeInsets.all(24),
            header: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('ॐ', style: pw.TextStyle(font: kannadaFontBold, fontSize: 28, color: PdfColors.deepOrange)),
                    pw.Text('ಸಾಮಾನು ಪಟ್ಟಿ / GROCERY LIST', style: pw.TextStyle(font: kannadaFontBold, fontSize: 14)),
                  ],
                ),
                pw.Divider(thickness: 2),
                pw.Text('ದಿನಾಂಕ (Date): $eventDateStr', style: pw.TextStyle(font: kannadaFontBold, fontSize: 11)),
                pw.SizedBox(height: 8),
              ],
            ),
            footer: (context) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', 
                  style: pw.TextStyle(font: kannadaFont, fontSize: 10)),
              ],
            ),
            build: (context) {
              List<pw.Widget> widgets = [];
              
              for (var category in allCategories) {
                // Category header
                widgets.add(pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  color: category.color,
                  child: pw.Text(category.title, 
                    style: pw.TextStyle(font: kannadaFontBold, fontSize: 12, color: PdfColors.white)),
                ));
                
                // Table
                widgets.add(pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FixedColumnWidth(60),
                    2: const pw.FixedColumnWidth(50),
                  },
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('ಸಾಮಾನು / Ingredient', 
                            style: pw.TextStyle(font: kannadaFontBold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('ಪ್ರಮಾಣ', 
                            style: pw.TextStyle(font: kannadaFontBold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('Unit', 
                            style: pw.TextStyle(font: kannadaFontBold, fontSize: 10)),
                        ),
                      ],
                    ),
                    // Data rows
                    ...category.items.map((item) {
                      final converted = _convertUnit(item.totalQty, item.unit);
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('${item.nameKn} (${item.nameEn})', 
                              style: pw.TextStyle(font: kannadaFont, fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(_formatQty(converted['qty'] as double), 
                              style: pw.TextStyle(font: kannadaFont, fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(converted['unit'] as String, 
                              style: pw.TextStyle(font: kannadaFont, fontSize: 10)),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ));
                
                widgets.add(pw.SizedBox(height: 12));
              }
              
              return widgets;
            },
          ),
        );

        return pdf.save();
      },
      name: filename,
      format: PdfPageFormat.a4,
    );
  }

  /// Fallback PDF generation using PDF package directly (when screenshots fail)
  static Future<void> _generatePdfFallback({
    required BuildContext context,
    required List<_MergedIngredient> groceriesList,
    required List<_MergedIngredient> vegetablesList,
    required List<_MergedIngredient> dairyList,
    required String eventDateStr,
    required String dateForFilename,
    required String suffix,
  }) async {
    final kannadaFont = await PdfGoogleFonts.notoSansKannadaRegular();
    final kannadaFontBold = await PdfGoogleFonts.notoSansKannadaBold();
    
    final pdf = pw.Document();
    
    final allCategories = <_CategoryData>[];
    if (groceriesList.isNotEmpty) {
      allCategories.add(_CategoryData(title: 'Groceries', items: groceriesList, color: PdfColors.teal));
    }
    if (vegetablesList.isNotEmpty) {
      allCategories.add(_CategoryData(title: 'Vegetables', items: vegetablesList, color: PdfColors.green));
    }
    if (dairyList.isNotEmpty) {
      allCategories.add(_CategoryData(title: 'Dairy', items: dairyList, color: PdfColors.blue));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('OM', style: pw.TextStyle(font: kannadaFontBold, fontSize: 24, color: PdfColors.deepOrange)),
                pw.Text('GROCERY LIST', style: pw.TextStyle(font: kannadaFontBold, fontSize: 16)),
              ],
            ),
            pw.Divider(thickness: 2),
            pw.Text('Date: $eventDateStr', style: pw.TextStyle(font: kannadaFontBold, fontSize: 11)),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (context) {
          List<pw.Widget> widgets = [];
          
          for (var category in allCategories) {
            widgets.add(pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(6),
              color: category.color,
              child: pw.Text(category.title, style: pw.TextStyle(font: kannadaFontBold, fontSize: 12, color: PdfColors.white)),
            ));
            
            widgets.add(pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FixedColumnWidth(60),
                2: const pw.FixedColumnWidth(50),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Ingredient', style: pw.TextStyle(font: kannadaFontBold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Qty', style: pw.TextStyle(font: kannadaFontBold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Unit', style: pw.TextStyle(font: kannadaFontBold, fontSize: 10))),
                  ],
                ),
                ...category.items.map((item) {
                  final converted = _convertUnit(item.totalQty, item.unit);
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${item.nameKn} (${item.nameEn})', style: pw.TextStyle(font: kannadaFont, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_formatQty(converted['qty'] as double), style: pw.TextStyle(font: kannadaFont, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(converted['unit'] as String, style: pw.TextStyle(font: kannadaFont, fontSize: 10))),
                    ],
                  );
                }).toList(),
              ],
            ));
            widgets.add(pw.SizedBox(height: 12));
          }
          
          return widgets;
        },
      ),
    );

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

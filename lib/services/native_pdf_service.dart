import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/plan_item.dart';
import '../models/extra_ingredient.dart';

/// Alternative PDF service that renders Kannada text properly
/// by capturing Flutter widgets as images
class NativePdfService {
  
  /// Generate Overall PDF with proper Kannada rendering
  static Future<File> generateOverallPdf({
    required List<PlanItem> planItems,
    List<ExtraIngredient> extraIngredients = const [],
    required int globalPeople,
    DateTime? eventDate,
  }) async {
    final generatedDateStr = DateFormat('dd-MMM-yyyy').format(DateTime.now());
    final eventDateStr = eventDate != null 
        ? DateFormat('dd/MM/yyyy').format(eventDate)
        : DateFormat('dd/MM/yyyy').format(DateTime.now());

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

    // Create PDF
    final pdf = pw.Document();

    // Capture header as image
    final headerImage = await _captureWidgetAsImage(
      _buildHeader(eventDateStr, globalPeople, generatedDateStr),
      width: 550,
    );

    // Capture each category as image
    pw.MemoryImage? groceriesImage;
    pw.MemoryImage? vegetablesImage;
    pw.MemoryImage? dairyImage;

    if (groceriesList.isNotEmpty) {
      groceriesImage = await _captureWidgetAsImage(
        _buildCategoryTable('Groceries', 'ದಿನಸಿ', groceriesList, Colors.teal),
        width: 550,
      );
    }

    if (vegetablesList.isNotEmpty) {
      vegetablesImage = await _captureWidgetAsImage(
        _buildCategoryTable('Vegetables', 'ತರಕಾರಿ', vegetablesList, Colors.green),
        width: 550,
      );
    }

    if (dairyList.isNotEmpty) {
      dairyImage = await _captureWidgetAsImage(
        _buildCategoryTable('Milk/Curd', 'ಹಾಲು/ಮೊಸರು', dairyList, Colors.blue),
        width: 550,
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          final List<pw.Widget> widgets = [];
          
          if (headerImage != null) {
            widgets.add(pw.Image(headerImage));
            widgets.add(pw.SizedBox(height: 10));
          }
          
          if (groceriesImage != null) {
            widgets.add(pw.Image(groceriesImage));
            widgets.add(pw.SizedBox(height: 10));
          }
          
          if (vegetablesImage != null) {
            widgets.add(pw.Image(vegetablesImage));
            widgets.add(pw.SizedBox(height: 10));
          }
          
          if (dairyImage != null) {
            widgets.add(pw.Image(dairyImage));
          }
          
          return widgets;
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/Overall_Native_$generatedDateStr.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Capture a Flutter widget as an image
  static Future<pw.MemoryImage?> _captureWidgetAsImage(Widget widget, {required double width}) async {
    try {
      final repaintBoundary = RenderRepaintBoundary();
      final view = ui.PlatformDispatcher.instance.views.first;
      final renderView = RenderView(
        view: view,
        child: RenderPositionedBox(
          alignment: Alignment.topLeft,
          child: repaintBoundary,
        ),
        configuration: ViewConfiguration(
          size: Size(width, 2000), // Large height to accommodate content
          devicePixelRatio: 3.0,
        ),
      );

      final pipelineOwner = PipelineOwner();
      pipelineOwner.rootNode = renderView;
      renderView.prepareInitialFrame();

      final buildOwner = BuildOwner(focusManager: FocusManager());
      final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
        container: repaintBoundary,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Material(
              color: Colors.white,
              child: widget,
            ),
          ),
        ),
      ).attachToRenderTree(buildOwner);

      buildOwner.buildScope(rootElement);
      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      final image = await repaintBoundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        return pw.MemoryImage(byteData.buffer.asUint8List());
      }
    } catch (e) {
      print('Error capturing widget: $e');
    }
    return null;
  }

  /// Build header widget
  static Widget _buildHeader(String eventDateStr, int globalPeople, String generatedDateStr) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ॐ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Text('ITEM LIST / ಅಡುಗೆ ಪಟ್ಟಿ', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(thickness: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Date (ದಿನಾಂಕ): $eventDateStr',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Text('No. of People (ಜನ): $globalPeople',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Generated: $generatedDateStr', 
            style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          const SizedBox(height: 12),
          const Text('Overall Combined Ingredients',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(thickness: 0.5),
        ],
      ),
    );
  }

  /// Build category table widget
  static Widget _buildCategoryTable(String titleEn, String titleKn, List<_MergedIngredient> items, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            color: color,
            child: Text(
              '$titleEn ($titleKn)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          // Table header
          Container(
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: const Text('Ingredient', 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: const Text('Qty', 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: const Text('Unit', 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          // Table rows
          ...items.map((item) {
            final converted = _convertUnit(item.totalQty, item.unit);
            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: Text('${item.nameEn} (${item.nameKn})', 
                      style: const TextStyle(fontSize: 11)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: Text(_formatQty(converted['qty'] as double), 
                      style: const TextStyle(fontSize: 11)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: Text(converted['unit'] as String, 
                      style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
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


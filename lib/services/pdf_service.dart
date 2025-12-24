import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/plan_item.dart';
import '../models/extra_ingredient.dart';

class PdfService {
  static pw.Font? _kannadaFont;

  // Load font from assets - this ensures Kannada characters render properly
  static Future<pw.Font> _loadKannadaFont() async {
    if (_kannadaFont == null) {
      final fontData = await rootBundle.load('assets/fonts/NotoSansKannada-Regular.ttf');
      _kannadaFont = pw.Font.ttf(fontData);
    }
    return _kannadaFont!;
  }

  // Helper to get display name in format: ಕನ್ನಡ (English)
  static String _getDisplayName(String? nameKn, String? nameEn) {
    final kn = nameKn ?? '';
    final en = nameEn ?? '';
    return '$kn ($en)';
  }

  // Convert units: g→kg if >1000, ml→L if >1000
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
    // Round to 2 decimal places
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  // Public method for preview screen to use the same conversion logic
  static Map<String, dynamic> formatQtyWithUnitConversion(double qty, String unit) {
    return _convertUnit(qty, unit);
  }

  static Future<File> generateDishWisePdf({
    required List<PlanItem> planItems,
    List<ExtraIngredient> extraIngredients = const [],
    required int globalPeople,
  }) async {
    final font = await _loadKannadaFont();
    
    final pdf = pw.Document();
    final dateStr = DateFormat('dd-MMM-yyyy').format(DateTime.now());

    // Use the embedded Kannada font for all text
    final theme = pw.ThemeData.withFont(
      base: font,
      bold: font,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Dish-wise Ingredients',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Generated: $dateStr', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (context) {
          List<pw.Widget> widgets = [];

          // Dishes section
          for (var item in planItems) {
            final effectivePeople = item.getEffectivePeople(globalPeople);
            final dishName = _getDisplayName(item.dish.nameKn, item.dish.nameEn);

            widgets.add(pw.Container(
              margin: const pw.EdgeInsets.only(top: 15, bottom: 5),
              child: pw.Text(
                '$dishName - $effectivePeople people',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ));

            widgets.add(pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Ingredient',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Qty',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Unit',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ...item.ingredients.map((ing) {
                  final rawQty = ing.getScaledQty(effectivePeople);
                  final converted = _convertUnit(rawQty, ing.unit);
                  final qty = converted['qty'] as double;
                  final unit = converted['unit'] as String;
                  
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_getDisplayName(ing.ingredientNameKn, ing.ingredientNameEn)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_formatQty(qty)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(unit),
                      ),
                    ],
                  );
                }),
              ],
            ));
          }

          // Extra ingredients section
          if (extraIngredients.isNotEmpty) {
            widgets.add(pw.Container(
              margin: const pw.EdgeInsets.only(top: 20, bottom: 5),
              child: pw.Text(
                'Extra Ingredients - $globalPeople people',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ));

            widgets.add(pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.orange100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Ingredient',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Qty',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Unit',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ...extraIngredients.map((extra) {
                  final rawQty = extra.getScaledQty(globalPeople);
                  final converted = _convertUnit(rawQty, extra.unit);
                  final qty = converted['qty'] as double;
                  final unit = converted['unit'] as String;
                  
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_getDisplayName(extra.ingredient.nameKn, extra.ingredient.nameEn)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_formatQty(qty)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(unit),
                      ),
                    ],
                  );
                }),
              ],
            ));
          }

          return widgets;
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/Dish-wise_$dateStr.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<File> generateOverallPdf({
    required List<PlanItem> planItems,
    List<ExtraIngredient> extraIngredients = const [],
    required int globalPeople,
  }) async {
    final font = await _loadKannadaFont();
    
    final pdf = pw.Document();
    final dateStr = DateFormat('dd-MMM-yyyy').format(DateTime.now());

    // Merge all ingredients
    final Map<String, _MergedIngredient> merged = {};

    // From dishes
    for (var item in planItems) {
      final effectivePeople = item.getEffectivePeople(globalPeople);
      for (var ing in item.ingredients) {
        final qty = ing.getScaledQty(effectivePeople);
        final key = '${ing.ingredientId}_${ing.unit}';
        if (merged.containsKey(key)) {
          merged[key]!.totalQty += qty;
          merged[key]!.usedIn.add(item.dish.nameEn);
        } else {
          merged[key] = _MergedIngredient(
            ingredientId: ing.ingredientId,
            nameEn: ing.ingredientNameEn ?? '',
            nameKn: ing.ingredientNameKn ?? '',
            unit: ing.unit,
            totalQty: qty,
            usedIn: [item.dish.nameEn],
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
        if (!merged[key]!.usedIn.contains('Extra')) {
          merged[key]!.usedIn.add('Extra');
        }
      } else {
        merged[key] = _MergedIngredient(
          ingredientId: extra.ingredient.id!,
          nameEn: extra.ingredient.nameEn,
          nameKn: extra.ingredient.nameKn,
          unit: extra.unit,
          totalQty: qty,
          usedIn: ['Extra'],
        );
      }
    }

    final mergedList = merged.values.toList()
      ..sort((a, b) => a.nameEn.compareTo(b.nameEn));

    // Use the embedded Kannada font for all text
    final theme = pw.ThemeData.withFont(
      base: font,
      bold: font,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Overall Combined Ingredients',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Generated: $dateStr', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (context) {
          return [
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Ingredient',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Total Qty',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Unit',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ...mergedList.map((m) {
                  final converted = _convertUnit(m.totalQty, m.unit);
                  final qty = converted['qty'] as double;
                  final unit = converted['unit'] as String;
                  
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_getDisplayName(m.nameKn, m.nameEn)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_formatQty(qty)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(unit),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/Overall_$dateStr.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}

class _MergedIngredient {
  final int ingredientId;
  final String nameEn;
  final String nameKn;
  final String unit;
  double totalQty;
  List<String> usedIn;

  _MergedIngredient({
    required this.ingredientId,
    required this.nameEn,
    required this.nameKn,
    required this.unit,
    required this.totalQty,
    required this.usedIn,
  });
}

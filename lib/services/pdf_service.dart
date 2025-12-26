import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/plan_item.dart';
import '../models/extra_ingredient.dart';

class PdfService {
  static pw.Font? _kannadaFont;
  static pw.Font? _englishFont;

  // Load fonts - try Google Fonts first (better shaping), fallback to local
  static Future<void> _loadFonts() async {
    if (_kannadaFont == null) {
      try {
        // Try Tiro Kannada which is designed for better Kannada readability
        _kannadaFont = await PdfGoogleFonts.tiroKannadaRegular();
        _englishFont = await PdfGoogleFonts.notoSansRegular();
      } catch (e) {
        try {
          // Fallback to NotoSerifKannada
          _kannadaFont = await PdfGoogleFonts.notoSerifKannadaRegular();
          _englishFont = await PdfGoogleFonts.notoSansRegular();
        } catch (e2) {
          // Final fallback to local font if network unavailable
          final fontData = await rootBundle.load('assets/fonts/NotoSansKannada-Regular.ttf');
          _kannadaFont = pw.Font.ttf(fontData);
          _englishFont = _kannadaFont;
        }
      }
    }
  }

  static Future<pw.Font> _getKannadaFont() async {
    await _loadFonts();
    return _kannadaFont!;
  }

  static Future<pw.Font?> _getEnglishFont() async {
    await _loadFonts();
    return _englishFont;
  }

  // Helper to get display name
  // Option 1: English only (guaranteed quality)
  static String _getDisplayNameEnglishOnly(String? nameKn, String? nameEn) {
    return nameEn ?? '';
  }
  
  // Option 2: Try both languages (may have rendering issues)
  static String _getDisplayNameBoth(String? nameKn, String? nameEn) {
    final kn = nameKn ?? '';
    final en = nameEn ?? '';
    return '$en ($kn)';
  }
  
  // Current default - use English only for reliable PDF
  static String _getDisplayName(String? nameKn, String? nameEn) {
    return _getDisplayNameEnglishOnly(nameKn, nameEn);
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
    DateTime? eventDate,
  }) async {
    final kannadaFont = await _getKannadaFont();
    final englishFont = await _getEnglishFont();
    
    final pdf = pw.Document();
    final generatedDateStr = DateFormat('dd-MMM-yyyy').format(DateTime.now());
    final eventDateStr = eventDate != null 
        ? DateFormat('dd/MM/yyyy').format(eventDate)
        : DateFormat('dd/MM/yyyy').format(DateTime.now());

    // Use Kannada font with English fallback for mixed text
    final theme = pw.ThemeData.withFont(
      base: kannadaFont,
      bold: kannadaFont,
      fontFallback: englishFont != null ? [englishFont] : null,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('ॐ',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text('ITEM LIST / ಅಡುಗೆ ಪಟ್ಟಿ',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date (ದಿನಾಂಕ): $eventDateStr',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('No. of People (ಜನ): $globalPeople',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text('Generated: $generatedDateStr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 10),
            pw.Text('Dish-wise Ingredients',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Divider(thickness: 0.5),
          ],
        ),
        build: (context) {
          List<pw.Widget> widgets = [];

          // Dishes section
          for (var item in planItems) {
            final effectivePeople = item.getEffectivePeople(globalPeople);
            final dishName = _getDisplayName(item.dish.nameKn, item.dish.nameEn);

            widgets.add(pw.Container(
              margin: const pw.EdgeInsets.only(top: 12, bottom: 5),
              child: pw.Text(
                '$dishName - $effectivePeople people',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
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
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Qty',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Unit',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
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
                        child: pw.Text(_getDisplayName(ing.ingredientNameKn, ing.ingredientNameEn),
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_formatQty(qty), style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(unit, style: const pw.TextStyle(fontSize: 10)),
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
                'Extra Ingredients (ಹೆಚ್ಚುವರಿ ದಿನಸಿ) - $globalPeople people',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
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
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Qty',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Unit',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
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
                        child: pw.Text(_getDisplayName(extra.ingredient.nameKn, extra.ingredient.nameEn),
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_formatQty(qty), style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(unit, style: const pw.TextStyle(fontSize: 10)),
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
    final file = File('${output.path}/Dish-wise_$generatedDateStr.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<File> generateOverallPdf({
    required List<PlanItem> planItems,
    List<ExtraIngredient> extraIngredients = const [],
    required int globalPeople,
    DateTime? eventDate,
  }) async {
    final kannadaFont = await _getKannadaFont();
    final englishFont = await _getEnglishFont();
    
    final pdf = pw.Document();
    final generatedDateStr = DateFormat('dd-MMM-yyyy').format(DateTime.now());
    final eventDateStr = eventDate != null 
        ? DateFormat('dd/MM/yyyy').format(eventDate)
        : DateFormat('dd/MM/yyyy').format(DateTime.now());

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
          merged[key]!.usedIn.add(item.dish.nameEn ?? item.dish.nameKn);
        } else {
          merged[key] = _MergedIngredient(
            ingredientId: ing.ingredientId,
            nameEn: ing.ingredientNameEn ?? '',
            nameKn: ing.ingredientNameKn ?? '',
            unit: ing.unit,
            category: ing.ingredientCategory ?? 'dinasi',
            totalQty: qty,
            usedIn: [item.dish.nameEn ?? item.dish.nameKn],
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
          nameEn: extra.ingredient.nameEn ?? '',
          nameKn: extra.ingredient.nameKn,
          unit: extra.unit,
          category: extra.ingredient.category.name,
          totalQty: qty,
          usedIn: ['Extra'],
        );
      }
    }

    // Group by category
    final dinasiList = merged.values.where((m) => m.category == 'dinasi').toList()
      ..sort((a, b) => a.nameEn.compareTo(b.nameEn));
    final vegetableList = merged.values.where((m) => m.category == 'vegetable').toList()
      ..sort((a, b) => a.nameEn.compareTo(b.nameEn));
    final dairyList = merged.values.where((m) => m.category == 'dairy').toList()
      ..sort((a, b) => a.nameEn.compareTo(b.nameEn));

    // Use Kannada font with English fallback for mixed text
    final theme = pw.ThemeData.withFont(
      base: kannadaFont,
      bold: kannadaFont,
      fontFallback: englishFont != null ? [englishFont] : null,
    );

    // Helper to build a category table
    pw.Widget buildCategoryTable(String titleEn, String titleKn, List<_MergedIngredient> items, PdfColor headerColor) {
      if (items.isEmpty) return pw.SizedBox();
      
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            color: headerColor,
            child: pw.Text(
              titleEn, // English only for reliable rendering
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            ),
          ),
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
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Qty',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Unit',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
              ...items.map((m) {
                final converted = _convertUnit(m.totalQty, m.unit);
                final qty = converted['qty'] as double;
                final unit = converted['unit'] as String;
                
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(_getDisplayName(m.nameKn, m.nameEn),
                          style: const pw.TextStyle(fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(_formatQty(qty), style: const pw.TextStyle(fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(unit, style: const pw.TextStyle(fontSize: 10)),
                    ),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 15),
        ],
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('ॐ',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text('ITEM LIST / ಅಡುಗೆ ಪಟ್ಟಿ',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date (ದಿನಾಂಕ): $eventDateStr',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('No. of People (ಜನ): $globalPeople',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text('Generated: $generatedDateStr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 10),
            pw.Text('Overall Combined Ingredients',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Divider(thickness: 0.5),
          ],
        ),
        build: (context) {
          return [
            // Groceries (ದಿನಸಿ) section
            buildCategoryTable('Groceries', 'ದಿನಸಿ', dinasiList, PdfColors.teal),
            
            // Vegetables section  
            buildCategoryTable('Vegetables', 'ತರಕಾರಿ', vegetableList, PdfColors.green),
            
            // Dairy (Milk/Curd) section
            buildCategoryTable('Milk/Curd', 'ಹಾಲು/ಮೊಸರು', dairyList, PdfColors.blue),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/Overall_$generatedDateStr.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Generate PDF with just the list of selected dishes (no ingredients)
  static Future<File> generateDishListPdf({
    required List<PlanItem> planItems,
    required int globalPeople,
    DateTime? eventDate,
  }) async {
    final kannadaFont = await _getKannadaFont();
    final englishFont = await _getEnglishFont();
    
    final pdf = pw.Document();
    final generatedDateStr = DateFormat('dd-MMM-yyyy').format(DateTime.now());
    final eventDateStr = eventDate != null 
        ? DateFormat('dd/MM/yyyy').format(eventDate)
        : DateFormat('dd/MM/yyyy').format(DateTime.now());

    // Use Kannada font with English fallback for mixed text
    final theme = pw.ThemeData.withFont(
      base: kannadaFont,
      bold: kannadaFont,
      fontFallback: englishFont != null ? [englishFont] : null,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('ॐ',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.Text('ITEM LIST / ಅಡುಗೆ ಪಟ್ಟಿ',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date (ದಿನಾಂಕ): $eventDateStr',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('No. of People (ಜನ): $globalPeople',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text('Generated: $generatedDateStr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 10),
            pw.Text('Selected Dishes',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Divider(thickness: 0.5),
          ],
        ),
        build: (context) {
          return [
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.5),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.teal100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('#',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Dish Name',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('People',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                ...planItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final effectivePeople = item.getEffectivePeople(globalPeople);
                  
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${index + 1}', style: const pw.TextStyle(fontSize: 11)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(_getDisplayName(item.dish.nameKn, item.dish.nameEn),
                            style: const pw.TextStyle(fontSize: 11)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('$effectivePeople', style: const pw.TextStyle(fontSize: 11)),
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Text(
                'Total Dishes: ${planItems.length}',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/DishList_$generatedDateStr.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}

class _MergedIngredient {
  final int ingredientId;
  final String nameEn;
  final String nameKn;
  final String unit;
  final String category; // dinasi, vegetable, dairy
  double totalQty;
  List<String> usedIn;

  _MergedIngredient({
    required this.ingredientId,
    required this.nameEn,
    required this.nameKn,
    required this.unit,
    required this.category,
    required this.totalQty,
    required this.usedIn,
  });
}

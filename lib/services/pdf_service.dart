import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/plan_item.dart';

class PdfService {
  // Use Noto Sans Kannada which supports both Kannada and English
  static Future<pw.Font> _getFont() async {
    return await PdfGoogleFonts.notoSansKannadaRegular();
  }

  static Future<pw.Font> _getBoldFont() async {
    return await PdfGoogleFonts.notoSansKannadaBold();
  }

  // Helper to get display name in format: ಕನ್ನಡ (English)
  static String _getDisplayName(String? nameKn, String? nameEn) {
    final kn = nameKn ?? '';
    final en = nameEn ?? '';
    return '$kn ($en)';
  }

  static Future<File> generateDishWisePdf({
    required List<PlanItem> planItems,
    required int globalPeople,
  }) async {
    final font = await _getFont();
    final boldFont = await _getBoldFont();
    final pdf = pw.Document();
    final dateStr = DateFormat('dd-MMM-yyyy').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Dish-wise Ingredients / ಖಾದ್ಯ ಪದಾರ್ಥಗಳು',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Generated: $dateStr', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (context) {
          List<pw.Widget> widgets = [];

          for (var item in planItems) {
            final effectivePeople = item.getEffectivePeople(globalPeople);
            final dishName = _getDisplayName(item.dish.nameKn, item.dish.nameEn);

            widgets.add(pw.Container(
              margin: const pw.EdgeInsets.only(top: 15, bottom: 5),
              child: pw.Text(
                '$dishName — $effectivePeople people',
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
                      child: pw.Text('Ingredient / ಪದಾರ್ಥ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Qty / ಪ್ರಮಾಣ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Unit / ಏಕಮಾನ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ...item.ingredients.map((ing) {
                  final qty = ing.getScaledQty(effectivePeople);
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
                        child: pw.Text(ing.unit),
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
    required int globalPeople,
  }) async {
    final font = await _getFont();
    final boldFont = await _getBoldFont();
    final pdf = pw.Document();
    final dateStr = DateFormat('dd-MMM-yyyy').format(DateTime.now());

    // Merge all ingredients
    final Map<int, _MergedIngredient> merged = {};

    for (var item in planItems) {
      final effectivePeople = item.getEffectivePeople(globalPeople);
      for (var ing in item.ingredients) {
        final qty = ing.getScaledQty(effectivePeople);
        final key = ing.ingredientId;
        if (merged.containsKey(key)) {
          merged[key]!.totalQty += qty;
          merged[key]!.usedIn.add(item.dish.nameEn);
        } else {
          merged[key] = _MergedIngredient(
            ingredientId: key,
            nameEn: ing.ingredientNameEn ?? '',
            nameKn: ing.ingredientNameKn ?? '',
            unit: ing.unit,
            totalQty: qty,
            usedIn: [item.dish.nameEn],
          );
        }
      }
    }

    final mergedList = merged.values.toList()
      ..sort((a, b) => a.nameEn.compareTo(b.nameEn));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Overall Combined Ingredients / ಒಟ್ಟು ಪದಾರ್ಥಗಳು',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
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
                      child: pw.Text('Ingredient / ಪದಾರ್ಥ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Total Qty / ಒಟ್ಟು',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Unit / ಏಕಮಾನ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ...mergedList.map((m) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_getDisplayName(m.nameKn, m.nameEn)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(_formatQty(m.totalQty)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(m.unit),
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

  static String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2);
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

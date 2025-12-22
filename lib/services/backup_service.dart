import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

class BackupService {
  static Future<File?> exportBackup() async {
    try {
      final data = await DatabaseHelper.instance.exportAll();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      
      final dateStr = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/dish_planner_backup_$dateStr.json');
      await file.writeAsString(jsonStr);
      
      return file;
    } catch (e) {
      return null;
    }
  }

  static Future<void> shareBackup(File file) async {
    await Share.shareXFiles([XFile(file.path)], text: 'Dish Planner Backup');
  }

  static Future<bool> importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (result == null || result.files.single.path == null) {
        return false;
      }
      
      final file = File(result.files.single.path!);
      final jsonStr = await file.readAsString();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      // Validate structure
      if (!data.containsKey('ingredients') || 
          !data.containsKey('dishes') || 
          !data.containsKey('dishIngredients')) {
        return false;
      }
      
      await DatabaseHelper.instance.importAll(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, int>> getBackupStats(String jsonStr) async {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return {
        'ingredients': (data['ingredients'] as List).length,
        'dishes': (data['dishes'] as List).length,
        'dishIngredients': (data['dishIngredients'] as List).length,
      };
    } catch (e) {
      return {'ingredients': 0, 'dishes': 0, 'dishIngredients': 0};
    }
  }
}


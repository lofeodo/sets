import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/exercise_day_log.dart';
import 'local_db_provider.dart';

final exerciseLogsProvider = FutureProvider<List<ExerciseDayLog>>((ref) async {
  final db = ref.watch(localDbProvider);
  return db.loadExerciseLogs();
});
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/session_log.dart';
import '../storage/local_db.dart';

final localDbProvider = Provider<LocalDb>((ref) => LocalDb());

final sessionsProvider = FutureProvider<List<SessionLog>>((ref) async {
  final db = ref.watch(localDbProvider);
  return db.loadSessions();
});
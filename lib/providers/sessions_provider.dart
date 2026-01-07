import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/session_log.dart';
import 'local_db_provider.dart';

final sessionsProvider = FutureProvider<List<SessionLog>>((ref) async {
  final db = ref.watch(localDbProvider);
  return db.loadSessions();
});
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/local_db.dart';

final localDbProvider = Provider<LocalDb>((ref) => LocalDb());
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SessionStatus { unknown, active, expired }

final sessionStatusProvider = StateProvider<SessionStatus>((ref) => SessionStatus.unknown);

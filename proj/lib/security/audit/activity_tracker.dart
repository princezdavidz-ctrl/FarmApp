import 'audit_event.dart';
import 'audit_logger.dart';

class ActivityTracker {
	const ActivityTracker(this.logger);
	final AuditLogger logger;
	Future<void> track(String action, {String? userId}) => logger.log(AuditEvent(action: action, timestamp: DateTime.now(), userId: userId));
}

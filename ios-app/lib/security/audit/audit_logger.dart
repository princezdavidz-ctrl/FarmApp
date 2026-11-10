import 'audit_event.dart';

abstract interface class AuditLogger {
	Future<void> log(AuditEvent event);
}

class InMemoryAuditLogger implements AuditLogger {
	final events = <AuditEvent>[];
	@override
	Future<void> log(AuditEvent event) async => events.add(event);
}

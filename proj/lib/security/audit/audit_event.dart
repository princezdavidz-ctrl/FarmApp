class AuditEvent {
	const AuditEvent({required this.action, required this.timestamp, this.userId});
	final String action;
	final DateTime timestamp;
	final String? userId;
}

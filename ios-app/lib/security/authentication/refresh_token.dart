import '../session/session_manager.dart';

class RefreshTokenLifecycle {
	const RefreshTokenLifecycle({required this.sessionManager});
	final SessionManager sessionManager;

	Future<bool> shouldRefresh() async => !(await sessionManager.isValid());
}

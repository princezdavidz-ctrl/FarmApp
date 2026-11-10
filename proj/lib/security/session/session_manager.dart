import '../authentication/auth_service.dart';

class SessionManager {
	SessionManager(this._authService);

	final AuthService _authService;
	static const sessionDuration = Duration(hours: 12);

	Future<void> markActive() async {
		await _authService.setSessionTimestamp(DateTime.now());
	}

	Future<bool> isValid() async {
		final timestamp = await _authService.readSessionTimestamp();
		return timestamp != null && DateTime.now().difference(timestamp) < sessionDuration;
	}
}

import 'dart:async';

class InactivityTimer {
	InactivityTimer({required this.timeout, required this.onExpired});
	final Duration timeout;
	final void Function() onExpired;
	Timer? _timer;

	void reset() {
		_timer?.cancel();
		_timer = Timer(timeout, onExpired);
	}

	void dispose() => _timer?.cancel();
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/feed/data/feed_reminder_service.dart';

void main() {
  test(
    'notification sound preference configures platform notification sounds',
    () {
      final defaultSound = FeedReminderService.notificationDetailsForSound(
        'default',
      );
      expect(
        defaultSound.android!.channelId,
        'feed_schedule_reminders_default',
      );
      expect(defaultSound.android!.playSound, isTrue);
      expect(defaultSound.android!.sound, isNull);
      expect(defaultSound.iOS!.sound, 'default');
      expect(defaultSound.iOS!.presentSound, isTrue);

      final chime = FeedReminderService.notificationDetailsForSound('chime');
      expect(chime.android!.sound, isA<RawResourceAndroidNotificationSound>());
      expect(chime.android!.sound!.sound, 'feed_chime');
      expect(chime.iOS!.sound, 'feed_chime.wav');

      final alert = FeedReminderService.notificationDetailsForSound('alert');
      expect(alert.android!.sound, isA<RawResourceAndroidNotificationSound>());
      expect(alert.android!.sound!.sound, 'feed_alert');
      expect(alert.iOS!.sound, 'feed_alert.wav');

      final silent = FeedReminderService.notificationDetailsForSound('silent');
      expect(silent.android!.playSound, isFalse);
      expect(silent.iOS!.presentSound, isFalse);
    },
  );

  test('rejects unsupported notification sounds', () {
    expect(
      () => FeedReminderService.notificationDetailsForSound('unknown'),
      throwsArgumentError,
    );
  });
}

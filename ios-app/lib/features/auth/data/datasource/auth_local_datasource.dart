import '../../domain/entities/farm.dart';
import '../../domain/entities/session.dart';

abstract interface class AuthLocalDataSource {
  Future<void> saveSession(Session session);
  Future<Session?> readSession();
  Future<void> saveSelectedFarm(Farm farm);
  Future<void> clear();
}

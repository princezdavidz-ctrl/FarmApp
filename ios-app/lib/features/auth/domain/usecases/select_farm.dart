import '../entities/farm.dart';
import '../entities/session.dart';
import '../repositories/auth_repository.dart';

class SelectFarm {
  const SelectFarm(this.repository);
  final AuthRepository repository;
  Future<Session> call(Farm farm) => repository.selectFarm(farm);
}

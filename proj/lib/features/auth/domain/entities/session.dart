import 'farm.dart';
import 'user.dart';

class Session {
  const Session({required this.accessToken, required this.refreshToken, required this.user, required this.farms, this.selectedFarm});

  final String accessToken;
  final String refreshToken;
  final User user;
  final List<Farm> farms;
  final Farm? selectedFarm;
}

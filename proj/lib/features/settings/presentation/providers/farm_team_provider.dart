import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/farm_team_api.dart';
import '../../domain/entities/farm_join_request.dart';
import '../../../../security/authorization/roles.dart';
import 'farm_access_provider.dart';

final farmTeamApiProvider = Provider<FarmTeamApi>(
  (ref) => FarmTeamApi(ref.watch(dioProvider)),
);

final farmTeamProvider = AsyncNotifierProvider<FarmTeamNotifier, FarmTeamState>(
  FarmTeamNotifier.new,
);

class FarmTeamState {
  const FarmTeamState({
    this.myRequests = const [],
    this.farmRequests = const [],
  });

  final List<FarmJoinRequest> myRequests;
  final List<FarmJoinRequest> farmRequests;
}

class FarmTeamNotifier extends AsyncNotifier<FarmTeamState> {
  @override
  Future<FarmTeamState> build() async {
    final session = ref.watch(authProvider).valueOrNull;
    final myRequests = await ref.watch(farmTeamApiProvider).fetchMyRequests();
    final farmId = session?.selectedFarm?.id;
    if (farmId == null || session?.user.role != UserRole.farmOwner) {
      return FarmTeamState(myRequests: myRequests);
    }
    final farmRequests = await ref
        .watch(farmTeamApiProvider)
        .fetchFarmRequests(farmId);
    return FarmTeamState(myRequests: myRequests, farmRequests: farmRequests);
  }

  Future<void> requestToJoin(String inviteCode, {String? message}) async {
    await ref
        .read(farmTeamApiProvider)
        .requestToJoin(inviteCode: inviteCode, message: message);
    ref.invalidateSelf();
  }

  Future<void> reviewRequest(String requestId, bool accept) async {
    final farmId = ref.read(authProvider).valueOrNull?.selectedFarm?.id;
    if (farmId == null) return;
    await ref
        .read(farmTeamApiProvider)
        .reviewRequest(farmId: farmId, requestId: requestId, accept: accept);
    ref.invalidateSelf();
    ref.invalidate(farmAccessProvider);
  }
}

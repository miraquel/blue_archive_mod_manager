import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bamm/features/recovery/application/repair_controller.dart';
import 'package:bamm/features/recovery/domain/services/nexon_api_client.dart';
import 'package:bamm/features/recovery/domain/services/repair_diff_engine.dart';
import 'package:bamm/features/recovery/infrastructure/http_nexon_api_client.dart';

final nexonApiClientProvider = Provider<NexonApiClient>((ref) {
  return HttpNexonApiClient();
});

final repairDiffEngineProvider = Provider<RepairDiffEngine>((ref) {
  return const RepairDiffEngine();
});

final repairControllerProvider =
    NotifierProvider<RepairController, RepairState>(RepairController.new);

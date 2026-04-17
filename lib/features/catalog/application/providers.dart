import 'package:bamm/features/catalog/application/mapping_controller.dart';
import 'package:bamm/features/catalog/domain/repositories/mapping_repository.dart';
import 'package:bamm/features/catalog/infrastructure/local_mapping_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final mappingRepositoryProvider = Provider<MappingRepository>((ref) {
  return LocalMappingRepository();
});

final mappingControllerProvider =
    AsyncNotifierProvider<MappingController, MappingState>(
  MappingController.new,
);

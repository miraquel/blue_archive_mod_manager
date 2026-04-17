import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bamm/features/settings/application/validator_index_controller.dart';

final validatorIndexControllerProvider =
    AsyncNotifierProvider<ValidatorIndexController, ValidatorIndexState>(
      ValidatorIndexController.new,
    );

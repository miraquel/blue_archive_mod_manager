enum ModCompatibilityStatus { compatible, needsReview, unsupported }

extension ModCompatibilityStatusX on ModCompatibilityStatus {
  String get label {
    switch (this) {
      case ModCompatibilityStatus.compatible:
        return 'Global Android';
      case ModCompatibilityStatus.needsReview:
        return 'Needs review';
      case ModCompatibilityStatus.unsupported:
        return 'Not in Global Android';
    }
  }
}

class ModCompatibilityAssessment {
  final ModCompatibilityStatus status;
  final String reason;

  const ModCompatibilityAssessment({
    required this.status,
    required this.reason,
  });
}

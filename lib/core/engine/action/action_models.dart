/// A single item in the action catalog.
class TromblAction {
  const TromblAction({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.tags,
    required this.timeRequiredMin,
    required this.energyRequired, // 1=low 2=medium 3=high
    required this.socialRequired, // 1=solo 2=small-group 3=crowd
  });

  final String id;
  final String title;
  final String description;
  final String category; // social|adventure|build|money|selfcare|entertainment|learning
  final List<String> tags; // reuse menu tags: squad|discover|order in|rest|content|solo
  final int timeRequiredMin;
  final int energyRequired;
  final int socialRequired;
}

/// Supported action categories.
abstract final class ActionCategory {
  static const social       = 'social';
  static const adventure    = 'adventure';
  static const build        = 'build';
  static const money        = 'money';
  static const selfcare     = 'selfcare';
  static const entertainment = 'entertainment';
  static const learning     = 'learning';

  static const all = [
    social, adventure, build, money, selfcare, entertainment, learning,
  ];
}

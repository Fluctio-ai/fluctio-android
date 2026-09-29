// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'fluctio';

  @override
  String get navChat => 'Chat';

  @override
  String get navKnowledge => 'Knowledge';

  @override
  String get navWiki => 'Wiki';

  @override
  String get navWorkflow => 'Workflows';

  @override
  String get navSettings => 'Settings';

  @override
  String get comingSoon => 'This module arrives in a later milestone';
}

import 'package:flutter/material.dart';

/// Sport ordering preferences by locale
/// Extracted as constants to reduce duplication and improve maintainability
const List<String> _usOrder = [
  'american_football',
  'basketball',
  'baseball',
  'ice_hockey',
  'soccer',
  'mma',
  'boxing',
  'tennis',
  'cricket',
  'weightlifting',
  'badminton',
  'pool',
  'snooker',
];

const List<String> _canadaOrder = [
  'ice_hockey',
  'american_football',
  'basketball',
  'soccer',
  'baseball',
  'mma',
  'boxing',
  'tennis',
  'cricket',
  'weightlifting',
  'badminton',
  'pool',
  'snooker',
];

const List<String> _ukOrder = [
  'soccer',
  'cricket',
  'boxing',
  'tennis',
  'snooker',
  'mma',
  'basketball',
  'pool',
  'badminton',
  'weightlifting',
  'ice_hockey',
  'american_football',
  'baseball',
];

const List<String> _australiaOrder = [
  'cricket',
  'soccer',
  'tennis',
  'basketball',
  'boxing',
  'mma',
  'american_football',
  'weightlifting',
  'badminton',
  'pool',
  'ice_hockey',
  'snooker',
  'baseball',
];

const List<String> _indiaOrder = [
  'cricket',
  'soccer',
  'badminton',
  'tennis',
  'boxing',
  'mma',
  'weightlifting',
  'basketball',
  'snooker',
  'pool',
  'ice_hockey',
  'american_football',
  'baseball',
];

const List<String> _pakistanOrder = [
  'cricket',
  'soccer',
  'badminton',
  'boxing',
  'snooker',
  'mma',
  'tennis',
  'weightlifting',
  'basketball',
  'pool',
  'ice_hockey',
  'american_football',
  'baseball',
];

const List<String> _euOrder = [
  'soccer',
  'tennis',
  'basketball',
  'ice_hockey',
  'boxing',
  'mma',
  'weightlifting',
  'badminton',
  'pool',
  'snooker',
  'cricket',
  'american_football',
  'baseball',
];

const List<String> _spainOrder = [
  'soccer',
  'basketball',
  'tennis',
  'boxing',
  'mma',
  'weightlifting',
  'badminton',
  'pool',
  'american_football',
  'baseball',
  'ice_hockey',
  'cricket',
  'snooker',
];

const List<String> _germanyOrder = [
  'soccer',
  'ice_hockey',
  'tennis',
  'basketball',
  'boxing',
  'mma',
  'weightlifting',
  'badminton',
  'pool',
  'snooker',
  'american_football',
  'baseball',
  'cricket',
];

const List<String> _italyCountryOrder = [
  'soccer',
  'basketball',
  'tennis',
  'boxing',
  'mma',
  'weightlifting',
  'ice_hockey',
  'pool',
  'badminton',
  'snooker',
  'american_football',
  'baseball',
  'cricket',
];

const List<String> _franceCountryOrder = [
  'soccer',
  'tennis',
  'basketball',
  'boxing',
  'mma',
  'weightlifting',
  'badminton',
  'ice_hockey',
  'pool',
  'snooker',
  'american_football',
  'baseball',
  'cricket',
];

const List<String> _italyLangOrder = [
  'soccer',
  'basketball',
  'tennis',
  'boxing',
  'mma',
  'weightlifting',
  'ice_hockey',
  'pool',
  'badminton',
  'snooker',
  'american_football',
  'baseball',
  'cricket',
];

const List<String> _franceLangOrder = [
  'soccer',
  'tennis',
  'basketball',
  'boxing',
  'mma',
  'weightlifting',
  'badminton',
  'ice_hockey',
  'pool',
  'snooker',
  'american_football',
  'baseball',
  'cricket',
];

const List<String> _spanishOrder = [
  'soccer',
  'basketball',
  'tennis',
  'boxing',
  'mma',
  'badminton',
  'weightlifting',
  'pool',
  'american_football',
  'baseball',
  'ice_hockey',
  'cricket',
  'snooker',
];

const List<String> _hindiOrder = [
  'cricket',
  'soccer',
  'badminton',
  'tennis',
  'boxing',
  'mma',
  'weightlifting',
  'basketball',
  'snooker',
  'pool',
  'ice_hockey',
  'american_football',
  'baseball',
];

const List<String> _urduOrder = [
  'cricket',
  'soccer',
  'badminton',
  'boxing',
  'snooker',
  'mma',
  'tennis',
  'weightlifting',
  'basketball',
  'pool',
  'ice_hockey',
  'american_football',
  'baseball',
];

/// Sports ordering by locale, based on regional popularity
/// Key format: language_COUNTRY (e.g., en_US, de_DE)
/// Falls back to language only if country-specific ordering is not found
const Map<String, List<String>> sportOrderByLocale = {
  // English-speaking regions (country-specific)
  'en_US': _usOrder,
  'en_CA': _canadaOrder,
  'en_GB': _ukOrder,
  'en_AU': _australiaOrder,
  'en_IN': _indiaOrder,
  'en_PK': _pakistanOrder,
  'en_EU': _euOrder,

  // European regions (country-specific)
  'es_ES': _spainOrder,
  'de_DE': _germanyOrder,
  'it_IT': _italyCountryOrder,
  'fr_FR': _franceCountryOrder,

  // Language fallbacks
  'en': _usOrder,
  'es': _spanishOrder,
  'de': _germanyOrder,
  'it': _italyLangOrder,
  'fr': _franceLangOrder,
  'hi': _hindiOrder,
  'ur': _urduOrder,
};

/// Resolve sport IDs in the preferred order for a locale.
///
/// Fallback chain:
/// 1. Full locale, e.g. `en_IN`
/// 2. Language only, e.g. `en`upload
/// 3. English default ordering
List<String> getOrderedSportIdsForLocale(Locale? locale) {
  if (locale == null) {
    return sportOrderByLocale['en']!;
  }

  final fullLocale = '${locale.languageCode}_${locale.countryCode}';

  return sportOrderByLocale[fullLocale] ??
      sportOrderByLocale[locale.languageCode] ??
      sportOrderByLocale['en']!;
}

/// Get the display name for a sport based on its ID
/// Converts snake_case IDs to readable titles (e.g., 'american_football' → 'American Football')
String getDisplayNameForSport(String sportId) {
  switch (sportId) {
    case 'mma':
      return 'MMA';
    case 'mixed_martial_arts':
      return 'Mixed Martial Arts';
    default:
      break;
  }

  return sportId
      .split('_')
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

/// Get the icon for a sport based on its ID
/// Maps sport IDs to Material Design sport icons
IconData getIconForSport(String sportId) {
  switch (sportId) {
    case 'american_football':
      return Icons.sports_football;
    case 'basketball':
      return Icons.sports_basketball;
    case 'baseball':
      return Icons.sports_baseball;
    case 'ice_hockey':
      return Icons.sports_hockey;
    case 'soccer':
      return Icons.sports_soccer;
    case 'tennis':
      return Icons.sports_tennis;
    case 'badminton':
      return Icons.sports_tennis;
    case 'cricket':
      return Icons.sports_baseball;
    case 'pool':
      return Icons.circle;
    case 'snooker':
      return Icons.grain;
    case 'weightlifting':
      return Icons.fitness_center;
    default:
      return Icons.sports;
  }
}

/// Get the bundled image asset for a sport when one exists.
String? getImageAssetPathForSport(String sportId) {
  switch (sportId) {
    case 'american_football':
      return 'assets/american_football_male.jpg';
    case 'badminton':
      return 'assets/badmington.png';
    case 'baseball':
      return 'assets/baseball_male.jpg';
    case 'basketball':
      return 'assets/basketball_male.jpg';
    case 'boxing':
      return 'assets/boxing_male.jpg';
    case 'cricket':
      return 'assets/cricket_male.jpg';
    case 'ice_hockey':
      return 'assets/ice_hockey_male.jpg';
    case 'mma':
    case 'mixed_martial_arts':
      return 'assets/mma_male.png';
    case 'pool':
      return 'assets/pool_male.jpg';
    case 'soccer':
      return 'assets/soccer_male.jpg';
    case 'snooker':
      return 'assets/snooker_male.jpg';
    case 'tennis':
      return 'assets/tennis_male.jpg';
    case 'weightlifting':
      return 'assets/weightlifting_male.jpg';
    default:
      return null;
  }
}

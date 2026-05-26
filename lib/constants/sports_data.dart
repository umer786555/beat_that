import 'package:flutter/material.dart';

/// Sport ordering preferences by locale
/// Extracted as constants to reduce duplication and improve maintainability
const List<String> _usOrder = [
  'american_football',
  'basketball',
  'baseball',
  'ice_hockey',
  'soccer',
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
  'tennis',
  'snooker',
  'ice_hockey',
  'basketball',
  'weightlifting',
  'pool',
  'badminton',
  'american_football',
  'baseball',
];

const List<String> _australiaOrder = [
  'cricket',
  'soccer',
  'tennis',
  'basketball',
  'american_football',
  'weightlifting',
  'badminton',
  'pool',
  'ice_hockey',
  'snooker',
];

const List<String> _indiaOrder = [
  'cricket',
  'badminton',
  'tennis',
  'soccer',
  'weightlifting',
  'basketball',
  'pool',
  'snooker',
  'ice_hockey',
  'american_football',
  'baseball',
];

const List<String> _pakistanOrder = [
  'cricket',
  'badminton',
  'soccer',
  'tennis',
  'weightlifting',
  'basketball',
  'pool',
  'snooker',
  'ice_hockey',
  'american_football',
  'baseball',
];

const List<String> _euOrder = [
  'soccer',
  'tennis',
  'ice_hockey',
  'basketball',
  'weightlifting',
  'badminton',
  'cricket',
  'american_football',
  'baseball',
  'pool',
  'snooker',
];

const List<String> _spainOrder = [
  'soccer',
  'tennis',
  'basketball',
  'ice_hockey',
  'weightlifting',
  'badminton',
  'cricket',
  'american_football',
  'baseball',
  'pool',
  'snooker',
];

const List<String> _germanyOrder = [
  'soccer',
  'ice_hockey',
  'tennis',
  'basketball',
  'weightlifting',
  'badminton',
  'cricket',
  'american_football',
  'baseball',
  'pool',
  'snooker',
];

const List<String> _italyFranceCountryOrder = [
  'soccer',
  'tennis',
  'basketball',
  'ice_hockey',
  'weightlifting',
  'badminton',
  'cricket',
  'american_football',
  'baseball',
  'pool',
  'snooker',
];

const List<String> _italyFranceLangOrder = [
  'soccer',
  'tennis',
  'basketball',
  'badminton',
  'ice_hockey',
  'weightlifting',
  'cricket',
  'american_football',
  'baseball',
  'pool',
  'snooker',
];

const List<String> _spanishOrder = [
  'soccer',
  'tennis',
  'basketball',
  'badminton',
  'ice_hockey',
  'weightlifting',
  'cricket',
  'american_football',
  'baseball',
  'pool',
  'snooker',
];

const List<String> _hindiOrder = [
  'cricket',
  'badminton',
  'tennis',
  'soccer',
  'weightlifting',
  'basketball',
  'pool',
  'snooker',
  'ice_hockey',
  'american_football',
  'baseball',
];

const List<String> _urduOrder = [
  'cricket',
  'badminton',
  'soccer',
  'tennis',
  'weightlifting',
  'basketball',
  'pool',
  'snooker',
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
  'it_IT': _italyFranceCountryOrder,
  'fr_FR': _italyFranceCountryOrder,

  // Language fallbacks
  'en': _usOrder,
  'es': _spanishOrder,
  'de': _germanyOrder,
  'it': _italyFranceLangOrder,
  'fr': _italyFranceLangOrder,
  'hi': _hindiOrder,
  'ur': _urduOrder,
};

/// Get the display name for a sport based on its ID
/// Converts snake_case IDs to readable titles (e.g., 'american_football' → 'American Football')
String getDisplayNameForSport(String sportId) {
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

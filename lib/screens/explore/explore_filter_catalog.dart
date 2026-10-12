import 'package:beat_that/constants/sports_data.dart';
import 'package:beat_that/models/explore_filter_source_row.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

class ExploreFilterOption extends Equatable {
  const ExploreFilterOption({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  @override
  List<Object?> get props => [id, label];
}

class ExploreFilterCatalog extends Equatable {
  const ExploreFilterCatalog({
    required this.sports,
    required this.games,
  });

  const ExploreFilterCatalog.empty()
    : sports = const <ExploreFilterOption>[],
      games = const <ExploreFilterOption>[];

  final List<ExploreFilterOption> sports;
  final List<ExploreFilterOption> games;

  List<ExploreFilterOption> get allOptions {
    return List<ExploreFilterOption>.unmodifiable([...sports, ...games]);
  }

  @override
  List<Object?> get props => [sports, games];

  String labelFor(String? id) {
    final normalizedId = id?.trim();
    if (normalizedId == null || normalizedId.isEmpty) {
      return '';
    }

    for (final option in sports) {
      if (option.id == normalizedId) {
        return option.label;
      }
    }

    for (final option in games) {
      if (option.id == normalizedId) {
        return option.label;
      }
    }

    return getFallbackDisplayNameForFilter(normalizedId);
  }
}

const Map<String, String> _fallbackGameLabelsById = {
  'apex_legends': 'Apex Legends',
  'fifa': 'FIFA',
  'fortnite': 'FORTNITE',
  'grand_theft_auto': 'Grand Theft Auto',
  'league_of_legends': 'League of Legends',
  'minecraft': 'Minecraft',
  'roblox': 'Roblox',
  'rocket_league': 'Rocket League',
  'valorant': 'Valorant',
  'call_of_duty': 'Call of Duty',
  'other_games': 'Other Games',
  'counter_strike': 'Counter Strike',
  'dota': 'Dota',
  'pubg': 'PUBG Battlegrounds',
  'rainbow_six': 'Rainbow Six',
  'marvel_rivals': 'Marvel Rivals',
  'overwatch': 'Overwatch',
  'rust': 'Rust',
  'dead_by_daylight': 'Dead by Daylight',
  'nba_2k': 'NBA 2K',
  'warframe': 'Warframe',
  'warcraft': 'Warcraft',
};

ExploreFilterCatalog buildFallbackExploreFilterCatalog(Locale? locale) {
  final sports = getOrderedSportIdsForLocale(locale)
      .map(
        (sportId) => ExploreFilterOption(
          id: sportId,
          label: getDisplayNameForSport(sportId),
        ),
      )
      .toList(growable: false);

  final games = _sortGameOptions(
    _fallbackGameLabelsById.entries
        .map(
          (entry) => ExploreFilterOption(
            id: entry.key,
            label: entry.value,
          ),
        )
        .toList(growable: false),
  );

  return ExploreFilterCatalog(sports: sports, games: games);
}

ExploreFilterCatalog buildExploreFilterCatalogFromRows({
  required Locale? locale,
  required List<ExploreFilterSourceRow> rows,
}) {
  final orderedSportIds = getOrderedSportIdsForLocale(locale);
  final orderIndexBySportId = <String, int>{
    for (var index = 0; index < orderedSportIds.length; index++)
      orderedSportIds[index]: index,
  };

  final sportOptions = _sortSportOptions(
    _dedupeOptions(
      rows
          .where((row) => row.isSport)
          .map(
            (row) => ExploreFilterOption(
              id: row.name.trim(),
              label: _displayLabelForCategory(
                categoryName: row.name,
                displayName: row.displayName,
              ),
            ),
          )
          .where((option) => option.id.isNotEmpty)
          .toList(),
    ),
    orderIndexBySportId,
    orderedSportIds.length,
  );

  final gameOptions = _sortGameOptions(
    _dedupeOptions(
      rows
          .where((row) => row.isGame)
          .map(
            (row) => ExploreFilterOption(
              id: row.name.trim(),
              label: _displayLabelForCategory(
                categoryName: row.name,
                displayName: row.displayName,
              ),
            ),
          )
          .where((option) => option.id.isNotEmpty)
          .toList(),
    ),
  );

  return ExploreFilterCatalog(sports: sportOptions, games: gameOptions);
}

String getFallbackDisplayNameForFilter(String filterId) {
  return _fallbackGameLabelsById[filterId] ?? getDisplayNameForSport(filterId);
}

String _displayLabelForCategory({
  required String categoryName,
  required String displayName,
}) {
  final normalizedDisplayName = displayName.trim();
  if (normalizedDisplayName.isNotEmpty) {
    return normalizedDisplayName;
  }

  return getFallbackDisplayNameForFilter(categoryName.trim());
}

List<ExploreFilterOption> _sortSportOptions(
  List<ExploreFilterOption> options,
  Map<String, int> orderIndexBySportId,
  int fallbackIndex,
) {
  options.sort((left, right) {
    final leftIsOtherGames = _isOtherGamesOption(left);
    final rightIsOtherGames = _isOtherGamesOption(right);

    if (leftIsOtherGames != rightIsOtherGames) {
      return leftIsOtherGames ? 1 : -1;
    }

    final leftIndex = orderIndexBySportId[left.id] ?? fallbackIndex;
    final rightIndex = orderIndexBySportId[right.id] ?? fallbackIndex;

    if (leftIndex != rightIndex) {
      return leftIndex.compareTo(rightIndex);
    }

    return left.label.toLowerCase().compareTo(right.label.toLowerCase());
  });

  return options;
}

List<ExploreFilterOption> _sortGameOptions(List<ExploreFilterOption> options) {
  options.sort((left, right) {
    final leftIsOtherGames = _isOtherGamesOption(left);
    final rightIsOtherGames = _isOtherGamesOption(right);

    if (leftIsOtherGames != rightIsOtherGames) {
      return leftIsOtherGames ? 1 : -1;
    }

    return left.label.toLowerCase().compareTo(right.label.toLowerCase());
  });

  return options;
}

List<ExploreFilterOption> _dedupeOptions(List<ExploreFilterOption> options) {
  final seenIds = <String>{};
  final uniqueOptions = <ExploreFilterOption>[];

  for (final option in options) {
    if (seenIds.add(option.id)) {
      uniqueOptions.add(option);
    }
  }

  return uniqueOptions;
}

bool _isOtherGamesOption(ExploreFilterOption option) {
  return option.id == 'other_games' ||
      option.label.toLowerCase() == 'other games';
}
class ExploreFilterSourceRow {
  const ExploreFilterSourceRow({
    required this.name,
    required this.displayName,
    required this.kind,
  });

  final String name;
  final String displayName;
  final String kind;

  bool get isSport => kind == 'sport';
  bool get isGame => kind == 'game';

  factory ExploreFilterSourceRow.fromMap(Map<String, dynamic> data) {
    return ExploreFilterSourceRow(
      name: (data['name'] as String? ?? '').trim(),
      displayName: (data['displayName'] as String? ?? '').trim(),
      kind: (data['kind'] as String? ?? '').trim().toLowerCase(),
    );
  }
}

import 'package:beat_that/constants/app_colors.dart';
import 'package:beat_that/constants/sports_data.dart';
import 'package:beat_that/screens/explore/video_feed/widgets/sport_chip.dart';
import 'package:flutter/material.dart';

class SearchHeader extends StatefulWidget {
  const SearchHeader({
    super.key,
    required this.controller,
    required this.selectedSportId,
    required this.availableSportIds,
    required this.onChanged,
    required this.onSportChanged,
    required this.onClearQuery,
    this.onSubmitted,

    this.onFocusChanged,
    this.hintText = '',
    this.labelText = 'Search',
    this.cursorColor = AppColors.cyan,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 6),
    this.spaceBetween = 10,
    this.sportChipSpacing = 8,
  });

  final TextEditingController controller;
  final String? selectedSportId;
  final List<String> availableSportIds;
  final ValueChanged<String> onChanged;
  final ValueChanged<String?> onSportChanged;
  final VoidCallback onClearQuery;
  final VoidCallback? onSubmitted;
  final ValueChanged<bool>? onFocusChanged;
  final String hintText;
  final String labelText;
  final Color cursorColor;
  final EdgeInsets padding;
  final double spaceBetween;
  final double sportChipSpacing;

  @override
  State<SearchHeader> createState() => _SearchHeaderState();
}

class _SearchHeaderState extends State<SearchHeader> {
  static const Duration _animationDuration = Duration(milliseconds: 220);

  late FocusNode _focusNode;
  late bool _isSearchOpen;

  bool get _hasQuery => widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _isSearchOpen = _hasQuery;
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant SearchHeader oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller == widget.controller) {
      return;
    }

    oldWidget.controller.removeListener(_onControllerChanged);
    widget.controller.addListener(_onControllerChanged);

    if (_hasQuery && !_isSearchOpen) {
      _isSearchOpen = true;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    widget.onFocusChanged?.call(_focusNode.hasFocus);
    setState(() {});
  }

  void _onControllerChanged() {
    if (_hasQuery && !_isSearchOpen) {
      setState(() {
        _isSearchOpen = true;
      });
      return;
    }

    setState(() {});
  }

  void _openSearch() {
    if (_isSearchOpen) {
      _focusNode.requestFocus();
      return;
    }

    setState(() {
      _isSearchOpen = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _focusNode.requestFocus();
    });
  }

  void _closeSearch() {
    if (_hasQuery) {
      widget.onClearQuery();
    }

    _focusNode.unfocus();

    if (!_isSearchOpen) {
      return;
    }

    setState(() {
      _isSearchOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipBackgroundColor = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: 0.42);
    final chipBorderColor = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.52,
    );
    final chipSelectedColor = theme.brightness == Brightness.dark
        ? AppColors.cyan.withValues(alpha: 0.78)
        : AppColors.electricMagenta.withValues(alpha: 0.9);
    const chipSelectedLabelColor = AppColors.white;

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isSearchOpen) ...[
            _ExpandedSearchBar(
              key: const ValueKey('expanded-search'),
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              onClearQuery: widget.onClearQuery,
              onClose: _closeSearch,
              hintText: widget.hintText,
              cursorColor: widget.cursorColor,
            ),
            SizedBox(height: widget.spaceBetween),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (!_isSearchOpen)
                    _CollapsedHeader(
                      key: const ValueKey('collapsed-search'),
                      onOpenSearch: _openSearch,
                      labelText: widget.labelText,
                    ),
                  if (!_isSearchOpen) SizedBox(width: widget.sportChipSpacing),
                  SportChip(
                    label: 'All Sports',
                    selected: widget.selectedSportId == null,
                    onSelected: () => widget.onSportChanged(null),
                    selectedColor: chipSelectedColor,
                    selectedLabelColor: chipSelectedLabelColor,
                    unselectedBackgroundColor: chipBackgroundColor,
                    unselectedBorderColor: chipBorderColor,
                    unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                    borderRadius: 999,
                  ),
                  ...widget.availableSportIds.map(
                    (sportId) => Padding(
                      padding: EdgeInsets.only(left: widget.sportChipSpacing),
                      child: SportChip(
                        label: _getDisplayNameForSport(sportId),
                        selected: widget.selectedSportId == sportId,
                        onSelected: () => widget.onSportChanged(sportId),
                        selectedColor: chipSelectedColor,
                        selectedLabelColor: chipSelectedLabelColor,
                        unselectedBackgroundColor: chipBackgroundColor,
                        unselectedBorderColor: chipBorderColor,
                        unselectedLabelColor:
                            theme.colorScheme.onSurfaceVariant,
                        borderRadius: 999,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDisplayNameForSport(String sportId) {
    return getDisplayNameForSport(sportId);
  }
}

class _CollapsedHeader extends StatelessWidget {
  const _CollapsedHeader({
    super.key,
    required this.onOpenSearch,
    required this.labelText,
  });

  final VoidCallback onOpenSearch;
  final String labelText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.88)
        : theme.colorScheme.onSurfaceVariant;
    final borderColor = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.18)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenSearch,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, size: 18, color: foregroundColor),
              const SizedBox(width: 8),
              Text(
                labelText,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedSearchBar extends StatelessWidget {
  const _ExpandedSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClearQuery,
    required this.onClose,
    required this.hintText,
    required this.cursorColor,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmitted;
  final VoidCallback onClearQuery;
  final VoidCallback onClose;
  final String hintText;
  final Color cursorColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuery = controller.text.trim().isNotEmpty;
    final borderColor = theme.brightness == Brightness.dark
        ? AppColors.cyan
        : AppColors.electricMagenta;
    final backgroundColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
        : Colors.white;

    return AnimatedContainer(
      duration: _SearchHeaderState._animationDuration,
      curve: Curves.easeOutCubic,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Theme(
              data: theme.copyWith(
                inputDecorationTheme: const InputDecorationTheme(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  fillColor: Colors.transparent,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              child: TextField(
                cursorColor: cursorColor,
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                onSubmitted: (_) => onSubmitted?.call(),
                textInputAction: TextInputAction.search,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration.collapsed(
                  hintText: hintText,
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          if (hasQuery)
            IconButton(
              onPressed: onClearQuery,
              tooltip: 'Clear search',
              splashRadius: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.cancel_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          IconButton(
            onPressed: onClose,
            tooltip: 'Close search',
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:beat_that/constants/app_colors.dart';

/// A bottom sheet widget for entering and validating video titles
///
/// Provides real-time character count feedback, validation, and visual indicators
/// Supports both light and dark themes with appropriate text color handling
class TitleInputBottomSheet extends StatefulWidget {
  /// Callback when user submits a valid title
  final Function(String) onTitleSubmitted;

  const TitleInputBottomSheet({super.key, required this.onTitleSubmitted});

  @override
  State<TitleInputBottomSheet> createState() => _TitleInputBottomSheetState();
}

class _TitleInputBottomSheetState extends State<TitleInputBottomSheet> {
  // Constants
  static const int _maxCharacters = 50;
  static const double _warningThreshold = 0.9; // 90% of max
  static const BorderRadius _defaultBorderRadius = BorderRadius.all(
    Radius.circular(8),
  );
  static const EdgeInsets _defaultPadding = EdgeInsets.all(24);
  static const EdgeInsets _inputPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  );

  // Controllers and focus
  late TextEditingController _titleController;
  late FocusNode _focusNode;

  // State
  String _errorMessage = '';
  int _characterCount = 0;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _requestFocus();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Initialize text controller and focus node
  void _initializeControllers() {
    _titleController = TextEditingController();
    _focusNode = FocusNode();
    _titleController.addListener(_validateTitle);
  }

  /// Request focus on the input field after widget is built
  void _requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  /// Validate title based on length and content
  void _validateTitle() {
    final title = _titleController.text.trim();
    final isExceeded = title.length > _maxCharacters;

    setState(() {
      _characterCount = _titleController.text.length;
      _isValid = !isExceeded && title.isNotEmpty;
      _errorMessage = isExceeded
          ? 'Title cannot exceed $_maxCharacters characters'
          : '';
    });
  }

  /// Handle title submission
  void _handleSubmit() {
    HapticFeedback.heavyImpact();

    if (_isValid) {
      widget.onTitleSubmitted(_titleController.text.trim());
    }
  }

  /// Build an outline input border with customizable color and width
  InputBorder _buildInputBorder({required Color color, required double width}) {
    return OutlineInputBorder(
      borderRadius: _defaultBorderRadius,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Get text color for character count based on proximity to max
  Color _getCountTextColor(bool isDarkMode) {
    if (_isWarningThresholdExceeded()) {
      return AppColors.orange;
    }
    return isDarkMode ? Colors.white : Colors.black;
  }

  /// Get progress indicator color based on character count
  Color _getProgressIndicatorColor() {
    return _isWarningThresholdExceeded()
        ? AppColors.orange
        : AppColors.electricMagenta;
  }

  /// Check if character count exceeds warning threshold
  bool _isWarningThresholdExceeded() =>
      _characterCount > _maxCharacters * _warningThreshold;

  @override
  Widget build(BuildContext context) {
    final themeColors = _ThemeColors.from(context);

    return SingleChildScrollView(
      child: _buildSheetContainer(
        backgroundColor: themeColors.backgroundColor,
        borderColor: themeColors.borderColor,
        themeColors: themeColors,
      ),
    );
  }

  /// Build the main bottom sheet container with rounded corners
  Widget _buildSheetContainer({
    required Color backgroundColor,
    required Color borderColor,
    required _ThemeColors themeColors,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        border: Border(
          top: BorderSide(color: borderColor, width: 1.5),
          left: BorderSide(color: borderColor, width: 1.5),
          right: BorderSide(color: borderColor, width: 1.5),
        ),
      ),
      child: Padding(
        padding: _defaultPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDragHandle(themeColors.handleBarColor),
            const SizedBox(height: 24),
            _buildHeader(themeColors.textColor),
            const SizedBox(height: 24),
            _buildTitleInput(themeColors),
            const SizedBox(height: 12),
            _buildCharacterCounter(themeColors),
            const SizedBox(height: 12),
            if (_errorMessage.isNotEmpty) ...[
              _buildErrorMessage(),
            ],
            const SizedBox(height: 18),

            _buildSubmitButton(themeColors),
          ],
        ),
      ),
    );
  }

  /// Build the drag handle indicator
  Widget _buildDragHandle(Color color) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  /// Build the header section with title and close button
  Widget _buildHeader(Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Video Title',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Give your video a catchy title',
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: Icon(Icons.close, color: textColor, size: 24),
        ),
      ],
    );
  }

  /// Build the text input field
  Widget _buildTitleInput(_ThemeColors themeColors) {
    return TextField(
      controller: _titleController,
      focusNode: _focusNode,
      maxLength: _maxCharacters,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _handleSubmit(),
      cursorColor: Colors.white,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: themeColors.textColor,
      ),
      decoration: InputDecoration(
        hintText: 'e.g., "Epic Dance Challenge"',
        hintStyle: TextStyle(color: themeColors.inputHintColor, fontSize: 14),
        counterText: '',
        contentPadding: _inputPadding,
        border: _buildInputBorder(
          color: themeColors.inputBorderColor,
          width: 1.5,
        ),
        enabledBorder: _buildInputBorder(
          color: themeColors.inputBorderColor,
          width: 1.5,
        ),
        focusedBorder: _buildInputBorder(
          color: AppColors.electricMagenta,
          width: 2,
        ),
        errorBorder: _buildInputBorder(color: AppColors.red, width: 1.5),
        focusedErrorBorder: _buildInputBorder(color: AppColors.red, width: 2),
      ),
    );
  }

  /// Build character count and progress bar
  Widget _buildCharacterCounter(_ThemeColors themeColors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$_characterCount/$_maxCharacters',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _getCountTextColor(themeColors.isDarkMode),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _characterCount / _maxCharacters,
                minHeight: 4,
                backgroundColor: themeColors.progressBackgroundColor,
                valueColor: AlwaysStoppedAnimation(
                  _getProgressIndicatorColor(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build error message with icon
  Widget _buildErrorMessage() {
    return Row(
      children: [
        Icon(Icons.error_outline, size: 16, color: AppColors.red),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _errorMessage,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Build the submit button
  Widget _buildSubmitButton(_ThemeColors themeColors) {
    return GestureDetector(
      onTap: _isValid ? _handleSubmit : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _isValid
              ? AppColors.electricMagenta
              : themeColors.disabledButtonColor,
          borderRadius: _defaultBorderRadius,
        ),
        child: Text(
          'Save',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _isValid ? Colors.white : themeColors.disabledTextColor,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

/// Helper class to manage theme-specific colors and properties
/// Centralizes all theme logic for light and dark modes
class _ThemeColors {
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final Color handleBarColor;
  final Color inputBorderColor;
  final Color inputHintColor;
  final Color progressBackgroundColor;
  final Color disabledButtonColor;
  final Color disabledTextColor;
  final bool isDarkMode;

  const _ThemeColors({
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    required this.handleBarColor,
    required this.inputBorderColor,
    required this.inputHintColor,
    required this.progressBackgroundColor,
    required this.disabledButtonColor,
    required this.disabledTextColor,
    required this.isDarkMode,
  });

  /// Factory constructor to build theme colors from BuildContext
  factory _ThemeColors.from(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    return _ThemeColors(
      backgroundColor: isDarkMode
          ? Color.lerp(Colors.black, colorScheme.surface, 0.1) ?? Colors.black
          : Colors.white,
      textColor: isDarkMode ? Colors.white : Colors.black,
      borderColor: isDarkMode
          ? colorScheme.onSurface.withValues(alpha: 0.1)
          : AppColors.borderVeryLightGray,
      handleBarColor: isDarkMode
          ? colorScheme.onSurface.withValues(alpha: 0.2)
          : AppColors.greyLight,
      inputBorderColor: isDarkMode
          ? colorScheme.onSurface.withValues(alpha: 0.3)
          : AppColors.greyLight,
      inputHintColor: isDarkMode ? Colors.white70 : Colors.black54,
      progressBackgroundColor: isDarkMode
          ? colorScheme.onSurface.withValues(alpha: 0.1)
          : AppColors.greyLight,
      disabledButtonColor: isDarkMode
          ? colorScheme.surface
          : AppColors.greyLight,
      disabledTextColor: isDarkMode ? Colors.white70 : Colors.black54,
      isDarkMode: isDarkMode,
    );
  }
}

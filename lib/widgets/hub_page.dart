import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Page shell shared by the upload category screen and the sports/gaming
/// hubs: a transparent app bar with a floating back button, a large header,
/// and a scrollable [sliver] body.
class HubPage extends StatelessWidget {
  const HubPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.sliver,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final Widget sliver;

  /// Called by the back button. Defaults to [Navigator.maybePop].
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: _BackButton(
              onPressed: onBack ?? () => Navigator.maybePop(context),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                18,
                MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
                18,
                24,
              ),
              sliver: SliverToBoxAdapter(
                child: _Header(title: title, subtitle: subtitle),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: sliver,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.9,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      child: Tooltip(
        message: MaterialLocalizations.of(context).backButtonTooltip,
        child: Material(
          color: colorScheme.surface.withValues(alpha: 0.86),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 40,
              child: Icon(
                CupertinoIcons.chevron_back,
                size: 19,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

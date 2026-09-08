import 'dart:async';

import 'package:beat_that/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

class OnboardingFlowIds {
  static const String homeFeed = 'home_feed';
  static const String profileScreen = 'profile_screen';
  static const String sportsHub = 'sports_hub';

  static const List<String> all = <String>[homeFeed, profileScreen, sportsHub];
}

class OnboardingStepData {
  final GlobalKey key;
  final String title;
  final String description;

  const OnboardingStepData({
    required this.key,
    required this.title,
    required this.description,
  });
}

class OnboardingFlowRequest {
  final String flowId;
  final int version;
  final List<OnboardingStepData> steps;

  const OnboardingFlowRequest({
    required this.flowId,
    required this.version,
    required this.steps,
  });
}

typedef OnboardingPrelude = Future<bool> Function(BuildContext context);

class OnboardingService {
  static const String _versionSuffix = '_version';
  static const String _completedSuffix = '_completed';

  final PreferencesService _preferencesService;

  OnboardingService({required PreferencesService preferencesService})
    : _preferencesService = preferencesService;

  String _versionKey(String flowId) => 'onboarding_$flowId$_versionSuffix';

  String _completedKey(String flowId) => 'onboarding_$flowId$_completedSuffix';

  bool shouldShow(String flowId, {required int version}) {
    final isCompleted = _preferencesService.getBool(_completedKey(flowId));
    final storedVersion = _preferencesService.getInt(_versionKey(flowId));

    if (!isCompleted) {
      return true;
    }

    return storedVersion != version;
  }

  Future<void> markCompleted(String flowId, {required int version}) async {
    await _preferencesService.setBool(_completedKey(flowId), true);
    await _preferencesService.setInt(_versionKey(flowId), version);
  }

  Future<void> _resetFlow(String flowId) async {
    await _preferencesService.remove(_completedKey(flowId));
    await _preferencesService.remove(_versionKey(flowId));
  }

  Future<void> resetAllFeatureTips([
    List<String> flowIds = OnboardingFlowIds.all,
  ]) async {
    for (final flowId in flowIds) {
      await _resetFlow(flowId);
    }
  }

  Future<bool> startFlow(
    BuildContext context,
    OnboardingFlowRequest request, {
    bool force = false,
    OnboardingPrelude? beforeStart,
    Duration startDelay = const Duration(milliseconds: 250),
  }) async {
    if (!force && !shouldShow(request.flowId, version: request.version)) {
      return false;
    }

    if (beforeStart != null) {
      final shouldContinue = await beforeStart(context);
      if (!shouldContinue) {
        await markCompleted(request.flowId, version: request.version);
        return false;
      }
    }

    final completer = Completer<bool>();
    final showcaseView = ShowcaseView.get();

    late VoidCallback finishListener;
    late OnDismissCallback dismissListener;

    Future<void> completeFlow() async {
      if (completer.isCompleted) {
        return;
      }

      showcaseView.removeOnFinishCallback(finishListener);
      showcaseView.removeOnDismissCallback(dismissListener);
      await markCompleted(request.flowId, version: request.version);
      completer.complete(true);
    }

    finishListener = () {
      unawaited(completeFlow());
    };
    dismissListener = (_) {
      unawaited(completeFlow());
    };

    showcaseView.addOnFinishCallback(finishListener);
    showcaseView.addOnDismissCallback(dismissListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) {
        unawaited(completeFlow());
        return;
      }

      final renderedKeys = request.steps
          .map((step) => step.key)
          .where(showcaseView.isTargetRendered)
          .toList();

      if (renderedKeys.isEmpty) {
        unawaited(completeFlow());
        return;
      }

      showcaseView.startShowCase(renderedKeys, delay: startDelay);
    });

    return completer.future;
  }
}

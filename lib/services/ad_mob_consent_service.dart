import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobConsentService extends ChangeNotifier {
  bool _canRequestAds = false;
  bool _isPrivacyOptionsRequired = false;
  bool _isRequestInFlight = false;

  bool get canRequestAds => _canRequestAds;
  bool get isPrivacyOptionsRequired => _isPrivacyOptionsRequired;

  Future<void> requestConsentInfoUpdate() async {
    if (_isRequestInFlight || kIsWeb) {
      return;
    }

    _isRequestInFlight = true;

    final params = ConsentRequestParameters();

    try {
      await _requestConsentUpdate(params);
      await _refreshState();
      await _loadAndShowConsentFormIfRequired();
      await _refreshState();
    } catch (error) {
      debugPrint('Failed to update AdMob consent information: $error');
      await _refreshState();
    } finally {
      _isRequestInFlight = false;
    }
  }

  Future<String?> showPrivacyOptionsForm() async {
    final completer = Completer<String?>();

    ConsentForm.showPrivacyOptionsForm((formError) async {
      if (formError != null) {
        completer.complete(formError.message);
        return;
      }

      await _refreshState();
      completer.complete(null);
    });

    return completer.future;
  }

  Future<void> _requestConsentUpdate(ConsentRequestParameters params) async {
    final completer = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () {
        completer.complete();
      },
      (FormError error) {
        completer.completeError(error);
      },
    );

    await completer.future;
  }

  Future<void> _loadAndShowConsentFormIfRequired() async {
    final completer = Completer<void>();

    ConsentForm.loadAndShowConsentFormIfRequired((FormError? formError) {
      if (formError != null) {
        debugPrint(
          'AdMob consent form finished with an error: ${formError.message}',
        );
      }

      completer.complete();
    });

    await completer.future;
  }

  Future<void> _refreshState() async {
    final canRequestAds = await ConsentInformation.instance.canRequestAds();
    final privacyOptionsRequirementStatus = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    final isPrivacyOptionsRequired =
        privacyOptionsRequirementStatus ==
        PrivacyOptionsRequirementStatus.required;

    if (_canRequestAds == canRequestAds &&
        _isPrivacyOptionsRequired == isPrivacyOptionsRequired) {
      return;
    }

    _canRequestAds = canRequestAds;
    _isPrivacyOptionsRequired = isPrivacyOptionsRequired;
    notifyListeners();
  }
}

import 'dart:async';
import 'dart:io';

import 'package:huawei_ads/huawei_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

enum AdPlacement {
  continueGame,
  doubleCoins,
  unlockPowerUp,
  gameOverInterstitial,
  levelBreakInterstitial,
}

enum AdNetwork { unity, huawei }

enum AdsBuildVariant { apkpure, huawei }

class AdShowResult {
  const AdShowResult({
    required this.shown,
    required this.rewarded,
    this.network,
    this.message,
  });

  final bool shown;
  final bool rewarded;
  final AdNetwork? network;
  final String? message;

  static const unavailable = AdShowResult(
    shown: false,
    rewarded: false,
    message: 'No ad available right now.',
  );
}

class AdManager {
  static const AdsBuildVariant buildVariant =
      String.fromEnvironment('ADS_VARIANT', defaultValue: 'apkpure') == 'huawei'
      ? AdsBuildVariant.huawei
      : AdsBuildVariant.apkpure;

  static const bool _testMode = bool.fromEnvironment(
    'ADS_TEST_MODE',
    defaultValue: false,
  );

  static const String _unityGameIdAndroid = String.fromEnvironment(
    'UNITY_GAME_ID_ANDROID',
    defaultValue: '6062438',
  );
  static const String _unityGameIdIos = String.fromEnvironment(
    'UNITY_GAME_ID_IOS',
    defaultValue: '6062439',
  );
  static const String _unityInterstitialPlacementId = String.fromEnvironment(
    'UNITY_INTERSTITIAL_PLACEMENT_ID',
    defaultValue: 'Interstitial_Android',
  );
  static const String _unityRewardedPlacementId = String.fromEnvironment(
    'UNITY_REWARDED_PLACEMENT_ID',
    defaultValue: 'Rewarded_Android',
  );

  static const String _huaweiInterstitialSlotId = String.fromEnvironment(
    'HUAWEI_INTERSTITIAL_SLOT_ID',
  );
  static const String _huaweiRewardedSlotId = String.fromEnvironment(
    'HUAWEI_REWARDED_SLOT_ID',
  );

  static bool _didInit = false;
  static bool _unityInitialized = false;
  static bool _huaweiInitialized = false;
  static bool _isShowingAnyAd = false;

  static String get _unityGameId =>
      Platform.isIOS ? _unityGameIdIos : _unityGameIdAndroid;

  static bool get _canUseUnity =>
      _unityGameId.isNotEmpty &&
      _unityInterstitialPlacementId.isNotEmpty &&
      _unityRewardedPlacementId.isNotEmpty;

  static bool get _canUseHuawei =>
      Platform.isAndroid &&
      _huaweiInterstitialSlotId.isNotEmpty &&
      _huaweiRewardedSlotId.isNotEmpty;

  static Future<void> init() async {
    if (_didInit) {
      return;
    }

    if (_canUseUnity) {
      try {
        await UnityAds.init(
          gameId: _unityGameId,
          testMode: _testMode,
          onComplete: () {
            _unityInitialized = true;
          },
          onFailed: (_, __) {
            _unityInitialized = false;
          },
        );
      } catch (_) {
        _unityInitialized = false;
      }
    }

    if (_canUseHuawei) {
      try {
        await HwAds.init();
        _huaweiInitialized = true;
      } catch (_) {
        _huaweiInitialized = false;
      }
    }

    _didInit = true;
  }

  static Future<AdShowResult> showRewarded({
    required AdPlacement placement,
  }) async {
    if (_isShowingAnyAd) {
      return const AdShowResult(
        shown: false,
        rewarded: false,
        message: 'Another ad is already in progress.',
      );
    }

    _isShowingAnyAd = true;
    await init();
    try {
      for (final network in _networkOrder) {
        final result = await _showByNetwork(
          network: network,
          placement: placement,
          rewarded: true,
        );
        if (result.shown) {
          return result;
        }
      }

      return AdShowResult.unavailable;
    } finally {
      _isShowingAnyAd = false;
    }
  }

  static Future<AdShowResult> showInterstitial({
    required AdPlacement placement,
  }) async {
    if (_isShowingAnyAd) {
      return const AdShowResult(
        shown: false,
        rewarded: false,
        message: 'Another ad is already in progress.',
      );
    }

    _isShowingAnyAd = true;
    await init();
    try {
      for (final network in _networkOrder) {
        final result = await _showByNetwork(
          network: network,
          placement: placement,
          rewarded: false,
        );
        if (result.shown) {
          return result;
        }
      }

      return AdShowResult.unavailable;
    } finally {
      _isShowingAnyAd = false;
    }
  }

  static List<AdNetwork> get _networkOrder {
    switch (buildVariant) {
      case AdsBuildVariant.huawei:
        return const [AdNetwork.huawei, AdNetwork.unity];
      case AdsBuildVariant.apkpure:
        return const [AdNetwork.unity, AdNetwork.huawei];
    }
  }

  static Future<AdShowResult> _showByNetwork({
    required AdNetwork network,
    required AdPlacement placement,
    required bool rewarded,
  }) async {
    switch (network) {
      case AdNetwork.unity:
        if (!_unityInitialized) {
          return const AdShowResult(
            shown: false,
            rewarded: false,
            network: AdNetwork.unity,
            message: 'Unity Ads is not initialized.',
          );
        }
        return rewarded ? _showUnityRewarded() : _showUnityInterstitial();
      case AdNetwork.huawei:
        if (!_huaweiInitialized) {
          return const AdShowResult(
            shown: false,
            rewarded: false,
            network: AdNetwork.huawei,
            message: 'Huawei Ads is not initialized.',
          );
        }
        return rewarded
            ? _showHuaweiRewarded(placement)
            : _showHuaweiInterstitial(placement);
    }
  }

  static Future<AdShowResult> _showUnityRewarded() async {
    final completer = Completer<AdShowResult>();
    try {
      await UnityAds.load(
        placementId: _unityRewardedPlacementId,
        onComplete: (_) async {
          try {
            await UnityAds.showVideoAd(
              placementId: _unityRewardedPlacementId,
              onSkipped: (_) {
                if (!completer.isCompleted) {
                  completer.complete(
                    const AdShowResult(
                      shown: true,
                      rewarded: false,
                      network: AdNetwork.unity,
                      message: 'Rewarded ad was skipped.',
                    ),
                  );
                }
              },
              onComplete: (_) {
                if (!completer.isCompleted) {
                  completer.complete(
                    const AdShowResult(
                      shown: true,
                      rewarded: true,
                      network: AdNetwork.unity,
                    ),
                  );
                }
              },
              onFailed: (_, __, message) {
                if (!completer.isCompleted) {
                  completer.complete(
                    AdShowResult(
                      shown: false,
                      rewarded: false,
                      network: AdNetwork.unity,
                      message: message,
                    ),
                  );
                }
              },
            );
          } catch (error) {
            if (!completer.isCompleted) {
              completer.complete(
                AdShowResult(
                  shown: false,
                  rewarded: false,
                  network: AdNetwork.unity,
                  message: error.toString(),
                ),
              );
            }
          }
        },
        onFailed: (_, __, message) {
          if (!completer.isCompleted) {
            completer.complete(
              AdShowResult(
                shown: false,
                rewarded: false,
                network: AdNetwork.unity,
                message: message,
              ),
            );
          }
        },
      );
    } catch (error) {
      return AdShowResult(
        shown: false,
        rewarded: false,
        network: AdNetwork.unity,
        message: error.toString(),
      );
    }

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => const AdShowResult(
        shown: false,
        rewarded: false,
        network: AdNetwork.unity,
        message: 'Unity rewarded ad timed out.',
      ),
    );
  }

  static Future<AdShowResult> _showUnityInterstitial() async {
    final completer = Completer<AdShowResult>();

    try {
      await UnityAds.load(
        placementId: _unityInterstitialPlacementId,
        onComplete: (_) async {
          try {
            await UnityAds.showVideoAd(
              placementId: _unityInterstitialPlacementId,
              onSkipped: (_) {
                if (!completer.isCompleted) {
                  completer.complete(
                    const AdShowResult(
                      shown: true,
                      rewarded: false,
                      network: AdNetwork.unity,
                    ),
                  );
                }
              },
              onComplete: (_) {
                if (!completer.isCompleted) {
                  completer.complete(
                    const AdShowResult(
                      shown: true,
                      rewarded: false,
                      network: AdNetwork.unity,
                    ),
                  );
                }
              },
              onFailed: (_, __, message) {
                if (!completer.isCompleted) {
                  completer.complete(
                    AdShowResult(
                      shown: false,
                      rewarded: false,
                      network: AdNetwork.unity,
                      message: message,
                    ),
                  );
                }
              },
            );
          } catch (error) {
            if (!completer.isCompleted) {
              completer.complete(
                AdShowResult(
                  shown: false,
                  rewarded: false,
                  network: AdNetwork.unity,
                  message: error.toString(),
                ),
              );
            }
          }
        },
        onFailed: (_, __, message) {
          if (!completer.isCompleted) {
            completer.complete(
              AdShowResult(
                shown: false,
                rewarded: false,
                network: AdNetwork.unity,
                message: message,
              ),
            );
          }
        },
      );
    } catch (error) {
      return AdShowResult(
        shown: false,
        rewarded: false,
        network: AdNetwork.unity,
        message: error.toString(),
      );
    }

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => const AdShowResult(
        shown: false,
        rewarded: false,
        network: AdNetwork.unity,
        message: 'Unity interstitial ad timed out.',
      ),
    );
  }

  static Future<AdShowResult> _showHuaweiRewarded(AdPlacement placement) async {
    final completer = Completer<AdShowResult>();
    var rewarded = false;
    late final RewardAd ad;

    Future<void> complete(AdShowResult result) async {
      if (completer.isCompleted) {
        return;
      }
      completer.complete(result);
      await ad.destroy();
    }

    ad = RewardAd(
      listener: (event, {reward, errorCode}) async {
        switch (event) {
          case RewardAdEvent.loaded:
            final shown = await ad.show() ?? false;
            if (!shown) {
              await complete(
                const AdShowResult(
                  shown: false,
                  rewarded: false,
                  network: AdNetwork.huawei,
                  message: 'Huawei rewarded ad failed to show.',
                ),
              );
            }
            break;
          case RewardAdEvent.rewarded:
            rewarded = true;
            break;
          case RewardAdEvent.closed:
            await complete(
              AdShowResult(
                shown: true,
                rewarded: rewarded,
                network: AdNetwork.huawei,
                message: rewarded ? null : 'Rewarded ad was closed early.',
              ),
            );
            break;
          case RewardAdEvent.failedToLoad:
            await complete(
              AdShowResult(
                shown: false,
                rewarded: false,
                network: AdNetwork.huawei,
                message: 'Huawei rewarded ad failed to load ($errorCode).',
              ),
            );
            break;
          default:
            break;
        }
      },
    );

    try {
      final loaded = await ad.loadAd(
        adSlotId: _slotIdFor(placement, rewarded: true),
        adParam: AdParam(),
      );
      if (loaded == false) {
        await ad.destroy();
        return const AdShowResult(
          shown: false,
          rewarded: false,
          network: AdNetwork.huawei,
          message: 'Huawei rewarded ad was not loaded.',
        );
      }
    } catch (error) {
      return AdShowResult(
        shown: false,
        rewarded: false,
        network: AdNetwork.huawei,
        message: error.toString(),
      );
    }

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () async {
        await ad.destroy();
        return const AdShowResult(
          shown: false,
          rewarded: false,
          network: AdNetwork.huawei,
          message: 'Huawei rewarded ad timed out.',
        );
      },
    );
  }

  static Future<AdShowResult> _showHuaweiInterstitial(
    AdPlacement placement,
  ) async {
    final completer = Completer<AdShowResult>();
    late final InterstitialAd ad;

    Future<void> complete(AdShowResult result) async {
      if (completer.isCompleted) {
        return;
      }
      completer.complete(result);
      await ad.destroy();
    }

    ad = InterstitialAd(
      adSlotId: _slotIdFor(placement, rewarded: false),
      listener: (event, {errorCode}) async {
        switch (event) {
          case AdEvent.loaded:
            final shown = await ad.show() ?? false;
            if (!shown) {
              await complete(
                const AdShowResult(
                  shown: false,
                  rewarded: false,
                  network: AdNetwork.huawei,
                  message: 'Huawei interstitial ad failed to show.',
                ),
              );
            }
            break;
          case AdEvent.closed:
            await complete(
              const AdShowResult(
                shown: true,
                rewarded: false,
                network: AdNetwork.huawei,
              ),
            );
            break;
          case AdEvent.failed:
            await complete(
              AdShowResult(
                shown: false,
                rewarded: false,
                network: AdNetwork.huawei,
                message: 'Huawei interstitial ad failed to load ($errorCode).',
              ),
            );
            break;
          default:
            break;
        }
      },
    );

    try {
      final loaded = await ad.loadAd();
      if (loaded == false) {
        await ad.destroy();
        return const AdShowResult(
          shown: false,
          rewarded: false,
          network: AdNetwork.huawei,
          message: 'Huawei interstitial ad was not loaded.',
        );
      }
    } catch (error) {
      return AdShowResult(
        shown: false,
        rewarded: false,
        network: AdNetwork.huawei,
        message: error.toString(),
      );
    }

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () async {
        await ad.destroy();
        return const AdShowResult(
          shown: false,
          rewarded: false,
          network: AdNetwork.huawei,
          message: 'Huawei interstitial ad timed out.',
        );
      },
    );
  }

  static String _slotIdFor(AdPlacement placement, {required bool rewarded}) {
    switch (placement) {
      case AdPlacement.continueGame:
      case AdPlacement.doubleCoins:
      case AdPlacement.unlockPowerUp:
        return rewarded ? _huaweiRewardedSlotId : _huaweiInterstitialSlotId;
      case AdPlacement.gameOverInterstitial:
      case AdPlacement.levelBreakInterstitial:
        return rewarded ? _huaweiRewardedSlotId : _huaweiInterstitialSlotId;
    }
  }
}

#pragma once
#import "StormyGromoreSupport.h"
#import "StormyGromoreEvents.h"
#import "StormyGromoreAdRequests.h"
#import "StormyGromoreInitialization.h"

@interface StormyGromoreFullScreenAds : StormyGromoreSupport <BUMSplashAdDelegate, BUMNativeExpressRewardedVideoAdDelegate, BUMNativeExpressFullscreenVideoAdDelegate>
- (instancetype)initWithEvents:(StormyGromoreEvents *)events
                      requests:(StormyGromoreAdRequests *)requests
                initialization:(StormyGromoreInitialization *)initialization;
- (void)dispose;
- (void)loadSplashWithArguments:(NSDictionary *)arguments
                         result:(FlutterResult)result;
- (void)showSplashWithArguments:(NSDictionary *)arguments
                         result:(FlutterResult)result;
- (void)showSplashAd:(BUSplashAd *)ad
            requestId:(NSString *)requestId
                result:(nullable FlutterResult)result;
- (void)loadRewardedWithArguments:(NSDictionary *)arguments
                           result:(FlutterResult)result;
- (void)showRewardedWithArguments:(NSDictionary *)arguments
                           result:(FlutterResult)result;
- (void)loadInterstitialWithArguments:(NSDictionary *)arguments
                               result:(FlutterResult)result;
- (void)showInterstitialWithArguments:(NSDictionary *)arguments
                               result:(FlutterResult)result;
- (void)disposeAdWithArguments:(NSDictionary *)arguments
                        result:(FlutterResult)result;
- (void)splashAdLoadSuccess:(BUSplashAd *)splashAd;
- (void)splashAdLoadFail:(BUSplashAd *)splashAd error:(BUAdError *)error;
- (void)splashAdRenderSuccess:(BUSplashAd *)splashAd;
- (void)splashAdRenderFail:(BUSplashAd *)splashAd error:(BUAdError *)error;
- (void)splashAdWillShow:(BUSplashAd *)splashAd;
- (void)splashAdDidShow:(BUSplashAd *)splashAd;
- (void)emitSplashShownIfNeeded:(BUSplashAd *)splashAd;
- (void)splashAdViewControllerDidClose:(BUSplashAd *)splashAd;
- (void)splashDidCloseOtherController:(BUSplashAd *)splashAd
                      interactionType:(BUInteractionType)interactionType;
- (void)splashVideoAdDidPlayFinish:(BUSplashAd *)splashAd
                   didFailWithError:(NSError *)error;
- (void)splashAdDidClick:(BUSplashAd *)splashAd;
- (void)splashAdDidClose:(BUSplashAd *)splashAd closeType:(BUSplashAdCloseType)closeType;
- (void)splashAdDidShowFailed:(BUSplashAd *)splashAd error:(NSError *)error;
- (void)nativeExpressRewardedVideoAdDidLoad:(BUNativeExpressRewardedVideoAd *)ad;
- (void)nativeExpressRewardedVideoAd:(BUNativeExpressRewardedVideoAd *)ad
                    didFailWithError:(NSError *)error;
- (void)nativeExpressRewardedVideoAdDidShowFailed:(BUNativeExpressRewardedVideoAd *)ad
                                            error:(NSError *)error;
- (void)nativeExpressRewardedVideoAdDidVisible:(BUNativeExpressRewardedVideoAd *)ad;
- (void)nativeExpressRewardedVideoAdDidClick:(BUNativeExpressRewardedVideoAd *)ad;
- (void)nativeExpressRewardedVideoAdDidClickSkip:(BUNativeExpressRewardedVideoAd *)ad;
- (void)nativeExpressRewardedVideoAdDidClose:(BUNativeExpressRewardedVideoAd *)ad;
- (void)nativeExpressRewardedVideoAdDidPlayFinish:(BUNativeExpressRewardedVideoAd *)ad
                               didFailWithError:(NSError *)error;
- (void)nativeExpressRewardedVideoAdServerRewardDidSucceed:(BUNativeExpressRewardedVideoAd *)ad
                                                    verify:(BOOL)verify;
- (void)nativeExpressRewardedVideoAdServerRewardDidFail:(BUNativeExpressRewardedVideoAd *)ad
                                                   error:(NSError *)error;
- (void)nativeExpressFullscreenVideoAdDidLoad:(BUNativeExpressFullscreenVideoAd *)ad;
- (void)nativeExpressFullscreenVideoAd:(BUNativeExpressFullscreenVideoAd *)ad
                      didFailWithError:(NSError *)error;
- (void)nativeExpressFullscreenVideoAdDidShowFailed:(BUNativeExpressFullscreenVideoAd *)ad
                                              error:(NSError *)error;
- (void)nativeExpressFullscreenVideoAdDidVisible:(BUNativeExpressFullscreenVideoAd *)ad;
- (void)nativeExpressFullscreenVideoAdDidClick:(BUNativeExpressFullscreenVideoAd *)ad;
- (void)nativeExpressFullscreenVideoAdDidClickSkip:(BUNativeExpressFullscreenVideoAd *)ad;
- (void)nativeExpressFullscreenVideoAdDidClose:(BUNativeExpressFullscreenVideoAd *)ad;
- (void)nativeExpressFullscreenVideoAdDidPlayFinish:(BUNativeExpressFullscreenVideoAd *)ad
                                 didFailWithError:(NSError *)error;
- (void)closeRewardedRequestId:(NSString *)requestId
                             ad:(BUNativeExpressRewardedVideoAd *)ad;
- (BOOL)beginRewardDeliveryForRequestId:(NSString *)requestId
                                      ad:(BUNativeExpressRewardedVideoAd *)ad;
- (void)releaseRewardedIfClosed:(NSString *)requestId;
- (void)scheduleRewardedRelease:(NSString *)requestId;
- (BOOL)ensureUnused:(NSString *)requestId result:(FlutterResult)result;
- (NSString *)requestIdForObject:(id)object inDictionary:(NSDictionary *)dictionary;
- (void)emitSimpleEvent:(NSString *)event
                  adType:(NSString *)adType
                  object:(id)object
              dictionary:(NSDictionary *)dictionary;
- (NSDictionary *)detailsForRequestId:(NSString *)requestId
                                  ecpm:(NSDictionary *)ecpm;
- (void)releaseRequestId:(NSString *)requestId emitDisposed:(BOOL)emitDisposed;
@end

#import "StormyGromoreFullScreenAds.h"
#import "StormyRewardTerminalState.h"
#import <objc/message.h>
@interface StormyGromoreFullScreenAds ()
@property(nonatomic, strong) NSMutableDictionary<NSString *, BUSplashAd *> *splashAds;
@property(nonatomic, strong) NSMutableDictionary<NSString *, BUNativeExpressRewardedVideoAd *> *rewardedAds;
@property(nonatomic, strong) NSMutableDictionary<NSString *, BUNativeExpressFullscreenVideoAd *> *interstitialAds;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *adMetadata;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *rewardReleaseBlocks;
@property(nonatomic, strong) NSMutableDictionary<NSString *, StormyRewardTerminalState *> *rewardStates;
@property(nonatomic, strong) StormyGromoreEvents *events;
@property(nonatomic, strong) StormyGromoreAdRequests *requests;
@property(nonatomic, strong) StormyGromoreInitialization *initialization;
@end
@implementation StormyGromoreFullScreenAds
- (instancetype)initWithEvents:(StormyGromoreEvents *)events
                      requests:(StormyGromoreAdRequests *)requests
                initialization:(StormyGromoreInitialization *)initialization {
  self = [super init];
  if (self) {
    _events = events; _requests = requests; _initialization = initialization;
    _splashAds = [NSMutableDictionary dictionary];
    _rewardedAds = [NSMutableDictionary dictionary];
    _interstitialAds = [NSMutableDictionary dictionary];
    _adMetadata = [NSMutableDictionary dictionary];
    _rewardReleaseBlocks = [NSMutableDictionary dictionary];
    _rewardStates = [NSMutableDictionary dictionary];
  }
  return self;
}
- (void)loadSplashWithArguments:(NSDictionary *)arguments
                         result:(FlutterResult)result {
  NSString *requestId = [self requiredString:arguments key:@"requestId" result:result];
  NSString *slotId = [self requiredString:arguments key:@"slotId" result:result];
  if (requestId == nil || slotId == nil || ![self ensureUnused:requestId result:result]) {
    return;
  }

  BUSplashAd *ad = [self.requests splashAdWithArguments:arguments];
  ad.delegate = self;
  self.splashAds[requestId] = ad;
  self.adMetadata[requestId] = @{
    @"adType" : @"splash",
    @"slotId" : slotId,
    @"autoShow" : @([self boolValue:arguments key:@"autoShow" fallback:YES]),
    @"shown" : @NO,
  };
  [ad loadAdData];
  result(requestId);
}

- (void)showSplashWithArguments:(NSDictionary *)arguments
                         result:(FlutterResult)result {
  NSString *requestId = [self requiredString:arguments key:@"requestId" result:result];
  if (requestId == nil) {
    return;
  }
  BUSplashAd *ad = self.splashAds[requestId];
  if (ad == nil) {
    [self unknownAd:@"splash" requestId:requestId result:result];
    return;
  }
  [self showSplashAd:ad requestId:requestId result:result];
}

- (void)showSplashAd:(BUSplashAd *)ad
            requestId:(NSString *)requestId
                result:(nullable FlutterResult)result {
  if (ad.mediation != nil && !ad.mediation.isReady) {
    if (result != nil) {
      result([FlutterError errorWithCode:@"ad_not_ready"
                                 message:@"Splash ad has expired or is not ready."
                                 details:nil]);
    }
    return;
  }
  UIViewController *viewController = [self topViewController];
  if (viewController == nil) {
    NSString *message = @"A foreground view controller is required to show a splash ad.";
    [self.events emitAdType:@"splash"
               event:@"showFailed"
           requestId:requestId
             details:@{ @"message" : message }];
    if (result != nil) {
      result([FlutterError errorWithCode:@"view_controller_unavailable"
                                 message:message
                                 details:nil]);
    }
    return;
  }
  [ad showSplashViewInRootViewController:viewController];
  if (result != nil) {
    result(@YES);
  }
}

- (void)loadRewardedWithArguments:(NSDictionary *)arguments
                           result:(FlutterResult)result {
  NSString *requestId = [self requiredString:arguments key:@"requestId" result:result];
  NSString *slotId = [self requiredString:arguments key:@"slotId" result:result];
  if (requestId == nil || slotId == nil || ![self ensureUnused:requestId result:result]) {
    return;
  }

  BUNativeExpressRewardedVideoAd *ad =
      [self.requests rewardedAdWithArguments:arguments];
  ad.delegate = self;
  self.rewardedAds[requestId] = ad;
  self.rewardStates[requestId] = [[StormyRewardTerminalState alloc] init];
  self.adMetadata[requestId] = @{
    @"adType" : @"rewarded",
    @"slotId" : slotId,
  };
  [ad loadAdData];
  result(requestId);
}

- (void)showRewardedWithArguments:(NSDictionary *)arguments
                           result:(FlutterResult)result {
  NSString *requestId = [self requiredString:arguments key:@"requestId" result:result];
  if (requestId == nil) {
    return;
  }
  BUNativeExpressRewardedVideoAd *ad = self.rewardedAds[requestId];
  if (ad == nil) {
    [self unknownAd:@"rewarded" requestId:requestId result:result];
    return;
  }
  if (ad.mediation != nil && !ad.mediation.isReady) {
    result([FlutterError errorWithCode:@"ad_not_ready"
                               message:@"Rewarded ad has expired or is not ready."
                               details:nil]);
    return;
  }
  UIViewController *viewController = [self topViewController];
  if (viewController == nil) {
    result([FlutterError errorWithCode:@"view_controller_unavailable"
                               message:@"A foreground view controller is required."
                               details:nil]);
    return;
  }
  BOOL shown = [ad showAdFromRootViewController:viewController];
  if (!shown) {
    [self.events emitAdType:@"rewarded"
               event:@"showFailed"
           requestId:requestId
             details:@{ @"slotId" : self.adMetadata[requestId][@"slotId"] ?: @"" }];
  }
  result(@(shown));
}

- (void)loadInterstitialWithArguments:(NSDictionary *)arguments
                               result:(FlutterResult)result {
  NSString *requestId = [self requiredString:arguments key:@"requestId" result:result];
  NSString *slotId = [self requiredString:arguments key:@"slotId" result:result];
  if (requestId == nil || slotId == nil || ![self ensureUnused:requestId result:result]) {
    return;
  }

  BUNativeExpressFullscreenVideoAd *ad =
      [self.requests interstitialAdWithArguments:arguments];
  ad.delegate = self;
  self.interstitialAds[requestId] = ad;
  self.adMetadata[requestId] = @{
    @"adType" : @"interstitial",
    @"slotId" : slotId,
  };
  [ad loadAdData];
  result(requestId);
}

- (void)showInterstitialWithArguments:(NSDictionary *)arguments
                               result:(FlutterResult)result {
  NSString *requestId = [self requiredString:arguments key:@"requestId" result:result];
  if (requestId == nil) {
    return;
  }
  BUNativeExpressFullscreenVideoAd *ad = self.interstitialAds[requestId];
  if (ad == nil) {
    [self unknownAd:@"interstitial" requestId:requestId result:result];
    return;
  }
  if (ad.mediation != nil && !ad.mediation.isReady) {
    result([FlutterError errorWithCode:@"ad_not_ready"
                               message:@"Interstitial ad has expired or is not ready."
                               details:nil]);
    return;
  }
  UIViewController *viewController = [self topViewController];
  if (viewController == nil) {
    result([FlutterError errorWithCode:@"view_controller_unavailable"
                               message:@"A foreground view controller is required."
                               details:nil]);
    return;
  }
  BOOL shown = [ad showAdFromRootViewController:viewController];
  if (!shown) {
    [self.events emitAdType:@"interstitial"
               event:@"showFailed"
           requestId:requestId
             details:@{ @"slotId" : self.adMetadata[requestId][@"slotId"] ?: @"" }];
  }
  result(@(shown));
}

- (void)disposeAdWithArguments:(NSDictionary *)arguments
                        result:(FlutterResult)result {
  NSString *requestId = [self requiredString:arguments key:@"requestId" result:result];
  if (requestId == nil) {
    return;
  }
  NSString *adType = self.adMetadata[requestId][@"adType"];
  if (adType == nil) {
    result(nil);
    return;
  }
  [self releaseRequestId:requestId emitDisposed:YES];
  result(nil);
}

- (void)splashAdLoadSuccess:(BUSplashAd *)splashAd {
  NSString *requestId = [self requestIdForObject:splashAd inDictionary:self.splashAds];
  if (requestId == nil) return;
  NSDictionary *metadata = self.adMetadata[requestId];
  [self.events emitAdType:@"splash"
             event:@"loadSuccess"
         requestId:requestId
           details:@{ @"slotId" : metadata[@"slotId"] ?: @"" }];
  [self.events emitAdType:@"splash"
             event:@"loaded"
         requestId:requestId
           details:@{ @"slotId" : metadata[@"slotId"] ?: @"" }];
  if ([metadata[@"autoShow"] boolValue]) {
    [self showSplashAd:splashAd requestId:requestId result:nil];
  }
}

- (void)splashAdLoadFail:(BUSplashAd *)splashAd error:(BUAdError *)error {
  NSString *requestId = [self requestIdForObject:splashAd inDictionary:self.splashAds];
  if (requestId == nil) return;
  NSString *slotId = self.adMetadata[requestId][@"slotId"];
  [self.events emitAdType:@"splash"
             event:@"failed"
         requestId:requestId
           details:[self errorDetails:error slotId:slotId]];
  [self releaseRequestId:requestId emitDisposed:YES];
}

- (void)splashAdRenderSuccess:(BUSplashAd *)splashAd {
  NSString *requestId = [self requestIdForObject:splashAd inDictionary:self.splashAds];
  if (requestId != nil) {
    [self.events emitAdType:@"splash" event:@"rendered" requestId:requestId details:nil];
  }
}

- (void)splashAdRenderFail:(BUSplashAd *)splashAd error:(BUAdError *)error {
  NSString *requestId = [self requestIdForObject:splashAd inDictionary:self.splashAds];
  if (requestId == nil) return;
  [self.events emitAdType:@"splash"
             event:@"renderFailed"
         requestId:requestId
           details:[self errorDetails:error slotId:self.adMetadata[requestId][@"slotId"]]];
  [self releaseRequestId:requestId emitDisposed:YES];
}

- (void)splashAdWillShow:(BUSplashAd *)splashAd {
  [self emitSplashShownIfNeeded:splashAd];
}

- (void)splashAdDidShow:(BUSplashAd *)splashAd {
  // Some mediated networks only invoke willShow, while CSJ also invokes didShow.
  [self emitSplashShownIfNeeded:splashAd];
}

- (void)emitSplashShownIfNeeded:(BUSplashAd *)splashAd {
  NSString *requestId = [self requestIdForObject:splashAd inDictionary:self.splashAds];
  if (requestId == nil) return;
  NSDictionary *metadata = self.adMetadata[requestId];
  if ([metadata[@"shown"] boolValue]) return;
  NSMutableDictionary *updatedMetadata = [metadata mutableCopy];
  updatedMetadata[@"shown"] = @YES;
  self.adMetadata[requestId] = updatedMetadata;
  [self.events emitAdType:@"splash"
             event:@"shown"
         requestId:requestId
           details:[self detailsForRequestId:requestId
                                       ecpm:[self ecpmDetailsForMediation:splashAd.mediation]]];
}

- (void)splashAdViewControllerDidClose:(BUSplashAd *)splashAd {
}

- (void)splashDidCloseOtherController:(BUSplashAd *)splashAd
                      interactionType:(BUInteractionType)interactionType {
}

- (void)splashVideoAdDidPlayFinish:(BUSplashAd *)splashAd
                   didFailWithError:(NSError *)error {
  NSString *requestId = [self requestIdForObject:splashAd inDictionary:self.splashAds];
  if (requestId == nil) return;
  [self.events emitAdType:@"splash"
             event:error == nil ? @"completed" : @"videoError"
         requestId:requestId
           details:error == nil
                       ? [self detailsForRequestId:requestId ecpm:nil]
                       : [self errorDetails:error
                                         slotId:self.adMetadata[requestId][@"slotId"]]];
}

- (void)splashAdDidClick:(BUSplashAd *)splashAd {
  [self emitSimpleEvent:@"clicked" adType:@"splash" object:splashAd dictionary:self.splashAds];
}

- (void)splashAdDidClose:(BUSplashAd *)splashAd closeType:(BUSplashAdCloseType)closeType {
  NSString *requestId = [self requestIdForObject:splashAd inDictionary:self.splashAds];
  if (requestId == nil) return;
  [self.events emitAdType:@"splash"
             event:@"closed"
         requestId:requestId
           details:[self detailsForRequestId:requestId
                                         ecpm:@{ @"closeReason" : @(closeType) }]];
  [self releaseRequestId:requestId emitDisposed:YES];
}

- (void)splashAdDidShowFailed:(BUSplashAd *)splashAd error:(NSError *)error {
  NSString *requestId = [self requestIdForObject:splashAd inDictionary:self.splashAds];
  if (requestId == nil) return;
  [self.events emitAdType:@"splash"
             event:@"showFailed"
         requestId:requestId
           details:[self errorDetails:error slotId:self.adMetadata[requestId][@"slotId"]]];
  [self releaseRequestId:requestId emitDisposed:YES];
}

- (void)nativeExpressRewardedVideoAdDidLoad:(BUNativeExpressRewardedVideoAd *)ad {
  NSString *requestId = [self requestIdForObject:ad inDictionary:self.rewardedAds];
  if (requestId == nil) return;
  [self.events emitAdType:@"rewarded" event:@"loadSuccess" requestId:requestId details:[self detailsForRequestId:requestId ecpm:nil]];
  [self.events emitAdType:@"rewarded" event:@"loaded" requestId:requestId details:[self detailsForRequestId:requestId ecpm:nil]];
}

- (void)nativeExpressRewardedVideoAd:(BUNativeExpressRewardedVideoAd *)ad
                    didFailWithError:(NSError *)error {
  NSString *requestId = [self requestIdForObject:ad inDictionary:self.rewardedAds];
  if (requestId == nil) return;
  [self.events emitAdType:@"rewarded" event:@"failed" requestId:requestId details:[self errorDetails:error slotId:self.adMetadata[requestId][@"slotId"]]];
  [self releaseRequestId:requestId emitDisposed:YES];
}

- (void)nativeExpressRewardedVideoAdDidShowFailed:(BUNativeExpressRewardedVideoAd *)ad
                                            error:(NSError *)error {
  NSString *requestId = [self requestIdForObject:ad inDictionary:self.rewardedAds];
  if (requestId == nil) return;
  [self.events emitAdType:@"rewarded" event:@"showFailed" requestId:requestId details:[self errorDetails:error slotId:self.adMetadata[requestId][@"slotId"]]];
  [self releaseRequestId:requestId emitDisposed:YES];
}

- (void)nativeExpressRewardedVideoAdDidVisible:(BUNativeExpressRewardedVideoAd *)ad {
  NSString *requestId = [self requestIdForObject:ad inDictionary:self.rewardedAds];
  if (requestId != nil) {
    [self.events emitAdType:@"rewarded" event:@"shown" requestId:requestId details:[self detailsForRequestId:requestId ecpm:[self ecpmDetailsForMediation:ad.mediation]]];
  }
}

- (void)nativeExpressRewardedVideoAdDidClick:(BUNativeExpressRewardedVideoAd *)ad {
  [self emitSimpleEvent:@"clicked" adType:@"rewarded" object:ad dictionary:self.rewardedAds];
}

- (void)nativeExpressRewardedVideoAdDidClickSkip:(BUNativeExpressRewardedVideoAd *)ad {
  [self emitSimpleEvent:@"skipped" adType:@"rewarded" object:ad dictionary:self.rewardedAds];
}

- (void)nativeExpressRewardedVideoAdDidClose:(BUNativeExpressRewardedVideoAd *)ad {
  [self runOnMain:^{
    NSString *requestId =
        [self requestIdForObject:ad inDictionary:self.rewardedAds];
    if (requestId == nil) return;
    [self closeRewardedRequestId:requestId ad:ad];
  }];
}

- (void)nativeExpressRewardedVideoAdDidPlayFinish:(BUNativeExpressRewardedVideoAd *)ad
                               didFailWithError:(NSError *)error {
  NSString *requestId = [self requestIdForObject:ad inDictionary:self.rewardedAds];
  if (requestId == nil) return;
  [self.events emitAdType:@"rewarded"
             event:error == nil ? @"completed" : @"videoError"
         requestId:requestId
           details:error == nil ? [self detailsForRequestId:requestId ecpm:nil]
                                : [self errorDetails:error slotId:self.adMetadata[requestId][@"slotId"]]];
}

- (void)nativeExpressRewardedVideoAdServerRewardDidSucceed:(BUNativeExpressRewardedVideoAd *)ad
                                                    verify:(BOOL)verify {
  [self runOnMain:^{
    NSString *requestId =
        [self requestIdForObject:ad inDictionary:self.rewardedAds];
    if (![self beginRewardDeliveryForRequestId:requestId ad:ad]) return;
    BURewardedVideoModel *model = ad.rewardedVideoModel;
    NSMutableDictionary *rewardDetails =
        [NSMutableDictionary dictionaryWithDictionary:
            [self detailsForRequestId:requestId ecpm:nil]];
    rewardDetails[@"rewardValid"] = @(verify);
    rewardDetails[@"rewardType"] = @(model.rewardType);
    rewardDetails[@"rewardAmount"] = @(model.rewardAmount);
    if (model.rewardName != nil) rewardDetails[@"rewardName"] = model.rewardName;
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    if (model.mediation.rewardId != nil) extra[@"rewardId"] = model.mediation.rewardId;
    if (model.mediation.tradeId != nil) extra[@"tradeId"] = model.mediation.tradeId;
    if (model.mediation.adnName != nil) extra[@"adnName"] = model.mediation.adnName;
    extra[@"verifyByGroMoreS2S"] = @(model.mediation.verifyByGroMoreS2S);
    rewardDetails[@"extra"] = extra;
    [self.events emitAdType:@"rewarded"
               event:verify ? @"rewardEarned" : @"rewardFailed"
           requestId:requestId
             details:rewardDetails];
    [self releaseRewardedIfClosed:requestId];
  }];
}

- (void)nativeExpressRewardedVideoAdServerRewardDidFail:(BUNativeExpressRewardedVideoAd *)ad
                                                   error:(NSError *)error {
  [self runOnMain:^{
    NSString *requestId =
        [self requestIdForObject:ad inDictionary:self.rewardedAds];
    if (![self beginRewardDeliveryForRequestId:requestId ad:ad]) return;
    [self.events emitAdType:@"rewarded"
               event:@"rewardFailed"
           requestId:requestId
             details:[self errorDetails:error
                                      slotId:self.adMetadata[requestId][@"slotId"]]];
    [self releaseRewardedIfClosed:requestId];
  }];
}

- (void)nativeExpressFullscreenVideoAdDidLoad:(BUNativeExpressFullscreenVideoAd *)ad {
  NSString *requestId = [self requestIdForObject:ad inDictionary:self.interstitialAds];
  if (requestId == nil) return;
  [self.events emitAdType:@"interstitial" event:@"loadSuccess" requestId:requestId details:[self detailsForRequestId:requestId ecpm:nil]];
  [self.events emitAdType:@"interstitial" event:@"loaded" requestId:requestId details:[self detailsForRequestId:requestId ecpm:nil]];
}

- (void)nativeExpressFullscreenVideoAd:(BUNativeExpressFullscreenVideoAd *)ad
                      didFailWithError:(NSError *)error {
  NSString *requestId = [self requestIdForObject:ad inDictionary:self.interstitialAds];
  if (requestId == nil) return;
  [self.events emitAdType:@"interstitial" event:@"failed" requestId:requestId details:[self errorDetails:error slotId:self.adMetadata[requestId][@"slotId"]]];
  [self releaseRequestId:requestId emitDisposed:YES];
}

- (void)nativeExpressFullscreenVideoAdDidShowFailed:(BUNativeExpressFullscreenVideoAd *)ad
                                              error:(NSError *)error {
  NSString *requestId = [self requestIdForObject:ad inDictionary:self.interstitialAds];
  if (requestId == nil) return;
  [self.events emitAdType:@"interstitial" event:@"showFailed" requestId:requestId details:[self errorDetails:error slotId:self.adMetadata[requestId][@"slotId"]]];
  [self releaseRequestId:requestId emitDisposed:YES];
}

- (void)nativeExpressFullscreenVideoAdDidVisible:(BUNativeExpressFullscreenVideoAd *)ad {
  NSString *requestId = [self requestIdForObject:ad inDictionary:self.interstitialAds];
  if (requestId != nil) {
    [self.events emitAdType:@"interstitial" event:@"shown" requestId:requestId details:[self detailsForRequestId:requestId ecpm:[self ecpmDetailsForMediation:ad.mediation]]];
  }
}

- (void)nativeExpressFullscreenVideoAdDidClick:(BUNativeExpressFullscreenVideoAd *)ad {
  [self emitSimpleEvent:@"clicked" adType:@"interstitial" object:ad dictionary:self.interstitialAds];
}

- (void)nativeExpressFullscreenVideoAdDidClickSkip:(BUNativeExpressFullscreenVideoAd *)ad {
  [self emitSimpleEvent:@"skipped" adType:@"interstitial" object:ad dictionary:self.interstitialAds];
}

- (void)nativeExpressFullscreenVideoAdDidClose:(BUNativeExpressFullscreenVideoAd *)ad {
  NSString *requestId = [self requestIdForObject:ad inDictionary:self.interstitialAds];
  if (requestId == nil) return;
  [self.events emitAdType:@"interstitial" event:@"closed" requestId:requestId details:[self detailsForRequestId:requestId ecpm:nil]];
  [self releaseRequestId:requestId emitDisposed:YES];
}

- (void)nativeExpressFullscreenVideoAdDidPlayFinish:(BUNativeExpressFullscreenVideoAd *)ad
                                 didFailWithError:(NSError *)error {
  NSString *requestId = [self requestIdForObject:ad inDictionary:self.interstitialAds];
  if (requestId == nil) return;
  [self.events emitAdType:@"interstitial"
             event:error == nil ? @"completed" : @"videoError"
         requestId:requestId
           details:error == nil ? [self detailsForRequestId:requestId ecpm:nil]
                                : [self errorDetails:error slotId:self.adMetadata[requestId][@"slotId"]]];
}

- (void)closeRewardedRequestId:(NSString *)requestId
                             ad:(BUNativeExpressRewardedVideoAd *)ad {
  if (self.rewardedAds[requestId] != ad) return;
  if ([self.rewardStates[requestId] beginClose]) {
    [self.events emitAdType:@"rewarded"
               event:@"closed"
           requestId:requestId
             details:[self detailsForRequestId:requestId ecpm:nil]];
  }
  if (self.rewardStates[requestId].isRewardDelivered) {
    [self releaseRequestId:requestId emitDisposed:YES];
  } else {
    [self scheduleRewardedRelease:requestId];
  }
}

- (BOOL)beginRewardDeliveryForRequestId:(NSString *)requestId
                                      ad:(BUNativeExpressRewardedVideoAd *)ad {
  if (requestId == nil || self.rewardedAds[requestId] != ad ||
      self.rewardStates[requestId].isRewardDelivered) {
    return NO;
  }
  return [self.rewardStates[requestId] beginRewardDelivery];
}

- (void)releaseRewardedIfClosed:(NSString *)requestId {
  if (self.rewardStates[requestId].isClosed) {
    [self releaseRequestId:requestId emitDisposed:YES];
  }
}

- (void)scheduleRewardedRelease:(NSString *)requestId {
  if (self.rewardReleaseBlocks[requestId] != nil) return;
  __weak typeof(self) weakSelf = self;
  dispatch_block_t releaseBlock = dispatch_block_create(0, ^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (strongSelf == nil) return;
    [strongSelf.rewardReleaseBlocks removeObjectForKey:requestId];
    if (strongSelf.rewardStates[requestId].isClosed &&
        strongSelf.rewardedAds[requestId] != nil) {
      [strongSelf releaseRequestId:requestId emitDisposed:YES];
    }
  });
  self.rewardReleaseBlocks[requestId] = releaseBlock;
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW,
                    (int64_t)(self.initialization.rewardCallbackRetentionSeconds * NSEC_PER_SEC)),
      dispatch_get_main_queue(), releaseBlock);
}

- (BOOL)ensureUnused:(NSString *)requestId result:(FlutterResult)result {
  if (self.adMetadata[requestId] != nil) {
    result([FlutterError errorWithCode:@"duplicate_request"
                               message:[NSString stringWithFormat:@"Duplicate request ID: %@", requestId]
                               details:nil]);
    return NO;
  }
  return YES;
}

- (NSString *)requestIdForObject:(id)object inDictionary:(NSDictionary *)dictionary {
  for (NSString *requestId in dictionary) {
    if (dictionary[requestId] == object) return requestId;
  }
  return nil;
}

- (void)emitSimpleEvent:(NSString *)event
                  adType:(NSString *)adType
                  object:(id)object
              dictionary:(NSDictionary *)dictionary {
  NSString *requestId = [self requestIdForObject:object inDictionary:dictionary];
  if (requestId != nil) {
    [self.events emitAdType:adType event:event requestId:requestId details:[self detailsForRequestId:requestId ecpm:nil]];
  }
}

- (NSDictionary *)detailsForRequestId:(NSString *)requestId
                                  ecpm:(NSDictionary *)ecpm {
  NSMutableDictionary *details = [NSMutableDictionary dictionary];
  NSString *slotId = self.adMetadata[requestId][@"slotId"];
  if (slotId != nil) details[@"slotId"] = slotId;
  if (ecpm != nil) [details addEntriesFromDictionary:ecpm];
  return details;
}

- (void)releaseRequestId:(NSString *)requestId emitDisposed:(BOOL)emitDisposed {
  dispatch_block_t pendingRewardRelease = self.rewardReleaseBlocks[requestId];
  if (pendingRewardRelease != nil) {
    dispatch_block_cancel(pendingRewardRelease);
    [self.rewardReleaseBlocks removeObjectForKey:requestId];
  }
  [self.rewardStates[requestId] releaseResources];
  [self.rewardStates removeObjectForKey:requestId];
  id ad = self.splashAds[requestId] ?: self.rewardedAds[requestId] ?: self.interstitialAds[requestId];
  NSString *adType = self.adMetadata[requestId][@"adType"];
  NSString *slotId = self.adMetadata[requestId][@"slotId"];
  id mediation = [ad respondsToSelector:@selector(mediation)] ? [ad mediation] : nil;
  if ([ad respondsToSelector:@selector(setDelegate:)]) {
    ((void (*)(id, SEL, id))objc_msgSend)(ad, @selector(setDelegate:), nil);
  }
  [self destroyMediation:mediation];
  [self.splashAds removeObjectForKey:requestId];
  [self.rewardedAds removeObjectForKey:requestId];
  [self.interstitialAds removeObjectForKey:requestId];
  [self.adMetadata removeObjectForKey:requestId];
  if (emitDisposed && adType != nil) {
    [self.events emitAdType:adType
               event:@"disposed"
           requestId:requestId
             details:slotId == nil ? nil : @{ @"slotId" : slotId }];
  }
}


- (void)dispose {
  for (NSString *requestId in self.adMetadata.allKeys) {
    [self releaseRequestId:requestId emitDisposed:NO];
  }
}
- (void)dealloc { [self dispose]; }
@end

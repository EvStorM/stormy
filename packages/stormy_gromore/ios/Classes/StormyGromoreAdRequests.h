#pragma once
#import "StormyGromoreSupport.h"

@interface StormyGromoreAdRequests : StormyGromoreSupport
- (void)dispose;
- (void)preloadAdsWithArguments:(NSDictionary *)arguments
                          result:(FlutterResult)result;
- (BUSplashAd *)splashAdWithArguments:(NSDictionary *)arguments;
- (BUNativeExpressRewardedVideoAd *)rewardedAdWithArguments:
    (NSDictionary *)arguments;
- (BUNativeExpressFullscreenVideoAd *)interstitialAdWithArguments:
    (NSDictionary *)arguments;
- (BUNativeAdsManager *)nativeAdsManagerWithArguments:
    (NSDictionary *)arguments;
@end

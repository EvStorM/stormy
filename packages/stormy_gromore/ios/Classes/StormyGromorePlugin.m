#import "StormyGromorePlugin.h"
#import "StormyGromorePluginInternal.h"
#import "StormyGromoreEvents.h"
#import "StormyGromoreInitialization.h"
#import "StormyGromoreAdRequests.h"
#import "StormyGromoreFullScreenAds.h"
#import "StormyGromorePlatformViews.h"
static NSString *const StormyMethodChannel = @"stormy_gromore/methods";
static NSString *const StormyEventChannel = @"stormy_gromore/events";
static NSString *const StormyBannerView = @"stormy_gromore/banner";
static NSString *const StormyFeedView = @"stormy_gromore/feed";
static NSString *const StormyDrawFeedView = @"stormy_gromore/draw_feed";

@interface StormyGromorePlugin ()
@property(nonatomic, strong) StormyGromoreEvents *events;
@property(nonatomic, strong) StormyGromoreInitialization *initialization;
@property(nonatomic, strong) StormyGromoreAdRequests *requests;
@property(nonatomic, strong) StormyGromoreFullScreenAds *fullScreen;
@property(nonatomic, strong) NSArray<StormyGromoreViewFactory *> *viewFactories;
@end
@implementation StormyGromorePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *methodChannel =
      [FlutterMethodChannel methodChannelWithName:StormyMethodChannel
                                  binaryMessenger:registrar.messenger];
  FlutterEventChannel *eventChannel =
      [FlutterEventChannel eventChannelWithName:StormyEventChannel
                                binaryMessenger:registrar.messenger];
  StormyGromorePlugin *instance = [[StormyGromorePlugin alloc] init];
  instance.events = [[StormyGromoreEvents alloc] init];
  instance.initialization = [[StormyGromoreInitialization alloc] initWithEvents:instance.events];
  instance.requests = [[StormyGromoreAdRequests alloc] init];
  instance.fullScreen = [[StormyGromoreFullScreenAds alloc] initWithEvents:instance.events
    requests:instance.requests initialization:instance.initialization];
  [registrar addMethodCallDelegate:instance channel:methodChannel];
  [eventChannel setStreamHandler:instance.events];
  instance.viewFactories = @[
    [[StormyGromoreViewFactory alloc] initWithPlugin:instance kind:StormyNativeViewKindBanner],
    [[StormyGromoreViewFactory alloc] initWithPlugin:instance kind:StormyNativeViewKindFeed],
    [[StormyGromoreViewFactory alloc] initWithPlugin:instance kind:StormyNativeViewKindDrawFeed],
  ];
  NSArray<NSString *> *viewIds = @[StormyBannerView, StormyFeedView, StormyDrawFeedView];
  [instance.viewFactories enumerateObjectsUsingBlock:^(StormyGromoreViewFactory *factory, NSUInteger index, BOOL *stop) {
    [registrar registerViewFactory:factory withId:viewIds[index]];
  }];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSDictionary *arguments = [call.arguments isKindOfClass:NSDictionary.class]
                                ? call.arguments
                                : @{};
  @try {
    if ([call.method isEqualToString:@"initialize"]) {
      [self.initialization initializeWithArguments:arguments result:result];
    } else if ([call.method isEqualToString:@"requestTrackingAuthorization"]) {
      [self.initialization requestTrackingAuthorization:result];
    } else if ([call.method isEqualToString:@"loadSplash"]) {
      [self.initialization requireReady:result action:^{
        [self.fullScreen loadSplashWithArguments:arguments result:result];
      }];
    } else if ([call.method isEqualToString:@"showSplash"]) {
      [self.initialization requireReady:result action:^{
        [self.fullScreen showSplashWithArguments:arguments result:result];
      }];
    } else if ([call.method isEqualToString:@"loadRewarded"]) {
      [self.initialization requireReady:result action:^{
        [self.fullScreen loadRewardedWithArguments:arguments result:result];
      }];
    } else if ([call.method isEqualToString:@"showRewarded"]) {
      [self.initialization requireReady:result action:^{
        [self.fullScreen showRewardedWithArguments:arguments result:result];
      }];
    } else if ([call.method isEqualToString:@"loadInterstitial"]) {
      [self.initialization requireReady:result action:^{
        [self.fullScreen loadInterstitialWithArguments:arguments result:result];
      }];
    } else if ([call.method isEqualToString:@"showInterstitial"]) {
      [self.initialization requireReady:result action:^{
        [self.fullScreen showInterstitialWithArguments:arguments result:result];
      }];
    } else if ([call.method isEqualToString:@"preloadAds"]) {
      [self.initialization requireReady:result action:^{
        [self.requests preloadAdsWithArguments:arguments result:result];
      }];
    } else if ([call.method isEqualToString:@"disposeAd"]) {
      [self.initialization requireReady:result action:^{
        [self.fullScreen disposeAdWithArguments:arguments result:result];
      }];
    } else {
      result(FlutterMethodNotImplemented);
    }
  } @catch (NSException *exception) {
    result([FlutterError errorWithCode:@"native_exception"
                               message:exception.reason ?: @"Unknown native exception."
                               details:nil]);
  }
}


- (BOOL)ready { return self.initialization.ready; }
- (void)emitAdType:(NSString *)adType event:(NSString *)event
        requestId:(NSString *)requestId details:(NSDictionary *)details {
  [self.events emitAdType:adType event:event requestId:requestId details:details];
}
- (UIViewController *)topViewController { return [self.requests topViewController]; }
- (NSDictionary *)ecpmDetailsForMediation:(id)mediation { return [self.requests ecpmDetailsForMediation:mediation]; }
- (NSDictionary *)errorDetails:(NSError *)error slotId:(NSString *)slotId { return [self.requests errorDetails:error slotId:slotId]; }
- (void)destroyMediation:(id)mediation { [self.requests destroyMediation:mediation]; }
- (void)runOnMain:(dispatch_block_t)block { [self.requests runOnMain:block]; }
- (BUNativeAdsManager *)nativeAdsManagerWithArguments:(NSDictionary *)arguments {
  return [self.requests nativeAdsManagerWithArguments:arguments];
}
- (void)detachFromEngineForRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  [self.initialization dispose];
  [self.requests dispose];
  [self.fullScreen dispose];
  for (StormyGromoreViewFactory *factory in self.viewFactories) [factory dispose];
  [self.events dispose];
}
- (void)dealloc {
  [self.initialization dispose];
  [self.requests dispose];
  [self.fullScreen dispose];
  for (StormyGromoreViewFactory *factory in self.viewFactories) [factory dispose];
  [self.events dispose];
}
@end

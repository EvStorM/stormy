#import "StormyGromorePlatformViews.h"
#import "StormyGromorePluginInternal.h"
#import "StormyGromoreSupport.h"
@interface StormyGromorePlatformView : StormyGromoreSupport <
    FlutterPlatformView,
    BUMNativeExpressBannerViewDelegate,
    BUMNativeAdsManagerDelegate,
    BUMNativeAdDelegate,
    BUCustomEventProtocol>

- (instancetype)initWithFrame:(CGRect)frame
                     arguments:(NSDictionary *)arguments
                         plugin:(StormyGromorePlugin *)plugin
                           kind:(StormyNativeViewKind)kind;
- (void)dispose;

@end

@interface StormyGromoreViewFactory ()
@property(nonatomic, weak) StormyGromorePlugin *plugin;
@property(nonatomic, assign) StormyNativeViewKind kind;
@property(nonatomic, strong) NSHashTable<StormyGromorePlatformView *> *views;
@end

@implementation StormyGromoreViewFactory

- (instancetype)initWithPlugin:(StormyGromorePlugin *)plugin
                           kind:(StormyNativeViewKind)kind {
  self = [super init];
  if (self != nil) {
    _plugin = plugin;
    _kind = kind;
    _views = [NSHashTable weakObjectsHashTable];
  }
  return self;
}

- (NSObject<FlutterMessageCodec> *)createArgsCodec {
  return FlutterStandardMessageCodec.sharedInstance;
}

- (NSObject<FlutterPlatformView> *)createWithFrame:(CGRect)frame
                                    viewIdentifier:(int64_t)viewId
                                         arguments:(id)args {
  NSDictionary *arguments = [args isKindOfClass:NSDictionary.class] ? args : @{};
  StormyGromorePlatformView *view = [[StormyGromorePlatformView alloc] initWithFrame:frame
                                                arguments:arguments
                                                    plugin:self.plugin
                                                      kind:self.kind];
  [self.views addObject:view];
  return view;
}

- (void)dispose {
  for (StormyGromorePlatformView *view in self.views.allObjects) [view dispose];
  [self.views removeAllObjects];
}
@end

@interface StormyGromorePlatformView ()
@property(nonatomic, strong) UIView *container;
@property(nonatomic, weak) StormyGromorePlugin *plugin;
@property(nonatomic, assign) StormyNativeViewKind kind;
@property(nonatomic, copy) NSString *requestId;
@property(nonatomic, copy) NSString *slotId;
@property(nonatomic, strong) BUNativeExpressBannerView *bannerView;
@property(nonatomic, strong) BUNativeAdsManager *nativeManager;
@property(nonatomic, strong) BUNativeAd *nativeAd;
@property(nonatomic, assign) BOOL disposed;
@property(nonatomic, assign) BOOL nativeRendered;
- (void)loadBanner:(NSDictionary *)arguments;
- (void)loadNativeAd:(NSDictionary *)arguments;
- (BOOL)attachCanvasForNativeAd:(BUNativeAd *)nativeAd;
- (void)reportNativeRenderedIfNeeded;
- (void)reportShownWithMediation:(nullable id)mediation;
- (void)reportEvent:(NSString *)event
            details:(nullable NSDictionary *)details;
- (void)reportFailure:(nullable NSString *)message
                 error:(nullable NSError *)error;
- (NSString *)adType;
- (void)releaseBanner;
- (void)releaseNativeAd;
@end

@implementation StormyGromorePlatformView

- (instancetype)initWithFrame:(CGRect)frame
                     arguments:(NSDictionary *)arguments
                         plugin:(StormyGromorePlugin *)plugin
                           kind:(StormyNativeViewKind)kind {
  self = [super init];
  if (self != nil) {
    _container = [[UIView alloc] initWithFrame:frame];
    _container.clipsToBounds = YES;
    _plugin = plugin;
    _kind = kind;
    _requestId = [arguments[@"requestId"] isKindOfClass:NSString.class]
                     ? arguments[@"requestId"]
                     : @"";
    _slotId = [arguments[@"slotId"] isKindOfClass:NSString.class]
                  ? arguments[@"slotId"]
                  : @"";
    if (_requestId.length == 0 || _slotId.length == 0) {
      [plugin emitAdType:[self adType]
                   event:@"failed"
               requestId:_requestId.length == 0 ? nil : _requestId
                 details:@{ @"message" : @"requestId and slotId are required." }];
    } else if (!plugin.ready) {
      [plugin emitAdType:[self adType]
                   event:@"failed"
               requestId:_requestId
                 details:@{
                   @"slotId" : _slotId,
                   @"message" : @"Initialize GroMore before creating an ad view."
                 }];
    } else if (kind == StormyNativeViewKindBanner) {
      [self loadBanner:arguments];
    } else {
      [self loadNativeAd:arguments];
    }
  }
  return self;
}

- (UIView *)view {
  return self.container;
}

- (void)loadBanner:(NSDictionary *)arguments {
  UIViewController *viewController = [self topViewController];
  if (viewController == nil) {
    [self reportFailure:@"A foreground view controller is required." error:nil];
    return;
  }
  CGFloat width = [arguments[@"width"] doubleValue];
  CGFloat height = [arguments[@"height"] doubleValue];
  BUAdSlot *slot = [[BUAdSlot alloc] init];
  slot.ID = self.slotId;
  slot.mediation.bidNotify = [arguments[@"bidNotify"] boolValue];
  self.bannerView =
      [[BUNativeExpressBannerView alloc] initWithSlot:slot
                                  rootViewController:viewController
                                              adSize:CGSizeMake(width, height)];
  self.bannerView.delegate = self;
  [self.bannerView loadAdData];
}

- (void)loadNativeAd:(NSDictionary *)arguments {
  UIViewController *viewController = [self topViewController];
  if (viewController == nil) {
    [self reportFailure:@"A foreground view controller is required." error:nil];
    return;
  }
  self.nativeManager =
      [self.plugin nativeAdsManagerWithArguments:arguments];
  self.nativeManager.mediation.rootViewController = viewController;
  self.nativeManager.delegate = self;
  [self.nativeManager loadAdDataWithCount:1];
}

- (void)nativeExpressBannerAdViewDidLoad:(BUNativeExpressBannerView *)bannerAdView {
  if (self.disposed || bannerAdView != self.bannerView) return;
  bannerAdView.frame = self.container.bounds;
  bannerAdView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self.container addSubview:bannerAdView];
  [self.plugin emitAdType:@"banner" event:@"loaded" requestId:self.requestId details:@{ @"slotId" : self.slotId }];
}

- (void)nativeExpressBannerAdViewRenderSuccess:(BUNativeExpressBannerView *)bannerAdView {
  if (self.disposed || bannerAdView != self.bannerView) return;
  [self.plugin emitAdType:@"banner" event:@"rendered" requestId:self.requestId details:@{ @"slotId" : self.slotId }];
}

- (void)nativeExpressBannerAdViewRenderFail:(BUNativeExpressBannerView *)bannerAdView
                                      error:(NSError *)error {
  if (self.disposed || bannerAdView != self.bannerView) return;
  [self reportEvent:@"renderFailed"
            details:[self errorDetails:error slotId:self.slotId]];
  [self releaseBanner];
}

- (void)nativeExpressBannerAdView:(BUNativeExpressBannerView *)bannerAdView
             didLoadFailWithError:(NSError *)error {
  if (self.disposed || bannerAdView != self.bannerView) return;
  [self reportFailure:nil error:error];
  [self releaseBanner];
}

- (void)nativeExpressBannerAdViewDidBecomeVisible:(BUNativeExpressBannerView *)bannerAdView {
  if (self.disposed || bannerAdView != self.bannerView) return;
  [self reportShownWithMediation:bannerAdView.mediation];
}

- (void)nativeExpressBannerAdViewDidClick:(BUNativeExpressBannerView *)bannerAdView {
  if (self.disposed || bannerAdView != self.bannerView) return;
  [self reportEvent:@"clicked" details:nil];
}

- (void)nativeExpressBannerAdView:(BUNativeExpressBannerView *)bannerAdView
                 dislikeWithReason:(NSArray<BUDislikeWords *> *)filterWords {
  if (self.disposed || bannerAdView != self.bannerView) return;
  [self reportEvent:@"disliked"
            details:@{ @"extra" : @{ @"reasonCount" : @(filterWords.count) } }];
  [self releaseBanner];
}

- (void)nativeExpressBannerAdViewDidRemoved:(BUNativeExpressBannerView *)bannerAdView {
  if (self.disposed || bannerAdView != self.bannerView) return;
  [self reportEvent:@"closed" details:nil];
  [self releaseBanner];
}

- (void)nativeExpressBannerAdNeedLayoutUI:(BUNativeExpressBannerView *)bannerAd
                               canvasView:(BUMCanvasView *)canvasView {
  if (self.disposed || bannerAd != self.bannerView) return;
  (void)canvasView;
  [self reportFailure:@"Self-rendered banner creatives are not supported; configure this placement as template-rendered."
                 error:nil];
  [self releaseBanner];
}

- (void)nativeAdsManagerSuccessToLoad:(BUNativeAdsManager *)adsManager
                            nativeAds:(NSArray<BUNativeAd *> *)nativeAdDataArray {
  if (self.disposed || adsManager != self.nativeManager) return;
  BUNativeAd *model = nativeAdDataArray.firstObject;
  if (model == nil) {
    [self reportFailure:@"GroMore returned no native creative." error:nil];
    [self releaseNativeAd];
    return;
  }
  UIViewController *viewController = [self topViewController];
  if (viewController == nil) {
    [self reportFailure:@"The foreground view controller detached while loading the ad."
                   error:nil];
    [self releaseNativeAd];
    return;
  }
  self.nativeAd = model;
  model.rootViewController = viewController;
  model.delegate = self;
  [self reportEvent:@"loaded" details:nil];
  if (model.mediation.isExpressAd) {
    if (![self attachCanvasForNativeAd:model]) {
      [self reportEvent:@"renderFailed"
                details:@{ @"message" : @"Native ad canvas is unavailable." }];
      [self releaseNativeAd];
      return;
    }
    [model.mediation render];
  } else {
    [self reportFailure:@"Self-rendered native creatives are not supported; configure this placement as template-rendered."
                   error:nil];
    [self releaseNativeAd];
  }
}

- (void)nativeAdsManager:(BUNativeAdsManager *)adsManager
         didFailWithError:(NSError *)error {
  if (self.disposed || adsManager != self.nativeManager) return;
  [self reportFailure:nil error:error];
  [self releaseNativeAd];
}

- (void)nativeAdExpressViewRenderSuccess:(BUNativeAd *)nativeAd {
  if (self.disposed || nativeAd != self.nativeAd) return;
  if (![self attachCanvasForNativeAd:nativeAd]) {
    [self reportEvent:@"renderFailed"
              details:@{ @"message" : @"Rendered native canvas is unavailable." }];
    [self releaseNativeAd];
    return;
  }
  [self reportNativeRenderedIfNeeded];
}

- (void)nativeAdExpressViewRenderFail:(BUNativeAd *)nativeAd error:(NSError *)error {
  if (self.disposed || nativeAd != self.nativeAd) return;
  [self reportEvent:@"renderFailed"
            details:[self errorDetails:error slotId:self.slotId]];
  [self releaseNativeAd];
}

- (void)nativeAdDidBecomeVisible:(BUNativeAd *)nativeAd {
  if (self.disposed || nativeAd != self.nativeAd) return;
  // Some mediation adapters omit the express-render success callback. Visibility
  // is a safe fallback because it proves that the already-mounted canvas rendered.
  [self reportNativeRenderedIfNeeded];
  [self reportShownWithMediation:nativeAd.mediation];
}

- (void)nativeAdDidClick:(BUNativeAd *)nativeAd withView:(UIView *)view {
  if (self.disposed || nativeAd != self.nativeAd) return;
  [self reportEvent:@"clicked" details:nil];
}

- (void)nativeAdWillPresentFullScreenModal:(BUNativeAd *)nativeAd {
}

- (void)nativeAdVideoDidClick:(BUNativeAd *)nativeAd {
  if (self.disposed || nativeAd != self.nativeAd) return;
  [self reportEvent:@"clicked" details:nil];
}

- (void)nativeAdShakeViewDidDismiss:(BUNativeAd *)nativeAd {
}

- (void)nativeAdVideo:(BUNativeAd *)nativeAd rewardDidCountDown:(NSInteger)countDown {
  if (self.disposed || nativeAd != self.nativeAd) return;
  [self reportEvent:@"videoStateChanged"
            details:@{ @"extra" : @{ @"rewardCountDown" : @(countDown) } }];
}

- (void)nativeAd:(BUNativeAd *)nativeAd
    dislikeWithReason:(NSArray<BUDislikeWords *> *)filterWords {
  if (self.disposed || nativeAd != self.nativeAd) return;
  [self reportEvent:@"disliked"
            details:@{ @"extra" : @{ @"reasonCount" : @(filterWords.count) } }];
  [self releaseNativeAd];
}

- (void)nativeAdVideo:(BUNativeAd *)nativeAd
       stateDidChanged:(BUPlayerPlayState)playerState {
  if (self.disposed || nativeAd != self.nativeAd) return;
  [self reportEvent:@"videoStateChanged"
            details:@{ @"extra" : @{ @"state" : @(playerState) } }];
}

- (void)nativeAdVideoDidPlayFinish:(BUNativeAd *)nativeAd {
  if (self.disposed || nativeAd != self.nativeAd) return;
  [self reportEvent:@"completed" details:nil];
}

- (BOOL)attachCanvasForNativeAd:(BUNativeAd *)nativeAd {
  UIView *canvas = nativeAd.mediation.canvasView;
  if (canvas == nil) return NO;
  canvas.frame = self.container.bounds;
  canvas.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  if (canvas.superview != self.container) {
    [canvas removeFromSuperview];
    [self.container addSubview:canvas];
  }
  return YES;
}

- (void)reportNativeRenderedIfNeeded {
  if (self.nativeRendered) return;
  self.nativeRendered = YES;
  [self reportEvent:@"rendered" details:nil];
}

- (void)reportShownWithMediation:(id)mediation {
  NSMutableDictionary *details = [NSMutableDictionary dictionaryWithObject:self.slotId
                                                                     forKey:@"slotId"];
  [details addEntriesFromDictionary:[self ecpmDetailsForMediation:mediation]];
  [self.plugin emitAdType:[self adType]
                    event:@"shown"
                requestId:self.requestId
                  details:details];
}

- (void)reportEvent:(NSString *)event details:(NSDictionary *)details {
  if (self.disposed && ![event isEqualToString:@"disposed"]) return;
  NSMutableDictionary *combined = [NSMutableDictionary dictionaryWithObject:self.slotId
                                                                       forKey:@"slotId"];
  if (details != nil) [combined addEntriesFromDictionary:details];
  [self.plugin emitAdType:[self adType]
                    event:event
                requestId:self.requestId
                  details:combined];
}

- (void)reportFailure:(NSString *)message error:(NSError *)error {
  if (self.disposed) return;
  NSMutableDictionary *details =
      [NSMutableDictionary dictionaryWithDictionary:[self errorDetails:error
                                                                      slotId:self.slotId]];
  if (message != nil) details[@"message"] = message;
  [self.plugin emitAdType:[self adType]
                    event:@"failed"
                requestId:self.requestId
                  details:details];
}

- (NSString *)adType {
  switch (self.kind) {
    case StormyNativeViewKindBanner:
      return @"banner";
    case StormyNativeViewKindFeed:
      return @"feed";
    case StormyNativeViewKindDrawFeed:
      return @"drawFeed";
  }
}

- (void)dispose {
  if (self.disposed) return;
  [self reportEvent:@"disposed" details:nil];
  self.disposed = YES;
  [self releaseBanner];
  [self releaseNativeAd];
}

- (void)releaseBanner {
  BUNativeExpressBannerView *banner = self.bannerView;
  self.bannerView = nil;
  banner.delegate = nil;
  [banner removeFromSuperview];
  [self destroyMediation:banner.mediation];
}

- (void)releaseNativeAd {
  BUNativeAd *nativeAd = self.nativeAd;
  BUNativeAdsManager *manager = self.nativeManager;
  self.nativeAd = nil;
  self.nativeManager = nil;
  self.nativeRendered = NO;
  nativeAd.delegate = nil;
  [nativeAd.mediation.canvasView removeFromSuperview];
  manager.delegate = nil;
  [self destroyMediation:manager.mediation];
}

- (void)dealloc {
  [self dispose];
}

@end

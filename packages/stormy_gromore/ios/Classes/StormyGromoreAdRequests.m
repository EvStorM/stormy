#import "StormyGromoreAdRequests.h"
#import <Network/Network.h>
static NSUInteger const StormyMaximumPreloadPlacements = 20;
static NSString *const StormyPreloadWifiOnly = @"wifiOnly";
static NSString *const StormyPreloadAnyNetwork = @"any";
@interface StormyGromoreAdRequests ()
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *monitors;
@property(nonatomic, strong) NSMutableDictionary<NSString *, FlutterResult> *pendingResults;
@property(nonatomic, assign) BOOL disposed;
@end
@implementation StormyGromoreAdRequests
- (instancetype)init {
  self = [super init];
  if (self) {
    _monitors = [NSMutableDictionary dictionary];
    _pendingResults = [NSMutableDictionary dictionary];
  }
  return self;
}
- (void)preloadAdsWithArguments:(NSDictionary *)arguments
                          result:(FlutterResult)result {
  NSArray *rawItems = [arguments[@"items"] isKindOfClass:NSArray.class]
                          ? arguments[@"items"]
                          : nil;
  if (rawItems == nil || rawItems.count == 0 ||
      rawItems.count > StormyMaximumPreloadPlacements) {
    result([FlutterError
        errorWithCode:@"invalid_arguments"
              message:[NSString
                          stringWithFormat:@"items must contain between 1 and %lu placements.",
                                           (unsigned long)StormyMaximumPreloadPlacements]
              details:nil]);
    return;
  }

  NSNumber *intervalValue =
      [arguments[@"intervalSeconds"] isKindOfClass:NSNumber.class]
          ? arguments[@"intervalSeconds"]
          : nil;
  NSInteger interval = intervalValue.integerValue;
  if (intervalValue == nil || intervalValue.doubleValue != interval ||
      interval < 1 || interval > 10) {
    result([FlutterError errorWithCode:@"invalid_arguments"
                               message:@"intervalSeconds must be an integer between 1 and 10."
                               details:nil]);
    return;
  }

  NSNumber *concurrentValue =
      [arguments[@"concurrent"] isKindOfClass:NSNumber.class]
          ? arguments[@"concurrent"]
          : nil;
  NSInteger concurrent = concurrentValue.integerValue;
  if (concurrentValue == nil || concurrentValue.doubleValue != concurrent ||
      concurrent < 1 || concurrent > 20) {
    result([FlutterError errorWithCode:@"invalid_arguments"
                               message:@"concurrent must be an integer between 1 and 20."
                               details:nil]);
    return;
  }

  NSString *network = [self requiredString:arguments key:@"network" result:result];
  if (network == nil) return;
  if (![network isEqualToString:StormyPreloadWifiOnly] &&
      ![network isEqualToString:StormyPreloadAnyNetwork]) {
    result([FlutterError errorWithCode:@"invalid_arguments"
                               message:@"network must be wifiOnly or any."
                               details:nil]);
    return;
  }

  NSMutableSet<NSString *> *placements = [NSMutableSet set];
  NSMutableArray<NSDictionary *> *items = [NSMutableArray array];
  NSSet<NSString *> *supportedTypes =
      [NSSet setWithObjects:@"splash", @"rewarded", @"interstitial", @"feed", nil];
  for (id rawItem in rawItems) {
    if (![rawItem isKindOfClass:NSDictionary.class]) {
      result([FlutterError errorWithCode:@"invalid_arguments"
                                 message:@"Each preload item must be a map."
                                 details:nil]);
      return;
    }
    NSDictionary *item = rawItem;
    NSString *adType = [self requiredString:item key:@"adType" result:result];
    NSDictionary *request = [item[@"request"] isKindOfClass:NSDictionary.class]
                                ? item[@"request"]
                                : nil;
    if (adType == nil) return;
    if (request == nil) {
      result([FlutterError errorWithCode:@"invalid_arguments"
                                 message:@"Each preload item must include request parameters."
                                 details:nil]);
      return;
    }
    if (![supportedTypes containsObject:adType]) {
      result([FlutterError
          errorWithCode:@"unsupported_preload_type"
                message:[NSString stringWithFormat:
                                       @"GroMore does not support first precaching for %@.",
                                       adType]
                details:nil]);
      return;
    }
    NSString *slotId = [self requiredString:request key:@"slotId" result:result];
    if (slotId == nil) return;
    if ([adType isEqualToString:@"feed"]) {
      NSNumber *width = [request[@"width"] isKindOfClass:NSNumber.class]
                            ? request[@"width"]
                            : nil;
      NSNumber *height = [request[@"height"] isKindOfClass:NSNumber.class]
                             ? request[@"height"]
                             : nil;
      if (width == nil || height == nil || width.doubleValue <= 0 ||
          height.doubleValue <= 0) {
        result([FlutterError errorWithCode:@"invalid_arguments"
                                   message:@"Feed width and height must be positive numbers."
                                   details:nil]);
        return;
      }
    }
    NSString *placement =
        [NSString stringWithFormat:@"%@/%@", adType, slotId];
    if ([placements containsObject:placement]) {
      result([FlutterError
          errorWithCode:@"invalid_arguments"
                message:[NSString stringWithFormat:@"Duplicate preload placement: %@.",
                                                   placement]
                details:nil]);
      return;
    }
    [placements addObject:placement];
    [items addObject:@{ @"adType" : adType, @"request" : [request copy] }];
  }

  NSString *token = NSUUID.UUID.UUIDString;
  self.pendingResults[token] = result;
  __weak typeof(self) weakSelf = self;
  __block BOOL receivedFirstPath = NO;
  __block nw_path_monitor_t retainedMonitor = nw_path_monitor_create();
  dispatch_queue_t queue =
      dispatch_queue_create("com.stormy.gromore.preload-network", DISPATCH_QUEUE_SERIAL);
  self.monitors[token] = retainedMonitor;
  nw_path_monitor_set_queue(retainedMonitor, queue);
  nw_path_monitor_set_update_handler(retainedMonitor, ^(nw_path_t path) {
    if (receivedFirstPath) return;
    receivedFirstPath = YES;
    BOOL connected = nw_path_get_status(path) == nw_path_status_satisfied;
    BOOL usesWifi = nw_path_uses_interface_type(path, nw_interface_type_wifi);
    nw_path_monitor_cancel(retainedMonitor);
    retainedMonitor = nil;

    dispatch_async(dispatch_get_main_queue(), ^{
      __strong typeof(weakSelf) self = weakSelf;
      if (self == nil || self.disposed) return;
      [self.monitors removeObjectForKey:token];
      [self.pendingResults removeObjectForKey:token];
      if (!connected) {
        result(@"skippedNoNetwork");
        return;
      }
      if ([network isEqualToString:StormyPreloadWifiOnly] && !usesWifi) {
        result(@"skippedNotWifi");
        return;
      }

      @try {
        NSMutableArray *infos = [NSMutableArray arrayWithCapacity:items.count];
        for (NSDictionary *item in items) {
          NSString *adType = item[@"adType"];
          NSDictionary *request = item[@"request"];
          if ([adType isEqualToString:@"splash"]) {
            [infos addObject:[self splashAdWithArguments:request]];
          } else if ([adType isEqualToString:@"rewarded"]) {
            [infos addObject:[self rewardedAdWithArguments:request]];
          } else if ([adType isEqualToString:@"interstitial"]) {
            [infos addObject:[self interstitialAdWithArguments:request]];
          } else {
            BUNativeAdsManager *manager =
                [self nativeAdsManagerWithArguments:request];
            manager.mediation.rootViewController = [self topViewController];
            [infos addObject:manager];
          }
        }
        [BUAdSDKManager.mediation preloadAdsWithInfos:infos
                                         andInterval:interval
                                       andConcurrent:concurrent];
        result(@"requested");
      } @catch (NSException *exception) {
        result([FlutterError errorWithCode:@"native_exception"
                                   message:exception.reason ?: @"Unknown native exception."
                                   details:nil]);
      }
    });
  });
  nw_path_monitor_start(retainedMonitor);
}

- (BUSplashAd *)splashAdWithArguments:(NSDictionary *)arguments {
  BUAdSlot *slot = [[BUAdSlot alloc] init];
  slot.ID = arguments[@"slotId"];
  slot.mediation.mutedIfCan = [self boolValue:arguments key:@"muted" fallback:YES];
  slot.mediation.bidNotify = [self boolValue:arguments key:@"bidNotify" fallback:NO];
  return [[BUSplashAd alloc] initWithSlot:slot
                                  adSize:UIScreen.mainScreen.bounds.size];
}

- (BUNativeExpressRewardedVideoAd *)rewardedAdWithArguments:
    (NSDictionary *)arguments {
  BUAdSlot *slot = [[BUAdSlot alloc] init];
  slot.ID = arguments[@"slotId"];
  slot.mediation.mutedIfCan = [self boolValue:arguments key:@"muted" fallback:NO];
  slot.mediation.bidNotify = [self boolValue:arguments key:@"bidNotify" fallback:NO];
  BURewardedVideoModel *model = [[BURewardedVideoModel alloc] init];
  [self setValue:arguments[@"userId"]
         onObject:model
     possibleKeys:@[ @"userId", @"userID" ]];
  [self setValue:arguments[@"customData"]
         onObject:model
     possibleKeys:@[ @"extra", @"customData" ]];
  [self setValue:arguments[@"rewardName"]
         onObject:model
     possibleKeys:@[ @"rewardName" ]];
  [self setValue:arguments[@"rewardAmount"]
         onObject:model
     possibleKeys:@[ @"rewardAmount" ]];
  BUNativeExpressRewardedVideoAd *ad =
      [[BUNativeExpressRewardedVideoAd alloc] initWithSlot:slot
                                      rewardedVideoModel:model];
  [ad.mediation addParam:@([self integerValue:arguments
                                                key:@"orientation"
                                           fallback:0])
                 withKey:@"show_direction"];
  return ad;
}

- (BUNativeExpressFullscreenVideoAd *)interstitialAdWithArguments:
    (NSDictionary *)arguments {
  BUAdSlot *slot = [[BUAdSlot alloc] init];
  slot.ID = arguments[@"slotId"];
  slot.mediation.mutedIfCan = [self boolValue:arguments key:@"muted" fallback:NO];
  slot.mediation.bidNotify = [self boolValue:arguments key:@"bidNotify" fallback:NO];
  BUNativeExpressFullscreenVideoAd *ad =
      [[BUNativeExpressFullscreenVideoAd alloc] initWithSlot:slot];
  [ad.mediation addParam:@([self integerValue:arguments
                                                key:@"orientation"
                                           fallback:0])
                 withKey:@"show_direction"];
  return ad;
}

- (BUNativeAdsManager *)nativeAdsManagerWithArguments:
    (NSDictionary *)arguments {
  BUAdSlot *slot = [[BUAdSlot alloc] init];
  slot.ID = arguments[@"slotId"];
  slot.adSize = CGSizeMake([arguments[@"width"] doubleValue],
                           [arguments[@"height"] doubleValue]);
  slot.mediation.mutedIfCan = [self boolValue:arguments key:@"muted" fallback:NO];
  slot.mediation.bidNotify = [self boolValue:arguments key:@"bidNotify" fallback:NO];
  return [[BUNativeAdsManager alloc] initWithSlot:slot];
}


- (void)dispose {
  self.disposed = YES;
  for (id monitor in self.monitors.allValues) nw_path_monitor_cancel(monitor);
  [self.monitors removeAllObjects];
  NSArray *callbacks = self.pendingResults.allValues;
  [self.pendingResults removeAllObjects];
  for (FlutterResult callback in callbacks) {
    callback([FlutterError errorWithCode:@"engine_detached"
      message:@"Flutter engine detached during preload." details:nil]);
  }
}
- (void)dealloc { [self dispose]; }
@end

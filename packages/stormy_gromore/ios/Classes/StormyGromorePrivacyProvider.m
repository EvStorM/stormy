#import "StormyGromorePrivacyProvider.h"
#import <AppTrackingTransparency/AppTrackingTransparency.h>
@interface StormyGromorePrivacyProvider ()

@property(nonatomic, copy) NSDictionary *privacy;

@end


@implementation StormyGromorePrivacyProvider

- (instancetype)initWithPrivacy:(NSDictionary *)privacy {
  self = [super init];
  if (self != nil) {
    _privacy = [privacy copy];
  }
  return self;
}

- (BOOL)canUseLocation {
  return [self boolValueForKey:@"canUseLocation"];
}

- (CLLocationDegrees)latitude {
  return 0;
}

- (CLLocationDegrees)longitude {
  return 0;
}

- (BOOL)canUseWiFiBSSID {
  return [self boolValueForKey:@"canUseWifiState"];
}

- (NSDictionary *)privacyConfig {
  BOOL canUsePhoneState = [self boolValueForKey:@"canUsePhoneState"];
  BOOL canUseIdfa = [self canUseIdfa];
  return @{
    kBUMPrivacyLimitPersonalAds :
        @([self boolValueForKey:@"limitPersonalAds"]),
    kBUMPrivacyLimitProgrammaticAds :
        @([self boolValueForKey:@"limitProgrammaticAds"]),
    kBUMPrivacyForbiddenIDFA : @(!canUseIdfa),
    kBUMPrivacyAdvertiserTrackingEnabled : canUseIdfa ? @"1" : @"0",
    kBUMPrivacyMotionInfo :
        [self boolValueForKey:@"canUseSensors"] ? @"1" : @"0",
    kBUMPrivacyLimitPersonalCPUs :
        [self boolValueForKey:@"limitPersonalAds"] ? @"1" : @"0",
    kBUMPrivacyDisableUsePhoneStatus : canUsePhoneState ? @"0" : @"1",
    kBUMPrivacyForbiddenIDFV :
        [self boolValueForKey:@"canUseIdfv"] ? @"0" : @"1",
    kBUMPrivacyCanUseSpaceSize :
        [self boolValueForKey:@"canUseStorageSize"] ? @"1" : @"0",
    kBUMPrivacyCanUseCarrier : @(canUsePhoneState),
  };
}

- (BOOL)canUseIdfa {
  if (![self boolValueForKey:@"canUseIdfa"]) return NO;
  if (@available(iOS 14, *)) {
    return ATTrackingManager.trackingAuthorizationStatus ==
           ATTrackingManagerAuthorizationStatusAuthorized;
  }
  return YES;
}

- (BOOL)boolValueForKey:(NSString *)key {
  NSNumber *value = [self.privacy[key] isKindOfClass:NSNumber.class]
                        ? self.privacy[key]
                        : nil;
  return value != nil && value.boolValue;
}

@end


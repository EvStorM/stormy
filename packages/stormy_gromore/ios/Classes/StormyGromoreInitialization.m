#import "StormyGromoreInitialization.h"
#import "StormyGromorePrivacyProvider.h"
#import <AppTrackingTransparency/AppTrackingTransparency.h>
static NSInteger const StormyDefaultRewardCallbackRetentionMilliseconds = 6000;
static NSInteger const StormyMaximumConfigDurationMilliseconds = 2147483647;
@interface StormyGromoreInitialization ()
@property(nonatomic, assign) BOOL ready;
@property(nonatomic, assign) BOOL initializing;
@property(nonatomic, assign) NSTimeInterval rewardCallbackRetentionSeconds;
@property(nonatomic, strong) StormyGromorePrivacyProvider *privacyProvider;
@property(nonatomic, strong) StormyGromoreEvents *events;
@property(nonatomic, copy) FlutterResult pendingResult;
@end
@implementation StormyGromoreInitialization
- (instancetype)initWithEvents:(StormyGromoreEvents *)events {
  self = [super init];
  if (self) { _events = events; _rewardCallbackRetentionSeconds = 6.0; }
  return self;
}
- (void)initializeWithArguments:(NSDictionary *)arguments
                         result:(FlutterResult)result {
  NSNumber *retentionValue =
      [arguments[@"rewardCallbackRetentionMs"] isKindOfClass:NSNumber.class]
          ? arguments[@"rewardCallbackRetentionMs"]
          : nil;
  NSInteger retentionMilliseconds =
      retentionValue == nil
          ? StormyDefaultRewardCallbackRetentionMilliseconds
          : retentionValue.integerValue;
  if (retentionValue != nil &&
      (retentionValue.doubleValue != retentionMilliseconds ||
       retentionMilliseconds < 1 ||
       retentionMilliseconds > StormyMaximumConfigDurationMilliseconds)) {
    result([FlutterError
        errorWithCode:@"invalid_arguments"
              message:@"rewardCallbackRetentionMs must be a positive integer no greater than 2147483647."
              details:nil]);
    return;
  }
  self.rewardCallbackRetentionSeconds = retentionMilliseconds / 1000.0;
  if (self.ready) {
    result(@YES);
    return;
  }
  if (self.initializing) {
    result([FlutterError errorWithCode:@"initialization_in_progress"
                               message:@"GroMore initialization is already in progress."
                               details:nil]);
    return;
  }
  NSString *appId = [self requiredString:arguments key:@"appId" result:result];
  NSString *appName = [self requiredString:arguments key:@"appName" result:result];
  if (appId == nil || appName == nil) {
    return;
  }

  NSDictionary *privacy = [arguments[@"privacy"] isKindOfClass:NSDictionary.class]
                              ? arguments[@"privacy"]
                              : @{};
  BUAdSDKConfiguration *configuration = [BUAdSDKConfiguration configuration];
  configuration.appID = appId;
  configuration.debugLog =
      @([self boolValue:arguments key:@"debug" fallback:NO]);
  configuration.useMediation = [self boolValue:arguments
                                           key:@"useMediation"
                                      fallback:YES];
  configuration.themeStatus = @([self integerValue:arguments key:@"theme" fallback:0]);
  self.privacyProvider =
      [[StormyGromorePrivacyProvider alloc] initWithPrivacy:privacy];
  configuration.privacyProvider = self.privacyProvider;
  configuration.mediation.forbiddenIDFA = @(!self.privacyProvider.canUseIdfa);
  // `forbiddenCAID` is present only in some GroMore releases. Resolve the
  // setter dynamically so the privacy flag is applied where supported while
  // remaining source-compatible with SDKs whose public header omits it.
  [self setValue:@([self boolValue:privacy key:@"forbidCaid" fallback:YES])
           onObject:configuration.mediation
       possibleKeys:@[ @"forbiddenCAID" ]];
  configuration.mediation.limitPersonalAds =
      @([self boolValue:privacy key:@"limitPersonalAds" fallback:YES]);
  configuration.mediation.limitProgrammaticAds =
      @([self boolValue:privacy key:@"limitProgrammaticAds" fallback:YES]);
  configuration.mediation.allowUploadDeviceInfo =
      [self boolValue:privacy key:@"allowUploadDeviceInfo" fallback:NO];

  self.initializing = YES;
  self.pendingResult = result;
  __weak typeof(self) weakSelf = self;
  @try {
    [BUAdSDKManager startWithAsyncCompletionHandler:^(BOOL success, NSError *error) {
      dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil || !strongSelf.initializing) {
          return;
        }
        strongSelf.initializing = NO;
        strongSelf.pendingResult = nil;
        strongSelf.ready = success;
        if (success) {
          [strongSelf.events emitAdType:@"sdk"
                           event:@"initialized"
                       requestId:nil
                         details:nil];
          result(@YES);
        } else {
          NSDictionary *details = [strongSelf errorDetails:error slotId:nil];
          [strongSelf.events emitAdType:@"sdk"
                           event:@"failed"
                       requestId:nil
                         details:details];
          result([FlutterError errorWithCode:@"initialization_failed"
                                     message:error.localizedDescription ?: @"GroMore initialization failed."
                                     details:details]);
        }
      });
    }];
  } @catch (NSException *exception) {
    self.initializing = NO;
    self.pendingResult = nil;
    @throw exception;
  }
}

- (void)requestTrackingAuthorization:(FlutterResult)result {
  if (@available(iOS 14, *)) {
    [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:
        ^(ATTrackingManagerAuthorizationStatus status) {
      NSString *value;
      switch (status) {
        case ATTrackingManagerAuthorizationStatusNotDetermined:
          value = @"notDetermined";
          break;
        case ATTrackingManagerAuthorizationStatusRestricted:
          value = @"restricted";
          break;
        case ATTrackingManagerAuthorizationStatusDenied:
          value = @"denied";
          break;
        case ATTrackingManagerAuthorizationStatusAuthorized:
          value = @"authorized";
          break;
        default:
          value = @"notSupported";
          break;
      }
      dispatch_async(dispatch_get_main_queue(), ^{
        result(value);
      });
    }];
  } else {
    result(@"notSupported");
  }
}

- (void)requireReady:(FlutterResult)result action:(dispatch_block_t)action {
  if (!self.ready) {
    result([FlutterError errorWithCode:@"not_initialized"
                               message:@"Initialize GroMore successfully before loading or showing ads."
                               details:nil]);
    return;
  }
  action();
}


- (void)dispose {
  self.initializing = NO;
  self.ready = NO;
  FlutterResult callback = self.pendingResult;
  self.pendingResult = nil;
  if (callback) callback([FlutterError errorWithCode:@"engine_detached"
    message:@"Flutter engine detached during GroMore initialization." details:nil]);
}
@end

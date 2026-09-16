#import "StormyGromoreSupport.h"
#import <objc/message.h>
#import "StormyRewardTerminalState.h"

@implementation StormyGromoreSupport
- (void)runOnMain:(dispatch_block_t)block {
  if (NSThread.isMainThread) {
    block();
  } else {
    dispatch_async(dispatch_get_main_queue(), block);
  }
}

- (NSString *)requiredString:(NSDictionary *)arguments
                           key:(NSString *)key
                        result:(FlutterResult)result {
  NSString *value = [arguments[key] isKindOfClass:NSString.class] ? arguments[key] : nil;
  if (value.length == 0) {
    result([FlutterError errorWithCode:@"invalid_arguments"
                               message:[NSString stringWithFormat:@"%@ must not be empty.", key]
                               details:nil]);
    return nil;
  }
  return value;
}

- (BOOL)boolValue:(NSDictionary *)arguments key:(NSString *)key fallback:(BOOL)fallback {
  NSNumber *number = [arguments[key] isKindOfClass:NSNumber.class] ? arguments[key] : nil;
  return number == nil ? fallback : number.boolValue;
}

- (NSInteger)integerValue:(NSDictionary *)arguments
                        key:(NSString *)key
                   fallback:(NSInteger)fallback {
  NSNumber *number = [arguments[key] isKindOfClass:NSNumber.class] ? arguments[key] : nil;
  return number == nil ? fallback : number.integerValue;
}

- (void)setValue:(id)value onObject:(id)object possibleKeys:(NSArray<NSString *> *)keys {
  if (value == nil || value == NSNull.null) return;
  for (NSString *key in keys) {
    NSString *first = [[key substringToIndex:1] uppercaseString];
    NSString *setterName = [NSString stringWithFormat:@"set%@%@:", first, [key substringFromIndex:1]];
    if ([object respondsToSelector:NSSelectorFromString(setterName)]) {
      [object setValue:value forKey:key];
      return;
    }
  }
}

- (NSDictionary *)errorDetails:(NSError *)error slotId:(NSString *)slotId {
  NSMutableDictionary *details = [NSMutableDictionary dictionary];
  if (slotId != nil) details[@"slotId"] = slotId;
  if (error != nil) {
    details[@"code"] = @(error.code);
    details[@"message"] = error.localizedDescription ?: @"Unknown SDK error.";
  }
  return details;
}

- (NSDictionary *)ecpmDetailsForMediation:(id)mediation {
  if (mediation == nil || ![mediation respondsToSelector:@selector(getShowEcpmInfo)]) {
    return @{};
  }
  BUMRitInfo *info = [mediation getShowEcpmInfo];
  if (info == nil) return @{};
  NSMutableDictionary *details = [NSMutableDictionary dictionary];
  if (info.ecpm != nil) details[@"ecpm"] = info.ecpm;
  if (info.adnName != nil) details[@"adnName"] = info.adnName;
  if (info.slotID != nil) details[@"adnSlotId"] = info.slotID;
  if (info.requestID != nil) details[@"networkRequestId"] = info.requestID;
  return details;
}

- (void)destroyMediation:(id)mediation {
  if (mediation == nil) return;
  SEL selector = NSSelectorFromString(@"destoryAd");
  if (![mediation respondsToSelector:selector]) {
    selector = NSSelectorFromString(@"destory");
  }
  if ([mediation respondsToSelector:selector]) {
    ((void (*)(id, SEL))objc_msgSend)(mediation, selector);
  }
}

- (void)unknownAd:(NSString *)adType
          requestId:(NSString *)requestId
              result:(FlutterResult)result {
  result([FlutterError errorWithCode:@"unknown_ad"
                             message:[NSString stringWithFormat:@"Unknown %@ request: %@", adType, requestId]
                             details:nil]);
}

- (UIViewController *)topViewController {
  UIWindow *keyWindow = nil;
  for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
    if (![scene isKindOfClass:UIWindowScene.class] ||
        scene.activationState != UISceneActivationStateForegroundActive) {
      continue;
    }
    for (UIWindow *window in ((UIWindowScene *)scene).windows) {
      if (window.isKeyWindow) {
        keyWindow = window;
        break;
      }
    }
    if (keyWindow != nil) break;
  }
  UIViewController *controller = keyWindow.rootViewController;
  while (controller != nil) {
    if (controller.presentedViewController != nil) {
      controller = controller.presentedViewController;
    } else if ([controller isKindOfClass:UINavigationController.class]) {
      controller = ((UINavigationController *)controller).visibleViewController;
    } else if ([controller isKindOfClass:UITabBarController.class]) {
      controller = ((UITabBarController *)controller).selectedViewController;
    } else {
      break;
    }
  }
  return StormyCanPresentHost(YES, controller != nil, controller.isBeingDismissed) ? controller : nil;
}

@end

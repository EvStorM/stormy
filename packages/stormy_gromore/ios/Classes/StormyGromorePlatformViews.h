#pragma once
#import "StormyGromorePlugin.h"
typedef NS_ENUM(NSInteger, StormyNativeViewKind) {
  StormyNativeViewKindBanner,
  StormyNativeViewKindFeed,
  StormyNativeViewKindDrawFeed,
};

@interface StormyGromoreViewFactory : NSObject <FlutterPlatformViewFactory>

- (instancetype)initWithPlugin:(StormyGromorePlugin *)plugin
                           kind:(StormyNativeViewKind)kind;

- (void)dispose;
@end


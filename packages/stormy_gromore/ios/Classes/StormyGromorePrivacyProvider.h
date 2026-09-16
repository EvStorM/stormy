#pragma once
#import <BUAdSDK/BUAdSDK.h>
@interface StormyGromorePrivacyProvider : NSObject <BUAdSDKPrivacyProvider>

- (instancetype)initWithPrivacy:(NSDictionary *)privacy;
- (BOOL)canUseIdfa;

@end


#pragma once
#import "StormyGromoreSupport.h"

@interface StormyGromoreEvents : StormyGromoreSupport <FlutterStreamHandler>
- (void)dispose;
- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events;
- (FlutterError *)onCancelWithArguments:(id)arguments;
- (void)emitAdType:(NSString *)adType
              event:(NSString *)event
          requestId:(NSString *)requestId
            details:(NSDictionary *)details;
@end

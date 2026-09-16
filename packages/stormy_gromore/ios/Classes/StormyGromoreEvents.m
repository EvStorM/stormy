#import "StormyGromoreEvents.h"
static NSUInteger const StormyMaximumPendingEvents = 100;
@interface StormyGromoreEvents ()
@property(nonatomic, copy) FlutterEventSink eventSink;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *pendingEvents;
@property(nonatomic, assign) BOOL disposed;
@end
@implementation StormyGromoreEvents
- (instancetype)init {
  self = [super init];
  if (self) _pendingEvents = [NSMutableArray array];
  return self;
}
- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
  self.eventSink = events;
  for (NSDictionary *event in self.pendingEvents) {
    events(event);
  }
  [self.pendingEvents removeAllObjects];
  return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
  self.eventSink = nil;
  return nil;
}

- (void)emitAdType:(NSString *)adType
              event:(NSString *)event
          requestId:(NSString *)requestId
            details:(NSDictionary *)details {
  dispatch_block_t block = ^{
    if (self.disposed) return;
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithDictionary:@{
      @"adType" : adType,
      @"event" : event,
    }];
    if (requestId != nil) payload[@"requestId"] = requestId;
    if (details != nil) [payload addEntriesFromDictionary:details];
    if (self.eventSink != nil) {
      self.eventSink(payload);
    } else {
      if (self.pendingEvents.count == StormyMaximumPendingEvents) {
        [self.pendingEvents removeObjectAtIndex:0];
      }
      [self.pendingEvents addObject:payload];
    }
  };
  if (NSThread.isMainThread) {
    block();
  } else {
    dispatch_async(dispatch_get_main_queue(), block);
  }
}


- (void)dispose {
  self.disposed = YES;
  self.eventSink = nil;
  [self.pendingEvents removeAllObjects];
}
@end

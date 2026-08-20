#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(CliqItModule, RCTEventEmitter)

RCT_EXTERN_METHOD(configure:(NSString *)apiKey)
RCT_EXTERN_METHOD(handleUrl:(NSString *)urlString)

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

@end

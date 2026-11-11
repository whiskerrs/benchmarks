#import <Foundation/Foundation.h>

@interface SBNative : NSObject
/// Writes the benchmark marker line to the unified log.
+ (void)logHomeReady;
/// Presents the URL in an SFSafariViewController over the key window.
+ (void)openInAppBrowser:(NSString *)url;
@end

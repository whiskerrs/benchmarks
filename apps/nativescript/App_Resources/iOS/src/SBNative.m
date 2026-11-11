#import "SBNative.h"
#import <os/log.h>
#import <UIKit/UIKit.h>
#import <SafariServices/SafariServices.h>

@implementation SBNative

+ (void)logHomeReady {
    os_log(OS_LOG_DEFAULT, "SHOPBENCH home_ready");
}

+ (UIViewController *)topViewController {
    UIWindow *keyWindow = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (w.isKeyWindow) { keyWindow = w; break; }
        }
        if (keyWindow) break;
    }
    UIViewController *vc = keyWindow.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

+ (void)openInAppBrowser:(NSString *)url {
    NSURL *u = [NSURL URLWithString:url];
    if (!u) return;
    SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:u];
    [[self topViewController] presentViewController:safari animated:YES completion:nil];
}

@end

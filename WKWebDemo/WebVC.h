//
//  WebVC.h
//  WKWebDemo
//
//  Created by Joymake on 2019/8/14.
//  Copyright © 2019 IB. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WebVC : UIViewController
@property (nonatomic,strong,readonly)WKWebView *wkWebView;
@property (nonatomic,strong,readonly)WKUserContentController *userContentController ;
@property (nonatomic,assign) BOOL isNavHidden;

- (void)addJsCallNativeMethods:(NSSet *)methods;
@end

NS_ASSUME_NONNULL_END

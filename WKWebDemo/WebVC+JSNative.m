//
//  WebVC+JSNative.m
//  WKWebDemo
//
//  Created by Joymake on 2019/8/14.
//  Copyright © 2019 IB. All rights reserved.
//

#import "WebVC+JSNative.h"

@implementation WebVC (JSNative)

-(void)registOCMethods:(NSSet *)methods{
    for (NSString *method in methods) {
        [self.userContentController addScriptMessageHandler:self name:method];
    }
}

- (void)removeOCMethods:(NSSet *)methods{
    for (NSString *method in methods) {
        [self.userContentController removeScriptMessageHandlerForName:method];
    }
}

//js获取app运行环境
- (void)getAppEnv:(NSString *)env{
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *shareResult = [NSString stringWithFormat:@"appEnvResult('%@')",version];
    //OC调用JS
    [self.wkWebView evaluateJavaScript:shareResult completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        NSLog(@"%@", error);
    }];
}

//js调用app分享
- (void)Share:(NSDictionary *)dic{
    if (![dic isKindOfClass:[NSDictionary class]]) {
        return;
    }
    NSString *title = [dic objectForKey:@"title"];
    NSString *content = [dic objectForKey:@"content"];
    NSString *url = [dic objectForKey:@"shareUrl"];
    //在这里写分享操作的代码
    NSLog(@"要分享了哦😯");
    //OC反馈给JS分享结果
    NSError * error = nil;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&error];
    NSString * jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    NSString *replaceStr = [jsonStr stringByReplacingOccurrencesOfString:@"\"" withString:@"\'"];
    NSString *JSResult = [NSString stringWithFormat:@"shareResult('%@','%@','%@',%@)",title,content,url,replaceStr];
    //OC调用JS
    [self.wkWebView evaluateJavaScript:JSResult completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        NSLog(@"%@", error);
    }];
}

- (void)Camera:(id)obj{
    NSString *JSResult = [NSString stringWithFormat:@"cameraResult('%@')",@"保存相册照片成功"];
    [self.wkWebView evaluateJavaScript:JSResult completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        NSLog(@"%@----%@",result, error);
    }];
}
@end

@implementation WebVC (FiltUrl)

-(void)filtHTTP{
    Class cls = NSClassFromString(@"WKBrowsingContextController");
    SEL sel = NSSelectorFromString(@"registerSchemeForCustomProtocol:");
    if ([(id)cls respondsToSelector:sel]) {
        [(id)cls performSelector:sel withObject:@"http"];
        [(id)cls performSelector:sel withObject:@"https"];
    }
}

@end

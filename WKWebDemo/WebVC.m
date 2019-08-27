//
//  WebVC.m
//  WKWebDemo
//
//  Created by Joymake on 2019/8/14.
//  Copyright © 2019 IB. All rights reserved.
//

#import "WebVC.h"
#import "WebVC+JSNative.h"
#import "UrlRedirectionProtocol.h"

@interface WebVC()<WKUIDelegate,WKScriptMessageHandler,WKNavigationDelegate>
@property (nonatomic,strong)WKWebView *wkWebView;
@property (nonatomic,strong)WKWebViewConfiguration *configuration;
@property (nonatomic,strong)WKPreferences *preferences;
@property (nonatomic,strong)WKUserContentController *userContentController ;
@property (nonatomic,copy)NSMutableSet<NSString *> *calledByJSMethodSet;
@property (nonatomic,strong)UIProgressView *progressView;
@property (nonatomic)UIBarButtonItem* backItem;
@property (nonatomic)UIBarButtonItem* closeButtonItem;
@property (nonatomic)UIBarButtonItem* rightButtonItem;
@end

@implementation WebVC
-(WKUserContentController *)userContentController{
    return _userContentController = _userContentController?:[WKUserContentController new];
}

-(WKWebViewConfiguration *)configuration{
    if (!_configuration) {
        _configuration = [WKWebViewConfiguration new];
        _configuration.userContentController = self.userContentController;
        _configuration.preferences = self.preferences;
        //        [_configuration setURLSchemeHandler:[CustomURLSchemeHandler new] forURLScheme: @"customScheme"];
    }
    return _configuration;
}

-(WKPreferences *)preferences{
    if (!_preferences) {
        _preferences = [WKPreferences new];
        _preferences.javaScriptCanOpenWindowsAutomatically = YES;
        //        _preferences.minimumFontSize = 40.0;
    }
    return _preferences;
}
static void *WkwebBrowserContext = &WkwebBrowserContext;
-(WKWebView *)wkWebView{
    if (!_wkWebView) {
        _wkWebView = [[WKWebView alloc]initWithFrame:self.view.bounds configuration:self.configuration];
        //开启手势触摸
        _wkWebView.allowsBackForwardNavigationGestures = YES;
        [_wkWebView sizeToFit];
        [_wkWebView addObserver:self forKeyPath:NSStringFromSelector(@selector(estimatedProgress)) options:0 context:WkwebBrowserContext];
        _wkWebView.UIDelegate = self;
        _wkWebView.navigationDelegate = self;

    }
    return _wkWebView;
}
- (UIProgressView *)progressView{
    if (!_progressView) {
        _progressView = [[UIProgressView alloc]initWithProgressViewStyle:UIProgressViewStyleDefault];
        if (_isNavHidden == YES) {
            _progressView.frame = CGRectMake(0, 20, self.view.bounds.size.width, 3);
        }else{
            CGFloat navigationBarBottom = self.navigationController.navigationBar.bounds.size.height+self.navigationController.navigationBar.frame.origin.y;
            _progressView.frame = CGRectMake(0, navigationBarBottom, self.view.bounds.size.width, 3);
        }
        // 设置进度条的色彩
        [_progressView setTrackTintColor:[UIColor whiteColor]];
        _progressView.progressTintColor = [UIColor orangeColor];
    }
    return _progressView;
}

-(UIBarButtonItem*)backItem{
    return _backItem = _backItem?: [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemReply target:self action:@selector(customBackItemClicked)];
}

-(UIBarButtonItem*)closeButtonItem{
    return _closeButtonItem = _closeButtonItem?:[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(closeItemClicked)];
}

-(UIBarButtonItem*)rightButtonItem{
    return _rightButtonItem = _rightButtonItem?:[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(roadLoadClicked)];
}


-(NSMutableSet<NSString *> *)calledByJSMethodSet{
    return _calledByJSMethodSet = _calledByJSMethodSet?:[NSMutableSet setWithArray:@[@"Share",@"Camera",@"getAppEnv"]];
}

-(void)dealloc{
    [self.wkWebView removeObserver:self forKeyPath:NSStringFromSelector(@selector(estimatedProgress))];
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self removeOCMethods:self.calledByJSMethodSet];
    [self.wkWebView setNavigationDelegate:nil];
    [self.wkWebView setUIDelegate:nil];
    [NSURLProtocol unregisterClass:[UrlRedirectionProtocol class]];
}

-(void)viewWillAppear:(BOOL)animated{
    [NSURLProtocol registerClass:[UrlRedirectionProtocol class]];
    [self.wkWebView setNavigationDelegate:self];
    [self.wkWebView setUIDelegate:self];
    [self registOCMethods:self.calledByJSMethodSet];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = self.rightButtonItem;
    self.navigationItem.leftBarButtonItem = self.backItem;
    [self.view addSubview:self.wkWebView];
    [self.view addSubview:self.progressView];
    [self filtHTTP];
    [self loadHTML];
}

- (void)loadLocalHTML{
    //本地资源
    //  NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html"];
    //缓存资源
  NSString *htmlPath = [[UrlRedirectionProtocol getCachePath] stringByAppendingString:@"dist/index.html"];
    NSString *fileURL = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    NSURL *baseURL = [NSURL fileURLWithPath:htmlPath];
    [self.wkWebView loadHTMLString:fileURL baseURL:baseURL];
}

-(void)addJsCallNativeMethods:(NSSet *)methods{
    [self.calledByJSMethodSet setByAddingObjectsFromSet:methods];
}

-(void)addCalledByJSMethodSet:(NSSet *)objects{
    [self.calledByJSMethodSet setByAddingObjectsFromSet:objects];
    [self registOCMethods:objects];
}

-(void)customBackItemClicked{
    self.wkWebView.canGoBack?self.wkWebView.goBack:[self.navigationController popViewControllerAnimated:YES];
}

-(void)closeItemClicked{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)roadLoadClicked{
    [self.wkWebView reload];
}

-(void)updateNavigationItems{
    if (self.wkWebView.canGoBack) {
        [self.navigationItem setLeftBarButtonItems:@[self.backItem,self.closeButtonItem] animated:NO];
    }else{
        self.navigationController.interactivePopGestureRecognizer.enabled = YES;
        [self.navigationItem setLeftBarButtonItems:@[self.backItem]];
    }
}
- (void)clearBrowserCache {
    NSSet *websiteDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes modifiedSince:dateFrom completionHandler:^{
        }];
    });
}

- (void)loadHTML {
    //    [self clearBrowserCache];
    NSLog(@"regist");
    __weak __typeof(&*self)weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong __typeof(&*weakSelf)strongSelf = weakSelf;
        NSURL *nsurl=[NSURL URLWithString:@"http://127.0.0.1:8000/dist/index.html"];
        NSURLRequest *nsrequest=[NSURLRequest requestWithURL:nsurl];
        [strongSelf.wkWebView loadRequest: nsrequest];
    });
}

#pragma mark ================ WKNavigationDelegate ================
//这个是网页加载完成，导航的变化
-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation{
    /*
     主意：这个方法是当网页的内容全部显示（网页内的所有图片必须都正常显示）的时候调用（不是出现的时候就调用），，否则不显示，或则部分显示时这个方法就不调用。
     */
    // 获取加载网页的标题
    self.title = self.wkWebView.title;
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [self updateNavigationItems];
}

//开始加载
-(void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation{
    //开始加载的时候，让加载进度条显示
    self.progressView.hidden = NO;
}

//内容返回时调用
-(void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation{
}

//服务器请求跳转的时候调用
-(void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation{
}

//服务器开始请求的时候调用
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    [self updateNavigationItems];
    decisionHandler(WKNavigationActionPolicyAllow);
}

// 内容加载失败时候调用
-(void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error{
    NSLog(@"页面加载超时");
}

//跳转失败的时候调用
-(void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error{
}

//进度条
-(void)webViewWebContentProcessDidTerminate:(WKWebView *)webView{
}

#pragma mark - WKUIDelegate
-(void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提醒" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(YES);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(NO);
    }]];
    [self presentViewController:alert animated:YES completion:NULL];
}

// 交互。可输入的文本。
-(void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable))completionHandler{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"textinput" message:@"JS调用输入框" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.textColor = [UIColor redColor];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler([[alert.textFields lastObject] text]);
    }]];
    [self presentViewController:alert animated:YES completion:NULL];
}

//KVO监听进度条
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(estimatedProgress))] && object == self.wkWebView) {
        [self.progressView setAlpha:1.0f];
        BOOL animated = self.wkWebView.estimatedProgress > self.progressView.progress;
        [self.progressView setProgress:self.wkWebView.estimatedProgress animated:animated];
        // Once complete, fade out UIProgressView
        if(self.wkWebView.estimatedProgress >= 1.0f) {
            __weak __typeof(&*self)weakSelf =self;
            [UIView animateWithDuration:0.3f delay:0.3f options:UIViewAnimationOptionCurveEaseOut animations:^{
                __strong __typeof(&*weakSelf)strongSelf =weakSelf;
                [strongSelf.progressView setAlpha:0.0f];
            } completion:^(BOOL finished) {
                __strong __typeof(&*weakSelf)strongSelf =weakSelf;
                [strongSelf.progressView setProgress:0.0f animated:NO];
            }];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -- WKScriptMessageHandler
-(void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message{
    SEL selector =NSSelectorFromString([message.name stringByAppendingString:@":"]);
    IMP imp = [self methodForSelector:selector];
    void (*func)(id, SEL,id) = (void *)imp;
    if ([self respondsToSelector:selector]) {
        func(self, selector,message.body);
    }
}

@end

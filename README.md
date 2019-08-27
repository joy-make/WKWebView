# WKWebView
WKWebview实现http拦截、下载缓存本地秒开，js<->Native带参交互，
##主要实现两个功能
######1.拦截http和https的请求并替换成缓存资源(兼容IOS10)
######2.js<->Native的带参交互，参数可以直接是字典、数组、和字符串


##1.拦截原理：
######通过私有类WKBrowsingContextController 和让http和https执行私有API registerSchemeForCustomProtocol，
```
-(void)filtHTTP{
    Class cls = NSClassFromString(@"WKBrowsingContextController");
    SEL sel = NSSelectorFromString(@"registerSchemeForCustomProtocol:");
    if ([(id)cls respondsToSelector:sel]) {
        [(id)cls performSelector:sel withObject:@"http"];
        [(id)cls performSelector:sel withObject:@"https"];
    }
}
```
通过NSURLProtocol注册NSURLProtocol的派生类UrlRedirectionProtocol
```
  [NSURLProtocol registerClass:[UrlRedirectionProtocol class]];
//适当时机并卸载以防止泄漏和不需要拦截时依然被拦截
  [NSURLProtocol unregisterClass:[UrlRedirectionProtocol class]];
```
并在派生类实现url拦截并重定向本地url
```
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request{
//    NSLog(@"截获url : %@",request.URL.absoluteString);
    __block NSMutableURLRequest *mutableReqeust = [request mutableCopy];
    //截取重定向
    [[UrlFiltManager shareInstance].urlFiltSet enumerateObjectsUsingBlock:^(NSString *host, BOOL * _Nonnull stop) {
        if ([request.URL.absoluteString hasPrefix:host])
        {
            NSURL* proxyURL = [NSURL URLWithString:[UrlRedirectionProtocol generateProxyPath: request.URL.absoluteString host:host]];
            //        NSLog(@"替换为url : %@",proxyURL.absoluteString);
            if ([[NSFileManager defaultManager]fileExistsAtPath:proxyURL.absoluteString]) {
                mutableReqeust = [NSMutableURLRequest requestWithURL: proxyURL];
                *stop = YES;
            }
        }

    }];
    return mutableReqeust;
}
```
重写startLoading方法实现本地资源重载
```
- (void)startLoading {
    NSMutableURLRequest *mutableReqeust = [[self request] mutableCopy];
    // 标识该request已经处理过了，防止无限循环
    [NSURLProtocol setProperty:@YES forKey:FilteredKey inRequest:mutableReqeust];
    if ([self checkNeedLoadingLocalData]) {
        __weak __typeof(&*self)weakSelf = self;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
        __strong __typeof(&*weakSelf)strongSelf = weakSelf;
        NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:strongSelf.request.URL.absoluteString];
        NSData *data = [file readDataToEndOfFile];
        [file closeFile];
        //3.拼接响应Response
        NSInteger dataLength = data.length?:3;
        NSString *mimeType = [strongSelf getMIMETypeWithCAPIAtFilePath:strongSelf.request.URL.absoluteString];
        NSHTTPURLResponse *response = [strongSelf jointResponseWithData:data
                                                       dataLength:dataLength
                                                         mimeType:mimeType
                                                       requestUrl:strongSelf.request.URL
                                                       statusCode:dataLength?200:404
                                                      httpVersion:@"HTTP/1.1"];
        //4.响应
        [[strongSelf client] URLProtocol:strongSelf didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [[strongSelf client] URLProtocol:strongSelf didLoadData:data];
        [[strongSelf client] URLProtocolDidFinishLoading:strongSelf];
        });
    }
    else {
        self.connection = [NSURLConnection connectionWithRequest:mutableReqeust delegate:self];
    }
}
```

##2.js交互原理：
######通过向WKUserContentController的handler添加方法以供js调用
```
-(void)registOCMethods:(NSSet *)methods{
    for (NSString *method in methods) {
        [self.userContentController addScriptMessageHandler:self name:method];
    }
}
```
```
/*js调用oc方法通过回调执行，oc收到回调可以解析WKScriptMessage中的name(被js调用的oc方法名)和body（js传到oc消息提）并转换成oc方法
*/
#pragma mark -- WKScriptMessageHandler
-(void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message{
    SEL selector =NSSelectorFromString([message.name stringByAppendingString:@":"]);
    IMP imp = [self methodForSelector:selector];
    void (*func)(id, SEL,id) = (void *)imp;
    if ([self respondsToSelector:selector]) {
        func(self, selector,message.body);
    }
}
```
js通过window.webkit.messageHandlers.方法名.postMessage(消息体)调用oc并传参

```
//js中的方法，js调oc的getAppEnv方法
function getAppInfo()
{
    //获取app的运行环境
    alert("获取appinfo");
    window.webkit.messageHandlers.getAppEnv.postMessage("");
}

//oc中的方法 js调oc 的getAppEnv方法
- (void)getAppEnv:(NSString *)env{
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *shareResult = [NSString stringWithFormat:@"appEnvResult('%@')",version];
    //OC调用JS返回结果
    [self.wkWebView evaluateJavaScript:shareResult completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        NSLog(@"%@", error);
    }];
}

//js中的方法，js接收到oc调用appEnvResult方法和appEnv参数
function appEnvResult(appEnv)
{
    //获取到app的运行环境是 appEnv
    var content = "app回调数据" + appEnv;
    alert(content);
}
```

//oc调js通过wkwebview的api调用js
```
- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^ _Nullable)(_Nullable id, NSError * _Nullable error))completionHandler;

 [self.wkWebView evaluateJavaScript:@"js方法名('参数1','参数2','参数3',参数4)" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        NSLog(@"%@", error);
}];

```
```
-（void)ocCallJs{
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *shareResult = [NSString stringWithFormat:@"appEnvResult('%@')",version];
    //OC调用JS
    [self.wkWebView evaluateJavaScript:shareResult completionHandler:^(id _Nullable result, NSError * _Nullable error) {
        NSLog(@"%@", error);
    }];
}
```
//oc调js传对象，可以讲字典和数组转换成json并替换"""成"'"传给js，js可以接受不了到的就直接是js对象了

```
//js中的方法 调用app分享并带一个字典参数
function callShare() {
    var shareInfo ={"title": "标题", "content": "内容", "shareUrl": "http://www.xxx.com","shareIco":"http://upload/xxxx"};
    //    Joy.share(shareInfo)
   window.webkit.messageHandlers.Share.postMessage(shareInfo);
}

//oc中的方法“share”被js调用传回参数dic字典对象
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

//js接收oc方法并收到3个字符串参数和一个dic字典对象
function shareResult(channel_id,share_channel,share_url,dic) {
    //    var content = "app回调数据" + channel_id+","+share_channel+","+share_url;
    var content = dic['title'] + dic['content'] + dic['shareUrl'];
    alert(content);
    document.getElementById("shareResult").value = content;
}
```

我们可以把js调用oc和oc调用js的函数写成一个或多个category以实现不同模块的js<->native调用
比如我的wkwebview放到了一个WebVC的控制器里,然后把交互事件放到不同的category里，然后根据实际需要使用
```
@interface WebVC (JSNative)
@end

@implementation WebVC (JSNative)
- (void)Share:(NSDictionary *)dic{
}

- (void)ShareVideo:(NSDictionary *)dic{
}
@end
```

```
@interface WebVC (Media)
@end

@implementation WebVC (Media)
- (void)openAlbum:(NSDictionary *)dic{
}

- (void) openCamera:(NSDictionary *)dic{
}

- (void) openQRScan:(NSDictionary *)dic{
}
@end
```

#####测试，可以搭建一个简易服务器并把资源文件放进去以供下载解压使用，这里用python
```
cd /Users/joymake/Desktop/h5service 
//启动服务器，这里默认启动8000端口
python -m SimpleHTTPServer

//如果是模拟器地址用http://127.0.0.1:8000(demo里用的这个地址)就可以了，如果用的真机而资源包放在服务器上，那么地址需要改成服务器地址
ifconfig可用来查看当前服务器ip地址
```

![image.png](https://upload-images.jianshu.io/upload_images/1488115-6c07fcb7352b42c4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
![image.png](https://upload-images.jianshu.io/upload_images/1488115-e1a9933380136d76.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/300)

![image.png](https://upload-images.jianshu.io/upload_images/1488115-9b9856fd294c0096.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/300)

![image.png](https://upload-images.jianshu.io/upload_images/1488115-71c347c49f6ea8c0.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/300)

文章地址
https://www.jianshu.com/p/7eff3ba19840

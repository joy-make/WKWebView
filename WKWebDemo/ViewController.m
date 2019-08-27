//
//  ViewController.m
//  WKWebDemo
//
//  Created by Joymake on 2019/7/11.
//  Copyright © 2019 IB. All rights reserved.
//

#import "ViewController.h"
#import "WebVC.h"
#import "UrlRedirectionProtocol.h"
#import "SSZipArchive.h"
#import "AFNetworking.h"
#import "UrlFiltManager.h"

@interface ViewController (){
    NSURLSessionDownloadTask *_downloadTask;
}
@property (nonatomic,strong)WKWebView *web;
@property (nonatomic,strong)UIProgressView *progressView;
@property (nonatomic,strong)WebVC *webVC;

@end

@implementation ViewController
- (UIProgressView *)progressView{
    if (!_progressView) {
        _progressView = [[UIProgressView alloc]initWithProgressViewStyle:UIProgressViewStyleDefault];
        CGFloat navigationBarBottom = self.navigationController.navigationBar.bounds.size.height+self.navigationController.navigationBar.frame.origin.y;
        _progressView.frame = CGRectMake(0, navigationBarBottom, self.view.bounds.size.width, 3);
        [_progressView setTrackTintColor:[UIColor whiteColor]];
        _progressView.progressTintColor = [UIColor orangeColor];
    }
    return _progressView;
}

-(void)viewDidLoad{
    [super viewDidLoad];
    [self.view addSubview:self.progressView];
    UIButton *filtBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [filtBtn setTitle:@"缓存H5加载" forState:UIControlStateNormal];
    [filtBtn setFrame:CGRectMake(20, 100, 100, 40)];
    [filtBtn setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
    [self.view addSubview:filtBtn];
    [filtBtn addTarget:self action:@selector(btnAction) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *refreshBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [refreshBtn setTitle:@"远程加载" forState:UIControlStateNormal];
    [refreshBtn setFrame:CGRectMake(140, 100, 80, 40)];
    [refreshBtn setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
    [refreshBtn setTitleColor:[UIColor greenColor] forState:UIControlStateHighlighted];
    [self.view addSubview:refreshBtn];
    [refreshBtn addTarget:self action:@selector(refreshAction) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *downLoadBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [downLoadBtn setTitle:@"下载H5资源包" forState:UIControlStateNormal];
    [downLoadBtn setFrame:CGRectMake(220, 100, 120, 40)];
    [downLoadBtn setTitleColor:[UIColor orangeColor] forState:UIControlStateNormal];
    [self.view addSubview:downLoadBtn];
    [downLoadBtn addTarget:self action:@selector(downLoadAction) forControlEvents:UIControlEventTouchUpInside];
    
    //增加自己要拦截的域名
    [[UrlFiltManager shareInstance]configUrlFilt:[NSSet setWithArray:@[@"http://127.0.0.1:8000/",
                                                                       @"http://www.joy.com/"]]];

    
    self.web = [[WKWebView alloc]initWithFrame:CGRectMake(30, 150, CGRectGetWidth(self.view.bounds)-60, CGRectGetHeight(self.view.bounds)-300) configuration:[WKWebViewConfiguration new]];
    [self.view addSubview:self.web];
    NSURL *nsurl=[NSURL URLWithString:@"http://127.0.0.1:8000/dist/index.html"];
    NSURLRequest *nsrequest=[NSURLRequest requestWithURL:nsurl];
    [self.web loadRequest:nsrequest];
    self.webVC = [WebVC new];
}

- (void)btnAction{
    [self.navigationController pushViewController:self.webVC animated:YES];
}

- (void)refreshAction{
    [self.web reload];
}

static NSUInteger const TIMEOUT = 300;
- (NSURLSession *)sessionWithHeaders: (NSDictionary *)headers {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    configuration.timeoutIntervalForRequest = TIMEOUT;
    configuration.timeoutIntervalForResource = TIMEOUT;
    if (headers) {
        [configuration setHTTPAdditionalHeaders:headers];
    }
    return [NSURLSession sessionWithConfiguration:configuration delegate:nil delegateQueue:nil];
}

- (void)downLoadAction {
    //自己要缓存的地址
    NSString *cachePath = [UrlRedirectionProtocol getCachePath];
    BOOL isNeedUpdateZip = YES;
    if (isNeedUpdateZip) {
        //远程地址
        NSURL *URL = [NSURL URLWithString:@"http://127.0.0.1:8000/dist.zip"];
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
        NSURLRequest *request = [NSURLRequest requestWithURL:URL];
        _downloadTask = [manager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.progressView.progress = 1.0 * downloadProgress.completedUnitCount / downloadProgress.totalUnitCount;
            });
        } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
            //- block的返回值, 要求返回一个URL, 返回的这个URL就是文件的位置的路径
            NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
            NSString *path = [cachesPath stringByAppendingPathComponent:response.suggestedFilename];
            return [NSURL fileURLWithPath:path];
        } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
            BOOL unzipSuccess = [SSZipArchive unzipFileAtPath:filePath.path toDestination:cachePath];
            if (unzipSuccess) {
                if([[NSFileManager defaultManager] fileExistsAtPath:filePath.path]){
                    [[NSFileManager defaultManager] removeItemAtPath:filePath.path error:nil];
                }
//                [self writeVersion];
            }
        }];
        [_downloadTask resume];
    }else{
        self.progressView.progress = 1.;
    }
}
@end

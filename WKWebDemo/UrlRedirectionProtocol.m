//
//  BaseOnRedirectRequestURLProtocol.m
//  WKWebDemo
//
//  Created by Joymake on 2019/7/12.
//  Copyright © 2019 IB. All rights reserved.
//

#import "UrlRedirectionProtocol.h"
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "UrlFiltManager.h"

static NSString*const FilteredKey = @"FilteredKey";

@interface UrlRedirectionProtocol ()<NSURLSessionDelegate>
@property (nonnull,strong) NSURLSessionDataTask *task;
@property (nonatomic, strong) NSMutableData   *responseData;
@property (nonatomic, strong) NSURLConnection *connection;
@end

@implementation UrlRedirectionProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    return [NSURLProtocol propertyForKey:FilteredKey inRequest:request]== nil;
}

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

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b
{
    return [super requestIsCacheEquivalent:a toRequest:b];
}

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

- (BOOL)checkNeedLoadingLocalData{
    NSString *cachePath = [UrlRedirectionProtocol getCachePath];
    BOOL needLoadingLocal =[self.request.URL.absoluteString hasPrefix:cachePath];
    return needLoadingLocal;
}

- (void)stopLoading
{
    if (self.connection){
        [self.connection cancel];
        self.connection = nil;
    }
}

- (NSString *)getMIMETypeWithCAPIAtFilePath:(NSString *)path
{
    if (![[[NSFileManager alloc] init] fileExistsAtPath:path]) {
        return nil;
    }
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[path pathExtension], NULL);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    if (!MIMEType) {
        return @"application/octet-stream";
    }
    return (__bridge NSString *)(MIMEType)
    ;
}

#pragma mark - 拼接响应Response
- (NSHTTPURLResponse *)jointResponseWithData:(NSData *)data dataLength:(NSInteger)dataLength mimeType:(NSString *)mimeType requestUrl:(NSURL *)requestUrl statusCode:(NSInteger)statusCode httpVersion:(NSString *)httpVersion{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    mimeType?[dict setObject:mimeType forKey:@"Content-type"]:nil;
    [dict setObject:[NSString stringWithFormat:@"%ld",dataLength] forKey:@"Content-length"];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:requestUrl statusCode:statusCode HTTPVersion:httpVersion headerFields:dict];
    return response;
}

#pragma mark- NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
}

#pragma mark - NSURLConnectionDataDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.responseData = [[NSMutableData alloc] init];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
    [self.client URLProtocol:self didLoadData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
}

+ (NSString *)generateProxyPath:(NSString *) absoluteURL host:(NSString *)host{
    NSString *cachePath = [self getCachePath];
    return [absoluteURL stringByReplacingOccurrencesOfString:host withString:cachePath];
}

+(NSString *)getCachePath{
    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    cachePath = [cachePath stringByAppendingString:@"/h5Cache/"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return cachePath;
}

@end

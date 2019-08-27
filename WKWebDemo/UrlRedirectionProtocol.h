//
//  BaseOnRedirectRequestURLProtocol.h
//  WKWebDemo
//
//  Created by Joymake on 2019/7/12.
//  Copyright © 2019 IB. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UrlRedirectionProtocol : NSURLProtocol
+(NSString *)getCachePath;

@end

NS_ASSUME_NONNULL_END

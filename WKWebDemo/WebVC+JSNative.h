//
//  WebVC+JSNative.h
//  WKWebDemo
//
//  Created by Joymake on 2019/8/14.
//  Copyright © 2019 IB. All rights reserved.
//

#import "WebVC.h"

NS_ASSUME_NONNULL_BEGIN

@interface WebVC (JSNative)

- (void)registOCMethods:(NSSet *)methods;

- (void)removeOCMethods:(NSSet *)methods;

@end

@interface WebVC (FiltUrl)
- (void)filtHTTP;
@end

NS_ASSUME_NONNULL_END

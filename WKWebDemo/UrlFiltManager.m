//
//  UrlFiltManager.m
//  WKWebDemo
//
//  Created by Joymake on 2019/8/23.
//  Copyright © 2019 IB. All rights reserved.
//

#import "UrlFiltManager.h"

static UrlFiltManager *instance = nil;

@interface UrlFiltManager ()
@property (nonatomic,readwrite,strong)NSMutableSet *urlFiltSet;

@end

@implementation UrlFiltManager

+ (instancetype)shareInstance{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self.class new];
    });
    return instance;
}

-(void)configUrlFilt:(NSSet *)urlFitSet{
    [self.urlFiltSet setByAddingObjectsFromSet:urlFitSet];
}

-(NSMutableSet *)urlFiltSet{
    return _urlFiltSet = _urlFiltSet?:[NSMutableSet set];
}
@end

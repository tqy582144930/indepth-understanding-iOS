//
//  ChildOperation.m
//  NSOperation-test
//
//  Created by _祀梦 on 2019/8/13.
//  Copyright © 2019 涂强尧. All rights reserved.
//

#import "ChildOperation.h"

@implementation ChildOperation

//重写main函数
- (void)main {
    if (!self.isCancelled) {
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];
            NSLog(@"1---%@", [NSThread currentThread]);
        }
    }
}
@end

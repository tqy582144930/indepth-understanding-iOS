//
//  main.m
//  Block-test
//
//  Created by _祀梦 on 2019/9/9.
//  Copyright © 2019 涂强尧. All rights reserved.
//

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        void (^blk)(void) = ^{
            printf("Block\n");
        };
        blk();
    }
    return 0;
}

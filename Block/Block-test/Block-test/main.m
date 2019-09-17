//
//  main.m
//  Block-test
//
//  Created by _祀梦 on 2019/9/9.
//  Copyright © 2019 涂强尧. All rights reserved.
//

#import <Foundation/Foundation.h>
static int vision = 5;
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        static const int height = 170;
        static int weight = 60;
        void (^personInfoBlock)(void) = ^() {
            weight = 70;
            vision = 4;
            NSLog(@"vision is %d, height is %d, weight is %d", vision, height, weight);
        };
        weight = 80;
        vision = 3;
        personInfoBlock();
    }
    return 0;
}

//
//  main.m
//  Block-test
//
//  Created by _祀梦 on 2019/9/21.
//  Copyright © 2019 涂强尧. All rights reserved.
//

#import <Foundation/Foundation.h>
static int c = 30;

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
            static const int a = 10;
            static int b = 20;
            
            void (^Block)(void) = ^{
                b = 50;
                c = 60;
                printf("a = %d, b = %d, c = %d\n",a, b, c);
            };
        
            b = 30;
            c = 40;
            Block();                 // 输出结果：a = 20, b = 30, c = 30
    }
    return 0;
}

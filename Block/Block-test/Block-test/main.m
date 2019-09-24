//
//  main.m
//  Block-test
//
//  Created by _祀梦 on 2019/9/21.
//  Copyright © 2019 涂强尧. All rights reserved.
//

#import <Foundation/Foundation.h>
 static int a = 10;
int main(int argc, const char * argv[]) {
    @autoreleasepool {
       
      
            const int b = 20;
            
            void (^Block)(void) = ^{
                printf("a = %d, b = %d\n",a, b);
            };
            
            Block();                 // 输出结果：a = 10, b = 50, c = 60
        
    }
    return 0;
}

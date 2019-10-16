//
//  main.m
//  Block-test
//
//  Created by _祀梦 on 2019/9/21.
//  Copyright © 2019 涂强尧. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Person.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
//       int age = 20;
        __block Person *person = [[Person alloc] init];
        NSLog(@"person = %@", person);

       void(^block)(void) = ^ {
//           age = 30;
//           person = [[Person alloc] init];
//           NSLog(@"malloc address: %p %p", &age, person);
//           NSLog(@"malloc age is %d", age);
//           person.age = 30;
           NSLog(@"person is %@", person);
       };
       block();
//       NSLog(@"stack address: %p %p", &age, person);
//       NSLog(@"stack age is %d", age);
    }
    return 0;
}

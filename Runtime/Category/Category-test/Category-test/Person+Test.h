//
//  Person+Test.h
//  Category-test
//
//  Created by _祀梦 on 2019/9/30.
//  Copyright © 2019 涂强尧. All rights reserved.
//

#import "Person.h"



NS_ASSUME_NONNULL_BEGIN

@interface Person (Test) <NSCopying>
- (void)test;
+ (void)abc;
@property (nonatomic, assign) int age;
- (void)setAge:(int)age;
- (int)age;
@end

NS_ASSUME_NONNULL_END

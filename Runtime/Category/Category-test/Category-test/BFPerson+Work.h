//
//  BFPerson+Work.h
//  Category-test
//
//  Created by _祀梦 on 2019/10/2.
//  Copyright © 2019 涂强尧. All rights reserved.
//



#import "BFPerson.h"

NS_ASSUME_NONNULL_BEGIN

@interface BFPerson (Work)
@property (nonatomic, assign) double workAge;

- (void)work;
+ (void)workIn:(NSString *)city;
- (void)test;
@end

NS_ASSUME_NONNULL_END

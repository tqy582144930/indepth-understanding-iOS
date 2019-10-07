//
//  Person.h
//  Category-test
//
//  Created by _祀梦 on 2019/10/3.
//  Copyright © 2019 涂强尧. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Person : NSObject
- (void)printName;
@end

@interface Person (MyAdditon)
@property (nonatomic, copy)NSString *name;

- (void)printName;

@end
NS_ASSUME_NONNULL_END

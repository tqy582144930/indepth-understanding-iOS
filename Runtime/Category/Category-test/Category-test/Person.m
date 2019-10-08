//
//  Person.m
//  Category-test
//
//  Created by _祀梦 on 2019/10/3.
//  Copyright © 2019 涂强尧. All rights reserved.
//

#import "Person.h"
#import "objc/runtime.h"

@implementation Person

@end

@implementation Person (MyAdditon)

- (void)setName:(NSString *)name {
    objc_setAssociatedObject(self, @"name", name, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)name {
    return objc_getAssociatedObject(self, @"name");
}
@end


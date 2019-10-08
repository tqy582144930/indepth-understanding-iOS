//
//  ViewController.m
//  Category-test
//
//  Created by _祀梦 on 2019/9/30.
//  Copyright © 2019 涂强尧. All rights reserved.
//

#import "ViewController.h"
#import "Person.h"

@interface ViewController ()
@property (nonatomic, strong) Person *objc;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.objc = [[Person alloc] init];
    self.objc.name = @"tqy";
    NSLog(@"%@", self.objc.name);
}


@end

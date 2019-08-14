//
//  ViewController.m
//  pthread&NSThread-test
//
//  Created by _祀梦 on 2019/8/14.
//  Copyright © 2019 涂强尧. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //先创建线程，再启动线程
    NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(run) object:nil];
    [thread start];
    
    //创建线程自动启动
    [NSThread detachNewThreadSelector:@selector(run) toTarget:self withObject:nil];
    
    //隐式创建线程自动启动
    [self performSelector:@selector(run) withObject:nil];
}

-(void)run {
    NSLog(@"%@", [NSThread currentThread]);
}

@end

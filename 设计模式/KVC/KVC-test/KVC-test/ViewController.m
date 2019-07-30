//
//  ViewController.m
//  KVC-test
//
//  Created by _祀梦 on 2019/7/30.
//  Copyright © 2019 涂强尧. All rights reserved.
//

#import "ViewController.h"
#include "PersonModel.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:@"test1",@"key1",
                                     @"test2",@"key2",
                                     @"test3",@"key3",
                                     @"test4",@"key4", nil];
    NSLog(@"%@", [dictionary valueForKey:@"key1"]);
    NSDictionary *dictionary1 = [dictionary dictionaryWithValuesForKeys:@[@"key2", @"key1"]];
    NSLog(@"%@", dictionary1);
    
    //创建一个model模型，里面的字符串名称必须和key的名称对应，不然该方法会崩溃
    PersonModel *person = [[PersonModel alloc] init];
    //1.这是直接赋值，数据量小会很简单，但是数据量一多就很麻烦，就像我们进行网络请求时
    person.key1 = dictionary[@"key1"];
    person.key2 = dictionary[@"key2"];
    person.key3 = dictionary[@"key3"];
    
    //2.通过下面该方法可以批量赋值
    //2.1如果model里面的string不存在于dictionary中，输出结果为null；
    [person setValuesForKeysWithDictionary:dictionary];
    NSLog(@"\n%@\n%@\n%@\n%@\n", person.key1,person.key2,person.key3,person.other);
    
    //2.2如果dictionary中有的元素，moedl中没有运行会直接出错，那么我们应该怎么解决？
    //我们需要实现setValue:forUndefinedKey:这个方法能过滤掉不存在的键值
    //============请跳转至PersonModel文件中============
    person.key1 = dictionary[@"key1"];
    person.key2 = dictionary[@"key2"];
    person.key3 = dictionary[@"key3"];
    [person setValuesForKeysWithDictionary:dictionary];
    NSLog(@"\n%@\n%@\n%@\n", person.key1,person.key2,person.key3);
    
    //2.3如果dictionar中的key与model中的变量名字不同，怎么赋值？
    //还是从setValue:forUndefinedKey:这个方法入手
    //============请跳转至PersonModel文件中============
    person.key1 = dictionary[@"key1"];
    person.id = dictionary[@"key2"];
    person.key3 = dictionary[@"key3"];
    [person setValuesForKeysWithDictionary:dictionary];
    NSLog(@"\n%@\n%@\n%@\n", person.key1,person.id,person.key3);
  
}



@end

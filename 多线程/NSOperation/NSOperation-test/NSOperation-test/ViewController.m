//
//  ViewController.m
//  NSOperation-test
//
//  Created by _祀梦 on 2019/8/13.
//  Copyright © 2019 涂强尧. All rights reserved.
//

#import "ViewController.h"
#import "ChildOperation.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    //调用NSInvocationOperation
//    [self useInvocationOperation];
//    // 在其他线程使用子类 NSInvocationOperation
//    [NSThread detachNewThreadSelector:@selector(useInvocationOperation) toTarget:self withObject:nil];
    
//    //调用NSBlockOperation
//    [self useBlockOpretaion];
//    //调用NSBlockOperation+addExecutionBlock
//    [self useBlockOperationAddExecutionBlock];
    
//    //调用自定义Opetaion
//    [self useCustomOpetation];
    
//    //调用addOperation: 将操作加入到操作队列中
//    [self addOprationToQueue];
    
//    //调用addOperationWithBlock:将包含操作的blcok添加到队列中
//    [self addOperationWithBlockToQueue];
    
//    //设置MaxConcurrentOperationCount(最大并发操作数)
//    [self setMaxConcurrentOperationCount];
    
    //操作依赖
    [self addDependency];
    
}

#pragma 使用子类NSInvocationOperation
- (void)useInvocationOperation {
    //创建NSInvocationOperation对象
    NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(task1) object:nil];
    
    //调用start方法开始c执行操作
    [operation start];
}

- (void)task1 {
    for (int i = 0; i < 2; i++) {
        [NSThread sleepForTimeInterval:2];
        NSLog(@"1---%@", [NSThread currentThread]);//打印当前线程
    }
//打印结果
//    NSOperation-test[2316:472505] 1---<NSThread: 0x6000032b6940>{number = 1, name = main}
//    NSOperation-test[2316:472505] 1---<NSThread: 0x6000032b6940>{number = 1, name = main}
    //在没有使用 NSOperationQueue、在主线程中单独使用使用子类 NSInvocationOperation 执行一个操作的情况下，操作是在当前线程执行的，并没有开启新线程。
    
//打印结果
//    NSOperation-test[2316:472766] 1---<NSThread: 0x6000032d7580>{number = 3, name = (null)}
//    NSOperation-test[2316:472766] 1---<NSThread: 0x6000032d7580>{number = 3, name = (null)}
    //在其他线程中单独使用子类 NSInvocationOperation，操作是在当前调用的其他线程执行的，并没有开启新线程。
}

#pragma 使用子类NSBlockOperation
- (void)useBlockOpretaion {
    //1.创建 NSBlockOperation 对象
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    //2.调用 start 方法开始执行操作
    [operation start];
    
//打印结果
//    NSOperation-test[2366:483984] 1---<NSThread: 0x6000033e6940>{number = 1, name = main}
//    NSOperation-test[2366:483984] 1---<NSThread: 0x6000033e6940>{number = 1, name = main}
    
    //在没有使用 NSOperationQueue、在主线程中单独使用 NSBlockOperation 执行一个操作的情况下，操作是在当前线程执行的，并没有开启新线程。
}

#pragma 使用子类NSBlockOperation+调用方法AddExecutionBlock:
- (void)useBlockOperationAddExecutionBlock {
    // 1.创建 NSBlockOperation 对象
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    // 2.添加额外的操作
    [operation addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];
            NSLog(@"2---%@", [NSThread currentThread]);
        }
    }];
    
    [operation addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];
            NSLog(@"3---%@", [NSThread currentThread]);
        }
    }];
    
    [operation addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];
            NSLog(@"4---%@", [NSThread currentThread]);
        }
    }];
    
    [operation addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];
            NSLog(@"5---%@", [NSThread currentThread]);
        }
    }];
    
    [operation addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];
            NSLog(@"6---%@", [NSThread currentThread]);
        }
    }];
    
    [operation addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];
            NSLog(@"7---%@", [NSThread currentThread]);
        }
    }];
    
    [operation addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];
            NSLog(@"8---%@", [NSThread currentThread]);
        }
    }];
    
    //3.调用 start 方法开始执行操作
    [operation start];

/*打印结果
NSOperation-test[2503:513068] 5---<NSThread: 0x6000033507c0>{number = 1, name = main}
NSOperation-test[2503:513238] 6---<NSThread: 0x60000333f240>{number = 7, name = (null)}
NSOperation-test[2503:513217] 4---<NSThread: 0x60000332d040>{number = 6, name = (null)}
NSOperation-test[2503:513215] 1---<NSThread: 0x60000333f200>{number = 4, name = (null)}
NSOperation-test[2503:513216] 2---<NSThread: 0x60000332d000>{number = 3, name = (null)}
NSOperation-test[2503:513239] 7---<NSThread: 0x600003331180>{number = 8, name = (null)}
NSOperation-test[2503:513240] 8---<NSThread: 0x60000332d080>{number = 9, name = (null)}
NSOperation-test[2503:513218] 3---<NSThread: 0x6000033299c0>{number = 5, name = (null)}
NSOperation-test[2503:513068] 5---<NSThread: 0x6000033507c0>{number = 1, name = main}
NSOperation-test[2503:513217] 4---<NSThread: 0x60000332d040>{number = 6, name = (null)}
NSOperation-test[2503:513238] 6---<NSThread: 0x60000333f240>{number = 7, name = (null)}
NSOperation-test[2503:513216] 2---<NSThread: 0x60000332d000>{number = 3, name = (null)}
NSOperation-test[2503:513215] 1---<NSThread: 0x60000333f200>{number = 4, name = (null)}
NSOperation-test[2503:513218] 3---<NSThread: 0x6000033299c0>{number = 5, name = (null)}
NSOperation-test[2503:513240] 8---<NSThread: 0x60000332d080>{number = 9, name = (null)}
NSOperation-test[2503:513239] 7---<NSThread: 0x600003331180>{number = 8, name = (null)}
*/
    //使用子类 NSBlockOperation，并调用方法 AddExecutionBlock: 的情况下，blockOperationWithBlock:方法中的操作 和 addExecutionBlock: 中的操作是在不同的线程中异步执行的。而且，这次执行结果中 blockOperationWithBlock:方法中的操作也不是在当前线程（主线程）中执行的。从而印证了blockOperationWithBlock: 中的操作也可能会在其他线程（非当前线程）中执行。
}

#pragma 自定义即成自NSOpretaion的子类
- (void)useCustomOpetation {
    ChildOperation *opretion = [[ChildOperation alloc] init];
    
    [opretion start];
    
//打印结果
//NSOperation-test[2599:548248] 1---<NSThread: 0x60000309a900>{number = 1, name = main}
//NSOperation-test[2599:548248] 1---<NSThread: 0x60000309a900>{number = 1, name = main}
    
    //在没有使用 NSOperationQueue、在主线程单独使用自定义继承自 NSOperation 的子类的情况下，是在主线程执行操作，并没有开启新线程。
}

#pragma 使用 addOperation: 将操作加入到操作队列中
- (void)addOprationToQueue {
    // 1.创建队列
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    //2.创建操作
    // 使用 NSInvocationOperation 创建操作1
    NSInvocationOperation *operation1 = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(task1) object:nil];
    
    // 使用 NSInvocationOperation 创建操作2
    NSInvocationOperation *operation2 = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(task2) object:nil];
    
    // 使用 NSBlockOperation 创建操作3
    NSBlockOperation *operation3 = [NSBlockOperation blockOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2];
            NSLog(@"3---%@", [NSThread currentThread]);
        }
    }];
    [operation3 addExecutionBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"4---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    [queue addOperation:operation1];
    [queue addOperation:operation2];
    [queue addOperation:operation3];
    
/*打印结果
NSOperation-test[2762:588970] 1---<NSThread: 0x6000027d5180>{number = 3, name = (null)}
NSOperation-test[2762:588969] 2---<NSThread: 0x6000027fd600>{number = 4, name = (null)}
NSOperation-test[2762:588975] 4---<NSThread: 0x6000027d8140>{number = 6, name = (null)}
NSOperation-test[2762:588968] 3---<NSThread: 0x6000027c2e00>{number = 5, name = (null)}
NSOperation-test[2762:588970] 1---<NSThread: 0x6000027d5180>{number = 3, name = (null)}
NSOperation-test[2762:588968] 3---<NSThread: 0x6000027c2e00>{number = 5, name = (null)}
NSOperation-test[2762:588969] 2---<NSThread: 0x6000027fd600>{number = 4, name = (null)}
NSOperation-test[2762:588975] 4---<NSThread: 0x6000027d8140>{number = 6, name = (null)}
*/
    //使用 NSOperation 子类创建操作，并使用 addOperation: 将操作加入到操作队列后能够开启新线程，进行并发执行。
}

- (void)task2 {
    for (int i = 0; i < 2; i++) {
        [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
        NSLog(@"2---%@", [NSThread currentThread]); // 打印当前线程
    }
}

#pragma 使用 addOperationWithBlock: 将操作加入到操作队列中
- (void)addOperationWithBlockToQueue {
    // 1.创建队列
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    // 2.使用 addOperationWithBlock: 添加操作到队列中
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"2---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"3---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
//打印结果
//NSOperation-test[2834:603909] 2---<NSThread: 0x600002fbc800>{number = 5, name = (null)}
//NSOperation-test[2834:603907] 3---<NSThread: 0x600002fb0380>{number = 3, name = (null)}
//NSOperation-test[2834:603906] 1---<NSThread: 0x600002faf600>{number = 4, name = (null)}
//NSOperation-test[2834:603906] 1---<NSThread: 0x600002faf600>{number = 4, name = (null)}
//NSOperation-test[2834:603909] 2---<NSThread: 0x600002fbc800>{number = 5, name = (null)}
//NSOperation-test[2834:603907] 3---<NSThread: 0x600002fb0380>{number = 3, name = (null)}
    
    //使用 addOperationWithBlock: 将操作加入到操作队列后能够开启新线程，进行并发执行。
}

#pragma 设置MaxConcurrentOperationCount(最大并发操作数)
- (void)setMaxConcurrentOperationCount {
    // 1.创建队列
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    // 2.设置最大并发操作数
    queue.maxConcurrentOperationCount = 1;//串行队列
//    queue.maxConcurrentOperationCount = 2;//并发队列
//    queue.maxConcurrentOperationCount = 8;//并发队列

    // 3.添加操作
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"2---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"3---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    [queue addOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"4---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
//打印结果
//NSOperation-test[1452:89261] 1---<NSThread: 0x600002ca0140>{number = 3, name = (null)}
//NSOperation-test[1452:89261] 1---<NSThread: 0x600002ca0140>{number = 3, name = (null)}
//NSOperation-test[1452:89264] 2---<NSThread: 0x600002ca8240>{number = 4, name = (null)}
//NSOperation-test[1452:89264] 2---<NSThread: 0x600002ca8240>{number = 4, name = (null)}
//NSOperation-test[1452:89261] 3---<NSThread: 0x600002ca0140>{number = 3, name = (null)}
//NSOperation-test[1452:89261] 3---<NSThread: 0x600002ca0140>{number = 3, name = (null)}
//NSOperation-test[1452:89261] 4---<NSThread: 0x600002ca0140>{number = 3, name = (null)}
//NSOperation-test[1452:89261] 4---<NSThread: 0x600002ca0140>{number = 3, name = (null)}

//当最大并发操作数为1时，操作是按顺序串行执行的，并且一个操作完成之后，下一个操作才开始执行。当最大操作并发数为2时，操作是并发执行的，可以同时执行两个操作。而开启线程数量是由系统决定的，不需要我们来管理。
}

#pragma 操作依赖
- (void)addDependency {
    // 1.创建队列
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    // 2.创建操作
    NSBlockOperation *operation1 = [NSBlockOperation blockOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    NSBlockOperation *operation2 = [NSBlockOperation blockOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"2---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    
    // 3.添加依赖
    [operation2 addDependency:operation1];//让op2依赖于op1，先执行op1，再执行op2
    
    [queue addOperation:operation1];
    [queue addOperation:operation2];
    
//打印结果
//NSOperation-test[1547:108900] 1---<NSThread: 0x60000177c140>{number = 3, name = (null)}
//NSOperation-test[1547:108900] 1---<NSThread: 0x60000177c140>{number = 3, name = (null)}
//NSOperation-test[1547:108898] 2---<NSThread: 0x60000173c1c0>{number = 4, name = (null)}
//NSOperation-test[1547:108898] 2---<NSThread: 0x60000173c1c0>{number = 4, name = (null)}

    //通过添加操作依赖，无论运行几次，其结果都是 op1 先执行，op2 后执行。
}

@end

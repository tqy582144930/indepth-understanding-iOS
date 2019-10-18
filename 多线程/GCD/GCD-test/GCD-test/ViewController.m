//
//  ViewController.m
//  GCD-test
//
//  Created by _祀梦 on 2019/8/12.
//  Copyright © 2019 涂强尧. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
//    //同步执行+并发队列
//    [self syncConcurrent];
//    //异步执行+并发队列
//    [self asyncConcurrent];
//    //同步执行+串行队列
//    [self syncSerial];
//    //异步执行+串行队列
//    [self asyncSerial];
//    //同步执行+主队列
//    [self syncMain];
//    //在其他线程中调用同步执行+主队列
//    //使用 NSThread 的 detachNewThreadSelector 方法会创建线程，并自动启动线程执行 selector 任务
//    [NSThread detachNewThreadSelector:@selector(syncMain) toTarget:self withObject:nil];
//    //异步执行+主队列
//    [self asyncMain];
//    //栅栏方法
//    [self barrier];
//    //延时方法
//    [self barrier];
//    //快速迭代
//    [self apply];
//    //监听任务
//    [self groupNotify];
//    //阻塞线程
//    [self groupWait];
//    //添加删除任务
//    [self groupEnterAndLeave];

    
    
}

#pragma 同步执行+并发队列
//在当前的线程中执行任务，不会开辟新的线程，执行完一个任务，再执行下一个任务
- (void)syncConcurrent {
    NSLog(@"currentThread-----%@", [NSThread currentThread]);//打印当前线程
    NSLog(@"syncConcurrent---begin");
    
    //创建一个并发队列
    dispatch_queue_t queue = dispatch_queue_create("net.GCD-test", DISPATCH_QUEUE_CONCURRENT);
    //同步执行
    dispatch_sync(queue, ^{
        [NSThread sleepForTimeInterval:2];// 拟耗时操作
        NSLog(@"1---%@", [NSThread currentThread]);//打印当前线程
    });
    
    dispatch_sync(queue, ^{
        [NSThread sleepForTimeInterval:2];//模拟耗时操作
        NSLog(@"2---%@", [NSThread currentThread]);//打印当前线程
    });
    
    dispatch_sync(queue, ^{
        [NSThread sleepForTimeInterval:2];//模拟耗时操作
        NSLog(@"3---%@", [NSThread currentThread]);//打印当前线程
    });
    
    NSLog(@"syncConcurrent---end");
//打印结果
//GCD-test[1610:357278] currentThread-----<NSThread: 0x6000026f53c0>{number = 1, name = main}
//GCD-test[1610:357278] syncConcurrent---begin
//GCD-test[1610:357278] 1---<NSThread: 0x6000026f53c0>{number = 1, name = main}
//GCD-test[1610:357278] 2---<NSThread: 0x6000026f53c0>{number = 1, name = main}
//GCD-test[1610:357278] 3---<NSThread: 0x6000026f53c0>{number = 1, name = main}GCD-test[1610:357278] syncConcurrent---end
    
    //所有任务都是在当前线程（主线程）中执行的，并没有开启新线程
    //同步执行需要等待队列的任务执行结束
}

#pragma 异步执行+并发队列
-(void)asyncConcurrent {
    NSLog(@"currentThread-----%@", [NSThread currentThread]);//打印当前线程
    NSLog(@"asyncConcurrent---begin");
    
    //创建并行队列
    dispatch_queue_t queue = dispatch_queue_create("net.GCD-test", DISPATCH_QUEUE_CONCURRENT);
    //异步执行
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];//模拟耗时操作
        NSLog(@"1---%@", [NSThread currentThread]);//打印当前线程
    });
    
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];//模拟耗时操作
        NSLog(@"2---%@", [NSThread currentThread]);//打印当前线程
    });
    
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];//模拟耗时操作
        NSLog(@"3---%@", [NSThread currentThread]);//打印当前线程
    });
    
    NSLog(@"asyncConcurrent---end");
    
//打印结果
//GCD-test[1543:336717] currentThread-----<NSThread: 0x60000388a8c0>{number = 1, name = main}
//GCD-test[1543:336717] asyncConcurrent---begin
//GCD-test[1543:336717] asyncConcurrent---end
//GCD-test[1543:336786] 1---<NSThread: 0x6000038c41c0>{number = 3, name = (null)}
//GCD-test[1543:336788] 3---<NSThread: 0x6000038d8180>{number = 4, name = (null)}
//GCD-test[1543:336785] 2---<NSThread: 0x6000038c0780>{number = 5, name = (null)}
    
    /*  1.除了当前线程（主线程），还开辟了3个线程，并且任务是交替进行执行的。
        异步执行具有开辟新线程的能力。并且并发队列可开启多个线程同时执行任务
        2.所有任务是在打印完syncConcurrent---end之后才执行的，说明当前线程没有等待
        而是直接开辟新线程，在新线程中执行任务
        3.异步执行不做等待，可以直接执行任务
   */
}

#pragma 同步执行+串行队列
- (void)syncSerial {
    NSLog(@"currentThread-----%@", [NSThread currentThread]);//打印当前线程
    NSLog(@"syncSerial---begin");
    
    //创建串行队列
    dispatch_queue_t queue = dispatch_queue_create("net.GCD-test", DISPATCH_QUEUE_SERIAL);
    
    dispatch_sync(queue, ^{
        [NSThread sleepForTimeInterval:2];//模拟耗时操作
        NSLog(@"1---%@", [NSThread currentThread]);//打印当前线程
    });
    
    dispatch_sync(queue, ^{
        [NSThread sleepForTimeInterval:2];//模拟耗时操作
        NSLog(@"2---%@", [NSThread currentThread]);//打印当前线程
    });
    
    dispatch_sync(queue, ^{
        [NSThread sleepForTimeInterval:2];//模拟耗时操作
        NSLog(@"3---%@", [NSThread currentThread]);//打印当前线程
    });
    
    NSLog(@"syncSerial---end");
    
//打印结果
//GCD-test[1669:369534] currentThread-----<NSThread: 0x600002600000>{number = 1, name = main}
//GCD-test[1669:369534] syncSerial---begin
//GCD-test[1669:369534] 1---<NSThread: 0x600002600000>{number = 1, name = main}
//GCD-test[1669:369534] 2---<NSThread: 0x600002600000>{number = 1, name = main}
//GCD-test[1669:369534] 3---<NSThread: 0x600002600000>{number = 1, name = main}
//GCD-test[1669:369534] syncSerial---end
    
    //不会开启新的线程，同步执行不具有开辟新线程的能力
    //同步执行需要等待队列的任务执行结束

}

#pragma 异步执行+串行队列
- (void)asyncSerial {
    NSLog(@"currentThread-----%@", [NSThread currentThread]);//打印当前线程
    NSLog(@"asyncSerial---begin");
    
    //创建串行队列
    dispatch_queue_t queue = dispatch_queue_create("net.GCD-test", DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];//模拟耗时操作
        NSLog(@"1---%@", [NSThread currentThread]);//打印当前线程
    });
    
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];//模拟耗时操作
        NSLog(@"2---%@", [NSThread currentThread]);//打印当前线程
    });
    
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];//模拟耗时操作
        NSLog(@"3---%@", [NSThread currentThread]);//打印当前线程
    });
    
    NSLog(@"asyncSerial---end");
    
//打印结果
//GCD-test[1848:404092] currentThread-----<NSThread: 0x600000bf5380>{number = 1, name = main}
//GCD-test[1848:404092] asyncSerial---begin
//GCD-test[1848:404092] asyncSerial---end
//GCD-test[1848:404214] 1---<NSThread: 0x600000b893c0>{number = 3, name = (null)}
//GCD-test[1848:404214] 2---<NSThread: 0x600000b893c0>{number = 3, name = (null)}
//GCD-test[1848:404214] 3---<NSThread: 0x600000b893c0>{number = 3, name = (null)}
    
    //会开辟新的线程，异步执行具有开辟新线程的能力
    //所有任务都是在end之后才开始执行，异步执行不会做任何等待，可以继续执行任务
    //任务是按顺序执行的，串行队列每次只会执行一个任务
}

//主队列一种特殊的串行队列
#pragma 同步执行+主队列
- (void)syncMain {
    NSLog(@"currentThread-----%@", [NSThread currentThread]);//打印当前线程
    NSLog(@"syncMain---begin");
    
    //创建主队列
    dispatch_queue_t queue = dispatch_get_main_queue();
    
    //同步执行
    dispatch_sync(queue, ^{
        [NSThread sleepForTimeInterval:2];//模拟耗时操作
        NSLog(@"1---%@", [NSThread currentThread]);//打印当前线程
    });
    
    dispatch_sync(queue, ^{
        [NSThread sleepForTimeInterval:2];//模拟耗时操作
        NSLog(@"2---%@", [NSThread currentThread]);//打印当前线程
    });
    
    dispatch_sync(queue, ^{
        [NSThread sleepForTimeInterval:2];//模拟耗时操作
        NSLog(@"3---%@", [NSThread currentThread]);//打印当前线程
    });
    
    NSLog(@"syncMain---end");
    //打印结果
//    GCD-test[1973:421252] currentThread-----<NSThread: 0x600001eb6d00>{number = 1, name = main}
//    GCD-test[1973:421252] syncMain---begin
//发生死锁
    
    /*  这是因为我们在主线程中执行syncMain方法，相当于把syncMain 任务放到了主线程的队列中。而同步执行会等待当前队列中的任务执行完毕，才会接着执行。
        那么当我们把任务1追加到主队列中，任务1就在等待主线程处理完syncMain任务。
        而syncMain 任务需要等待 任务 1 执行完毕，才能接着执行。
    */
    
//在其他线程调用同步执行+主队列
//打印结果
//GCD-test[2031:440299] currentThread-----<NSThread: 0x600000ea5a00>{number = 3, name = (null)}
//GCD-test[2031:440299] syncMain---begin
//GCD-test[2031:440114] 1---<NSThread: 0x600000ec6900>{number = 1, name = main}
//GCD-test[2031:440114] 2---<NSThread: 0x600000ec6900>{number = 1, name = main}
//GCD-test[2031:440114] 3---<NSThread: 0x600000ec6900>{number = 1, name = main}
//GCD-test[2031:440299] syncMain---end
    
    //所有任务都是在主线程执行，没有开辟新线程，所有放在主队列中的任务，都会在主线程中执行
    //同步执行需要等待任务的执行结束
    //串行队列，每一次只有一个任务被执行，任务按顺序执行
}

#pragma 异步执行+主队列
- (void)asyncMain {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"asyncMain---begin");
    
    //创建主队列
    dispatch_queue_t queue = dispatch_get_main_queue();
    //异步执行
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);      // 打印当前线程
    });
    
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);      // 打印当前线程
    });
    
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);      // 打印当前线程
    });
    
    NSLog(@"asyncMain---end");
    
//打印结果
//GCD-test[2111:457173] currentThread---<NSThread: 0x600002b12900>{number = 1, name = main}
//GCD-test[2111:457173] asyncMain---begin
//GCD-test[2111:457173] asyncMain---end
//GCD-test[2111:457173] 1---<NSThread: 0x600002b12900>{number = 1, name = main}
//GCD-test[2111:457173] 2---<NSThread: 0x600002b12900>{number = 1, name = main}
//GCD-test[2111:457173] 3---<NSThread: 0x600002b12900>{number = 1, name = main}
    
    /*  所有任务都在主线程中执行，并没有开启新线程，异步执行具备开辟新线程的能力，但因为是
        主队列，所有所有任务都在主线程中执行
        异步执行不会做任何等待，可以继续执行任务
        主队列，每次只执行一个的任务，任务是一个按顺序执行的。
    */
}

#pragma 栅栏方法
- (void)barrier {
    dispatch_queue_t queue = dispatch_queue_create("net.GCD-test", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);      // 打印当前线程
    });
    
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);      // 打印当前线程
    });
    
    dispatch_barrier_async(queue, ^{
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"barrier---%@",[NSThread currentThread]);// 打印当前线程
    });
    
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);      // 打印当前线程
    });
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"4---%@",[NSThread currentThread]);      // 打印当前线程
    });
    
   /* 1. dispatch_barrier_async方法会等待前边追加到并发队列中的任务全部执行完毕之后，
        再将指定的任务追加到该异步队列中。
      2.然后在dispatch_barrier_async方法追加的任务执行完毕之后，
        异步队列才恢复为一般动作，接着追加任务到该异步队列并开始执行
    */
}

#pragma 延时方法
- (void)after {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"after---begin");
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 2.0 秒后异步追加任务代码到主队列，并开始执行
        NSLog(@"after---%@",[NSThread currentThread]);  // 打印当前线程
    });
    
    //dispatch_after 方法并不是在指定时间之后才开始执行处理，而是在指定时间之后将任务追加到主队列中。
}

#pragma 快速迭代
- (void)apply {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    NSLog(@"apply---begin");
    dispatch_apply(6, queue, ^(size_t index) {
        NSLog(@"%zd---%@", index, [NSThread currentThread]);
    });
    NSLog(@"apply---end");
    
    //apply---end 一定在最后执行。这是因为 dispatch_apply 方法会等待全部任务执行完毕。
}

#pragma 监听任务状态
- (void)groupNotify {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"group---begin");
    
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);      // 打印当前线程
    });
    
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);      // 打印当前线程
    });
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);      // 打印当前线程
    });
     NSLog(@"group---end");
    
    //当所有任务都执行完成之后，才执行 dispatch_group_notify 相关 block 中的任务。
}

#pragma 暂定当前线程
- (void)groupWait {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"group---begin");
    
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);      // 打印当前线程
    });
    
    dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);      // 打印当前线程
    });
    
    // 等待上面的任务全部完成后，会往下继续执行（会阻塞当前线程）
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    NSLog(@"group---end");
    
    //当所有任务执行完成之后，才执行 dispatch_group_wait 之后的操作。但是，使用dispatch_group_wait 会阻塞当前线程。
}

#pragma 追加删除任务
- (void)groupEnterAndLeave {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"group---begin");
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_group_enter(group);
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);      // 打印当前线程
        
        dispatch_group_leave(group);
    });
    
    dispatch_group_enter(group);
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"2---%@",[NSThread currentThread]);      // 打印当前线程
        
        dispatch_group_leave(group);
    });
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        // 等前面的异步操作都执行完毕后，回到主线程.
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"3---%@",[NSThread currentThread]);      // 打印当前线程
        
        NSLog(@"group---end");
    });
}
@end

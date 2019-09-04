[TOC]

# RunLoop源码---图解RunLoop

## 前言

我们在`iOS APP`中的`main`函数如下：

```objective-c
int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
```

我们在`macOS`下的`main`函数如下：

```objective-c
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"Hello, World!");
    }
    return 0;
}
```

- 对比这两个程序：
  1. `iOS App`启动后会一直运行，等待用户触摸、输入等，在接收到点击后，就会立即响应，完成本次响应后，会等待下次用户操作。只要用户不主动退出或者程序闪退，会一直在循环等待。
  2. 而`macOS`下的命令行程序，启动后，执行程序，执行完毕后会立即退出。

- 两者最大的区别是：**是否能持续响应用户输入**

## 什么是RunLoop？

- 之所以，`iOS App` 能持续响应，保证程序运行状态，在于其有一个事件循环——`Event Loop`
- 事件循环机制，即线程能随时响应并处理事件的机制。这种机制要求线程不能退出，而且需要高效的完成事件调度与处理。
- 事件循环在很多编程语言，或者说不同的操作系统层面都支持。比如 `JS `中的事件循环、`Windows`下的消息循环，在 `iOS/macOS` 下，该机制就称为 `RunLoop`。

> 如果大家对上面的专业术语不太了解，下面我举一个生活中的🌰
>
> 进程是一家工厂，线程是一个流水线，`RunLoop`就是流水线上的主管；当工厂接到商家的订单分配给这个流水线时，`RunLoop`就启动这个流水线，让流水线动起来，生产产品；当产品生产完毕时，`RunLoop`就会暂时停下流水线，节约资源。
>
> `RunLoop`管理流水线，流水线才不会因为无所事事被工厂销毁；而不需要流水线时，就会辞退`RunLoop`这个主管，即退出线程，把所有资源释放。

- 事件循环在本质上是如下一个编程实现：

```objective-c
function loop() {
    initialize();
    do {
        var message = get_next_message();
        process_message(message);
    } while (message != quit);
}
```

- **`RunLoop `实际上就是一个对象**，这个对象管理了其需要处理的事件和消息，并提供了一个入口函数来执行上面 `Event Loop` 的逻辑。线程执行了这个函数后，就会一直处于这个函数内部 “接受消息->等待->处理” 的循环中，直到这个循环结束（比如传入 `quit` 的消息），函数返回。
- 下面我们用一张图来看看这个过程

![RunLoop机制](https://tva1.sinaimg.cn/large/006y8mN6ly1g6nozkfvpdj311u0u0mxh.jpg)

## RunLoop的作用

> 在这里我会先简单介绍一下RunLoop的作用，有一个总体的印象，然后我会在后面仔细给大家介绍它的每个作用，和部分作用的一些应用场景。

1. **保持程序持续运行**，程序一启动就会开一个主线程，主线程一开起来就会跑一个主线程对应的`RunLoop`,`RunLoop`保证主线程不会被销毁，也就保证了程序的持续运行
2. **处理App中的各种事件：**
   1. 定时器（`Timer`）、方法调用（`PerformSelector`）
   2. `GCD Async Main Queue`
   3. 事件响应、手势识别、界面刷新
   4. 网络请求
   5. 自动释放池 `AutoreleasePool`
3.  **节省CPU资源，提高程序性能**，程序运行起来时，当什么操作都没有做的时候，`RunLoop`就告诉`CUP`，现在没有事情做，我要去休息，这时`CUP`就会将其资源释放出来去做其他的事情，当有事情做的时候`RunLoop`就会立马起来去做事情

## RunLoop在何处开启？

- 我们还记得前言中那个`main`函数么？不记得也不要紧，我把它再次贴出来

```objective-c
int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
```

- 我们知道主线程一开起来，就会跑一个和主线程对应的`RunLoop`，**那么我们猜测`RunLoop`一定是在程序的入口`main`函数中开启**。
- 我们进入`UIApplicationMain`

```objective-c
UIKIT_EXTERN int UIApplicationMain(int argc, char * _Nullable argv[_Nonnull], NSString * _Nullable principalClassName, NSString * _Nullable delegateClassName);
```

- 我们发现它返回的是一个int数，那么我们对main函数做一些修改

```objective-c
int main(int argc, char * argv[]) {
    @autoreleasepool {
        NSLog(@"开始");
        int result = UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
        NSLog(@"结束");
        return result;
    }
}
```

- 运行程序，我们发现只会打印开始，并不会打印结束，这**说明在`UIApplicationMain`函数中，开启了一个和主线程相关的`RunLoop`，导致`UIApplicationMain`不会返回，一直在运行中，也就保证了程序的持续运行**。
- 下面我把上面几个点用一张图总结一下

![RunLoop作用](https://tva1.sinaimg.cn/large/006y8mN6ly1g6npph9t50j315w0hkn2a.jpg)

## RunLoop对象

### RunLoop对象的获取

- 我在前面提到过RunLoop其实也是一个对象，下面我们来介绍一下它

> Fundation框架 （基于CFRunLoopRef的封装）
> NSRunLoop对象

- `NSRunLoop `是基于` CFRunLoopRef` 的封装，提供了面向对象的 `API`，但是这些` API` 不是线程安全的。 

```objective-c
[NSRunLoop currentRunLoop]; // 获得当前线程的RunLoop对象
[NSRunLoop mainRunLoop];   // 获得主线程的RunLoop对象
```

> CoreFoundation
> CFRunLoopRef对象

- `CFRunLoopRef` 是在` CoreFoundation` 框架内的，它提供了纯 `C` 函数的` API`，所有这些 `API` 都是线程安全的。

```objective-c
CFRunLoopGetCurrent(); // 获得当前线程的RunLoop对象
CFRunLoopGetMain();   // 获得主线程的RunLoop对象
```

- 我们通过一张图对上面知识的进行总结一下

![RunLoop两个库的比较](https://tva1.sinaimg.cn/large/006y8mN6ly1g6nruzk6k6j316q0iojvf.jpg)

- 我们来看看上面两个函数的底层实现

```objective-c
CFRunLoopRef CFRunLoopGetCurrent(void) {
    CHECK_FOR_FORK();
    CFRunLoopRef rl = (CFRunLoopRef)_CFGetTSD(__CFTSDKeyRunLoop);
    if (rl) return rl;
    return _CFRunLoopGet0(pthread_self());
}

CFRunLoopRef CFRunLoopGetMain(void) {
    CHECK_FOR_FORK();
    static CFRunLoopRef __main = NULL; // no retain needed
    if (!__main) 
      __main = _CFRunLoopGet0(pthread_main_thread_np()); // no CAS needed
    return __main;
}
```

- 我们发现不论是`CFRunLoopGetCurrent()`还是`CFRunLoopGetMain()`的底层实现都会调用一个`_CFRunLoopGet0`函数，那么这个函数到底是怎么实现的呢？我在这里先留一个悬念，**我会在RunLoop和线程中仔细讲解。**

![获取RunLoop对象](https://tva1.sinaimg.cn/large/006y8mN6ly1g6nrcw75o8j316m0imdld.jpg)

### CFRunLoopRef对象源码剖析

- 由于`NSRunLoop`对象是基于`CFRunLoopRef`的，并且`CFRunLoopRef`是基于`c`语言的，线程安全，所以我们来分析一下`CFRunLoopRef`的源码

```objective-c
struct __CFRunLoop {
    CFRuntimeBase _base;
    pthread_mutex_t _lock;
    __CFPort _wakeUpPort;	//通过该函数CFRunLoopWakeUp内核向该端口发送消息可以唤醒runloop
    Boolean _unused;
    volatile _per_run_data *_perRunData;            
    pthread_t _pthread;//RunLoop对应的线程
    uint32_t _winthread;
    CFMutableSetRef _commonModes;//存储的是字符串，记录所有标记为common的mode
    CFMutableSetRef _commonModeItems;//存储所有commonMode的item(source、timer、observer)
    CFRunLoopModeRef _currentMode;//当前运行的mode
    CFMutableSetRef _modes;//存储的是CFRunLoopModeRef
    struct _block_item *_blocks_head;//do blocks的时候用到
    struct _block_item *_blocks_tail;
    CFAbsoluteTime _runTime;
    CFAbsoluteTime _sleepTime;
    CFTypeRef _counterpart;
};
```

-  除了记录一些属性外，我们主要来看这两个成员变量

```objective-c
pthread_t _pthread;//RunLoop对应的线程
CFRunLoopModeRef _currentMode;//当前运行的mode
CFMutableSetRef _modes;//存储的是CFRunLoopModeRef
```

1. 它为什么需要记录线程呢？加着上面的悬念，种种迹象都表明`RunLoop`和线程中有着千丝万缕的联系。我会在**`RunLoop`和线程**这一节中仔细讲解。

2. `_currentMode`和`_modes`又是什么东西呢？`CFRunLoopModeRef `其实是指向`__CFRunLoopMode`结构体的指针，所以`RunLoop`和`Mode`又有什么不可告人的秘密呢？我会在**`RunLoop的Mode`**这一节中仔细讲解

## RunLoop和线程

- 在上面我们留下了问题，现在我们会在这一节中解释`_CFRunLoopGet0`这个函数是怎么实现的，和`RunLoop和线程`到底有什么关系。
- 首先我们看看`_CFRunLoopGet0`源码

```objective-c
// 全局的Dictionary，key是pthread_t， value是CFRunLoopRef
static CFMutableDictionaryRef __CFRunLoops = NULL;
// 访问__CFRunLoops的锁
static CFLock_t loopsLock = CFLockInit;

// 获取pthread 对应的 RunLoop。
CF_EXPORT CFRunLoopRef _CFRunLoopGet0(pthread_t t) {
    if (pthread_equal(t, kNilPthreadT)) {
      	// pthread为空时，获取主线程
        t = pthread_main_thread_np();
    }
  
    __CFLock(&loopsLock);
    if (!__CFRunLoops) {
        __CFUnlock(&loopsLock);
      	// 第一次进入时，创建一个临时字典dict
        CFMutableDictionaryRef dict = CFDictionaryCreateMutable(kCFAllocatorSystemDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
      	// 根据传入的主线程获取主线程对应的RunLoop
        CFRunLoopRef mainLoop = __CFRunLoopCreate(pthread_main_thread_np());
        // 保存主线程 将主线程-key和RunLoop-Value保存到字典中
      	CFDictionarySetValue(dict, pthreadPointer(pthread_main_thread_np()), mainLoop);
      	//此处NULL和__CFRunLoops指针都指向NULL，匹配，所以将dict写到__CFRunLoops
        if (!OSAtomicCompareAndSwapPtrBarrier(NULL, dict, (void * volatile *)&__CFRunLoops)) {
          	//释放dict
            CFRelease(dict);
        }
      	//释放mainrunloop
        CFRelease(mainLoop);
        __CFLock(&loopsLock);
    }
  	//以上说明，第一次进来的时候，不管是getMainRunloop还是get子线程的runloop，主线程的runloop总是会被创建
  
  	// 从全局字典里获取对应的RunLoop
    CFRunLoopRef loop = (CFRunLoopRef)CFDictionaryGetValue(__CFRunLoops, pthreadPointer(t));
    __CFUnlock(&loopsLock);
    if (!loop) {
      	// 如果取不到，就创建一个新的RunLoop
        CFRunLoopRef newLoop = __CFRunLoopCreate(t);
        __CFLock(&loopsLock);
        loop = (CFRunLoopRef)CFDictionaryGetValue(__CFRunLoops, pthreadPointer(t));
     	 // 创建好之后，以线程为key runloop为value，一对一存储在字典中，下次获取的时候，则直接返回字典内的runloop
        if (!loop) {
          	//把newLoop存入字典__CFRunLoops，key是线程t
            CFDictionarySetValue(__CFRunLoops, pthreadPointer(t), newLoop);
            loop = newLoop;
        }
        __CFUnlock(&loopsLock);
        CFRelease(newLoop);
    }
  
  	//如果传入线程就是当前线程
    if (pthread_equal(t, pthread_self())) {
        _CFSetTSD(__CFTSDKeyRunLoop, (void *)loop, NULL);
        if (0 == _CFGetTSD(__CFTSDKeyRunLoopCntr)) {
          	//注册一个回调，当线程销毁时，销毁对应的RunLoop
            _CFSetTSD(__CFTSDKeyRunLoopCntr, (void *)(PTHREAD_DESTRUCTOR_ITERATIONS-1), (void (*)(void *))__CFFinalizeRunLoop);
        }
    }
    return loop;
}
```



## RunLoop中的Mode

## RunLoop的应用

### 常驻线程

### NSTimer

### AutoreleasePool

### 事件响应

### 手势识别

### 界面更新


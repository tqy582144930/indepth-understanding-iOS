[TOC]

# RunLoop源码剖析---图解RunLoop

> 源码面前，了无秘密

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

> 在上面我们留下了两个问题，现在我们会在这一节中解释`_CFRunLoopGet0`这个函数是怎么实现的，和`RunLoop和线程`到底有什么关系。

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

- 通过以上代码我们可以得出一下结论
  1. RunLoop是基于线程来管理的，它们一一对应，共同存储在一个全局区的runLoopDict中，线程是key，RunLoop是value。
  2. **RunLoop的创建**：主线程所对应RunLoop在程序一启动创建主线程的时候系统就会自动为我们创建好，而子线程所对应的RunLoop并不是在子线程创建出来的时候就创建好的，而是在我们获取该子线程所对应的RunLoop时才创建出来的，换句话说，如果你不获取一个子线程的RunLoop，那么它的RunLoop就永远不会被创建。
  3. **RunLoop的获取**：我们可以通过一个指定的线程从runLoopDict中获取它所对应的RunLoop。
  4. **RunLoop的销毁**：系统在创建RunLoop的时候，会注册一个回调，确保线程在销毁的同时，也销毁掉其对应的RunLoop。
- 下面我用一张图来总结一下上面的源码

![_CFRunLoopGet0总结](https://tva1.sinaimg.cn/large/006y8mN6ly1g6ougsg565j310w0h4wgy.jpg)

## RunLoop的相关类

> 在上面一节我们介绍了RunLoop和线程的关系，在__CFRunLoop这个结构体中发现还有一个CFRunLoopModeRef类，这又是什么，在 `CoreFoundation` 里面还有没有关于 `RunLoop`的类呢？答案是肯定的，这也就是我们这一节所要介绍的重点

### RunLoop的相关类之间关系

- 首先我们要知道RunLoop相关的类有5个
  1. `CFRunLoopRef`
  2. `CFRunLoopModeRef`
  3. `CFRunLoopSourceRef`
  4. `CFRunLoopTimerRef`
  5. `CFRunLoopObserverRef`
- 那么每个类都是什么呢？
  1. 第一个类我在前面已经剖析过了，它就是`RunLoop`对象所属于的类
  2. `CFRunLoopModeRef` 是 `RunLoop` 当前的一个运行模式，什么是运行模式呢？我会在**`RunLoop和Mode`这一节仔细讲解**
  3. `CFRunLoopSourceRef`和`CFRunLoopTimerRef`是RunLoop处理的消息类型
  4. `CFRunLoopObserverRef`监听RunLoop运行状态的一个类

- 现在我们用一张图来看看各个类之间的关系

![RunLoop各个类之间的关系](https://tva1.sinaimg.cn/large/006y8mN6ly1g6owsuovutj319o0pgtfs.jpg)

1. 一个`RunLoop`包含若干个`Mode`，每个`Mode`又包含若干个` Source/Timer/Observer`。
2. 每次调用 `RunLoop`的主函数时，只能指定其中一个 `Mode`，这个`Mode`被称作`CurrentMode`。
3. 如果需要切换 `Mode`，只能退出`Loop`，再重新指定一个`Mode`进入。这样做主要是为了分隔开不同组的 `Source/Timer/Observer`，让其互不影响。
4. 如果一个 `mode`中一个`Source/Timer/Observer` 都没有，则`RunLoop`会直接退出，不进入循环。

### 各个类的作用

- 我们已经知道了每个类是什么，现在我们需要了解一下每个类具体是干什么的
  1. `CFRunLoopRef`是一个`CFRunLoop`结构体的指针，所以说它的职责就是`CFRunLoop`的职责，**运行循环，处理事件，保持运行**
  2. `CFRunLoopModeRef`**运行模式，模式下对应多个处理源,具体有哪些模式我会在RunLoop和Mode这一节仔细讲解**
  3. `CFRunLoopSourceRef`**是事件产生的地方**。`Source`有两个版本：`Source0` 和 `Source1`。
     1. `Source0`**触摸事件处理**
     2. `Source1`**基于Port的线程见通信**
  4. `CFRunLoopTimerRef`**NSTimer的运用**
  5. `CFRunLoopObserverRef`**用于监听RunLoop的状态，UI刷新，自动释放池**

- 下面我们用一张图来总结它的职责

![各个类的职责](https://tva1.sinaimg.cn/large/006y8mN6ly1g6owqpa9w9j31860oojvq.jpg)

## RunLoop中的Mode

> **千呼万唤始出来，犹抱琵琶半遮面。**在前面我们不止一次提到了这一节，可见这一节是多么的重要，那么现在我们就来给大家仔细讲解一下这一节到底有什么秘密，看完这节后希望前面的问题都能解决，并把相互之间的关系给链接起来，那么我们现在开始吧

- 首先我们要回顾一下在**RunLoop的相关类之间关系**这一节中所讲述的知识点和关系图，如果忘了请再次回到此处仔细阅读一遍，下面的讲解都给予你有了上面的基础。
- 那张图的重点就是**一个`RunLoop`包含若干个`Mode`，每个`Mode`又包含若干个 `Source/Timer/Observer`。**这句话真的是点晴之笔，一句话就把5个相关类的关系说的一清二楚。

### CFRunLoopModeRef

#### __CFRunLoopMode源码剖析

> **CFRunLoopModeRef代表RunLoop的运行模式**

```objective-c
typedef struct __CFRunLoopMode *CFRunLoopModeRef;
struct __CFRunLoopMode {
    CFRuntimeBase _base;
    pthread_mutex_t _lock;	
    CFStringRef _name;//mode名称，运行模式是通过名称来识别的
    Boolean _stopped;//mode是否被终止
    char _padding[3];
  //整个结构体最核心的部分
---------------------------------------------------------------------------------
    CFMutableSetRef _sources0;//sources0
    CFMutableSetRef _sources1;//sources1
    CFMutableArrayRef _observers;//观察者
    CFMutableArrayRef _timers;//定时器
---------------------------------------------------------------------------------
    CFMutableDictionaryRef _portToV1SourceMap; //字典  key是mach_port_t，value是CFRunLoopSourceRef
    __CFPortSet _portSet;//保存所有需要监听的port，比如_wakeUpPort，_timerPort都保存在这个数组中
    CFIndex _observerMask;
#if USE_DISPATCH_SOURCE_FOR_TIMERS
    dispatch_source_t _timerSource;
    dispatch_queue_t _queue;
    Boolean _timerFired; 
    Boolean _dispatchTimerArmed;
#endif
#if USE_MK_TIMER_TOO
    mach_port_t _timerPort;
    Boolean _mkTimerArmed;
#endif
#if DEPLOYMENT_TARGET_WINDOWS
    DWORD _msgQMask;
    void (*_msgPump)(void);
#endif
    uint64_t _timerSoftDeadline; /* TSR */
    uint64_t _timerHardDeadline; /* TSR */
};

```

- 一个`CFRunLoopModeRef`对象有一个`name`，若干`source0`，`source1`，`timer`，`observer`和`port`，可以看出事件都是由`mode`在管理，而`RunLoop`管理着`Mode`。
- 下面我们用一张图来总结一下

![CFRunLoopModeRef](https://tva1.sinaimg.cn/large/006y8mN6ly1g6oxo4ar1aj318u0l4dlc.jpg)

#### __CFRunLoopMode的五种运行模式

- 系统默认注册的五个Mode

```objective-c
1. kCFRunLoopDefaultMode：App的默认Mode，通常主线程是在这个Mode下运行
2. UITrackingRunLoopMode：界面跟踪Mode，用于ScrollView追踪触摸滑动，保证界面滑动时不受其他 Mode 影响
3. UIInitializationRunLoopMode: 在刚启动 App 时第进入的第一个 Mode，启动完成后就不再使用，会切换到kCFRunLoopDefaultMode
4. GSEventReceiveRunLoopMode: 接受系统事件的内部 Mode，通常用不到
5. kCFRunLoopCommonModes: 这是一个占位用的Mode，作为标记kCFRunLoopDefaultMode和UITrackingRunLoopMode用，并不是一种真正的Mode 
```

##### CommonModes

- 其中，需要着重说明的是，在 RunLoop 对象中，有一个叫 `CommonModes` 的概念。

- 先看 `RunLoop` 对象的组成：

```objective-c
//简化版本
struct __CFRunLoop {
    pthread_t _pthread;
    CFMutableSetRef _commonModes;//存储的是字符串，记录所有标记为common的mode
    CFMutableSetRef _commonModeItems;//存储所有commonMode的item(source、timer、observer)
    CFRunLoopModeRef _currentMode;//当前运行的mode
    CFMutableSetRef _modes;//存储的是CFRunLoopModeRef对象，不同mode类型，它的mode名字不同
};
```

- 一个`Mode`可以将自己标记为`Common`属性，通过将其 `ModeName` 添加到 `RunLoop` 的 `commonModes` 中。那么添加进去之后的作用是什么？

- 每当 `RunLoop` 的内容发生变化时，`RunLoop` 都会自动将 **_commonModeItems** 里的 `Source/Observer/Timer` 同步到具有 `Common`标记的所有 `Mode` 里。其底层实现如下：

```objective-c
void CFRunLoopAddCommonMode(CFRunLoopRef rl, CFStringRef modeName) {
    if (!CFSetContainsValue(rl->_commonModes, modeName)) {
        //获取所有的_commonModeItems
        CFSetRef set = rl->_commonModeItems ? CFSetCreateCopy(kCFAllocatorSystemDefault, rl->_commonModeItems) : NULL;
        //获取所有的_commonModes
        CFSetAddValue(rl->_commonModes, modeName);
        if (NULL != set) {
            CFTypeRef context[2] = {rl, modeName};
            // 将所有的_commonModeItems逐一添加到_commonModes里的每一个Mode
            CFSetApplyFunction(set, (__CFRunLoopAddItemsToCommonMode), (void *)context);
            CFRelease(set);
        }
    }
}
```

- Mode API

- `CFRunLoop` 对外暴露的管理`Mode`接口只有下面 2 个:

```objective-c
CFRunLoopAddCommonMode(CFRunLoopRef runloop, CFStringRef modeName);
CFRunLoopRunInMode(CFStringRef modeName, ...);
```

##### 什么是Mode Item？

> 从这个名字大概就能知道这是什么了？
>
> Mode包含的元素
>
> 那么Mode到底包含哪些类型的元素呢？

- `RunLoop` 需要处理的消息，包括 `time` 以及 `source` 消息，它们都属于 `Mode item`。

- `RunLoop` 也可以被监听，被监听的对象是`observer`对象，也属于`Mode item`。

- 所有的 `mode item` 都可以被添加到 `Mode` 中，`Mode` 中包含可以包含多个 `mode item`，一个 `item` 可以被同时加入多个 `mode`。但一个 `item` 被重复加入同一个 `mode` 时是不会有效果的。如果一个 `mode` 中一个 `item` 都没有，则 `RunLoop` 会直接退出，不进入循环。

------

- `Mode`暴露的管理`mode item` 的接口有下面几个：

```objective-c
CFRunLoopAddSource(CFRunLoopRef rl, CFRunLoopSourceRef source, CFStringRef modeName);
CFRunLoopAddObserver(CFRunLoopRef rl, CFRunLoopObserverRef observer, CFStringRef modeName);
CFRunLoopAddTimer(CFRunLoopRef rl, CFRunLoopTimerRef timer, CFStringRef mode);
CFRunLoopRemoveSource(CFRunLoopRef rl, CFRunLoopSourceRef source, CFStringRef modeName);
CFRunLoopRemoveObserver(CFRunLoopRef rl, CFRunLoopObserverRef observer, CFStringRef modeName);
CFRunLoopRemoveTimer(CFRunLoopRef rl, CFRunLoopTimerRef timer, CFStringRef mode);
```

- 你只能通过 `mode name` 来操作内部的 `mode`，当你传入一个新的 `mode name` 但 `RunLoop` 内部没有对应 `mode` 时，`RunLoop` 会自动帮你创建对应的 `CFRunLoopModeRef`。对于一个 `RunLoop` 来说，其内部的 `mode` 只能增加不能删除。

- 苹果公开提供的 `Mode` 有两个：`kCFRunLoopDefaultMode` (`NSDefaultRunLoopMode`) 和 `UITrackingRunLoopMode`，你可以用这两个` Mode Name` 来操作其对应的 `Mode`。

- 同时苹果还提供了一个操作 `Common` 标记的字符串：`kCFRunLoopCommonModes` (`NSRunLoopCommonModes`)，你可以用这个字符串来操作 `Common Items`，或标记一个` Mode` 为 `Common`。使用时注意区分这个字符串和其他 `mode name`。

- 如下：

```objective-c
[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
```

##### Mode之间的切换

- 我们平时在开发中一定遇到过，当我们使用`NSTimer`每一段时间执行一些事情时滑动`UIScrollView`，`NSTimer`就会暂停，当我们停止滑动以后，`NSTimer`又会重新恢复的情况，我们通过一段代码来看一下

  > 注意⚠️：**代码中的注释也很重要，展示了我们探索的过程**

```objective-c
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    // [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(show) userInfo:nil repeats:YES];
    NSTimer *timer = [NSTimer timerWithTimeInterval:2.0 target:self selector:@selector(show) userInfo:nil repeats:YES];
    // 加入到RunLoop中才可以运行
    // 1. 把定时器添加到RunLoop中，并且选择默认运行模式NSDefaultRunLoopMode = kCFRunLoopDefaultMode
    // [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    // 当textFiled滑动的时候，timer失效，停止滑动时，timer恢复
    // 原因：当textFiled滑动的时候，RunLoop的Mode会自动切换成UITrackingRunLoopMode模式，因此timer失效，当停止滑动，RunLoop又会切换回NSDefaultRunLoopMode模式，因此timer又会重新启动了
    
    // 2. 当我们将timer添加到UITrackingRunLoopMode模式中，此时只有我们在滑动textField时timer才会运行
    // [[NSRunLoop mainRunLoop] addTimer:timer forMode:UITrackingRunLoopMode];
    
    // 3. 那个如何让timer在两个模式下都可以运行呢？
    // 3.1 在两个模式下都添加timer 是可以的，但是timer添加了两次，并不是同一个timer
    // 3.2 使用站位的运行模式 NSRunLoopCommonModes标记，凡是被打上NSRunLoopCommonModes标记的都可以运行，下面两种模式被打上标签
    //0 : <CFString 0x10b7fe210 [0x10a8c7a40]>{contents = "UITrackingRunLoopMode"}
    //2 : <CFString 0x10a8e85e0 [0x10a8c7a40]>{contents = "kCFRunLoopDefaultMode"}
    // 因此也就是说如果我们使用NSRunLoopCommonModes，timer可以在UITrackingRunLoopMode，kCFRunLoopDefaultMode两种模式下运行
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    NSLog(@"%@",[NSRunLoop mainRunLoop]);
}
-(void)show
{
    NSLog(@"-------");
}
```

- 由上述代码可以看出，`NSTimer`不管用是因为Mode的切换，因为如果我们在主线程使用定时器，此时`RunLoop`的`Mode`为`kCFRunLoopDefaultMode`，即定时器属于`kCFRunLoopDefaultMode`，那么此时我们滑动`ScrollView`时，`RunLoop`的`Mode`会切换到`UITrackingRunLoopMode`，因此在主线程的定时器就不在管用了，调用的方法也就不再执行了，当我们停止滑动时，`RunLoop`的Mode切换回`kCFRunLoopDefaultMode`，所以`NSTimer`就又管用了。

### CFRunLoopSourceRef

>  是事件产生的地方

- 首先我们来看看`CFRunLoopSourceRef`的源码

```objective-c
typedef struct __CFRunLoopSource * CFRunLoopSourceRef;
struct __CFRunLoopSource {
    CFRuntimeBase _base;
    uint32_t _bits;
    pthread_mutex_t _lock;
    CFIndex _order;//执行顺序
    CFMutableBagRef _runLoops;//包含多个RunLoop
  	//版本
    union {
        CFRunLoopSourceContext version0;	/* immutable, except invalidation */
        CFRunLoopSourceContext1 version1;	/* immutable, except invalidation */
    } _context;
};
```

- 从上面我们可看见有两个版本：
  1. `Source0` 只包含了一个回调（函数指针），它并不能主动触发事件。使用时，你需要先调用 `CFRunLoopSourceSignal (source)`，将这个 `Source` 标记为待处理，然后手动调用 `CFRunLoopWakeUp (runloop)` 来唤醒 `RunLoop`，让其处理这个事件。
  2. `Source1`包含了一个 `mach_port` 和一个回调（函数指针），被用于通过内核和其他线程相互发送消息。这种` Source` 能主动唤醒 `RunLoop` 的线程，其原理在下面会讲到。

- 下面我们用一张图来总结一下以上知识点

![CFRunLoopSourceRef总结](https://tva1.sinaimg.cn/large/006y8mN6ly1g6q0r9twldj31580gygpg.jpg)

### CFRunLoopTimerRef 

> 是基于时间的触发器

```objective-c
typedef struct __CFRunLoopTimer * CFRunLoopTimerRef;
struct __CFRunLoopTimer {
    CFRuntimeBase _base;
    uint16_t _bits;
    pthread_mutex_t _lock;
    CFRunLoopRef _runLoop;
    CFMutableSetRef _rlModes;//包含timer的mode集合
    CFAbsoluteTime _nextFireDate;
    CFTimeInterval _interval;		/* immutable */
    CFTimeInterval _tolerance;          /* mutable */
    uint64_t _fireTSR;			/* TSR units */
    CFIndex _order;			/* immutable */
    CFRunLoopTimerCallBack _callout;//timer的回调
    CFRunLoopTimerContext _context;//上下文对象
};
```

- `CFRunLoopTimerRef` 是基于时间的触发器，它和 `NSTimer` 是 `toll-free bridged` 的，可以混用。其包含一个时间长度和一个回调（函数指针）。当其加入到 `RunLoop` 时，`RunLoop` 会注册对应的时间点，当时间点到时，`RunLoop` 会被唤醒以执行那个回调。
- 下面我们用一张图来总结上面知识点

![CFRunLoopTimerRef总结](https://tva1.sinaimg.cn/large/006y8mN6ly1g6q0xafarmj31520fawhl.jpg)

### CFRunLoopObserverRef

> `CFRunLoopObserverRef` 是观察者，每个 Observer 都包含了一个回调（函数指针），当 `RunLoop` 的状态发生变化时，观察者就能通过回调接受到这个变化。

```objective-c
typedef struct __CFRunLoopObserver * CFRunLoopObserverRef;
struct __CFRunLoopObserver {
    CFRuntimeBase _base;
    pthread_mutex_t _lock;
    CFRunLoopRef _runLoop;//监听的RunLoop
    CFIndex _rlCount;//添加该Observer的RunLoop对象个数
    CFOptionFlags _activities;		/* immutable */
    CFIndex _order;//同时间最多只能监听一个
    CFRunLoopObserverCallBack _callout;//监听的回调
    CFRunLoopObserverContext _context;//上下文用于内存管理
};

//观测的时间点有一下几个
typedef CF_OPTIONS(CFOptionFlags, CFRunLoopActivity) {
    kCFRunLoopEntry = (1UL << 0),   //   即将进入RunLoop
    kCFRunLoopBeforeTimers = (1UL << 1), // 即将处理Timer
    kCFRunLoopBeforeSources = (1UL << 2), // 即将处理Source
    kCFRunLoopBeforeWaiting = (1UL << 5), //即将进入休眠
    kCFRunLoopAfterWaiting = (1UL << 6),// 刚从休眠中唤醒
    kCFRunLoopExit = (1UL << 7),// 即将退出RunLoop
    kCFRunLoopAllActivities = 0x0FFFFFFFU
};
```

- 下面我用一个例子来展示一下，监听示例

```objective-c
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
     //创建监听者
     /*
     第一个参数 CFAllocatorRef allocator：分配存储空间 CFAllocatorGetDefault()默认分配
     第二个参数 CFOptionFlags activities：要监听的状态 kCFRunLoopAllActivities 监听所有状态
     第三个参数 Boolean repeats：YES:持续监听 NO:不持续
     第四个参数 CFIndex order：优先级，一般填0即可
     第五个参数 ：回调 两个参数observer:监听者 activity:监听的事件
     */
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(CFAllocatorGetDefault(), kCFRunLoopAllActivities, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        switch (activity) {
            case kCFRunLoopEntry:
                NSLog(@"RunLoop进入");
                break;
            case kCFRunLoopBeforeTimers:
                NSLog(@"RunLoop要处理Timers了");
                break;
            case kCFRunLoopBeforeSources:
                NSLog(@"RunLoop要处理Sources了");
                break;
            case kCFRunLoopBeforeWaiting:
                NSLog(@"RunLoop要休息了");
                break;
            case kCFRunLoopAfterWaiting:
                NSLog(@"RunLoop醒来了");
                break;
            case kCFRunLoopExit:
                NSLog(@"RunLoop退出了");
                break;
                
            default:
                break;
        }
    });
    
    // 给RunLoop添加监听者
    /*
     第一个参数 CFRunLoopRef rl：要监听哪个RunLoop,这里监听的是主线程的RunLoop
     第二个参数 CFRunLoopObserverRef observer 监听者
     第三个参数 CFStringRef mode 要监听RunLoop在哪种运行模式下的状态
     */
    CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, kCFRunLoopDefaultMode);
     /*
     CF的内存管理（Core Foundation）
     凡是带有Create、Copy、Retain等字眼的函数，创建出来的对象，都需要在最后做一次release
     GCD本来在iOS6.0之前也是需要我们释放的，6.0之后GCD已经纳入到了ARC中，所以我们不需要管了
     */
    CFRelease(observer);
}
2019-09-06 RunLoop醒来了
2019-09-06 RunLoop要处理Timers了
2019-09-06 RunLoop要处理Sources了
2019-09-06 RunLoop要处理Timers了
2019-09-06 RunLoop要处理Sources了
2019-09-06 RunLoop要休息了
2019-09-06 RunLoop醒来了
```

- 下面我们用一张图来总结我们上面的知识

![CFRunLoopObserverRef总结](https://tva1.sinaimg.cn/large/006y8mN6ly1g6q0yzd7tbj31ck0feqan.jpg)

## RunLoop的内部逻辑

### 运行逻辑

![运行逻辑](https://tva1.sinaimg.cn/large/006y8mN6ly1g6q8h6h4vuj31b40kwah8.jpg)

- 可以看到，在 `RunLoop` 中，接收输入事件来自两种不同的来源：输入源（**input source**）和定时源（**timer source**）。

#### 1.来源按同步异步分类

##### 1.1 Input sources

**输入源**传递异步事件，通常消息来自于其他线程或程序，按照是否来源于内核也分为下面几种：

- Port-Based Sources，基于 Port 的 事件，系统底层的，一般由**内核自动发出信号**。例如 `CFSocketRef` ，在应用层基本用不到。
- Custom Input Sources，非基于 Port 事件，用户手动创建的 Source，则必须**从其他线程手动发送信号**。
- Cocoa Perform Selector Sources， Cocoa 提供的 `performSelector` 系列方法，也是一种事件源。和基于端口的源一样，执行 `selector` 请求会在目标线程上序列化，减缓许多在线程上允许多个方法容易引起的同步问题。不像基于端口的源，一个 selector 执行完后会自动从 `Run Loop` 里面移除。

##### 1.2 Timer sources

- **定时源**则传递同步事件，发生在特定时间或者重复的时间间隔。

- 定时器可以产生基于时间的通知，但它并不是**实时机制**。和输入源一样，定时器也和你的 `Run Loop` 的特定模式相关。如果定时器所在的模式当前未被 `Run Loop` 监视，那么定时器将不会开始直到 `Run Loop` 运行在相应的模式下。

- 其主要包含了两部分：
  - NSTimer
  - performSelector:withObject:afterDelay:

#### 2.来源按对象分类

##### 2.1 Source1

- 对应于 Port-Based Sources，即基于 Port 的，通过内核和其他线程通信。

- 常用于接收、分发系统事件，大部分屏幕交互事件都是由 `Source1` 接收，包装成 `Event`，然后分发下去，最后由 `Source0` 去处理。

- 所以，其包括：
  - 基于 Port 的线程间通信；
  - 系统事件捕捉；

##### 2.2 Source0

- 是非 Port 事件。在应用中，触摸事件的最终处理，以及 `perforSelector:onThread` 都是包装成该类型对象，最后由开发者指定回调函数，手动处理该事件。

- 需要注意的是 `perforSelector:onThread` 是否有 `delay`，即是否延迟函数或者定时函数等类型。

- `perforSelector:onThread` 不是 `delay` 函数时， 是 `Source0` 事件。
- `performSelector:withObject:afterDelay` 有 `delay` 时，则属于 `Timers` 事件。

所以，其包括：

- 触摸事件处理
- performSelector:onThread

##### 2.3 Timers

- 同上 

### 源码详解

#### 入口函数

```objective-c
// 共外部调用的公开的CFRunLoopRun方法，其内部会调用CFRunLoopRunSpecific
void CFRunLoopRun(void) {	/* DOES CALLOUT */
    int32_t result;
    do {
      	// 调用RunLoop执行函数
        result = CFRunLoopRunSpecific(CFRunLoopGetCurrent(), kCFRunLoopDefaultMode, 1.0e10, false);
        CHECK_FOR_FORK();
    } while (kCFRunLoopRunStopped != result && kCFRunLoopRunFinished != result);
}

```

#### RunLoop执行函数

```objective-c
// 经过精简的 CFRunLoopRunSpecific 函数代码，其内部会调用__CFRunLoopRun函数
/*
 * 指定mode运行runloop
 * @param rl 当前运行的runloop
 * @param modeName 需要运行的mode的name
 * @param seconds  runloop的超时时间
 * @param returnAfterSourceHandled 是否处理完事件就返回
 */
SInt32 CFRunLoopRunSpecific(CFRunLoopRef rl, CFStringRef modeName, CFTimeInterval seconds, Boolean returnAfterSourceHandled) {
    CHECK_FOR_FORK();
  	// RunLoop正在释放，完成返回
    if (__CFRunLoopIsDeallocating(rl)) return kCFRunLoopRunFinished;
    __CFRunLoopLock(rl);
 		// 根据modeName 取出当前的运行Mode
    CFRunLoopModeRef currentMode = __CFRunLoopFindMode(rl, modeName, false
    // 如果没找到 || mode中没有注册任何事件，则就此停止，不进入循环                                           
    if (NULL == currentMode || __CFRunLoopModeIsEmpty(rl, currentMode, rl->_currentMode)) {
        Boolean did = false;
        if (currentMode) 
          	__CFRunLoopModeUnlock(currentMode);
            __CFRunLoopUnlock(rl);
            return did ? kCFRunLoopRunHandledSource : kCFRunLoopRunFinished;
    }
                                                       
    volatile _per_run_data *previousPerRun = __CFRunLoopPushPerRunData(rl
		//取上一次运行的mode
    CFRunLoopModeRef previousMode = rl->_currentMode;
    //如果本次mode和上次的mode一致                                                          
    rl->_currentMode = currentMode;
    //初始化一个result为kCFRunLoopRunFinished                                                                   
    int32_t result = kCFRunLoopRunFinished;

	if (currentMode->_observerMask & kCFRunLoopEntry ) 
        // 1. 通知 Observers: 进入RunLoop。                                                 
        __CFRunLoopDoObservers(rl, currentMode, kCFRunLoopEntry);     
        // 2--11.RunLoop的运行循环的核心代码（这里为什么是2-11呢？请看下面源码）                                                
        result = __CFRunLoopRun(rl, currentMode, seconds, returnAfterSourceHandled, previousMode);
                                                       
	if (currentMode->_observerMask & kCFRunLoopExit ) 
        // 12. 通知 Observers: 退出RunLoop                                               
        __CFRunLoopDoObservers(rl, currentMode, kCFRunLoopExit);
        __CFRunLoopModeUnlock(currentMode);
        __CFRunLoopPopPerRunData(rl, previousPerRun);
		rl->_currentMode = previousMode;
    __CFRunLoopUnlock(rl);
    return result;
}
```

#### RunLoop消息处理函数

```objective-c
// 精简后的 __CFRunLoopRun函数，保留了主要代码
/**
 *  运行run loop
 *
 *  @param rl              运行的RunLoop对象
 *  @param rlm             运行的mode
 *  @param seconds         run loop超时时间
 *  @param stopAfterHandle true:run loop处理完事件就退出  false:一直运行直到超时或者被手动终止
 *  @param previousMode    上一次运行的mode
 *
 *  @return 返回4种状态
 */
static int32_t __CFRunLoopRun(CFRunLoopRef rl, CFRunLoopModeRef rlm, CFTimeInterval seconds, Boolean stopAfterHandle, CFRunLoopModeRef previousMode) {
    //获取系统启动后的CPU运行时间，用于控制超时时间
    uint64_t startTSR = mach_absolute_time();
  
  	//如果RunLoop或者mode是stop状态，则直接return，不进入循环
    if (__CFRunLoopIsStopped(rl)) {
        __CFRunLoopUnsetStopped(rl);
        return kCFRunLoopRunStopped;
    } else if (rlm->_stopped) {
        rlm->_stopped = false;
        return kCFRunLoopRunStopped;
    }
  
  	//mach端口，在内核中，消息在端口之间传递。 初始为0
    mach_port_name_t dispatchPort = MACH_PORT_NULL;
    //判断是否为主线程
    Boolean libdispatchQSafe = pthread_main_np() && ((HANDLE_DISPATCH_ON_BASE_INVOCATION_ONLY && NULL == previousMode) || (!HANDLE_DISPATCH_ON_BASE_INVOCATION_ONLY && 0 == _CFGetTSD(__CFTSDKeyIsInGCDMainQ)));
    //如果在主线程 && runloop是主线程的runloop && 该mode是commonMode，则给mach端口赋值为主线程收发消息的端口
    if (libdispatchQSafe && (CFRunLoopGetMain() == rl) && CFSetContainsValue(rl->_commonModes, rlm->_name)) dispatchPort = _dispatch_get_main_queue_port_4CF();
  
  	#if USE_DISPATCH_SOURCE_FOR_TIMERS
    mach_port_name_t modeQueuePort = MACH_PORT_NULL;
    if (rlm->_queue) {
        //mode赋值为dispatch端口_dispatch_runloop_root_queue_perform_4CF
        modeQueuePort = _dispatch_runloop_root_queue_get_port_4CF(rlm->_queue);
        if (!modeQueuePort) {
            CRASH("Unable to get port for run loop mode queue (%d)", -1);
        }
    }
#endif
    
    //GCD管理的定时器，用于实现runloop超时机制
    dispatch_source_t timeout_timer = NULL;
    struct __timeout_context *timeout_context = (struct __timeout_context *)malloc(sizeof(*timeout_context));
    
    //立即超时
    if (seconds <= 0.0) { // instant timeout
        seconds = 0.0;
        timeout_context->termTSR = 0ULL;
    }
    //seconds为超时时间，超时时执行__CFRunLoopTimeout函数
    else if (seconds <= TIMER_INTERVAL_LIMIT) {
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, DISPATCH_QUEUE_OVERCOMMIT);
        timeout_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_retain(timeout_timer);
        timeout_context->ds = timeout_timer;
        timeout_context->rl = (CFRunLoopRef)CFRetain(rl);
        timeout_context->termTSR = startTSR + __CFTimeIntervalToTSR(seconds);
        dispatch_set_context(timeout_timer, timeout_context); // source gets ownership of context
        dispatch_source_set_event_handler_f(timeout_timer, __CFRunLoopTimeout);
        dispatch_source_set_cancel_handler_f(timeout_timer, __CFRunLoopTimeoutCancel);
        uint64_t ns_at = (uint64_t)((__CFTSRToTimeInterval(startTSR) + seconds) * 1000000000ULL);
        dispatch_source_set_timer(timeout_timer, dispatch_time(1, ns_at), DISPATCH_TIME_FOREVER, 1000ULL);
        dispatch_resume(timeout_timer);
    }
    //永不超时
    else { // infinite timeout
        seconds = 9999999999.0;
        timeout_context->termTSR = UINT64_MAX;
    }
    
    //标志位默认为true
    Boolean didDispatchPortLastTime = true;
  	//记录最后runloop状态，用于return
    int32_t retVal = 0;
    do {
      	//初始化一个存放内核消息的缓冲池
        uint8_t msg_buffer[3 * 1024];
        mach_msg_header_t *msg = NULL;
        mach_port_t livePort = MACH_PORT_NULL;

        //取所有需要监听的port
        __CFPortSet waitSet = rlm->_portSet;
        
        //设置RunLoop为可以被唤醒状态
        __CFRunLoopUnsetIgnoreWakeUps(rl);
      
        if (rlm->_observerMask & kCFRunLoopBeforeTimers)
            // 2. 通知 Observers: RunLoop 即将处理 Timer 回调。
            __CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeTimers);
        if (rlm->_observerMask & kCFRunLoopBeforeSources)
            // 3. 通知 Observers: RunLoop 即将处理 Source
            __CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeSources);
        // 4. 处理Blocks
        __CFRunLoopDoBlocks(rl, rlm);
        
        // 5. 处理 Source0 (非port) 回调(可能再次处理Blocks)
        Boolean sourceHandledThisLoop = __CFRunLoopDoSources0(rl, rlm, stopAfterHandle);
        if (sourceHandledThisLoop) {
            // 处理Blocks
            __CFRunLoopDoBlocks(rl, rlm);
        }
        
      	//如果没有Sources0事件处理 并且 没有超时，poll为false
        //如果有Sources0事件处理 或者 超时，poll都为true
        Boolean poll = sourceHandledThisLoop || (0ULL == timeout_context->termTSR);
        
      	//第一次do..whil循环不会走该分支，因为didDispatchPortLastTime初始化是true
        if (MACH_PORT_NULL != dispatchPort && !didDispatchPortLastTime) {
            // 6. 如果有 Source1 (基于port) 处于 ready 状态，直接处理这个 Source1 然后跳转去处理消息。
          	//从缓冲区读取消息
            msg = (mach_msg_header_t *)msg_buffer;
          	//接收dispatchPort端口的消息，（接收source1事件）
            if (__CFRunLoopServiceMachPort(dispatchPort, &msg, sizeof(msg_buffer), &livePort, 0, &voucherState, NULL)) {
              	//如果接收到了消息的话，前往第9步开始处理msg
                goto handle_msg;
            }
        }
        
      	didDispatchPortLastTime = false;
      
        if (!poll && (rlm->_observerMask & kCFRunLoopBeforeWaiting))
            // 7. 通知 Observers: RunLoop 的线程即将进入休眠(sleep)。
            __CFRunLoopDoObservers(rl, rlm, kCFRunLoopBeforeWaiting);
            __CFRunLoopSetSleeping(rl);
        CFAbsoluteTime sleepStart = poll ? 0.0 : CFAbsoluteTimeGetCurrent();
        do {
            msg = (mach_msg_header_t *)msg_buffer;
            // 8. RunLoop开始休眠：等待消息唤醒，调用 mach_msg 等待接收 mach_port 的消息。直到被下面某一个事件唤醒。
            // • 一个基于 port 的Source 的事件。
            // • 一个 Timer 到时间了
            // • RunLoop 自身的超时时间到了
            // • 被其他什么调用者手动唤醒
            __CFRunLoopServiceMachPort(waitSet, &msg, sizeof(msg_buffer), &livePort, poll ? 0 : TIMEOUT_INFINITY, &voucherState, &voucherCopy);
        } while (1);

        __CFRunLoopUnsetSleeping(rl);
        if (!poll && (rlm->_observerMask & kCFRunLoopAfterWaiting))
            // 9. 通知 Observers: RunLoop 结束休眠（被某个消息唤醒）
            __CFRunLoopDoObservers(rl, rlm, kCFRunLoopAfterWaiting);
      	// 收到消息，处理消息。
    handle_msg:;
        __CFRunLoopSetIgnoreWakeUps(rl);
        
        if (MACH_PORT_NULL == livePort) {
            CFRUNLOOP_WAKEUP_FOR_NOTHING();
            // handle nothing
          	//通过CFRunloopWake唤醒
        } else if (livePort == rl->_wakeUpPort) {
          	//什么都不干，跳回2重新循环
            CFRUNLOOP_WAKEUP_FOR_WAKEUP();
        } else if (rlm->_timerPort != MACH_PORT_NULL && livePort == rlm->_timerPort) {
            CFRUNLOOP_WAKEUP_FOR_TIMER();
            // 9.1 处理Timer：如果一个 Timer 到时间了，触发这个Timer的回调。
            if (!__CFRunLoopDoTimers(rl, rlm, mach_absolute_time())) {
                __CFArmNextTimerInMode(rlm, rl);
            }
        } else if (livePort == dispatchPort) {
            CFRUNLOOP_WAKEUP_FOR_DISPATCH();
            _CFSetTSD(__CFTSDKeyIsInGCDMainQ, (void *)6, NULL);
            // 9.2 处理GCD Async To Main Queue：如果有dispatch到main_queue的block，执行block。
            __CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__(msg);
        } else {
            CFRUNLOOP_WAKEUP_FOR_SOURCE();
            voucher_t previousVoucher = _CFSetTSD(__CFTSDKeyMachMessageHasVoucher, (void *)voucherCopy, os_release);
            CFRunLoopSourceRef rls = __CFRunLoopModeFindSourceForMachPort(rl, rlm, livePort);
            if (rls) {
                mach_msg_header_t *reply = NULL;
                // 9.3 处理Source1：如果一个 Source1 (基于port) 发出事件了，处理这个事件
                sourceHandledThisLoop = __CFRunLoopDoSource1(rl, rlm, rls, msg, msg->msgh_size, &reply) || sourceHandledThisLoop;
                if (NULL != reply) {
                    (void)mach_msg(reply, MACH_SEND_MSG, reply->msgh_size, 0, MACH_PORT_NULL, 0, MACH_PORT_NULL);
                    CFAllocatorDeallocate(kCFAllocatorSystemDefault, reply);
                }
            }
        }
        // 10. 处理Blocks
        __CFRunLoopDoBlocks(rl, rlm);
        
        // 11. 根据前面的处理结果，决定流程
        // 11.1 当下面情况发生时，退出RunLoop
        if (sourceHandledThisLoop && stopAfterHandle) {
            retVal = kCFRunLoopRunHandledSource;
        } else if (timeout_context->termTSR < mach_absolute_time()) {
            // 11.1.1 超出传入参数标记的超时时间了
            retVal = kCFRunLoopRunTimedOut;
        } else if (__CFRunLoopIsStopped(rl)) {
            // 11.1.2 当前RunLoop已经被外部调用者强制停止了
            __CFRunLoopUnsetStopped(rl);
            retVal = kCFRunLoopRunStopped;
        } else if (rlm->_stopped) {
            // 11.1.3 当前运行模式已经被停止
            rlm->_stopped = false;
            retVal = kCFRunLoopRunStopped;
        } else if (__CFRunLoopModeIsEmpty(rl, rlm, previousMode)) {
            // 11.1.4 source/timer/observer一个都没有了
            retVal = kCFRunLoopRunFinished;
        }
        voucher_mach_msg_revert(voucherState);
        os_release(voucherCopy);
        // 11.2 如果没超时，mode里不为空也没停止，loop也没被停止，那继续loop。
    } while (0 == retVal);
    
    return retVal;
}
```

#### 消息处理底层函数

- 当 `RunLoop` 进行回调时，一般都是通过一个很长的函数调用出去` (call out)`，当你在你的代码中下断点调试时，打印堆栈`（bt）`，就能在调用栈上看到这些函数。

- 下面是这几个函数的整理版本，如果你在调用栈中看到这些长函数名，在这里查找一下就能定位到具体的调用地点了：

```objective-c
{
    // 1. 通知 Observers: 进入RunLoop。
    // 此处有Observer会创建AutoreleasePool: _objc_autoreleasePoolPush();
    __CFRUNLOOP_IS_CALLING_OUT_TO_AN_OBSERVER_CALLBACK_FUNCTION__(kCFRunLoopEntry);
 
    // 2. 通知 Observers: RunLoop 即将处理 Timer 回调。   
__CFRUNLOOP_IS_CALLING_OUT_TO_AN_OBSERVER_CALLBACK_FUNCTION__(kCFRunLoopBeforeTimers);
   
    // 3. 通知 Observers: RunLoop 即将处理 Source
 __CFRUNLOOP_IS_CALLING_OUT_TO_AN_OBSERVER_CALLBACK_FUNCTION__(kCFRunLoopBeforeSources);
    // 4. 处理Blocks
    __CFRUNLOOP_IS_CALLING_OUT_TO_A_BLOCK__(block);

    // 5. 处理 Source0 (非port) 回调(可能再次处理Blocks)
    __CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE0_PERFORM_FUNCTION__(source0);
    __CFRUNLOOP_IS_CALLING_OUT_TO_A_BLOCK__(block);

    // 7. 通知 Observers: RunLoop 的线程即将进入休眠(sleep)。
    /// 此处有Observer释放并新建AutoreleasePool: _objc_autoreleasePoolPop(); _objc_autoreleasePoolPush();
 __CFRUNLOOP_IS_CALLING_OUT_TO_AN_OBSERVER_CALLBACK_FUNCTION__(kCFRunLoopBeforeWaiting);

    // 8. RunLoop开始休眠：等待消息唤醒，调用 mach_msg 等待接收 mach_port 的消息。
    mach_msg() -> mach_msg_trap();


    // 9. 通知 Observers: RunLoop 结束休眠（被某个消息唤醒）
 __CFRUNLOOP_IS_CALLING_OUT_TO_AN_OBSERVER_CALLBACK_FUNCTION__(kCFRunLoopAfterWaiting);

    // 9.1 处理Timer：如果一个 Timer 到时间了，触发这个Timer的回调。
    __CFRUNLOOP_IS_CALLING_OUT_TO_A_TIMER_CALLBACK_FUNCTION__(timer);

    // 9.2 处理GCD Async To Main Queue：如果有dispatch到main_queue的block，执行block。
    __CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__(dispatched_block);

    // 9.3 处理Source1：如果一个 Source1 (基于port) 发出事件了，处理这个事件
    __CFRUNLOOP_IS_CALLING_OUT_TO_A_SOURCE1_PERFORM_FUNCTION__(source1);
 
    // 10. 处理Blocks
    __CFRUNLOOP_IS_CALLING_OUT_TO_A_BLOCK__(block);
    
    // 12. 通知 Observers: 退出RunLoop
    // 此处有Observer释放AutoreleasePool: _objc_autoreleasePoolPop();
    __CFRUNLOOP_IS_CALLING_OUT_TO_AN_OBSERVER_CALLBACK_FUNCTION__(kCFRunLoopExit);
}

```

#### 休眠的实现



#### 代码逻辑图

- 将上面的代码逻辑抽取下面得到如下：
  - 黄色：表示通知 Observer 各个阶段；
  - 蓝色：处理消息的逻辑；
  - 绿色：分支判断逻辑；

![RunLoop执行逻辑](https://tva1.sinaimg.cn/large/006y8mN6ly1g6q8tf8rbhj318q0m8108.jpg)

#### 代码流程图

![RunLoop流程图](https://tva1.sinaimg.cn/large/006y8mN6ly1g6q8tnx4rcj30u016g453.jpg)

## RunLoop的应用

### 常驻线程

- 常驻线程的作用：我们知道，当子线程中的任务执行完毕之后就被销毁了，那么如果我们需要开启一个子线程，在程序运行过程中永远都存在，那么我们就会面临一个问题，如何让子线程永远活着，这时就要用到常驻线程：给子线程开启一个`RunLoop`**注意：子线程执行完操作之后就会立即释放，即使我们使用强引用引用子线程使子线程不被释放，也不能给子线程再次添加操作，或者再次开启。**
- 子线程开启`RunLoop`的代码，先点击屏幕开启子线程并开启子线程`RunLoop`，然后点击`button`。

```objective-c
#import "ViewController.h"

@interface ViewController ()
@property(nonatomic,strong)NSThread *thread;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
   // 创建子线程并开启
    NSThread *thread = [[NSThread alloc]initWithTarget:self selector:@selector(show) object:nil];
    self.thread = thread;
    [thread start];
}
-(void)show
{
    // 注意：打印方法一定要在RunLoop创建开始运行之前，如果在RunLoop跑起来之后打印，RunLoop先运行起来，已经在跑圈了就出不来了，进入死循环也就无法执行后面的操作了。
    // 但是此时点击Button还是有操作的，因为Button是在RunLoop跑起来之后加入到子线程的，当Button加入到子线程RunLoop就会跑起来
    NSLog(@"%s",__func__);
    // 1.创建子线程相关的RunLoop，在子线程中创建即可，并且RunLoop中要至少有一个Timer 或 一个Source 保证RunLoop不会因为空转而退出，因此在创建的时候直接加入
    // 添加Source [NSMachPort port] 添加一个端口
    [[NSRunLoop currentRunLoop] addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
    // 添加一个Timer
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(test) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];    
    //创建监听者
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(CFAllocatorGetDefault(), kCFRunLoopAllActivities, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        switch (activity) {
            case kCFRunLoopEntry:
                NSLog(@"RunLoop进入");
                break;
            case kCFRunLoopBeforeTimers:
                NSLog(@"RunLoop要处理Timers了");
                break;
            case kCFRunLoopBeforeSources:
                NSLog(@"RunLoop要处理Sources了");
                break;
            case kCFRunLoopBeforeWaiting:
                NSLog(@"RunLoop要休息了");
                break;
            case kCFRunLoopAfterWaiting:
                NSLog(@"RunLoop醒来了");
                break;
            case kCFRunLoopExit:
                NSLog(@"RunLoop退出了");
                break;
            
            default:
                break;
        }
    });
    // 给RunLoop添加监听者
    CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, kCFRunLoopDefaultMode);
    // 2.子线程需要开启RunLoop
    [[NSRunLoop currentRunLoop]run];
    CFRelease(observer);
}
- (IBAction)btnClick:(id)sender {
    [self performSelector:@selector(test) onThread:self.thread withObject:nil waitUntilDone:NO];
}
-(void)test
{
    NSLog(@"%@",[NSThread currentThread]);
}
@end
```

- **注意：创建子线程相关的RunLoop，在子线程中创建即可，并且RunLoop中要至少有一个Timer 或 一个Source 保证RunLoop不会因为空转而退出，因此在创建的时候直接加入，如果没有加入Timer或者Source，或者只加入一个监听者，运行程序会崩溃**

### NSTimer

#### 1. 定时器的使用

- 定时器，在开发中一般使用 `NSTimer`，可以产生基于时间的通知，但它并不是实时机制。和输入源一样，定时器也 `RunLoop` 的特定模式相关。如果定时器所在的模式当前未被 `RunLoop` 监视，那么定时器并不会被调用。

- `NSTimer` 就是基于 `runLoop` 在运行的, 当它被添加到` runLoop` 之后,` runLoop` 就会根据它的时间间隔来注册相应的时间点, 到时间点之后 `timer` 就会唤醒 `runLoop` 来触发 `timer` 指定的事件. **因此在使用 timer 的时候我们必须先把 timer 添加到 runLoop  中, 并且还得添加到 runLoop 的指定模式中, 它才能起作用, 否则它是不起作用的.**

- `NSTimer` 有两种创建方式。

```objective-c
// a. timerWithTimeInterval
+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer *timer))block;

// b. scheduledTimerWithTimeInterval
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(NSTimer *timer))block;
```

- **其中，方式 a，仅仅创建，并返回，如果要是的 `NSTimer` 被调用，需要手动 `RunLoop`。**

```objective-c
// 方式1：创建timer，手动添加到default mode，滑动时定时器停止
static int count = 0;
NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
    NSLog(@"%d", ++count);
}];
[[NSRunLoop currentRunLoop] addTimer:timer forMode: NSDefaultRunLoopMode];
```

- **方式 b，创建一个定时器之外, 还会把创建的这个定时器自动添加到当前线程的 runLoop 下, 并且是添加到了 runloop 的 defaultMode 下.**

```objective-c
//     方式2：创建timer默认添加到default mode，滑动时定时器停止
    static int count = 0;
    [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        NSLog(@"%d", ++count);
    }];
```

- 这种方式下，不用再往 mode 里添加，也能正常调用 Timer。

#### 2. 滑动时失效

- 在上面创建 `NSTimer` 的方式中，不管方式 a，还是 b，假如页面在滑动 `ScrollView` 时，定时器都会停止调用。

- 因为在滑动 `ScrollView` 时，`RunLoop` 处于 **UITrackingRunLoopMode** 运行模式下，该模式中如果不手动添加对应的 Timer，是不会有定时器的，所以在滑动时，也就不会调用定时器的回调。

- 那么，解决方式，就是将定时器，添加到 **UITrackingRunLoopMode** 下。

```objective-c
[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
[[NSRunLoop currentRunLoop] addTimer:timer forMode:UITrackingRunLoopMode];
```

- 或者利用之前的 `Common Mode`。

```objective-c
[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
```

#### 3. 不准时

- 一个 `NSTimer` 注册到 `RunLoop` 后，`RunLoop` 会为其重复的时间点注册好事件。例如 10:00, 10:10, 10:20 这几个时间点。`RunLoop` 为了节省资源，并不会在非常准确的时间点回调这个 Timer。Timer 有个属性叫做 Tolerance (宽容度)，标示了当时间点到后，容许有多少最大误差。

- 如果某个时间点被错过了，例如执行了一个很长的任务，则那个时间点的回调也会跳过去，不会延后执行。就比如等公交，如果 10:10 时我忙着玩手机错过了那个点的公交，那我只能等 10:20 这一趟了。

- `CADisplayLink` 是一个和屏幕刷新率一致的定时器（但实际实现原理更复杂，和 `NSTimer` 并不一样，其内部实际是操作了一个 Source）。如果在两次屏幕刷新之间执行了一个长任务，那其中就会有一帧被跳过去（和 `NSTimer` 相似），造成界面卡顿的感觉。

### AutoreleasePool

- `App` 启动后，苹果在主线程 `RunLoop` 里注册了两个 `Observer`，其回调都是 `_wrapRunLoopWithAutoreleasePoolHandler ()`。

```objective-c
observers = (
    // activities = 0x1，监听的是Entry
    "<CFRunLoopObserver>{valid = Yes, activities = 0x1, repeats = Yes, order = -2147483647, callout = _wrapRunLoopWithAutoreleasePoolHandler (0x1138221b1), context = <CFArray >{type = mutable-small, count = 1, values = (\n\t0 : <0x7ff6e6002058>\n)}}",
    "<CFRunLoopObserver >{valid = Yes, activities = 0xa0, repeats = Yes, order = 2147483647, callout = _wrapRunLoopWithAutoreleasePoolHandler (0x1138221b1), context = <CFArray>{type = mutable-small, count = 1, values = (\n\t0 : <0x7ff6e6002058>\n)}}"
),
```

在主线程执行的代码，通常是写在诸如事件回调、`Timer` 回调内的。这些回调会被 `RunLoop` 创建好的 `AutoreleasePool` 环绕着，所以不会出现内存泄漏，开发者也不必显示创建` Pool` 了。

- 第一个` Observer` 会监听 **Entry**（即将进入 Loop），其回调内会调用 **objc_autoreleasePoolPush()** 向当前的 **AutoreleasePoolPage** 增加一个**哨兵对象**标志创建自动释放池。这个` Observer` 的 `order` 是 - 2147483647 优先级最高，确保发生在所有回调操作之前。
- 第二个 `Observer` 会监听 `RunLoop` 的 **BeforeWaiting**（准备进入休眠）和 **Exit**（即将退出 Loop）两种状态。
  - 在即将进入休眠时会调用 **objc_autoreleasePoolPop()** 和 **objc_autoreleasePoolPush()** 根据情况从最新加入的对象一直往前清理直到遇到哨兵对象。
  - 即将退出 `RunLoop` 时会调用 **objc_autoreleasePoolPop()** 释放自动自动释放池内对象。这个 `Observer` 的 `order` 是 2147483647，优先级最低，确保发生在所有回调操作之后。

当然你如果需要显式释放，例如循环，可以自己创建` AutoreleasePool`，否则一般不需要自己创建。

### 事件响应

- 苹果注册了一个 `Source1` (基于 mach port 的) 用来接收系统事件，其回调函数为 `__IOHIDEventSystemClientQueueCallback ()`。

- 当一个硬件事件 (触摸 / 锁屏 / 摇晃等) 发生后，首先由 `IOKit.framework` 生成一个 IOHIDEvent 事件并由 `SpringBoard` 接收。这个过程的详细情况可以参考[这里](http://iphonedevwiki.net/index.php/IOHIDFamily)。`SpringBoard` 只接收按键 (锁屏 / 静音等)，触摸，加速，接近传感器等几种 `Event`，随后用 `mach port` 转发给需要的 App 进程。随后苹果注册的那个 `Source1` 就会触发回调，并调用` _UIApplicationHandleEventQueue ()` 进行应用内部的分发。

- `_UIApplicationHandleEventQueue ()` 会把 `IOHIDEvent` 处理并包装成` UIEvent` 进行处理或分发，其中包括识别 `UIGesture / 处理屏幕旋转 / 发送给 UIWindow` 等。通常事件比如` UIButton` 点击、`touchesBegin/Move/End/Cancel` 事件都是在这个回调中完成的。

- 比如，`UIButton` 点击事件，通过 `Source1` 接收后，包装成 `Event`，最后进行分发是由 `Source0` 事件回调来处理的。

### 手势识别

```objective-c
"<CFRunLoopObserver 0x60000137cf00 [0x110c33b68]>{valid = Yes, activities = 0x20, repeats = Yes, order = 0, callout = _UIGestureRecognizerUpdateObserver (0x1133f4473), context = <CFRunLoopObserver context 0x60000097d9d0>}"
```

- 当上面的 `_UIApplicationHandleEventQueue ()` 识别了一个手势时，其首先会调用 `Cancel` 将当前的 `touchesBegin/Move/End` 系列回调打断。随后系统将对应的 `UIGestureRecognizer` 标记为待处理。

- 苹果注册了一个 `Observer` 监测 **BeforeWaiting**（Loop 即将进入休眠）事件，这个 `Observer `的回调函数是 `_UIGestureRecognizerUpdateObserver ()`，其内部会获取所有刚被标记为待处理的 `GestureRecognizer`，并执行 `GestureRecognizer` 的回调。

- 当有 `UIGestureRecognizer` 的变化 (创建 / 销毁 / 状态改变) 时，这个回调都会进行相应处理。

### 界面更新

```objective-c
"<CFRunLoopObserver>{valid = Yes, activities = 0xa0, repeats = Yes, order = 2000000, callout = _ZN2CA11Transaction17observer_callbackEP19__CFRunLoopObservermPv (0x1152506ae), context = <CFRunLoopObserver context 0x0>}"
```

- 当在操作 UI 时，比如改变了 `Frame`、更新了 `UIView/CALayer` 的层次时，或者手动调用了 `UIView/CALayer` 的 `setNeedsLayout/setNeedsDisplay` 方法后，这个 `UIView/CALayer` 就被标记为待处理，并被提交到一个全局的容器去。

- 苹果注册了一个 `Observer` 监听 **BeforeWaiting（即将进入休眠）**和 **Exit （即将退出 Loop）**事件，回调去执行一个很长的函数：
  **_ZN2CA11Transaction17observer_callbackEP19__CFRunLoopObservermPv()**。这个函数里会遍历所有待处理的 `UIView/CAlayer` 以执行实际的绘制和调整，并更新 UI 界面。

- 这个函数内部的调用栈大概是这样的：

```objective-c
_ZN2CA11Transaction17observer_callbackEP19__CFRunLoopObservermPv()
    QuartzCore:CA::Transaction::observer_callback:
        CA::Transaction::commit();
            CA::Context::commit_transaction();
                CA::Layer::layout_and_display_if_needed();
                    CA::Layer::layout_if_needed();
                        [CALayer layoutSublayers];
                            [UIView layoutSubviews];
                    CA::Layer::display_if_needed();
                        [CALayer display];
                            [UIView drawRect];
```

- 通常情况下这种方式是完美的，因为除了系统的更新，以及 `setNeedsDisplay` 等方法手动触发下一次 `RunLoop` 运行的更新。但是如果当前正在执行大量的逻辑运算可能 UI 的更新就会比较卡，因此 `facebook` 推出了 [AsyncDisplayKit](https://github.com/facebookarchive/AsyncDisplayKit) 来解决这个问题。`AsyncDisplayKit` 其实是将 UI 排版和绘制运算尽可能放到后台，将 UI 的最终更新操作放到主线程（这一步也必须在主线程完成），同时提供一套类 `UIView 或 CALayer` 的相关属性，尽可能保证开发者的开发习惯。这个过程中 `AsyncDisplayKit` 在主线程 `RunLoop` 中增加了一个 `Observer` 监听即将进入休眠和退出 `RunLoop` 两种状态，收到回调时遍历队列中的待处理任务一一执行。

### PerformSelecter

perforSelector 有下面三类：

```objective-c
// 1.和RunLoop不相干，底层直接调用objc_sendMsg方法
- (id)performSelector:(SEL)aSelector withObject:(id)object;
// 2. 和RunLoop相关，封装成Source0事件，依赖于RunLoop，若线程无对应的RunLoop，会调用objc_sendMsg执行
- (void)performSelectorOnMainThread:(SEL)aSelector withObject:(nullable id)arg waitUntilDone:(BOOL)wait;
// 3. 和RunLoop相关，封装成Timers事件
- (void)performSelector:(SEL)aSelector withObject:(nullable id)anArgument afterDelay:(NSTimeInterval)delay;
```

- 在苹果开源的 [objc 源码](https://opensource.apple.com/tarballs/objc4/)，我们从 **NSObject.mm** 得到如下源码：

```objective-c
- (id)performSelector:(SEL)sel {
    if (!sel) [self doesNotRecognizeSelector:sel];
    return ((id(*)(id, SEL))objc_msgSend)(self, sel);
}

- (id)performSelector:(SEL)sel withObject:(id)obj {
    if (!sel) [self doesNotRecognizeSelector:sel];
    return ((id(*)(id, SEL, id))objc_msgSend)(self, sel, obj);
}
```

- 从源码可以直接看出，在不包含 `delay` 时，其直接调用 `objc_msgSend`，与 `RunLoop` 无关。

- 但是，找不到 `- (void) performSelector: withObject: afterDelay:` 的源码。苹果并没有开源。

- 我们通过 **GNUstep** 项目，找到该方法的 [Foundation 的源码](http://www.gnustep.org/resources/downloads.php)。

```objective-c
- (void) performSelector: (SEL)aSelector
	      withObject: (id)argument
	      afterDelay: (NSTimeInterval)seconds
{
  NSRunLoop		*loop = [NSRunLoop currentRunLoop];
  GSTimedPerformer	*item;
  item = [[GSTimedPerformer alloc] initWithSelector: aSelector
					     target: self
					   argument: argument
					      delay: seconds];
  [[loop _timedPerformers] addObject: item];
  RELEASE(item);
  [loop addTimer: item->timer forMode: NSDefaultRunLoopMode];
}
// GSTimedPerformer对象
@interface GSTimedPerformer: NSObject
{
@public
  SEL		selector;
  id		target;
  id		argument;
  NSTimer	*timer;
}
```

- 其实本质上，是转换为一个包含 `NSTimer` 定时器的 `GSTimedPerformer` 对象，实质上是个 `Timers` 事件，添加到 `RunLoop` 中。

**注意：GNUstep 项目只是一个开源实现，其实现和苹果实现大部分一致，所以可参考性很强，但并不是完全一致。**

### 关于 GCD

- 在 `RunLoop` 的源代码中可以看到用到了 GCD 的相关内容，但是 RunLoop 本身和 GCD 并没有直接的关系。

- 当调用了 `dispatch_async (dispatch_get_main_queue (), <#^(void) block#>)` 时 `libDispatch` 会向主线程 `RunLoop` 发送消息唤醒` RunLoop`，`RunLoop` 从消息中获取 `block`，并且在 **CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE** 回调里执行这个 `block`。

- 不过这个操作仅限于主线程，其他线程 `dispatch` 操作是全部由 `libDispatch `驱动的。
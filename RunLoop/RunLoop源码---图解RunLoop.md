[TOC]

# RunLoop源码---图解RunLoop

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

### CFRunLoopSourceRef

### CFRunLoopTimerRef 

### CFRunLoopObserverRef

## RunLoop的应用

### 常驻线程

### NSTimer

### AutoreleasePool

### 事件响应

### 手势识别

### 界面更新


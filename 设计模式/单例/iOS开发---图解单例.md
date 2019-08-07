[TOC]

# iOS开发---单例详解

## 什么是单例模式？

> 单例模式是设计模式中最简单的形式之一。这一模式的目的是使得类的一个对象成为系统中的唯一实例。要实现这一点，可以从客户端对其进行实例化开始。因此需要用一种只允许生成对象类的唯一实例的机制，“阻止”所有想要生成对象的访问。使用工厂方法来限制实例化过程。这个方法应该是静态方法（类方法），因为让类的实例去生成另一个唯一实例毫无意义。

1. 第一句话说明了单例是一种设计模式，有很多人在面试被问到单例时经常说：单例是一个对象，它在程序运行中是唯一的。这是把单例的定义和作用混淆了，它的作用是保证程序运行过程中对象的唯一性，所以这点需要注意。

2. 后面说的就是如何实现单例了，其中提到需要创建一个静态方法（类方法），这正是需要我们去做的

## 单例使用场合

> 在整个应用程序中，共享一份资源（这份资源只需要创建初始化1次），一般用于工具类。例如：**登陆控制器，网络数据请求，音乐播放器**等一个工程需要使用多次的控制器或方法。

## 单例优缺点

#### 优点

- 单例模式可以保证系统中一个类只有一个实例而且该实例易于外界访问，从而方便对实例个数的控制并节约系统资源。如果希望在系统中某个类的对象只能存在一个，单例模式是最好的解决方案。单例模式因为类控制了实例化过程，所以类可以更加灵活修改实例化过程。

#### 缺点

- 单例对象一旦建立，对象指针是保存在静态区的，单例对象在堆中分配的内存空间，会在应用程序终止后才会被释放。单例类无法继承，因此很难进行类的扩展。单例不适用于变化的对象，如果同一类型的对象总是要在不同的用例场景发生变化，单例就会引起数据的错误，不能保存彼此的状态。

## 单例的实现方式

### 单例中懒汉式实现方式

> 在`iOS`中，懒加载几乎是无处不在的，其实，懒加载在某种意义上也是采用了单例模式的思想（如果对象存在就直接返回，对象不存在就创建对象），那么本文就从大家熟悉的懒加载入手进行讲解（整个过程都用实际的代码进行说明）

#### 加锁

> 如果要保证应用中就只有一个对象，就应该让类的`alloc`方法只会进行一次内存空间的分配。所以我们需要重写`alloc`方法，这里提供了两种方法，一种是`alloc`，一种是`allocWithZone`方法

- 其实在`alloc`调用的底层也是`allocWithZone`方法，所以在此，我们只需要重写`allocWithZone`方法：

```objective-c
id manager;
+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    if (manager == nil) {
        // 调用super的allocWithZone方法来分配内存空间
        manager = [super allocWithZone:zone];
    }
    return manager;
}
```

> 在这里我们初步使用懒加载来控制保证只有一个单例，但是这种仅仅适合在单一线程中使用的情况，要是涉及到了多线程的话，那么就会出现这样的情况：
>
> 当一个线程走到了`if`判断时，判断为空，然后进入其中去创建对象，在还没有返回的时候，另外一条线程又到了`if`判断，判断仍然为空，于是又进入进行对象的创建，所以这样的话就保证不了只有一个单例对象。

- 于是，我们对代码进行手动加锁:

```objective-c
id manager;
+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    // 在这里加一把锁（利用本类为锁）进行多线程问题的解决
    @synchronized(self){
        if (manager == nil) {
            // 调用super的allocWithZone方法来分配内存空间
            manager = [super allocWithZone:zone];
        }
    }
    return manager;
}
```

> 这样的话，就可以解决上述问题，但是，每一次进行`alloc`的时候都会加锁和判断锁的存在，这一点是可以进行优化的

- 于是在加锁之前再次进行判断，修改代码如下:

```objective-c

id manager;
+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    // 在这里判断，为了优化资源，防止多次加锁和判断锁
    if (manager == nil) {
        // 在这里加一把锁（利用本类为锁）进行多线程问题的解决
        @synchronized(self){
            if (manager == nil) {
                // 调用super的allocWithZone方法来分配内存空间
                manager = [super allocWithZone:zone];
            }
        }
    }
    return manager;
}
```

> 到此，在`allocWithZone`方法中的代码基本完善.

------

>  我们在创建单例的时候都不是使用的`alloc`和`init`，而是使用的`shared`加上变量名这种创建方式，所以，我们自己写单例的话，也应该向外界暴露这个方法。

- 在.h文件中先声明下方法

```objective-c
+ (instancetype)sharedManager;

//在.m文件中实现该方法
+ (instancetype)sharedManager
{
    if (manager == nil) {
        @synchronized(self){
            if (manager == nil) {
                // 在这里写self和写本类名是一样的
                manager = [[self alloc]init];
            }
        }
    }
    return manager;
}
```

- 这个对外暴露的方法完成之后，我们还需要注意一点，在使用`copy`这个语法的时候，是能够创建新的对象的，如果使用`copy`创建出新的对象的话，那么就不能够保证单例的存在了，所以我们需要重写`copyWithZone`方法.
- 如果直接在.m文件中敲的话，会发现没有提示，这是没有声明协议的原因，可以在.h文件中声明`NSCopying`协议，然后重写`copyWithZone`方法：

```objective-c
- (id)copyWithZone:(NSZone *)zone
{
    return manager;
}
```

> ⚠️：在这里没有像上面两个方法一样实现逻辑是因为：使用`copy`的前提是必须现有一个对象，然后再使用，所以既然都已经创建了一个对象了，那么全局变量所代表的对象也就是这个单例，那么在`copyWithZone`方法中直接返回就好了

- 到了这里不知道大家有没有发现什么问题？

  - 我们所声明的全局变量是没有使用`static`来修饰的，大家在开发过程中所遇见到的全局变量很多都是使用了`static`来修饰的

  - 下面我们给大家说明一下static的用法：

    1. static修饰局部变量：

       如果修饰了局部变量的话，那么这个局部变量的生命周期就和不加static的全局变量一样了（也就是只有一块内存区域，无论这个方法执行多少次，都不会进行内存的分配），不同的在于作用域仍然没有改变

    2. static修饰全局变量：

       如果不适用static的全局变量，我们可以在其他的类中使用extern关键字直接获取到这个对象，可想而知，在我们所做的单例模式中，如果在其他类中利用extern拿到了这个对象，进行一个对象销毁，例如：

       ```objective-c
       extern id moviePlayer;
       moviePlayer = nil;
       //这时候在这句代码之前创建的单例就销毁了，再次创建的对象就不是同一个了，这样就无法保证单例的存在
       ```

    - 所以对于全局变量的定义，需要加上static修饰符

    ```objective-c
    static id manager;
    ```

#### GCD

```objective-c
static id manager;
+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [super allocWithZone:zone];
    });
    return manager;
}
```

> `dispatch_once`方法是已经在方法的内部解决了多线程问题的，所以我们不用再去加锁,`dispatch_once`表示内部方法只会执行一次

```objective-c
+ (instancetype)sharedManager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc]init];
    });
    return manager;
}

- (id)copyWithZone:(NSZone *)zone
{
    return manager;
}
```

- 这样通过GCD方式的单例实现完成

### 单例中饿汉式实现方式

- 首先我们来解释一下懒汉式和饿汉式的区别
  1. 懒汉式：实现原理和懒加载其实很像，如果在程序中不使用这个对象，那么就不会创建，只有在你使用代码创建这个对象，才会创建。这种实现思想或者说是原理都是iOS开发中非常重要的，所以，懒汉式的单例模式也是最为重要的，是开发中最常见的。
  2. 饿汉式：在没有使用代码去创建对象之前，这个对象已经加载好了，并且分配了内存空间，当你去使用代码创建的时候，实际上只是将这个原本创建好的对象拿出来而已。
- 接下来我们介绍饿汉式：
  - 饿汉式是在使用代码（这里提到的使用代码去创建对象实际上就是用alloc或者是对外暴露的shared方法，最根本上是调用了alloc方法）去创建对象之前就已经创建好了对象，换句话说，饿汉式也就是在我们手动写代码去alloc之前就已经将对象创建完毕了。这里介绍两个方法，第一个是load方法，第二个是initialize方法
    1. load方法：当类加载到运行环境中的时候就会调用且仅调用一次，同时注意一个类只会加载一次（类加载有别于引用类，可以这么说，所有类都会在程序启动的时候加载一次，不管有没有在目前显示的视图类中引用到
    2. 当第一次使用类的时候加载且仅加载一次
- 下面我只用load给大家做示范

------

- 首先我们需要重写`load`方法

```objective-c
static id manager;
+ (void)load
{
    manager = [[self alloc]init];
}
```

- 接着重写`allocWithZone`方法

```objective-c
+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    if (manager == nil) {
        manager = [super allocWithZone:zone];
    }
    return manager;
}
```

> 在这里我们会发现特别简介，去掉了枷锁或者使用GCD的方式，我们来分析一下原因：
>
> 首先，在类被加载的时候会调用且仅调用一次load方法，而load方法里面又调用了alloc方法，所以，第一次调用肯定是创建好了对象，而且这时候不会存在多线程问题。当我们手动去使用alloc的时候，无论如何都过不了判断，所以也不会存在多线程的问题了。

- 接下来我们要实现shear和copy方法

```objective-c
+ (instancetype)sharedManager
{
    return manager;
}

- (id)copyWithZone:(NSZone *)zone
{
    return manager;
}
```

> 这里变得更加简洁了，甚至连判断都不用加，这是为什么？
>
> 是因为我们使用sharedManager方法和copy的时候必然全局变量是有值的

### MRC下单例实现方式

>  在MRC模式下，我们是需要手动去管理内存的，因此，我们可以使用release去将一个对象手动销毁，那么这样的话，我们的创建出来的单例对象也可以被很轻易的销毁。所以在MRC情况下的单例模式，我们将着重将目光放到内存管理的方法上去

- 首先是release方法，我们是不希望将我们的单例对象进行销毁掉的，那么很简单，重写release

```objective-c
- (oneway void)release
{
    
}
//我们只需要将这个方法重写，然后不在里面写代码就可以了
```

- retain方法：在这里面只需要返回这个单例本身就好了，不对引用计数做任何处理

```objective-c
- (instancetype)retain
{
    return manager;
}
```

- retainCount方法，这个方法返回的是对象的引用计数，我们已经重写了retain方法，不希望改变单例对象的引用计数，所以在这里返回1就好了

```objective-c
- (NSUInteger)retainCount
{
    return 1;
}
```

- autorelease方法，对这个方法的处理和retain方法类似，我们只需要将对象本身返回，不需要进行自动释放池的操作

```objective-c
- (instancetype)autorelease
{
    return manager;
}
```

- 现在MRC下代码已经完成了

```objective-c
static id manager;
+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[super alloc]init];
    });
    return manager;
}
+ (instancetype)sharedManager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc]init];
    });
    return manager;
}
- (id)copyWithZone:(NSZone *)zone
{
    return manager;
}
- (oneway void)release
{
    
}
- (instancetype)retain
{
    return manager;
}
- (NSUInteger)retainCount
{
    return 1;
}
- (instancetype)autorelease
{
    return manager;
}
@end
```

## 封装单例模式

- 想要单例模式的代码实用化，我们会面临两个问题
  1. 如何写一份单例代码在ARC和MRC环境下都适用？
  2. 如何使一份单例代码可以多个类共同使用

- 第一个问题可以通过条件编译来解决

```objective-c
#if __has_feature(objc_arc)
//如果是ARC，那么就执行这里的代码1
#else
//如果不是ARC，那么就执行代理的代码2
#endif
```

- 第二个问题直接上代码

```php

// .h文件的代码
#define NTSingletonH(name) + (instancetype)shared##name;
// .m文件中的代码（使用条件编译来区别ARC和MRC）
#if __has_feature(objc_arc)
 
#define NTSingletonM(name)\
static id instance;\
+ (instancetype)allocWithZone:(struct _NSZone *)zone\
{\
    static dispatch_once_t onceToken;\
    dispatch_once(&onceToken, ^{\
    instance = [[super alloc]init];\
    });\
    return instance;\
}\
+ (instancetype)shared##name\
{\
    static dispatch_once_t onceToken;\
    dispatch_once(&onceToken, ^{\
    instance = [[self alloc]init];\
    });\
    return instance;\
}\
- (id)copyWithZone:(NSZone *)zone\
{\
		return instance;\
}
 
#else
 
#define NTSingletonM(name)\
static id instance;\
+ (instancetype)allocWithZone:(struct _NSZone *)zone\
{\
    static dispatch_once_t onceToken;\
    dispatch_once(&onceToken, ^{\
    instance = [[super alloc]init];\
    });\
    return instance;\
}\
+ (instancetype)shared##name\
{\
    static dispatch_once_t onceToken;\
    dispatch_once(&onceToken, ^{\
    instance = [[self alloc]init];\
    });\
    return instance;\
}\
- (id)copyWithZone:(NSZone *)zone\
{\
		return instance;\
}\
- (oneway void)release\
{\
}\
- (instancetype)retain\
{\
		return instance;\
}\
- (NSUInteger)retainCount\
{\
		return 1;\
}\
- (instancetype)autorelease\
{\
		return instance;\
}
```


Table of Contents
=================

   * [iOS开发---图解KVO](#ios开发---图解kvo)
      * [什么是KVO？](#什么是kvo)
      * [KVO基本使用](#kvo基本使用)
         * [注册观察者](#注册观察者)
         * [监听回调](#监听回调)
         * [调用方式](#调用方式)
            * [自动调用](#自动调用)
            * [手动调用](#手动调用)
         * [移除观察者](#移除观察者)
         * [Crash](#crash)
            * [观察者未实现监听方法](#观察者未实现监听方法)
            * [未及时移除观察者](#未及时移除观察者)
            * [多次移除观察者](#多次移除观察者)
         * [实际应用](#实际应用)
      * [KVO实现原理](#kvo实现原理)
            * [测试代码](#测试代码)
            * [发现中间对象](#发现中间对象)
               * [NSKVONotifying_Person类内部实现](#nskvonotifying_person类内部实现)
               * [setter实现不同](#setter实现不同)
            * [KVO内部调用流程](#kvo内部调用流程)
      * [KVO扩展](#kvo扩展)
            * [1.KVC 与 KVO 的不同？](#1kvc-与-kvo-的不同)
            * [2.和 notification(通知)的区别？](#2和-notification通知的区别)

# iOS开发---图解KVO

## 什么是KVO？

> `KVO` 全称 `Key Value Observing`，是苹果提供的一套事件通知机制。允许对象监听另一个对象特定属性的改变，并在改变时接收到事件。由于 `KVO` 的实现机制，只针对属性才会发生作用，一般继承自 `NSObject` 的对象都默认支持 `KVO`。
>
>  `KVO` 可以监听单个属性的变化，也可以监听集合对象的变化。通过 `KVC` 的 `mutableArrayValueForKey:` 等方法获得代理对象，当代理对象的内部对象发生改变时，会回调 `KVO` 监听的方法。集合对象包含 `NSArray` 和 `NSSet`。

## KVO基本使用

- 使用KVO大致分为三个步骤：

  1. 通过`addObserver:forKeyPath:options:context:`方法注册观察者，观察者可以接收`keyPath`属性的变化事件

  2. 在观察者中实现`observeValueForKeyPath:ofObject:change:context:`方法，当`keyPath`属性发生改变后，`KVO`会回调这个方法来通知观察者
  3. 当观察者不需要监听时，可以调用`removeObserver:forKeyPath:`方法将`KVO`移除。需要注意的是，调用`removeObserver`需要在观察者消失之前，否则会导致`Crash`

### 注册观察者

```objective-c
 /*
@observer:就是观察者，是谁想要观测对象的值的改变。
@keyPath:就是想要观察的对象属性。
@options:options一般选择NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld，这样当属性值发生改变时我们可以同时获得旧值和新值，如果我们只填NSKeyValueObservingOptionNew则属性发生改变时只会获得新值。
@context:想要携带的其他信息，比如一个字符串或者字典什么的。
*/
- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(nullable void *)context;
```

### 监听回调

```objective-c
/*
@keyPath:观察的属性
@object:观察的是哪个对象的属性
@change:这是一个字典类型的值，通过键值对显示新的属性值和旧的属性值
@context:上面添加观察者时携带的信息
*/
- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change context:(nullable void *)context;
```

### 调用方式

#### 自动调用

- 调用KVO属性对象时，不仅可以通过点语法和set语法进行调用，还可以使用KVC方法

```objective-c
//通过属性的点语法间接调用
objc.name = @"";

// 直接调用set方法
[objc setName:@"Savings"];
 
// 使用KVC的setValue:forKey:方法
[objc setValue:@"Savings" forKey:@"name"];
 
// 使用KVC的setValue:forKeyPath:方法
[objc setValue:@"Savings" forKeyPath:@"account.name"];
```

#### 手动调用

- KVO 在属性发生改变时的调用是自动的，如果想要手动控制这个调用时机，或想自己实现 KVO 属性的调用，则可以通过 KVO 提供的方法进行调用。

  1. 第一步我们需要认识下面这个方法，如果想要手动调用或自己实现KVO需要重写该方法该方法返回YES表示可以调用，返回NO则表示不可以调用。

  ```objective-c
  + (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey {
      BOOL automatic = NO;
      if ([theKey isEqualToString:@"name"]) {
          automatic = NO;//对该key禁用系统自动通知，若要直接禁用该类的KVO则直接返回NO；
      }
      else {
          automatic = [super automaticallyNotifiesObserversForKey:theKey];
      }
      return automatic;
  }
  ```

  2. 第二步我们需要重写setter方法

  ```objective-c
  - (void)setName:(NSString *)name {
      if (name != _name) {
          [self willChangeValueForKey:@"name"];
          _name = name;
          [self didChangeValueForKey:@"name"];
      }
  }
  ```

### 移除观察者

```objective-c
//需要在不使用的时候,移除监听
- (void)dealloc{
    [self removeObserver:self forKeyPath:@"age"];
}
```

### Crash

#### 观察者未实现监听方法

- 若观察者对象 **-observeValueForKeyPath:ofObject:change:context:** 未实现，将会 Crash

  > Crash：**Terminating app due to uncaught exception ‘NSInternalInconsistencyException’, reason: ‘<ViewController: 0x7f9943d06710>: An -observeValueForKeyPath:ofObject:change:context: message was received but not handled**

#### 未及时移除观察者

> Crash： Thread 1: EXC_BAD_ACCESS (code=1, address=0x105e0fee02c0)

```objective-c
//观察者ObserverPersonChage
@interface ObserverPersonChage : NSObject
  //实现observeValueForKeyPath: ofObject: change: context:
@end

//ViewController
- (void)addObserver
{
    self.observerPersonChange = [[ObserverPersonChage alloc] init];
    [self.person1 addObserver:self.observerPersonChange forKeyPath:@"age" options:option context:@"age chage"];
    [self.person1 addObserver:self.observerPersonChange forKeyPath:@"name" options:option context:@"name change"];
}

//点击按钮将观察者置为nil，即销毁
- (IBAction)clearObserverPersonChange:(id)sender {
    self.observerPersonChange = nil;
}

//点击改变person1属性值
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    self.person1.age = 29;
    self.person1.name = @"hengcong";
}
```

1. 假如在当前 ViewController 中，注册了观察者，点击屏幕，改变被观察对象 person1 的属性值。

2. 点击对应按钮，销毁观察者，此时 **self.observerPersonChange** 为 nil。

3. 再次点击屏幕，此时 Crash；

#### 多次移除观察者

> **Cannot remove an observer for the key path “age” from because it is not registered as an observer.**

### 实际应用

> `KVO`主要用来做键值观察操作，想要一个值发生改变后通知另一个对象，则用`KVO`实现最为合适。斯坦福大学的`iOS`教程中有一个很经典的案例，通过`KVO`在`Model`和`Controller`之间进行通信。

![](http://ww1.sinaimg.cn/large/006tNc79ly1g5q2t2h98cj30m50bv3zm.jpg)

## KVO实现原理

> `KVO`是通过isa 混写(`isa-swizzling`)技术实现的(是不是一脸懵逼？我第一次见和你一样，你现在只需要知道这个技术就行了，下面我会图文并茂的给你讲解到底是怎么回事。)。在运行时根据原类创建一个中间类，这个中间类是原类的子类，并动态修改当前对象的`isa`指向中间类。并且将`class`方法重写，返回原类的`Class`。所以苹果建议在开发中不应该依赖`isa`指针，而是通过`class`实例方法来获取对象类型。

#### 测试代码

```objective-c
NSKeyValueObservingOptions option = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;
    
NSLog(@"person1添加KVO监听对象之前-类对象 -%@", object_getClass(self.person1));
NSLog(@"person1添加KVO监听之前-方法实现 -%p", [self.person1 methodForSelector:@selector(setAge:)]);
NSLog(@"person1添加KVO监听之前-元类对象 -%@", object_getClass(object_getClass(self.person1)));
    
[self.person1 addObserver:self forKeyPath:@"age" options:option context:@"age chage"];
    
NSLog(@"person1添加KVO监听对象之后-类对象 -%@", object_getClass(self.person1));
NSLog(@"person1添加KVO监听之后-方法实现 -%p", [self.person1 methodForSelector:@selector(setAge:)]);
NSLog(@"person1添加KVO监听之后-元类对象 -%@", object_getClass(object_getClass(self.person1)));

//打印结果
KVO-test[1214:513029] person1添加KVO监听对象之前-类对象 -Person
KVO-test[1214:513029] person1添加KVO监听之前-方法实现 -0x100411470
KVO-test[1214:513029] person1添加KVO监听之前-元类对象 -Person
  
KVO-test[1214:513029] person1添加KVO监听对象之后-类对象 -NSKVONotifying_Person
KVO-test[1214:513029] person1添加KVO监听之后-方法实现 -0x10076c844
KVO-test[1214:513029] person1添加KVO监听之后-元类对象 -NSKVONotifying_Person
  
//通过地址查找方法
(lldb) p (IMP)0x10f24b470
(IMP) $0 = 0x000000010f24b470 (KVO-test`-[Person setAge:] at Person.h:15)
(lldb) p (IMP)0x10f5a6844
(IMP) $1 = 0x000000010f5a6844 (Foundation`_NSSetLongLongValueAndNotify)
```

- 通过测试代码，我们添加KVO前后发生以下变化
  1. `person`指向的`类对象`和`元类对象`，以及 `setAge:` 均发生了变化；
  2. 添加KVO后，`person` 中的 `isa` 指向了 **NSKVONotifying_Person** 类对象；
  3. 添加 KVO 之后，`setAge:` 的实现调用的是：Foundation 中 `_NSSetLongLongValueAndNotify` 方法；

#### 发现中间对象

> 从上述测试代码的结果我们发现，`person` 中的 `isa` 从开始指向`Person`类对象，变成指向了 **NSKVONotifying_Person** 类对象

- `KVO`会在运行时动态创建一个新类，将对象的`isa`指向新创建的类，新类是原类的子类，命名规则是`NSKVONotifying_xxx`的格式。

  1. 未使用KVO监听对象是，对象和类对象之间的关系如下

  ![](http://ww4.sinaimg.cn/large/006tNc79ly1g5q0s9e644j31700sugo1.jpg)

  2. 使用KVO监听对象后，对象和类对象之间会添加一个中间对象

  ![](http://ww4.sinaimg.cn/large/006tNc79ly1g5q0up2tybj317u0u0gq5.jpg)

##### NSKVONotifying_Person类内部实现

我们从上面两张图很清楚的看到添加KVO之前和KVO之后的变化，下面我们剖析一下这个中间类`NSKVONotifying_Person`（这里是` *`通配符,它代表数据类型，例如：int， longlong）

```objective-c
- (void)setAge:(int)age{
    _NSSet*ValueAndNotify();//这个方法调用顺序是什么，它是在调用何处方法，都在setter方法改变中详解
}

- (Class)class {
    return [LDPerson class];
}

- (void)dealloc {
    // 收尾工作
}

- (BOOL)_isKVOA {
    return YES;
}
```

- isa混写之后如何调用方法

  1. 调用**监听的属性设置方法**，如 `setAge:`，都会先调用 `NSKVONotify_Person` 对应的属性设置方法；

  2. 调用**非监听属性设置方法**，如 `test`，会通过 `NSKVONotify_Person` 的 `superclass`，找到 `Person` 类对象，再调用其 `[Person test]` 方法

- 为什么重写`class`方法

  - 如果没有重写`class`方法,当该对象调用`class`方法时,会在自己的方法缓存列表,方法列表,父类缓存,方法列表一直向上去查找该方法,因为`class`方法是`NSObject`中的方法,如果不重写最终可能会返回`NSKVONotifying_Person`,就会将该类暴露出来,也给开发者造成困扰,写的是`Person`,添加KVO之后`class`方法返回怎么是另一个类。

- _isKVOA有什么作用

  - 这个方法可以当做使用了`KVO`的一个标记，系统可能也是这么用的。如果我们想判断当前类是否是`KVO`动态生成的类，就可以从方法列表中搜索这个方法。

##### setter实现不同

- 在测试代码中，我们已经通过地址查找添加KVO前后调用的方法

- ```objective-c
  //通过地址查找方法
  //添加KVO之前
  (lldb) p (IMP)0x10f24b470
  (IMP) $0 = 0x000000010f24b470 (KVO-test`-[Person setAge:] at Person.h:15)
  //添加KVO之后
  (lldb) p (IMP)0x10f5a6844
  (IMP) $1 = 0x000000010f5a6844 (Foundation`_NSSetLongLongValueAndNotify)
  ```

  - `0x10f24b470`这个地址的`setAge:`实现是调用Person类的`setAge:`方法，并且是在Person.h的第15行。
  - 而`0x10f5a6844`这个地址的`setAge:`实现是调用`_NSSetIntValueAndNotify`这样一个C函数。

#### KVO内部调用流程

- 由于我们无法去窥探`_NSSetIntValueAndNotify`的真实结构，也无法去重写`NSKVONotifying_Person`这个类，所以我们只能利用它的父类Person类来分析其执行过程。

  ```objective-c
  - (void)setAge:(int)age{
      _age = age;
      NSLog(@"setAge:");
  }
  
  - (void)willChangeValueForKey:(NSString *)key{
      [super willChangeValueForKey:key];
      NSLog(@"willChangeValueForKey");
  }
  
  - (void)didChangeValueForKey:(NSString *)key{
      NSLog(@"didChangeValueForKey - begin");
      [super didChangeValueForKey:key];
      NSLog(@"didChangeValueForKey - end");
  }
  @end
    
  //打印结果
  KVO-test[1457:637227] willChangeValueForKey
  KVO-test[1457:637227] setAge:
  KVO-test[1457:637227] didChangeValueForKey - begin
  KVO-test[1457:637227] didChangeValueForKey - end
  KVO-test[1457:637227] willChangeValueForKey
  KVO-test[1457:637227] didChangeValueForKey - begin
  KVO-test[1457:637227] didChangeValueForKey - end
  ```

  - 通过打印结果，我们可以清晰看到

    1. 首先调用`willChangeValueForKey:`方法。 

    2. 然后调用`setAge:`方法真正的改变属性的值。

    3. 开始调用`didChangeValueForKey:`这个方法，调用`[super didChangeValueForKey:key]`时会通知监听者属性值已经改变，然后监听者执行自己的`- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context`这个方法。

- 下面我用一张图来展示KVO执行流程

  ![](http://ww2.sinaimg.cn/large/006tNc79ly1g5q2gj1h4sj31e60u0qa8.jpg)

## KVO扩展

#### 1.KVC 与 KVO 的不同？

- KVC(键值编码)，即 Key-Value Coding，一个非正式的 Protocol，使用字符串(键)访问一个对象实例变量的机制。而不是通过调用 Setter、Getter 方法等显式的存取方式去访问。
- KVO(键值监听)，即 Key-Value Observing，它提供一种机制,当指定的对象的属性被修改后,对象就会接受到通知，前提是执行了 setter 方法、或者使用了 KVC 赋值。

#### 2.和 notification(通知)的区别？

- `KVO` 和 `NSNotificationCenter` 都是 `iOS` 中观察者模式的一种实现。区别在于，相对于被观察者和观察者之间的关系，`KVO` 是一对一的，而不是一对多的。`KVO` 对被监听对象无侵入性，不需要修改其内部代码即可实现监听。

- notification 的优点是监听不局限于属性的变化，还可以对多种多样的状态变化进行监听，监听范围广，例如键盘、前后台等系统通知的使用也更显灵活方便。


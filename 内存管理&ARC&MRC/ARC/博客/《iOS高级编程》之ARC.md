# 什么是ARC

## 概述

- 实际上"引用计数式内存管理"的本质在ARC中并没有改变，ARC只是自动的帮助我们处理"引用计数"的相关部分
- 内存管理的思考方式在ARC也是相同的，只是在源码的实现方法与上述稍有不同

## 所有权修饰符

- OC中为了处理对象，可把变量类型定义为id类型或者各种对象类型

- 在使用这些对象时，需要我们附加上多有权修饰符，所有权修饰符一共有四种
  - __strong
  - __weak
  - __unsafe_unretained
  - __autoreleasing

### __strong修饰符 

- __strong修饰符是id类型和对象类型默认的所有权修饰符。也就是说，定义 一个变量实际上是附加了所有权修饰符

  ```objective-c
  id obj  = [[NSObject alloc] init]
    
  //在没有明确指定所有权修饰符时，默认为__strong
  id __strong obj = [[NSObject alloc] init];
  ```

  ```objective-c
  //在ARC无效时如何表示
  id obj = [[NSObject alloc] init];
  ```

  -  看似两种表示方法没有区别，我们再看看一下源码

    ```objective-c
    //ARC有效时
    {
      id __strong obj = [[NSObject alloc] init];
    }
    
    //ARC无效时
    {
      //变量    //对象
      id obj = [[NSObject allioc] init];
      [obj release];
    }
    //为了释放生成并持有的对象，增加了调用release方法
    ```

  - __strong修饰符表示对对象的强引用。持有强引用的变量在超出其作用域时被废弃，随着强引用的失效，引用的对象会随之释放。

#### ARC下自己生成并持有对象的源代码

```objective-c
 id __strong obj = [[NSObject alloc] init];

//源码实现如下
{
  //自己生成并持有对象
  id __strong obj = [[NSObject alloc] init];
  //因为变量obj为 强 引用，所以自己持有对象
}
//变量obj超出其作用域，强引用失效
//自动释放持有的object对象
//对象的所有者不存在，因此废弃该对象
```

#### ARC下非自己生成并持有的对象

```objective-c
id __strong obj = [[NSMutableArray alloc] init];

//源码实现如下
{
	//取得非自己生成并持有的对象
  id __strong obj = [[NSMutableArray alloc] init];
  //因为变量obj为强引用，所以自己持有对象
 
}
//因为变量超出其作用域，强引用失效
//所以自动释放自己持有的对象
//对象的所有者不存在，因此废弃该对象
```

#### __strong修饰符的变量之间相互赋值

```objective-c
id __strong obj0 = [[NSObject alloc] init];//对象A
//obj0持有对象A的强引用

id __strong  obj1 = [[NSObject alloc] init];//对象B
//obj1持有对象B的强应用

id __strong obj2 = nil;
//obj2不持有任何对象

obj0 = obj1;
//obj0持有由obj1持有的对象B的强引用
//因为obj0被赋值，所以原先持有对象A的强引用失效
//对象A的所有者不存在，因此废弃对象A
//此时，持有对象B的强引用的便利那个为obj0和obj1

obj2 = obj0;
//obj2持有由obj0持有对象B的强引用
//此时持有对象B的强引用的变量为obj0、obj1、obj2

obj1 = nil;
//因为nil被赋值给obj1，所以obj1对对象B的强引用失效
//此时，持有对象B的强引用的变量为obj0、obj2

obj0 = nil;
//因为nil被赋值给obj0，所以obj0对对象B的强引用失效
//此时，持有对象B的强引用的变量为obj2

obj2 = nil;
//因为nil被赋值给obj2，所以obj2对对象B的强引用失效
//此时对象B的所有者不存在，因此废弃对象B
```

- 通过上面发现，__strong修饰符的变量，不仅只在变量作用域中，在赋值上也能够正确的管理其对象的所有者

- 注意_strong修饰符和后面__weak修饰符和__autoreleasing修饰符一样，可以保证将附有这些修饰符的自动变量初始化为nil。

  ```objective-c
  id __strong obj0;
  id __weak obj1;
  id _autoreleasing obj2;
  
  //相当于
  id __strong obj0 = nil;
  id _weak obj1 = nil;
  id _autoreleasing obj2 = nil;
  ```

  - id类型和对象类型的所有权修饰符默认为_strong修饰符，所以不再需要写上"__strong"

### __weak修饰符

#### 循环引用

- 前面已经提出了_strong修饰符，按理说我们应该不需要别的修饰符了，但是__strong 修饰符会有一个重大问题，那就是循环应用问题
  - 循环引用容易发生内存泄漏，所谓<u>**内存泄漏就是应当废弃的对象在超出其生命周期后继续存在**</u>
  - 循环应用发生条件
    1. 两个对象互相强引用对方
    2. 在该对象持有其自身时（自己引用自己）

#### __weak

- 怎样才能避免循环应用，这个时候就提出了__weak修饰符,提供弱引用，不能持有对象实例

  ```objective-c
  id __weak obj = [[NSObject alloc] init];
  //这样编译，编译器会发出警告
  //发出警告原因：将自己生成并持有的对象赋值给附有__weak修饰符的变量obj，即变量obj不能持有对象，
  //因此，为了以自己不持有对象的状态来保存自己生成并持有的对象，生成的对象会立即被释放
  ```

- 如果想要把一个自己生成并持有的变量赋值给附有__weak修饰符的变量，按照一下方式就不会发生警告

  ```objective-c
  {
    id __strong obj0 = [[NSObject alloc] init];
  	id __weak obj1 = obj0;
  }
  
  //下面确定对象的持有状况
  {
    //自己生成并持有对象
  	id __strong objo = [[NSObject alloc] init];
    
    //因为obj0变量为强引用，所以自己持有对象
    
    id __weak obj1 = obj0;
    
    //obj1变量持有生成obj0的弱引用
  }
  
  //因为obj0变量超出其作用域，强引用失效，所以自动释放自己持有的对象，因为对象的所有者不存在，所以废弃该对象
  //因为带__weak修饰符的变量不持有对象，所以在超出其变量作用域时，对象即被释放。
  ```

- __weak修饰符还有另外一个优点，在持有某对象的弱引用时，若该对象被废弃，则此弱引用将自动失效且处于nil被赋值的状态

  ```objective-c
  id __weak obj1 = nil;
  {
    id __strong obj0 = [[NSObject alloc] init];
    obj1 = obj0;
    NSLog(@"A:%@", obj1);
  }
  NSLog(@"B:%@",obj1);
  
  //输出结果为：
  //A：<NSObject:0x.....>
  //B:(null)
  
  //下面确定对象的持有情况
  id __weak obj1 = nil;
  {
  	//自己生成并持有对象
    id __strong obj0 = [[NSObject alloc] init];
    
    //因为obj0变量为强引用，所以自己持有对象
    
    obj1 = obj0;
    
    //obj1对变量obj0持有弱引用
  }
  //因为obj0变量超出其作用域，强引用失效，所以自动释放自己持有的对象，因为对象无人持有，所以废弃该对象
  //废弃对象的同时，持有该对象弱引用的obj1变量的弱引用失效，nil赋值给obj1；
  ```

  - 使用__weak修饰符可避免循环引用，通过检查附有该修饰符的变量是否为nil，可以判断被赋值的对象是否已经废弃

### __unsafe_unretained修饰符

- 附有__unsafe_unretained修饰符的变量不属于编译器的内存管理，附有unsafe修饰符的变量同附有weak的修饰符变量一样，因为自己生成并持有的对象不能被自己持有，所以生成的对象会立马释放。看起来unsafe和weak是一样的，让我们来看看unsafe的源码

  ```objective-c
  id __unsafe_unretained obj1 = nil;
  {
    //自己生成并持有对象
    id __strong obj0 = [[NSObject alloc] init];
    
    //因为obj0变量的强引用，所以自己持有对象
    
    obj1 = obj0;
    //虽然obj0变量赋值给obj1，但是obj1变量既不持有对象的强引用也不持有弱引用
  }
  
  //因为obj0变量超出了其作用域，强引用失效，所以自动释放自己持有的对象，因为对象无持有者，所以对象被废弃
  NSLog(@"%@", obj1);
  //因为obj1变量表示的对象已经被废弃（悬垂指针）错误访问！！！！！！
  ```

  - 虽然访问了已经废弃的对象，但是应用程序在个别运行状况下会崩溃

### __autoreleasing修饰符

#### ARC有效修饰符和ARC无效方法比较

- ARC有效时，不能使用autoreleasing方法，另外，也不能使用NSAutoreleasePool类。

  ```objective-c
  //在ARC无效时
  
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  id obj = [[NSObject alloc] init];
  [obj autorelease];
  [pool drain];
  
  //ARC有效时
  @autoreleasepool {
    id __autoreleasing obj = [[NSObject alloc] init];
  }
  ```

  - 指定@autoreleasepool块代替”NSAutoreleasePool类对象生成、持有以及废弃"
  - 附有__autoreleasing修饰符的变量替代autorelease方法

#### 非显示使用__autoreleasing修饰符

##### 通过方法名使用

- 编译器会检查方法名是否以alloc/new/copy/mutableCopy开始，如果不是则自动将返回值的对象注册到autoreleasepool中
  - init方法返回值的对象不注册到autoreleasepool

  ```objective-c
  @autoreleasepool {
  	id __strong obj = [NSMutable array];
  }
  
  //对象持有分析
  @autoreleasepool {
    //取得非自己生成并持有的对象
    id __strong obj = [NSMutable array];
    //因为变量obj为强引用，所以自己持有对象，并且该对象由编译器判断其方法名后自动注册到autoreleasepool中
  }
  //因为变量obj超出其作用域，强引用失效
  //所以自动释放自己持有的对象
  
  //同时，随着@autoreleasepool块的结束，注册到autoreleasepool中的所有对象自动被释放
  //因为对象的所有者不存在，所以废弃对象
  ```

  - 像这样不使用__autoreleasing修饰符也能把对象注册到auto release pool，以下为非自己生成并持有对象时源码示例

  ```objective-c
  + (id)array {
    id obj = [[NSMutable alloc] init];
    return obj;
  }
  
  //因为没有显示指定所有权修饰符，所以id obj同附有__strong修饰符的id __strong obj是完全一样的。由于return使得对象变量超出其作用域，所以该强引用对应自己持有的对象会被自动释放，但该对象作为函数的返回值，编译器会自动将其注册到autoreleasepool中
  ```

##### 访问附有__weak修饰变量时

- 虽然__weak修饰符实为了避免循环引用而使用的，但在访问附有weak修饰符的变量时，实际上必定要访问注册到autoreleasepool的对象

  ```objective-c
  id __weak obj1 = obj0;
  
  //在源码中
  id __weak obj1 = obj0;
  id __autoreleaseing tmp = obj1;
  
  //为什么访问附有__weak修饰符的变量时必须访问注册到aotoreleasepool的对象呢？这是因为__weak修饰符只持有对象的弱引用，而在访问引用对象的过程中，该对象有可能被废弃。如果要把访问的对象注册到autoreleasepool中，那么在@autoreleasepool块结束前都能确保该对象存在。
  ```

  #### id的指针id *obj类型

  ```objective-c
  //同前面讲述的id obj和id __strong obj 完全一样，那么id指针id *obj可以由id __strong *obj的例子推出吗？其实，推出来的是id __autoreleasing *obj
  //同样，对象的指针NSObject **obj便成为了NSObject *__autoreleasing *obj
  ```
  
  - 作为alloc/new/copy/mutableCopy方法返回值取得的对象是自己生成并持有的，其他情况下便是取得非自己生成并持有的对象。使用附有__autoreleasing修饰符的变量作为对象取得参数，与除alloc/new/copy/mutableCopy外其他方法的返回值取得对象完全一样，都会注册到autoreleasepool，并取得非自己生成并持有的对象。
  
- 赋值给对象指针时，所有权修饰符必须一致

  ```objective-c
  //这种形式时错误的
  NSError *error = nil;
  NSError **pError = &error;
  //因为error默认的修饰符是__strong,而pError默认的修饰符__autoreleaseing，所以会发生错误
  
  //所以赋值给对象指针，所有权修饰符必须一致
  //就像下面这种
  NSError *error = nil;
  NSError *__strong *pErroe = &error;
  ```

#### @autoreleasepool

- 在ARC无效时，可以将NSAutoreleasePool对象嵌套使用，同样的，@autoreleasepool块也能够嵌套使用
- 推荐不管ARC是否有效，都可以使用@autoreleasepool块

## ARC规则

- 不能使用retain/release/retainCount/autorelease
- 不能使用NSAllocateObject/NSDeallocateObject
- 须遵守内存管理的方法命名规则
- 不要显示调用dealloc
- 使用@autoreleasepool块代替NSAutoreleasePool类
- 不能使用区域（NSZone）
- 对象型变量不能作为c语言结构体成员
- 显示转换id和void *

####  init方法

- 以init开始的方法都必须是实例方法，并且必须要返回对象，返回对象应为id类型或该方法声明类的对象类型，该返回对象并不注册到autoreleasepool上，基本上只是对alloc方法返回值的对象进行初始化处理并返回该对象。

#### 显示转换id和void*

- id型或对象型变量赋值给void*后者逆向赋值时都需要进行特定的转换。如果只想**单纯地赋值**，则可以使用"__bridge转换"

  ```objective-c
  id obj = [[NSObject alloc] init];
  
  void *p = (__bridge void *)obj;
  
  id o = (__bridge id)p;
  
  //但是转换为void*的__bridge转换，其安全性与赋值给__unsafe_unretained修饰符相近，甚至会更低。如果管理时不注意赋值对象的所有者，就会因悬垂指针而导致程序崩溃
  ```

  1. __bridge_retained转换

     ```objective-c
     id obj = [[NSObject alloc] init];
     void *p = (__bridge_retained void *)obj;
     
     //__bridge_retained转换可使要转换赋值的变量也持有赋值的对象
     ```

  2. __bridge_transfer转换

     ```objective-c
     id obj = (__bridge_transfer id)p;
     
     //__bridge_transfer被转换的变量所持有的对象在该变量被赋值给转换目标变量后随之释放
     ```
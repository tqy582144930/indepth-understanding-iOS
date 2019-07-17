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

- 附有__unsafe_unretained修饰符的变量不属于编译器的内存管理对象
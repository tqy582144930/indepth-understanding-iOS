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


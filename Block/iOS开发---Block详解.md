[TOC]

# iOS开发---Block详解

## Block的基础

### 什么是Blocks？

- 用一句话来描述：**带有自动变量的匿名函数**（是不是一脸懵逼，不要担心，整篇博客都会围绕这句话展开）顾名思义：`Block`没有函数名，另外`Block`带有"`^`"标记,插入记号便于查找到`Block`
- `Blocks` 也被称作**闭包**、**代码块**。展开来讲，`Blocks`就是一个代码块，把你想要执行的代码封装在这个代码块里，等到需要的时候再去调用。
- `Block` 共享局部作用域的数据。`Block` 的这项特征非常有用，因为如果您实现一个方法，并且该方法定义一个块，则该块可以访问该方法的局部变量和参数（包括堆栈变量），以及函数和全局变量（包括实例变量）。这种访问是只读的，但如果使用 `__block` 修饰符声明变量，则可在 `Block` 内更改其值。即使包含有块的方法或函数已返回，并且其局部作用范围已销毁，但是只要存在对该块的引用，局部变量仍作为块对象的一部分继续存在。

### Blocks的语法

- `Block`的完整语法格式如下：

```objective-c
^ returnType (argument list) {
  expressions
}
```

用一张图来表示

![Block语法](https://tva1.sinaimg.cn/large/006y8mN6ly1g756lmtruej30vo0braau.jpg)

- 也可以写省略格式的`Block`,比如省略返回值类型：

```objective-c
^ (int x) {
  return x;
}
```

> `Block`省略返回值类型时，如果表达式中有return语句就使用该返回值的类型，没有return语句就使用`void`类型。

- 如果没有参数列表，也可以省略参数列表：

```objective-c
^ {
  NSLog(@"hello world");
}
```

- 与c语言的区别
  1. 没有函数名
  2. 带有"^"符号

### Block类型变量

- `Block`类型变量与一般的`C`语言变量完全相同，可以作为自动变量，函数参数，静态变量，全局变量使用
- C语言函数将是如何将所定义的函数的地址赋值给函数指针类型变量中

```objective-c
int func (int count)
{
    return count + 1;
}

int (*funcptr) (int) = &func;
```

- 使用`Block`语法就相当于生成了可赋值给`Block`类型变量的值。

```objective-c
//Blocks 变量声明与赋值
int (^blk) (int) = ^int (int count) {
    return count + 1;
};
//把Block语法生成的值赋值给Block类型变量
int (^myBlock)(int) = blk; 
```

> 与前面的使用函数指针的源代码对比可知，声明`Block`类型变量仅仅是**将声明函数指针类型变量的"*"变为 “^”**

- 在函数返回值中指定`Block`类型，可以将`Block`作为函数的返回值返回。

```objective-c
int (^func()(int)) {
    return ^(int count){
        return count + 1;
  	}
}
```

### Block在oc中的使用

- 通过`property`声明成员变量:`@property (nonatomic, copy) 返回值类型 (^变量名) (参数列表);`

```objective-c
@property (nonatomic, copy) void (^callBack) (NSString *);

- (void)useBlock {
  self.callBack = ^ (NSString *str){
    NSLog(@"useBlock %@", str);
  };
  self.callBack(@"hello world");
}
```

- 作为方法参数：`- (void)someMethodThatTaksesABlock:(返回值类型 (^)(参数列表)) 变量名;`

```objective-c
- (void)callBackAsAParameter:(void (^)(NSString *print))callBack {
  callBack(@"i am alone");
}

//调用该函数
[self callbackAsAParameter:^(NSString *print) {
    NSLog(@"here is %@",print);
}];
```

- 通过typedef定义变量类型

```objective-c
//typedef 返回值类型 (^声明名称)(参数列表);
//声明名称 变量名 = ^返回值类型(参数列表) { 表达式 };
typedef void (^callBlock)(NSSting *);

callBlock block = ^(NSString *str) {
  NSLog(@"%@", str);
}
```

与上一个知识点中指定Block为函数返回值对比

```objective-c
//原来的记述方式
void func(void (^blk)(NSString 8))
//用了 typedef 定义后的记述方式
void func(callBlock blk)

//原来的记述方式
void (^func()(NSString *)) 
//用了 typedef 定义后的记述方式
callBlock func()
```

### Block截取变量

#### 截获自动变量的值

- 我们先看一个🌰

```objective-c
// 使用 Blocks 截获局部变量值
- (void)useBlockInterceptLocalVariables {
    int a = 10, b = 20;

    void (^myLocalBlock)(void) = ^{
        printf("a = %d, b = %d\n",a, b);
    };

    myLocalBlock();    // 打印结果：a = 10, b = 20

    a = 20;
    b = 30;

    myLocalBlock();    // 打印结果：a = 10, b = 20
}
```

为什么两次打印结果都是 `a = 10, b = 20`？

明明在第一次调用 `myLocalBlock();`之后已经重新给变量 a、变量 b 赋值了，为什么第二次调用 `myLocalBlock();`的时候，使用的还是之前对应变量的值？

因为 `Block` 语法的表达式使用的是它之前声明的局部变量` a`、变量 `b`。`Blocks` 中，`Block` 表达式截获所使用的局部变量的值，保存了该变量的瞬时值。所以在第二次执行 `Block` 表达式时，即使已经改变了局部变量 `a` 和 `b` 的值，也不会影响 `Block` 表达式在执行时所保存的局部变量的瞬时值。

这就是 `Blocks` 变量截获局部变量值的特性。

#### 通过__block说明符赋值

- 上面我们想修改变量`a`，变量`b`的值，但是有没有成功，那么我们难道就没有方法来修改了么？别急，`__block`来也，只要用这个说明符修饰变量，就可以在块中修改。

```objective-c
// 使用 __block 说明符修饰，更改局部变量值
- (void)useBlockQualifierChangeLocalVariables {
    __block int a = 10, b = 20;
    void (^myLocalBlock)(void) = ^{
        a = 20;
        b = 30;
        printf("a = %d, b = %d\n",a, b);  // 打印结果：a = 20, b = 30
    };
    
    myLocalBlock();
}
```

可以看到，使用`__block`说明符修饰之后，我们在 `Block`表达式中，成功的修改了局部变量值。

使用`__block`修饰符的自动变量被称为`__blcok`变量

## Block的实现

> 在上一部分我们知道了`Blocks`是 **带有局部变量的匿名函数**。但是 Block 的实质究竟是什么呢？类型？变量？
>
> 要想了解 Block 的本质，就需要从 Block 对应的 C++ 源码来入手。
>
> 下面我们通过一步步的源码剖析来了解 Block 的本质。

### Block的实质是什么？

#### 准备工作

1. 在项目中添加 `blocks.m` 文件，并写好 `block` 的相关代码。
2. 打开『终端』，执行 `cd XXX/XXX` 命令，其中 `XXX/XXX` 为`block.m`所在的目录。
3. 继续执行`clang -rewrite-objc block.m`
4. 执行完命令之后，`block.m` 所在目录下就会生成一个`block.cpp`文件，这就是我们需要的 `block` 相关的 `C++ `源码。

#### Block源码预览

- 转换前OC代码：

```objective-c
int main () {
    void (^myBlock)(void) = ^{
        printf("myBlock\n");
    };
    myBlock();
    return 0;
}
```

- 转换后c++代码：

```objective-c
/* 包含 Block 实际函数指针的结构体 */
struct __block_impl {
    void *isa;
    int Flags;               
    int Reserved;       // 今后版本升级所需的区域大小
    void *FuncPtr;      // 函数指针
};

/* Block 结构体 */
struct __main_block_impl_0 {
    // impl：Block 的实际函数指针，指向包含 Block 主体部分的 __main_block_func_0 结构体
    struct __block_impl impl;
    // Desc：Desc 指针，指向包含 Block 附加信息的 __main_block_desc_0（） 结构体
    struct __main_block_desc_0* Desc;
    // __main_block_impl_0：Block 构造函数
    __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int flags=0) {
        impl.isa = &_NSConcreteStackBlock;
        impl.Flags = flags;
        impl.FuncPtr = fp;
        Desc = desc;
    }
};

/* Block 主体部分结构体 */
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
    printf("myBlock\n");
}

/* Block 附加信息结构体：包含今后版本升级所需区域大小，Block 的大小*/
static struct __main_block_desc_0 {
    size_t reserved;      // 今后版本升级所需区域大小
    size_t Block_size;    // Block 大小
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)};

/* main 函数 */
int main () {
  	//myBlock的初始化
    void (*myBlock)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA));
  	//myBlock的调用
    ((void (*)(__block_impl *))((__block_impl *)myBlock)->FuncPtr)((__block_impl *)myBlock);

    return 0;
}
```

下面我们一步一步来拆解转换后的源码

##### Block结构体

- 我们先来看看 `__main_block_impl_0` 结构体（ Block 结构体）

```objective-c
/* Block 结构体 */
struct __main_block_impl_0 {
    // impl：Block 的实际函数指针，指向包含 Block 主体部分的 __main_block_func_0 结构体
    struct __block_impl impl;
    // Desc：Desc 指针，指向包含 Block 附加信息的 __main_block_desc_0（） 结构体
    struct __main_block_desc_0* Desc;
    // __main_block_impl_0：Block 构造函数
    __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int flags=0) {
        impl.isa = &_NSConcreteStackBlock;
        impl.Flags = flags;
        impl.FuncPtr = fp;
        Desc = desc;
    }
};
```

从上边我们可以看出，`__main_block_impl_0` 结构体**（Block 结构体）**包含了三个部分：

1. 成员变量 `impl`;
2. 成员变量 `Desc` 指针;
3. `__main_block_impl_0` 构造函数。

##### `struct __block_impl` 结构

> 我们先看看第一部分`impl`是 `__block_impl`结构体类型的成员变量

```objective-c
/* 包含 Block 实际函数指针的结构体 */
struct __block_impl {
    void *isa;          // 用于保存 Block 结构体的实例指针
    int Flags;          // 标志位
    int Reserved;       // 今后版本升级所需的区域大小
    void *FuncPtr;      // 函数指针
};
```

- `__block_impl`包含了 Block 实际函数指针 `FuncPtr`，`FuncPtr`指针指向 Block 的主体部分，也就是 Block 对应 OC 代码中的 `^{ printf("myBlock\n"); };`部分。
- 还包含了标志位 `Flags`，在实现`block`的内部操作时会用到
- 今后版本升级所需的区域大小 `Reserved`
- `__block_impl`结构体的实例指针 `isa`。

##### `static struct __main_block_desc_0`结构

> 第二部分 Desc 是指向的是 `__main_block_desc_0` 类型的结构体的指针型成员变量，`__main_block_desc_0` 结构体用来描述该 Block 的相关附加信息：

```objective-c
/* Block 附加信息结构体：包含今后版本升级所需区域大小，Block 的大小*/
static struct __main_block_desc_0 {
    size_t reserved;      // 今后版本升级所需区域大小
    size_t Block_size;  // Block 大小
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)};
```

##### `__main_block_impl_0` 构造函数

> 第三部分是 `__main_block_impl_0` 结构体（Block 结构体） 的构造函数，负责初始化 `__main_block_impl_0` 结构体（Block 结构体） 的成员变量。

```objective-c
__main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int flags=0) {
    impl.isa = &_NSConcreteStackBlock;
    impl.Flags = flags;
    impl.FuncPtr = fp;
    Desc = desc;
}
```

- 关于结构体构造函数中对各个成员变量的赋值，我们需要先来看看 `main()`函数中，对该构造函数的调用。

```objective-c
  void (*myBlock)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA));
```

- 我们可以把上面的代码稍微转换一下，去掉不同类型之间的转换，使之简洁一点：

```objective-c
struct __main_block_impl_0 temp = __main_block_impl_0(__main_block_func_0, &__main_block_desc_0_DATA);
struct __main_block_impl_0 *myBlock = &temp;
```

- 这样，就容易看懂了。该代码将通过 `__main_block_impl_0`构造函数，生成的 `__main_block_impl_0`结构体（Block 结构体）类型实例的指针，赋值给 `__main_block_impl_0`结构体（Block 结构体）类型的指针变量 `myBlock`。

可以看到， 调用 `__main_block_impl_0`构造函数的时候，传入了两个参数。

1. 第一个参数：`__main_block_func_0`。

   - 其实就是 `Block` 对应的主体部分，可以看到下面关于 `__main_block_func_0`结构体的定义 ，和` OC` 代码中 `^{ printf("myBlock\n"); };`部分具有相同的表达式。
   - 这里参数中的 `__cself`是指向 Block 的值的指针变量，相当于 `OC` 中的 `self`。

   ```objective-c
   /* Block 主体部分结构体 */
   static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
       printf("myBlock\n");
   }
   ```

2. 第二个参数：`__main_block_desc_0_DATA`：`__main_block_desc_0_DATA`包含该 Block 的相关信息。
   我们再来结合之前的 `__main_block_impl_0`结构体定义。

   - `__main_block_impl_0`结构体（Block 结构体）可以表述为：

   ```objective-c
   struct __main_block_impl_0 {
       void *isa;          // 用于保存 Block 结构体的实例指针
       int Flags;          // 标志位
       int Reserved;       // 今后版本升级所需的区域大小
       void *FuncPtr;      // 函数指针
       struct __main_block_desc_0* Desc;      	// Desc：Desc 指针
   };
   ```

   - `__main_block_impl_0`构造函数可以表述为：

   ```objective-c
   impl.isa = &_NSConcreteStackBlock;     // isa 保存 Block 结构体实例
   impl.Flags = 0;        // 标志位赋值
   impl.FuncPtr = __main_block_func_0;    // FuncPtr 保存 Block 结构体的主体部分
   Desc = &__main_block_desc_0_DATA;      // Desc 保存 Block 结构体的附加信息
   ```

##### 调用

> 在分析了Block结构体和成员变量，现在我们看看main函数中是如何调用block的

```objective-c
((void (*)(__block_impl *))((__block_impl *)myBlock)->FuncPtr)((__block_impl *)myBlock);
```

- `myBlock`结构体的第一个成员变量为`__block_impl`，所以`myBlock`首地址，就是`__block_impl impl` 的首地址，即可以直接转换为`__block_impl` 类型
- **(void (\*)(__block_impl \*))** 是`__block_impl` 中 `Func` 的类型
- **((__block_impl \*)myBlock)->FuncPtr()** 调用函数
- **((__block_impl \*)myBlock)** 函数参数

##### Block的实质总结

> 用一句话来说，Block是个对象

- 在C语言的底层实现里，它是一个结构体。这个结构体相当于`objc_class`的类对象结构体，用`_NSConcreteStackBlock`对其中成员变量`isa`初始化，`_NSConcreteStackBlock`相当于`class_t`结构体实例(在我的理解中就是该 `block` 实例的元类)。在将 `Block` 作为`OC`对象处理时，关于该类的信息放置于`_NSConcreteStackBlock`中。

> - 是对象：其内部第一个成员为 `isa` 指针；
> - 封装了函数调用：`Block`内代码块，封装了函数调用，调用`Block`，就是调用该封装的函数；
> - 执行上下文：`Block` 还有一个描述 `Desc`，该描述对象包含了`Block`的信息以及捕获变量的内存相关函数，及`Block`所在的环境上下文；

### Block的类型

> 前面已经说过了，Block的本质就是一个OC对象，既然它是OC对象，那么它就有类型。
>
> 准备工作：
>
> - 先把ARC关掉，因为ARC帮我们做了太多的事，不方便我们观察结果。关掉ARC的方法在Build Settings里面搜索Objective-C Automatic Reference Counting，把这一项置为NO。

```objective-c
static int weight = 20;

int main(int argc, char * argv[]) {
    @autoreleasepool {
        int age = 10;
        void (^block)(void) = ^{
            NSLog(@"%d %d", height, age);
        };
        
        NSLog(@"%@\n %@\n %@\n %@", [block class], [[block class] superclass], [[[block class] superclass] superclass], [[[[block class] superclass] superclass] superclass]);
        
        return 0;
    }
}

//打印结果
 __NSStackBlock__
 __NSStackBlock
 NSBlock
 NSObject
```

- 这说明上面定义的这个`block`的类型是`NSStackBlock`，并且它最终继承自`NSObject`也说明`Block`的本质是`OC`对象。

#### Block的三种类型

- **Block有三种类型，分别是NSGlobalBlock,MallocBlock,NSStackBlock。**
  这三种类型的`Block`对象的存储区域如下：

| 类                                      | 对象的存储域            |
| --------------------------------------- | ----------------------- |
| NSStackBlock（_NSConcreteStackBlock）   | 栈                      |
| NSGlobalBlock（_NSConcreteGlobalBlock） | 程序的数据区域(.data区) |
| NSMallocBlock（_NSConcreteMallocBlock） | 堆                      |

> **截获了自动变量的Block是NSStackBlock类型，没有截获自动变量的Block则是NSGlobalStack类型,NSStackBlock类型的Block进行copy操作之后其类型变成了NSMallocBlock类型。**

- 下面我们用一张图来看一下不同block的存储区域

![Block的存储区域](https://tva1.sinaimg.cn/large/006y8mN6ly1g7ay95zsxrj30ko0frq5d.jpg)

- 从上图可以发现，根据`block`的类型不同，block存放在不同的区域中。
  1. 数据段中的`__NSGlobalBlock__`直到程序结束才会被回收，不过我们很少使用到`__NSGlobalBlock__`类型的`block`，因为这样使用`block`并没有什么意义。
  2. `__NSStackBlock__`类型的`block`存放在栈中，我们知道栈中的内存由系统自动分配和释放，作用域执行完毕之后就会被立即释放，而在相同的作用域中定义`block`并且调用`block`似乎也多此一举。
  3. `__NSMallocBlock__`是在平时编码过程中最常使用到的。存放在堆中需要我们自己进行内存管理。

1. **_NSConcreteGlobalBlock**

   - 在以下两种情况下使用 `Block` 的时候，`Block` 为 `NSConcreteGlobalBlock`类对象。

   1. 记述全局变量的地方，使用 `Block` 语法时；
   2. `Block` 语法的表达式中没有截获的自动变量时。

   - `NSConcreteGlobalBlock`类的 `Block` 存储在**『程序的数据区域』**。因为存放在程序的数据区域，所以即使在变量的作用域外，也可以通过指针安全的使用。

   - 记述全局变量的地方，使用 Block 语法示例代码：

   ```objective-c
   void (^myGlobalBlock)(void) = ^{
       printf("GlobalBlock\n");
   };
   
   int main() {
       myGlobalBlock();
   
       return 0;
   }
   ```

   通过对应 `C++` 源码，我们可以发现：`Block` 结构体的成员变量 `isa`赋值为：`impl.isa = &_NSConcreteGlobalBlock;`，说明该 `Block` 为 `NSConcreteGlobalBlock`类对象。

2. **_NSConcreteStackBlock**

除了**_NSConcreteGlobalBlock**中提到的两种情形，其他情形下创建的 `Block` 都是 `NSConcreteStackBlock`对象，平常接触的 `Block` 大多属于 `NSConcreteStackBlock`对象。

`NSConcreteStackBlock`类的 `Block` 存储在『栈区』的。如果其所属的变量作用域结束，则该 Block 就会被废弃。如果 Block 使用了 `__block`变量，则当 `__block`变量的作用域结束，则 `__block`变量同样被废弃。

![栈上Block随着作用域结束而废弃](https://tva1.sinaimg.cn/large/006y8mN6ly1g7azdcvz6pj31ty0sok3o.jpg)

3. **_NSConcreteMallocBlock**

为了解决栈区上的 `Block` 在变量作用域结束被废弃这一问题，`Block` 提供了 **『复制』**功能。可以将 Block 对象和 `__block`变量从栈区复制到堆区上。当 `Block` 从栈区复制到堆区后，即使栈区上的变量作用域结束时，堆区上的 `Block` 和 `__block`变量仍然可以继续存在，也可以继续使用。

![Block从栈复制到堆](https://tva1.sinaimg.cn/large/006y8mN6ly1g7azh00rhcj31b40u0api.jpg)

此时，『堆区』上的 Block 为 `NSConcreteMallocBlock` 对象，Block 结构体的成员变量 isa 赋值为：`impl.isa = &_NSConcreteMallocBlock;`

那么，什么时候才会将 Block 从栈区复制到堆区呢？

这就涉及到了 Block 的自动拷贝和手动拷贝。

#### Block的自动拷贝和手动拷贝

##### Block的自动拷贝

在使用` ARC` 时，大多数情形下编译器会自动进行判断，自动生成将 `Block` 从栈上复制到堆上的代码：

1. 将 `Block` 作为函数返回值返回时，会自动拷贝；
2. 向方法或函数的参数中传递 `Block` 时，使用以下两种方法的情况下，会进行自动拷贝，否则就需要手动拷贝：
   1. `Cocoa` 框架的方法且方法名中含有 `usingBlock`等时；
   2. `Grand Central Dispatch（GCD）`的 API。

##### Block的手动拷贝

我们可以通过『copy 实例方法（即 `alloc / new / copy / mutableCopy`）』来对 `Block` 进行手动拷贝。当我们不确定 `Block` 是否会被遗弃，需不需要拷贝的时候，直接使用 `copy` 实例方法即可，不会引起任何的问题。

关于 Block 不同类的拷贝效果总结如下：

|        Block 类        |    存储区域    |   拷贝效果   |
| :--------------------: | :------------: | :----------: |
| _NSConcreteStackBlock  |      栈区      | 从栈拷贝到堆 |
| _NSConcreteGlobalBlock | 程序的数据区域 |   不做改变   |
| _NSConcreteMallocBlock |      堆区      | 引用计数增加 |

##### __block变量的拷贝

在使用 `__block`变量的 `Block` 从栈复制到堆上时，`__block`变量也会受到如下影响：

| __block 变量的配置存储区域 |   Block 从栈复制到堆时的影响    |
| :------------------------: | :-----------------------------: |
|            堆区            | 从栈复制到堆，并被 Block 所持有 |
|            栈区            |         被 Block 所持有         |

当然，如果不再有 `Block` 引用该 `__block`变量，那么 `__block`变量也会被废除。

### Block截获变量实质

我们下面见根据变量修饰符，来探查 Block 如何捕获不同修饰符的类型变量。

- auto：自动变量修饰符
- static：静态修饰符
- const：常量修饰符

在这三种修饰符，我们又细分为**全局变量和局部变量**。

#### Block截获自动局部变量的实质

```objective-c
// 使用 Blocks 截获局部变量值
int c = 30;//全局变量
- (void)useBlockInterceptLocalVariables {
    int a = 10, b = 20;//局部变量

    void (^myLocalBlock)(void) = ^{
        printf("a = %d, b = %d, c = %d\n",a, b， c);
    };
  	void (^Block)(int, int, int) = ^(int a, int b, int c){
        printf("a = %d, b = %d, c = %d\n",a, b, c);
    };

    myLocalBlock();    // 输出结果：a = 10, b = 20, c = 30

    a = 20;
    b = 30;

    myLocalBlock();    // 输出结果：a = 10, b = 20, c = 30
  	Block(a, b, c);				 // 输出结果：a = 20, b = 30, c = 30
}
```

##### Block块中直接调用局部变量

- 从中我们可以看出，我们在第一次调用 `myLocalBlock();` 之后已经重新给变量 `a`、变量 `b` 赋值了，但是第二次调用 `myLocalBlock();` 的时候，使用的还是之前对应变量的值。

> 这是因为Block 语法的表达式使用的是它之前申明的局部变量`a`、变量`b`。Blocks中，Block表达式截获所使用的局部变量的值，保存了该变量的瞬时值。所以再第二次执行Block表达式的时候，即使已经改变了局部变量`a`和`b`的值，也不会影响Block表达式在执行时所保存的局部变量的瞬时值。
>
> 这就是Block变量截获局部变量值的特性

- ⚠️：`Block` 语法表达式中没有使用的自动变量不会被追加到结构体中，`Blocks` 的自动变量截获只针对 `Block` 中**使用的**自动变量。

- 可是，**为什么 Blocks 变量使用的是局部变量的瞬时值，而不是局部变量的当前值呢？**让我们看一下对应的`C++`代码

```objective-c
struct __main_block_impl_0 {
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
    int a;
    int b;
    __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int _a, int _b, int flags=0) : a(_a), b(_b) {
        impl.isa = &_NSConcreteStackBlock;
        impl.Flags = flags;
        impl.FuncPtr = fp;
        Desc = desc;
    }
};
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
    int a = __cself->a; // bound by copy
    int b = __cself->b; // bound by copy

    printf("a = %d, b = %d, c = %d\n",a, b, c);
}

static struct __main_block_desc_0 {
    size_t reserved;
    size_t Block_size;
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)};


int main () {
    int a = 10, b = 20;

    void (*myLocalBlock)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, a, b));
    ((void (*)(__block_impl *))((__block_impl *)myLocalBlock)->FuncPtr)((__block_impl *)myLocalBlock);

    a = 20;
    b = 30;

    ((void (*)(__block_impl *))((__block_impl *)myLocalBlock)->FuncPtr)((__block_impl *)myLocalBlock);
}
```

1. 可以看到 `__main_block_impl_0` 结构体（Block 结构体）中多了两个成员变量 `a` 和 `b`，这两个变量就是 Block 截获的局部变量。 `a` 和 `b` 的值来自与 `__main_block_impl_0` 构造函数中传入的值。

```objective-c
  struct __main_block_impl_0 {
        struct __block_impl impl;
        struct __main_block_desc_0* Desc;
        int a;    // 增加的成员变量 a
        int b;    // 增加的成员变量 b
        __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int _a, int _b, int flags=0) : a(_a), b(_b) {    
            impl.isa = &_NSConcreteStackBlock;
            impl.Flags = flags;
            impl.FuncPtr = fp;
            Desc = desc;
        }
    };
```

2. `还可以看出 __main_block_func_0`（保存 `Block` 主体部分的结构体）中，变量 `a、b` 的值使用的 `__cself `获取的值。
   而 `__cself->a`、`__cself->b` 是通过值传递的方式传入进来的，而不是通过指针传递。这也就说明了 `a`、`b` 只是 `Block` 内部的变量，改变 `Block` 外部的局部变量值，并不能改变 `Block` 内部的变量值。

```objective-c
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
    int a = __cself->a; // bound by copy
    int b = __cself->b; // bound by copy
    printf("a = %d, b = %d\n",a, b);
}
```

3. 我们可以看出全局变量并没有存储在Block的结构体中，而是在调用的时候通过直接访问的方式来调用。

- 下面用一张图我们把上面所说的全局作用域和局部作用域做一个总结

| 变量类型 | 抓获到Block对象内部 | 访问方式 |
| :------: | :-----------------: | :------: |
| 局部变量 |                     |  指传递  |
| 全局变量 |                     | 直接访问 |

##### Block通过传值间接访问局部变量

```objective-c
// 使用 Blocks 截获局部变量值
int c = 30;
- (void)useBlockInterceptLocalVariables {
    int a = 10, b = 20;

  	void (^Block)(void) = ^(int a, int b){
        printf("a = %d, b = %d\n",a, b);
    };

    a = 20;
    b = 30;
  	Block(a,b);				 // 输出结果：a = 20, b = 30, c = 30
}
```

- 我们来看看直接传值和通过`block`截获局部变量的区别

```objective-c
struct __main_block_impl_1 {
    struct __block_impl impl;
    struct __main_block_desc_1* Desc;
    __main_block_impl_1(void *fp, struct __main_block_desc_1 *desc, int flags=0) {
        impl.isa = &_NSConcreteStackBlock;
        impl.Flags = flags;
        impl.FuncPtr = fp;
        Desc = desc;
    }
};

static void __main_block_func_1(struct __main_block_impl_1 *__cself, int a, int b, int c) {

    printf("a = %d, b = %d, c = %d\n",a, b, c);
}

static struct __main_block_desc_1 {
    size_t reserved;
    size_t Block_size;
} __main_block_desc_1_DATA = { 0, sizeof(struct __main_block_impl_1)};


int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 
        int a = 10, b = 20;
                            
        void (*Block)(int,int) = ((void (*)(int, int))&__main_block_impl_1((void *)__main_block_func_1, &__main_block_desc_1_DATA));

        a = 20;
        b = 30;

        ((void (*)(__block_impl *, int, int))((__block_impl *)Block)->FuncPtr)((__block_impl *)Block, a, b, c);
    }
    return 0;
}
```

1. 可以看见`__main_block_impl_1`结构体中没有变量`a`、变量`b`,说明通过直接传值的方式，变量并没有存进`Block`的结构体中。
2. 在`__main_block_func_1`函数中，发现参数列表中多了`int a, int b`这两个参数，还有调用`Block`的时候，直接把变量`a`、`b`的值传入进去了。

#### Block截获static修饰变量的实质

下面我们定义了三个变量：

- 全局
  - 变量：c
- 局部
  - 常量：a
  - 变量：b

```objective-c
static int c = 30;
- (void)useBlockInterceptLocalVariables {
    static const int a = 10;
  	static int b = 20;

  	void (^Block)(void) = ^{
      	b = 50;
      	c = 60;
        printf("a = %d, b = %d, c = %d\n",a, b, c);
    };
  
    b = 30;
    c = 40;
  	Block();				 // 输出结果：a = 10, b = 50, c = 60
}
```

- 从以上测试结果我们可以得出：
  - `Block` 对象能获取最新的**静态全局变量**和**静态局部变量**；
  - **静态局部常量**由于值不会更改，故没有变化；
- 我们来看看`c++`代码，到底发生了什么

```objective-c
static int c = 30;//全局静态变量

struct __main_block_impl_0 {
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
    int *b;//捕获变量，获取变量地址
    const int *a;//捕获变量，获取变量地址
    __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int *_b, const int *_a, int flags=0) : b(_b), a(_a) {
        impl.isa = &_NSConcreteStackBlock;
        impl.Flags = flags;
        impl.FuncPtr = fp;
        Desc = desc;
    }
};

static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
  	//2.通过Block对象获取到b和a的指针
    int *b = __cself->b; // bound by copy
    const int *a = __cself->a; // bound by copy
		//通过b指针，修改b指向的值
    (*b) = 50;
    c = 60;
    printf("a = %d, b = %d, c = %d\n",(*a), (*b), c);
}

static struct __main_block_desc_0 {
    size_t reserved;
    size_t Block_size;
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)};

int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool;
        static const int a = 10;
        static int b = 20;
                            
				//1.传入&a, &b地址进行Blcok对象的初始化
        void (*Block)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, &b, &a));

        b = 30;
        c = 40;
        ((void (*)(__block_impl *))((__block_impl *)Block)->FuncPtr)((__block_impl *)Block);
    }
    return 0;
}
```

1. 可以看到在 `__main_block_impl_0` 结构体中，静态局部变量`static int b`以指针的形式添加为成员变量，而静态局部常量`static const int a`以`const int *`的形式添加为成员变量。而全局静态变量`static int c` 并没有添加为成员变量

```objective-c
struct __main_block_impl_0 {
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
    int *b;//捕获变量，获取变量地址
    const int *a;//捕获变量，获取变量地址
    __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int *_b, const int *_a, int flags=0) : b(_b), a(_a) {
        impl.isa = &_NSConcreteStackBlock;
        impl.Flags = flags;
        impl.FuncPtr = fp;
        Desc = desc;
    }
};
```

2. 再来看看 `__main_block_func_0` 结构体部分，静态全局变量`static int c`是直接访问的，静态局部变量`static int b`是通过『指针传递』的方式进行访问，静态局部常量`static const int a`也是通过『指针传递』的方式进行访问，但是它是通过`const`修饰的无法进行赋值操作。

```objective-c
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
  	//2.通过Block对象获取到b和a的指针
    int *b = __cself->b; // bound by copy
    const int *a = __cself->a; // bound by copy
		//通过b指针，修改b指向的值
    (*b) = 50;
    c = 60;
    printf("a = %d, b = %d, c = %d\n",(*a), (*b), c);
}
```

- 我们为什么能获取 `static` 变量最新的值？

  1. `static` 修饰的，其作用区域不管是全局还是局部，不管是常量还是变量，**均存储在全局存储区中**，存在全局存储区，该地址在程序运行过程中一直不会改变，所以能访问最新值。
  2. `static` 修饰后：

  - 全局变量，**直接访问**。
  - 局部变量，指针访问。其中在局部变量中，又有局部静态常量，即被` const` 修饰的。
    - `const` 存放在 `text` 段中，即使被 `static` 同时修饰，也存放` text` 中的常量区；

#### Block截获const修饰变量的实质

- 如下定义：
  - `const` 全局变量：a
  - `const` 局部变量：b

```objective-c
const int a = 10;
- (void)useBlockInterceptLocalVariables {
  	const int b = 20;

  	void (^Block)(void) = ^{
        printf("a = %d, b = %d\n",a, b);
    };
  
  	Block();				 // 输出结果：a = 10, b = 20
}
```

- 看看转换后的`c++`代码

```objective-c
static int a = 10;

struct __main_block_impl_0 {
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
    const int b;
    __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, const int _b, int flags=0) : b(_b) {
        impl.isa = &_NSConcreteStackBlock;
        impl.Flags = flags;
        impl.FuncPtr = fp;
        Desc = desc;
    }
};

static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
    const int b = __cself->b; // bound by copy
    printf("a = %d, b = %d\n",a, b);
}

static struct __main_block_desc_0 {
    size_t reserved;
    size_t Block_size;
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)};

int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 
        const int b = 20;
        void (*Block)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, b));
        ((void (*)(__block_impl *))((__block_impl *)Block)->FuncPtr)((__block_impl *)Block);

    }
    return 0;
}
```

- 从上面看出：
  - `const` 全局变量**直接访问**；
  - `const` 局部变量，其实仍然是 `auto` 修饰，**值传递**；

- 最后我们用一张图来总结一下这一节所学的内容

![Block不同作用域的访问方式](https://tva1.sinaimg.cn/large/006y8mN6ly1g7avqsahmhj312h0h90vn.jpg)

### Block截获对象实质



### Blocks内改写被截获变量的值的方式

#### __block修饰符

##### __blcok修饰局部变量

##### __block修饰对象

#### 更改特殊区域变量值
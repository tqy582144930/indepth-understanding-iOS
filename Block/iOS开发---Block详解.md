

   * [iOS开发---Block详解](#ios开发---block详解)
      * [Block的基础](#block的基础)
         * [什么是Blocks？](#什么是blocks)
         * [Blocks的语法](#blocks的语法)
         * [Block类型变量](#block类型变量)
         * [Block在oc中的使用](#block在oc中的使用)
         * [Block截取变量](#block截取变量)
            * [截获自动变量的值](#截获自动变量的值)
            * [通过__block说明符赋值](#通过__block说明符赋值)
      * [Block的实现](#block的实现)
         * [Block的实质是什么？](#block的实质是什么)
            * [准备工作](#准备工作)
            * [Block源码预览](#block源码预览)
               * [Block结构体](#block结构体)
               * [struct __block_impl 结构](#struct-__block_impl-结构)
               * [static struct __main_block_desc_0结构](#static-struct-__main_block_desc_0结构)
               * [__main_block_impl_0 构造函数](#__main_block_impl_0-构造函数)
               * [调用](#调用)
               * [Block的实质总结](#block的实质总结)
         * [Block的类型](#block的类型)
            * [Block的三种类型](#block的三种类型)
            * [Block的自动拷贝和手动拷贝](#block的自动拷贝和手动拷贝)
               * [Block的自动拷贝](#block的自动拷贝)
               * [Block的手动拷贝](#block的手动拷贝)
               * [__block变量的拷贝](#__block变量的拷贝)
         * [Block截获变量实质](#block截获变量实质)
            * [Block截获自动局部变量的实质](#block截获自动局部变量的实质)
               * [Block块中直接调用局部变量](#block块中直接调用局部变量)
               * [Block通过传值间接访问局部变量](#block通过传值间接访问局部变量)
            * [Block截获static修饰变量的实质](#block截获static修饰变量的实质)
            * [Block截获const修饰变量的实质](#block截获const修饰变量的实质)
         * [Block截获对象实质](#block截获对象实质)
         * [Blocks内改写被截获变量的值的方式](#blocks内改写被截获变量的值的方式)
            * [__block修饰符](#__block修饰符)
               * [__blcok修饰局部变量](#__blcok修饰局部变量)
               * [__block修饰对象](#__block修饰对象)
            * [更改特殊区域变量值](#更改特殊区域变量值)
      * [__block变量内存管理](#__block变量内存管理)
         * [基本类型的Desc](#基本类型的desc)
         * [对象类型的Desc](#对象类型的desc)
            * [初始化__block对象](#初始化__block对象)
            * [对象类型的内存管理](#对象类型的内存管理)
            * [与auto对象变量的区别](#与auto对象变量的区别)
         * [从栈到堆](#从栈到堆)
            * [Block从栈拷贝到堆](#block从栈拷贝到堆)
            * [Block销毁](#block销毁)
            * [总结](#总结)
      * [更多细节](#更多细节)
         * [__block捕获变量存放在哪？](#__block捕获变量存放在哪)
         * [对象与__block变量的区别](#对象与__block变量的区别)

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

2. 第二个参数：`__main_block_desc_0_DATA`：`__main_block_desc_0_DATA`包含该Block 的相关信息。
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

- **Block有三种类型，分别是NSGlobalBlock,NSMallocBlock,NSStackBlock。**
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
3. 将 `Block` 赋值给类的附有 `__strong`修饰符的`id`类型或 Block 类型成员变量时

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
|            栈区            | 从栈复制到堆，并被 Block 所持有 |
|            堆区            |         被 Block 所持有         |

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

- 在前一节我们学习了`Block`如何截获基本类型，这一节我们主要学习截获对象类型的`auto`变量

```objective-c
Person *person = [[Person alloc] init];
person.age = 20;
void (^block)(void) = ^{
  NSLog(@"age = %d", person.age);
};
block();
```

- 根据`Block`捕获基本变量的规律，针对对象，仍然适用
  - `auto` 变量捕获后，`Block` 中变量的类型和变量原类型一致；
  - `static` 变量捕获后，`Block` 对应的变量是对应变量的指针类型；

那么，`auto` 对象与基本类型在 `Block` 内部有什么区别呢。

- 我们把上述代换转换成`C++`

```objective-c
struct __main_block_impl_0 {
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
    Person *person;
    __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, Person *_person, int flags=0) : person(_person) {
        impl.isa = &_NSConcreteStackBlock;
        impl.Flags = flags;
        impl.FuncPtr = fp;
        Desc = desc;
    }
};

static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
    Person *person = __cself->person; // bound by copy

    NSLog((NSString *)&__NSConstantStringImpl__var_folders_bp_sg6dyc5957s2j2v4l6z9k4dm0000gn_T_main_f5936b_mi_0, ((int (*)(id, SEL))(void *)objc_msgSend)((id)person, sel_registerName("age")));
}

static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {
  	_Block_object_assign((void*)&dst->person, (void*)src->person, 3/*BLOCK_FIELD_IS_OBJECT*/);
}

static void __main_block_dispose_0(struct __main_block_impl_0*src) {
    _Block_object_dispose((void*)src->person, 3/*BLOCK_FIELD_IS_OBJECT*/);
}

static struct __main_block_desc_0 {
    size_t reserved;
    size_t Block_size;
    void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*);
    void (*dispose)(struct __main_block_impl_0*);
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0), __main_block_copy_0, __main_block_dispose_0};

int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 
        Person *person = ((Person *(*)(id, SEL))(void *)objc_msgSend)((id)((Person *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("Person"), sel_registerName("alloc")), sel_registerName("init"));
        ((void (*)(id, SEL, int))(void *)objc_msgSend)((id)person, sel_registerName("setAge:"), 20);
        void (*block)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, person, 570425344));
        ((void (*)(__block_impl *))((__block_impl *)block)->FuncPtr)((__block_impl *)block);
    }
    return 0;
}
```

1. 我们看到`__main_block_impl_0`结构体中多了一个一个成员变量`Person *person`，因为`person`是自动变量，所以这里捕获了自动变量`person`作为`_main_block_impl_0`结构体的成员变量。**而且还要注意的是，由于是自动变量，所以在block外面，自动变量是什么类型，在结构体里面作为成员变量就是什么类型。person在结构体外面作为自动变量是指针类型，所以作为结构体里面的成员变量也是指针类型。**

```objective-c
struct __main_block_impl_0 {
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
    Person *person;
    __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, Person *_person, int flags=0) : person(_person) {
        impl.isa = &_NSConcreteStackBlock;
        impl.Flags = flags;
        impl.FuncPtr = fp;
        Desc = desc;
    }
};
```

2. 我们看到`__main_block_desc_0`结构中多了两个函数指针`void (*copy)`和`void (*dispose)`

```objective-c
static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {
  	_Block_object_assign((void*)&dst->person, (void*)src->person, 3/*BLOCK_FIELD_IS_OBJECT*/);
}

static void __main_block_dispose_0(struct __main_block_impl_0*src) {
    _Block_object_dispose((void*)src->person, 3/*BLOCK_FIELD_IS_OBJECT*/);
}
```

针对这两个函数，它们的作用就是：

| 函数                   | 作用                                                         | 调用时机                |
| :--------------------- | :----------------------------------------------------------- | :---------------------- |
| __main_block_copy_0    | 调用 `_Block_object_assign`，相当于 **retain**，将对象赋值在对象类型的结构体变量 `__main_block_impl_0` 中。 | 栈上的 Block 复制到堆时 |
| __main_block_dispose_0 | 调用 `_Block_object_dispose`，相当于 **release**，释放赋值在对象类型的结构体变量中的对象。 | 堆上 Block 被废弃时     |

### Blocks内改写被截获变量的值的方式

> 在Block中修饰被截获变量的值只有一下两种情况，我们先分析通过`__block`修饰符来修改截获变量的方式

#### __block修饰符

- `__block 说明符`类似于 `static`、`auto`、`register` 说明符，它们用于指定将变量值设置到哪个存储域中。例如`auto` 表示作为自动变量存储在**栈**中， `static`表示作为静态变量存储在**数据区**中。

> `__block`修饰符又分为修饰局部变量和修饰对象

##### __blcok修饰局部变量

```objective-c
- (void)useBlockQualifierChangeLocalVariables {
    __block int a = 10, b = 20;

    void (^myLocalBlock)(void) = ^{
        a = 20;
        b = 30;

        printf("a = %d, b = %d\n",a, b);    // 输出结果：a = 20, b = 30
    };

    myLocalBlock();
}
```

- 从中我们可以发现：通过 `__block` 修饰的局部变量，可以在 Block 的主体部分中改变值。

- 我们来转换下源码，分析一下：

```objective-c
struct __Block_byref_a_0 {
    void *__isa;
    __Block_byref_a_0 *__forwarding;
    int __flags;
    int __size;
    int a;
};

struct __Block_byref_b_1 {
    void *__isa;
    __Block_byref_b_1 *__forwarding;
    int __flags;
    int __size;
    int b;
};

struct __main_block_impl_0 {
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
    __Block_byref_a_0 *a; // by ref
    __Block_byref_b_1 *b; // by ref
    __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, __Block_byref_a_0 *_a, __Block_byref_b_1 *_b, int flags=0) : a(_a->__forwarding), b(_b->__forwarding) {
        impl.isa = &_NSConcreteStackBlock;
        impl.Flags = flags;
        impl.FuncPtr = fp;
        Desc = desc;
    }
};

static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
    __Block_byref_a_0 *a = __cself->a; // bound by ref
    __Block_byref_b_1 *b = __cself->b; // bound by ref

    (a->__forwarding->a) = 20;
    (b->__forwarding->b) = 30;

    printf("a = %d, b = %d\n",(a->__forwarding->a), (b->__forwarding->b));
}

static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {_Block_object_assign((void*)&dst->a, (void*)src->a, 8/*BLOCK_FIELD_IS_BYREF*/);_Block_object_assign((void*)&dst->b, (void*)src->b, 8/*BLOCK_FIELD_IS_BYREF*/);}

static void __main_block_dispose_0(struct __main_block_impl_0*src) {_Block_object_dispose((void*)src->a, 8/*BLOCK_FIELD_IS_BYREF*/);_Block_object_dispose((void*)src->b, 8/*BLOCK_FIELD_IS_BYREF*/);}

static struct __main_block_desc_0 {
    size_t reserved;
    size_t Block_size;
    void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*);
    void (*dispose)(struct __main_block_impl_0*);
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0), __main_block_copy_0, __main_block_dispose_0};

int main() {
    __attribute__((__blocks__(byref))) __Block_byref_a_0 a = {(void*)0,(__Block_byref_a_0 *)&a, 0, sizeof(__Block_byref_a_0), 10};
    __Block_byref_b_1 b = {(void*)0,(__Block_byref_b_1 *)&b, 0, sizeof(__Block_byref_b_1), 20};

    void (*myLocalBlock)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, (__Block_byref_a_0 *)&a, (__Block_byref_b_1 *)&b, 570425344));
    ((void (*)(__block_impl *))((__block_impl *)myLocalBlock)->FuncPtr)((__block_impl *)myLocalBlock);

    return 0;
}
```

- 可以看到，只是加上了一个 `__block`，代码量就增加了很多。

- 我们从 `__main_block_impl_0` 开始说起：

```objective-c
struct __main_block_impl_0 {
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
    __Block_byref_a_0 *a; // by ref
    __Block_byref_b_1 *b; // by ref
    __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, __Block_byref_a_0 *_a, __Block_byref_b_1 *_b, int flags=0) : a(_a->__forwarding), b(_b->__forwarding) {
        impl.isa = &_NSConcreteStackBlock;
        impl.Flags = flags;
        impl.FuncPtr = fp;
        Desc = desc;
    }
};
```

- 我们在 `__main_block_impl_0`结构体中可以看到： 原 OC 代码中，被 `__block`修饰的局部变量 `__block int a`、`__block int b`分别变成了 `__Block_byref_a_0`、`__Block_byref_b_1`类型的结构体指针 `a`、结构体指针 `b`。这里使用结构体指针 `a`、结构体指针 `b`说明 `_Block_byref_a_0`、`__Block_byref_b_1`类型的结构体并不在 `__main_block_impl_0`结构体中，而只是通过指针的形式引用，这是为了可以在多个不同的 Block 中使用 `__block`修饰的变量。

- `__Block_byref_a_0`、`__Block_byref_b_1` 类型的结构体声明如下：

```objective-c
struct __Block_byref_a_0 {
    void *__isa;
    __Block_byref_a_0 *__forwarding;
    int __flags;
    int __size;
    int a;
};

struct __Block_byref_b_1 {
    void *__isa;
    __Block_byref_b_1 *__forwarding;
    int __flags;
    int __size;
    int b;
};
```

- 拿第一个 `__Block_byref_a_0`结构体定义来说明，`__Block_byref_a_0`有 5 个部分：

  1. `__isa`：标识对象类的 `isa`实例变量
  2. `__forwarding`：传入变量的地址
  3. `__flags`：标志位
  4. `__size`：结构体大小

  5. `a`：存放实变量 `a`实际的值，相当于原局部变量的成员变量（和之前不加__block修饰符的时候一致）。

- 再来看一下 `main()`函数中，`__block int a`、`__block int b`的赋值情况。

```objective-c
__Block_byref_a_0 a = {
    (void*)0,
    (__Block_byref_a_0 *)&a, 
    0, 
    sizeof(__Block_byref_a_0), 
    10
};

__Block_byref_b_1 b = {
    0,
    &b, 
    0, 
    sizeof(__Block_byref_b_1), 
    20
};
```

- 还是拿第一个`__Block_byref_a_0 a`的赋值来说明。

- 可以看到 `__isa`指针值传空，`__forwarding`指向了局部变量 `a`本身的地址，`__flags`分配了 0，`__size`为结构体的大小，`a`赋值为 10。下图用来说明 `__forwarding`指针的指向情况。

![__forwarding指向](https://tva1.sinaimg.cn/large/006y8mN6ly1g7cqcq5jzvj314m0fy0wm.jpg)

- 这下，我们知道 `__forwarding` 其实就是局部变量 `a` 本身的地址，那么我们就可以通过 `__forwarding` 指针来访问局部变量，同时也能对其进行修改了。

- 来看一下 Block 主体部分对应的 `__main_block_func_0` 结构体来验证一下。

```objective-c
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
    __Block_byref_a_0 *a = __cself->a; // bound by ref
    __Block_byref_b_1 *b = __cself->b; // bound by ref

    (a->__forwarding->a) = 20;
    (b->__forwarding->b) = 30;

    printf("a = %d, b = %d\n",(a->__forwarding->a), (b->__forwarding->b));
}
```

可以看到 `(a->__forwarding->a) = 20;`和 `(b->__forwarding->b) = 30;`是通过指针取值的方式来改变了局部变量的值。这也就解释了通过 `__block`来修饰的变量，在 Block 的主体部分中改变值的原理其实是：通过**『指针传递』**的方式。

##### __block修饰对象

```objective-c
- (void)useBlockQualifierChangeLocalVariables {
    __block Person *person = [[Person alloc] init];

    void(^block)(void) = ^ {
      person = [[Person alloc] init];//修改person创建的地址
      NSLog(@"person is %@", person);
    };
    block();
}
```

- 把上述代码转换成C++

```objective-c
static void __Block_byref_id_object_copy_131(void *dst, void *src) {
	 _Block_object_assign((char*)dst + 40, *(void * *) ((char*)src + 40), 131);
}
static void __Block_byref_id_object_dispose_131(void *src) {
	 _Block_object_dispose(*(void * *) ((char*)src + 40), 131);
}

struct __Block_byref_person_0 {
    void *__isa;
    __Block_byref_person_0 *__forwarding;
    int __flags;
    int __size;
    void (*__Block_byref_id_object_copy)(void*, void*);
    void (*__Block_byref_id_object_dispose)(void*);
    Person *person;
};

struct __main_block_impl_0 {
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
    __Block_byref_person_0 *person; // by ref
    __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, 	    __Block_byref_person_0 *_person, int flags=0) : person(_person->__forwarding) {
        impl.isa = &_NSConcreteStackBlock;
        impl.Flags = flags;
        impl.FuncPtr = fp;
        Desc = desc;
    }
};

static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
    __Block_byref_person_0 *person = __cself->person; // bound by ref

    (person->__forwarding->person) = ((Person *(*)(id, SEL))(void *)objc_msgSend)((id)((Person *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("Person"), sel_registerName("alloc")), sel_registerName("init"));
    NSLog((NSString *)&__NSConstantStringImpl__var_folders_bp_sg6dyc5957s2j2v4l6z9k4dm0000gn_T_main_1f2ea2_mi_0, (person->__forwarding->person));
}

static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {
    _Block_object_assign((void*)&dst->person, (void*)src->person, 8/*BLOCK_FIELD_IS_BYREF*/);
}

static void __main_block_dispose_0(struct __main_block_impl_0*src) {
    _Block_object_dispose((void*)src->person, 8/*BLOCK_FIELD_IS_BYREF*/);
}

static struct __main_block_desc_0 {
    size_t reserved;
    size_t Block_size;
    void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*);
    void (*dispose)(struct __main_block_impl_0*);
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0), __main_block_copy_0, __main_block_dispose_0};

int main(int argc, const char * argv[]) {
    /* @autoreleasepool */ { __AtAutoreleasePool __autoreleasepool; 
       __attribute__((__blocks__(byref))) 
       __Block_byref_person_0 person = {
           (void*)0,
           (__Block_byref_person_0 *)&person,
           33554432,
           sizeof(__Block_byref_person_0), 
         	 __Block_byref_id_object_copy_131,
           __Block_byref_id_object_dispose_131,
           ((Person *(*)(id, SEL))(void *)objc_msgSend)((id)((Person *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("Person"),
           sel_registerName("alloc")),
           sel_registerName("init"))
       };

       void(*block)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, (__Block_byref_person_0 *)&person, 570425344));
        ((void (*)(__block_impl *))((__block_impl *)block)->FuncPtr)((__block_impl *)block);
    }
    return 0;
}
```

- 我们先从 `__main_block_impl_0` 开始说起：

```objective-c
struct __main_block_impl_0 {
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
    __Block_byref_person_0 *person; // by ref
    __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, __Block_byref_person_0 *_person, int flags=0) : person(_person->__forwarding) {
        impl.isa = &_NSConcreteStackBlock;
        impl.Flags = flags;
        impl.FuncPtr = fp;
        Desc = desc;
    }
};
```

- 我们在 `__main_block_impl_0` 结构体中可以看到： 原 `OC `代码中，被 `__block` 修饰的`person`变成了 `__Block_byref_person_0`类型结构体指针
-  `__Block_byref_person_0`类型结构体声明和该结构体初始化如下：

```objective-c
struct __Block_byref_person_0 {
    void *__isa;
    __Block_byref_person_0 *__forwarding;
    int __flags;
    int __size;
    void (*__Block_byref_id_object_copy)(void*, void*);
    void (*__Block_byref_id_object_dispose)(void*);
    Person *person;
};

__Block_byref_person_0 person = {
           (void*)0,
           (__Block_byref_person_0 *)&person,
           33554432,
           sizeof(__Block_byref_person_0), 
         	 __Block_byref_id_object_copy_131,
           __Block_byref_id_object_dispose_131,
           ((Person *(*)(id, SEL))(void *)objc_msgSend)((id)((Person *(*)(id, SEL))(void *)objc_msgSend)((id)objc_getClass("Person"),
           sel_registerName("alloc")),
           sel_registerName("init"))
       };


```

- 我们发现，在`_Block_byref_person_0`中多了两个函数，通过其初始化可以知道这两个函数分别是`__Block_byref_id_object_copy_131`和`__Block_byref_id_object_dispose_131`这两个函数

```objective-c
static void __Block_byref_id_object_copy_131(void *dst, void *src) {
	 _Block_object_assign((char*)dst + 40, *(void * *) ((char*)src + 40), 131);
}
static void __Block_byref_id_object_dispose_131(void *src) {
	 _Block_object_dispose(*(void * *) ((char*)src + 40), 131);
}
```

- 这两个函数其实和`_main_block_copy_0`和`_main_block_dispose_0`一样，最终都是调用`_Block_object_assign`和`_Block_object_dispose`这两个函数。那么这里为什么都加上了40呢？我们分析一下`_Block_byref_person_0`的结构：

```objective-c
struct __Block_byref_person_0 {
    void *__isa;    //指针，8字节
    __Block_byref_person_0 *__forwarding; //指针，8字节
    int __flags; //int型，4字节
    int __size;  //int型，4字节
    void (*__Block_byref_id_object_copy)(void*, void*);//指针型，8字节
    void (*__Block_byref_id_object_dispose)(void*);//指针型，8字节
    Person *person;
};
```

- 这样一来，`_Block_byref_person_0`的地址和`person`指针的地址就相差40字节，所以+40的目的就是找到`person`指针。

#### 更改特殊区域变量值

- C语言中有几种特殊区域的变量，允许 Block 改写值，具体如下：
  - 静态局部变量
  - 静态全局变量
  - 全局变量

下面我们通过代码来看看这种情况

- OC代码

```objective-c
int global_val = 10; // 全局变量
static int static_global_val = 20; // 静态全局变量

int main() {
    static int static_val = 30; // 静态局部变量

    void (^myLocalBlock)(void) = ^{
        global_val *= 1;
        static_global_val *= 2;
        static_val *= 3;

        printf("static_val = %d, static_global_val = %d, global_val = %d\n",static_val, static_global_val, static_val);
    };

    myLocalBlock();

    return 0;
}
```

- C++代码

```objective-c
int global_val = 10;
static int static_global_val = 20;

struct __main_block_impl_0 {
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
    int *static_val;
    __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int *_static_val, int flags=0) : static_val(_static_val) {
        impl.isa = &_NSConcreteStackBlock;
        impl.Flags = flags;
        impl.FuncPtr = fp;
        Desc = desc;
    }
};

static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
    int *static_val = __cself->static_val; // bound by copy
    global_val *= 1;
    static_global_val *= 2;
    (*static_val) *= 3;

    printf("static_val = %d, static_global_val = %d, global_val = %d\n",(*static_val), static_global_val, (*static_val));
}

static struct __main_block_desc_0 {
    size_t reserved;
    size_t Block_size;
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0)};

int main() {
    static int static_val = 30;

    void (*myLocalBlock)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA, &static_val));
    ((void (*)(__block_impl *))((__block_impl *)myLocalBlock)->FuncPtr)((__block_impl *)myLocalBlock);

    return 0;

}
```

- 从中可以看到：
  - 在 `__main_block_impl_0` 结构体中，将静态局部变量 `static_val` 以指针的形式添加为成员变量，而静态全局变量 `static_global_val`、全局变量 `global_val` 并没有添加为成员变量。

```objective-c
int global_val = 10;
static int static_global_val = 20;

struct __main_block_impl_0 {
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
    int *static_val;
    __main_block_impl_0(void *fp, struct __main_block_desc_0 *desc, int *_static_val, int flags=0) : static_val(_static_val) {
        impl.isa = &_NSConcreteStackBlock;
        impl.Flags = flags;
        impl.FuncPtr = fp;
        Desc = desc;
    }
};
```

- 再来看一下 Block 主体部分对应的 `__main_block_func_0` 结构体部分。静态全局变量 `static_global_val`、全局变量 `global_val` 是直接访问的，而静态局部变量 `static_val` 则是通过『指针传递』的方式进行访问和赋值。

```objective-c
static void __main_block_func_0(struct __main_block_impl_0 *__cself) {
    int *static_val = __cself->static_val; // bound by copy
    global_val *= 1;
    static_global_val *= 2;
    (*static_val) *= 3;

    printf("static_val = %d, static_global_val = %d, global_val = %d\n",(*static_val), static_global_val, (*static_val));
}
```

- 静态变量的这种方法似乎也适用于自动变量的访问，但我们为什么没有这么做呢？

  实际上，在由 Block 语法生成的值 Block 上，可以存有超过其变量域的被截获对象的自动变量。变量作用域结束的同时，原来的自动变量被废弃，因此 Block 中超过变量作用域而存在的变量同静态变量一样，将不能通过指针访问原来的自动变量。

- 最后我们用一张图来总结一下这一节所学

![block捕获变量类型](https://tva1.sinaimg.cn/large/006y8mN6ly1g7d7hpphsxj314g0hwgp5.jpg)

## `__block`变量内存管理

- 我们先回顾一下之前的一些捕获变量或对象是如何管理内存的。

- **注：下面 “干预” 是指不用程序员手动管理，其实本质还是要系统管理内存的分配与释放。**
  - `auto` 局部基本类型变量，因为是值传递，内存是跟随 Block，不用干预；
  - `static` 局部基本类型变量，指针传递，由于分配在静态区，故不用干预；
  - 全局变量，存储在数据区，不用多说，不用干预；
  - 局部对象变量，如果在栈上，不用干预。但 `Block` 在拷贝到堆的时候，对其 `retain`，在 `Block` 对象销毁时，对其 `release`；

在这里，`__block` 变量呢？

**注意点就是：__block 变量在转换后封装成了一个新对象，内存管理会多出一层。**

### 基本类型的Desc

上述 `age` 是基本类型，其转换后的结构体为：

```objective-c
struct __Block_byref_age_0 {
    void *__isa;	
    __Block_byref_age_0 *__forwarding;
    int __flags;
    int __size;
    int age;
};
```

而 `Block` 中的 `Desc` 如下：

```objective-c
static struct __main_block_desc_0 {
  size_t reserved;
  size_t Block_size;
  void (*copy)(struct __main_block_impl_0*, struct __main_block_impl_0*);
  void (*dispose)(struct __main_block_impl_0*);
} __main_block_desc_0_DATA = { 0, sizeof(struct __main_block_impl_0), __main_block_copy_0, __main_block_dispose_0};

//下面两个方法是Block内: 内存管理相关函数
static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {
    _Block_object_assign((void*)&dst->age, (void*)src->age, 8/*BLOCK_FIELD_IS_BYREF*/);
    _Block_object_assign((void*)&dst->person, (void*)src->person, 8/*BLOCK_FIELD_IS_BYREF*/);
}

static void __main_block_dispose_0(struct __main_block_impl_0*src) {
    _Block_object_dispose((void*)src->age, 8/*BLOCK_FIELD_IS_BYREF*/);
    _Block_object_dispose((void*)src->person, 8/*BLOCK_FIELD_IS_BYREF*/);
}
```

针对基本类型，以 `age` 类型为例：

- `__Block_byref_age_0` 对象同样是在 `Block对象`从栈上拷贝到堆上，进行 `retain`；
- 当 `Block对象`销毁时，对`__Block_byref_age_0` 进行 `release`；
- `__Block_byref_age_0` 内 `age`，由于是基本类型，是不用进行内存手动干预的。

### 对象类型的Desc

下面看`__block` 对象类型的转换：

```objective-c
struct __Block_byref_person_1 {
    void *__isa;		//地址0---占用8字节
    __Block_byref_person_1 *__forwarding;	//地址8-16---占用8字节
    int __flags;		//地址16-20---占用4字节
    int __size;			//地址20-24---占用8字节
    void (*__Block_byref_id_object_copy)(void*, void*);	//地址24-32---占用8字节
    void (*__Block_byref_id_object_dispose)(void*);     //地址32-40---占用8字节
    BFPerson *person; 	//地址40-48---占用8字节
};
```

- 因为捕获的本身是一个对象类型，所以该对象类型还需要进行内存的干预。

- 这里有两个熟悉的函数，即用于管理对象 auto 变量时，我们见过，用于管理对象 auto 的内存：

```objective-c
void (*__Block_byref_id_object_copy)(void*, void*);
void (*__Block_byref_id_object_dispose)(void*);
```

- 那么这两个函数对应的实现，我们也找出来：

#### 初始化__block对象

下面针对转换来转换去的细节做了删减，方便阅读：

```objective-c
struct __Block_byref_person_1 person = {
    0,	//isa
    &person,	//__forwarding
    33554432, 	//__flags
    sizeof(__Block_byref_person_1),		//__size
    __Block_byref_id_object_copy_131,  //(*__Block_byref_id_object_copy)
    __Block_byref_id_object_dispose_131,// (*__Block_byref_id_object_dispose)
    (objc_msgSend)((objc_msgSend)(objc_getClass("BFPerson"), sel_registerName("alloc")), sel_registerName("init"))
};

//注意此处+40字节
static void __Block_byref_id_object_copy_131(void *dst, void *src
{
		_Block_object_assign((char*)dst + 40, *(void * *) ((char*)src + 40), 131);
}
static void __Block_byref_id_object_dispose_131(void *src) 
{
    _Block_object_dispose(*(void * *) ((char*)src + 40), 131);
}
```

- 我们注意观察，在`__Block_byref_id_object_copy_131` 和`__Block_byref_id_object_dispose_131` 函数中，都会偏移 40 字节，我们再看`__block BFPerson` 对象转换后的`__Block_byref_person_1` 结构体发现，其 40 字节偏移处就是原本的 `BFPerson *person` 对象。

#### 对象类型的内存管理

以 `BFPerson *person`，在`__block` 修饰后，转换为：`__Block_byref_person_1` 对象：

- `__Block_byref_person_1` 对象同样是在 `Block对象`从栈上拷贝到堆上，进行 `retain`；
  - 当`__Block_byref_person_1` 进行 `retain` 同时，会将 `person` 对象进行 retain
- 当 `Block对象`销毁时，对`__Block_byref_person_1` 进行 `release`
  - 当`__Block_byref_person_1` 对象 `release` 时，会将 `person` 对象 `release` 

#### 与auto对象变量的区别

![auto对象变量与_block变量对比](https://tva1.sinaimg.cn/large/006y8mN6ly1g7d88ehhu0j31680nm0zi.jpg)

### 从栈到堆

Block 从栈复制到堆时，__block 变量产生的影响如下：

| __block 变量的配置存储域 | Block 从栈复制到堆的影响      |
| :----------------------- | :---------------------------- |
| 栈                       | 从栈复制到堆，并被 Block 持有 |
| 堆                       | 被 Block 持有                 |

#### Block从栈拷贝到堆

![block从栈拷贝到堆](https://tva1.sinaimg.cn/large/006y8mN6ly1g7d89t0pp6j316k0hqn2p.jpg)

当有多个 Block 对象，持有同一个__block 变量。

- 当其中任何 Block 对象复制到堆上，__block 变量就会复制到堆上。
- 后续，其他 Block 对象复制到堆上，__block 对象引用计数会增加。
- Block 复制到堆上的对象，持有__block 对象。

#### Block销毁

![Block销毁](https://tva1.sinaimg.cn/large/006y8mN6ly1g7d8b4ku98j312g0k0wks.jpg)

#### 总结

![__block变量的内存管理](https://tva1.sinaimg.cn/large/006y8mN6ly1g7d8bepd3bj316e0ka452.jpg)

## 更多细节

### __block捕获变量存放在哪？

```objective-c
__block int age = 20;
__block BFPerson *person = [[BFPerson alloc] init];

void(^block)(void) = ^ {
    age = 30;
    person = [[BFPerson alloc] init];
    NSLog(@"malloc address: %p %p", &age, person);
    NSLog(@"malloc age is %d", age);
    NSLog(@"person is %@", person);
};
block();
NSLog(@"stack address: %p %p", &age, person);
NSLog(@"stack age is %d", age);

//输出结果
Block-test[12866:2303749] malloc address: 0x100610bf8 0x100612ff0
Block-test[12866:2303749] malloc age is 30
Block-test[12866:2303749] person is <Person: 0x100612ff0>
Block-test[12866:2303749] stack address: 0x100610bf8 0x100612ff0
Block-test[12866:2303749] stack age is 30
```

可以看到，不管是 `age` 还是 `person`，均在堆空间。

其实，本质上，将 `Block` 从栈拷贝到堆，也会将`__block` 对象一并拷贝到堆，如下图：

![block从栈到堆细节](https://tva1.sinaimg.cn/large/006y8mN6ly1g7d8febw82j30ry0lqdjq.jpg)

### 对象与__block变量的区别

```objective-c
__block BFPerson *blockPerson = [[BFPerson alloc] init];
BFPerson *objectPerson = [[BFPerson alloc] init];
void(^block)(void) = ^ {
    NSLog(@"person is %@ %@", blockPerson, objectPerson);
};
```

转换后：

```objective-c
//Block对象
struct __main_block_impl_0 {
	struct __block_impl impl;
	struct __main_block_desc_0* Desc;
  	BFPerson *objectPerson;			//objectPerson对象，捕获
  	__Block_byref_blockPerson_0 *blockPerson; // blockPerson封装后的对象，内部捕获blockPerson
};

//__block blockPerson封装后的对象
struct __Block_byref_blockPerson_0 {
  	void *__isa;
	__Block_byref_blockPerson_0 *__forwarding;
 	void (*__Block_byref_id_object_copy)(void*, void*);
 	void (*__Block_byref_id_object_dispose)(void*);
 	BFPerson *blockPerson;
};

//两种对象不同的处理方式
static void __main_block_copy_0(struct __main_block_impl_0*dst, struct __main_block_impl_0*src) {
    _Block_object_assign((void*)&dst->blockPerson, (void*)src->blockPerson, 8/*BLOCK_FIELD_IS_BYREF*/);
    _Block_object_assign((void*)&dst->objectPerson, (void*)src->objectPerson, 3/*BLOCK_FIELD_IS_OBJECT*/);
}

//__Block_byref_blockPerson_0内部对__block blockPerson的处理
static void __Block_byref_id_object_copy_131(void *dst, void *src) {
	_Block_object_assign((char*)dst + 40, *(void * *) ((char*)src + 40), 131);
}
```

从上面可以得出

![__block变量和对象的区别](https://tva1.sinaimg.cn/large/006y8mN6ly1g7d8h9uus6j31ii0syai4.jpg)

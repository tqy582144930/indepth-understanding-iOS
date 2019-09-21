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
    void (*myBlock)(void) = ((void (*)())&__main_block_impl_0((void *)__main_block_func_0, &__main_block_desc_0_DATA));
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

##### __block_impl 结构

##### block Desc结构

##### 调用

### Block截获变量实质
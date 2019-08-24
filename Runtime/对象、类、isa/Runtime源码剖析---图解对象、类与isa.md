[TOC]

# Runtime源码剖析---图解对象、类与isa

> 源码面前，了无秘密

## 前言

- 在`iOS`开发的过程中，对象、类应该是我们接触最的一个部分，本篇文章就以对象为主题，分一下对象和类在底层是如何实现的，让你更深入了解`iOS`开发。
- 从这篇博客开始我们就会进行Runtime源码分析，所以你需要准备一份最新的源代码，源码建议从[Apple官方获取](<https://opensource.apple.com/>)
- 本篇博客所用的是750.1版本的objc4源码(目前最新版)

## 对象

### objc_object定义

- 在`OC`中每一个对象都是一个结构体，结构体中都包含一个`isa`的成员变量，其位于成员变量的第一位

### 如何在源码中找到它？

- 我们先在源码中找到objc_object在哪，于是你打开全局搜索，找到了这么一段

```objective-c
#if !OBJC_TYPES_DEFINED
/// An opaque type that represents an Objective-C class.
typedef struct objc_class *Class;

/// Represents an instance of a class.
struct objc_object {
    Class _Nonnull isa  OBJC_ISA_AVAILABILITY;
};

/// A pointer to an instance of a class.
typedef struct objc_object *id;
#endif
```

- 于是你认为它里面就一个`Class _Nonnull isa OBJC_ISA_AVAILABILITY`;
- 然而，请注意最上面的`#if !OBJC_TYPES_DEFINED`，点进去会发现该宏是1，说明根本不会走这个方法。
- 然而真正的定义是在objc-private文件里

```objective-c
struct objc_object {
private:
    isa_t isa;
public:
		//此处省略方法
};
```

- 我们不需要关心它的方法，我们来看看它的成员变量

### isa_t

```objective-c
union isa_t {
    isa_t() { }
    isa_t(uintptr_t value) : bits(value) { }

    Class cls;//----视线放在这------
    uintptr_t bits;
#if defined(ISA_BITFIELD)
    struct {
        ISA_BITFIELD;  // defined in isa.h
    };
#endif
};
```

- `isa_t`的作用就是**用来存储类的信息**
- 关于`isa_t`这个结构我们在下面会详细剖析
- 我们把视线放在`Class cls`这个变量，这个到底是什么呢？
  - 它其实就我们口中的类，下面我们来仔细看看类的内部实现

## 类

### objc_class定义

```objective-c
struct objc_class : objc_object {
    // Class ISA;
    Class superclass;
    cache_t cache;             // formerly cache pointer and vtable
    class_data_bits_t bits;    // class_rw_t * plus custom rr/alloc flags

  	//省略方法
}  
```

#### 成员变量

- 第一个变量`superclass`:指向他的父类
- 第二个变量`cache`:这里面存储的方法缓存，这个知识点我会在下一篇文章中仔细剖析
- 第三个变量`bits`：存储对象的方法、属性、协议等信息，这个知识点我会在下一篇文章中仔细剖析

#### 继承关系

- 从继承关系我们就会发现，原来`objc_class`是继承于`objc_object`,

  - 那就是说**类其实也是一个对象**
  - 还说明类实例化后也会包含`isa`这样一个成员
  - 用一张图来表示

  ![](http://ww3.sinaimg.cn/large/006y8mN6ly1g67ls7mk1uj30nf07dwen.jpg)

- 这个时候就会有一个疑问？

  - 既然类继承对象，它也有一个`isa `，前面我们说了这个成员的作用是记录类的信息的，那么我们类也拥有这个成员，那它也应该来记录一些信息，那它记得的是什么信息呢？这个时候我们需要引进一个概念**元类**

  > 注意⚠️：
  >
  > - 学习过程中，会发现很多人将`isa`称之为`isa`指针,的确在32位机时代它就是一个指针，但是在现在64位机时代，它是一个结构体，同时他也包含了指针的作用。具体为什么，我在后面会为大家详细解释
  > - 但是为方便讲述，下面也开始使用isa指向xxx这种说法

### 元类

- 元类的定义：元类是`Class`对象的类，类的`isa`会指向其元类

- 根类的定义：根类是所有对象的父类（除了特殊情况），它没有父类，一般情况下就是指NSObject

- 为什么会定义元类这个类？

  > 方法的调用机制：
  >
  > - 因为在 `Objective-C `中，对象的方法并**没有存储于对象的结构体中**（如果每一个对象都保存了自己能执行的方法，那么对内存的占用有极大的影响）。
  >
  > - 当**实例方法**被调用时，它要通过自己持有的 `isa` 来查找对应的类，然后在这里的 `class_data_bits_t` 结构体中查找对应方法的实现。同时，每一个 `objc_class` 也有一个**指向自己的父类的指针** `super_class` 用来查找继承的方法。

  - 既然类中存储的是实例方法，每个对象需要调用实例方法都来类里寻找即可，那么如果一个类需要调用类方法的时候，我们是如何查找并调用的呢？
    - 这个时候就需要引入**元类**来保证无论是类还是对象都能**通过相同的机制查找方法的实现**。

- 引入元类这个概念后，这样就达到了使类方法和实例方法的调用机制相同的目的：

  - 实例方法调用时，通过对象的 `isa` 在类中获取方法的实现
  - 类方法调用时，通过类的 `isa` 在元类中获取方法的实现

- 下面这张图介绍了对象、类与元类之间的关系

![](http://ww4.sinaimg.cn/large/006y8mN6ly1g67ml59sgdj30px0r5abj.jpg)

- 注意⚠️：
  - `Root class`根类，它是继承关系的顶点，它不继承于任何类
  - `Root meta class`根元类，它是`isa`指向的顶点，其`isa`直接指向自己,它继承于根类

## isa_t结构剖析

### 结构分析

- 我们先再来看一遍他的结构

```objective-c
union isa_t {
    isa_t() { }
    isa_t(uintptr_t value) : bits(value) { }

    Class cls;
    uintptr_t bits;
#if defined(ISA_BITFIELD)
    struct {
        ISA_BITFIELD;  // defined in isa.h
    };
#endif
};

//struct中的结构
#   define ISA_BITFIELD                                                        
      uintptr_t nonpointer        : 1;                                         
      uintptr_t has_assoc         : 1;                                         
      uintptr_t has_cxx_dtor      : 1;                                         
      uintptr_t shiftcls          : 44; 
      uintptr_t magic             : 6;                                         
      uintptr_t weakly_referenced : 1;                                         
      uintptr_t deallocating      : 1;                                         
      uintptr_t has_sidetable_rc  : 1;                                         
      uintptr_t extra_rc          : 8
```

>  注意⚠️：这是在 `__x86_64__` 上的实现，对于 iPhone5s 等架构为 `__arm64__` 的设备上，具体结构体的实现和位数可能有些差别，不过这些字段都是存在的，由于源码是在Mac OS运行的，所以我们就以`__x86_64__` 为例进行讲解

- `isa_t`是一个`union`的结构对象，`union`类似于`C++`结构体，其内部可以定义成员变量和函数。在`isa_t`中定义了`cls`、`bits`、`struct`三部分。联合体的大小取决的最大的那个成员变量，最大就是`struct`结构体，它占有64位，所以`union`的大小就是64位

#### cls对象

- 在前面我已经讲过了它代表的是类，如果有忘记的可以再回去看看。

#### bits对象

- 它其实是一个`unsigned long`类型
- 它是用来获取类指针，具体怎么操作下面我会详解

### struct

- 下面对`isa_t`中的结构体进行了位域声明，地址从`nonpointer`起到`extra_rc`结束，从低到高进行排列。位域也是对结构体内存布局进行了一个声明，通过下面的结构体成员变量可以直接操作某个地址。位域总共占8字节，所有的位域加在一起正好是64位。

  >  小提示：`union`中`bits`可以操作整个内存区，而位域只能操作对应的位。

- 下面我们用一张图来展示strucr的位域

![](http://ww4.sinaimg.cn/large/006y8mN6ly1g67myyhxhbj30lw0fnjsq.jpg)

- 下面我们看一下具体的存储地址

![](http://ww4.sinaimg.cn/large/006y8mN6ly1g67nqwjw3aj31900u0q4r.jpg)

### isa_t初始化过程

- 我们可以通过 `isa` 初始化的方法 `initIsa` 来初步了解这 64 位的 bits 的作用：

```objective-c
inline void 
objc_object::initInstanceIsa(Class cls, bool hasCxxDtor)
{
    initIsa(cls, true, hasCxxDtor);
}

inline void 
objc_object::initIsa(Class cls, bool index, bool hasCxxDtor) 
{ 
    if (!indexed) {
        isa.cls = cls;
    } else {
        isa.bits = ISA_MAGIC_VALUE;
        isa.has_cxx_dtor = hasCxxDtor;
        isa.shiftcls = (uintptr_t)cls >> 3;
    }
}
```

- 上来就看不懂，`index`是个什么，为什么在这里传的是`true`？在这里我给大家推荐一篇大神博客：[Non-pointer isa](<http://www.sealiesoftware.com/blog/archive/2013/09/24/objc_explain_Non-pointer_isa.html>)
  - 大概的意思是在64位系统中，为了降低内存使用，提升性能，`isa`中有一部分字段用来存储其他信息。这也解释了上面`isa_t`的那部分结构体。

- 由于在 `initInstanceIsa` 方法中传入了` index = true`，初始化就分为三步

#### `indexed` 和 `magic`

- 初始化第一步

```objective-c
isa.bits = ISA_MAGIC_VALUE;
```

- 我们来看看`ISA_MAGIC_VALUE`的定义

```objective-c
#define ISA_MAGIC_VALUE 0x001d800000000001ULL
二进制表示：11101100000000000000000000000000000000000000000000001
```

- 我们转换成二进制数据，然后看一下哪些属性对应的位域被这行代码初始化了（标记为红色）

![](http://ww2.sinaimg.cn/large/006y8mN6ly1g67o401xshj31cc0rkwgq.jpg)

- 从图中了解到，在使用 `ISA_MAGIC_VALUE` 设置 `isa_t` 结构体之后，实际上只是设置了 `indexed` 以及 `magic` 这两部分的值。

  - 其中 `indexed` 表示 `isa_t` 的类型

    - 0 表示 `raw isa`，也就是没有结构体的部分，访问对象的 `isa` 会直接返回一个指向 `cls` 的指针，也就是在 iPhone 迁移到 64 位系统之前时 isa 的类型。

    ```objective-c
    union isa_t {
        isa_t() { }
        isa_t(uintptr_t value) : bits(value) { }
    
        Class cls;
        uintptr_t bits;
    };
    ```

    - 1 表示当前 `isa` 不是指针，但是其中也有 `cls` 的信息，只是其中**关于类的指针都是保存在 shiftcls 中**。

    ```objective-c
    union isa_t {
        isa_t() { }
        isa_t(uintptr_t value) : bits(value) { }
    
        Class cls;
        uintptr_t bits;
    
        struct {
            uintptr_t indexed           : 1;
            uintptr_t has_assoc         : 1;
            uintptr_t has_cxx_dtor      : 1;
            uintptr_t shiftcls          : 44;
            uintptr_t magic             : 6;
            uintptr_t weakly_referenced : 1;
            uintptr_t deallocating      : 1;
            uintptr_t has_sidetable_rc  : 1;
            uintptr_t extra_rc          : 8;
        };
    };
    ```

  - `magic` 的值为 `0x3b` 用于调试器判断当前对象是真的对象还是没有初始化的空间

#### `has_cxx_dtor`

- 初始化第二步

```objective-c
isa.has_cxx_dtor = hasCxxDtor;
```

- `has_cxx_dtor`表示当前对象有 C++ 或者 ObjC 的析构器(destructor)，如果没有析构器就会快速释放内存。

![](http://ww2.sinaimg.cn/large/006y8mN6ly1g67oeaqxwqj31cc0rkq56.jpg)

#### `shiftcls`

- 初始化第三步

```
isa.shiftcls = (uintptr_t)cls >> 3;
```

- `shiftcls`代表类真正的地址，将当前对象对应的类指针存入 `isa` 结构体中了。

> **将当前地址右移三位的主要原因是用于将 Class 指针中无用的后三位清除减小内存的消耗，因为类的指针要按照字节（8 bits）对齐内存，其指针后三位都是没有意义的 0**。

- 地址填进去后，位域变化如下

![](http://ww3.sinaimg.cn/large/006y8mN6ly1g67ok5dzvzj31cc0rk0uz.jpg)

- 其中红色的为**类指针**，这也就验证了我们之前对于初始化 `isa` 时对 `initIsa` 方法的分析是正确的。它设置了 `indexed`、`magic` 以及 `shiftcls`。

#### 其他位域

在 `isa_t` 中，我们还有一些没有介绍的其它 bits，在这个小结就简单介绍下这些 bits 的作用

- `has_assoc`
  - 对象含有或者曾经含有关联引用，没有关联引用的可以更快地释放内存
- `weakly_referenced`
  - 对象被指向或者曾经指向一个 ARC 的弱变量，没有弱引用的对象可以更快释放

- `deallocating`
  - 对象正在释放内存
- `has_sidetable_rc`
  - 对象的引用计数太大了，存不下
- `extra_rc`
  - 对象的引用计数超过 1，会存在这个这个里面，如果引用计数为 10，`extra_rc` 的值就为 9

### isa的应用

#### 获取cls地址

- 由于现在`isa`不在只存放地址了，还多了很多附加内容，因此需要一个专门的方法获取`shiftcls`中的内容
- 我在前面提到了`bits`的用法，现在就是它的用武之地，它通过与`ISA_MASK`按&操作，就能从64位域中，获得`shiftcls`的值，也就是类的地址

```objective-c
#define ISA_MASK 0x00007ffffffffff8ULL
inline Class 
objc_object::ISA() 
{
    return (Class)(isa.bits & ISA_MASK);
}
```

#### class方法

- 进入源码以后，可以查看很多内容的源码

```objective-c
+ (Class)class {
    return self;
}

- (Class)class {
    return object_getClass(self);
}

Class object_getClass(id obj)
{
    if (obj) return obj->getIsa();
    else return Nil;
}
```

- `class`既是类方法又是实例方法，类方法直接返回自身，实例方法返回的就是`isa`中的内容

### isMemberOfClass&&isKindOfClass

```objective-c
+ (BOOL)isMemberOfClass:(Class)cls {
    return object_getClass((id)self) == cls;
}

- (BOOL)isMemberOfClass:(Class)cls {
    return [self class] == cls;
}

+ (BOOL)isKindOfClass:(Class)cls {
    for (Class tcls = object_getClass((id)self); tcls; tcls = tcls->superclass) {
        if (tcls == cls) return YES;
    }
    return NO;
}

- (BOOL)isKindOfClass:(Class)cls {
    for (Class tcls = [self class]; tcls; tcls = tcls->superclass) {
        if (tcls == cls) return YES;
    }
    return NO;
}
```

- 这也没啥好解释的了，结合`class`的内容应该很好理解了
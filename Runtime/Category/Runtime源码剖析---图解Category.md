[TOC]

# Runtime源码剖析---图解Category

> 源码面前，了无秘密

无论一个类设计的多么完美，在未来的需求演进中，都有可能会碰到一些无法预测的情况。那怎么扩展已有的类呢？一般而言，继承和组合是不错的选择。但是在`Objective-C 2.0`中，又提供了`category`这个语言特性，可以动态地为已有类添加新行为。

## 什么是Category？

`category` 的主要作用是为已经存在的类添加方法。

可以把类的实现分开在几个不同的文件里面。这样做有几个显而易见的好处。

- 把不同的功能组织到不同的 `category` 里，减少单个文件的体积，且易于维护；
- 可以由多个开发者共同完成一个类；
- 可以按需加载想要的 `category`；
- 声明私有方法；

不过除了 `apple` 推荐的使用场景，还衍生出了` category` 的其他几个使用场景：

1. 模拟多继承（另外可以模拟多继承的还有 protocol）
2. 把 `framework` 的私有方法公开

### extension

- `extension` 被开发者称之为扩展、延展、匿名分类。`extension`看起来很像一个匿名的 `category`，但是`extension`和`category`几乎完全是两个东西。

- 和 `category`不同的是`extension`不但可以声明方法，还可以声明属性、成员变量。`extension` 一般用于声明私有方法，私有属性，私有成员变量。

- 使用`extension`必须有原有类的源码。`extension`声明的方法、属性和成员变量必须在类的主 `@implementation` 区间内实现，可以避免使用有名称的`category`带来的多个不必要的`implementation`段。

- `extension`很常见的用法，是用来给类添加私有的变量和方法，用于在类的内部使用。例如在 `@interface`中定义为`readonly`类型的属性，在实现中添加`extension`，将其重新定义为 `readwrite`，这样我们在类的内部就可以直接修改它的值，然而外部依然不能调用`setter`方法来修改。

### category 与 extension 的区别

`category` 和 `extension` 的区别:

- `extension`可以添加实例变量，而`category`是无法添加实例变量的。
- `extension`在编译期决议，是类的一部分，`category`则在运行期决议。`extension`在编译期和头文件里的` @interface` 以及实现文件里的 `@implement` 一起形成一个完整的类，`extension` 伴随类的产生而产生，亦随之一起消亡。
- `extension` 一般用来隐藏类的私有信息，你必须有一个类的源码才能为一个类添加 `extension`，所以你无法为系统的类比如 `NSString` 添加 `extension`，除非创建子类再添加 `extension`。而 `category` 不需要有类的源码，我们可以给系统提供的类添加 `category`。
- `extension` 和 `category` 都可以添加属性，但是 `category` 的属性不能生成成员变量和 `getter`、`setter` 方法的实现。

## Category的实质

### category_t 结构体

```objective-c
struct category_t {
    const char *name;//类的名字
    classref_t cls;//类
    struct method_list_t *instanceMethods;//实例方法列表
    struct method_list_t *classMethods;//类方法列表
    struct protocol_list_t *protocols;//协议列表
    struct property_list_t *instanceProperties;//属性列表
    struct property_list_t *_classProperties;

    method_list_t *methodsForMeta(bool isMeta) {
        if (isMeta) return classMethods;
        else return instanceMethods;
    }

    property_list_t *propertiesForMeta(bool isMeta, struct header_info *hi);
};
```

- 从源码基本可以看出我们平时使用categroy的方式，对象方法，类方法，协议，和属性都可以找到对应的存储方式。并且我们发现分类结构体中是不存在成员变量的，因此分类中是不允许添加成员变量的。分类中添加的属性并不会帮助我们自动生成成员变量，只会生成get set方法的声明，需要我们自己去实现。

### 分类如何存储在类对象中

- 我们先写一个分类，看看分类到底是何方妖魔

```objective-c
#import <Foundation/Foundation.h>

@interface BFPerson : NSObject
@property (nonatomic, assign)NSInteger age;
- (void)test;
@end
@interface BFPerson (Work)
@property (nonatomic, assign) double workAge;

- (void)work;
+ (void)workIn:(NSString *)city;
- (void)test;
@end

@interface BFPerson (Study)
@property (nonatomic, copy) NSString *lesson;
@property (nonatomic, assign) NSInteger classNo;

- (void)study;
+ (void)studyLession:(NSString *)les;
- (void)test;
@end
```

- 我们再通过命令行将`BFPerson+Study.m`文件转换成`c++`文件

```objective-c
clang -rewrite-objc Person+Study.m
```

- 在分类转化为c++文件中可以看出_category_t结构体中，存放着类名，对象方法列表，类方法列表，协议列表，以及属性列表。

```objective-c
struct _category_t {
	const char *name;
	struct _class_t *cls;
	const struct _method_list_t *instance_methods;
	const struct _method_list_t *class_methods;
	const struct _protocol_list_t *protocols;
	const struct _prop_list_t *properties;
};
```



## load与initialize的区别

## 关联对象




   * [iOS开发—属性关键字详解](#ios开发属性关键字详解)
      * [@Property](#property)
         * [什么是属性？](#什么是属性)
         * [Property的默认设置](#property的默认设置)
      * [关键字](#关键字)
         * [详解copy](#详解copy)
         * [atomic与nonatomic](#atomic与nonatomic)
         * [readwrite与readonly](#readwrite与readonly)
         * [比较strong与copy](#比较strong与copy)
         * [比较assign、weak、unsafe_unretain](#比较assignweakunsafe_unretain)
         * [@synthesize 和 @dynamic](#synthesize-和-dynamic)

# iOS开发—属性关键字详解

## @Property

### 什么是属性？

- 属性`（property）`是`Objective-C`的一项特性，用于封装对象中的数据。这一特性可以令编译器自动编写与属性相关的存取方法，并且保存为各种实例变量。
- 属性的本质是实例变量与存取方法的结合。`@property = ivar + getter + setter`
  - 实现流程：
  - 每次增加一个属性,系统都会在 `ivar_list`中添加一个成员变量的描述，在` method_list` 中增加` setter` 与` getter` 方法的描述，在 `prop_list `中增加一个属性的描述，计算该属性在对象中的偏移量，然后给出 `setter `与 `getter `方法对应的实现。在 `setter` 方法中从偏移量的位置开始赋值,在 `getter` 方法中从偏移量开始取值,为了能够读取正确字节数,系统对象偏移量的指针类型进行了类型强转。

### Property的默认设置

- 基本数据类型：`atomic`, `readwrite`,` assign`
- 对象类型：`atomic`, `readwrite`, `strong`

>⚠️：注意：考虑到代码可读性以及日常代码修改频率，规范的编码风格中关键词的顺序是：原子性、读写权限、内存管理语义、getter/getter。

## 关键字

| 关键字          | 解释                                                         |
| --------------- | ------------------------------------------------------------ |
| atomic          | 原子性访问                                                   |
| nonatomic       | 非原子性访问，多线程并发访问会提高性能                       |
| readwrite       | 此标记说明属性会被当成读写的，这也是默认属性                 |
| readonly        | 此标记说明属性只可以读，也就是不能设置，可以获取             |
| strong          | 打开ARC时才会使用，相当于retain                              |
| weak            | 打开ARC时才会使用，相当于assign，可以把对应的指针变量置为nil |
| assign          | 不会使引用计数加1，也就是直接赋值                            |
| unsafe_unretain | 与weak类似，但是销毁时不自动清空，容易形成野指针             |
| copy            | 与strong类似，设置方法会拷贝一份副本。一般用于修饰字符串和集合类的不可变版， block用copy修饰 |

### 详解copy

- `copy`语法的作用：

  - 产生副本
    - `copy`返回的是不可变的副本
    - `mutableCopy`返回的是可变的副本
  - 修改了副本并不会影响源对象，修改了源对象，并不会影响副本。

- `copy`使用场景：

  - `NSString`、`NSArray`、`NSictionary` 等等经常使用` copy` 关键字,是因为他们有对应的可变类型:`NSMutableString`、`NSMutableArray`、`NSMutableDictionary`.为确保对象中的属性值不会无意间变动,应该在设置新属性值时拷贝一份,保护其封装性
  - `block`，也经常使用 `copy`
    - 使用 `copy` 是从` MRC` 遗留下来的“传统”,在` MRC` 中,方法内部的 `block` 是在栈区的,使用 `copy` 可以把它放到堆区.

    - 在 `ARC` 中写不写都行:对于`block` 使用 `copy `还是 `strong `效果是一样的,但是建议写上 `copy`,因为这样显示告知调用者“编译器会自动对 block 进行了 `copy` 操作.

- 为什么用`@property` 声明的` NSString`(或` NSArray,NSDictionary`)经常使用 `copy` 关键字,为什么?如果改用`strong`关键字,可能造成什么问题?

  - 因为父类指针可以指向子类对象,使用 `copy` 的目的是为了让本对象的属性不受外界影响,使用 `copy` 无论给我传入是一个可变对象还是不可对象,我本身持有的就是一个不可变的副本. 如果我们使用是 `strong`,那么这个属性就有可能指向一个可变对象,如果这个可变对象在外部被修改了,那么会影响该属性.

- 如何让自定义类可以用 `copy` 修饰符?如何重写带` copy` 关键字的 `setter`?

  - 若想令自己所写的对象具有拷贝功能,则需实现` NSCopying` 协议。如果自定义的对象分为可变版本与不可变版本,那么就要同时实现 `NSCopyiog` 与`NSMutableCopying` 协议,不过一般没什么必要,实现`NSCopying` 协议就够了

  ```objective-c
  - (id)copyWithZone:(NSZone *)zone {
      NSObject *copyObj = [[NSObject allocWithZone:zone] init];
      copyObj.name = self.name;
      return copyObj;
  }
  
  - (void)setName;(Mitchell*)name {
      _name = [name copy];
  }
  ```

### atomic与nonatomic

- 什么是原子性？
  - 并发编程中确保其操作具备整体性，系统其它部分无法观察到中间步骤，只能看到操作前后的结果
- atomic：原子性的，编译器会通过锁定机制确保`setter`和`getter`的完整性。
- nonatomic：非原子性的，不保证`setter`和`getter`的完整性。
- 区别：由于要保证操作完整，`atomic`速度比较慢，线程相对安全；`nonatomic`速度比较快，但是线程不安全。`atomic`也不是绝对的线程安全，当多个线程同时调用`setter`和`getter`时，就会导致获取的值不一样。由于锁定机制开销较大，一般iOS开发中会使用`nonatomic`，而`macOS`中使用`atomic`通常不会有性能瓶颈。
- 如果对这块不太了解，你可以看一下这篇文章[atomic到底不安全在哪？](<http://mrpeak.cn/blog/ios-thread-safety/>)

### readwrite与readonly

- 读写权限不写时默认为 readwrite 。一般可在 .h 里写成readonly，只对外提供读取，在 .m 的Extension中再设置为 readwrite 可进行写入。

```objective-c
//.h文件
@interface MyClass : NSObject
@property (nonatomic, readonly, copy) NSString *name;
@end

//.m文件
@interface MyClass()
@property (nonatomic, readwrite, copy) NSString *name;
@end
```

### 比较strong与copy

- 相同之处：是用于修饰表示拥有关系的对象。
- 不同之处：`strong`复制是多个指针指向同一个地址，而`copy`的复制是每次会在内存中复制一份对象，指针指向不同的地址。
  - `NSString`、`NSArray`、`NSDictionary`等不可变对象用copy修饰，因为有可能传入一个可变的版本，此时能保证属性值不会受外界影响。
- 注意⚠️：若用`strong`修饰`NSArray`，当数组接收一个可变数组，可变数组若发生变化，被修饰的属性数组也会发生变化，也就是说属性值容易被篡改；若用`copy`修饰`NSMutableArray`，当试图修改属性数组里的值时，程序会崩溃，因为数组被复制成了一个不可变的版本。

### 比较assign、weak、unsafe_unretain

- 相同之处：都不是强引用
- 不同之处：`weak`引用的 OC 对象被销毁时, **指针会被自动清空，不再指向销毁的对象，不会产生野指针错误**；`unsafe_unretain`引用的 OC 对象被销毁时, **指针并不会被自动清空, 依然指向销毁的对象，很容易产生野指针错误:EXC_BAD_ACCESS**；`assign`修饰基本数据类型，**内存在栈上由系统自动回收。**

### @synthesize 和 @dynamic

- `@property` 有两个对应的词,一个是`@synthesize`,一个是`@dynamic`。
   如果`@synthesize` 和`@dynamic` 都没写,那么默认的就是
   `@syntheszie var = _var;` 

- `@synthesize` 的语义是如果你没有手动实现 setter 方法和 getter 方法,那么编译器会自动为你加上这两个方法。

- `@dynamic` 告诉编译器:属性的` setter` 与` getter` 方法由用户自己实现,不自动生成。(当然对于 `readonly` 的属性只需提供 `getter` 即可)
   假如一个属性被声明为

- `@dynamic var`；然后你没有提供`@setter` 方法和`@getter` 方法,编译的时候没问题,但是当程序运行到 `instance.var = someVar`,由于缺 `setter`方法会导致程序崩溃;
   或者当运行到 `someVar = instance.var` 时,由于缺` getter` 方法同样会导致崩溃。


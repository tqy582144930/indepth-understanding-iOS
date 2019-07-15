# 概要

- OC中内存管理（也就是引用计数），通俗来说给每个对象添加一个标记值，每次增加一个对象持有他标记值加一，每次减少一个对象持有它标记值减一，最小为0。

# 内存管理的思考方式

## 思考方式

- 想要了解他的方式，你需要牢记一下几句话
  - 自己生成的对象，自己持有。
  - 非自己生成的对象，自己也能持有。
  - 不再需要自己持有的对象时释放。
  - 非自己持有的对象无法释放。

## 对象操作与OC中方法的对应

| 对象操作       | OC中方法                     |
| -------------- | ---------------------------- |
| 生成并持有对象 | alloc/new/copy/mutableCopy等 |
| 持有对象       | retain                       |
| 释放对象       | release                      |
| 废弃对象       | dealloc                      |

你看倒这些方法估计会一脸懵逼，我会在后面通过源码方式解释这几个方法。

## 自己生成的对象，并自己持有

####  alloc

```objective-c
//自己生成并持有对象
id obj = [[NSObject alloc] init];

//指向生成并持有对象的指针被赋值给obj
```

#### new

```objective-c
//自己生成并持有对象
id obj = [[NSObject alloc] init];

//[[NSObject alloc] init] 与 [NSObject new]方法完全一致
```

#### copy与mutableCopy

- 由于这两个比较类似，区别在于，copy生成不可变副本，mutableCopy生成可变更的对象。这就类似于NSArray和NSMutableArray的差异。
- 想要更好的理解copy和mutableCopy建议大家了解一下什么是深复制和浅复制。

##非自己生成的对象，自己也能持有

####retain

```objective-c
//取得非自己生成并持有的对象
id obj = [NSMutableArray array];

//NSMutableArray类变量被赋值给obj，但是obj自己并不持有该对象。
[obj retain];

//现在obj持有该对象

//通过retain方法，非自己生成的对象跟用alloc方法生成并持有的对象一样。
```

## 不再需要自己持有的对象时释放

#### release

```objective-c
//自己生成并持有对象
id obj = [[NSObject alloc] init];

[obj release];
//释放对象
//指向对象的指针仍然被保留在变量obj中，貌似能访问，但对象一经释放绝对不可访问。

//通过release方法，只要是自己持有某个对象，使用release方法都可以释放
```

- 如果要用某个方法生成对象，并将其返还给该方法的调用方

  ```objective-c
  - (id)allocObject {
    //自己生成并持有对象
    id obj = [[NSObject alloc] init];
    return obj;
  }
  
  //取非自己生成并持有的对象obj0
  id obj1 = [obj0 allocObject];
  //自己持有对象
  ```

- 实现取得的对象存在，但自己不持有对象

  ```objective-c
  - (id)object {
    id obj = [[NSObejct alloc] init];
    //自己持有对象
    
    [obj autorelease];
    //取得对象存在，但自己不持有对象
    return obj;
  }
  
  //通过autorelease方法，可以使取得的对象存在，但自己不持有对象
  ```

  - autorelease：使对象在超出指定的生存范围时能够自动并正确的释放（调用release方法）

    ![release和autorelease区别](/Users/tuqiangyao/Desktop/release和autorelease区别.png)

## 无法释放非自己持有的对象

- 对于用alloc/new等方法生成并持有的对象，或是用retain方法持有的对象，由于持有者是自己，所以在不需要该对象的时候需要将其释放。由此以外所得到的对象绝对不能释放。

  - 自己生成并持有对象后，再释放完不再需要的对象之后再次释放。

  ```objective-c
  id obj = [[NSObject alloc] init];
  //自己生成并持有对象
  
  [obj release];
  //对象已释放
  
  [obj release];
  //释放之后再次释放已经非持有的对象，应用程序崩溃
  //崩溃情况：再度废弃已经废弃的对象时崩溃，访问已经废弃的对象时崩溃
  ```

  - 取得对象存在，但自己不持有对象

  ```objective-c
  id obj1 = [obj0 object];
  //取得对象存在，但自己不持有对象
  
  [obj1 release];
  //释放了非自己持有的对象！应用程序会崩溃
  ```

# alloc/retain/release/dealloc底层实现

- 由于苹果没有开源NSObject类的源码，很难了解它的内部实现细节。但是GNUstep时Cocoa框架的互换框架。也就是说，从使用者角度来看，两者的行为和实现方式一样，理解了GNUstep源代码也就间接理解了苹果Cocoa实现。
- 为了明确重点，有的地方对你引用的源代码进行了摘录或在不改变意思的范围内进行了修改

## GNU源码

### alloc

```objective-c
+ (id)alloc {
  return [self allocWithZone:NSDefaultMallocZone()];
}

+ (id)allocWithZone:(NSZone *)z {
  return NSAllocateObject(self, 0, z);
}
//通过allocWithZone：类方法调用了NSAllocateObject函数分配对象

struct obj_layout {
  NSUInteger retained; 
}

inline id 
NSAllocateObject (Clasee aClass, NSUInterger extraBytes, NSZone *zone) {
  int size = 计算容纳对象所需内存大小
  id new = NSZoneMalloc(zone, size);
  memset(new, 0, size);//把分配的内存全部置为0
  new = (id)&((struct obj_layout *) new)(1);
}

//其中NSDefaultMallocZone和NSZoneMalloc中NSZone时为了防止内存碎片化而引入的结构。
//然而现在内存管理本身已经极具效率，使用区域来管理内存反而会引起内存使用效率低下
```

- 去掉NSZone后简化的源码

  ```objective-c
  //使用一个结构体存储一个数据类型为NSUInteger对象retained，也就是引用计数
  struct obj_layout {
      NSUInteger retained;	//引用计数
  };
   
  + （id)alloc
  {
      int size = sizeof(struct obj_layout) + 对象大小;	//size大小对象的是实际大小加上引用计数一个结构体
      struct obj_layout *p = (struct obj_layout *)calloc(1, size);//calloc分配n个长度为size连续空间
    	return (id)(p + 1)	//这里应该是返回该对象的内存地址，但是它返回了p+1，也就是说他返回的是内存空间地址跳过了结构体
  		//也就是说引用计数存在了对象的头地址里
  }
  ```

- 引用计数通过retainCount实例方法获取

  ```objective-c
  id obj = [[NSObject alloc] init];
  NSLog(@"retainCount = %d", [obj retainCount]);	
  ```

  ```objective-c
- (NSUInteger) retainCount
  {
      return NSExtraRefCount(self) + 1;
  }
   
  inline NSUInteger
  NSExtraRefCount(id anObject)
  {
      return ((struct obj_layout *) anObject)[-1].retained;	//先找到对象内存头部，然后减去一个struct obj_layout的大小，然后就能获取到引用计数的地址，然后获取到retained的值。由于分配内存时为0，所以在返回值时需要+1；
  }
  ```

### retain

```objective-c
- (id)retain {
  NSIncrementExtraRefCount(self);
  return self;
}

inline void 
NSIncrementExtraRefCount (id anObject) {
  if (((struct obj_layout *) anObject)[-1].retained == UINT_MAX - 1) {
    [NSException raise: NSInternalInconsistencyException format:@"NSIncrementExtraRefCount () asked to increment too far"];
  }//如果retained变量超过最大值时发生异常的代码
  ((struct obj_layout *) anObject)[-1].retained++;
}
```

### release

```objective-c
- (void)release {
  if (NSDecrementExtraRefCountWasZero(self)) {
    [self dealloc];
  }
}

BOOL
NSDecrementExtraRefCountWasZero(id anObject) {
  if((struct obj_layout *) anObject)[-1].retained == 0) {//如果引用计数已经为0时，调用release方法直接废弃该对象
		return YES;
  } else {
    (struct obj_layout *) anObject)[-1].retained--;//如果引用计数不为0，引用计数减一；
    return NO;
  }
}
```

### dealloc

```objective-c
- (void)dealloc {
  NSDeallocateObject(self);
}

inline void
NSDeallocateObject(id anObject) {
  struct obj_layout *o = &((struct obj_layout *) anobject)[-1];
  free(o);//仅仅废弃有alloc分配的内存
}
```

## 苹果实现

- 作者通过添加断点的方式 大致还原了上述方法所调用的函数，本质上与GNU没有区别

  ```objective-c
  //下面展示retainCount/retain/release方法执行时所调用的方法和函数
  - retainCount
  __CFDoExternRefOperation
  CFBasicHashGetCountOfKey
    
  - retain
  __CFDoExternRefOperation
  CFBasicHashAddValue
  
  - release
  __CFDoExternRefOperation
  CFBasicHashRemoveValue
  (CFBasicHashRemoveValue返回0时，-release调用dealloc)
    
  //你会发现每个方法都通过同一个__CFDoExternRefOperation函数，下面我们来看看简化后的__CFDoExternRefOperation函数
    
  int __CFDoExternRefOperation(uintptr_t op, id obj)  {
    CFBasicHashRef table = 取得对象对应的散列表（obj）;//这里的散列表就是我们常说的哈希表
    
    swithch(op) {
      case OPERARION_retainCount;
      	count = CFBasicHashGetCountOfKey(table, obj);
      	return count;
      case OPERARION_retain
        CFBasicHashAddValue(table, obj);
      	return obj;
      case OPERATION_release
        count = CFBasicHashRemoveValue(table, obj);
      	return 0 == count;
    }
  }
  ```

  - 可以通过函数以及由函数的调用看出，苹果的实现大概率采用的是哈希表的方式来管理引用计数，GNUstep是将引用计数保存在对象占用内存块头部地址。

    - 内存块管理好处：
      1. 少量代码即可完成
      2. 能够统一管理引用计数用内存块和对象用内存块

    - 哈希表管理好处：
      1. 对象用内存块的分配无需考虑内存块头部
      2. 引用计数表中存有内存块的地址，根据地址可以找到内存块

    - 最重要就是最后一点，即使我的内存块损坏，只要我的引用计数表还在，我就能通过计数表找到内存的位置。

# autorelease

## 什么是autorelease

- 从 名字上看就是自动释放，看起来很像ARC，但是他更类似c语言中自动变量的特性

- autorelease，当超出其作用域时，对象实例的release实例方法被调用

  ![](/Users/tuqiangyao/Desktop/屏幕快照 2019-07-15 上午9.13.38.png)

- autorelease方法的实现是通过NSAutoreleasePool的生存周期来实现的，当废弃NSAutoreleasePool时所有对象都将调用release方法，所以学会使用NSAutoreleasePool就理解了autorelease

  ```objective-c
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  id obj = [[NSObject allc] init];
  
  [obj autorelease];
  [pool drain];
  //调用最后一个方法后，相当于obj release
  ```

- Cocoa框架中也有很多类方法用于返回autorelease对象

  ```objective-c
  id array = [NSMutable arrayWithCapacity:1];
  
  //实质上是
  id array = [[NSMutable arrayWithCapacity:1] autorelease];
  ```

## GNU源码

- ```objective-c
  - (id)autorelease {
    [NSAutoreleasePool addObject:self];
  }
  
  //下面通过简化后的源码来展示addObject
  + (void)addObject:(id)anObj {
    NSAutoreleasePool *pool = 取得正在使用的NSAutoreleasePool对象
    if (pool != nil) {
      [pool addObject:anObj];
    } else {
      NSLog(@"NSAutoreleasePool对象非存在状态下调用autorelease")；
    }
  }
  
  //如果嵌套生成或持有NSAutoreleasePool对象，理所当然会使用最内侧的对象。
  //pool就好像一个可变数组，每次你autorelease一个对象都会被添加到pool数组中
  ```

## 苹果实现

```objective-c
class AutoreleasePoolPage {
  static inline void *push() {
    相当于生成或持有NSAutoreleasePoolPage对象
  }
  
  static inline void *po() {
    相当于废弃NSAutoreleasePool类对象
      releaseAll();
  }
  
  static inline id autorelease (id obj) {
    相当于NSAutoreleasePool类 的addObject类方法
    AutoreleasePoolPage *autoreleasePoolPage = 取得正在使用的AutoreleasePoolPage实例 ；
    autoreleasePoolPage->add(obj)
  }
  
  id *add(id obj) {
    将对象追加到内部数组
  }
  
  void releaseAll() {
    调用内部数组中对象 的release方法
  }
}
```


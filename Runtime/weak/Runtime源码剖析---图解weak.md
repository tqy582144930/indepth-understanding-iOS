[TOC]

# Runtime源码剖析---图解引用计数与weak

> 在iOS开发过程中，会经常使用到一个修饰词“weak”，使用场景大家都比较清晰，用于一些对象相互引用的时候，避免出现强引用，对象不能被释放，出现内存泄露的问题。
>
> **weak 关键字的作用弱引用，所引用对象的计数器不会加一，并在引用对象被释放的时候自动被设置为 nil。**

## 前言

### 什么是引用计数?

- `Objective-C`通过`retainCount`的机制来决定对象是否需要释放。 每次`runloop`迭代结束后，都会检查对象的 `retainCount`，如果`retainCount`等于0，就说明该对象没有地方需要继续使用它，可以被释放掉了。无论是手动管理内存，还是`ARC`机制，都是通过对`retainCount`来进行内存管理的。
- 内存中每一个对象都有一个属于自己的引用计数器。当某个对象A被另一个家伙引用时，A的引用计数器就+1,如果再有一个家伙引用到A，那么A的引用计数器就再+1。当其中某个家伙不再引用A了，A的引用计数器会-1。直到A的引用计数减到了0,那么就没有人再需要它了，就是时候把它释放掉了。

> 在引用计数中，每一个对象负责维护对象所有引用的计数值。当一个新的引用指向对象时，引用计数器就递增，当去掉一个引用时，引用计数就递减。当引用计数到零时，该对象就将释放占有的资源。

### 什么是循环引用？

- 循环引用发生的条件：
  1. 两个对象互相强引用对方
  2. 该对象持有其自身（自己引用自己）

- 这个时候就提出了`__weak`修饰符，提供弱引用，不能持有对象实例，若该对象被废弃，则此弱引用将自动失效且处于`nil`被赋值的状态

> 对前面两个问题进行总结：
>
> 1. 如何实现的引用计数管理,控制加一减一和释放？
> 2. 如何维护weak指针防止野指针错误？
>
> - 这也就是我们这篇文章要解决的主要问题，下面我们就会针对上面两个问题一一解释。

## 引用计数

### 引用计数的存储

> 有些对象如果支持使用 `TaggedPointer`，苹果会直接将其指针值作为引用计数返回；如果当前设备是 64 位环境并且使用 `Objective-C 2.0`，那么‘一些’对象会使用其 `isa` 指针的一部分空间来存储它的引用计数；否则 `Runtime` 会使用一张散列表来管理引用计数。

- 我们知道，对于纯量类型的变量，是没有引用计数的，因为不是对象，其申请的变量存储在栈上，由系统来负责管理。

- 另外一种类型，是前面讲过的 `Tagged Pointer` 小对象，包括 `NSNumber`、`NSString`、`NSDate` 等几个类的变量。它们也是存储在栈上，当然也没有引用计数。

![引用计数存储方式](https://tva1.sinaimg.cn/large/006y8mN6ly1g7s9ic91gij315o0i641q.jpg)

- 关于对象类型的引用计数，其存在的两种方式

![两种存储方式](https://tva1.sinaimg.cn/large/006y8mN6ly1g7s9iwpfwhj319w0e0juz.jpg)

#### isa指针中的引用计数

- 如果你对isa不够熟悉的话，可以看看我这篇文章[Runtime源码剖析---图解对象、类与isa](https://www.jianshu.com/p/a0256f1d80f8)
- 简单来说，就是isa再32位之前为指针，在64位操作系统之后就不仅仅是个指针，是个联合体，它一部分负责存储地址，另一部分可以存储其他的信息。这样做可以提高了内存的使用率、减少了不必要的开销。
- 下面我给出isa的源码

```objective-c
union isa_t {
    isa_t() { }
    isa_t(uintptr_t value) : bits(value) { }

    Class cls;
    // 相当于是unsigned long bits;
    uintptr_t bits;
#if defined(ISA_BITFIELD)
    // 这里的定义在isa.h中，如下(注意uintptr_t实际上就是unsigned long)
//    uintptr_t nonpointer        : 1;                                         \
//    uintptr_t has_assoc         : 1;                                         \
//    uintptr_t has_cxx_dtor      : 1;                                         \
//    uintptr_t shiftcls          : 44; /*MACH_VM_MAX_ADDRESS 0x7fffffe00000*/ \
//    uintptr_t magic             : 6;                                         \
//    uintptr_t weakly_referenced : 1;                                         \
//    uintptr_t deallocating      : 1;                                         \
//    uintptr_t has_sidetable_rc  : 1;                                         \
//    uintptr_t extra_rc          : 8
    struct {
        ISA_BITFIELD;  // defined in isa.h
    };
#endif
};
```

- 下面列出`isa`指针中变量对应的含义

| 变量名            |                             含义                             |
| ----------------- | :----------------------------------------------------------: |
| indexed           |    0 表示普通的 `isa` 指针，1 表示使用优化，存储引用计数     |
| has_assoc         | 表示该对象是否包含 associated object，如果没有，则析构时会更快 |
| has_cxx_dtor      | 表示该对象是否有 C++ 或 ARC 的析构函数，如果没有，则析构时更快 |
| shiftcls          |                           类的指针                           |
| magic             |    固定值为 0xd2，用于在调试时分辨对象是否未完成初始化。     |
| weakly_referenced |    表示该对象是否有过 `weak` 对象，如果没有，则析构时更快    |
| deallocating      |                    表示该对象是否正在析构                    |
| has_sidetable_rc  |     表示该对象的引用计数值是否过大无法存储在 `isa` 指针      |
| extra_rc          |                  存储引用计数值减一后的结果                  |

- 我们发现最后两个变量，就和我们引用计数相关。
- 最后我们用一张图来看看具体布局

![isa布局](https://tva1.sinaimg.cn/large/006y8mN6ly1g7s9sk6tkqj31i40u0wml.jpg)

#### Side Table里的引用计数

- Side Table 在系统中的结构如下：

![Side Table在系统中结构](https://tva1.sinaimg.cn/large/006y8mN6ly1g7s9v8yionj30pu0a6goe.jpg)

- 而每一个`Side Table`中引用计数的结构

![Side Table中引用计数结构](https://tva1.sinaimg.cn/large/006y8mN6ly1g7s9vznxhcj315i0k00w6.jpg)

- 现在我们只需要了解一下有这个结构就够了，我会在后面仔细剖析如何存储和如何调用的。

### 引用计数的管理

#### 管理引用计数的方法

![管理引用计数的方法](https://tva1.sinaimg.cn/large/006y8mN6ly1g7sa2hwbgkj30wm0ecwg0.jpg)

#### 获取引用计数

##### 非ARC环境下

- 在非ARC环境下通过`retainCount`方法来获取引用计数

```c++
- (NSUInteger)retainCount {
    return ((id)self)->rootRetainCount();
}
```

该方法内部调用了`rootRetainCount`函数

```c++
inline uintptr_t 
objc_object::rootRetainCount()
{
  	//1.如果是Tagged Pointer，直接返回指针
    if (isTaggedPointer()) return (uintptr_t)this;

    sidetable_lock();
    isa_t bits = LoadExclusive(&isa.bits);
    ClearExclusive(&isa.bits);
  	//如果是优化后的isa
    if (bits.nonpointer) {
      	//取出isa中的retainCount+1；
        uintptr_t rc = 1 + bits.extra_rc;
        if (bits.has_sidetable_rc) {
          	//如果Side Table还有存储，则取出累加返回
            rc += sidetable_getExtraRC_nolock();
        }
        sidetable_unlock();
        return rc;
    }

    sidetable_unlock();
    return sidetable_retainCount();
}
```

- 如果它既不是`Tagged Point`对象，`isa`指针中也没有存储引用计数，这个时候就会走`sidetable_retainCount`这个方法。

```c++
uintptr_t
objc_object::sidetable_retainCount()
{
  	//先从SideTables中取出对应的SideTable对象
    SideTable& table = SideTables()[this];

    size_t refcnt_result = 1;
    
    table.lock();
  	//通过table对象中的refcnts，在通过传入的地址，找到对应的引用计数
    RefcountMap::iterator it = table.refcnts.find(this);
    if (it != table.refcnts.end()) {
        // this is valid for SIDE_TABLE_RC_PINNED too
        refcnt_result += it->second >> SIDE_TABLE_RC_SHIFT;
    }
    table.unlock();
    return refcnt_result;
}
```

- 这里有个疑惑，为什么要把取出来的数据进行右移位操作呢？
  - 因为在`refcnts`中存储的并不是直接就是引用计数，而是可以理解为一个联合体，在他的低2位存储其他特殊信心，引用计数从第三位开始存储，所以取出来的时候需要右移操作。

##### ARC环境下

- 在 `ARC `时代除了使用` Core Foundation` 库的 `CFGetRetainCount()` 方法，也可以使用 `Runtime` 的 `_objc_rootRetainCount(id obj)` 方法来获取引用计数，此时需要引入 `<objc/runtime.h>` 头文件。这个函数也是调用 `objc_object` 的 `rootRetainCount()` 方法：所以分析同上。

![retainCount总结](https://tva1.sinaimg.cn/large/006y8mN6ly1g7sam82q3lj316o06sdhp.jpg)

![获取引用计数的方式](https://tva1.sinaimg.cn/large/006y8mN6ly1g7saoyuabaj31ay0jkqa4.jpg)

#### retain的实现

```c++
inline id 
objc_object::retain()
{
    assert(!isTaggedPointer());

    if (fastpath(!ISA()->hasCustomRR())) {
        return rootRetain();
    }

    return ((id(*)(objc_object *, SEL))objc_msgSend)(this, SEL_retain);
}
```

- 这个方法内部会调用`rootRetain()` 方法

```c++
ALWAYS_INLINE id 
objc_object::rootRetain(bool tryRetain, bool handleOverflow)
{
  	//Tagged Pointer对象直接返回
    if (isTaggedPointer()) return (id)this;

    bool sideTableLocked = false;
  	//transcribeToSideTable用于表示extra_rc是否溢出，默认为false
    bool transcribeToSideTable = false;
    isa_t oldisa;
    isa_t newisa;
    do {
        transcribeToSideTable = false;
        oldisa = LoadExclusive(&isa.bits);//将isa提取出来
        newisa = oldisa;
      	//如果isa没有优化，直接从sideTable中返回引用计数
        if (slowpath(!newisa.nonpointer)) {
            ClearExclusive(&isa.bits);
            if (!tryRetain && sideTableLocked) sidetable_unlock();
            if (tryRetain) return sidetable_tryRetain() ? (id)this : nil;
            else return sidetable_retain();
        }
        //如果对象正在析构，则直接返回nil
        if (slowpath(tryRetain && newisa.deallocating)) {
            ClearExclusive(&isa.bits);
            if (!tryRetain && sideTableLocked) sidetable_unlock();
            return nil;
        }
        uintptr_t carry;
      	//isa指针中的extra_rc+1；
        newisa.bits = addc(newisa.bits, RC_ONE, 0, &carry);  // extra_rc++

        if (slowpath(carry)) {
          	//有进位，表示溢出，extra_rc已经不能存储在isa指针中了
            // newisa.extra_rc++ overflowed
            if (!handleOverflow) {
              	//如果不处理溢出情况，则在这里会递归调用一次，再进来的时候
              	//handleOverflow会被rootRetain_overflow设置为true，从而直接进入到下面的溢出处理流程
                ClearExclusive(&isa.bits);
                return rootRetain_overflow(tryRetain);
            }
            // Leave half of the retain counts inline and 
            // prepare to copy the other half to the side table.
          	/*
          		溢出处理
          		1.先将extra_rc中引用计数减半，继续存储在isa中
          		2.同时把has_sidetable_rc设置为true，表明借用了sideTable存储
          		3.将另一半的引用计数，存放在sideTable中
          	*/
            if (!tryRetain && !sideTableLocked) sidetable_lock();
            sideTableLocked = true;
            transcribeToSideTable = true;
            newisa.extra_rc = RC_HALF;
            newisa.has_sidetable_rc = true;
        }
    } while (slowpath(!StoreExclusive(&isa.bits, oldisa.bits, newisa.bits)));

    if (slowpath(transcribeToSideTable)) {
        // Copy the other half of the retain counts to the side table.
      	//isa的extra_rc溢出，将一半refer count值放到SideTable中
        sidetable_addExtraRC_nolock(RC_HALF);
    }

    if (slowpath(!tryRetain && sideTableLocked)) sidetable_unlock();
    return (id)this;
}
```

- 总结：
  - **Tagged Pointer 对象，没有 retain。**
  - **isa 中 extra_rc 若未溢出，则累加 1。如果溢出，则将 isa 和 side table 对半存储。**

![retain操作](https://tva1.sinaimg.cn/large/006y8mN6ly1g7sbjjvcgzj317609s77h.jpg)

#### release的实现

```c++
inline void
objc_object::release()
{
    assert(!isTaggedPointer());

    if (fastpath(!ISA()->hasCustomRR())) {
        rootRelease();
        return;
    }

    ((void(*)(objc_object *, SEL))objc_msgSend)(this, SEL_release);
}
```

- 这个方法内部会调用`rootRelease`

```c++
ALWAYS_INLINE bool 
objc_object::rootRelease(bool performDealloc, bool handleUnderflow)
{
  	//如果是Tagged Pointer，直接返回false，不需要dealloc
    if (isTaggedPointer()) return false;
    bool sideTableLocked = false;
    isa_t oldisa;
    isa_t newisa;

 retry:
    do {
        oldisa = LoadExclusive(&isa.bits);
        newisa = oldisa;
      	//如果isa为优化，直接调用sideTable的release函数
        if (slowpath(!newisa.nonpointer)) {
            ClearExclusive(&isa.bits);
            if (sideTableLocked) sidetable_unlock();
            return sidetable_release(performDealloc);
        }
        //将当前isa指针中存储的引用计数减1，如果未溢出，返回false，不需要dealloc
        uintptr_t carry;
        newisa.bits = subc(newisa.bits, RC_ONE, 0, &carry);  // extra_rc--
        if (slowpath(carry)) {
            //减1下导致溢出，则需要从side Table借位，跳转到溢出处理
            goto underflow;
        }
    } while (slowpath(!StoreReleaseExclusive(&isa.bits, 
                                             oldisa.bits, newisa.bits)));

    if (slowpath(sideTableLocked)) sidetable_unlock();
    return false;

 underflow:
    newisa = oldisa;
    if (slowpath(newisa.has_sidetable_rc)) {
      	//Side Table存在引用计数
        if (!handleUnderflow) {
          	//如果不处理溢出，此处只会调用一次，handleUnderflow会被rootRelease_underflow设置为ture
          	//再次进入，则会直接进入溢出处理流程
            ClearExclusive(&isa.bits);
            return rootRelease_underflow(performDealloc);
        }
        if (!sideTableLocked) {
            ClearExclusive(&isa.bits);
            sidetable_lock();
            sideTableLocked = true;
            // Need to start over to avoid a race against 
            // the nonpointer -> raw pointer transition.
            goto retry;
        }

        //尝试从SideTable中取出，当前isa能存储引用计数最大值的一半的引用计数  
        size_t borrowed = sidetable_subExtraRC_nolock(RC_HALF);
      	//如果取出引用计数大于0
        if (borrowed > 0) {
            //将取出的引用计数减一，并保存到isa中，保存成功返回false（未被销毁）
            newisa.extra_rc = borrowed - 1;  // redo the original decrement too
            bool stored = StoreReleaseExclusive(&isa.bits, 
                                                oldisa.bits, newisa.bits);
            if (!stored) {
                //保存到isa中失败，再次尝试保存
                isa_t oldisa2 = LoadExclusive(&isa.bits);
                isa_t newisa2 = oldisa2;
                if (newisa2.nonpointer) {
                    uintptr_t overflow;
                    newisa2.bits = 
                        addc(newisa2.bits, RC_ONE * (borrowed-1), 0, &overflow);
                    if (!overflow) {
                        stored = StoreReleaseExclusive(&isa.bits, oldisa2.bits, 
                                                       newisa2.bits);
                    }
                }
            }

            if (!stored) {
                //如果还是失败，则将借出来的一半retain count，重新返回给side Table
              	//并且重新从2开始尝试
                sidetable_addExtraRC_nolock(borrowed);
                goto retry;
            }

            // Decrement successful after borrowing from side table.
            // This decrement cannot be the deallocating decrement - the side 
            // table lock and has_sidetable_rc bit ensure that if everyone 
            // else tried to -release while we worked, the last one would block.
            sidetable_unlock();
            return false;
        }
        else {
            // Side table is empty after all. Fall-through to the dealloc path.
        }
    }

    //以上流程执行完了，则需要销毁对象，调用dealloc
    if (slowpath(newisa.deallocating)) {
      	//对象正在销毁
        ClearExclusive(&isa.bits);
        if (sideTableLocked) sidetable_unlock();
        return overrelease_error();
        // does not actually return
    }
    newisa.deallocating = true;
    if (!StoreExclusive(&isa.bits, oldisa.bits, newisa.bits)) goto retry;
    if (slowpath(sideTableLocked)) sidetable_unlock();
    __sync_synchronize();
  	//销毁对象
    if (performDealloc) {
        ((void(*)(objc_object *, SEL))objc_msgSend)(this, SEL_dealloc);
    }
    return true;
}
```



## weak


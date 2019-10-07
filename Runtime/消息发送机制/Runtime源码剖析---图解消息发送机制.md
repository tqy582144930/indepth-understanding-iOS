

   * [Rumtime源码剖析---图解消息发送机制](#Runtime源码剖析---图解消息发送机制)
      * [前言](#前言)
         * [预备知识](#预备知识)
         * [选择子SEL](#选择子sel)
         * [objc_msgSend()的执行流程](#objc_msgsend的执行流程)
      * [消息发送阶段](#消息发送阶段)
      * [动态解析阶段](#动态解析阶段)
         * [动态解析流程](#动态解析流程)
         * [动态解析例子](#动态解析例子)
      * [消息转发阶段](#消息转发阶段)
         * [消息转发流程](#消息转发流程)
         * [消息转发例子](#消息转发例子)

# Runtime源码剖析---图解消息发送机制

> 源码面前，了无秘密

## 前言

### 预备知识

- 在阅读这篇文章之前，你需要了解一些基础知识：

  1. 在 `Objective-C `中的“方法调用”其实应该叫做消息传递

     - 我们为什么需要消息传递？
     - 在很多语言，比如 C ，调用一个方法其实就是跳到内存中的某一点并开始执行一段代码。没有任何动态的特性，因为这在编译时就决定好了。而在 `Objective-C` 中，`[object foo]` 语法并不会立即执行 `foo `这个方法的代码。它是在运行时给` object` 发送一条叫 `foo` 的消息。这个消息，也许会由 `object `来处理，也许会被转发给另一个对象，或者不予理睬假装没收到这个消息。多条不同的消息也可以对应同一个方法实现。这些都是在程序运行的时候决定的。

  2. `[receiver message]`会被翻译为 `objc_msgSend(receiver, @selector(message))`

  3.  关于选择子`SEL`的知识，这个我会在下面给大家简略介绍

  4. 方法的存储位置，什么是缓存、方法查找方式

     > 如果不了解，可以看我下一篇文章。

### 选择子SEL

- 在 Objective-C 中，所有的消息传递中的“消息“都会被转换成一个 `selector` 作为 `objc_msgSend` 函数的参数：

  ```objective-c
  [object hello] -> objc_msgSend(object, @selector(hello))
  ```

- `Objective-C `在编译的时候, 会根据方法的名字(包括参数序列),生成一个用来区分这个方法的唯一的一个`ID`,这个 `ID` 就是` SEL` 类型的。我们需要注意的是,只要方法的名字(包括参数序列)相同,那么它们的 `ID `都是相同的。就是说,不管是超类还是子类,不管是有没有超类和子类的关系,只要名字相同那么 `ID` 就是一样的

```objective-c
///Person.m
#import "Person.h"
@implementation Person
- (void)eat {
    NSLog(@"Person EAT");
}

- (void)eat:(NSString *)str {
    NSLog(@"Person EATSTR");
}

- (void)dayin {
    NSLog(@"dayin");
    SEL sell1 = @selector(eat:);
    NSLog(@"sell1:%p", sell1);
    SEL sell2 = @selector(eat);
    NSLog(@"sell2:%p", sell2);
}
@end

///main.m
#import <Foundation/Foundation.h>
#include "Student.h"
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Person *newPerson = [[Person alloc] init];
        [newPerson dayin];
    }
    return 0;
}

//结果
//dayin
//sell1:0x100000f63
//sell2:0x100000f68
```

- 这里要注意，`@selector`等同于是把方法名翻译成sel方法签名，它只关心方法名和参数个数，在`dayin`方法里，可以在`eat`后加上任意个:都有效果

- 这个生成`SEL`的过程是固定的，因为它只是一个表明方法的`ID`，不管是在任何类里去写这个`dayin`方法，还是运行好几次，这个`SEL`都是固定这个

- 这里我们可以直观的看出，`SEL`不关心返回值与参数的数据类型

- 不同的类可以拥有相同的方法，因为`SEL`的存储是存在这个类的`methods`里的

  > 总结：在`Runtime`中维护了一个`SEL`的表，这个表存储`SEL`不按照类来存储，只要相同的`SEL`就会被看做一个，并存储到表中。在项目加载时，会将所有方法都加载到这个表中，而动态生成的方法也会被加载到表中。

- **现在我们了解什么是SEL之后，接下来我们就需要探究为什么给消息接受者发送消息之后，就能调用函数，这个过程之间发生了什么？所以接下来的问题就变成了去探究objc_msgSend()这个函数的调用过程。**

### objc_msgSend()的执行流程

1. 消息发送阶段：负责从类及父类的缓存列表及方法列表查找方法。
2. 动态解析阶段：如果消息发送阶段没有找到方法，则会进入动态解析阶段，负责动态的添加方法实现。
3. 消息转发阶段：如果也没有实现动态解析方法，则会进行消息转发阶段，将消息转发给可以处理消息的接受者来处理。

- 接下来我们通过源码探寻消息发送者三个阶段分别是如何实现的。

  > **在runtime源码中搜索`_objc_msgSend`查看其内部实现，在`objc-msg-arm64.s`汇编文件可以知道`_objc_msgSend`函数的实现**

- 我先通过一张图来具体展示消息传递流程，**你可以先大致把图浏览一遍，再看我对每一步的详解，也可以先看每一步的详解，如果理不清逻辑关系了，可以回来再看看图，争取通过图文并茂的方式，让你掌握**

  > **我知道你们乍一看这张图就会觉得太难了，就不想再接着看了，一个优秀的程序员就必须有知难而上的精神，我会通过源码、文字、图片结合的方式，尽可能做到清楚、明了，让你顺利的掌握这个知识点。**

![objc_msgSend流程 ](https://tva1.sinaimg.cn/large/006y8mN6ly1g6apw8y7ocj30u012on67.jpg)

## 消息发送阶段

- **我会在重点源码面前加上⚠️这个符号**

```assembly
	//从这里开始
	ENTRY _objc_msgSend
	UNWIND _objc_msgSend, NoFrame
	//p0寄存器，消息接收者
⚠️cmp	p0, #0			// nil check and tagged pointer check
#if SUPPORT_TAGGED_POINTERS
⚠️b.le	LNilOrTagged	//b是跳转，le是小于等于，也就是p0小于等于0时，跳转到LNilOrTagged
#else
	b.eq	LReturnZero
#endif
	ldr	p13, [x0]		// p13 = isa
	GetClassFromIsa_p16 p13		// p16 = class
LGetIsaDone:
⚠️CacheLookup NORMAL		//缓存查找

#if SUPPORT_TAGGED_POINTERS

LNilOrTagged:-------------------如果接收者为nil，跳转至此---------------------------

⚠️b.eq	LReturnZero		//如果消息接收者为空，直接退出这个函数

	// tagged
	adrp	x10, _objc_debug_taggedpointer_classes@PAGE
	add	x10, x10, _objc_debug_taggedpointer_classes@PAGEOFF
	ubfx	x11, x0, #60, #4
	ldr	x16, [x10, x11, LSL #3]
	adrp	x10, _OBJC_CLASS_$___NSUnrecognizedTaggedPointer@PAGE
	add	x10, x10, _OBJC_CLASS_$___NSUnrecognizedTaggedPointer@PAGEOFF
	cmp	x10, x16
	b.ne	LGetIsaDone

	// ext tagged
	adrp	x10, _objc_debug_taggedpointer_ext_classes@PAGE
	add	x10, x10, _objc_debug_taggedpointer_ext_classes@PAGEOFF
	ubfx	x11, x0, #52, #8
	ldr	x16, [x10, x11, LSL #3]
	b	LGetIsaDone
// SUPPORT_TAGGED_POINTERS
#endif

LReturnZero:
	// x0 is already zero
	mov	x1, #0
	movi	d0, #0
	movi	d1, #0
	movi	d2, #0
	movi	d3, #0
	ret

	END_ENTRY _objc_msgSend
	//结束
```

1. 首先从`cmp	p0, #0`开始，这里p0是寄存器，里面是消息接收者。`b.le LNilOrTagged`，`b`是跳转的意思，`le`是如果`p0`小于等于0，总体意思是若`p0`小于等于0，则跳转到`LNilOrTagged`(我在上述代码中已标出),执行`b.eq LReturnZero`就是直接退出程序。
2. 如果消息接收者不为nil，汇编代码继续执行，到`CacheLookup NORMAL`,通过字面意思可以知道这是从缓存中查找方法的实现。我们在本文件中搜索一下：

```assembly
//开始
.macro CacheLookup  //这里是一个宏定义
	// p1 = SEL, p16 = isa
	ldp	p10, p11, [x16, #CACHE]	// p10 = buckets, p11 = occupied|mask
#if !__LP64__
	and	w11, w11, 0xffff	// p11 = mask
#endif
	and	w12, w1, w11		// x12 = _cmd & mask
	add	p12, p10, p12, LSL #(1+PTRSHIFT)
		             // p12 = buckets + ((_cmd & mask) << (1+PTRSHIFT))

	ldp	p17, p9, [x12]		// {imp, sel} = *bucket
1:	cmp	p9, p1			// if (bucket->sel != _cmd)
	b.ne	2f			//     scan more
	CacheHit $0			// call or return imp
	
2:	// not hit: p12 = not-hit bucket
	CheckMiss $0			// miss if bucket->sel == 0
	cmp	p12, p10		// wrap if bucket == buckets
	b.eq	3f
	ldp	p17, p9, [x12, #-BUCKET_SIZE]!	// {imp, sel} = *--bucket
	b	1b			// loop

3:	// wrap: p12 = first bucket, w11 = mask
	add	p12, p12, w11, UXTW #(1+PTRSHIFT)
		                        // p12 = buckets + (mask << 1+PTRSHIFT)

	// Clone scanning loop to miss instead of hang when cache is corrupt.
	// The slow path may detect any corruption and halt later.

	ldp	p17, p9, [x12]		// {imp, sel} = *bucket
1:	cmp	p9, p1			// if (bucket->sel != _cmd)
	b.ne	2f			//     scan more
	
⚠️CacheHit $0-------------//缓存命中，在缓存中找到了对应的方法及其实现-----------------
	
2:	// not hit: p12 = not-hit bucket
⚠️CheckMiss $0------------//在缓存中没有找到对应的方法-------------------------------
	cmp	p12, p10		// wrap if bucket == buckets
	b.eq	3f
	ldp	p17, p9, [x12, #-BUCKET_SIZE]!	// {imp, sel} = *--bucket
	b	1b			// loop

3:	// double wrap
	JumpMiss $0
	
.endmacro
//结束
```

3. 在缓存中找到了方法那就直接调用，**下面主要看一下从缓存中没有找到方法怎么办。没有找到方法则会执行`CheckMiss`，**我们搜索一下它的汇编

```assembly
//开始
.macro CheckMiss//这是一个宏定义
	// miss if bucket->sel == 0
.if $0 == GETIMP
	cbz	p9, LGetImpMiss
.elseif $0 == NORMAL
⚠️cbz	p9, __objc_msgSend_uncached//在缓存中没有找到方法时，主要执行这个方法
.elseif $0 == LOOKUP
	cbz	p9, __objc_msgLookup_uncached
.else
.abort oops
.endif
.endmacro

.macro JumpMiss
.if $0 == GETIMP
	b	LGetImpMiss
.elseif $0 == NORMAL
	b	__objc_msgSend_uncached
.elseif $0 == LOOKUP
	b	__objc_msgLookup_uncached
.else
.abort oops
.endif
.endmacro
//结束
```

- 搜索`__objc_msgSend_uncached`:

```assembly
STATIC_ENTRY __objc_msgSend_uncached
	UNWIND __objc_msgSend_uncached, FrameWithNoSaves

	// THIS IS NOT A CALLABLE C FUNCTION
	// Out-of-band p16 is the class to search
	
⚠️MethodTableLookup--------//去方法列表中去查找方法---------------
	TailCallFunctionPointer x17
	
	END_ENTRY __objc_msgSend_uncached
```

- 通过`MethodTableLookup`这个字面名称我们就大概知道这是从方法列表中去查找方法。我们再查看一下它的结构：

```assembly
//开始
.macro MethodTableLookup
	
	// push frame
	SignLR
	stp	fp, lr, [sp, #-16]!
	mov	fp, sp

	// save parameter registers: x0..x8, q0..q7
	sub	sp, sp, #(10*8 + 8*16)
	stp	q0, q1, [sp, #(0*16)]
	stp	q2, q3, [sp, #(2*16)]
	stp	q4, q5, [sp, #(4*16)]
	stp	q6, q7, [sp, #(6*16)]
	stp	x0, x1, [sp, #(8*16+0*8)]
	stp	x2, x3, [sp, #(8*16+2*8)]
	stp	x4, x5, [sp, #(8*16+4*8)]
	stp	x6, x7, [sp, #(8*16+6*8)]
	str	x8,     [sp, #(8*16+8*8)]

	// receiver and selector already in x0 and x1
	mov	x2, x16
⚠️bl	__class_lookupMethodAndLoadCache3//通过这个方法来查找缓存和方法列表

	// IMP in x0
	mov	x17, x0
	
	// restore registers and return
	ldp	q0, q1, [sp, #(0*16)]
	ldp	q2, q3, [sp, #(2*16)]
	ldp	q4, q5, [sp, #(4*16)]
	ldp	q6, q7, [sp, #(6*16)]
	ldp	x0, x1, [sp, #(8*16+0*8)]
	ldp	x2, x3, [sp, #(8*16+2*8)]
	ldp	x4, x5, [sp, #(8*16+4*8)]
	ldp	x6, x7, [sp, #(8*16+6*8)]
	ldr	x8,     [sp, #(8*16+8*8)]

	mov	sp, fp
	ldp	fp, lr, [sp], #16
	AuthenticateLR

.endmacro
//结束
```

- 然后我们在本文件中搜索`__class_lookupMethodAndLoadCache3`发现没有它的定义，然后我们再在整个文件中搜索，发现还是没有，这个时候我们去掉开头的一个下划线再搜索，发现有了结果，这是因为汇编的函数比c++的多一个下划线。

4. 我们在`objc-runtime-new.mm`这个文件中找到了`_class_lookupMethodAndLoadCache3`的实现：

```objective-c
IMP _class_lookupMethodAndLoadCache3(id obj, SEL sel, Class cls)
{
    return lookUpImpOrForward(cls, sel, obj, 
                              YES/*initialize*/, NO/*cache*/, YES/*resolver*/);
}
```

- 主要就是实现了`lookUpImpOrForward()`这个方法，然后我们再查找一下这个方法：

  > **这个方法很长，但也是消息传递的核心，到了这了千万不要放弃，下面你只需要一点点耐心，跟着我走，很快就能掌握它。**
  >
  > 如果不了解什么是方法缓存的，你就只需要知道，**苹果认为如果一个方法被调用了，那个这个方法有更大的几率被再此调用，既然如此直接维护一个缓存列表，把调用过的方法加载到缓存列表中，再次调用该方法时，先去缓存列表中去查找，如果找不到再去方法列表查询。这样避免了每次调用方法都要去方法列表去查询，大大的提高了速率。**如果想仔细了方法缓存请看我下一篇文章。
  >
  > **注意看我标有⚠️这个标志的代码行**

```objective-c
IMP lookUpImpOrForward(Class cls, SEL sel, id inst, 
                       bool initialize, bool cache, bool resolver)
{
    IMP imp = nil;
    bool triedResolver = NO;

    runtimeLock.assertUnlocked();

    // Optimistic cache lookup
⚠️  if (cache) { //由于我们在此之前进行过一次缓存查找，所以不会进入这里
        imp = cache_getImp(cls, sel);
        if (imp) return imp;
    }
  
    runtimeLock.lock();
    checkIsKnownClass(cls);

    if (!cls->isRealized()) {
        realizeClass(cls);
    }

    if (initialize  &&  !cls->isInitialized()) {
        runtimeLock.unlock();
        _class_initialize (_class_getNonMetaClass(cls, inst));
        runtimeLock.lock()；
    }

 retry:    
    runtimeLock.assertLocked();
  
//再查找一次缓存中有没有，因为担心代码在运行中动态添加了方法
⚠️  imp = cache_getImp(cls, sel);
    if (imp) goto done;
  	
  	//如果是类对象
  	// Try this class's method lists.
⚠️  //这一个代码块从类的方法列表中去查找
---------------------------------------------------------------------------------
-  	{																																
-  ⚠️⚠️⚠️Method meth = getMethodNoSuper_nolock(cls, sel);	//查找方法	 
-    	  if (meth) {																									
-						//把方法缓存到类对象的缓存列表中，并返回方法的IMP							 
-    	      log_and_fill_cache(cls, meth->imp, sel, inst, cls);			
-     	    imp = meth->imp;																				
-     	    goto done;        																			
-    	  }                                                           
-    	}                                                             
---------------------------------------------------------------------------------
  
  	// Try superclass caches and method lists.
⚠️  //这一个代码块沿着继承链，从类对象的父类中去查找
---------------------------------------------------------------------------------
-   {
-       unsigned attempts = unreasonableClassCount();
-       for (Class curClass = cls->superclass;
-            curClass != nil;
-            curClass = curClass->superclass)
-       {
-           // Halt if there is a cycle in the superclass chain.
-           if (--attempts == 0) {
-               _objc_fatal("Memory corruption in class list.");
-           }
-           // Superclass cache.
- 					//再查找一次缓存中有没有，因为担心代码在运行中动态添加了方法
-         ⚠️imp = cache_getImp(curClass, sel);
-           if (imp) {
-               if (imp != (IMP)_objc_msgForward_impcache) {
-                   // Found the method in a superclass. Cache it in this class.
-                   log_and_fill_cache(cls, imp, sel, inst, curClass);
-                   goto done;
-               }
-               else {
-                   break;
-               }
-           }
-           // Superclass method list.
-						//查找父类的方法列表
-         ⚠️Method meth = getMethodNoSuper_nolock(curClass, sel);
-           if (meth) {
-               log_and_fill_cache(cls, meth->imp, sel, inst, curClass);
-               imp = meth->imp;
-               goto done;
-           }
-       }
-   }
---------------------------------------------------------------------------------
  
  ...........................
  //省略部分涉及到动态方法解析和消息转发
  //我在下面拿出来仔细讲解
  
}  	
```

5. 我们具体看一下是怎么从类对象中查找方法的，这个主要是在`getMethodNoSuper_nolock()`这个方法，拥有⚠️⚠️⚠️这一行代码。

```objective-c
static method_t *
getMethodNoSuper_nolock(Class cls, SEL sel)
{
    runtimeLock.assertLocked();

    assert(cls->isRealized());
    // fixme nil cls? 
    // fixme nil sel?

  	//cls->data()->methods就是类对象的方法列表
    for (auto mlists = cls->data()->methods.beginLists(), 
              end = cls->data()->methods.endLists(); 
         mlists != end;
         ++mlists)
    {
        ⚠️method_t *m = search_method_list(*mlists, sel);//通过这个方法具体去查找
        if (m) return m;
    }

    return nil;
}
```



## 动态解析阶段

### 动态解析流程

- 在自己的类对象的缓存和方法列表中都没有找到方法，并且在父类的类对象的缓存和方法列表中都没有找到方法时，这时候就会启动动态方法解析。
- 我们再次回到**lookUpImpOrForward这个方法**，在上面我们是不是省略了一部分，现在我把与动态解析有关的代码贴出来：

```objective-c
  	// No implementation found. Try method resolver once.
		//如果上述在类对象和父类对象中没有查到方法
 		//我们进入动态方法解析
 	 if (resolver  &&  !triedResolver) {//triedResolver用来判断是否曾经进行过动态方法解析，如果没有那就进入动态方法解析，如果进行过，就跳过
  	   runtimeLock.unlock();
    ⚠️ _class_resolveMethod(cls, sel, inst);//动态方法解析函数
   	   runtimeLock.lock();
   	   // Don't cache the result; we don't hold the lock so it may have 
   	   // changed already. Re-do the search from scratch instead.
   	 ⚠️triedResolver = YES;//进行过动态方法解析就把这个标志位设置为YES
   	 ⚠️goto retry;//retry是前面消息发送的整个过程，也就是说进行了方法解析后还要回到前面从类对象的缓存和方法列表中查找。如果动态方法解析添加了方法实现，那么自然能找到，如果没有，那么还是找不到方法实现，这个时候也不会再进入动态方法解析了，而是直接进入下一步，消息转发
   }
```

- 然后我们查看一下`_class_resolveMethod()`的实现：

```objective-c
void _class_resolveMethod(Class cls, SEL sel, id inst)
{
  	//判断是不是元类对象
    if (! cls->isMetaClass()) {
        // try [cls resolveInstanceMethod:sel]
      	//调用类的resolveInstanceMethod方法
       ⚠️ _class_resolveInstanceMethod(cls, sel, inst);
    } 
  	//不是类对象肯定就是元类对象
    else {
        // try [nonMetaClass resolveClassMethod:sel]
        // and [cls resolveInstanceMethod:sel]
      	//调用元类的resolveClassMethod方法
        ⚠️_class_resolveClassMethod(cls, sel, inst);
        if (!lookUpImpOrNil(cls, sel, inst, 
                            NO/*initialize*/, YES/*cache*/, NO/*resolver*/)) 
        {
            _class_resolveInstanceMethod(cls, sel, inst);
        }
    }
}
```

> - **其实实现很简单，就是判断是类对象还是元类对象，如果是类对象则说明调用的实例方法，则调用类的resolveInstanceMethod:方法，**
>
> - **如果是元类对象，则说明是调用的类方法，则调用类的resolveClassMethod:方法。**

- `resolveClassMethod:`默认返回值是`NO`,如果你想在这个函数里添加方法实现，你需要借助`class_addMethod`

```objective-c
class_addMethod(Class _Nullable cls, SEL _Nonnull name, IMP _Nonnull imp, 
                const char * _Nullable types) 
  
@cls : 给哪个类对象添加方法
@name : SEL类型的，给哪个方法名添加方法实现
@imp : IMP类型的，要把哪个方法实现添加给给定的方法名
@types ：在讲method_t的结构时讲过这个，就是表示返回值和参数类型的字符串，比如"v16@0:8"
```

- 看了上面这个函数，那么如何获得方法的`Method`？

```objective-c
Method _Nullable
class_getInstanceMethod(Class _Nullable cls, SEL _Nonnull name)
```

- 如何通过`Method`结构获取方法的`IMP`

```objective-c
IMP _Nonnull
method_getImplementation(Method _Nonnull m) 
```

### 动态解析例子

- 通过上面学习我们大致知道了动态解析的流程，现在我们通过一个例子来证实我们上面所说的

```objective-c
//创建一个Person对象，并在.h文件中声明test方法，但在.m文件中并未实现

#import "ViewController.h"
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    Person *person = [[Person alloc] init];
    [person test];
}

@end
```

- 一运行果然崩溃了，并打印了经典错误：`unrecognized selector sent to instance 0x60400000e3e0`。

> **程序崩溃很容易理解，因为在第一步查找方法中，在自己的类对象以及父类的类对象中都没有找到这个方法，**
>
> **所以转向动态方法解析，动态方法解析我们什么也没做，所以会转向消息转发，消息转发我们也什么都没做，所以最后产生崩溃。**
>
> **接下来我们实现一下动态方法解析。**

- 动态方法解析
  - 是当第一步中方法查找失败时会进行的，当调用的是对象方法时，动态方法解析是在`resolveInstanceMethod:`方法中实现的，
  - 当调用的是类方法时，动态方法解析是在`resolveClassMethod:`方法中实现的。利用动态方法解析和`runtime`，我们可以给一个没有实现的方法添加方法实现。会运用到我上面提到的方法

```objective-c
//我现在Person.m文件中实现了test2方法：
//通过class_addMethod的方法动态添加方法
+ (BOOL)resolveInstanceMethod:(SEL)sel{
    if (sel == @selector(test)) {
        Method method = class_getInstanceMethod(self, @selector(test2));
        class_addMethod(self, sel, method_getImplementation(method), "v16@0:8");
        return YES;
    }
    
    return [super resolveInstanceMethod:sel];
}

- (void)test2{
    NSLog(@"测试动态方法解析");
}
```

- 这样当第一步方法查找找不到方法时，就会进行第二步动态方法解析，由于调用的是对象方法，所以会执行`resolveInstanceMethod:`方法中的代码，在这个方法中，使用`runtime`的API，给类对象中动态添加了`test`方法的实现，这个实现是`test2`方法的实现。当动态方法解析结束后还会返回去进行方法查找，这次能够查找到`test`方法及其实现了，也就能够成功调用`test`方法了。
- **注意⚠️：进行动态方法解析结束之后，会从头开始再进行消息发送这一步，如果在动态方法解析的时候有动态添加方法实现，那么就能找到方法实现并返回方法实现，不再执行下面的代码；如果在动态方法解析的时候没有做什么事，那么就不能找到方法实现，这时候由于`triedResolver`标志位已经置为YES，也就不会再进入动态消息解析，而是会进入消息转发。**

## 消息转发阶段

### 消息转发流程

- 如果动态方法解析没有实现，我们就会进入最后一步消息转发阶段，首先我们还是回到`lookUpImpOrForward`这个方法,我们把动态方法解析的代码一同贴出来，下面还会用到：

```objective-c
     //如果上述在类对象和父类对象中没有查到方法
 		 //我们进入动态方法解析
    if (resolver  &&  !triedResolver) {//triedResolver用来判断是否曾经进行过动态方法解析，如果没有那就进入动态方法解析，如果进行过，就跳过
        runtimeLock.unlock();
    ⚠️ _class_resolveMethod(cls, sel, inst);//动态方法解析函数
        runtimeLock.lock();
        // Don't cache the result; we don't hold the lock so it may have 
        // changed already. Re-do the search from scratch instead.
      ⚠️triedResolver = YES;//进行过动态方法解析就把这个标志位设置为YES
      ⚠️goto retry;
      //retry是前面消息发送的整个过程，也就是说进行了方法解析后还要回到前面从类对象的缓存和方法列表中查找。如果动态方法解析添加了方法实现，那么自然能找到，如果没有，那么还是找不到方法实现，这个时候也不会再进入动态方法解析了，而是直接进入下一步，消息转发
     }
  

  ⚠️ //如果动态方法解析失败，进入消息转发

  ⚠️imp = (IMP)_objc_msgForward_impcache;//这一步进入消息转发
    cache_fill(cls, sel, imp, inst);
  
   //如果消息转发失败，程序崩溃
 done:
  ⚠️runtimeLock.unlock();
```

- 消息转发通俗地讲就是本类没有能力去处理这个消息，那么就转发给其他的类，让其他类去处理。
- 看一下进行消息转发的函数`_objc_msgForward_impcache`的具体实现，去文件中搜索，在汇编中找到了它的实现：

```assembly
	//开始
	STATIC_ENTRY __objc_msgForward_impcache

	// No stret specialization.
	b	__objc_msgForward//跳转至此函数

	END_ENTRY __objc_msgForward_impcache
	//结束
	
	//开始
	ENTRY __objc_msgForward

	adrp	x17, __objc_forward_handler@PAGE//主要是通过它实现
	ldr	p17, [x17, __objc_forward_handler@PAGEOFF]
	TailCallFunctionPointer x17
	
	END_ENTRY __objc_msgForward
	//结束
```

- 然后我们去查找`__objc_forward_handler`的实现，但是找到了半天好像并不能找到其实现，这个函数有可能并不是开源的，那我们这条路就行不通了。
- 不过网上有人写了`__forwarding__`这个函数的实现的伪代码，我们可以拿来学习一下

```objective-c
int __forwarding__(void *frameStackPointer, int isStret) { 
    id receiver = *(id *)frameStackPointer; 
    SEL sel = *(SEL *)(frameStackPointer + 8); 
    const char *selName = sel_getName(sel); 
    Class receiverClass = object_getClass(receiver); 

    // 调用 forwardingTargetForSelector: 
    if (class_respondsToSelector(receiverClass,@selector(forwardingTargetForSelector:))) { 
      //首先调用消息接收者的forwardingTargetForSelector方法来获取消息转发对象
      ⚠️id forwardingTarget = [receiver forwardingTargetForSelector:sel]; 
        if (forwardingTarget && forwarding != receiver) { 
            if (isStret == 1) { 
                    int ret; 
                    objc_msgSend_stret(&ret,forwardingTarget, sel, ...); 
                    return ret; 
            } 
          	//然后直接给这个消息转发对象发送消息
            return objc_msgSend(forwardingTarget, sel, ...); 
       } 
  } 

// 僵尸对象 
const char *className = class_getName(receiverClass); 
const char *zombiePrefix = "_NSZombie_"; 
size_t prefixLen = strlen(zombiePrefix); // 0xa 
if (strncmp(className, zombiePrefix, prefixLen) == 0) { 
    CFLog(kCFLogLevelError, 
            @"*** -[%s %s]: message sent to deallocated instance %p", 
            className + prefixLen, 
            selName, 
            receiver); 
    <breakpoint-interrupt> 
} 

//如果forwardingTargetForSelector没有实现或者返回值为0都会继续往下执行
  
// 调用 methodSignatureForSelector 获取方法签名后再调用forwardInvocation 
⚠️if (class_respondsToSelector(receiverClass, @selector(methodSignatureForSelector:))) { 
  //如果methodSignatureForSelector返回值不为nil
  ⚠️NSMethodSignature *methodSignature = [receiver methodSignatureForSelector:sel]; 
    if (methodSignature) { 
       BOOL signatureIsStret = [methodSignature _frameDescriptor]->returnArgInfo.flags.isStruct; 
       if (signatureIsStret != isStret) { 
         CFLog(kCFLogLevelWarning , 
                    @"*** NSForwarding: warning: method signature and compiler disagree on struct-return-edness of '%s'. Signature thinks it does%s return a struct, and compiler thinks it does%s.", 
            selName, 
            signatureIsStret ? "" : not, 
            isStret ? "" : not); 
} 

   //并且实现了forwardInvocation方法
⚠️if (class_respondsToSelector(receiverClass, @selector(forwardInvocation:))) { 
    NSInvocation *invocation = [NSInvocation _invocationWithMethodSignature:methodSignature frame:frameStackPointer]; 

    [receiver forwardInvocation:invocation]; 

    void *returnValue = NULL;
    [invocation getReturnValue:&value]; 
    return returnValue; 
    } 
    else { 
        CFLog(kCFLogLevelWarning , 
                @"*** NSForwarding: warning: object %p of class '%s' does not implement forwardInvocation: -- dropping message",
             receiver, 
             className); 
        return 0; 
        } 
    } 
} 

SEL *registeredSel = sel_getUid(selName); 

// selector 是否已经在 Runtime 注册过 
if (sel != registeredSel) { 
    CFLog(kCFLogLevelWarning , 
            @"*** NSForwarding: warning: selector (%p) for message '%s' does not match selector known to Objective C runtime (%p)-- abort", 
            sel, 
            selName, 
            registeredSel); 
}
  
⚠️//如果上面两个方法都未实现，那么就会崩溃
// doesNotRecognizeSelector 
else if (class_respondsToSelector(receiverClass,@selector(doesNotRecognizeSelector:))) { 
    [receiver doesNotRecognizeSelector:sel]; 
}  else { 
    CFLog(kCFLogLevelWarning , 
            @"*** NSForwarding: warning: object %p of class '%s' does not implement doesNotRecognizeSelector: -- abort", 
            receiver, 
            className); 
} 

// The point of no return. 
kill(getpid(), 9);
}
```

### 消息转发例子

```objective-c
//Person.h中有- (void)testAge:(int)age;但是在Person.m中并没有实现
[person testAge:10];
```

- 这个时候会产生崩溃，因为在消息发送阶段没有找到该方法的实现，而动态方法解析和消息转发阶段则什么都没有做，所以就崩溃了。 第一阶段消息发送结束后会进行第二阶段动态消息解析，动态消息解析依赖于`+ (BOOL)resolveInstanceMethod:(SEL)sel`这个函数，当这个函数也没有动态添加方法实现时，就会进入第三阶段-消息转发。

- **消息转发**
  - **首先依赖于`- (id)forwardingTargetForSelector:(SEL)aSelector`这个方法，若是这个方法直接返回了一个消息转发对象，则会通过objc_msgSend()把这个消息转发给消息转发对象了。**
  - **若是这个方法没有实现或者实现了但是返回值为空，则会跑去执行后面的`- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector`这个函数以及`- (void)forwardInvocation:(NSInvocation *)anInvocation`这个函数。**

```objective-c
//现在我们在第二阶段动态方法解析阶段没有做任何处理，
//在- (id)forwardingTargetForSelector:(SEL)aSelector这个函数中也不做处理。
//那么代码就会执行到- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector这个函数，
//在这个函数中我们要返回一个方法签名：

//方法签名：返回值类型，参数类型
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector{
    if(aSelector == @selector(testAge:)){
        return [NSMethodSignature signatureWithObjCTypes:"v20@0:8i16"];
    }
    return [super methodSignatureForSelector:aSelector];
}
```

- 这里为什么只需要返回返回值类型和参数类型？
  - `person`对象调用`- (void)testAge:(int)age`这个过程，我们就需要知道方法调用者，方法名，方法参数。
  - 而在`Person.m`中我们肯定知道方法调用者是`person`对象，方法名也知道是"`testAge:`"，那么现在不知道的就是方法参数了
  - 那么这个方法签名就是表征这个方法参数的，包括返回值和参数，这样方法调用者，方法名和方法参数就都知道了。

- 然后看`- (void)forwardInvocation:(NSInvocation *)anInvocation`的实现：

  ```objective-c
  ///NSInvocation封装了一个方法调用，包括：方法调用者，方法名，方法参数
  @  anInvocation.target 方法调用者
  @   anInvocation.selector 方法名
  @   [anInvocation getArgument:NULL atIndex:0];
  - (void)forwardInvocation:(NSInvocation *)anInvocation{
      NSLog(@"%@ %@", anInvocation.target, NSStringFromSelector(anInvocation.selector));
      int age;
      [anInvocation getArgument:&age atIndex:2];
      NSLog(@"%d", age);
      //这行代码是把方法的调用者改变为student对象
      [anInvocation invokeWithTarget:[[Student alloc] init]];
  }
  ```

- 在这个方法中有一个`NSInvocation`类型的`anInvocation`参数，这个参数就是表征一个方法调用的，我们可以通过这个参数获取`person`对象调用`- (void)testAge:(int)age`方法这个过程中的方法调用者，方法名，方法参数。然后我们可以通过修改方法调用者来达到消息转发的效果，这里是把方法调用者修改为了`student`对象。这样就完成了成功转发消息给`student`对象。
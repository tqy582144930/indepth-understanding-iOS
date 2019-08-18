[TOC]

# iOS开发---图解事件的产生和响应

> 本博客会从事件的产生和响应这两个方面来完整的解释事件。
>
> 我们先打值看一下本文的主要内容，正文我会一一讲解：
>
> 产生：事件如何从父控件传递到子控件并寻找到最合适的view
>
> 响应：找到最合适的view后事件的处理（touches方法的重写，也就是事件的响应）

## 事件的产生

### 什么是事件(UIEvent)？

- UIEvent:称为事件对象，记录事件产生的时刻和类型

  ```objective-c
  NS_CLASS_AVAILABLE_IOS(2_0) @interface UIEvent : NSObject
  //事件类型
  @property(nonatomic,readonly) UIEventType     type NS_AVAILABLE_IOS(3_0);
  @property(nonatomic,readonly) UIEventSubtype  subtype NS_AVAILABLE_IOS(3_0);
  //时间
  @property(nonatomic,readonly) NSTimeInterval  timestamp;
  
  #if UIKIT_DEFINE_AS_PROPERTIES
  @property(nonatomic, readonly, nullable) NSSet <UITouch *> *allTouches;
  #else
  @end
  ```

- iOS中的事件可以分为4大类型：

  1. 触摸事件
  2. 加速计事件(运动事件，比如重力感应和摇一摇等)
  3. 远程遥控事件
  4. 按压事件（iOS9之后出现的）

  ```objective-c
  //这是UIEventType
  typedef NS_ENUM(NSInteger, UIEventType) {
      UIEventTypeTouches,
      UIEventTypeMotion,
      UIEventTypeRemoteControl,
      UIEventTypePresses NS_ENUM_AVAILABLE_IOS(9_0),
  };
  ```

- 下面是官方给出的一张图

![](http://ww4.sinaimg.cn/large/006tNc79ly1g62yw0ok35j316u0hs0x8.jpg)

- 下面主要讲解`Touch Events(触摸事件)`：`UIApplication`通过一个触摸检测来决定最合适来处理该事件的响应者，一般情况下，这个响应者是`UIView`对象。

### 事件的产生

1. 当用户的手指触摸屏幕的某一个`view`的时候，此时就发生了触摸事件，产生触摸事件后，系统会将该事件加入到一个由`UIApplication`管理的事件队列中,为什么是队列而不是栈？因为队列的特点是FIFO，即先进先出，先产生的事件先处理才符合常理，所以把事件添加到队列。
2. `UIApplication`会从事件队列中取出最前面的事件，并将事件分发下去以便处理，通常，先发送事件给应用程序的主窗口`（keyWindow）`。
3. 然后由主窗口决定如何将事件交给最合适的响应者(UIResponder)来处理

### 事件的传递

- 在上面提到**主窗口决定如何将事件交给最合适的响应者(UIResponder)来处理**这个过程就称之为事件的传递，说直白一点事件的传递就是从`UIApplication`->`window`->寻找处理事件最合适的`view`的过程

#### 如何寻找最合适的UIView

##### UIView接收触摸事件的条件

1. `userInteractionEnabled`属性为`YES`，该属性表示允许控件同用户交互。
2. `Hidden`属性为NO。控件都看不见，自然不存在触摸
3. `opacity`属性值0 ～0.01。
4. 触摸点在这个UIView的范围内。

##### 事件传递的流程

1. 触摸事件发生后，`UIApplication`会先发送事件给应用程序的主窗口`（keyWindow）`，判断主窗口`（keyWindow）`自己是否能接受触摸事件
2. 触摸点是否在自己身上
3. 在子控件数组中从后往前遍历子控件，重复前面的两个步骤（首先查找数组中最后一个元素）
4. 如果没有符合条件的子控件，那么就认为自己最合适处理

- 下面我们通过一个🌰来了解这个过程是如何发生的：

![](http://ww1.sinaimg.cn/large/006tNc79ly1g6300agxq4j3061081gli.jpg)

- 假设我点击了绿色的`view`

  1. 主窗口`（UIWindow）`接收到应用程序传递过来的事件后，首先判断自己能否接收触摸事件。如果能，那么再判断触摸点在不在窗口自己身上。
  2. 如果触摸点也在窗口身上，那么主窗口会从后往前遍历自己的`子控件（白色view）`,判断自己能否接收触摸事件。如果能，那么再判断触摸点在不在`白色view`自己身上。
  3. 如果触摸点也在`白色view`身上，那么`白色view`会从后往前遍历自己的`子控件（绿色view）`,判断自己能否接收触摸事件。如果能，那么再判断触摸点在不在`绿色view`自己身上。
  4. 如果触摸点也在`绿色view`身上，那么`绿色view`会从后往前遍历自己的子控件，发现自己没有子控件，那么我们就找到了最合适的`view`就是`绿色view`

  > 注意⚠️：**之所以会采取从后往前遍历子控件的方式寻找最合适的`view`只是为了做一些循环优化。因为相比较之下，后添加的`view`在上面，降低循环次数。**

##### 事件传递的底层实现

> 前面我们为大家清楚的介绍了事件传递的流程，但是大家肯定会有两个疑惑：
>
> **一、你怎么知道自己能否接收触摸事件**
>
> **二、你怎么知道触摸点在不在自己身上**

- 上个两个疑惑都会在**hitTest:withEvent:方法**中找到答案，下面我们认真看一下这个方法的底层实现

###### hitTest:withEvent:方法

```objective-c
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    // 1.判断自己能否接收触摸事件
    if (self.userInteractionEnabled == NO || self.hidden == YES || self.alpha <= 0.01) return nil;
    // 2.判断触摸点在不在自己范围内
    if (![self pointInside:point withEvent:event]) return nil;
    // 3.从后往前遍历自己的子控件，看是否有子控件更适合响应此事件
    int count = self.subviews.count;
    for (int i = count - 1; i >= 0; i--) {
        UIView *childView = self.subviews[i];
        CGPoint childPoint = [self convertPoint:point toView:childView];
        UIView *fitView = [childView hitTest:childPoint withEvent:event];
        if (fitView) {
            return fitView;
        }
    }
    // 没有找到比自己更合适的view
    return self;
}
```

- 什么时候调用？
  - 只要事件一传递给一个控件,这个控件就会调用他自己的`hitTest:withEvent:方法`
- 这个方法作用？
  - 寻找并返回最合适的view(能够响应事件的那个最合适的view)
- 注意⚠️：**不管这个控件能不能处理事件，也不管触摸点在不在这个控件上，事件都会先传递给这个控件，随后再调用`hitTest:withEvent:方法`来进行判断**

###### pointInside:withEvent:方法

- `pointInside:withEvent:`方法判断点在不在当前`view`上（方法调用者的坐标系上）如果返回`YES`，代表点在方法调用者的坐标系上;返回`NO`代表点不在方法调用者的坐标系上，那么方法调用者也就不能处理事件。

## 事件的响应

> 找到最合适的视图控件后，就会调用控件的touches方法来做具体的事件处理，这就是事件的响应。

### UITouch对象

-  什么是UITouch？

  - 在 iOS 中，每一个“触摸”`(touch)`行为对象就代表单根手指在屏幕上的一次运动操作，在 iOS 中以`UITouch` 类对象进行抽象表示。

  > 注意⚠️：
  >
  > - **当用户用一根手指触摸屏幕时，会创建一个与手指相关的UITouch对象* **
  >
  > - **一根手指对应一个UITouch对象**
  >
  > - **如果两根手指同时触摸一个view，那么view只会调用一次touchesBegan:withEvent:方法，touches参数中装着2个UITouch对象**
  >
  > - **如果这两根手指一前一后分开触摸同一个view，那么view会分别调用2次touchesBegan:withEvent:方法，并且每次调用时的touches参数中只包含一个UITouch对象**

- UITouch的作用

  - 保存着跟手指相关的信息，比如触摸的位置、时间、阶段
  - 当手指移动时，系统会更新同一个`UITouch`对象，使之能够一直保存该手指在的触摸位置
  - 当手指离开屏幕时，系统会销毁相应的`UITouch`对象

- UITouch的属性

  ```objective-c
  //触摸产生时所处的窗口
  @property(nonatomic,readonly,retain) UIWindow *window;
  //触摸产生时所处的视图
  @property(nonatomic,readonly,retain) UIView *view;
  //短时间内点按屏幕的次数，可以根据tapCount判断单击、双击或更多的点击
  @property(nonatomic,readonly) NSUInteger tapCount;
  //记录了触摸事件产生或变化时的时间，单位是秒
  @property(nonatomic,readonly) NSTimeInterval timestamp;
  //当前触摸事件所处的状态
  @property(nonatomic,readonly) UITouchPhase phase;
  ```

- UITouch的方法

  ```objective-c
  - (CGPoint)locationInView:(UIView *)view;
  // 返回值表示触摸在view上的位置
  // 这里返回的位置是针对view的坐标系的（以view的左上角为原点(0, 0)）
  // 调用时传入的view参数为nil的话，返回的是触摸点在UIWindow的位置
  
  - (CGPoint)previousLocationInView:(UIView *)view;
  // 该方法记录了前一个触摸点的位置
  ```

### 响应者对象

- 在iOS中不是任何对象都能处理事件，只有继承了`UIResponder`的对象才能接受并处理事件，我们称之为“响应者对象”。以下都是继承自`UIResponder`的，所以都能接收并处理事件。

  - UIApplication
  - UIViewController
  - UIView

- 那么为什么继承自`UIResponder`的类就能够接收并处理事件呢？

  - 因为`UIResponder`中提供了以下4个对象方法来处理触摸事件

  ```objective-c
  // 一根或者多根手指开始触摸view，系统会自动调用view的下面方法
  - (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
  // 一根或者多根手指在view上移动，系统会自动调用view的下面方法（随着手指的移动，会持续调用该方法）
  - (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
  // 一根或者多根手指离开view，系统会自动调用view的下面方法
  - (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
  // 触摸结束前，某个系统事件(例如电话呼入)会打断触摸过程，系统会自动调用view的下面方法
  - (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
  ```

- 上面有两个参数`(NSSet *)touches` 和`(UIEvent *)event`

  - (NSSet *)touches：就是UITouch对象的集合

    - > 举例：
      >
      > - 如果两根手指同时触摸一个view，那么view只会调用一次touchesBegan:withEvent:方法，touches参数中装着2个UITouch对象
      >
      > - 如果这两根手指一前一后分开触摸同一个view，那么view会分别调用2次touchesBegan:withEvent:方法，并且每次调用时的touches参数中只包含一个UITouch对象

  - (UIEvent *)event：就是最开始我们介绍的UIEevent，它记录事件产生的时刻和类型

### 事件的响应流程

1. 当我们找到最合适的`View`后,如果当前的`View`有添加手势，那么直接响应相应的事件，如果没有手势事件，那么会看其是否实现了如下的方法：

```objective-c
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;//开始触摸
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;//手指移动
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;//结束触摸
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;://触摸终端
```

2. 如果有实现那么就由此`View`响应，如果没有实现（即不能处理当前事件），那么事件将会沿着响应者链`(Responder Chain)`进行传递，直到遇到能处理该事件的响应者`(Responsder Object)`。

### 响应者链

- 由很多**响应者**链接在一起组合起来的一个链条称之为**响应者链条**

  - > 补充：**响应者链条其实还包括视图控制器、UIWindow和UIApplication**

- 下面我们用一张图来展示响应者链

![](http://ww1.sinaimg.cn/large/006tNc79ly1g63sc2jxb9j30gr093q4b.jpg)

- 首先`initial view`会把事件传递给`橘黄色的view`，`橘黄色view`又把事件给时间传递给了`蓝绿色view`，`蓝绿色view`把时间传递给了`控制器view`，`控制器view`把事件传递给了窗口，窗口把事件传递给了`Application`对象,如果最后`Application`还是不能处理此事件则将其丢弃.
  - 在事件的响应中，如果某个控件实现了`touches`方法，则这个事件将由该控件来接受，如果调用了`[super touches….]`;就会将事件顺着响应者链条往上传递，传递给上一个响应者；接着就会调用上一个响应者的`touches`方法
- 如何判断上一个响应者
  1. 如果当前这个`view`是控制器的`view`,那么控制器就是上一个响应者
  2. 如果当前这个`view`不是控制器的`view`,那么父控件就是上一个响应者

## 事件的整个流程总结

1. 当一个事件发生后，事件会从父控件传给子控件，也就是说由`UIApplication -> UIWindow -> UIView -> initial view`,以上就是**事件的传递，也就是寻找最合适的view的过程**。

2. 接下来是**事件的响应**。首先看`initial view`能否处理这个事件，如果不能则会将事件传递给其上级视图`（inital view的superView）`；如果上级视图仍然无法处理则会继续往上传递；一直传递到视图控制器`view controller`，首先判断视图控制器的根视图view是否能处理此事件；如果不能则接着判断该视图控制器能否处理此事件，如果还是不能则继续向上传递；（对于第二个图视图控制器本身还在另一个视图控制器中，则继续交给父视图控制器的根视图，如果根视图不能处理则交给父视图控制器处理）；一直到` window`，如果`window`还是不能处理此事件则继续交给`application`处理，如果最后application还是不能处理此事件则将其丢弃

3. 在**事件的响应中**，如果某个控件实现了`touches`方法，则这个事件将由该控件来接受，如果调用了`[super touches….]`;就会将事件顺着响应者链条往上传递，传递给上一个响应者；接着就会调用上一个响应者的`touches`方法

- 注意⚠️：**事件的传递是从上到下（父控件到子控件），事件的响应是从下到上（顺着响应者链条向上传递：子控件到父控件）。**

# hitTest:和pointInside:的应用

### 屏蔽

- 如果将某个view的`pointInsdie:`方法直接返回NO（无论子控件的`pointInsdie:`返回什么），影响的是子控件区域和自身区域的点击事件处理，这些区域不再响应事件。其余区域响应点击事件不发生变化。
- 如果将某个`view`的`pointInside:`方法直接返回`YES`，自身区域响应点击事件不变。其它区域改变:
  1. 父控件所有区域点击事件交给该`view`处理。
  2. 再看该`view`处于父控件的子控件数组中的位置。数组前面的兄弟控件的点击事件交给该`view`处理，数组后面的兄弟控件的点击事件由其兄弟控件处理。
  3. 该`view`的子控件原来能够自己处理点击的区域继续由子控件处理，子控件原来不能够自己处理点击的（超出了该view范围）区域仍然可以由子控件处理了
- 总结：**想要屏蔽掉某个view响应点击事件，如果其没有子控件或者子控件响应事件也想屏蔽掉，直接将该view的pointInside返回为NO就行了。而在一般情况下，不建议将view的pointInside直接返回YES（影响范围太广，不好控制）。**

### 穿透

- 我们先假设有一个黄色控件和白色控件，白色空间覆盖在黄色控件上，如果你不想让你点击的那个`白色view`处理该事件，而是想要`黄色view`来响应该事件，就需要我么所说的穿透

- 我们有两种方式来实现穿透：

  1. 如果`whiteView`是`yellowView`的兄弟控件。

     1. 可以重写`whiteView`里面的`hitTest:`方法:判断触摸在`whiteView`上的点，如果在`yellowView`上，`hitTest:`返回`yellowView`，交给其响应。

     ```objective-c
     - (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
         CGPoint yellowPoint = [self convertPoint:point toView:_yellowView];
             if ([_yellowView pointInside:yellowPoint withEvent:event]) {
             		return _yellowView;
         }
         return [super hitTest:point withEvent:event];
     }
     ```

     2. 也可以重写`whiteView`的`pointInside:`方法：如果触摸点属于`yellowView`范围，返回`NO`，该范围内`whiteView`不响应点击。

     ```objective-c
     - (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
         CGPoint yellowPoint =[_yellowView convertPoint:point fromView:self];
         if ([_yellowView pointInside:yellowPoint withEvent:event]){
           	return NO;
         } else {
          		return [super pointInside:point withEvent:event];
         }
     }
     
     ```

  2. 如果`whiteView`是`yellowView`的子控件

     1. 需要重写`whiteView`里面的`hitTest方法：`

     ```objective-c
     - (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
         CGPoint yellowPoint = [self convertPoint:point toView:_yellowView];
         if ([_yellowView pointInside:yellowPoint withEvent:event]) {
         		return _yellowView;
         }
         return [super hitTest:point withEvent:event];
     }
     
     ```

     

  



   * [iOS开发---图解代理](#ios开发---图解代理)
      * [什么是代理？](#什么是代理)
      * [代理的组成](#代理的组成)
         * [协议](#协议)
            * [协议的作用和内容](#协议的作用和内容)
            * [协议定义地点](#协议定义地点)
            * [协议的继承](#协议的继承)
            * [协议的修饰符](#协议的修饰符)
            * [如何定义协议](#如何定义协议)
         * [代理对象](#代理对象)
            * [如何实现代理对象](#如何实现代理对象)
         * [委托者](#委托者)
            * [如何定义委托者](#如何定义委托者)
            * [代理对象和委托者对应关系](#代理对象和委托者对应关系)
      * [代理实现原理](#代理实现原理)
        * [实现流程](#实现流程)
        * [内存管理](#内存管理)
           * [为什么我们设置代理属性都使用weak呢？](#为什么我们设置代理属性都使用weak呢)
           * [弱引用有weak和assign两种方式，用哪一种好？](#弱引用有weak和assign两种方式用哪一种好)
      * [代理给ViewController瘦身](#代理给viewcontroller瘦身)


# iOS开发---图解代理

## 什么是代理？

> 代理（`Delegate`）是iOS开发中的一种重要的消息传递方式，是iOS开发中普遍使用的通用设计模式，iOS集成开发环境Xcode中，提供大量的控件，例如`UITableView`，`UIScrollViewDelegate`，`UISearchView`等都是用代理机制实现消息传递。

- 官方解释是不是看起来一脸懵逼，下面我们从生活中举个🌰

> 有一个婴儿，他本身不会自己吃饭和洗澡等等一些事情，于是婴儿就花钱请了一个保姆，于是婴儿和保姆之间商定了一个协议，协议中写明了保姆需要做什么事情， 而保姆就是这个代理人。
>
> 即：婴儿和保姆之间有个`协议`，保姆继承该协议，于是保姆就需要实现该协议中的条款成为`代理人`。你的父母雇佣了这个保姆，父母就是`委托人`。父母雇佣保姆需要支付薪酬，这就是传递的`参数`，保姆给婴儿洗了澡这就是`处理结果`。

## 代理的组成

- 代理机制由代理对象、委托者、协议三部分组成
- 下面我们用一张图来展示之间的关系

![](http://ww4.sinaimg.cn/large/006tNc79ly1g5se8intlwj30mg0eiq4d.jpg)

### 协议

> 用来指定代理双方可以做什么，必须做什么。

#### 协议的作用和内容

- 从上图我们可以看到三方之间的关系，在实际应用中通过协议来规定代理双方的行为，协议中的内容一般都是方法列表，当然也可以定义属性

#### 协议定义地点

- 协议是公共的定义，如果只是某个类使用，我们常做的就是写在某个类中。如果是多个类都是用同一个协议，建议创建一个`Protocol`文件，在这个文件中定义协议。

#### 协议的继承

- 遵循的协议可以被继承，例如我们常用的`UITableView`，由于继承自`UIScrollView`的缘故，所以也将`UIScrollViewDelegate`继承了过来，我们可以通过代理方法获取`UITableView`偏移量等状态参数。

- 协议只能定义公用的一套接口，类似于一个约束代理双方的作用。但不能提供具体的实现方法，实现方法需要代理对象去实现。协议可以继承其他协议，并且可以继承多个协议，在`iOS`中对象是不支持多继承的，而协议可以多继承。

#### 协议的修饰符

> 创建一个协议如果没有声明，默认是`@required`状态的，`@required`状态的方法代理没有遵守，会报一个黄色的警告，只是起一个约束的作用，没有其他功能

- @optional:下的方法可选择实现

-  @required:下的方法必须实现

#### 如何定义协议

```objective-c
#import <Foundation/Foundation.h>
@protocol Login <NSObject>
@optional
- (void)userLoginWithUsername:(NSString *)username password:(NSString *)password;
@end
```

### 代理对象

> 根据指定的协议，完成委托方需要实现的功能。

#### 如何实现代理对象

```objective-c
// 遵守登录协议
//.h文件中
@interface ViewController () <Protocol> 
@end

//.m文件中
@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
  
    LoginViewController *loginViewController = [[LoginViewController alloc] init];
    loginViewController.delegate = self;
    [self.navigationController pushViewController:loginViewController animated:YES];
}

/**
 *  代理方实现具体登录细节
 */
- (void)userLoginWithUsername:(NSString *)username password:(NSString *)password {
    NSLog(@"username : %@, password : %@", username, password);
}
```

### 委托者

> 根据指定的协议，指定代理去完成什么功能。

#### 如何定义委托者

> 定义委托类，这里简单实现了一个用户登录功能，将用户登录后的账号密码传递出去，由代理来处理具体登录细节。

```objective-c
#import <UIKit/UIKit.h>
#import "Protocol.h"
/**
 *  当前类是委托类。用户登录后，让代理对象去实现登录的具体细节，委托者不需要知道其中实现的具体细节。
 */
//.h文件中
@interface LoginViewController : UIViewController
// 通过属性来设置代理对象
@property (nonatomic, weak) id <Protocol> delegate;
@end

//.m文件中
@implementation LoginViewController
- (void)loginButtonClick:(UIButton *)button {
  // 判断代理对象是否实现这个方法，没有实现会导致崩溃
  if ([self.delegate respondsToSelector:@selector(userLoginWithUsername:password:)]) {
      //调用代理对象的登录方法，代理对象去实现登录方法
      [self.delegate userLoginWithUsername:self.username.text password:self.password.text];
  }
}
```

#### 代理对象和委托者对应关系

- 下面我还是举个🌰来说明代理对象和委托者的关系
  1. 由于我的🚗脏了，不想自己动手清洗他，于是委托洗车店帮我把车子洗干净（协议内容），然后洗车店就会帮我把车洗干净。在这个过程中，我是`委托者`，洗车店是`代理对象`，洗车是`协议`，我给洗车店薪酬是`参数`，洗车店帮我把车洗好是`结果`。
  2. 在洗车的过程中，突然我有点口渴，但是洗车店不提供饮品服务，所以我只能通过APP在别的商家订了一杯柠檬水。在这个过程中，我是`委托者`，饮品店是`代理对象`，买饮品是`协议`，我支付饮品店薪酬是`参数`，饮品店把饮品送过来是`结果`.
  3. 在我等待洗车的过程中，该洗车店又接待了别的车；我在洗车的同时，还喝了饮品。
- 我在洗车同时，又点了饮品，说明**一个委托方可以有多个代理对象**
- 洗车行在给我写的同时，又接待了别的客户，说明**一个代理对象可以有多个委托方**

- 下面我们用一张图来展示之间的关系

![](http://ww3.sinaimg.cn/large/006tNc79ly1g5sf5luk6cj30jm0c874v.jpg)

## 代理实现原理

#### 实现流程

- 我们先看一张图大致了解他们之间的流程关系

![](http://ww3.sinaimg.cn/large/006tNc79ly1g5sgkqpdu0j312v0ho41z.jpg)

- 在`iOS`中代理的本质就是**对代理对象内存的传递和操作，*
- 委托方和代理方如何通讯
  - **我们在委托类设置代理对象后，实际上只是用一个`id`类型的指针指向代理对象，并将代理对象进行了一个弱引用。**
- 委托方的调用方法，代理方如何实现
  - 委托方让代理方执行某个方法，实际上是在委托类中**向这个`id`类型指针指向的对象发送消息，而这个`id`类型指针指向的对象，就是代理对象。**
- 什么是协议？
  - 协议其实就是一种语法，**委托方中的代理属性可以调用、协议中声明的方法**，**而协议中方法的实现还是有代理方完成**

#### 内存管理

##### 为什么我们设置代理属性都使用weak呢？

- 我们定义的指针默认都是`__strong`类型的，而属性本质上也是一个成员变量和`set`、`get`方法构成的，`strong`类型的指针会造成强引用，必定会影响一个对象的生命周期，这也就会形成循环引用。

![](http://ww4.sinaimg.cn/large/006tNc79ly1g5sh5phy58j30uk0ar3zm.jpg)

- 上图中，由于代理对象使用强引用指针，指向创建的委托方`loginViewController`对象，并且委托方`delegate`属性强引用代理对象。这就会导致`LoginVC`的`delegate`属性强引用代理对象，导致循环引用的问题，最终两个对象都无法正常释放。

![](http://ww4.sinaimg.cn/large/006tNc79ly1g5sh9pxfr3j30uk07j3zh.jpg)

- 我们将`loginViewController`对象的`delegate`属性，设置为弱引用属性。这样在代理对象生命周期存在时，可以正常为我们工作，如果代理对象被释放，委托方和代理对象都不会因为内存释放导致的**Crash**。

##### 弱引用有weak和assign两种方式，用哪一种好？

```objective-c
@property (nonatomic, weak) id <Protocol> delegate;
@property (nonatomic, assign) id <Protocol> delegate;
```

- 下面两种方式都是弱引用代理对象，但是第一种在代理对象被释放后不会导致崩溃，而第二种会导致崩溃。
- `weak`和`assign`是一种“非拥有关系”的指针，通过这两种修饰符修饰的指针变量，都不会改变被引用对象的引用计数。但是在一个对象被释放后，`weak`会自动将指针指向`nil`，而`assign`则不会。在`iOS`中，向`nil`发送消息时不会导致崩溃的，所以`assign`就会导致野指针的错误`unrecognized selector sent to instance`。

## 代理给ViewController瘦身

- 在我们写项目时，特别是主界面会随着处理的逻辑越来越多它会越来越肥。对于新项目来说MVVM设计模式是一种最好的选择，但是对于一个已经很复杂的项目来说，代理是很很好的方式。

- 这是我们平成控制器的使用

![](http://ww1.sinaimg.cn/large/006tNc79ly1g5shnc9nm1j309c066dfw.jpg)

- 这是优化后的控制器

![](http://ww2.sinaimg.cn/large/006tNc79ly1g5shnqc41hj30re0663zb.jpg)

- 从上面两张图可以看出，我们将`UITableView`的`delegate`和`DataSource`单独拿出来，由代理对象进行控制，只将必须控制器处理的逻辑传递给控制器处理。`UITableView`的数据处理、展示逻辑和简单的逻辑交互都由代理对象去处理，和控制器相关的逻辑处理传递出来，交由控制器来处理，这样控制器的工作少了很多，而且耦合度也大大降低了。这样一来，我们只需要将需要处理的工作交由代理对象处理，并传入一些参数即可。

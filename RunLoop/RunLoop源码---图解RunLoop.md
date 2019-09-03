[TOC]

# RunLoop源码---图解RunLoop

## 前言

我们在`iOS APP`中的`main`函数如下：

```objective-c
int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
```

我们在`macOS`下的`main`函数如下：

```objective-c
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"Hello, World!");
    }
    return 0;
}
```

- 对比这两个程序：
  1. `iOS App`启动后会一直运行，等待用户触摸、输入等，在接收到点击后，就会立即响应，完成本次响应后，会等待下次用户操作。只要用户不主动退出或者程序闪退，会一直在循环等待。
  2. 而`macOS`下的命令行程序，启动后，执行程序，执行完毕后会立即退出。

- 两者最大的区别是：**是否能持续响应用户输入**

## 什么是RunLoop？

- 之所以，`iOS App` 能持续响应，保证程序运行状态，在于其有一个事件循环——`Event Loop`
- 事件循环机制，即线程能随时响应并处理事件的机制。这种机制要求线程不能退出，而且需要高效的完成事件调度与处理。
- 事件循环在很多编程语言，或者说不同的操作系统层面都支持。比如 `JS `中的事件循环、`Windows`下的消息循环，在 `iOS/macOS` 下，该机制就称为 `RunLoop`。
- 事件循环在本质上是如下一个编程实现：

```objective-c
function loop() {
    initialize();
    do {
        var message = get_next_message();
        process_message(message);
    } while (message != quit);
}
```

- 

## RunLoop的应用

### 常驻线程

### NSTimer

### AutoreleasePool

### 事件响应

### 手势识别

### 界面更新


[TOC]

# iOS开发---详解KVC

## 什么是KVC？

> KVC（Key-value coding）键值编码，单看这个名字可能不太好理解。其实是指iOS的开发中，可以允许开发者通过Key名直接访问对象的属性，或者给对象的属性赋值。这样就可以在运行时动态地访问和修改对象的属性。而不是在编译时确定，很多高级的iOS开发技巧都是基于KVC实现的。目前网上关于KVC的文章在非常多，有的只是简单地说了下用法，我会运用图解的方式写下这遍文章就是为了让大家更好的理解。

## KVC方法全览

> `KVC`提供了一种间接访问其属性方法或成员变量的机制，可以通过字符串来访问对应的属性方法或成员变量。

![KVC方法全览](http://ww4.sinaimg.cn/large/006tNc79ly1g5nx6lrhusj309t0oktki.jpg)

### 最重要的四个方法

##### key

- 直接将属性名当做`key`，并设置`value`，即可对属性进行赋值。

  ```objective-c
  - (nullable id)valueForKey:(NSString *)key;                          //直接通过Key来取值
  - (void)setValue:(nullable id)value forKey:(NSString *)key;          //通过Key来设值
  ```

##### keyPath

- 除了对当前对象的属性进行赋值外，还可以对其更“深层”的对象进行赋值。`KVC`进行多级访问时，直接类似于属性调用一样用点语法进行访问即可。例如`Person`属性中有`name`属性，我就可以通过`Person.name`进行赋值

  ```objective-c
  - (nullable id)valueForKeyPath:(NSString *)keyPath;                  //通过KeyPath来取值
  - (void)setValue:(nullable id)value forKeyPath:(NSString *)keyPath;  //通过KeyPath来设值
  ```

### KVC搜索规则

> `KVC`在通过`key`或者`keyPath`进行操作的时候，可以查找属性方法、成员变量等，查找的时候可以兼容多种命名。首先我们来探讨KVC在内部是按什么样的顺序来寻找`key`的。

![基于setter搜素](http://ww2.sinaimg.cn/large/006tNc79ly1g5nzl3txetj31390mtwhw.jpg)
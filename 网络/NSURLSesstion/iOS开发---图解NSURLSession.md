[TOC]

# iOS开发---图解NSURLSession

## 基本类

### NSURLRequest

> 封装了网络请求的两个基本元素，一个是网络请求的URL，另一个是缓存策略

- 两种创建方式

  1. 直接通过`NSURL`创建，默认超时60s、缓存策略`NSURLRequestUseProtocolCachePolicy`

  ```objective-c
  + (instancetype)requestWithURL:(NSURL *)URL;
  - (instancetype)initWithURL:(NSURL *)URL;
  ```

  2. 通过`NSURL`、`超时时间`、`缓存策略`共同创建:

  ```objective-c
  + (instancetype)requestWithURL:(NSURL *)URL cachePolicy:(NSURLRequestCachePolicy)cachePolicy timeoutInterval:(NSTimeInterval)timeoutInterval;
  - (instancetype)initWithURL:(NSURL *)URL cachePolicy:(NSURLRequestCachePolicy)cachePolicy timeoutInterval:(NSTimeInterval)timeoutInterval NS_DESIGNATED_INITIALIZER;
  ```

- 缓存策略

```objective-c
typedef NS_ENUM(NSUInteger, NSURLRequestCachePolicy)
{
    NSURLRequestUseProtocolCachePolicy = 0,//默认的缓存策略，使用协议的缓存策略

    NSURLRequestReloadIgnoringLocalCacheData = 1,//每次都从网络加载
    NSURLRequestReloadIgnoringLocalAndRemoteCacheData = 4,//忽略本地和远程的缓存数据 未实现的策略
    NSURLRequestReloadIgnoringCacheData = NSURLRequestReloadIgnoringLocalCacheData,
    NSURLRequestReturnCacheDataElseLoad = 2,//返回缓存否则加载
    NSURLRequestReturnCacheDataDontLoad = 3,//只返回缓存，没有也不加载
    NSURLRequestReloadRevalidatingCacheData = 5,//未实现的策略
};
```

- 由于获取对象的URL、缓存策略、超时时间等都是可读属性，想要修改这些书香我们可以使用`NSURLRequest`的子类，`NSMutableUrlRequest`

```objective-c
@interface NSMutableURLRequest : NSURLRequest
//设置请求的URL
@property (nullable, copy) NSURL *URL;
//设置请求的缓存策略
@property NSURLRequestCachePolicy cachePolicy;
//设置请求的超时时间
@property NSTimeInterval timeoutInterval;
//设置请求的缓存目录
@property (nullable, copy) NSURL *mainDocumentURL;
//设置请求的网络服务类型
@property NSURLRequestNetworkServiceType networkServiceType NS_AVAILABLE(10_7, 4_0);
//设置请求是否支持蜂窝网络
@property BOOL allowsCellularAccess NS_AVAILABLE(10_8, 6_0);
```

### NSURLSessionConfiguration

> 对NSURLSession提供一个配置策略，NSURLSession在初始化时会copy NSURLSessionConfiguration。

- 三种模式
  1. `@property (class, readonly, strong) NSURLSessionConfiguration *defaultSessionConfiguration;`
     默认配置：会将缓存、钥匙串、cookie都保存下来
  2. `@property (class, readonly, strong) NSURLSessionConfiguration *ephemeralSessionConfiguration;`
     可以看作无痕浏览：所有东西随着session的废弃而废弃。
  3. `+(NSURLSessionConfiguration*)backgroundSessionConfigurationWithIdentifier:(NSString *)identifier`
     正常来讲APP在退出到后台的时候、网络传输将会停止。
     但通过background配置的session、当APP被切入后台的时候依旧可以进行网络会话。

- 除此之外，还可以配置请求头信息、传输的类型、是否允许蜂窝传输、超时时间、cookie的控制、证书的存储、缓存(`NSURLCache`)、缓存策略(`NSURLRequestCachePolicy`)、最大连接数等等。
- 注意⚠️
  - `NSURLSessionConfiguration`所能配置的策略、有一些和`NSURLRequest`能配置的会冲突。
    这时候、会优先使用`NSURLRequest`中的配置(比如超时、请求头等等)。

### NSURLSession

> NSURLSession由NSURLSessionConfiguration来配置，通过NSURLRequest创建出NSURLSessionTask进行网络会话

- 我们可以使用NSURLSession的API来创建一个或多个session对象，每个session对象都管理着一组网络请求任务。

#### NSURLSession的类型

- 传入的NSURLConfiguration对象类型决定了创建的NSURLSession的类型
  1. sharedSession
     - NSURLSession可以通过sharedSession方法创建一个单例，这种创建方法是不需要传入NSURLConfiguration对象的，并且不能设置代理。这样可以应对基本的网络请求，这样的session的可定制型很差但是可以满足基本的需求。
  2. default session
     - 要创建default session需要通过`[NSURLSessionConfiguration defaultSessionConfiguration]`创建一个defaultConfiguration对象传入进去。default session和sharedSession差不多，但是可以配置更多的信息，并且允许我们为session对象设置代理，这样就可以在代理回调中一部分一部分的收到响应的数据。
  3. ephemeral session
     - ephemeral是暂时性的意思，它和shared session一样，但是由于是短暂性会话，所以不会将缓存，Cookie，认证写入磁盘
  4. background session
     - background session允许upload task和download task在后台进行。

#### NSURLSession三种工作方式

```objective-c
//使用静态的sharedSession方法，该类使用共享的会话，该会话使用全局的Cache，Cookie和证书
@property (class, readonly, strong) NSURLSession *sharedSession;
//通过sessionWithConfiguration:方法创建对象，也就是创建对应配置的会话，与NSURLSessionConfiguration合作使用
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration;
//通过设置配置、代理、队列来创建会话对象
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(nullable id <NSURLSessionDelegate>)delegate delegateQueue:(nullable NSOperationQueue *)queue
```

- 通过Block来工作

```objective-c
//生成session
NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
//产出task
NSURLSessionDataTask * dataTask = [session dataTaskWithURL:[NSURL URLWithString:imageURL] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
  //taks完成
}];
//开始task
[dataTask resume];
```

- 通过代理来工作

```objective-c
//生成session并绑定代理
NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
//产出task
NSURLSessionDataTask * dataTask = [session dataTaskWithURL:[NSURL URLWithString:imageURL]];
//开始task
[dataTask resume];
```

- 可以看出
  - 通过block方式的粒度较大、只关注结果、使用方便。
  - 通过代理方式的粒度很小、可以做很多复杂的操作。

- 注意：
  - 我们必须在初始化session对象之前先配置好Configuration对象，然后再用这个Configuration对象去初始化session对象。因为session对象会先把这个Configuration对象复制一遍，然后再用复制的值去初始化session对象，所以一旦创建好了session对象，再去修改Configuration就不会起作用了。

### NSURLSessionTask

> NSURLSessionTask是由Session创建的，Session会保持对Task的一个强引用，直到Task完成或者出错才会释放。通过NSURLSessionTask可以获得Task的各种状态，以及对Task进行取消，挂起，继续等操作。每个session对象要管理很多个请求，也就是很多个task，每一个task对应是一个具体的网络请求。一共包括三种Task，三种Task的结构如图。

![NSURLSessionTask](https://tva1.sinaimg.cn/large/006y8mN6ly1g80f3ekh27j30xw0hogls.jpg)

- 管理Task的状态方法

```objective-c
- (void)cancel //取消一个task
- (void)resume //如果task在挂起状态，则继续执行task
- (void)suspend //挂起task
```

#### 三种Task

1. NSURLSessionDataTask

   - 以`NSData`的形式接收`服务器返回的数据`，适用于`频繁的短小通讯`

   我们可以通过request对象或url对象创建NSURLSessionDataTask对象，也可以选择用代理或者Block来接收数据

   ```objective-c
   //这两个方法需要设置代理来接收数据
   //通过NSURLRequest、创建NSURLSessionDataTask
   - (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request;
   //通过NSURL、创建NSURLSessionDataTask
   - (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url;
   
   //这两个方法通过Block来接收数据
   //通过NSURLRequest、创建NSURLSessionDataTask
   - (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
   //通过NSURL、创建NSURLSessionDataTask
   - (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
   ```

   

2. NSURLSessionDownloadTask

   - 以`文件`的形式接收服务器返回的数据，解决了大文件下载的`内存管理`问题，能够断点续传，支持后台下载

   ```objective-c
   //代理方式
   //通过NSURLRequest、创建NSURLSessionDownloadTask
   - (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request;  
   //通过NSURL、创建NSURLSessionDownloadTask
   - (NSURLSessionDownloadTask *)downloadTaskWithURL:(NSURL *)url;  
   //通过之前已经下载的数据来创建下载任务
   - (NSURLSessionDownloadTask *)downloadTaskWithResumeData:(NSData *)resumeData;  
   
   //Block方式
   //通过NSURLReques、创建NSURLSessionDownLoadTask
   - (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURL *location, NSURLResponse *response, NSError *error))completionHandler;  
   //通过NSURL、创建NSURLSessionDownloadTask
   - (NSURLSessionDownloadTask *)downloadTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSURL *location, NSURLResponse *response, NSError *error))completionHandler;  
   //通过NSData、创建NSURLSessionDownloadTask
   - (NSURLSessionDownloadTask *)downloadTaskWithResumeData:(NSData *)resumeData completionHandler:(void (^)(NSURL *location, NSURLResponse *response, NSError *error))completionHandler;
   ```

   

3. NSURLSessionUploadTask

   - 向服务器发送文件数据、支持后台上传

   ```objective-c
   //代理方式
   //通过文件url来上传
   - (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL;  
   //通过文件data来上传
   - (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData;  
   //通过文件流来上传
   - (NSURLSessionUploadTask *)uploadTaskWithStreamedRequest:(NSURLRequest *)request;
   
   //Block方式
   - (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;  
   - (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler; 
   ```

   

## NSURLSession和NSURLConnection区别

### 1、 使用现状

​     NSURLSession是NSURLConnection 的替代者，在2013年苹果全球开发者大会（WWDC2013）随ios7一起发布，是对NSURLConnection进行了重构优化后的新的网络访问接口。从iOS9.0开始， NSURLConnection中发送请求的两个方法已过期（同步请求，异步请求），初始化网络连接（initWithRequest: delegate:）的方法也被设置为过期，系统不再推荐使用，建议使用NSURLSession发送网络请求。

### 2、普通任务和上传

​     NSURLSession针对下载/上传等复杂的网络操作提供了专门的解决方案，针对普通、上传和下载分别对应三种不同的网络请求任务：NSURLSessionDataTask, NSURLSessionUploadTask和NSURLSessionDownloadTask.。创建的task都是挂起状态，需要resume才能执行。 当服务器返回的数据较小时，NSURLSession与NSURLConnection执行普通任务的操作步骤没有区别。 执行上传任务时，NSURLSession与NSURLConnection一样同样需要设置POST请求的请求体进行上传。 

### 3、下载任务方式

​     NSURLConnection下载文件时，先将整个文件下载到内存，然后再写入沙盒，如果文件比较大，就会出现内存暴涨的情况。而使用NSURLSessionDownloadTask下载文件，会默认下载到沙盒中的tem文件夹中，不会出现内存暴涨的情况，但在下载完成后会将tem中的临时文件删除，需要在初始化任务方法时，在completionHandler回调中增加保存文件的代码。 以下代码是实例化网络下载任务时将下载的文件保存到沙盒的caches文件夹中:

```objective-c
[NSURLSessionDownloadTask [NSURLSessionDownloadTask *task = [session downloadTaskWithURL:[NSURL URLWithString:@"http://192.168.1.17/xxxx.zip"] completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
// 获取沙盒的caches路径 
NSString *path = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]stringByAppendingPathComponent:@"xxx.dmg"];
// 生成URL路径
NSURL *url = [NSURL fileURLWithPath:path]; 
// 将文件保存到指定文件目录下 
[[NSFileManager defaultManager]moveItemAtURL:location toURL: url error:nil]; 
}] resume];
```

### 4、请求方法的控制

​     NSURLConnection实例化对象，实例化开始，默认请求就发送（同步发送），不需要调用start方法。而cancel 可以停止请求的发送，停止后不能继续访问，需要创建新的请求。 NSURLSession有三个控制方法，取消（cancel），暂停（suspend），继续（resume），暂停后可以通过继续恢复当前的请求任务。

### 5、断点续传的方式

​     NSURLConnection进行断点下载，通过设置访问请求的HTTPHeaderField的Range属性，开启运行循环，NSURLConnection的代理方法作为运行循环的事件源，接收到下载数据时代理方法就会持续调用，并使用NSOutputStream管道流进行数据保存。 NSURLSession进行断点下载，当暂停下载任务后，如果 downloadTask （下载任务）为非空，调用 cancelByProducingResumeData:(void (^)(NSData *resumeData))completionHandler 这个方法，这个方法接收一个参数，完成处理代码块，这个代码块有一个 NSData 参数 resumeData，如果 resumeData 非空，我们就保存这个对象到视图控制器的 resumeData 属性中。在点击再次下载时，通过调用 [ [self.session downloadTaskWithResumeData:self.resumeData] resume]方法进行继续下载操作。 经过以上比较可以发现，使用NSURLSession进行断点下载更加便捷。

### 6、配置信息

​     NSURLSession的构造方法（sessionWithConfiguration:delegate:delegateQueue）中有一个 NSURLSessionConfiguration类的参数可以设置配置信息，其决定了cookie，安全和高速缓存策略，最大主机连接数，资源管理，网络超时等配置。NSURLConnection不能进行这个配置，相比于 NSURLConnection 依赖于一个全局的配置对象，缺乏灵活性而言，NSURLSession 有很大的改进了。 NSURLSession可以设置三种配置信息，分别通过调用三个累方法返回配置对象：

​     \+ (NSURLSessionConfiguration *)defaultSessionConfiguration，配置信息使用基于硬盘的持久话Cache，保存用户的证书到钥匙串,使用共享cookie存储；

​     \+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration ，配置信息和default大致相同。除了，不会把cache，证书，或者任何和Session相关的数据存储到硬盘，而是存储在内存中，生命周期和Session一致。比如浏览器无痕浏览等功能就可以基于这个来做；

​     \+ (NSURLSessionConfiguration *)backgroundSessionConfigurationWithIdentifier:(NSString *)identifier，配置信息可以创建一个可以在后台甚至APP已经关闭的时候仍然在传输数据的session。注意，后台Session一定要在创建的时候赋予一个唯一的identifier，这样在APP下次运行的时候，能够根据identifier来进行相关的区分。如果用户关闭了APP,IOS 系统会关闭所有的background Session。而且，被用户强制关闭了以后，IOS系统不会主动唤醒APP，只有用户下次启动了APP，数据传输才会继续。

### 
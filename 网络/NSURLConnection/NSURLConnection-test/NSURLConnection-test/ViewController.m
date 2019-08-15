//
//  ViewController.m
//  NSURLConnection-test
//
//  Created by _祀梦 on 2019/8/15.
//  Copyright © 2019 涂强尧. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () <NSURLConnectionDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //通过NSData下载小文件
//    [NSThread detachNewThreadSelector:@selector(nsDataDownload) toTarget:self withObject:nil];
    
//    //下载小文件
//    [self NSURLConnectionDownLoadSmallFile];
    
    self.progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(50, 200, 300, 20)];
    [self.view addSubview:self.progressView];
    
    self.progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 250, 200, 30)];
    [self.view addSubview:self.progressLabel];
    //下载大文件
    [self NSURLConnectionDownLoadBigFile];
}

#pragma NSData(小文件)
- (void)NSDataDownload {
    // 创建下载路径
    NSURL *url = [NSURL URLWithString:@"http://pics.sc.chinaz.com/files/pic/pic9/201508/apic14052.jpg"];
    
    // 使用NSData的dataWithContentsOfURL:方法下载
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSLog(@"%@", data);
}

#pragma NSURLConnection(小文件下载)
//NSURLConnection发送异步GET请求来下载文件
- (void)NSURLConnectionDownLoadSmallFile {
    // 创建下载路径
    NSURL *url = [NSURL URLWithString:@"http://pics.sc.chinaz.com/files/pic/pic9/201508/apic14052.jpg"];
    
    // 使用NSURLConnection发送异步GET请求，
    // 该方法在iOS9.0之后就废除了（推荐使用NSURLSession）
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:url] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        NSLog(@"%@",data);
        
        // 可以在这里把下载的文件保存起来
    }];
}

- (void)NSURLConnectionDownLoadBigFile {
    // 创建下载路径
    NSURL *url = [NSURL URLWithString:@"http://bmob-cdn-8782.b0.upaiyun.com/2017/01/17/24b0b37f40d8722480a23559298529f4.mp3"];
    
    // 使用NSURLConnection发送异步Get请求，并实现相应的代理方法，该方法iOS9.0之后废除了。
    [NSURLConnection connectionWithRequest:[NSURLRequest requestWithURL:url] delegate:self];
}

//接收到响应的时候：创建一个空的沙盒文件和文件句柄
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(nonnull NSURLResponse *)response {
    //获取下载文件的总长度
    self.fileLength = response.expectedContentLength;
    
    //沙盒文件路径
    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:response.suggestedFilename];
    
    //打印下载的沙盒路径
    NSLog(@"File downLoaded to: %@", path);
    
    //创建一个空的文件到沙盒中
    [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    
    //创建文件句柄
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
}

//接收到具体数据：把数据写入沙盒文件中
- (void)connection:(NSURLConnection *)connection didReceiveData:(nonnull NSData *)data {
    //指定数据的写入位置---文件内容的最后面
    [self.fileHandle seekToEndOfFile];
    
    //向沙盒写入数据
    [self.fileHandle writeData:data];
    
    //拼接文件总长度
    self.currentLength += data.length;
    
    //下载进度
    self.progressView.progress = 1.0*self.currentLength/self.fileLength;
    self.progressLabel.text = [NSString stringWithFormat:@"当前下载进度:%.2f%%",100.0 * self.currentLength / self.fileLength];
}

//下载完文件之后调用：关闭文件、清空长度
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    //关闭fileHandle
    [self.fileHandle closeFile];
    self.fileHandle = nil;
    
    //清空长度
    self.currentLength = 0;
    self.fileHandle = 0;
}
@end

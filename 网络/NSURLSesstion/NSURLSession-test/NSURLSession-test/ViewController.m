//
//  ViewController.m
//  NSURLSession-test
//
//  Created by _祀梦 on 2019/8/15.
//  Copyright © 2019 涂强尧. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () <NSURLSessionDelegate, NSURLSessionDataDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //通过blcok完成下载
//    [self NSURLSessionDownLoadWithBlock];
    //通过代理方法完成下载
    [self NSURLSessionDownLoadWithDelegate];
}

#pragma block方法
- (void)NSURLSessionDownLoadWithBlock {
    //创建下载路径
    NSURL *url = [NSURL URLWithString:@"http://bmob-cdn-8782.b0.upaiyun.com/2017/01/17/c6b6bb1640e9ae9e80b221c454c4e90d.jpg"];
    
    //创建NSURLRequest请求
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    
    //创建NSURLSession对象
    NSURLSession *session = [NSURLSession sharedSession];
    
    
    //创建下载任务，其中location为下载的临时文件路径
    NSURLSessionDownloadTask *downLoadTask = [session downloadTaskWithURL:url completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        //将文件要移动到指定目录
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        
        //新文件路径
        NSString *newFilePath = [documentsPath stringByAppendingPathComponent:response.suggestedFilename];
        
        //移动文件到新路径
        [[NSFileManager defaultManager] moveItemAtPath:location.path toPath:newFilePath error:nil];
    }];
    
    //开始下载任务
    [downLoadTask resume];
    NSLog(@"%@", downLoadTask);
}

#pragma 代理方法
- (void)NSURLSessionDownLoadWithDelegate {
    //创建下载路径
    NSURL *url = [NSURL URLWithString:@"http://dldir1.qq.com/qqfile/QQforMac/QQ_V5.4.0.dmg"];
    
    //创建NSURLSession对象，并设计代理方法。其中NSURLSessionConfiguration为默认配置
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    
    //创建任务
    NSURLSessionDownloadTask *downLoadTask = [session downloadTaskWithURL:url];
    
    [downLoadTask resume];
}

//文件下载完毕时调用
- (void)urlsession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    // 文件将要移动到的指定目录
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    
    // 新文件路径
    NSString *newFilePath = [documentsPath stringByAppendingPathComponent:@"QQ_V5.4.0.dmg"];
    
    NSLog(@"File downloaded to: %@",newFilePath);
    
    // 移动文件到新路径
    [[NSFileManager defaultManager] moveItemAtPath:location.path toPath:newFilePath error:nil];
    
}

/*
    每次写入数据到临时文件时，就会调用一次这个方法。可在这里获得下载进度
 
    @param bytesWritten              这次写入的文件大小
    @param totalBytesWritten         已经写入沙盒的文件大小
    @param totalBytesExpectedToWrite 文件总大小
 */
- (void)URLSession:(NSURLSession *)session dataTask:(nonnull NSURLSessionDataTask *)dataTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    NSLog(@"%@", [NSString stringWithFormat:@"当前下载进度:%.2f%%",100.0 * totalBytesWritten / totalBytesExpectedToWrite]);
}

@end

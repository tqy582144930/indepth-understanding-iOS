//
//  ViewController.h
//  NSURLConnection-test
//
//  Created by _祀梦 on 2019/8/15.
//  Copyright © 2019 涂强尧. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController
//下载进度条
@property (nonatomic, strong) UIProgressView *progressView;
//下载进度条
@property (nonatomic, strong) UILabel *progressLabel;

//NSURLConnection下载大文件用到的属性
//文件总长度
@property (nonatomic, assign) NSInteger fileLength;
//当前下载长度
@property (nonatomic, assign) NSInteger currentLength;
//文件句柄
@property (nonatomic, strong) NSFileHandle *fileHandle;

@end


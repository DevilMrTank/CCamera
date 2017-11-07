//
//  CCameraManager.h
//  crd
//
//  Created by 笔记本 on 2017/4/11.
//  Copyright © 2017年 crd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/avfoundation.h>

@class CMMotionManager;

typedef void(^FinishBlock)(void);
//原图 比例图 裁剪图 （原图是你照相机摄像头能拍出来的大小，比例图是按照原图的比例去缩小一倍，裁剪图是你设置好的摄像范围的图片）
//typedef void(^TakePhotoWithImageBlock)(UIImage *originImage, UIImage *scaledImage, UIImage *croppedImage);
typedef void(^TakePhotoWithImageBlock)(UIImage *originImage);

typedef void(^SwitchCameraBlock)(void);

@protocol CCameraManagerFocusDelegate <NSObject>

@optional
//对焦中
- (void)cameraDidStareFocus;
//对焦完成
- (void)cameraDidFinishFocus;

@end

@interface CCameraManager : NSObject
//执行输入和输出设备间的数据传输
@property (nonatomic, strong) AVCaptureSession *session;

@property (nonatomic, strong) CMMotionManager * motionManager;

@property (nonatomic, weak) id<CCameraManagerFocusDelegate> delegate;

- (instancetype)initWithParentView:(UIView *)view;

/**
 拍照回调
 */
- (void)takePhotoWithImageBlock:(TakePhotoWithImageBlock)block;

/**
 切换闪光灯模式

 @param button 触发按钮
 */
- (void)switchFlashModeWithButton:(UIButton *)button;

/**
 切换前后摄像头

 @param isFrontCamera 是否是前置摄像头
 @param block 回调
 */
- (void)switchCamera:(BOOL)isFrontCamera didFinishChangeBlock:(SwitchCameraBlock)block;

/**
 点击对焦

 @param devicePoint 点击点坐标
 */
- (void)focusInPoint:(CGPoint)devicePoint;

/**
 检查是否有权限
 */
+ (BOOL)checkAuthority;

- (void)updatePreviewLayoutFrame:(UIView *)parent;

/**
 关闭重力感应
 */
- (void)stopMotionManager;

@end

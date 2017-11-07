//
//  CCameraManager.m
//  crd
//
//  Created by 笔记本 on 2017/4/11.
//  Copyright © 2017年 crd. All rights reserved.
//

#import "CCameraManager.h"
#import "UIImage+CResize.h"
#import <CoreMotion/CoreMotion.h>

#define cameraManagerFocusKey      @"focusKey"
#define cameraManagerQueueName     "queue_name"
#define printLogWithNoDevice       NSLog(@"设备没有照相机")

@interface CCameraManager () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate, CAAnimationDelegate>

@property (nonatomic, strong) dispatch_queue_t sessionQueue;
//输入设备
@property (nonatomic, strong) AVCaptureDeviceInput *deviceInput;
//照片输出流对象
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;
//预览图层，显示照相机拍摄到的画面
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
//焦点图
@property (nonatomic, strong) UIImageView *focusImageView;
//是否手动对焦
@property (nonatomic, assign) BOOL isManualFocus;

@property (nonatomic, copy) FinishBlock finishBlock;

@property (nonatomic, assign) UIDeviceOrientation deviceOriention;

@end

@implementation CCameraManager
#pragma mark - Init

- (void)dealloc {
    
//    NSLog(@"照相机管理人释放了");
    if ([self.session isRunning]) {
        [self.session stopRunning];
        self.session = nil;
    }
    [self setFocusObserver:NO];
    [self stopMotionManager];
}

- (instancetype)init {
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithParentView:(UIView *)parent {
    if (self = [super init]) {
        [self setup];
        [self configureWithParentLayer:parent];
    }
    return self;
}

- (void)setup {
    
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    //添加输入设备（前置或者后置摄像头）
    [self addVideoInputFrontCamera:NO];
    //对焦MVO
    [self setFocusObserver:YES];
    //获取设备方向
    [self startMotionManager];
}

- (void)configureWithParentLayer:(UIView *)parent {
    
    if (!parent) {
        NSLog(@"no parent view");
        return;
    }
    self.previewLayer.frame = parent.bounds;
    [parent.layer addSublayer:self.previewLayer];
    //加入对焦框
    [self initFocusImageWithParent:parent];
}

- (void)updatePreviewLayoutFrame:(UIView *)parent {
    self.previewLayer.frame = parent.bounds;
    self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
}

- (void)initFocusImageWithParent:(UIView *)view {
    
    //if (self.focusImageView) {
    //    return;
    //}
    if (view.superview) {
        [view.superview addSubview:self.focusImageView];
    } else {
        self.focusImageView = nil;
    }
}

//添加前后摄像头
- (void)addVideoInputFrontCamera:(BOOL)front {
    
    NSArray *devices = [AVCaptureDevice devices];
    AVCaptureDevice *frontCamera;
    AVCaptureDevice *backCamera;
    for (AVCaptureDevice *device in devices) {
        if ([device hasMediaType:AVMediaTypeVideo]) {
            if ([device position] == AVCaptureDevicePositionBack) {
                backCamera = device;
            } else {
                frontCamera = device;
            }
        }
    }
    
    NSError *error = nil;
    if (front) {
        AVCaptureDeviceInput *frontDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:&error];
        if (!error) {
            if ([_session canAddInput:frontDeviceInput]) {
                [_session addInput:frontDeviceInput];
                self.deviceInput = frontDeviceInput;
            } else {
                NSLog(@"add front device input error");
            }
        } else {
            printLogWithNoDevice;
        }
    } else {
        AVCaptureDeviceInput *backDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
        if (!error) {
            if ([_session canAddInput:backDeviceInput]) {
                self.deviceInput = backDeviceInput;
                [_session addInput:self.deviceInput];
                //self.deviceInput = backDeviceInput;
            } else {
                NSLog(@"add back device input error");
            }
        } else {
            printLogWithNoDevice;
        }
    }
    if (error) {
        printLogWithNoDevice;
    }
}

#pragma mark - Check Authority
+ (BOOL)checkAuthority {
    
    NSString *mediaType = AVMediaTypeVideo;
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied) {
        return NO;
    }
    return YES;
}

#pragma mark - Take photo callback
- (void)takePhotoWithImageBlock:(TakePhotoWithImageBlock)block {
    
    AVCaptureConnection *videoConnection = [self findVideoConnection];
    if (!videoConnection) {
        printLogWithNoDevice;
        return;
    }
    WeakSelf
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        
        if (error) {
            return;
        }
        
        CABasicAnimation *caAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        caAnimation.fromValue = @(1.2);
        caAnimation.toValue = @(0.0);
        caAnimation.duration = 0.3f;
        caAnimation.repeatCount = 1;
        caAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [weakSelf.previewLayer addAnimation:caAnimation forKey:@"animScale"];
        
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage *originImage = [[UIImage alloc]initWithData:imageData];
//        NSLog(@"originImage = %@", originImage);
        
//        CGFloat squareLength = weakSelf.previewLayer.bounds.size.width;
//        CGFloat previewLayerH = weakSelf.previewLayer.bounds.size.height;
//        CGSize size = CGSizeMake(squareLength * 2, previewLayerH * 2);
//        UIImage *scaledImage = [originImage resizedImageWithContentMode:UIViewContentModeScaleAspectFit
//                                                           bounds:size
//                                                interpolationQuality:kCGInterpolationHigh];
////        NSLog(@"scaledImage = %@", scaledImage);
//        
//        CGRect cropFrame = CGRectMake((scaledImage.size.width - size.width) / 2, (scaledImage.size.height - size.height) / 2, size.width, size.height);
//        UIImage *cropedImage = [scaledImage croppedImage:cropFrame];
//        NSLog(@"croppedImage = %@", cropedImage);
        
        originImage = [originImage fixOrientation];
        
//        UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
//        NSLog(@"device orientation = %ld", orientation);
//        NSLog(@"image.Orientation = %ld", originImage.imageOrientation);
//        NSLog(@"_deviceOriention = %ld", _deviceOriention);
        if (_deviceOriention != UIDeviceOrientationPortrait) {
            CGFloat degree = 0;
            if (_deviceOriention == UIDeviceOrientationPortraitUpsideDown) {
                //M_PI     2
                degree = 180;
            } else if (_deviceOriention == UIDeviceOrientationLandscapeLeft) {
                //-M_PI_2    3
                degree = -90;
            } else if (_deviceOriention == UIDeviceOrientationLandscapeRight) {
                //M_PI_2    4
                degree = 90;
            }
            originImage = [originImage rotatedByDegrees:degree];
//            scaledImage = [scaledImage rotatedByDegrees:degree];
//            cropedImage = [cropedImage rotatedByDegrees:degree];
        }
        
//        originImage = [originImage rotation:originImage.imageOrientation];
        
//        UIImageWriteToSavedPhotosAlbum(originImage, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
//        originImage = [originImage fixOrientation];
        
//        UIImageWriteToSavedPhotosAlbum(originImage, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);

        if (block) {
            block(originImage);
        }
    }];
}

- (void)image: (UIImage *) image didFinishSavingWithError: (NSError *) error contextInfo: (void *) contextInfo

{
//    NSString *msg = nil ;
//    if(error != NULL){
//        msg = @"保存图片失败" ;
//    }else{
//        msg = @"保存图片成功" ;
//    }
//    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"保存图片结果提示"
//                                                    message:msg
//                                                   delegate:self
//                                          cancelButtonTitle:@"确定"
//                                          otherButtonTitles:nil];
//    [alert show];
}

#pragma mark - Switch action
- (void)switchFlashModeWithButton:(UIButton *)button {
    
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (!captureDeviceClass) {
        printLogWithNoDevice;
        return;
    }
    NSString *imgName = @"";
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [device lockForConfiguration:nil];
    if ([device hasFlash]) {
        if (device.flashMode == AVCaptureFlashModeOff) {
            device.flashMode = AVCaptureFlashModeOn;
            imgName = @"camera_flashing_on.png";
        } else if (device.flashMode == AVCaptureFlashModeOn) {
            device.flashMode = AVCaptureFlashModeAuto;
            imgName = @"camera_flashing_auto.png";
        } else if (device.flashMode == AVCaptureFlashModeAuto) {
            device.flashMode = AVCaptureFlashModeOff;
            imgName = @"camera_flashing_off.png";
        }
        if (button) {
            [button setImage:ImageNamed(imgName) forState:UIControlStateNormal];
        }
    } else {
        NSLog(@"camera has no function of flashing");
    }
    
    [device unlockForConfiguration];
}

- (void)switchCamera:(BOOL)isFrontCamera didFinishChangeBlock:(SwitchCameraBlock)block {
    
    if (!_deviceInput) {
        if (block) {
            block();
        }
        printLogWithNoDevice;
        return;
    }
    if (block) {
        self.finishBlock = [block copy];
    }
    CABasicAnimation *caAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.y"];
    caAnimation.fromValue = @(0);
    caAnimation.toValue = @(M_PI);
    caAnimation.duration = 0.5f;
    caAnimation.repeatCount = 1;
    caAnimation.delegate = self;
    caAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [self.previewLayer addAnimation:caAnimation forKey:@"anim"];
    
    //防止阻塞主线程
    WeakSelf
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [weakSelf.session beginConfiguration];
        [weakSelf.session removeInput:weakSelf.deviceInput];
        [weakSelf addVideoInputFrontCamera:isFrontCamera];
        [weakSelf.session commitConfiguration];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
        });
    });
}

#pragma mark - Animation Stop
- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    
    if (self.finishBlock) {
        self.finishBlock();
    }
}

#pragma mark - Click to focus
- (void)focusInPoint:(CGPoint)devicePoint {
    
    if (!CGRectContainsPoint(self.previewLayer.bounds, devicePoint)) {
        return;
    }
    
    self.isManualFocus = YES;
    [self focusImageAnimateWithCenterPoint:devicePoint];
//    devicePoint = [self convertToPointOfInterestFromViewCoordinates:devicePoint];
}

#pragma mark - Find camera connection
- (AVCaptureConnection *)findVideoConnection {
    
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in self.stillImageOutput.connections) {
        for (AVCaptureInputPort *port in connection.inputPorts) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                videoConnection = connection;
                return videoConnection;
            }
        }
    }
    return videoConnection;
}


/**
 外部的point转换为camera需要的point

 @param viewCoordinates 外部的point
 @return 相对位置的point
 */
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates {
    
    CGPoint pointOfInterest = CGPointMake(0.5f, 0.5f);
    CGSize frameSize = self.previewLayer.bounds.size;
    
    AVCaptureVideoPreviewLayer *videoPreviewLayer = self.previewLayer;
    if ([[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResize]) {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.0f - (viewCoordinates.x / frameSize.width));
    } else {
        CGRect cleanAperture;
        for (AVCaptureInputPort *port in [[self.session.inputs lastObject] ports]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;
                
                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;
                
                if ([[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspect]) {
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
                        if (point.x >= blackBar && point.x <= blackBar + x2) {
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    } else {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
                        if(point.y >= blackBar && point.y <= blackBar + y2) {
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                } else if([[videoPreviewLayer videoGravity]isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                    if(viewRatio > apertureRatio) {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2;
                        yc = (frameSize.width - point.x) / frameSize.width;
                    } else {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                        xc = point.y / frameSize.height;
                    }
                    
                }
                
                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
    }
    
    return pointOfInterest;
}

#pragma mark - Focus
- (void)focusImageAnimateWithCenterPoint:(CGPoint)point {
    
    [self.focusImageView setCenter:point];
    self.focusImageView.transform = CGAffineTransformMakeScale(2.0, 2.0);
    WeakSelf
    [UIView animateWithDuration:0.3f delay:0.f options:UIViewAnimationOptionAllowUserInteraction animations:^{
        weakSelf.focusImageView.alpha = 1.f;
        weakSelf.focusImageView.transform = CGAffineTransformMakeScale(1.0, 1.0);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.5f delay:0.5f options:UIViewAnimationOptionAllowUserInteraction animations:^{
            weakSelf.focusImageView.alpha = 0.f;
        } completion:^(BOOL finished) {
            weakSelf.isManualFocus = NO;
        }];
    }];
}

#pragma mark - Focus Obserer
- (void)setFocusObserver:(BOOL)flag {
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (device && [device isFocusPointOfInterestSupported]) {
        if (flag) {
            [device addObserver:self forKeyPath:cameraManagerFocusKey options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
        } else {
            [device removeObserver:self forKeyPath:cameraManagerFocusKey context:nil];
        }
    } else {
        printLogWithNoDevice;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:cameraManagerFocusKey]) {
        BOOL isFocus = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        if (isFocus) {
            if (!self.isManualFocus) {
                [self focusImageAnimateWithCenterPoint:CGPointMake(self.previewLayer.bounds.size.width / 2, self.previewLayer.bounds.size.height / 2)];
            }
            if (self.delegate && [self.delegate respondsToSelector:@selector(cameraDidStareFocus)]) {
                [self.delegate cameraDidStareFocus];
            }
        } else {
            if (self.delegate && [self.delegate respondsToSelector:@selector(cameraDidFinishFocus)]) {
                [self.delegate cameraDidFinishFocus];
            }
        }
    }
}

//获取屏幕方向
- (void)startMotionManager{
    if (_motionManager == nil) {
        _motionManager = [[CMMotionManager alloc] init];
    }
    _motionManager.deviceMotionUpdateInterval = 1/15.0;
    if (_motionManager.deviceMotionAvailable) {
//        NSLog(@"Device Motion Available");
        [_motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue]
                                            withHandler: ^(CMDeviceMotion *motion, NSError *error){
                                                [self performSelectorOnMainThread:@selector(handleDeviceMotion:) withObject:motion waitUntilDone:YES];
                                                
                                            }];
    } else {
        NSLog(@"No device motion on device.");
        [self setMotionManager:nil];
    }
}

- (void)stopMotionManager {
    if (_motionManager) {
        [_motionManager stopDeviceMotionUpdates];
        _motionManager = nil;
    }
}

- (void)handleDeviceMotion:(CMDeviceMotion *)deviceMotion{
    double x = deviceMotion.gravity.x;
    double y = deviceMotion.gravity.y;
    if (fabs(y) >= fabs(x))
    {
        if (y >= 0){
            // UIDeviceOrientationPortraitUpsideDown;
//            NSLog(@"UIDeviceOrientationPortraitUpsideDown");
            _deviceOriention = UIDeviceOrientationPortraitUpsideDown;
        }
        else{
            // UIDeviceOrientationPortrait;
//            NSLog(@"UIDeviceOrientationPortrait");
            _deviceOriention = UIDeviceOrientationPortrait;
        }
    }
    else
    {
        if (x >= 0){
            // UIDeviceOrientationLandscapeRight;
//            NSLog(@"UIDeviceOrientationLandscapeRight");
            _deviceOriention = UIDeviceOrientationLandscapeRight;
        }
        else{
            // UIDeviceOrientationLandscapeLeft;
//            NSLog(@"UIDeviceOrientationLandscapeLeft");
            _deviceOriention = UIDeviceOrientationLandscapeLeft;
        }
    }
}

#pragma mark - lazy load
//创建一个队列，防止阻塞主线程(对焦队列)
- (dispatch_queue_t)sessionQueue {
    if (!_sessionQueue) {
        _sessionQueue = dispatch_queue_create(cameraManagerQueueName, DISPATCH_QUEUE_SERIAL);
    }
    return _sessionQueue;
}

- (AVCaptureSession *)session {
    if (!_session) {
        _session = [[AVCaptureSession alloc] init];
        //添加输入设备
        if ([_session canAddInput:self.deviceInput]) {
            [_session addInput:self.deviceInput];
        }
        
        //添加输出设备
        if ([_session canAddOutput:self.stillImageOutput]) {
            [_session addOutput:self.stillImageOutput];
        }
    }
    return _session;
}

- (AVCaptureVideoPreviewLayer *)previewLayer {
    if (!_previewLayer) {
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    }
    return _previewLayer;
}

- (AVCaptureStillImageOutput *)stillImageOutput {
    if (!_stillImageOutput) {
        _stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        //输出格式jpeg
        NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG, AVVideoCodecKey, nil];
        _stillImageOutput.outputSettings = outputSettings;
    }
    return _stillImageOutput;
}

- (UIImageView *)focusImageView {
    if (!_focusImageView) {
        _focusImageView = [[UIImageView alloc] initWithImage:ImageNamed(@"camera_focus.png")];
        _focusImageView.alpha = 0.f;
    }
    return _focusImageView;
}

@end

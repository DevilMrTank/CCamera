//
//  UIImage+CResize.h
//  crd
//
//  Created by 笔记本 on 2017/4/11.
//  Copyright © 2017年 crd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (CResize)

- (UIImage *)croppedImage:(CGRect)bounds;

- (UIImage *)resizedImage:(CGSize)newSize
     interpolationQuality:(CGInterpolationQuality)quality;

- (UIImage *)resizedImageWithContentMode:(UIViewContentMode)contentMode
                                  bounds:(CGSize)bounds
                    interpolationQuality:(CGInterpolationQuality)quality;

- (UIImage *)resizedImage:(CGSize)newSize
                transform:(CGAffineTransform)transform
           drawTransposed:(BOOL)transpose
     interpolationQuality:(CGInterpolationQuality)quality;

- (CGAffineTransform)transformForOrientation:(CGSize)newSize;

- (UIImage *)fixOrientation;

- (UIImage *)rotatedByDegrees:(CGFloat)degrees;

- (UIImage *)rotation:(UIImageOrientation)orientation;

//- (UIImage *)rotateImageByOrientation:(UIImageOrientation)orientation;

@end

//
//  OpenCVWrapper.h
//  VisionBasics
//
//  Created by Tananya Prankprakma on 6/5/24.
//  Copyright © 2024 Apple. All rights reserved.
//

#ifndef OpenCVWrapper_h
#define OpenCVWrapper_h


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface OpenCVWrapper : NSObject


+ (UIImage *)drawContoursOnImage:(UIImage *)image
                    centerPoints:(NSArray<NSValue *> **)centerPoints
                   averageColors:(NSArray<NSArray<NSNumber *> *> **)averageColors
                           areas:(NSArray<NSNumber *> **)areas
                      identifiers:(NSArray<NSNumber *> **)identifiers;
@end


#endif /* OpenCVWrapper_h */


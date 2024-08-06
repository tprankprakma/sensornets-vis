//
//  OpenCVWrapper.m
//  VisionBasics
//
//  Created by Tananya Prankprakma on 6/5/24.
//  Copyright © 2024 Apple. All rights reserved.
//


#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#import "OpenCVWrapper.h"



@implementation OpenCVWrapper



+ (UIImage *)drawContoursOnImage:(UIImage *)image
                    centerPoints:(NSArray<NSValue *> **)centerPoints
                   averageColors:(NSArray<NSArray<NSNumber *> *> **)averageColors
                           areas:(NSArray<NSNumber *> **)areas
                           identifiers:(NSArray<NSNumber *> **)identifiers{
    // Convert UIImage to cv::Mat
    cv::Mat cvImage;
    UIImageToMat(image, cvImage);

    // Convert the image to grayscale for contour detection
    cv::Mat grayImage;
    if (cvImage.channels() > 1) {
        cv::cvtColor(cvImage, grayImage, cv::COLOR_BGR2GRAY);
    } else {
        grayImage = cvImage;
    }

    // Apply thresholding
    double threshold = 220;
    cv::Mat binaryImage;
    cv::threshold(grayImage, binaryImage, threshold, 255, cv::THRESH_BINARY);

    // Find contours
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(binaryImage, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);

    // Draw contours and calculate centers, average colors, and areas
    cv::Mat contourImage = cv::Mat::zeros(cvImage.size(), CV_8UC3);
    NSMutableArray *centerPointsArray = [NSMutableArray array];
    NSMutableArray *averageColorsArray = [NSMutableArray array];
    NSMutableArray *areasArray = [NSMutableArray array];
    NSMutableArray *identifiersArray = [NSMutableArray array];

    double maxRadius = 0;
    std::vector<double> radii;

    // First pass to determine the maximum radius
    for (const auto &contour : contours) {
        double area = cv::contourArea(contour);
        double radius = sqrt(area / CV_PI);
        radii.push_back(radius);
        if (radius > maxRadius) {
            maxRadius = radius;
        }
    }

    // Set the mask radius
    double maskRadius = 3 * maxRadius;

    for (size_t i = 0; i < contours.size(); i++) {
        cv::drawContours(contourImage, contours, static_cast<int>(i), cv::Scalar(0, 255, 0), 2);

        // Calculate center of contour using moments
        cv::Moments m = cv::moments(contours[i]);
        cv::Point2f center(m.m10 / m.m00, m.m01 / m.m00);

        // Draw the identifier number at the center of the contour
        std::string text = std::to_string(i);
        [identifiersArray addObject:@(i)];
        int fontFace = cv::FONT_HERSHEY_SIMPLEX;
        double fontScale = 2;
        int thickness = 1;
        cv::putText(contourImage, text, center, fontFace, fontScale, cv::Scalar(255, 0, 0), thickness);

        // Store center point
        CGPoint cgCenter = CGPointMake(center.x, center.y);
        [centerPointsArray addObject:[NSValue valueWithCGPoint:cgCenter]];

        // Create mask with a circle centered on the blob with radius of 3 times the largest radius
        cv::Mat circularMask = cv::Mat::zeros(cvImage.size(), CV_8UC1);
        cv::circle(circularMask, center, maskRadius, cv::Scalar(255), -1);

        // Calculate average color within the circular mask
        cv::Scalar meanColor = cv::mean(cvImage, circularMask);
        NSArray<NSNumber *> *rgbColor = @[@(meanColor[0]), @(meanColor[1]), @(meanColor[2])];
        [averageColorsArray addObject:rgbColor];

        // Calculate area of contour
        double area = cv::contourArea(contours[i]);
        [areasArray addObject:@(area)];
    }

    // Convert cv::Mat back to UIImage
    UIImage *resultImage = MatToUIImage(contourImage);

    // Set center points, average colors, and areas
    if (centerPoints != NULL) {
        *centerPoints = [centerPointsArray copy];
    }
    
    if (identifiers != NULL) {
        *identifiers = [identifiersArray copy];
    }

    if (averageColors != NULL) {
        *averageColors = [averageColorsArray copy];
    }

    if (areas != NULL) {
        *areas = [areasArray copy];
    }

    return resultImage;
}




@end


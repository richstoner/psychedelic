//  Psychedelic
//  Created by Richard Stoner on 3/17/12.
//  Copyright (c) 2012, All rights reserved.
//
//  FaceAnalysis.mm

#import "FaceAnalysis.h"
#include <mach/mach_time.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "UIImage+OpenCV.h"

@implementation FaceAnalysis

NSString * const kFaceCascadeFilename = @"haarcascade_frontalface_alt2";
NSString * const kEyesCascadeFilename = @"haarcascade_eye_tree_eyeglasses";

// Should grab a macro for this instead
static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};

// Options for cv::CascadeClassifier::detectMultiScale
const int kHaarOptions =  CV_HAAR_FIND_BIGGEST_OBJECT | CV_HAAR_DO_ROUGH_SEARCH;

static FaceAnalysis *sharedInstance = nil;

#pragma mark - Singleton

// Get the shared instance and create it if necessary.
+ (FaceAnalysis *)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[super allocWithZone:NULL] init];
    }
    return sharedInstance;
}

#pragma mark - Configuration methods

-(BOOL) configureCascade
{
    NSString *faceCascadePath = [[NSBundle mainBundle] pathForResource:kFaceCascadeFilename ofType:@"xml"];
    if (!_faceCascade.load([faceCascadePath UTF8String])) {
        NSLog(@"Could not load face cascade: %@", faceCascadePath);        
        return NO;
    }
    
    NSString *eyeCascadePath = [[NSBundle mainBundle] pathForResource:kEyesCascadeFilename ofType:@"xml"];
    if (!_eyeCascade.load([eyeCascadePath UTF8String])) {
        NSLog(@"Could not load face cascade: %@", eyeCascadePath);        
        return NO;
    }
    
    return YES;
}

- (void)configureWriter
{
    frameDuration = CMTimeMakeWithSeconds(1./30., 90000); 
    nextPTS = kCMTimeZero;
    
    _size = CGSizeMake(640, 480);
    

    NSString *betaCompressionDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.m4v"];    
    NSError *error = nil;
    
    unlink([betaCompressionDirectory UTF8String]);
    
    // initialize compression engine
    assetWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:betaCompressionDirectory]
                                                           fileType:AVFileTypeQuickTimeMovie
                                                              error:&error];
    
    NSParameterAssert(assetWriter);
    if(error)
    {
        NSLog(@"error = %@", [error localizedDescription]);
    }
    
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:_size.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:_size.height], AVVideoHeightKey, nil];
    
    assetWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    
    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    
    assetAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:assetWriterInput
                                                                                    sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    NSParameterAssert(assetWriterInput);
    NSParameterAssert([assetWriter canAddInput:assetWriterInput]);
    
    if ([assetWriter canAddInput:assetWriterInput])
    {
        NSLog(@"I can add this input");
    }
    else
    {
        NSLog(@"i can't add this input");
    }
    
    [assetWriter addInput:assetWriterInput];
    
    [assetWriter startWriting];
    [assetWriter startSessionAtSourceTime:kCMTimeZero];

    
}

#pragma mark - Postprocessing methods (OpenCV)

-(void) trackHeadEye:(CVImageBufferRef)_imageBuffer
{
    
    IplImage *iplimage = 0;
    
    uint8_t *bufferBaseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(_imageBuffer, 0);
//    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(_imageBuffer);
    size_t bufferWidth = CVPixelBufferGetWidth(_imageBuffer);
    size_t bufferHeight = CVPixelBufferGetHeight(_imageBuffer);
    
    // create IplImage
    if (bufferBaseAddress) {
        iplimage = cvCreateImage(cvSize(bufferWidth, bufferHeight), IPL_DEPTH_8U, 4);
        iplimage->imageData = (char*)bufferBaseAddress;
    }

    //    printf("iplimage->channelSeq %c\n", iplimage->channelSeq[0]);
    //    printf("iplimage->channelSeq %c\n", iplimage->channelSeq[1]);
    //    printf("iplimage->channelSeq %c\n", iplimage->channelSeq[2]);    
    //    printf("iplimage->channelSeq %c\n", iplimage->channelSeq[3]);        
    
    cv::Mat src = cv::Mat(iplimage);
    cv::Point2f src_center(src.cols/2.0f, src.rows/2.0f);
    cv::Mat rot_mat = cv::getRotationMatrix2D(src_center, 180, 1.0);
    
    cv::Mat rotated;
    cv::warpAffine(src, rotated, rot_mat, src.size());
    
    cv::Mat gray = cv::Mat(bufferWidth, bufferHeight, CV_8U);
    cv::cvtColor(rotated, gray, CV_BGRA2GRAY);
    cv::equalizeHist(gray, gray);
    
    std::vector<cv::Rect> faces;
    
    _faceCascade.detectMultiScale(gray, faces, 1.1, 2, kHaarOptions, cv::Size(60, 60));
    
    NSLog(@"Number of faces: %d", (int)faces.size());
    for(int i = 0; i < faces.size(); i++)
    {
        cv::Rect faceBox = faces[i];
        NSLog(@"\t%d %d - %d %d", faceBox.tl().x, faceBox.tl().y, faceBox.br().x, faceBox.br().y);
        cv::rectangle(rotated, faceBox.tl(), faceBox.br(), cv::Scalar(255, 0, 255, 255), 2);
        
        cv::Mat faceROI = gray(faceBox);
        std::vector<cv::Rect> eyes;
        
        _eyeCascade.detectMultiScale(faceROI, eyes, 1.1, 2, 0 | CV_HAAR_SCALE_IMAGE, cvSize(30, 30));
        if( eyes.size() > 0)
        {
            //-- Draw the face
            //            cv::Point2f center( faces[i].x + faces[i].width*0.5, faces[i].y + faces[i].height*0.5 );
            //            cv::ellipse( rotated, center, cvSize( faces[i].width*0.5, faces[i].height*0.5), 0, 0, 360, cv::Scalar(255, 0, 0, 255), 2, 8, 0 );
            //            cv::rectangle(rotated, faceBox.tl(), faceBox.br(), cv::Scalar(255, 0, 255, 255), 1);
            
            for( int j = 0; j < eyes.size(); j++ )
            { //-- Draw the eyes
                cv::Point2f center( faces[i].x + eyes[j].x + eyes[j].width*0.5, faces[i].y + eyes[j].y + eyes[j].height*0.5 ); 
                int radius = cvRound( (eyes[j].width + eyes[j].height)*0.25 );
                cv::circle( rotated, center, radius, cv::Scalar(255, 0, 0, 255), 1, 8, 0 );
            }
        }
        
    }
    
    cv::Mat finalImage = cv::Mat(bufferWidth, bufferHeight, CV_8UC3);
    cv::cvtColor(rotated, finalImage, CV_BGRA2RGBA);
    
    UIImage* imageFromMat = [[UIImage alloc] initWithCVMat:finalImage];
    
    CVPixelBufferRef newCVPB = [self pixelBufferFromCGImage:[imageFromMat CGImage]];
    
    if (newCVPB)
    {
        if(![assetAdaptor appendPixelBuffer:newCVPB withPresentationTime:nextPTS])
        {
            NSLog(@"FAIL");   
        }
        else
        {
            NSLog(@"Success");
            nextPTS = CMTimeAdd(frameDuration, nextPTS);
        }
    }
    
    CVPixelBufferUnlockBaseAddress(newCVPB,0);
    CFRelease(newCVPB);
    
    cvReleaseImage(&iplimage);
    
}




-(void) trackHeadEyeSmall:(CVImageBufferRef)_imageBuffer
{

    IplImage *iplimage = 0;

    uint8_t *bufferBaseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(_imageBuffer, 0);
//    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(_imageBuffer);
    size_t bufferWidth = CVPixelBufferGetWidth(_imageBuffer);
    size_t bufferHeight = CVPixelBufferGetHeight(_imageBuffer);
        
    // create IplImage
    if (bufferBaseAddress) {
        iplimage = cvCreateImage(cvSize(bufferWidth, bufferHeight), IPL_DEPTH_8U, 4);
        iplimage->imageData = (char*)bufferBaseAddress;
    }
    
//    printf("iplimage->channelSeq %c\n", iplimage->channelSeq[0]);
//    printf("iplimage->channelSeq %c\n", iplimage->channelSeq[1]);
//    printf("iplimage->channelSeq %c\n", iplimage->channelSeq[2]);    
//    printf("iplimage->channelSeq %c\n", iplimage->channelSeq[3]);        
    
    cv::Mat src = cv::Mat(iplimage);
    
    cv::pyrDown(src, src);
    
    cv::Point2f src_center(src.cols/2.0f, src.rows/2.0f);
    cv::Mat rot_mat = cv::getRotationMatrix2D(src_center, 180, 1.0);
    
    cv::Mat rotated;
    cv::warpAffine(src, rotated, rot_mat, src.size());
    
    cv::Mat gray = cv::Mat(src.cols, src.rows, CV_8U);
    cv::cvtColor(rotated, gray, CV_BGRA2GRAY);
    cv::equalizeHist(gray, gray);
    
    std::vector<cv::Rect> faces;
    
    _faceCascade.detectMultiScale(gray, faces, 1.1, 2, kHaarOptions, cv::Size(60, 60));
    
//    NSLog(@"Number of faces: %d", (int)faces.size());
    for(int i = 0; i < faces.size(); i++)
    {
        cv::Rect faceBox = faces[i];
//        NSLog(@"\t%d %d - %d %d", faceBox.tl().x, faceBox.tl().y, faceBox.br().x, faceBox.br().y);
        cv::rectangle(rotated, faceBox.tl(), faceBox.br(), cv::Scalar(255, 0, 255, 255), 1);
        
        cv::Mat faceROI = gray(faceBox);
        std::vector<cv::Rect> eyes;
        
        _eyeCascade.detectMultiScale(faceROI, eyes, 1.1, 2, kHaarOptions, cvSize(20, 20));
        if( eyes.size() > 1)
        {
            for( int j = 0; j < eyes.size(); j++ )
            { //-- Draw the eyes
                cv::Point2f center( faces[i].x + eyes[j].x + eyes[j].width*0.5, faces[i].y + eyes[j].y + eyes[j].height*0.5 ); 
                int radius = cvRound( (eyes[j].width + eyes[j].height)*0.25 );
                cv::circle( rotated, center, radius, cv::Scalar(255, 0, 0, 255), 3, 8, 0 );
            }
        }
  
        NSLog(@"Found %d eyes for face #%d", (int)eyes.size(), i);
    }
    
    cv::Mat finalImage = cv::Mat(src.cols, src.rows, CV_8UC3);
    cv::cvtColor(rotated, finalImage, CV_BGRA2RGBA);
    
    UIImage* imageFromMat = [[UIImage alloc] initWithCVMat:finalImage];
    CVPixelBufferRef newCVPB = [self pixelBufferFromCGImage:[imageFromMat CGImage]];
    if (newCVPB)
    {
        if(![assetAdaptor appendPixelBuffer:newCVPB withPresentationTime:nextPTS])
        {
            NSLog(@"Unable to add pixel buffer to encoder");   
        }
        else
        {
//            NSLog(@"Success");
            nextPTS = CMTimeAdd(frameDuration, nextPTS);
        }
    }
    
    CVPixelBufferUnlockBaseAddress(newCVPB,0);
    CFRelease(newCVPB);
    
    cvReleaseImage(&iplimage);

}
//
//- (UIImage *)imageByDrawingNumberOnImage:(UIImage *)image withNumber:(int)_number
//{
//	// begin a graphics context of sufficient size
//	UIGraphicsBeginImageContext(image.size);
//    
//	// draw original image into the context
//	[image drawAtPoint:CGPointZero];
//    
//	// get the context for CoreGraphics
////	CGContextRef ctx = UIGraphicsGetCurrentContext();
//    
//	// set stroking color and draw circle
//	[[UIColor whiteColor] setStroke];
//    [[UIColor whiteColor] setFill];
//    
////	// make circle rect 5 px from border
////	CGRect circleRect = CGRectMake(0, 0,
////                                   image.size.width,
////                                   image.size.width);
////	circleRect = CGRectInset(circleRect, 5, 5);
//    
//    NSString* text = [NSString stringWithFormat:@"%d", _number];
//    
//    if (_number > 9) {
//        [text drawAtPoint:CGPointMake(9, 5) withFont:[UIFont fontWithName:@"Helvetica" size:12]];        
//    }
//    else {
//        [text drawAtPoint:CGPointMake(13, 5) withFont:[UIFont fontWithName:@"Helvetica" size:12]];
//    }
//    
////    CGContextStrokeEllipseInRect(ctx, circleRect);
//
//    
//	// make image out of bitmap context
//	UIImage *retImage = UIGraphicsGetImageFromCurrentImageContext();
//    
//	// free the context
//	UIGraphicsEndImageContext();
//    
//	return retImage;
//}



- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image
{
    
    CGSize frameSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:NO], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:NO], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, frameSize.width,
                                          frameSize.height,  kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options, 
                                          &pxbuffer);
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, frameSize.width,
                                                 frameSize.height, 8, 4*frameSize.width, rgbColorSpace, 
                                                 kCGImageAlphaNoneSkipFirst);

    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), 
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

-(void) findFaces:(UIImage*) inputImage
{
    std::vector<cv::Rect> faces;
    cv::Mat gray = [inputImage CVGrayscaleMat]; 
    cv::Point2f src_center(gray.cols/2.0f, gray.rows/2.0f);
    cv::Mat rot_mat = cv::getRotationMatrix2D(src_center, 180, 1.0);
    cv::Mat rotated;
    cv::warpAffine(gray, rotated, rot_mat, gray.size());
    
    _faceCascade.detectMultiScale(rotated, faces, 1.1, 2, kHaarOptions, cv::Size(60, 60));
    
    NSLog(@"Number of faces: %d", (int)faces.size());
    for(int i = 0; i < faces.size(); i++)
    {
        cv::Rect faceBox = faces[i];
        NSLog(@"\t%d %d - %d %d", faceBox.tl().x, faceBox.tl().y, faceBox.br().x, faceBox.br().y);
    }
}



#pragma mark - Save Video to mLibrary

- (void)saveMovieToCameraRoll
{
    [assetWriterInput markAsFinished];
    [assetWriter finishWriting];
    
    NSLog(@"writing \"%@\" to photos album", [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.m4v"]);
	
    UISaveVideoAtPathToSavedPhotosAlbum ( [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.m4v"] ,self, @selector(video:didFinishSavingWithError: contextInfo:), nil);
}

- (void) video: (NSString *) videoPath didFinishSavingWithError: (NSError *) error contextInfo: (void *) contextInfo {
    NSLog(@"Finished saving video with error: %@", error);
}




#pragma mark - Save processed frame (canny) to mLibrary

-(void) writeEdgeImage:(UIImage*) inputImage
{
    cv::Mat gray = [inputImage CVGrayscaleMat]; 
    cv::Point2f src_center(gray.cols/2.0f, gray.rows/2.0f);
    cv::Mat rot_mat = cv::getRotationMatrix2D(src_center, 180, 1.0);
    cv::Mat rotated;
    cv::warpAffine(gray, rotated, rot_mat, gray.size());
    cv::Mat edges;

    cv::Canny(rotated, edges, 120, 270);

    UIImage* edgeImage = [UIImage imageWithCVMat:edges];
    UIImageWriteToSavedPhotosAlbum(edgeImage, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error 
  contextInfo:(void *)contextInfo
{
    // Was there an error?
    if (error != NULL)
    {
        // Show error message...
        
    }
    else  // No errors
    {
        // Show message image successfully saved
    }
}


@end


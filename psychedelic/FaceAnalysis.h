//  Psychedelic
//  Created by Richard Stoner on 3/17/12.
//  Copyright (c) 2012, All rights reserved.
//
//  FaceAnalysis.h

@interface FaceAnalysis : NSObject
{
    
    BOOL started;
	CMTime frameDuration;
	CMTime nextPTS;
	AVAssetWriter *assetWriter;
	AVAssetWriterInput *assetWriterInput;
    AVAssetWriterInputPixelBufferAdaptor *assetAdaptor;    
	AVCaptureStillImageOutput *stillImageOutput;
    
	NSURL *outputURL;
    CGSize _size;
    cv::CascadeClassifier _faceCascade;
    cv::CascadeClassifier _eyeCascade;

}

+ (id)sharedInstance;

-(BOOL) configureCascade;
-(void) configureWriter;

-(void) trackHeadEye:(CVImageBufferRef)_imageBuffer;
-(void) trackHeadEyeSmall:(CVImageBufferRef)_imageBuffer;

-(void) saveMovieToCameraRoll;

@end

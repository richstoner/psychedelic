//  Psychedelic
//  Created by Richard Stoner on 3/17/12.
//  Copyright (c) 2012, All rights reserved.
//
//  CaptureViewController.h


/*!
 @class     CaptureViewController
 @author    Based on code by Benjamin Loulier, Modified by Rich Stoner
 @brief     ViewController responsible for preview layer + capturing 
 */

@interface CaptureViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate> {
	AVCaptureSession *_captureSession;
	UIImageView *_imageView;
	CALayer *_customLayer;
	AVCaptureVideoPreviewLayer *_prevLayer;
	AVCaptureMovieFileOutput *_movieFileOutput;
    BOOL * shouldSaveToLibrary;
    NSString* temporaryFileName;
}

// Properties

/*!
 @brief	The capture session takes the input from the camera and capture it
 */
@property (nonatomic, retain) AVCaptureSession *captureSession;

/*!
 @brief	The UIImageView we use to display the image generated from the imageBuffer
 */
@property (nonatomic, retain) UIImageView *imageView;

/*!
 @brief	The CALayer we use to display the CGImageRef generated from the imageBuffer
 */
@property (nonatomic, retain) CALayer *customLayer;

/*!
 @brief	The CALAyer customized by apple to display the video corresponding to a capture session
 */
@property (nonatomic, retain) AVCaptureVideoPreviewLayer *prevLayer;
@property (nonatomic, retain) NSString* temporaryFileName;



// Methods


/*!
 @brief	This method initializes the capture session to record to video 
 */
- (void)initCaptureForSave;

/*!
 @brief	Starts capturing video to temporary file
 */
- (void)startCapture;

/*!
 @brief	Stops capturing video
 */
- (void)stopCapture;

/*!
 @brief	This method returns the front facing camera if it is present on the device
 */
- (AVCaptureDevice *)frontFacingCameraIfAvailable;

/*!
 @brief The URL from the tempfile
 */
- (NSURL *) tempFileURL;

@end

@interface CaptureViewController ()

@property (nonatomic,retain) AVCaptureMovieFileOutput *movieFileOutput;

@end
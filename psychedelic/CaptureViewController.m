//  Psychedelic
//  Created by Richard Stoner on 3/17/12.
//  Copyright (c) 2012, All rights reserved.
//
//  CaptureViewController.m

#import "CaptureViewController.h"

@implementation CaptureViewController

@synthesize captureSession = _captureSession;
@synthesize imageView = _imageView;
@synthesize customLayer = _customLayer;
@synthesize prevLayer = _prevLayer;
@synthesize movieFileOutput = _movieFileOutput;
@synthesize temporaryFileName;

#pragma mark -
#pragma mark Initialization
- (id)init {
	self = [super init];
	if (self) {

		self.imageView = nil;
		self.prevLayer = nil;
		self.customLayer = nil;
        shouldSaveToLibrary = NO;
	}
	return self;
}

- (void)viewDidLoad {
	[self initCaptureForSave];
}


- (void)initCaptureForSave
{
    NSLog(@"Temp filename to be used: %@", [[self tempFileURL] absoluteString]);
    
	AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput
										  deviceInputWithDevice:[self frontFacingCameraIfAvailable]
										  error:nil];
	
	self.movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];	 

	self.captureSession = [[AVCaptureSession alloc] init];
	[self.captureSession beginConfiguration]; 
	
    if ([[self frontFacingCameraIfAvailable] supportsAVCaptureSessionPreset:AVCaptureSessionPresetHigh]) {
        
        [self.captureSession setSessionPreset:AVCaptureSessionPresetHigh];    
        
    }
    
	
	[self.captureSession addInput:captureInput];
	[self.captureSession addOutput:self.movieFileOutput];
	[self.captureSession commitConfiguration];	
	
	/* add the preview */
	self.prevLayer = [AVCaptureVideoPreviewLayer layerWithSession: self.captureSession];
	self.prevLayer.frame = CGRectMake(0, 0, 300, 200);
	self.prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.prevLayer.orientation = AVCaptureVideoOrientationLandscapeRight;
	[self.view.layer addSublayer: self.prevLayer];
	
	[self.captureSession startRunning];
}

- (void) startCapture
{
    [[self movieFileOutput] startRecordingToOutputFileURL:[self tempFileURL] recordingDelegate:self];	
}

- (void) stopCapture
{
	[[self movieFileOutput] stopRecording];
}

- (AVCaptureDevice *)frontFacingCameraIfAvailable
{
    //  look at all the video devices and get the first one that's on the front
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *captureDevice = nil;
    for (AVCaptureDevice *device in videoDevices)
    {
        if (device.position == AVCaptureDevicePositionFront)
        {
            captureDevice = device;
            break;
        }
    }
    //  couldn't find one on the front, so just get the default video device.
    if ( ! captureDevice)
    {
        captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
	
    return captureDevice;
}

- (NSURL *) tempFileURL
{
    NSString *outputPath = [[NSString alloc] initWithFormat:@"%@%@", NSTemporaryDirectory(), @"output.mov"];
    [self setTemporaryFileName:outputPath];
    NSURL *outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:outputPath]) {
        NSError *error;
        if ([fileManager removeItemAtPath:outputPath error:&error] == NO) {
        }
    }
    
    return outputURL;
}



#pragma mark -
#pragma mark Memory management

- (void)viewDidUnload {
	self.imageView = nil;
	self.customLayer = nil;
	self.prevLayer = nil;
}

- (void)dealloc {
}

#pragma mark -
#pragma mark Recording Callbacks 

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    
}

- (void)             captureOutput:(AVCaptureFileOutput *)captureOutput
didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
                   fromConnections:(NSArray *)connections
{

}

- (void)              captureOutput:(AVCaptureFileOutput *)captureOutput
didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
                    fromConnections:(NSArray *)connections
                              error:(NSError *)error
{
    if (shouldSaveToLibrary) {
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:outputFileURL]) {
            [library writeVideoAtPathToSavedPhotosAlbum:outputFileURL
                                        completionBlock:^(NSURL *assetURL, NSError *error){
                                            
                                        }];
        }        
    }
}


@end

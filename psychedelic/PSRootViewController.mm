//  Psychedelic
//  Created by Richard Stoner on 3/17/12.
//  Copyright (c) 2012, All rights reserved.
//
//  PSRootViewController.mm

#import "PSRootViewController.h"
#import "UIImage+OpenCV.h"
#import "QuartzCore/QuartzCore.h"
#import "FaceAnalysis.h"

#pragma mark - Probably unnecessary legacy code

static const NSString *AVCaptureStillImageIsCapturingStillImageContext = @"AVCaptureStillImageIsCapturingStillImageContext";
static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};

static void ReleaseCVPixelBuffer(void *pixel, const void *data, size_t size);
static void ReleaseCVPixelBuffer(void *pixel, const void *data, size_t size) 
{	
	CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)pixel;
	CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
	CVPixelBufferRelease( pixelBuffer );
}

// create a CGImage with provided pixel buffer, pixel buffer must be uncompressed kCVPixelFormatType_32ARGB or kCVPixelFormatType_32BGRA
static OSStatus CreateCGImageFromCVPixelBuffer(CVPixelBufferRef pixelBuffer, CGImageRef *imageOut);
static OSStatus CreateCGImageFromCVPixelBuffer(CVPixelBufferRef pixelBuffer, CGImageRef *imageOut) 
{	
	OSStatus err = noErr;
	OSType sourcePixelFormat;
	size_t width, height, sourceRowBytes;
	void *sourceBaseAddr = NULL;
	CGBitmapInfo bitmapInfo;
	CGColorSpaceRef colorspace = NULL;
	CGDataProviderRef provider = NULL;
	CGImageRef image = NULL;
	
	sourcePixelFormat = CVPixelBufferGetPixelFormatType( pixelBuffer );
	if ( kCVPixelFormatType_32ARGB == sourcePixelFormat )
		bitmapInfo = kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipFirst;
	else if ( kCVPixelFormatType_32BGRA == sourcePixelFormat )
		bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst;
	else
		return -95014; // only uncompressed pixel formats
	
	sourceRowBytes = CVPixelBufferGetBytesPerRow( pixelBuffer );
	width = CVPixelBufferGetWidth( pixelBuffer );
	height = CVPixelBufferGetHeight( pixelBuffer );
	
	CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
	sourceBaseAddr = CVPixelBufferGetBaseAddress( pixelBuffer );
	
	colorspace = CGColorSpaceCreateDeviceRGB();
    
	CVPixelBufferRetain( pixelBuffer );
	provider = CGDataProviderCreateWithData( (void *)pixelBuffer, sourceBaseAddr, sourceRowBytes * height, ReleaseCVPixelBuffer);
	image = CGImageCreate(width, height, 8, 32, sourceRowBytes, colorspace, bitmapInfo, provider, NULL, true, kCGRenderingIntentDefault);
	
bail:
	if ( err && image ) {
		CGImageRelease( image );
		image = NULL;
	}
	if ( provider ) CGDataProviderRelease( provider );
	if ( colorspace ) CGColorSpaceRelease( colorspace );
	*imageOut = image;
	return err;
}

// utility used by newSquareOverlayedImageForFeatures for 
static CGContextRef CreateCGBitmapContextForSize(CGSize size);
static CGContextRef CreateCGBitmapContextForSize(CGSize size)
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    int             bitmapBytesPerRow;
	
    bitmapBytesPerRow = (size.width * 4);
	
    colorSpace = CGColorSpaceCreateDeviceRGB();
    context = CGBitmapContextCreate (NULL,
									 size.width,
									 size.height,
									 8,      // bits per component
									 bitmapBytesPerRow,
									 colorSpace,
									 kCGImageAlphaPremultipliedLast);
	CGContextSetAllowsAntialiasing(context, NO);
    CGColorSpaceRelease( colorSpace );
    return context;
}

#pragma mark -

@interface PSRootViewController (internal) {
@private
}
@end

@implementation PSRootViewController

@synthesize recorder = _recorder;
@synthesize currentStimuliURL = _currentStimuliURL;
@synthesize moviePlayer = _moviePlayer;

// utility routing used during image capture to set up capture orientation
- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation
{
	AVCaptureVideoOrientation result = deviceOrientation;
	if ( deviceOrientation == UIDeviceOrientationLandscapeLeft )
		result = AVCaptureVideoOrientationLandscapeRight;
	else if ( deviceOrientation == UIDeviceOrientationLandscapeRight )
		result = AVCaptureVideoOrientationLandscapeLeft;
	return result;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
// logic needed to run in simulator
#if TARGET_IPHONE_SIMULATOR
    #warning "Video recording disabled in simulator."
    NSLog(@"Running in simulator");
#else
    NSLog(@"Running on device.");
    
    _recorder = [[CaptureViewController alloc] init];
    [_recorder initCaptureForSave];    
    
#endif
    
    [self setCurrentStimuliURL:[[NSBundle mainBundle] URLForResource:@"yoga" withExtension:@"m4v"]];
    
    assets = [[NSMutableArray alloc]init];
    mLibrary =[[ALAssetsLibrary alloc]init];
    
    _moviePlayer = [[MPMoviePlayerController alloc] init];
    _moviePlayer.controlStyle = MPMovieControlStyleEmbedded;
    _moviePlayer.view.frame = CGRectMake(0.,0.,1024.,500.);
    _moviePlayer.view.center = CGPointMake(512,270);
    _moviePlayer.view.layer.borderColor = [UIColor lightGrayColor].CGColor;
    _moviePlayer.view.layer.borderWidth = 2.0f;
    [_moviePlayer.view setBackgroundColor:[UIColor blackColor]];
                    
    [_moviePlayer setShouldAutoplay:NO];
    [_moviePlayer prepareToPlay];
    
    _currentStimuliPath = [[UILabel alloc] initWithFrame:CGRectMake(20, 530, 800, 40)];
    _currentStimuliPath.text = _currentStimuliURL.absoluteString;
    _currentStimuliPath.textAlignment = UITextAlignmentLeft;
    [_currentStimuliPath setFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:14]];
    _currentStimuliPath.textColor = [UIColor whiteColor];
    _currentStimuliPath.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_currentStimuliPath];
    
    _currentCapturePath = [[UILabel alloc] initWithFrame:CGRectMake(20, 560, 800, 40)];
    [_currentCapturePath setText:_recorder.temporaryFileName];
    _currentCapturePath.textAlignment = UITextAlignmentLeft;
    [_currentCapturePath setFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:14]];
    _currentCapturePath.textColor = [UIColor whiteColor];
    _currentCapturePath.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_currentCapturePath];
    
    _currentProcessPath = [[UILabel alloc] initWithFrame:CGRectMake(20, 590, 800, 40)];
    _currentProcessPath.text = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.m4v"];
    _currentProcessPath.textAlignment = UITextAlignmentLeft;
    [_currentProcessPath setFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:14]];
    _currentProcessPath.textColor = [UIColor whiteColor];
    _currentProcessPath.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_currentProcessPath];
    
    _captureDuration = [[UISlider alloc] initWithFrame:CGRectMake(20, 630, 200, 30)];
    [_captureDuration setMinimumValue:2];
    [_captureDuration setMaximumValue:120];
    [_captureDuration setThumbTintColor:[UIColor blackColor]];
    [_captureDuration setValue:10];
    [_captureDuration addTarget:self action:@selector(updateSliderLabel:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_captureDuration];
    
    _sliderLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 660, 200, 30)];
    _sliderLabel.text = @"10.00 seconds";
    [_sliderLabel setFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:14]];
    [_sliderLabel setTextColor:[UIColor whiteColor]];
    [_sliderLabel setBackgroundColor:[UIColor clearColor]];
    [self.view addSubview:_sliderLabel];
    
    _progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 690, 200, 30)];
    _progressLabel.text = @"---";
    [_progressLabel setFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:14]];
    [_progressLabel setTextColor:[UIColor whiteColor]];
    [_progressLabel setBackgroundColor:[UIColor clearColor]];
    [self.view addSubview:_progressLabel];

    
    
    
    [self.view addSubview:_moviePlayer.view];
    [_recorder.view setFrame:CGRectMake(700,530,300,200)];
    [_recorder.view.layer setBorderWidth:1.0];
    [_recorder.view.layer setBorderColor:[UIColor blackColor].CGColor];
    
    
    
    [self.view addSubview:_recorder.view];
    [self configureAndAddToolbar];        
    
    FaceAnalysis* sharedSingleton = [FaceAnalysis sharedInstance];
    [sharedSingleton configureCascade];
    [sharedSingleton configureWriter];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

#pragma mark - Create Toolbar 

-(void)configureAndAddToolbar
{
    lastVideoThumbnail = [[UIImageView alloc] initWithFrame:CGRectMake(2,2,36,36)];
    [lastVideoThumbnail.layer setBorderColor:[UIColor whiteColor].CGColor];
    [lastVideoThumbnail.layer setBorderWidth:1.0f];
    [lastVideoThumbnail setBackgroundColor:[UIColor redColor]];
    
    UIToolbar* topToolBar =[[UIToolbar alloc] initWithFrame:CGRectMake(0, 1024-60, 768, 40)];
    [topToolBar setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin];
    
    CGSize ttbsize = [topToolBar frame].size;
    UIView* ttbfake = [[UIView alloc] initWithFrame:CGRectMake(0,0,ttbsize.width, ttbsize.height)];
    [ttbfake setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"px_by_Gre3g.png"]]];
    [ttbfake setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [topToolBar insertSubview:ttbfake atIndex:1];
    
    UILabel* ttbTitle = [[UILabel alloc] initWithFrame:CGRectMake(20, 0, 100, 40)];
    ttbTitle.text = @"Psychedelic";
    ttbTitle.textAlignment = UITextAlignmentRight;
    [ttbTitle setFont:[UIFont fontWithName:@"HelveticaNeue-Ultralight" size:18]];
    ttbTitle.textColor = [UIColor whiteColor];
    ttbTitle.textAlignment = UITextAlignmentLeft;
    ttbTitle.backgroundColor = [UIColor clearColor];

    startExperiment= [[UIBarButtonItem alloc] initWithTitle:@"Start Experiment" style:UIBarButtonItemStyleDone target:self action:@selector(startExperiment:) ];
    
    UIBarButtonItem* action1 = [[UIBarButtonItem alloc] initWithTitle:@"Playback" style:UIBarButtonItemStyleBordered target:self action:@selector(playbackCapturedVideo:)];
    [action1 setTintColor:[UIColor blackColor]];
    
    UIBarButtonItem* action2 = [[UIBarButtonItem alloc] initWithTitle:@"Analyze" style:UIBarButtonItemStyleBordered target:self action:@selector(analyzeTempVideo:)];
    [action2 setTintColor:[UIColor blackColor]];
    
    UIBarButtonItem* action3 = [[UIBarButtonItem alloc] initWithTitle:@"Review" style:UIBarButtonItemStyleBordered target:self action:@selector(reviewVideo:)];    
    [action3 setTintColor:[UIColor blackColor]];
    
    UIBarButtonItem* saveProcessed = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStyleBordered target:self action:@selector(saveProcessedVideo:)];    
    [saveProcessed setTintColor:[UIColor blackColor]];    
    
    analyzeExperiment= [[UIBarButtonItem alloc] initWithTitle:@"Analyze" style:UIBarButtonItemStyleBordered target:self action:@selector(analyzeExperiment:) ];    
    analyzeExperiment.tintColor = [UIColor redColor];
    progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];    

    UIBarButtonItem * fixedItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    [fixedItem setWidth:10.0f];    
    UIBarButtonItem *ttbFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *pvItem = [[UIBarButtonItem alloc] initWithCustomView:progressView];
    UIBarButtonItem* thumbItem = [[UIBarButtonItem alloc] initWithCustomView:lastVideoThumbnail];
    
    
    NSArray* topItems = [NSArray arrayWithObjects: startExperiment, action1, action2, action3, saveProcessed, ttbFlex, thumbItem,  fixedItem, pvItem,nil];
    [topToolBar setItems:topItems animated:NO];
    [self.view addSubview:topToolBar];

    [self enumerateAssets];
        
}

-(void) updateSliderLabel:(id)sender
{
    _sliderLabel.text = [NSString stringWithFormat:@"%.2f seconds", _captureDuration.value];
}


-(void) startExperiment:(id)sender
{
    [self.moviePlayer setContentURL: [[NSBundle mainBundle]
                                      URLForResource:@"bigBuckBunny" withExtension:@"m4v"]];
    [self.moviePlayer play];
    [_recorder startCapture];
    
    [self performSelector:@selector(stopExperiment:) withObject:nil afterDelay:_captureDuration.value];
}

// this happens 10 seconds later by default

-(void) stopExperiment:(id)sender
{
    [_recorder stopCapture];
    
    [self.moviePlayer stop];
    
    self.moviePlayer.initialPlaybackTime = -1;
    
    [self performSelector:@selector(enumerateAssets) withObject:nil afterDelay:10.0];   
}

// wait 10 more seconds to refresh ... but should not update as we're not capturing to mLibrary.

- (void)enumerateAssets
{
    [assets removeAllObjects];
    
    void (^assetEnumerator)(ALAsset *, NSUInteger, BOOL *) = ^(ALAsset *result, NSUInteger index, BOOL *stop)
    {
        if([[result valueForProperty:ALAssetPropertyType] isEqualToString:ALAssetTypeVideo])
        {
            [assets addObject:result];
        }
    };
    
    void (^assetGroupEnumerator)(ALAssetsGroup *, BOOL *) = ^(ALAssetsGroup *group, BOOL *stop)
    {
        if(group != nil)
        {
            [group enumerateAssetsUsingBlock:assetEnumerator];
        }
        else
        {
            [self performSelectorInBackground:@selector(updateThumbnail:) withObject:nil];

        }
    };
    
    void (^assetFailureBlock)(NSError *) = ^(NSError *error)
    {
        
    };
    
    [mLibrary enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:assetGroupEnumerator failureBlock:assetFailureBlock];
    
}

- (void)updateThumbnail:(id)sender
{
    NSLog(@"Update thumbnail, found video assets: %d\n", [assets count]);
    ALAsset* lastAsset = [assets lastObject];    
    [lastVideoThumbnail setImage:[UIImage imageWithCGImage:lastAsset.thumbnail]];
}



- (void) playbackCapturedVideo:(id)sender
{
    [self.moviePlayer setContentURL:[NSURL fileURLWithPath:_recorder.temporaryFileName]];    
    [self.moviePlayer prepareToPlay];
}

- (void) analyzeTempVideo:(id)sender
{
    NSURL *newURL = [NSURL fileURLWithPath:_recorder.temporaryFileName];
    [self readMovie:newURL];
}

- (void) reviewVideo:(id)sender
{
    [self.moviePlayer setContentURL:[NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.m4v"]]];
    [self.moviePlayer prepareToPlay];    
}

- (void) saveProcessedVideo:(id)sender
{
    NSLog(@"writing \"%@\" to photos album", [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.m4v"]);	
    UISaveVideoAtPathToSavedPhotosAlbum ( [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.m4v"] ,self, @selector(video:didFinishSavingWithError: contextInfo:), nil);
    
    [self performSelector:@selector(enumerateAssets) withObject:nil afterDelay:10.0];   

}

- (void) video: (NSString *) videoPath didFinishSavingWithError: (NSError *) error contextInfo: (void *) contextInfo {

}


-(void) analyzeExperiment:(id)sender
{
    ALAsset* lastCapture = [assets lastObject];
    
    NSDictionary*	tempDictionary = [lastCapture valueForProperty:ALAssetPropertyURLs];
    NSURL *newURL = [tempDictionary objectForKey:@"com.apple.quicktime-movie"];

    NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];		
    AVURLAsset* tempAsset = [AVURLAsset URLAssetWithURL:newURL options:options];
    
    printf("%f \n", tempAsset.preferredRate);
    
    if (tempAsset.providesPreciseDurationAndTiming) {
        printf("This asset has precise timing enabled.\n");
    }
    else {
        printf("This asset DOES NOT have precise timing enabled.\n");
    }
        
    [self readMovie:newURL];
}

- (void) readMovie:(NSURL *)url
{
	AVURLAsset * asset = [AVURLAsset URLAssetWithURL:url options:nil];
	[asset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObject:@"tracks"] completionHandler:
     ^{
         dispatch_async(dispatch_get_main_queue(),
                        ^{
                            AVAssetTrack * videoTrack = nil;
                            NSArray * tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
                            if ([tracks count] == 1)
                            {
                                videoTrack = [tracks objectAtIndex:0];
                                

                                NSError * error = nil;
                                
                                // mMovieReader is a member variable
                                mMovieReader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
                                if (error)
                                {
                                    NSLog(@"%@", error.localizedDescription);
                                }
                                
                                NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
                                NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
                                NSDictionary* videoSettings = 
                                [NSDictionary dictionaryWithObject:value forKey:key]; 
                                
                                [mMovieReader addOutput:[AVAssetReaderTrackOutput 
                                                         assetReaderTrackOutputWithTrack:videoTrack 
                                                         outputSettings:videoSettings]];
                                [mMovieReader startReading];
  
                                
                                
                                [self performSelector:@selector(readNextMovieFrame) withObject:nil afterDelay:0.5];
//                                [self performSelectorInBackground:@selector(readNextMovieFrame) withObject:nil];
                            }
                        });
     }];
}

- (void) updateProgressView:(id) sender
{
    NSNumber* progress = (NSNumber*)sender;
    _progressLabel.text = [NSString stringWithFormat:@"Processing frame #%d", [progress intValue]];
    [progressView setProgress:(float)[progress intValue]/(_captureDuration.value * 30)];
}


- (void) readNextMovieFrame
{
    int i = 0;
    
    FaceAnalysis* analysisEngine = [FaceAnalysis sharedInstance];
    
    while (mMovieReader.status == AVAssetReaderStatusReading)
    {

        AVAssetReaderTrackOutput * output = [mMovieReader.outputs objectAtIndex:0];
        CMSampleBufferRef sampleBuffer = [output copyNextSampleBuffer];
        if (sampleBuffer)
        {
            NSNumber* progressVal = [NSNumber numberWithInt:i];
            
            [self performSelectorInBackground:@selector(updateProgressView:) withObject:progressVal];
            
            i++;            
            CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer); 
            
            // Lock the image buffer
            CVPixelBufferLockBaseAddress(imageBuffer,0); 
            
            // Get information of the image
//            uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
//            size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
//            size_t width = CVPixelBufferGetWidth(imageBuffer);
//            size_t height = CVPixelBufferGetHeight(imageBuffer); 
            
//            [analysisEngine writeFrame:imageBuffer];
//            [analysisEngine trackHeadEyeSmall:imageBuffer];

            [analysisEngine trackHeadEye:imageBuffer];

            CVPixelBufferUnlockBaseAddress(imageBuffer,0);
            CMSampleBufferInvalidate(sampleBuffer);            
            CFRelease(sampleBuffer);
        }
    }
    
    [analysisEngine saveMovieToCameraRoll];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Analysis complete" message:@"" delegate:nil cancelButtonTitle:@""otherButtonTitles:nil];
    [alert show];
}

//locking to landscape view & viewport dimensions (1024x768)
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{    
    return (interfaceOrientation == UIInterfaceOrientationLandscapeRight);
}

@end

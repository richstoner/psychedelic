//  Psychedelic
//  Created by Richard Stoner on 3/17/12.
//  Copyright (c) 2012, All rights reserved.
//
//  ViewController.h

#import "CaptureViewController.h"
#import "mediaplayer/MPMoviePlayerController.h"


@interface PSRootViewController : UIViewController
{
    // VC reponsible for preview/capture/saving video
    CaptureViewController*      _recorder;
    
    // VC responsible for playing back video
    MPMoviePlayerController*    _moviePlayer;
    
    // Controls and UI
    UIBarButtonItem*            startExperiment;
    UIBarButtonItem*            analyzeExperiment;    
    UIProgressView*             progressView;    
    UIImageView*                lastVideoThumbnail;

    // shows file location
    UILabel*                    _currentStimuliPath;
    NSURL*                      _currentStimuliURL;
    
    // very hackish UI 
    UILabel*                    _currentCapturePath;
    UILabel*                    _currentProcessPath;
    UISlider*                   _captureDuration;
    UILabel*                    _sliderLabel;
    UILabel*                    _progressLabel;    
    
    // mLibrary vars - not really needed in class def
    ALAssetsLibrary*            mLibrary;
    AVAssetImageGenerator*      mImageGenerator;
    NSMutableArray*             assets;
    AVAssetReader*              mMovieReader;

}

// properties
@property(nonatomic, retain) CaptureViewController* recorder;
@property(nonatomic, retain) MPMoviePlayerController* moviePlayer;
@property(nonatomic, retain) NSURL* currentStimuliURL;

// methods
- (void) configureAndAddToolbar;
- (void) enumerateAssets;
- (void) readMovie:(NSURL *)url;

@end

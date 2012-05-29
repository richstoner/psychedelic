//  Psychedelic
//  Created by Richard Stoner on 3/17/12.
//  Copyright (c) 2012, All rights reserved.
//
//  AppDelegate.h


/* 
 
 How the application is setup:
 
 AppDelegate -> close to OS, put shared DBs here if needed
 
 PSRootViewController -> application's root view controller, 

 CaptureViewController -> VC that handles initializing capture hardware (front facing if possible), creates preview, and manages recording
 
 FaceAnalysis -> Singleton, contains headtracking and eyetracking algorithms, manages analysis plus encoding of analyzed frames to video

 The PSRootVC organizes other VCs and passes rotations/etc
    put animations / scenes / messaging between views here
    handles access to & from ipad video library
 
    contains at least 1 of the following:
        CaptureViewController -> VC that handles initializing capture hardware (front facing if possible), creates preview, and manages recording
        MoviePlayerController -> VC that controls video playback 
        ... could add additional VCs here... see neuroresponse / openframeworks / glkit 
 
    Most logic occurs in the Root VC
 
    Flow
 
        1. Application loads, user selects experiment length
        2. Tap start experiment -> video capture & playback start
            
            The capture device (CaptureViewController) takes frames and writes them to file output
            If you wanted to perform online video analysis, use the callbacks
 
        3. After experiment reaches endpoint, video capture & movie playback stop
        4. User can preview recorded video 
        5. User starts analysis
                
            Analysis class starts to read the most recently captured file from library frame by frame
            Offline algorithms run on each frame, modify base image, and resave as new video
 
            Currently am not able to run multiframe analyses but shouldn't be difficult to add via some persistence in singleton
            (keep it serial, parallel + clever = no)
    
 */

@class PSRootViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) PSRootViewController *viewController;

@end

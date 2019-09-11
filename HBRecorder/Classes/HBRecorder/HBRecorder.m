//
//  HBRecorder.m
//  HBRecorder
//
//  Created by HilalB on 11/07/2016.
//  Copyright (c) 2016 HilalB. All rights reserved.
//

//#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "SCTouchDetector.h"
#import "HBRecorder.h"
#import "HBVideoPlayerViewController.h"
#import "SCImageDisplayerViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "SCSessionListViewController.h"
#import "SCRecordSessionManager.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "CircleProgressView.h"


#define kVideoPreset AVCaptureSessionPresetHigh

////////////////////////////////////////////////////////////
// PRIVATE DEFINITION
/////////////////////

@interface HBRecorder () {
    SCRecorder *_recorder;
    UIImage *_photo;
    SCRecordSession *_recordSession;
    UIImageView *_ghostImageView;
    BOOL hasOrientaionLocked;
}

@property (strong, nonatomic) SCRecorderToolsView *focusView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *heightButtonConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *widthButtonConstraint;
@property (weak, nonatomic) IBOutlet CircleProgressView *circleProgressView;

@end

////////////////////////////////////////////////////////////
// IMPLEMENTATION
/////////////////////

@implementation HBRecorder

#pragma mark - UIViewController 

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0

- (UIStatusBarStyle) preferredStatusBarStyle {
	return UIStatusBarStyleLightContent;
}

#endif

#pragma mark - Left cycle

- (void)dealloc {
    _recorder.previewView = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.navigationController setNavigationBarHidden:YES];
    self.capturePhotoButton.alpha = 0.0;
    
    _ghostImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    _ghostImageView.contentMode = UIViewContentModeScaleAspectFill;
    _ghostImageView.alpha = 0.2;
    _ghostImageView.userInteractionEnabled = NO;
    _ghostImageView.hidden = YES;
    
    [self.view insertSubview:_ghostImageView aboveSubview:self.previewView];

    _recorder = [SCRecorder recorder];
    _recorder.captureSessionPreset = [SCRecorderTools bestCaptureSessionPresetCompatibleWithAllDevices];
    
    if (_maxRecordDuration) {
        _recorder.maxRecordDuration = CMTimeMake(_maxRecordDuration, 1);
    }
    
//    _recorder.fastRecordMethodEnabled = YES;
    
    _recorder.delegate = self;
    _recorder.autoSetVideoOrientation = YES; //YES causes bad orientation for video from camera roll
    
    UIView *previewView = self.previewView;
    _recorder.previewView = previewView;
    
    [self.retakeButton addTarget:self action:@selector(handleRetakeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.stopButton addTarget:self action:@selector(handleStopButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
	[self.reverseCamera addTarget:self action:@selector(handleReverseCameraTapped:) forControlEvents:UIControlEventTouchUpInside];
    
//    [self.recordView addGestureRecognizer:[[SCTouchDetector alloc] initWithTarget:self action:@selector(handleTouchDetected:)]];
    self.loadingView.hidden = YES;
    
    self.focusView = [[SCRecorderToolsView alloc] initWithFrame:previewView.bounds];
    self.focusView.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    self.focusView.recorder = _recorder;
    [previewView addSubview:self.focusView];
    
    self.focusView.outsideFocusTargetImage = [self imageNamed:@"focus"];

    _recorder.initializeSessionLazily = NO;
    
    NSError *error;
    if (![_recorder prepare:&error]) {
        NSLog(@"Prepare error: %@", error.localizedDescription);
    }
    
    if (_recorder.deviceHasFlash) {
        _flashModeButton.hidden = NO;
    } else {
        _flashModeButton.hidden = YES;
    }
    

    // Setup images for the Shutter Button
    UIImage *image;
    image = [self imageNamed:@"ShutterButtonStart"];
    self.recStartImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.recBtn setImage:self.recStartImage
                 forState:UIControlStateNormal];
    
    image = [self imageNamed:@"ShutterButtonStop"];
    self.recStopImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    [self.recBtn setTintColor:[UIColor colorWithRed:239/255.
                                              green:31/255.
                                               blue:147/255.
                                              alpha:1.0]];
    self.outerImage1 = [self imageNamed:@"outer1"];
    self.outerImage2 = [self imageNamed:@"outer2"];
    self.outerImageView.image = self.outerImage1;
    
}

-(UIImage*)imageNamed:(NSString*)imgName {
    
    NSBundle *bundle = [NSBundle bundleForClass:HBRecorder.class];
    
    return [UIImage imageNamed:imgName inBundle:bundle compatibleWithTraitCollection:nil];

}

- (void)recorder:(SCRecorder *)recorder didSkipVideoSampleBufferInSession:(SCRecordSession *)recordSession {
    NSLog(@"Skipped video buffer");
}

- (void)recorder:(SCRecorder *)recorder didReconfigureAudioInput:(NSError *)audioInputError {
    NSLog(@"Reconfigured audio input: %@", audioInputError);
}

- (void)recorder:(SCRecorder *)recorder didReconfigureVideoInput:(NSError *)videoInputError {
    NSLog(@"Reconfigured video input: %@", videoInputError);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self prepareSession];
    
	self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    [_recorder previewViewFrameChanged];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    SCRecordSession *recordSession = _recorder.session;

                     if (recordSession != nil) {
                         _recorder.session = nil;
                                                              
                         if ([[SCRecordSessionManager sharedInstance] isSaved:recordSession]) {
                             [recordSession endSegmentWithInfo:nil completionHandler:nil];
                         } else {
                             [recordSession cancelSession:nil];
                         }
                             [self prepareSession];
                     }
    [_recorder startRunning];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [_recorder stopRunning];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    self.navigationController.navigationBarHidden = YES;
}

#pragma mark - Handle

- (void)showAlertViewWithTitle:(NSString*)title message:(NSString*) message {
    UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [alertView show];
}

- (void)showVideo {
    [self performSegueWithIdentifier:@"Video" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController isKindOfClass:[HBVideoPlayerViewController class]]) {
        HBVideoPlayerViewController *videoPlayer = segue.destinationViewController;
        videoPlayer.recordSession = _recordSession;
        videoPlayer.parent = self;
    } else if ([segue.destinationViewController isKindOfClass:[SCImageDisplayerViewController class]]) {
        SCImageDisplayerViewController *imageDisplayer = segue.destinationViewController;
        imageDisplayer.photo = _photo;
        _photo = nil;
    } else if ([segue.destinationViewController isKindOfClass:[SCSessionListViewController class]]) {
        SCSessionListViewController *sessionListVC = segue.destinationViewController;
        
        sessionListVC.recorder = _recorder;
    }
}

- (void)showPhoto:(UIImage *)photo {
    _photo = photo;
    [self performSegueWithIdentifier:@"Photo" sender:self];
}

- (void) handleReverseCameraTapped:(id)sender {
	[_recorder switchCaptureDevices];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSURL *url = info[UIImagePickerControllerMediaURL];
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    SCRecordSessionSegment *segment = [SCRecordSessionSegment segmentWithURL:url info:nil];
    
    [_recorder.session addSegment:segment];
    _recordSession = [SCRecordSession recordSession];
    [_recordSession addSegment:segment];
    
    [self showVideo];
}
- (void) handleStopButtonTapped:(id)sender {
//    [_recorder pause:^{
//        self.heightButtonConstraint.constant = 70.f;
//        self.widthButtonConstraint.constant = 70.f;
//        [self saveAndShowSession:_recorder.session];
//    }];
    [_recorder switchCaptureDevices];
}

- (void)saveAndShowSession:(SCRecordSession *)recordSession {
    [[SCRecordSessionManager sharedInstance] saveRecordSession:recordSession];
        
    _recordSession = recordSession;
    [self showVideo];
}

- (void)handleRetakeButtonTapped:(id)sender {
    SCRecordSession *recordSession = _recorder.session;
    
    if (recordSession != nil) {
        _recorder.session = nil;
        
        // If the recordSession was saved, we don't want to completely destroy it
        if ([[SCRecordSessionManager sharedInstance] isSaved:recordSession]) {
            [recordSession endSegmentWithInfo:nil completionHandler:nil];
        } else {
            [recordSession cancelSession:nil];
        }
    }
    
	[self prepareSession];
}

- (IBAction)switchCameraMode:(id)sender {
    if ([_recorder.captureSessionPreset isEqualToString:AVCaptureSessionPresetPhoto]) {
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.capturePhotoButton.alpha = 0.0;
            self.recordView.alpha = 1.0;
            self.retakeButton.alpha = 1.0;
            self.stopButton.alpha = 1.0;
        } completion:^(BOOL finished) {
			_recorder.captureSessionPreset = kVideoPreset;
            [self.switchCameraModeButton setTitle:@"Switch Photo" forState:UIControlStateNormal];
            [self.flashModeButton setTitle:@"Flash : Off" forState:UIControlStateNormal];
            _recorder.flashMode = SCFlashModeOff;
        }];
    } else {
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.recordView.alpha = 0.0;
            self.retakeButton.alpha = 0.0;
            self.stopButton.alpha = 0.0;
            self.capturePhotoButton.alpha = 1.0;
        } completion:^(BOOL finished) {
			_recorder.captureSessionPreset = AVCaptureSessionPresetPhoto;
            [self.switchCameraModeButton setTitle:@"Switch Video" forState:UIControlStateNormal];
            [self.flashModeButton setTitle:@"Flash : Auto" forState:UIControlStateNormal];
            _recorder.flashMode = SCFlashModeAuto;
        }];
    }
}

- (IBAction)switchFlash:(id)sender {
    NSString *flashModeString = nil;
    if ([_recorder.captureSessionPreset isEqualToString:AVCaptureSessionPresetPhoto]) {
        switch (_recorder.flashMode) {
            case SCFlashModeAuto:
                flashModeString = @"Flash : Off";
                _recorder.flashMode = SCFlashModeOff;
                break;
            case SCFlashModeOff:
                flashModeString = @"Flash : On";
                _recorder.flashMode = SCFlashModeOn;
                break;
            case SCFlashModeOn:
                flashModeString = @"Flash : Light";
                _recorder.flashMode = SCFlashModeLight;
                break;
            case SCFlashModeLight:
                flashModeString = @"Flash : Auto";
                _recorder.flashMode = SCFlashModeAuto;
                break;
            default:
                break;
        }
    } else {
        switch (_recorder.flashMode) {
            case SCFlashModeOff:
                flashModeString = @"Flash : On";
                _recorder.flashMode = SCFlashModeLight;
                break;
            case SCFlashModeLight:
                flashModeString = @"Flash : Off";
                _recorder.flashMode = SCFlashModeOff;
                break;
            default:
                break;
        }
    }
    
//    [self.flashModeButton setTitle:flashModeString forState:UIControlStateNormal];
    
    
}

- (void)prepareSession {
    if (_recorder.session == nil) {
        
        SCRecordSession *session = [SCRecordSession recordSession];
        session.fileType = AVFileTypeQuickTimeMovie;
        
        _recorder.session = session;
    }
    
    [self updateTimeRecordedLabel];
    [self updateGhostImage];
}

- (void)recorder:(SCRecorder *)recorder didCompleteSession:(SCRecordSession *)recordSession {
    NSLog(@"didCompleteSession:");
    [self saveAndShowSession:recordSession];
}

- (void)recorder:(SCRecorder *)recorder didInitializeAudioInSession:(SCRecordSession *)recordSession error:(NSError *)error {
    if (error == nil) {
        NSLog(@"Initialized audio in record session");
    } else {
        NSLog(@"Failed to initialize audio in record session: %@", error.localizedDescription);
    }
}

- (void)recorder:(SCRecorder *)recorder didInitializeVideoInSession:(SCRecordSession *)recordSession error:(NSError *)error {
    if (error == nil) {
        NSLog(@"Initialized video in record session");
    } else {
        NSLog(@"Failed to initialize video in record session: %@", error.localizedDescription);
    }
}

- (void)recorder:(SCRecorder *)recorder didBeginSegmentInSession:(SCRecordSession *)recordSession error:(NSError *)error {
    NSLog(@"Began record segment: %@", error);
}

- (void)recorder:(SCRecorder *)recorder didCompleteSegment:(SCRecordSessionSegment *)segment inSession:(SCRecordSession *)recordSession error:(NSError *)error {
    NSLog(@"Completed record segment at %@: %@ (frameRate: %f)", segment.url, error, segment.frameRate);
    [self updateGhostImage];
}

- (void)updateTimeRecordedLabel {
    CMTime currentTime = kCMTimeZero;
    
    if (_recorder.session != nil) {
        currentTime = _recorder.session.duration;
    }
    
    self.timeRecordedLabel.text = [NSString stringWithFormat:@"%.2f sec", CMTimeGetSeconds(currentTime)];
    [self.circleProgressView setElapsedTime: CMTimeGetSeconds(currentTime)];
    self.circleProgressView.tintColor = [UIColor colorWithRed:239/255.
                    green:31/255.
                     blue:147/255. alpha:1.0];
}

- (void)recorder:(SCRecorder *)recorder didAppendVideoSampleBufferInSession:(SCRecordSession *)recordSession {
    [self updateTimeRecordedLabel];
    [self checkMaxSegmentDuration:recorder];
    
    
}

-(void)checkMaxSegmentDuration:(SCRecorder *)recorder {
    if(_maxSegmentDuration) {
        CMTime suggestedMaxSegmentDuration = CMTimeMake(_maxSegmentDuration, 1);
        if (CMTIME_IS_VALID(suggestedMaxSegmentDuration)) {
            if (CMTIME_COMPARE_INLINE(recorder.session.currentSegmentDuration, >=, suggestedMaxSegmentDuration)) {
                            [_recorder pause:^{
                                self.heightButtonConstraint.constant = 70.f;
                                self.widthButtonConstraint.constant = 70.f;
                    [self saveAndShowSession:_recorder.session];
                }];
                [self.recBtn setImage:self.recStartImage forState:UIControlStateNormal];
            }
        }
    }
}


- (void)handleTouchDetected:(SCTouchDetector*)touchDetector {
    if (touchDetector.state == UIGestureRecognizerStateBegan) {
        _ghostImageView.hidden = YES;
        [_recorder record];
        self.heightButtonConstraint.constant = 120.f;
        self.widthButtonConstraint.constant = 120.f;
    } else if (touchDetector.state == UIGestureRecognizerStateEnded) {
                    [_recorder pause:^{
                        self.heightButtonConstraint.constant = 70.f;
                        self.widthButtonConstraint.constant = 70.f;
            [self saveAndShowSession:_recorder.session];
        }];
    }
}

- (IBAction)capturePhoto:(id)sender {
    [_recorder capturePhoto:^(NSError *error, UIImage *image) {
        if (image != nil) {
            [self showPhoto:image];
        } else {
            [self showAlertViewWithTitle:@"Failed to capture photo" message:error.localizedDescription];
        }
    }];
}

- (void)updateGhostImage {
    UIImage *image = nil;
    
    if (_ghostModeButton.selected) {
        if (_recorder.session.segments.count > 0) {
            SCRecordSessionSegment *segment = [_recorder.session.segments lastObject];
            image = segment.lastImage;
        }
    }

    
    _ghostImageView.image = image;
//    _ghostImageView.image = [_recorder snapshotOfLastAppendedVideoBuffer];
    _ghostImageView.hidden = !_ghostModeButton.selected;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (IBAction)switchGhostMode:(id)sender {
    _ghostModeButton.selected = !_ghostModeButton.selected;
    _ghostImageView.hidden = !_ghostModeButton.selected;
    
    [self updateGhostImage];
}


- (BOOL)shouldAutorotate{
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations{
    return UIInterfaceOrientationPortrait |
    UIInterfaceOrientationPortraitUpsideDown;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation{
    return UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation)interfaceOrientation {
    return NO;
}



- (IBAction)shutterButtonTapped:(UIButton *)sender {
    
    if (!hasOrientaionLocked) {
        _recorder.autoSetVideoOrientation = NO;
        hasOrientaionLocked = YES;
        UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
        [[UIDevice currentDevice] setValue:[NSNumber numberWithInt:currentOrientation] forKey:@"orientation"];
    }
    
    
    // REC START
    
    if (!_recorder.isRecording) {
        
        
        
        // change UI
        [self.recBtn setImage:self.recStopImage
                     forState:UIControlStateNormal];
        
         [_recorder record];
        self.heightButtonConstraint.constant = 120.f;
        self.widthButtonConstraint.constant = 120.f;
    }
    // REC STOP
    else {
    
                    [_recorder pause:^{
                        self.heightButtonConstraint.constant = 70.f;
                        self.widthButtonConstraint.constant = 70.f;
            [self saveAndShowSession:_recorder.session];
        }];
        // change UI
        [self.recBtn setImage:self.recStartImage
                     forState:UIControlStateNormal];
    }

}

- (IBAction)shutterButtonActionStart:(id)sender {
    if (!hasOrientaionLocked) {
          _recorder.autoSetVideoOrientation = NO;
          hasOrientaionLocked = YES;
          UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
          [[UIDevice currentDevice] setValue:[NSNumber numberWithInt:currentOrientation] forKey:@"orientation"];
      }
      
      
      // REC START
      
      if (!_recorder.isRecording) {
       self.circleProgressView.status = NSLocalizedString(@"circle-progress-view.status-not-started", nil);
         self.circleProgressView.timeLimit = 10.f;
         self.circleProgressView.elapsedTime = 0;
         
          // change UI
          [self.recBtn setImage:self.recStopImage
                       forState:UIControlStateNormal];
          
           [_recorder record];
          self.heightButtonConstraint.constant = 120.f;
          self.widthButtonConstraint.constant = 120.f;
          self.circleProgressView.hidden = NO;
          self.outerImageView.hidden = YES;
      }
      // REC STOP
      else {
//
//             [_recorder pause:^{
//                 self.heightButtonConstraint.constant = 70.f;
//                 self.widthButtonConstraint.constant = 70.f;
//     [self saveAndShowSession:_recorder.session];
// }];
//          // change UI
 //         [self.recBtn setImage:self.recStartImage
 //                      forState:UIControlStateNormal];
      }

}

- (IBAction)shutterButtonActionEnd:(id)sender {
    
    self.heightButtonConstraint.constant = 70.f;
    self.widthButtonConstraint.constant = 70.f;
    if (_recorder.isRecording) {
     [_recorder pause:^{
          [self saveAndShowSession:_recorder.session];
      }];
    }
     self.circleProgressView.hidden = YES;
    self.outerImageView.hidden = NO;
           // change UI
           [self.recBtn setImage:self.recStartImage
                        forState:UIControlStateNormal];
}



- (IBAction)toolsButtonTapped:(UIButton *)sender {
    CGRect toolsFrame = self.toolsContainerView.frame;
    CGRect openToolsButtonFrame = self.openToolsButton.frame;
    
    if (toolsFrame.origin.y < 0) {
        sender.selected = YES;
        toolsFrame.origin.y = 0;
        openToolsButtonFrame.origin.y = toolsFrame.size.height + 15;
    } else {
        sender.selected = NO;
        toolsFrame.origin.y = -toolsFrame.size.height;
        openToolsButtonFrame.origin.y = 15;
    }
    
    [UIView animateWithDuration:0.15 animations:^{
        self.toolsContainerView.frame = toolsFrame;
        self.openToolsButton.frame = openToolsButtonFrame;
    }];
}

- (IBAction)closeCameraTapped:(id)sender {
    [self.delegate recorderDidCancel:self];
    
    self.navigationController.navigationBarHidden = NO;

    [self.navigationController popViewControllerAnimated:YES];
}

@end

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
@property (weak, nonatomic) IBOutlet UILabel *descLabel;


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
    self.descLabel.text = self.descriptionText;
    [self.navigationController setNavigationBarHidden:YES];
    
    
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
    
    _recorder.delegate = self;
    _recorder.autoSetVideoOrientation = YES; //YES causes bad orientation for video from camera roll
    
    UIView *previewView = self.previewView;
    _recorder.previewView = previewView;
    
    [self.stopButton addTarget:self action:@selector(handleStopButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
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
    UIAlertController* openProfileController = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle: UIAlertControllerStyleAlert];
    UIAlertAction* okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action)
                               {
    }];
    
    [openProfileController addAction:okAction];
    
    [self presentViewController:openProfileController animated:YES completion:nil];
}

- (void)showVideo {
    [self performSegueWithIdentifier:@"Video" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController isKindOfClass:[HBVideoPlayerViewController class]]) {
        HBVideoPlayerViewController *videoPlayer = segue.destinationViewController;
        videoPlayer.recordSession = _recordSession;
        videoPlayer.parent = self;
        videoPlayer.sendText = self.sendText;
        videoPlayer.retakeText = self.retakeText;
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
            self.stopButton.alpha = 1.0;
        } completion:^(BOOL finished) {
            self->_recorder.captureSessionPreset = kVideoPreset;
            
            self->_recorder.flashMode = SCFlashModeOff;
        }];
    } else {
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            
        } completion:^(BOOL finished) {
            _recorder.captureSessionPreset = AVCaptureSessionPresetPhoto;
            self->_recorder.flashMode = SCFlashModeAuto;
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
        self.descLabel.hidden = YES;
        self.heightButtonConstraint.constant = 120.f;
        self.widthButtonConstraint.constant = 120.f;
    } else if (touchDetector.state == UIGestureRecognizerStateEnded) {
        [_recorder pause:^{
            self.descLabel.hidden = NO;
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
    
    
    
    _ghostImageView.image = image;
    //    _ghostImageView.image = [_recorder snapshotOfLastAppendedVideoBuffer];
    
}

- (BOOL)prefersStatusBarHidden {
    return YES;
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
        self.descLabel.hidden = YES;
        self.heightButtonConstraint.constant = 120.f;
        self.widthButtonConstraint.constant = 120.f;
        
    }
    // REC STOP
    else {
        
        [_recorder pause:^{
            self.descLabel.hidden = NO;
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
        self.circleProgressView.timeLimit = 10.f;
        self.circleProgressView.elapsedTime = 0;
        
        // change UI
        [self.recBtn setImage:self.recStopImage
                     forState:UIControlStateNormal];
        
        [_recorder record];
        self.descLabel.hidden = YES;
        self.heightButtonConstraint.constant = 120.f;
        self.widthButtonConstraint.constant = 120.f;
        self.circleProgressView.hidden = NO;
        self.outerImageView.hidden = YES;
    }
    // REC STOP
    else {
        
    }
    
}

- (IBAction)shutterButtonActionEnd:(id)sender {
    self.descLabel.hidden = NO;
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
    
}

- (IBAction)closeCameraTapped:(id)sender {
    [self.delegate recorderDidCancel:self];
    
    self.navigationController.navigationBarHidden = NO;
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

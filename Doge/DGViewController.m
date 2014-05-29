//
//  DGViewController.m
//  Doge
//
//  Created by Sihao Lu on 5/26/14.
//  Copyright (c) 2014 DJ.Ben. All rights reserved.
//

#import "DGViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <SVProgressHUD.h>
#import <QuartzCore/QuartzCore.h>
#import "CIFaceFeature+UIImageOrientation.h"

CGFloat dogeFaceRatio = 409 / 491.0;

@interface DGViewController () <UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property NSMutableArray *featureMarkers;
@property NSMutableArray *doges;

- (IBAction)addPhoto:(id)sender;

@end

@implementation DGViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.featureMarkers = [NSMutableArray array];
    self.doges = [NSMutableArray array];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)addPhoto:(id)sender {
    UIActionSheet *actions = [[UIActionSheet alloc] initWithTitle:@"Add Photo" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"From Camera", @"From Gallery", nil];
    [actions setDelegate:self];
    [actions showFromBarButtonItem:self.navigationItem.rightBarButtonItem animated:YES];
}

- (void)setImage:(UIImage *)image withFeatures:(NSArray *)features {
    self.imageView.image = image;
    double viewAspectRatio = self.view.bounds.size.width / self.view.bounds.size.height;
    double compressionRatio;
    if (image.aspectRatio > viewAspectRatio) {
        // Wider, shorter than screen size
        CGFloat height = self.view.bounds.size.width / image.aspectRatio;
        CGFloat yOffset = (self.view.bounds.size.height - height) / 2;
        self.imageView.frame = CGRectMake(0, yOffset, self.view.bounds.size.width, height);
        compressionRatio = self.view.bounds.size.width / image.size.width;
    } else {
        // Thinner, taller than screen size
        CGFloat width = self.view.bounds.size.height * image.aspectRatio;
        CGFloat xOffset = (self.view.bounds.size.width - width) / 2;
        self.imageView.frame = CGRectMake(xOffset, 0, width, self.view.bounds.size.height);
        compressionRatio = self.view.bounds.size.height / image.size.height;
    }
    
    for (CIFaceFeature *feature in features) {
        CGRect faceBounds = [feature boundsForImage:image inView:self.imageView.bounds.size];
//        [self addMarkerAtFaceBounds:faceBounds];
        [self addDogeAtFaceBounds:faceBounds];
    }
    
}

- (void)removeAddons {
    for (UIView *featureMarker in self.featureMarkers) {
        [featureMarker removeFromSuperview];
    }
    for (UIImageView *doge in self.doges) {
        [doge removeFromSuperview];
    }
    [self.featureMarkers removeAllObjects];
    [self.doges removeAllObjects];
}

- (void)addMarkerAtFaceBounds:(CGRect)bounds {
    UIView *marker = [[UIView alloc] initWithFrame:bounds];
    marker.layer.borderColor = [UIColor orangeColor].CGColor;
    marker.layer.borderWidth = 2;
    [self.imageView addSubview:marker];
    [self.featureMarkers addObject:marker];

}

- (void)addDogeAtFaceBounds:(CGRect)bounds {
    // Extend the height upwards
    // because doge's ears occupy part of the image
    CGFloat extendedHeight = bounds.size.height / dogeFaceRatio;
    CGFloat newYCoordinate = bounds.origin.y - (extendedHeight - bounds.size.height);
    UIImageView *doge = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"doge_0_left"]];
    doge.frame = CGRectMake(bounds.origin.x, newYCoordinate, bounds.size.width, extendedHeight);
    [self.imageView addSubview:doge];
    [self.doges addObject:doge];
}

#pragma mark - Action Sheet
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 0:
            [self startImagePickerControllerFromViewController:self fromCamera:YES];
            break;
        case 1:
            [self startImagePickerControllerFromViewController:self fromCamera:NO];
            break;
        default:
            break;
    }
    // Clear the image view
    self.imageView.image = [UIImage imageNamed:@"doge_bg"];
    self.imageView.frame = [[UIScreen mainScreen] bounds];
    [self removeAddons];
}

#pragma mark - Image Picker
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    UIImage *originalImage, *editedImage, *imageToUse;
    
    // Handle a still image picked from a photo album
    if (CFStringCompare ((CFStringRef) mediaType, kUTTypeImage, 0)
        == kCFCompareEqualTo) {
        
        editedImage = (UIImage *) [info objectForKey:
                                   UIImagePickerControllerEditedImage];
        originalImage = (UIImage *) [info objectForKey:
                                     UIImagePickerControllerOriginalImage];
        
        if (editedImage) {
            imageToUse = editedImage;
        } else {
            imageToUse = originalImage;
        }
        
        [picker dismissViewControllerAnimated:YES completion:nil];

        // Detect face and smile
        [SVProgressHUD showWithStatus:@"Processing..."
                             maskType:SVProgressHUDMaskTypeGradient];
        
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(queue, ^{
            
            CIImage *image = [CIImage imageWithCGImage:imageToUse.CGImage];
            CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                                      context:nil
                                                      options:@{CIDetectorAccuracy: CIDetectorAccuracyHigh}];
            
            int exifOrientation;
            switch (imageToUse.imageOrientation) {
                case UIImageOrientationUp:
                    exifOrientation = 1;
                    break;
                case UIImageOrientationDown:
                    exifOrientation = 3;
                    break;
                case UIImageOrientationLeft:
                    exifOrientation = 8;
                    break;
                case UIImageOrientationRight:
                    exifOrientation = 6;
                    break;
                case UIImageOrientationUpMirrored:
                    exifOrientation = 2;
                    break;
                case UIImageOrientationDownMirrored:
                    exifOrientation = 4;
                    break;
                case UIImageOrientationLeftMirrored:
                    exifOrientation = 5;
                    break;
                case UIImageOrientationRightMirrored:
                    exifOrientation = 7;
                    break;
                default:
                    break;
            }
            NSLog(@"EXIF %d", exifOrientation);
            NSDictionary *options = @{CIDetectorSmile: @(YES),
                                      CIDetectorEyeBlink: @(YES),
                                      CIDetectorImageOrientation: @(exifOrientation)};
            
            NSArray *features = [detector featuresInImage:image options:options];
            for(CIFaceFeature *feature in features)
            {
                NSLog(@"bounds:%@\n", NSStringFromCGRect(feature.bounds));
                NSLog(@"hasSmile: %@\n\n", feature.hasSmile ? @"YES" : @"NO");
                NSLog(@"faceAngle: %@", feature.hasFaceAngle ? @(feature.faceAngle) : @"NONE");
                NSLog(@"leftEyeClosed: %@", feature.leftEyeClosed ? @"YES" : @"NO");
                NSLog(@"rightEyeClosed: %@", feature.rightEyeClosed ? @"YES" : @"NO");
            }
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self setImage:imageToUse withFeatures:features];
                [SVProgressHUD dismiss];
            });
            
        });
    }

    // Handle a selected movie
    if (CFStringCompare ((CFStringRef) mediaType, kUTTypeMovie, 0)
        == kCFCompareEqualTo) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Wrong Type" message:@"Please choose a photo instead of a video" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    }
    
}

#pragma mark - Helper
- (BOOL)startImagePickerControllerFromViewController:(UIViewController *)controller fromCamera:(BOOL)fromCamera {
    
    if (([UIImagePickerController isSourceTypeAvailable:
          UIImagePickerControllerSourceTypeCamera] == NO)
        || (controller == nil))
        return NO;
    
    
    UIImagePickerController *cameraUI = [[UIImagePickerController alloc] init];
    cameraUI.sourceType = fromCamera ? UIImagePickerControllerSourceTypeCamera : UIImagePickerControllerSourceTypePhotoLibrary;
    
    // Displays a control that allows the user to choose picture or
    // movie capture, if both are available:
    cameraUI.mediaTypes =
    [UIImagePickerController availableMediaTypesForSourceType:
     fromCamera ? UIImagePickerControllerSourceTypeCamera : UIImagePickerControllerSourceTypePhotoLibrary];
    
    // Hides the controls for moving & scaling pictures, or for
    // trimming movies. To instead show the controls, use YES.
    cameraUI.allowsEditing = NO;
    
    cameraUI.delegate = self;
    
    [controller presentViewController:cameraUI animated:YES completion:nil];
    return YES;
}

@end

@implementation UIImage (DGAspectRatio)

- (double)aspectRatio {
    return self.size.width / self.size.height;
}

@end

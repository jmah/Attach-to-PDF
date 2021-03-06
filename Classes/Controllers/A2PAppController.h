//
//  A2PAppController.h
//  Attach to PDF
//
//  Created by Jonathon Mah on 2008-02-10.
//  Copyright 2008 Playhaus. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ImageKit/ImageKit.h>


@interface A2PAppController : NSObject
{
	IBOutlet IKImageBrowserView *imageBrowserView;
	NSURL *inputFileURL;
	NSURL *outputDirectoryURL;
	NSArray *imagesToAttach;
    BOOL trashFilesOnClear;
}


#pragma mark Properties
@property(copy) NSArray *imagesToAttach;
@property(copy) NSURL *inputFileURL, *outputDirectoryURL;
@property BOOL trashFilesOnClear;

#pragma mark Interface actions
- (IBAction)attachFilesToPDF:(id)sender;
- (IBAction)clearInput:(id)sender;

@end

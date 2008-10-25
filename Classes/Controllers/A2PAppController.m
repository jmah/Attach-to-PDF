//
//  A2PAppController.m
//  Attach to PDF
//
//  Created by Jonathon Mah on 2008-02-10.
//  Copyright 2008 Playhaus. All rights reserved.
//

#import "A2PAppController.h"


@interface A2PImageObject : NSObject
{
	NSString *_path;
}

@property(readonly) NSString *path, *imageRepresentationType, *imageUID, *imageTitle;
@property(readonly) id imageRepresentation;

+ (id)imageObjectWithPath:(NSString *)path;
- (id)initWithPath:(NSString *)path;

@end


@implementation A2PImageObject

@synthesize path = _path;

+ (id)imageObjectWithPath:(NSString *)path; { return [[[self alloc] initWithPath:path] autorelease]; }

- (id)initWithPath:(NSString *)path;
{
	if ((self = [super init]))
		_path = [path copy];
	return self;
}

- (void)dealloc;
{
	[_path release], _path = nil;
	[super dealloc];
}

- (NSString *)imageRepresentationType; { return IKImageBrowserPathRepresentationType; }
- (id)imageRepresentation { return self.path; }
- (NSString *)imageUID; { return self.path; }
- (NSString *)imageTitle; { return [[NSFileManager defaultManager] displayNameAtPath:self.path]; }

@end


@implementation A2PAppController


#pragma mark Initialization and finalization

- (id)init;
{
	if ((self = [super init]))
		self.imagesToAttach = [NSArray array];
	return self;
}


- (void)awakeFromNib;
{
	[imageBrowserView setDraggingDestinationDelegate:self];
}


- (void)dealloc;
{
	[inputFileURL release], inputFileURL = nil;
	[outputDirectoryURL release], outputDirectoryURL = nil;
	[imagesToAttach release], imagesToAttach = nil;
	[super dealloc];
}



#pragma mark Properties

@synthesize imagesToAttach;
@synthesize inputFileURL, outputDirectoryURL;
@synthesize trashFilesOnClear;

- (void)setImagesToAttach:(NSArray *)imageObjects;
{
	id oldValue = imagesToAttach;
	imagesToAttach = [imageObjects copy];
	[oldValue release];
	[imageBrowserView reloadData];
}


- (void)setOutputDirectoryURL:(NSURL *)url;
{
	outputDirectoryURL = url;
	[[NSUserDefaults standardUserDefaults] setValue:[outputDirectoryURL path]
											 forKey:@"lastOutputDirectoryPath"];
}



#pragma mark Interface actions

- (IBAction)attachFilesToPDF:(id)sender;
{
	NSTask *task = [[[NSTask alloc] init] autorelease];
	
	task.launchPath = @"/usr/bin/env";
	
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"pdftk"];
	
	// Input file
	NSString *inputPath = [self.inputFileURL path];
	if (!inputPath)
#warning TODO Return error
		return;
	[arguments addObject:inputPath];
	
	// Files to attach
	[arguments addObject:@"attach_files"];
	for (A2PImageObject *imageObject in self.imagesToAttach)
		[arguments addObject:imageObject.path];
	
	
	// Output file
	NSString *outputPath = [[self.outputDirectoryURL path] stringByAppendingPathComponent:[inputPath lastPathComponent]];
	if (!outputPath)
#warning TODO Return error
		return;
	[arguments addObject:@"output"];
	[arguments addObject:outputPath];
	
	
	// Launch the task
	task.arguments = arguments;
	[task launch];
}


- (IBAction)clearInput:(id)sender;
{
    if (self.trashFilesOnClear) {
        NSMutableArray *pathsToTrash = [NSMutableArray array];
        if (self.inputFileURL)
            [pathsToTrash addObject:[self.inputFileURL path]];
        for (A2PImageObject *imageObject in self.imagesToAttach)
            [pathsToTrash addObject:imageObject.path];
        NSWorkspace *ws = [NSWorkspace sharedWorkspace];
        for (NSString *path in pathsToTrash)
            [ws performFileOperation:NSWorkspaceRecycleOperation
                              source:[path stringByDeletingLastPathComponent]
                         destination:nil
                               files:[NSArray arrayWithObject:[path lastPathComponent]]
                                 tag:NULL];
    }
	self.inputFileURL = nil;
	self.imagesToAttach = [NSArray array];
}



#pragma mark NSApplication delegate methods

- (void)applicationWillFinishLaunching:(NSNotification *)notification;
{
	NSString *lastOutputDirectoryPath = [[NSUserDefaults standardUserDefaults] valueForKey:@"lastOutputDirectoryPath"];
	if (lastOutputDirectoryPath)
		self.outputDirectoryURL = [NSURL fileURLWithPath:lastOutputDirectoryPath];
	
	// Launch pdftk to prime the cache
	// Create a dummy pipe to discard standard output
	NSPipe *pipe = [NSPipe pipe];
	NSTask *task = [[[NSTask alloc] init] autorelease];
	task.launchPath = @"/usr/bin/env";
	task.arguments = [NSArray arrayWithObject:@"pdftk"];
	task.standardOutput = pipe;
	task.standardError = pipe;
	[task launch];
}



#pragma mark NSWindow delegate methods

- (void)windowWillClose:(NSNotification *)notification;
{
	[NSApp terminate:self];
}



#pragma mark Image Browser data source

- (NSUInteger)numberOfItemsInImageBrowser:(IKImageBrowserView *)browser;
{
	return self.imagesToAttach.count;
}


- (id)imageBrowser:(IKImageBrowserView *)browser itemAtIndex:(NSUInteger)index;
{
	return [self.imagesToAttach objectAtIndex:index];
}


- (void)imageBrowser:(IKImageBrowserView *)browser removeItemsAtIndexes:(NSIndexSet *)indexes;
{
	NSMutableArray *newImages = [NSMutableArray arrayWithArray:self.imagesToAttach];
	[newImages removeObjectsAtIndexes:indexes];
	self.imagesToAttach = newImages;
}


- (BOOL)imageBrowser:(IKImageBrowserView *)browser moveItemsAtIndexes:(NSIndexSet *)indexes toIndex:(NSUInteger)destinationIndex;
{
	NSMutableArray *newImages = [NSMutableArray arrayWithArray:self.imagesToAttach];
	NSArray *movedImages = [newImages objectsAtIndexes:indexes];
	[newImages removeObjectsAtIndexes:indexes];
	destinationIndex -= [indexes countOfIndexesInRange:NSMakeRange(0, destinationIndex)];
	for (id imageObject in movedImages)
		[newImages insertObject:imageObject atIndex:destinationIndex++];
	self.imagesToAttach = newImages;
	return YES;
}



#pragma mark Image Browser drag and drop

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	if ([sender draggingSource] == imageBrowserView)
		return NSDragOperationMove;
	else
		return NSDragOperationCopy;
}


- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender;
{
	if ([sender draggingSource] == imageBrowserView)
		return NSDragOperationMove;
	else
		return NSDragOperationCopy;
}


- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
{
	NSPasteboard *pasteboard = [sender draggingPasteboard];

	if ([[pasteboard types] containsObject:NSFilenamesPboardType]) {
		NSString *errorString;
		NSArray *paths = [NSPropertyListSerialization propertyListFromData:[pasteboard dataForType:NSFilenamesPboardType]
														  mutabilityOption:kCFPropertyListImmutable
																	format:nil
														  errorDescription:&errorString];
		
		NSMutableArray *currentPaths = [NSMutableArray arrayWithCapacity:self.imagesToAttach.count];
		for (A2PImageObject *imageObject in self.imagesToAttach)
			[currentPaths addObject:imageObject.path];
		
		NSUInteger index = [imageBrowserView indexAtLocationOfDroppedItem];
		NSMutableArray *newImages = [NSMutableArray arrayWithArray:self.imagesToAttach];
		for (NSString *path in paths) {
			// Move the item, if it currently exists
			NSUInteger existingIndex = [currentPaths indexOfObject:path];
			if (existingIndex != NSNotFound) {
				[newImages removeObjectAtIndex:existingIndex];
				if (existingIndex < index)
					index--;
			}
			[newImages insertObject:[A2PImageObject imageObjectWithPath:path]
							atIndex:index++];
		}
		self.imagesToAttach = newImages;
		
		return YES;
	}
	else
		return NO;
}


@end

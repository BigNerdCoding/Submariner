//
//  SubmarinerAppDelegate.m
//  Submariner
//
//  Created by Rafaël Warnault on 06/06/11.
//
//  Copyright (c) 2011-2014, Rafaël Warnault
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  * Neither the name of the Read-Write.fr nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "SBAppDelegate.h"
#import "SBPreferencesController.h"
#import "SBDatabaseController.h"
#import "SBTrack.h"
#import "SBPlayer.h"
#import "SBArtist.h"
#import "SBLibrary.h"
#import "SBAlbum.h"
// Additions
#import "NSManagedObjectContext+Fetch.h"
#import "NSWindow-Zoom.h"


@implementation SBAppDelegate


#pragma mark -
#pragma mark Singlton

+ (id)sharedInstance {
    static SBAppDelegate *sharedInstance;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        //sharedInstance = [[MyClass alloc] init];
        sharedInstance = [SBAppDelegate alloc];
        sharedInstance = [sharedInstance init];
    });
    return sharedInstance;
}



#pragma mark -
#pragma mark LifeCycle


- (id)init {
    self = [super init];
    return self;
}


- (void)dealloc {
    [super dealloc];
}


#pragma mark -
#pragma mark NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    preferencesController = [[SBPreferencesController alloc] initWithManagedObjectContext:[self managedObjectContext]];
    databaseController = [[SBDatabaseController alloc] initWithManagedObjectContext:[self managedObjectContext]];
    
    [self zoomDatabaseWindow:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    
    // unplay all tracks before quitting
    NSError *error = nil;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(isPlaying == YES)"];
    NSArray *tracks = [[self managedObjectContext] fetchEntitiesNammed:@"Track" withPredicate:predicate error:&error];
    for(SBTrack *track in tracks) {
        [track setIsPlaying:[NSNumber numberWithBool:NO]];
    }
    
    // Save changes in the application's managed object context before the application terminates.
    if (!__managedObjectContext) {
        return NSTerminateNow;
    }
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }
    
    if (![[self managedObjectContext] hasChanges]) {
        return NSTerminateNow;
    }
    
    if (![[self managedObjectContext] save:&error]) {
        
        // Customize this code block to include application-specific recovery steps.              
        BOOL result = [sender presentError:error];
        if (result) {
            return NSTerminateCancel;
        }
        
        NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];
        
        NSInteger answer = [alert runModal];
        alert = nil;
        
        if (answer == NSAlertAlternateReturn) {
            return NSTerminateCancel;
        }
    }
    
    return NSTerminateNow;
}


- (BOOL) applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    [self zoomDatabaseWindow:self];
    return NO;
}

- (BOOL)application:(NSApplication *)app openFile:(NSString *)filename {
    if(filename) {
        [databaseController openImportAlert:[databaseController window] files:[NSArray arrayWithObject:filename]];
        return YES;
    }
    return NO;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames {
    if(filenames && [filenames count] > 0)
        [databaseController openImportAlert:[databaseController window] files:filenames];
}

- (BOOL)application:(NSApplication *)app openFileWithoutUI:(NSString *)filename {
    if(filename) {
        [databaseController openImportAlert:[databaseController window] files:[NSArray arrayWithObject:filename]];
        return YES;
    }
    return NO; 
}







#pragma mark -
#pragma mark App Directory Management


- (NSURL *)applicationFilesDirectory {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *libraryURL = [[fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    return [libraryURL URLByAppendingPathComponent:@"Submariner"];
}

- (NSString *)musicDirectory {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Music/Submariner/Music"];
    if(![fileManager fileExistsAtPath:path]) [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    return path;
}

- (NSString *)coverDirectory {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Music/Submariner/Covers"];
    if(![fileManager fileExistsAtPath:path]) [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    return path;
}







#pragma mark -
#pragma mark IBAction

- (IBAction) saveAction:(id)sender {
    
    NSError *error = nil;
    
    if([[self managedObjectContext] hasChanges]) {
        NSLog(@"save : hasChange");
        if (![[self managedObjectContext] commitEditing]) {
            NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
        }
        
        if (![[self managedObjectContext] save:&error]) {
            [[NSApplication sharedApplication] presentError:error];
        }
    }
}

- (IBAction)zoomDatabaseWindow:(id)sender {
    
    NSWindow *window = [databaseController window];
    
    // zoom the window, useless ?
//    NSRect rect = NSMakeRect([window frame].origin.x+[window frame].size.width/2,
//                             [window frame].origin.y+[window frame].size.height/2,
//                             10,
//                             10);    
//    
//    [window zoomOnFromRect:rect];
    
    [window makeKeyAndOrderFront:sender];
}


- (IBAction)openPreferences:(id)sender {
    [preferencesController showWindow:sender];
}

- (IBAction)openDatabase:(id)sender {
    [databaseController showWindow:sender];
}

- (IBAction)openAudioFiles:(id)sender {
    [databaseController openAudioFiles:sender];
}

- (IBAction)newPlaylist:(id)sender {
    [databaseController addPlaylist:sender];
}

- (IBAction)newServer:(id)sender {
    [databaseController addServer:sender];
}

- (IBAction)toogleTracklist:(id)sender {
    [databaseController toggleTrackList:sender];
}

- (IBAction)toggleServerUsers:(id)sender {
    [databaseController toggleServerUsers:sender];
}

- (IBAction)playPause:(id)sender {
    [databaseController playPause:sender];
}

- (IBAction)stop:(id)sender {
    [databaseController stop:sender];
}

- (IBAction)nextTrack:(id)sender {
    [databaseController nextTrack:sender];
}

- (IBAction)previousTrack:(id)sender {
    [databaseController previousTrack:sender];
}

- (IBAction)repeatNone:(id)sender {
    [databaseController repeatNone: sender];
}

- (IBAction)repeatOne:(id)sender {
    [databaseController repeatOne: sender];
}

- (IBAction)repeatAll:(id)sender {
    [databaseController repeatAll: sender];
}

- (IBAction)repeatModeCycle:(id)sender {
    [databaseController repeat: sender];
}

- (IBAction)toggleShuffle:(id)sender {
    [databaseController shuffle: sender];
}

- (IBAction)search:(id)sender {
    [databaseController search:sender];
}

- (IBAction)showIndices:(id)sender {
    [databaseController showIndices:sender];
}

- (IBAction)showAlbums:(id)sender {
    [databaseController showAlbums:sender];
}

- (IBAction)showPodcasts:(id)sender {
    [databaseController showPodcasts:sender];
}

- (IBAction)showWebsite:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.read-write.fr/"]];
}

- (IBAction)playTrackForMenuItem:(id)sender {
    SBTrack *track = [sender representedObject];
    if(track) {
        // stop current playing tracks
        [[SBPlayer sharedInstance] stop];
        
        NSArray *descriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"trackNumber" ascending:YES]];
        NSArray *tracks = [track.album.tracks sortedArrayUsingDescriptors:descriptors];
        
        // add track to player
        if([[NSUserDefaults standardUserDefaults] integerForKey:@"playerBehavior"] == 1) {
            [[SBPlayer sharedInstance] addTrackArray:tracks replace:YES];
            // play track
            [[SBPlayer sharedInstance] playTrack:track];
        } else {
            [[SBPlayer sharedInstance] addTrackArray:tracks replace:NO];
            [[SBPlayer sharedInstance] playTrack:track];
        }
    }
}



#pragma mark -
#pragma mark Core Data Support


/**
    Creates if necessary and returns the managed object model for the application.
 */
- (NSManagedObjectModel *)managedObjectModel {
    if (__managedObjectModel) {
        return __managedObjectModel;
    }
	
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Submariner" withExtension:@"momd"];
    __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];    
    return __managedObjectModel;
}

/**
    Returns the persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.)
 */
- (NSPersistentStoreCoordinator *) persistentStoreCoordinator {
    if (__persistentStoreCoordinator) {
        return __persistentStoreCoordinator;
    }

    NSManagedObjectModel *mom = [self managedObjectModel];
    if (!mom) {
        NSLog(@"%@:%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd));
        return nil;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationFilesDirectory = [self applicationFilesDirectory];
    NSError *error = nil;
    
    NSDictionary *properties = [applicationFilesDirectory resourceValuesForKeys:[NSArray arrayWithObject:NSURLIsDirectoryKey] error:&error];
        
    if (!properties) {
        BOOL ok = NO;
        if ([error code] == NSFileReadNoSuchFileError) {
            ok = [fileManager createDirectoryAtPath:[applicationFilesDirectory path] withIntermediateDirectories:YES attributes:nil error:&error];
        }
        if (!ok) {
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    }
    else {
        if ([[properties objectForKey:NSURLIsDirectoryKey] boolValue] != YES) {
            // Customize and localize this error.
            NSString *failureDescription = [NSString stringWithFormat:@"Expected a folder to store application data, found a file (%@).", [applicationFilesDirectory path]]; 
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            [dict setValue:failureDescription forKey:NSLocalizedDescriptionKey];
            error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:101 userInfo:dict];
            
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    }
    
    NSURL *url = [applicationFilesDirectory URLByAppendingPathComponent:@"Submariner.storedata"];
    __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    if (![__persistentStoreCoordinator addPersistentStoreWithType:NSXMLStoreType configuration:nil URL:url options:nil error:&error]) {
        [[NSApplication sharedApplication] presentError:error];
        __persistentStoreCoordinator, __persistentStoreCoordinator = nil;
        return nil;
    }

    return __persistentStoreCoordinator;
}

/**
    Returns the managed object context for the application (which is already
    bound to the persistent store coordinator for the application.) 
 */
- (NSManagedObjectContext *) managedObjectContext {
    if (__managedObjectContext) {
        return __managedObjectContext;
    }

    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@"Failed to initialize the store" forKey:NSLocalizedDescriptionKey];
        [dict setValue:@"There was an error building up the data file." forKey:NSLocalizedFailureReasonErrorKey];
        NSError *error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    __managedObjectContext = [[NSManagedObjectContext alloc] init];
    [__managedObjectContext setPersistentStoreCoordinator:coordinator];

    return __managedObjectContext;
}



- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return [[self managedObjectContext] undoManager];
}



#pragma mark -
#pragma mark UI Validator

- (BOOL)validateUserInterfaceItem: (id<NSValidatedUserInterfaceItem>) item {
    return [databaseController validateUserInterfaceItem: item];
}




@end
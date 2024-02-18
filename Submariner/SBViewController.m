//
//  SBViewController.m
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

#import "SBViewController.h"

#import "SBDatabaseController.h"

#import "Submariner-Swift.h"

@implementation SBViewController

@synthesize managedObjectContext;


#pragma mark -
#pragma mark Class Methods

+ (NSString *)nibName {
    return nil;
}



#pragma mark -
#pragma mark Lifecycle

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context
{
    self = [super initWithNibName:[[self class] nibName] bundle:nil];
    if (self) {
        managedObjectContext = context;
    }
    return self;
}


#pragma mark -
#pragma mark Workaround for split view and safe area

// If we don't do this, the split view autosaves based on the full frame, not the safe area.
// When restored, it'll shrink a bit based on the safe area height. So, let's compensate for it.
- (void)viewDidAppear {
    [super viewDidAppear];
    if (self->compensatedSplitView == nil) {
        return;
    }
    dispatch_once(&self->compensatedSplitViewToken, ^{
        if (self->compensatedSplitView.vertical && self->compensatedSplitView.subviews.count != 2) {
            return;
        }
        // Reset the holding priority, since we still want even resize,
        // we just need to make the previous size stick.
        NSLayoutPriority otherPriority = [self->compensatedSplitView holdingPriorityForSubviewAtIndex: 1];
        [self->compensatedSplitView setHoldingPriority: otherPriority forSubviewAtIndex: 0];
        NSView *topItem = [self->compensatedSplitView.subviews objectAtIndex: 0];
        // For some reason, we don't need to compensate for the safe area,
        // we just need to resize it even though it's the same size. Weird.
        CGFloat oldSize = topItem.frame.size.height;
        [self->compensatedSplitView setPosition: oldSize ofDividerAtIndex: 0];
    });
}


#pragma mark -
#pragma mark Library View Helper Functions

- (NSArray<NSSortDescriptor*>*) sortDescriptorsForPreference: (NSString*)preference {
    NSSortDescriptor *albumNameDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"itemName" ascending:YES];
    if ([preference isEqualToString: @"OldestFirst"]) {
        NSSortDescriptor *albumYearDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"year" ascending:YES];
        return @[albumYearDescriptor, albumNameDescriptor];
    } else {
        return @[albumNameDescriptor];
    }
}

- (NSArray<NSSortDescriptor*>*) sortDescriptorsForPreference {
    NSString *newOrderType = [[NSUserDefaults standardUserDefaults] stringForKey: @"albumSortOrder"];
    return [self sortDescriptorsForPreference: newOrderType];
}

-(void)showTracksInFinder:(NSArray<SBTrack*>*)trackList selectedIndices:(NSIndexSet*)indexSet
{
    NSArray *selectedTracks = [trackList objectsAtIndexes: indexSet];
    [self showTracksInFinder: selectedTracks];
}

-(void)showTracksInFinder:(NSArray<SBTrack*>*)trackList
{
    NSMutableArray *tracks = [NSMutableArray array];
    
    __block NSInteger remoteOnly = 0;
    for (SBTrack *track in trackList) {
        SBTrack *trackToUse = track;
        // handle remote but cached tracks
        if (track.localTrack != nil) {
            trackToUse = track.localTrack;
        } else if (trackToUse.isLocal.boolValue == NO) {
            remoteOnly++;
            return;
        }
        NSURL *trackURL = [NSURL fileURLWithPath: trackToUse.path];
        [tracks addObject: trackURL];
    }
    
    if ([tracks count] > 0) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: tracks];
    }
    if (remoteOnly > 0) {
        NSAlert *oops = [[NSAlert alloc] init];
        oops.messageText = @"Some tracks couldn't be shown in Finder";
        oops.informativeText = @"If the remote track isn't cached, it only exists on the server, and not the filesystem.";
        oops.alertStyle = NSAlertStyleInformational;
        [oops addButtonWithTitle: @"OK"];
        [oops beginSheetModalForWindow: self.view.window completionHandler: ^(NSModalResponse response) {}];
    }
}

-(void)downloadTracks:(NSArray<SBTrack*>*)trackList selectedIndices:(NSIndexSet*)indexSet databaseController:(SBDatabaseController*)databaseController
{
    NSArray *selectedTracks = [trackList objectsAtIndexes: indexSet];
    [self downloadTracks: selectedTracks databaseController: databaseController];
}

-(void)downloadTracks:(NSArray<SBTrack*>*)trackList databaseController:(SBDatabaseController*)databaseController
{
    NSInteger downloaded = 0;
    for (SBTrack *track in trackList) {
        // Check if we've already downloaded this track.
        if (track.localTrack != nil || track.isLocal.boolValue == YES) {
            return;
        }
        
        SBSubsonicDownloadOperation *op = [[SBSubsonicDownloadOperation alloc]
                                           initWithManagedObjectContext:self.managedObjectContext
                                           trackID: [track objectID]];
        
        [[NSOperationQueue sharedDownloadQueue] addOperation:op];
        downloaded++;
    }
    if (databaseController != nil && downloaded > 0) {
        [databaseController showDownloadView: self];
    }
}

- (SBSelectedRowStatus) selectedRowStatus:(NSArray<SBTrack*>*)trackList selectedIndices:(NSIndexSet*)indexSet
{
    NSArray *selectedTracks = [trackList objectsAtIndexes: indexSet];
    return [self selectedRowStatus: selectedTracks];
}

- (SBSelectedRowStatus) selectedRowStatus:(NSArray<SBTrack*>*)trackList
{
    __block NSInteger downloadable = 0, showable = 0;
    for (SBTrack *track in trackList) {
        if (track.isLocal.boolValue == YES || track.localTrack != nil) {
            showable++;
        }
        if (track.isLocal.boolValue == NO && track.localTrack == nil) {
            downloadable++;
        }
    }
    SBSelectedRowStatus status = 0;
    if (downloadable)
        status |= SBSelectedRowDownloadable;
    if (showable)
        status |= SBSelectedRowShowableInFinder;
    return status;
}

- (void)createLocalPlaylistWithSelected:(NSArray<SBTrack*>*)trackList selectedIndices:(NSIndexSet*)indexSet databaseController:(SBDatabaseController*)databaseController {
    NSArray *selectedTracks = [trackList objectsAtIndexes: indexSet];
    [self createLocalPlaylistWithSelected: selectedTracks databaseController: databaseController];
}

- (void)createLocalPlaylistWithSelected:(NSArray<SBTrack*>*)trackList databaseController:(SBDatabaseController*)databaseController {
    NSSet *selectedTracksAsSet = [NSSet setWithArray: trackList];
    
    // create playlist
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"Playlists"];
    SBSection *playlistsSection = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:nil];
    
    SBPlaylist *newPlaylist = [SBPlaylist insertInManagedObjectContext:self.managedObjectContext];
    [newPlaylist setResourceName:@"New Playlist"];
    [newPlaylist setSection:playlistsSection];
    [newPlaylist setTracks: selectedTracksAsSet];
    [playlistsSection addResourcesObject:newPlaylist];
}

@end

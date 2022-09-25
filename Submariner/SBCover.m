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


#import "SBArtist.h"
#import "SBAlbum.h"
#import "SBCover.h"
#import "SBTrack.h"
#import "SBServer.h"

#import "SBAppDelegate.h"

@implementation SBCover

// This is overriden so that consumers don't need to handle the difference
// between absolute and relative paths themselves. Ideally, the relative path
// is stored (for portability), and the absolute path provides for any consumers
// needing to load the file. By overriding the getter, we reduce refactoring.
//
// XXX: Migrate absolute resources to relative ones on-demand here
// XXX: Why is there a difference between MusicItem.path and Cover.imagePath?
- (NSString*)imagePath {
    NSString *currentPath = self.primitiveImagePath;
    if (currentPath == nil || [currentPath isAbsolutePath]) {
        return currentPath;
    } else {
        // Find the resource we belong to, either album through or track
        NSString *serverName = nil;
        if (self.album != nil && self.album.artist != nil && self.album.artist.server != nil) {
            serverName = self.album.artist.server.resourceName;
        } else if (self.track != nil && self.track.server != nil) {
            serverName = self.track.server.resourceName;
        } else {
            // give up, we can't know
            return currentPath;
        }
        NSString *coversDir = [[[SBAppDelegate sharedInstance] coverDirectory] stringByAppendingPathComponent: serverName];
        return [coversDir stringByAppendingPathComponent: currentPath];
    }
}

@end

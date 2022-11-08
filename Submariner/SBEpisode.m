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


#import "SBEpisode.h"
#import "NSString+Time.h"
#import "NSString+Hex.h"
#import "SBServer.h"
#import "SBPodcast.h"
#import "NSURL+Parameters.h"

@implementation SBEpisode

@synthesize statusImage;

- (NSImage *)statusImage {
    NSImage *result = [NSImage imageNamed: NSImageNameStatusPartiallyAvailable];
    
    if([self.episodeStatus isEqualToString:@"new"] || [self.episodeStatus isEqualToString:@"completed"])
        result = [NSImage imageNamed: NSImageNameStatusAvailable];
    
    if([self.episodeStatus isEqualToString:@"downloading"] || [self.episodeStatus isEqualToString:@"skipped"])
        result = [NSImage imageNamed: NSImageNameStatusPartiallyAvailable];
    
    if([self.episodeStatus isEqualToString:@"error"] || [self.episodeStatus isEqualToString:@"deleted"])
        result = [NSImage imageNamed: NSImageNameStatusUnavailable];
    
    return result;
}


- (NSURL *)streamURL {
    // the default URL parameters
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [self.server getBaseParameters: parameters];
    [parameters setValue:self.streamID forKey:@"id"];
    
    return [NSURL URLWithString:self.server.url command:@"rest/stream.view" parameters:parameters];
}


- (NSURL *)downloadURL {
    // the default URL parameters
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [self.server getBaseParameters: parameters];
    [parameters setValue:self.streamID forKey:@"id"];
    
    return [NSURL URLWithString:self.server.url command:@"rest/download.view" parameters:parameters];
}

- (NSString *)artistString {
    return self.podcast.itemName;
}

- (NSString *)albumString {
    return self.episodeDescription;
}

@end

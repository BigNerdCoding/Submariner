//
//  SBPlayer.m
//  Sub
//
//  Created by Rafaël Warnault on 22/05/11.
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

#include <libkern/OSAtomic.h>
#import <SFBAudioEngine/SFBAudioPlayer.h>
#import <SFBAudioEngine/SFBAudioDecoder.h>

#import "SBAppDelegate.h"
#import "SBPlayer.h"
#import "SBTrack.h"
#import "SBServer.h"
#import "SBLibrary.h"
#import "SBImportOperation.h"

#import "NSURL+Parameters.h"
#import "NSManagedObjectContext+Fetch.h"
#import "NSOperationQueue+Shared.h"
#import "NSString+Time.h"

#import <MediaPlayer/MPNowPlayingInfoCenter.h>
#import <MediaPlayer/MPMediaItem.h>

#import <MediaPlayer/MPRemoteCommandCenter.h>
#import <MediaPlayer/MPRemoteCommandEvent.h>
#import <MediaPlayer/MPRemoteCommand.h>

#define LOCAL_PLAYER localPlayer


// notifications
NSString *SBPlayerPlaylistUpdatedNotification = @"SBPlayerPlaylistUpdatedNotification";
NSString *SBPlayerPlayStateNotification = @"SBPlayerPlayStateNotification";
NSString *SBPlayerMovieToPlayNotification = @"SBPlayerPlaylistUpdatedNotification";



@interface SBPlayer (Private)

- (void)playRemoteWithURL:(NSURL *)url;
- (void)playLocalWithURL:(NSURL *)url;
- (void)unplayAllTracks;
- (void)decodingStarted:(const SFBAudioDecoder *)decoder;
- (SBTrack *)getRandomTrackExceptingTrack:(SBTrack *)_track;
- (SBTrack *)nextTrack;
- (SBTrack *)prevTrack;
- (void)showVideoAlert;

@end

@implementation SBPlayer


@synthesize currentTrack;
@synthesize playlist;
@synthesize isShuffle;
@synthesize isPlaying;
@synthesize isPaused;
//@synthesize repeatMode;




#pragma mark -
#pragma mark Singleton support 

+ (SBPlayer*)sharedInstance {

    static SBPlayer* sharedInstance = nil;
    if (sharedInstance == nil) {
        sharedInstance = [[SBPlayer alloc] init];
    }
    return sharedInstance;
    
}

- (void)initializeSystemMediaControls
{
    MPRemoteCommandCenter *remoteCommandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    
    [remoteCommandCenter.playCommand setEnabled:YES];
    [remoteCommandCenter.pauseCommand setEnabled:YES];
    [remoteCommandCenter.togglePlayPauseCommand setEnabled:YES];
    [remoteCommandCenter.stopCommand setEnabled:YES];
    [remoteCommandCenter.changePlaybackPositionCommand setEnabled:YES];
    [remoteCommandCenter.nextTrackCommand setEnabled:YES];
    [remoteCommandCenter.previousTrackCommand setEnabled:YES];

    [[remoteCommandCenter playCommand] addTarget:self action:@selector(clickPlay)];
    [[remoteCommandCenter pauseCommand] addTarget:self action:@selector(clickPause)];
    [[remoteCommandCenter togglePlayPauseCommand] addTarget:self action:@selector(clickPlay)];
    [[remoteCommandCenter stopCommand] addTarget:self action:@selector(clickStop)];
    [[remoteCommandCenter changePlaybackPositionCommand] addTarget:self action:@selector(clickSeek:)];
    [[remoteCommandCenter nextTrackCommand] addTarget:self action:@selector(clickNext)];
    [[remoteCommandCenter previousTrackCommand] addTarget:self action:@selector(clickPrev)];
    
    songInfo = [[NSMutableDictionary alloc] init];
}

- (id)init {
    self = [super init];
    if (self) {
        localPlayer = [[SFBAudioPlayer alloc] init];
        
        playlist = [[NSMutableArray alloc] init];
        isShuffle = NO;
        isCaching = NO;
        
        repeatMode = SBPlayerRepeatNo;
    }
    [self initializeSystemMediaControls];
    return self;
}

- (void)dealloc {
    // remove remote player observers
    [self stop];
    
    [LOCAL_PLAYER dealloc];
    localPlayer = NULL;
    
    [songInfo release];
    [remotePlayer release];
    [currentTrack release];
    [playlist release];
    if (tmpLocation) {
        [tmpLocation release];
    }
    [super dealloc];
}

#pragma mark -
#pragma mark System Now Playing/Controls

// These two are separate because updating metadata is more expensive than i.e. seek position
-(void) updateSystemNowPlayingStatus  {
    MPNowPlayingInfoCenter * defaultCenter = [MPNowPlayingInfoCenter defaultCenter];
    
    SBTrack *currentTrack = [self currentTrack];
    
    if (currentTrack != nil) {
        // times are in sec; trust the SBTrack if the player isn't ready
        // as passing NaNs here will crash the menu bar (!)
        auto duration = [self durationTime];
        if (isnan(duration) || duration == 0) {
            [songInfo setObject: [NSNumber numberWithDouble: 0] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
            [songInfo setObject: [currentTrack duration] forKey:MPMediaItemPropertyPlaybackDuration];
        } else {
            [songInfo setObject: [NSNumber numberWithDouble: [self currentTime]] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
            [songInfo setObject: [NSNumber numberWithDouble: duration] forKey:MPMediaItemPropertyPlaybackDuration];
        }
    }
    
    if (![self isPaused] && [self isPlaying]) {
        [defaultCenter setPlaybackState:MPNowPlayingPlaybackStatePlaying];
    } else if ([self isPaused] && [self isPlaying]) {
        [defaultCenter setPlaybackState:MPNowPlayingPlaybackStatePaused];
    } else if (![self isPlaying]) {
        [defaultCenter setPlaybackState:MPNowPlayingPlaybackStateStopped];
    }
    [defaultCenter setNowPlayingInfo: songInfo];
}

-(void) updateSystemNowPlayingMetadata {
    SBTrack *currentTrack = [self currentTrack];
    
    if (currentTrack != nil) {
        // i guess if we ever support video again...
        [songInfo setObject: [NSNumber numberWithInteger: MPNowPlayingInfoMediaTypeAudio] forKey:MPMediaItemPropertyMediaType];
        // XXX: podcasts will have different properties on SBTrack
        [songInfo setObject: [currentTrack itemName] forKey:MPMediaItemPropertyTitle];
        [songInfo setObject: [currentTrack albumString] forKey:MPMediaItemPropertyAlbumTitle];
        [songInfo setObject: [currentTrack artistString] forKey:MPMediaItemPropertyArtist];
        NSString *genre = [currentTrack genre];
        if (genre != nil) {
            [songInfo setObject: genre forKey:MPMediaItemPropertyGenre];
        }
        [songInfo setObject: [currentTrack rating] forKey:MPMediaItemPropertyRating];
        // seems the OS can use this to generate waveforms? should it be the download URL?
        [songInfo setObject:[currentTrack streamURL] forKey:MPMediaItemPropertyAssetURL];
        // do we have enough metadata to fill in?
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDate *releaseYear = [calendar dateWithEra:1 year:[[currentTrack year] intValue] month:0 day:0 hour:0 minute:0 second:0 nanosecond:0];
        [songInfo setObject:releaseYear forKey:MPMediaItemPropertyReleaseDate];
        // XXX: movieAttributes is blank and could be filled in with externalMetadata?
        if (@available(macOS 10.13.2, *)) {
            NSImage *artwork = [currentTrack coverImage];
            CGSize artworkSize = [artwork size];
            MPMediaItemArtwork *mpArtwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:artworkSize requestHandler:^NSImage * _Nonnull(CGSize size) {
                return artwork;
            }];
            [songInfo setObject: mpArtwork forKey:MPMediaItemPropertyArtwork];
        }
    }
}

-(void) updateSystemNowPlaying {
    [self updateSystemNowPlayingMetadata];
    [self updateSystemNowPlayingStatus];
}

- (MPRemoteCommandHandlerStatus)clickPlay {
    // This is a toggle because the system media key always sends play.
    [self playPause];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)clickPause {
    [self pause];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)clickStop {
    [self stop];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)clickNext {
    [self next];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)clickPrev {
    [self previous];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (MPRemoteCommandHandlerStatus)clickSeek: (MPChangePlaybackPositionCommandEvent*)event {
    NSTimeInterval newTime = [event positionTime];
    [self seekToTime: newTime];
    return MPRemoteCommandHandlerStatusSuccess;
}

#pragma mark -
#pragma mark Playlist Management

- (void)addTrack:(SBTrack *)track replace:(BOOL)replace {
    
    if(replace) {
        [playlist removeAllObjects];
    }
    
    [playlist addObject:track];
    [[NSNotificationCenter defaultCenter] postNotificationName:SBPlayerPlaylistUpdatedNotification object:self];
}

- (void)addTrackArray:(NSArray *)array replace:(BOOL)replace {
    
    if(replace) {
        [playlist removeAllObjects];
    }
    
    [playlist addObjectsFromArray:array];
    [[NSNotificationCenter defaultCenter] postNotificationName:SBPlayerPlaylistUpdatedNotification object:self];
}


- (void)removeTrack:(SBTrack *)track {
    if([track isEqualTo:self.currentTrack]) {
        [self stop];
    }
    
    [playlist removeObject:track];
    [[NSNotificationCenter defaultCenter] postNotificationName:SBPlayerPlaylistUpdatedNotification object:self];
}

- (void)removeTrackArray:(NSArray *)tracks {
    [playlist removeObjectsInArray:tracks];
    [[NSNotificationCenter defaultCenter] postNotificationName:SBPlayerPlaylistUpdatedNotification object:self];
}






#pragma mark -
#pragma mark Player Control

- (void)playTrack:(SBTrack *)track {
    
    // stop player
    [self stop];
        
    // clean previous playing track
    if(self.currentTrack != nil) {
        [self.currentTrack setIsPlaying:[NSNumber numberWithBool:NO]];
        self.currentTrack = nil;
    }
    
    // set the new current track
    [self setCurrentTrack:track];    
    
    // Caching is handled when we request it now, including its file name
    isCaching = NO;
    
    if(self.currentTrack.isVideo) {
        [self showVideoAlert];
        return;
    } else {
        NSURL *url = [self.currentTrack.localTrack streamURL];
        if (url == nil) {
            url = [self.currentTrack streamURL];
        }
        // SFBAudioEngine has issues with HTTP resources, and doesn't support some of the AVF features,
        // like spatialized audio. Nowadays, codec support in CoreAudio is better, and where it's weak,
        // like Vorbis tags, SFB can pick ip the slack. Using AVF is more predictable in general.
        // XXX: Override somewhere?
        BOOL useLocalPlayer = NO;
        if (useLocalPlayer) {
            [self playLocalWithURL:url];
        } else {
            [self playRemoteWithURL:url];
        }
    }
    
    // setup player for playing
    [self.currentTrack setIsPlaying:[NSNumber numberWithBool:YES]];
    [[NSNotificationCenter defaultCenter] postNotificationName:SBPlayerPlaylistUpdatedNotification object:self];
    self.isPlaying = YES;
    self.isPaused = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:SBPlayerPlayStateNotification object:self];
    
    // update NPIC
    [self updateSystemNowPlaying];
}


- (void)playRemoteWithURL:(NSURL *)url {
    remotePlayer = [[AVPlayer alloc] initWithURL:url];
    
	if (!remotePlayer)
		NSLog(@"Couldn't init player");
    
	else {
        [remotePlayer setVolume:[self volume]];
        [remotePlayer addObserver:self forKeyPath:@"status" options:0 context:nil];
        AVPlayerItem *currentItem = [remotePlayer currentItem];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:currentItem];
    }
}

- (void)playLocalWithURL:(NSURL *)url {
    NSError *decodeError = nil;
    SFBAudioDecoder *decoder = [[SFBAudioDecoder alloc] initWithURL: url /*decoderName:SFBAudioDecoderNameFLAC*/ error: &decodeError];
	if(NULL != decoder) {
        
        [LOCAL_PLAYER setVolume: [self volume] error: nil];
        
        // Register for rendering started/finished notifications so the UI can be updated properly
        [LOCAL_PLAYER setDelegate:self];
        NSError *decoderError = nil;
        [decoder openReturningError: &decoderError];
        if (decoderError) {
            NSLog(@"Decoder open error: %@", decoderError);
            [decoder dealloc];
            return;
        }
        if([LOCAL_PLAYER enqueueDecoder: decoder error: nil]) {
            //[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:url];
        }else {
            [decoder dealloc];
        }
    } else {
        NSLog(@"Couldn't decode %@: %@", url, decodeError);
    }
}


- (void)playOrResume {
    if(remotePlayer != nil) {
        [remotePlayer play];
        self.isPaused = NO;
    }
    if(LOCAL_PLAYER && [LOCAL_PLAYER isPaused]) {
        [LOCAL_PLAYER resume];
        self.isPaused = NO;
    } else if (LOCAL_PLAYER) {
        NSError *error;
        [LOCAL_PLAYER playReturningError:&error];
        self.isPaused = [LOCAL_PLAYER isPaused];
    }
    [self updateSystemNowPlaying];
    [[NSNotificationCenter defaultCenter] postNotificationName:SBPlayerPlayStateNotification object:self];
}


- (void)pause {
    if(remotePlayer != nil) {
        [remotePlayer pause];
        self.isPaused = YES;
    }
    if(LOCAL_PLAYER && [LOCAL_PLAYER engineIsRunning]) {
        [LOCAL_PLAYER pause];
        self.isPaused = YES;
    }
    [self updateSystemNowPlayingStatus];
    [[NSNotificationCenter defaultCenter] postNotificationName:SBPlayerPlayStateNotification object:self];
}


- (void)playPause {
    bool wasPlaying = self.isPlaying;
    if((remotePlayer != nil) && ([remotePlayer rate] != 0)) {
        [remotePlayer pause];
        self.isPaused = YES;
    } else {
        [remotePlayer play];
        self.isPaused = NO;
    }
    if(LOCAL_PLAYER && [LOCAL_PLAYER engineIsRunning]) {
        NSError *error;
        [LOCAL_PLAYER togglePlayPauseReturningError:&error];
        self.isPaused = [LOCAL_PLAYER isPaused];
    }
    // if we weren't playing, we need to update the metadata
    if (wasPlaying) {
        [self updateSystemNowPlayingStatus];
    } else {
        [self updateSystemNowPlaying];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:SBPlayerPlayStateNotification object:self];
}

- (void)next {
    SBTrack *next = [self nextTrack];
    if(next != nil) {
        @synchronized(self) {
            [self playTrack:next];
        }
    } else {
        [self stop];
    }
}

- (void)previous {
    SBTrack *prev = [self prevTrack];
    if(prev != nil) {
        @synchronized(self) {
            //[self stop];
            [self playTrack:prev];
        }
    }
}


- (void)setVolume:(float)volume {
    
    [[NSUserDefaults standardUserDefaults] setFloat:volume forKey:@"playerVolume"];
    
    if(remotePlayer)
        [remotePlayer setVolume:volume];
    
    NSError *error = nil;
    [LOCAL_PLAYER setVolume:volume error:&error];
}

- (void)seekToTime:(NSTimeInterval)time {
    if(remotePlayer != nil) {
        CMTime timeCM = CMTimeMakeWithSeconds(time, NSEC_PER_SEC);
        [remotePlayer seekToTime:timeCM];
    }
    
    if(LOCAL_PLAYER && [LOCAL_PLAYER isPlaying]) {
        if([LOCAL_PLAYER supportsSeeking]) {
            [LOCAL_PLAYER seekToTime: time];
        } else {
            NSLog(@"WARNING : no seek support for this file");
        }
    }
    
    if(isCaching) {
        isCaching = NO;
    }
    
    // seeks will desync the NPIC
    [self updateSystemNowPlayingStatus];
}

// This is relative (0..100) it seems
- (void)seek:(double)time {
    if(remotePlayer != nil) {
        AVPlayerItem *currentItem = [remotePlayer currentItem];
        CMTime durationCM = [currentItem duration];
        CMTime newTime = CMTimeMultiplyByFloat64(durationCM, (time / 100.0));
        [remotePlayer seekToTime:newTime];
    }
    
    if(LOCAL_PLAYER && [LOCAL_PLAYER isPlaying]) {
        if([LOCAL_PLAYER supportsSeeking]) {
            SFBAudioPlayerPlaybackPosition sfbPos;
            SFBAudioPlayerPlaybackTime sfbTime;
            [LOCAL_PLAYER getPlaybackPosition:&sfbPos andTime:&sfbTime];
            NSTimeInterval newTime = sfbTime.totalTime * (time / 100.0);
            [LOCAL_PLAYER seekToTime:newTime];
        } else {
            NSLog(@"WARNING : no seek support for this file");
        }
    }
    
    if(isCaching) {
        isCaching = NO;
    }
    
    // seeks will desync the NPIC
    [self updateSystemNowPlayingStatus];
}


- (void)stop {

    @synchronized(self) {
        // stop players
        if(remotePlayer) {
            [remotePlayer replaceCurrentItemWithPlayerItem:nil];
            [remotePlayer release];
            remotePlayer = nil;
        }
        
        if([LOCAL_PLAYER isPlaying]) {
            [LOCAL_PLAYER stop];
            [LOCAL_PLAYER clearQueue];
        }
        
        // unplay current track
        [self.currentTrack setIsPlaying:[NSNumber numberWithBool:NO]];
        self.currentTrack  = nil;
        
        // unplay all
        [self unplayAllTracks];
        
        // stop player !
        self.isPlaying = NO;
        self.isPaused = YES; // for sure
        
        // update NPIC
        [self updateSystemNowPlaying];
        [[NSNotificationCenter defaultCenter] postNotificationName:SBPlayerPlayStateNotification object:self];
        [[NSNotificationCenter defaultCenter] postNotificationName:SBPlayerPlaylistUpdatedNotification object:self];
	}
}


- (void)clear {
    //[self stop];
    [self.playlist removeAllObjects];
    [self setCurrentTrack:nil];
}


#pragma mark -
#pragma mark Accessors (Player Properties)

- (NSTimeInterval)currentTime {
    
    if(remotePlayer != nil)
    {
        CMTime currentTimeCM = [remotePlayer currentTime];
        NSTimeInterval currentTime = CMTimeGetSeconds(currentTimeCM);
        return currentTime;
    }
    
    if([LOCAL_PLAYER isPlaying])
    {
        SFBAudioPlayerPlaybackPosition sfbPos;
        SFBAudioPlayerPlaybackTime sfbTime;
        [LOCAL_PLAYER getPlaybackPosition:&sfbPos andTime:&sfbTime];
        return sfbTime.currentTime;
    }
    
    return 0;
}


- (NSString *)currentTimeString {
    return [NSString stringWithTime: [self currentTime]];
}

- (NSTimeInterval)durationTime
{
    if(remotePlayer != nil)
    {
        AVPlayerItem *currentItem = [remotePlayer currentItem];
        CMTime durationCM = [currentItem duration];
        NSTimeInterval duration = CMTimeGetSeconds(durationCM);
        return duration;
    }
    
    if([LOCAL_PLAYER isPlaying])
    {
        SFBAudioPlayerPlaybackPosition sfbPos;
        SFBAudioPlayerPlaybackTime sfbTime;
        [LOCAL_PLAYER getPlaybackPosition:&sfbPos andTime:&sfbTime];
        return sfbTime.totalTime;
    }
    
    return 0;
}

- (NSTimeInterval)remainingTime
{
    if(remotePlayer != nil)
    {
        AVPlayerItem *currentItem = [remotePlayer currentItem];
        CMTime durationCM = [currentItem duration];
        CMTime currentTimeCM = [currentItem currentTime];
        NSTimeInterval duration = CMTimeGetSeconds(durationCM);
        NSTimeInterval currentTime = CMTimeGetSeconds(currentTimeCM);
        NSTimeInterval remainingTime = duration-currentTime;
        return remainingTime;
    }
    
    if([LOCAL_PLAYER isPlaying])
    {
        SFBAudioPlayerPlaybackPosition sfbPos;
        SFBAudioPlayerPlaybackTime sfbTime;
        [LOCAL_PLAYER getPlaybackPosition:&sfbPos andTime:&sfbTime];
        return sfbTime.totalTime - sfbTime.currentTime;
    }
    
    return 0;
}

- (NSString *)remainingTimeString {
    return [NSString stringWithTime: [self remainingTime]];
}

- (double)progress {
    if(remotePlayer != nil)
    {
        // typedef struct { long long timeValue; long timeScale; long flags; } QTTime
        AVPlayerItem *currentItem = [remotePlayer currentItem];
        CMTime durationCM = [currentItem duration];
        CMTime currentTimeCM = [currentItem currentTime];
        NSTimeInterval duration = CMTimeGetSeconds(durationCM);
        NSTimeInterval currentTime = CMTimeGetSeconds(currentTimeCM);
        
        if(duration > 0) {
            double progress = ((double)currentTime) / ((double)duration) * 100; // make percent
            //double bitrate = [[[remotePlayer movieAttributes] valueForKey:QTMovieDataSizeAttribute] doubleValue]/duration * 10;
            //NSLog(@"bitrate : %f", bitrate);
            
            if(progress == 100) { // movie is at end
                [self next];
            }
            
            return progress;
            
        } else {
            return 0;
        }
    }
    
    if([LOCAL_PLAYER isPlaying])
    {
        SFBAudioPlayerPlaybackPosition sfbPos;
        SFBAudioPlayerPlaybackTime sfbTime;
        [LOCAL_PLAYER getPlaybackPosition:&sfbPos andTime:&sfbTime];
        if(sfbTime.totalTime > 0) {
            double progress = ((double)sfbTime.currentTime) / ((double)sfbTime.totalTime) * 100; // make percent
            //double bitrate = [[[remotePlayer movieAttributes] valueForKey:QTMovieDataSizeAttribute] doubleValue]/duration * 10;
            //NSLog(@"bitrate : %f", bitrate);
            
            if(progress == 100) { // movie is at end
                [self next];
            }
            
            return progress;
            
        } else {
            return 0;
        }
    }
    
    return 0;
}


- (float)volume {
    return [[NSUserDefaults standardUserDefaults] floatForKey:@"playerVolume"];
}

- (double)percentLoaded {
    double percentLoaded = 0;

    if(remotePlayer != nil) {
        AVPlayerItem *currentItem = [remotePlayer currentItem];
        CMTime durationCM = [currentItem duration];
        NSTimeInterval tMaxLoaded;
        NSArray *ranges = [currentItem loadedTimeRanges];
        if ([ranges count] > 0) {
            CMTimeRange range = [[ranges firstObject] CMTimeRangeValue];
            tMaxLoaded = CMTimeGetSeconds(range.duration) - CMTimeGetSeconds(range.start);
        } else {
            tMaxLoaded = 0;
        }
        NSTimeInterval tDuration = CMTimeGetSeconds(durationCM);
        
        percentLoaded = (double) tMaxLoaded/tDuration;
    }
    
    if([LOCAL_PLAYER isPlaying]) {
        percentLoaded = 1;
    }
    
    return percentLoaded;
}


- (SBPlayerRepeatMode)repeatMode {
    return (SBPlayerRepeatMode)[[NSUserDefaults standardUserDefaults] integerForKey:@"repeatMode"];
}

- (void)setRepeatMode:(SBPlayerRepeatMode)newRepeatMode {
    [[NSUserDefaults standardUserDefaults] setInteger:newRepeatMode forKey:@"repeatMode"];
    repeatMode = newRepeatMode;
}




#pragma mark -
#pragma mark Remote Player Notification 

- (NSString*)extensionForContentType: (NSString*)contentType {
    CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)contentType, NULL);
    CFStringRef extension = UTTypeCopyPreferredTagWithClass(fileUTI, kUTTagClassFilenameExtension);
    CFRelease(fileUTI);
    return (__bridge NSString*)extension;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == remotePlayer && [keyPath isEqualToString:@"status"]) {
        if ([remotePlayer status] == AVPlayerStatusFailed) {
            NSLog(@"AVPlayer Failed: %@", [remotePlayer error]);
            [self stop];
        } else if ([remotePlayer status] == AVPlayerStatusReadyToPlay) {
            NSLog(@"AVPlayerStatusReadyToPlay");
            [remotePlayer play];
        } else if ([remotePlayer status] == AVPlayerItemStatusUnknown) {
            NSLog(@"AVPlayer Unknown");
            [self stop];
        }
    }
    
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableCacheStreaming"] == YES)
    {
        // AVAssetExportSession doesn't work on remote files, download the stream ourself
        // XXX: Should we use the transcode type? The download URL?
        NSString *contentType = [self currentTrack].contentType;
        NSString *extension = [self extensionForContentType: contentType];
        // create a cache temp file
        NSURL *tempFileURL = [NSURL temporaryFileURL];
        if (tmpLocation) {
            [tmpLocation release];
        }
        // XXX: Should have in this scope?
        tmpLocation = [[[tempFileURL absoluteString] stringByAppendingPathExtension: extension] retain];
        // XXX: Move to the ClientController?
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: [self currentTrack].streamURL];
        // XXX: Seems Navidrome at least doesn't care, but prob sketch
//        NSString *loginString = [NSString stringWithFormat: @"%@:%@", server.username, server.password];
//        NSData *loginData = [loginString dataUsingEncoding: NSUTF8StringEncoding];
//        NSString *base64login = [loginData base64EncodedStringWithOptions: 0];
//        NSString *authHeader = [NSString stringWithFormat: @"Basic %@", base64login];
//        configuration.HTTPAdditionalHeaders = @{@"Authorization": authHeader};
        NSURLSessionDataTask *httpTask = [session dataTaskWithRequest: request completionHandler:
                ^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error != nil) {
                NSLog(@"Error in import stream: %@", error);
                [NSApp presentError: error];
                return;
            }
            if (response == nil) {
                NSLog(@"No response in import stream");
                return;
            }
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
            NSInteger statusCode = [httpResponse statusCode];
            NSLog(@"Status code is %ld", (long)statusCode);
            if (statusCode!= 200) {
                return;
            }
            // write the data to the temp file, then go for it
            if ([[NSFileManager defaultManager] createFileAtPath: tmpLocation contents: data attributes: nil] == NO) {
                NSLog(@"Failed to write import file %@", tmpLocation);
                return;
            }
            // unsure if we can write, but we're def caching
            isCaching = YES;
            NSManagedObjectContext *moc = self.currentTrack.managedObjectContext;
            SBLibrary *library = [moc fetchEntityNammed:@"Library" withPredicate:nil error:nil];
            
            // import audio file
            SBImportOperation *op = [[SBImportOperation alloc] initWithManagedObjectContext:moc];
            [op setFilePaths:[NSArray arrayWithObject:tmpLocation]];
            [op setLibraryID:[library objectID]];
            [op setRemoteTrackID:[self.currentTrack objectID]];
            [op setCopy:YES];
            [op setRemove:YES];
            
            [[NSOperationQueue sharedDownloadQueue] addOperation:op];
            
        }];
        [httpTask resume];
    }
}

-(void)itemDidFinishPlaying:(NSNotification *) notification {
    [self next];
}

#pragma mark -
#pragma mark Local Player Delegate

- (void) audioPlayer:(SFBAudioPlayer *)audioPlayer decodingStarted:(id<SFBPCMDecoding>)decoder
{
    #pragma unused(decoder)
    NSError *error = nil;
    [LOCAL_PLAYER playReturningError:&error];
}

// This is called from the realtime rendering thread and as such MUST NOT BLOCK!!
- (void) audioPlayer:(SFBAudioPlayer *)audioPlayer decodingComplete:(id<SFBPCMDecoding>)decoder
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self next];
        // needed to make it continue?
        [self playOrResume];
    });
}

#pragma mark -
#pragma mark Private


- (SBTrack *)getRandomTrackExceptingTrack:(SBTrack *)_track {
	
	SBTrack *randomTrack = _track;
	NSArray *sortedTracks = [self playlist];
	
	if([sortedTracks count] > 1) {
		while ([randomTrack isEqualTo:_track]) {
			NSInteger numberOfTracks = [sortedTracks count];
			NSInteger randomIndex = random() % numberOfTracks;
			randomTrack = [sortedTracks objectAtIndex:randomIndex];
		}
	} else {
		randomTrack = nil;
	}
	
	return randomTrack;
}


- (SBTrack *)nextTrack {
    
    if(self.playlist) {
        if(!isShuffle) {
            NSInteger index = [self.playlist indexOfObject:self.currentTrack];
            
            if(repeatMode == SBPlayerRepeatNo) {
                
                // no repeat, play next
                if(index > -1 && [self.playlist count]-1 >= index+1) {
                    return [self.playlist objectAtIndex:index+1];
                }
            }
                
            // if repeat one, esay to relaunch the track
            if(repeatMode == SBPlayerRepeatOne)
                return self.currentTrack;
            
            // if repeat all, broken...
             if(repeatMode == SBPlayerRepeatAll)
                 if([self.currentTrack isEqualTo:[self.playlist lastObject]] && index > 0)
                     return [self.playlist objectAtIndex:0];
				else
					if(index > -1 && [self.playlist count]-1 >= index+1) {
						return [self.playlist objectAtIndex:index+1];
					}
            
        } else {
            // if repeat one, get the piority
            if(repeatMode == SBPlayerRepeatOne)
                return self.currentTrack;
            
            // else play random
            return [self getRandomTrackExceptingTrack:self.currentTrack];
        }
    }
    return nil;
}


- (SBTrack *)prevTrack {
    if(self.playlist) {
        if(!isShuffle) {
            NSInteger index = [self.playlist indexOfObject:self.currentTrack];   
            
            if(repeatMode == SBPlayerRepeatOne)
                return self.currentTrack;
            
            if(index == 0)
                if(repeatMode == SBPlayerRepeatAll)
                    return [self.playlist lastObject];
                        if(index != -1)
                return [self.playlist objectAtIndex:index-1];
        } else {
            // if repeat one, get the piority
            if(repeatMode == SBPlayerRepeatOne)

                return self.currentTrack;
            
            return [self getRandomTrackExceptingTrack:self.currentTrack];
        }
    }
    return nil;
}

- (void)unplayAllTracks {

    NSError *error = nil;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(isPlaying == YES)"];
    NSArray *tracks = [[self.currentTrack managedObjectContext] fetchEntitiesNammed:@"Track" withPredicate:predicate error:&error];
    
    for(SBTrack *track in tracks) {
        [track setIsPlaying:[NSNumber numberWithBool:NO]];
    }
}


- (void)showVideoAlert {
    NSAlert *alert = [NSAlert alertWithMessageText:@"Video streaming" 
                                     defaultButton:@"OK" 
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:@"This file appears to be a video file. Submariner is not able to streaming movie yet."];
    
    [alert runModal];
}



@end
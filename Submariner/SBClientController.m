//
//  SBClient.m
//  Sub
//
//  Created by nark on 14/05/11.
//  Copyright 2011 OPALE. All rights reserved.
//

#import "SBClientController.h"
#import "SBSubsonicParsingOperation.h"
#import "SBServer.h"
#import "SBResource.h"
#import "SBHome.h"
#import "SBSection.h"
#import "SBLibrary.h"
#import "SBGroup.h"
#import "SBTrack.h"
#import "SBPlaylist.h"
#import "SBArtist.h"
#import "SBAlbum.h"
#import "SBCover.h"
#import "SBSearchResult.h"

#import "NSManagedObjectContext+Fetch.h"
#import "NSURL+Parameters.h"
#import "NSString+Hex.h"
#import "NSOperationQueue+Shared.h"
#import <LRResty/LRResty.h>


@interface SBClientController (Private)
- (void)initServerResources;
- (void)unplayAllTracks;
- (void)requestWithURL:(NSURL *)url requestType:(SBSubsonicRequestType)type;
@end



@implementation SBClientController


@synthesize managedObjectContext;
@synthesize delegate;
@synthesize connected;
@synthesize server;
@synthesize librarySection;
@synthesize remotePlaylistsSection;
@synthesize podcastsSection;
@synthesize radiosSection;
@synthesize searchsSection;
@synthesize home;
@synthesize library;
@synthesize isConnecting;
@synthesize queue;


#pragma mark -
#pragma mark LifeCycle

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context
{
    self = [super init];
    if (self) {
        parameters = [[NSMutableDictionary alloc] init];
        queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount:1];
        managedObjectContext = [context retain];
        connected = NO;
        isConnecting = NO;
        numberOfElements = 0;

    }
    
    return self;
}

- (void)dealloc {
    
    [managedObjectContext release];
    [queue release];
    [server release];
    [librarySection release];
    [podcastsSection release];
    [radiosSection release];
    [home release];
    [library release];
    [parameters release];
    
    [super dealloc];
}





#pragma mark -
#pragma mark Private


- (void)initServerResources {
    NSError *error = nil;
    NSArray *entities = nil;
    NSPredicate *predicate = nil;
    

    // check server sections
    predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@) && (server == %@)", @"MUSIC", server];
    entities = [self.managedObjectContext fetchEntitiesNammed:@"Section" withPredicate:predicate error:&error];
    if(entities && [entities count] > 0) {
        librarySection = [[entities objectAtIndex:0] retain];
    }
    
    predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@) && (server == %@)", @"PLAYLISTS", server];
    entities = [self.managedObjectContext fetchEntitiesNammed:@"Section" withPredicate:predicate error:&error];
    if(entities && [entities count] > 0) {
        remotePlaylistsSection = [[entities objectAtIndex:0] retain];
    }
    
    predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@) && (server == %@)", @"SEARCHS", server];
    entities = [self.managedObjectContext fetchEntitiesNammed:@"Section" withPredicate:predicate error:&error];
    if(entities && [entities count] > 0) {
        searchsSection = [[entities objectAtIndex:0] retain];
    }
    
    // check default resources
    predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@) && (server == %@)", @"Library", server];
    entities = [self.managedObjectContext fetchEntitiesNammed:@"Library" withPredicate:predicate error:&error];
    if(entities && [entities count] > 0) {
        library = [[entities objectAtIndex:0] retain];
    }
    
    predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@) && (server == %@)", @"Home", server];
    entities = [self.managedObjectContext fetchEntitiesNammed:@"Home" withPredicate:predicate error:&error];
    if(entities && [entities count] > 0) {
        home = [[entities objectAtIndex:0] retain];
    }

}




- (void)unplayAllTracks {
    NSError *error = nil;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(isPlaying == YES)"];
    NSArray *tracks = [self.managedObjectContext fetchEntitiesNammed:@"Track" withPredicate:predicate error:&error];
    
    for(SBTrack *track in tracks) {
        [track setIsPlaying:[NSNumber numberWithBool:NO]];
    }
}




- (void)requestWithURL:(NSURL *)url requestType:(SBSubsonicRequestType)type {

    [[LRResty authenticatedClientWithUsername:server.username password:server.password] get:[url absoluteString] withBlock:^(LRRestyResponse *response) {
        
        if(!response) {
            NSLog(@"no response !");
        }
        
        if (response.status == 200) {
            SBSubsonicParsingOperation *operation = [[SBSubsonicParsingOperation alloc] initWithManagedObjectContext:self.managedObjectContext
                                                                                                              client:self
                                                                                                         requestType:type
                                                                                                              server:[self.server objectID]
                                                                                                                 xml:[response responseData]];
            
            [[NSOperationQueue sharedServerQueue] addOperation:operation];
            [operation release];
        } else if (response.status >= 400 && response.status < 504) {

            // error ?
            NSError *error = nil;
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            
            switch (response.status) {
                case 400: [userInfo setValue:@"Bad request" forKey:NSLocalizedDescriptionKey];
                    break;
                case 401: [userInfo setValue:@"Unauthorized" forKey:NSLocalizedDescriptionKey];
                    break;
                case 402: [userInfo setValue:@"Payment Required" forKey:NSLocalizedDescriptionKey];
                    break;
                case 403: [userInfo setValue:@"Forbidden" forKey:NSLocalizedDescriptionKey];
                    break;
                case 404: [userInfo setValue:@"Not Found" forKey:NSLocalizedDescriptionKey];
                    break;
                case 500: [userInfo setValue:@"Internal Error" forKey:NSLocalizedDescriptionKey];
                    break;
                case 501: [userInfo setValue:@"Not Implemented" forKey:NSLocalizedDescriptionKey];
                    break;
                case 502: [userInfo setValue:@"Service temporarily overloaded" forKey:NSLocalizedDescriptionKey];
                    break;
                case 503: [userInfo setValue:@"Gateway timeout" forKey:NSLocalizedDescriptionKey];
                    break;
                default: [userInfo setValue:@"Bad request" forKey:NSLocalizedDescriptionKey];
                    break;
            }
            
            error = [NSError errorWithDomain:NSPOSIXErrorDomain code:response.status userInfo:userInfo];
            [NSApp presentError:error];
        } else {
            NSLog(@"status : %ld", response.status);
        }
    }];
}





#pragma mark -
#pragma mark Request Messages

- (void)connectToServer:(SBServer *)aServer {
    // setup parameters
    [parameters setValue:server.username forKey:@"u"];
    [parameters setValue:[@"enc:" stringByAppendingString:[NSString stringToHex:server.password]] forKey:@"p"];
    [parameters setValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"apiVersion"] forKey:@"v"];
    [parameters setValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"clientIdentifier"] forKey:@"c"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/ping.view" parameters:parameters];
    [self requestWithURL:url requestType:SBSubsonicRequestPing];
}

- (void)getLicense {
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getLicense.view" parameters:parameters];
    [self requestWithURL:url requestType:SBSubsonicRequestGetLicense];
}


- (void)getIndexes {
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getIndexes.view" parameters:parameters];
    [self requestWithURL:url requestType:SBSubsonicRequestGetIndexes];
}

- (void)getIndexesSince:(NSDate *)date {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:[NSString stringWithFormat:@"%00.f", [date timeIntervalSince1970]] forKey:@"ifModifiedSince"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getIndexes.view" parameters:params];
    [self requestWithURL:url requestType:SBSubsonicRequestGetIndexes];
}


- (void)getAlbumsForArtist:(SBArtist *)artist {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:artist.id forKey:@"id"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getMusicDirectory.view" parameters:params];
    [self requestWithURL:url requestType:SBSubsonicRequestGetAlbumDirectory];
}


- (void)getAlbumsForArtistWithID:(SBArtistID *)artistID {
    
}


- (void)getCoverWithID:(NSString *)coverID {
    
    if(![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(getCoverWithID:) withObject:coverID waitUntilDone:YES];
        return;
    }

    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:coverID forKey:@"id"];
     [params setValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"MaxCoverSize"] forKey:@"size"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getCoverArt.view" parameters:params];
    
    [[LRResty authenticatedClientWithUsername:server.username password:server.password] get:[url absoluteString] withBlock:^(LRRestyResponse *response) {
                
        if (response.status == 200) { // special status for binary data
            SBSubsonicParsingOperation *operation = [[SBSubsonicParsingOperation alloc] initWithManagedObjectContext:self.managedObjectContext
                                                                                                              client:self
                                                                                                         requestType:SBSubsonicRequestGetCoverArt
                                                                                                              server:[self.server objectID]
                                                                                                                 xml:[response responseData]];
            [operation setCurrentCoverID:coverID];
            [[NSOperationQueue sharedServerQueue] addOperation:operation];
            //[operation main];
            [operation release];
        }
    }];
}


- (void)getTracksForAlbumID:(NSString *)albumID {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:albumID forKey:@"id"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getMusicDirectory.view" parameters:params];
    [self requestWithURL:url requestType:SBSubsonicRequestGetTrackDirectory];
}


- (void)getPlaylists {
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getPlaylists.view" parameters:parameters];
    [self requestWithURL:url requestType:SBSubsonicRequestGetPlaylists];
}

- (void)getPlaylist:(SBPlaylist *)playlist {
    
    // setup parameters
    [parameters setValue:server.username forKey:@"u"];
    [parameters setValue:[@"enc:" stringByAppendingString:[NSString stringToHex:server.password]] forKey:@"p"];
    [parameters setValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"apiVersion"] forKey:@"v"];
    [parameters setValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"clientIdentifier"] forKey:@"c"];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:playlist.id forKey:@"id"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getPlaylist.view" parameters:params];
    [self requestWithURL:url requestType:SBSubsonicRequestGetPlaylist];
}


- (void)getPodcasts {
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getPodcasts.view" parameters:parameters];
    [self requestWithURL:url requestType:SBSubsonicRequestGetPodcasts];
}


- (void)deletePlaylistWithID:(NSString *)playlistID {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:playlistID forKey:@"id"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/deletePlaylist.view" parameters:params];
    [self requestWithURL:url requestType:SBSubsonicRequestDeletePlaylist];
    
}

- (void)createPlaylistWithName:(NSString *)playlistName tracks:(NSArray *)tracks {
    // required parameters
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:playlistName forKey:@"name"];
    
    // compute params string (because obviously, dictionary doesn't support set of multiple same key)
    NSMutableString *paramString = [NSMutableString string];
    for (NSString *trackID in tracks) {
        [paramString appendFormat:@"&songId=%@", trackID];
    }
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/createPlaylist.view" parameters:params andParameterString:paramString];
    //NSLog(@"url : %@", url);
    [self requestWithURL:url requestType:SBSubsonicRequestCreatePlaylist];
}


- (void)updatePlaylistWithID:(NSString *)playlistID tracks:(NSArray *)tracks {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:playlistID forKey:@"playlistId"];
    
    // compute params string (because obviously, dictionary doesn't support set of multiple same key)
    NSMutableString *paramString = [NSMutableString string];
    for (NSString *trackID in tracks) {
        [paramString appendFormat:@"&songId=%@", trackID];
    }
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/createPlaylist.view" parameters:params andParameterString:paramString];
    [self requestWithURL:url requestType:SBSubsonicRequestCreatePlaylist];
}


- (void)getAlbumListForType:(SBSubsonicRequestType)type {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    if(type == SBSubsonicRequestGetAlbumListRandom) {
        [params setValue:@"random" forKey:@"type"];
        
    } else if(type == SBSubsonicRequestGetAlbumListNewest) {
        [params setValue:@"newest" forKey:@"type"];
        
    } else if(type == SBSubsonicRequestGetAlbumListFrequent) {
        [params setValue:@"frequent" forKey:@"type"];
        
    } else if(type == SBSubsonicRequestGetAlbumListHighest) {
        [params setValue:@"highest" forKey:@"type"];
        
    } else if(type == SBSubsonicRequestGetAlbumListRecent) {
        [params setValue:@"recent" forKey:@"type"];
    }
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getAlbumList.view" parameters:params];
    [self requestWithURL:url requestType:type];
}

- (void)getChatMessagesSince:(NSDate *)date {    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:[NSString stringWithFormat:@"%00.f", [date timeIntervalSince1970]] forKey:@"since"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getChatMessages.view" parameters:params];
    [self requestWithURL:url requestType:SBSubsonicRequestGetChatMessages];    
}


- (void)addChatMessage:(NSString *)message {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:message forKey:@"message"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/addChatMessage.view" parameters:params];
    [self requestWithURL:url requestType:SBSubsonicRequestAddChatMessage];  
}


- (void)getNowPlaying {
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getNowPlaying.view" parameters:parameters];
    [self requestWithURL:url requestType:SBSubsonicRequestGetNowPlaying];   
}


- (void)getUserWithName:(NSString *)username {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:username forKey:@"username"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getUser.view" parameters:params];
    [self requestWithURL:url requestType:SBSubsonicRequestGetUser];  
}


- (void)search:(NSString *)query {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:query forKey:@"query"];
    [params setValue:@"100" forKey:@"songCount"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/search2.view" parameters:params];
    SBSearchResult *searchResult = [[[SBSearchResult alloc] initWithQuery:query] autorelease];
    
    [[LRResty authenticatedClientWithUsername:server.username password:server.password] get:[url absoluteString] withBlock:^(LRRestyResponse *response) {
        
        if (response.status == 200) { // special status for binary data
            SBSubsonicParsingOperation *operation = [[SBSubsonicParsingOperation alloc] initWithManagedObjectContext:self.managedObjectContext
                                                                                                              client:self
                                                                                                         requestType:SBSubsonicRequestSearch
                                                                                                              server:[self.server objectID]
                                                                                                                 xml:[response responseData]];
            [operation setCurrentSearch:searchResult];
            [[NSOperationQueue sharedServerQueue] addOperation:operation];
            //[operation main];
            [operation release];
        }
    }];
}


- (void)setRating:(NSInteger)rating forID:(NSString *)anID {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:[NSString stringWithFormat:@"%ld", rating] forKey:@"rating"];
    [params setValue:anID forKey:@"id"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/setRating.view " parameters:params];
    [self requestWithURL:url requestType:SBSubsonicRequestSetRating];  
}



@end

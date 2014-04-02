//
//  SBPodcastItemView.m
//  Submariner
//
//  Created by Rafaël Warnault on 24/08/11.
//  Copyright 2011 Read-Write.fr. All rights reserved.
//

#import "SBPodcastItemView.h"

@implementation SBPodcastItemView

@synthesize selected;

- (void)drawRect:(NSRect)dirtyRect 
{
    if (self.selected) {
        [[NSColor colorWithDeviceWhite:0.8 alpha:1.0] set];
        NSRectFill([self bounds]);
    }
}

@end

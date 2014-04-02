//
//  DXControlBarView.m
//  Submariner
//
//  Created by Rafaël Warnault on 22/03/11.
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
#import "SBControlBarView.h"


@implementation SBControlBarView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)awakeFromNib {
    [self setWantsLayer:YES];
}

- (void)dealloc
{
    [super dealloc];
}

- (void)drawRect:(NSRect)dirtyRect
{	    
    NSRect bottomRect = NSMakeRect(dirtyRect.origin.x, dirtyRect.origin.y, dirtyRect.size.width, 0.5);
    [[NSColor lightGrayColor] setStroke];
    
    // Draw gradient background.
	NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.75 alpha:1.0] 
														  endingColor:[NSColor colorWithCalibratedWhite:0.85 alpha:1.0]] autorelease];
	[gradient drawInRect:[self bounds] angle:90.0];

    // draw bottom path
    NSBezierPath *bottomPath = [NSBezierPath bezierPathWithRect:bottomRect];
    [bottomPath stroke];
    
    NSRect toplinetRect = NSMakeRect(0.0, NSMaxY(dirtyRect)-1, NSWidth(dirtyRect), 1.0);
    [[NSColor grayColor] setFill];
    NSRectFill(toplinetRect);
    
    NSRect highlightRect = NSMakeRect(0.0, NSMaxY(dirtyRect)-2, NSWidth(dirtyRect), 1.0);
    [[NSColor colorWithDeviceWhite:0.9 alpha:1.0] setFill];
    NSRectFill(highlightRect);
}

@end

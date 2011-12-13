//
//  NSImage+Additions.m
//  Submariner
//
//  Created by Rafaël Warnault on 11/12/11.
//  Copyright (c) 2011 OPALE. All rights reserved.
//

#import "NSImage+Additions.h"
#import <Quartz/Quartz.h>


@implementation NSImage (Additions)

- (NSImage *)imageTintedWithColor:(NSColor *)tint 
{
    NSSize size = [self size];
    NSRect imageBounds = NSMakeRect(0, 0, size.width, size.height);
    
    NSImage *copiedImage = [self copy];
    
    [copiedImage lockFocus];
    
    [tint set];
    NSRectFillUsingOperation(imageBounds, NSCompositeSourceAtop);
    
    [copiedImage unlockFocus];
    
    return [copiedImage autorelease];
    
//    if (tint != nil) {
//        NSSize size = [self size];
//        NSRect bounds = { NSZeroPoint, size };
//        NSImage *tintedImage = [[NSImage alloc] initWithSize:size];
//        
//        [tintedImage lockFocus];
//        
//        CIFilter *colorGenerator = [CIFilter filterWithName:@"CIConstantColorGenerator"];
//        CIColor *color = [[[CIColor alloc] initWithColor:tint] autorelease];
//        
//        [colorGenerator setValue:color forKey:@"inputColor"];
//        
//        CIFilter *monochromeFilter = [CIFilter filterWithName:@"CIColorMonochrome"];
//        CIImage *baseImage = [CIImage imageWithData:[self TIFFRepresentation]];
//        
//        [monochromeFilter setValue:baseImage forKey:@"inputImage"];             
//        [monochromeFilter setValue:[CIColor colorWithRed:0.75 green:0.75 blue:0.75] forKey:@"inputColor"];
//        [monochromeFilter setValue:[NSNumber numberWithFloat:1.0] forKey:@"inputIntensity"];
//        
//        CIFilter *compositingFilter = [CIFilter filterWithName:@"CIMultiplyCompositing"];
//        
//        [compositingFilter setValue:[colorGenerator valueForKey:@"outputImage"] forKey:@"inputImage"];
//        [compositingFilter setValue:[monochromeFilter valueForKey:@"outputImage"] forKey:@"inputBackgroundImage"];
//        
//        CIImage *outputImage = [compositingFilter valueForKey:@"outputImage"];
//        
//        [outputImage drawAtPoint:NSZeroPoint
//						fromRect:bounds
//					   operation:NSCompositeCopy
//						fraction:1.0];
//        
//        [tintedImage unlockFocus];  
//        
//        return [tintedImage autorelease];
//    }
//    else {
//        return [[self copy] autorelease];
//    }
}

- (NSImage*)imageCroppedToRect:(NSRect)rect
{
    NSPoint point = { -rect.origin.x, -rect.origin.y };
    NSImage *croppedImage = [[NSImage alloc] initWithSize:rect.size];
    
    [croppedImage lockFocus];
    {
        [self compositeToPoint:point operation:NSCompositeCopy];
    }
    [croppedImage unlockFocus];
    
    return [croppedImage autorelease];
}

@end

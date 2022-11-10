//
//  SBAlbumsCollectionViewItem.m
//  Submariner
//
//  Created by JaxWu on 2022/11/10.
//  Copyright © 2022 OPALE. All rights reserved.
//

#import "SBAlbumsCollectionViewItem.h"
#import "SBAlbum.h"
#import "SBCover.h"

@interface SBAlbumsCollectionViewItem ()

@property (weak, nonatomic) IBOutlet NSImageView *coverImageView;
@property (weak, nonatomic) IBOutlet NSTextField *titleLabel;

@end

@implementation SBAlbumsCollectionViewItem

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (void)updateViewItem:(SBAlbum *)album {
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:album.cover.imagePath];
    if (image) {
        [self.coverImageView setImage:image];
    }
    self.titleLabel.stringValue = album.itemName;
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    
    if (!self.isSelected) {
        self.view.layer = nil;
    } else {
        CALayer *selectionLayer = [CALayer layer];
        selectionLayer.frame = CGRectMake(0, 0, self.view.frame.size.width,  self.view.frame.size.height);
        
        //set a background color
        CGColorRef color = [[NSColor selectedContentBackgroundColor] CGColor];
        [selectionLayer setBackgroundColor:color];
        
        //set a border color
        [selectionLayer setBorderColor:color];

        [selectionLayer setBorderWidth:1.0];
        [selectionLayer setCornerRadius:5];
        self.view.layer = selectionLayer;
    }
}

- (void)mouseDown:(NSEvent *)event {
    if (event.clickCount == 2 && self.doubleClickAction) {
        self.doubleClickAction();
        return;
    }
    [super mouseDown:event];
}

@end

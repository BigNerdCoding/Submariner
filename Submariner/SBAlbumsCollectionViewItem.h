//
//  SBAlbumsCollectionViewItem.h
//  Submariner
//
//  Created by JaxWu on 2022/11/10.
//  Copyright © 2022 OPALE. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SBAlbum;
NS_ASSUME_NONNULL_BEGIN

@interface SBAlbumsCollectionViewItem : NSCollectionViewItem

@property (nonatomic, copy) void (^doubleClickAction)(void);

- (void)updateViewItem:(SBAlbum *)album;

@end

NS_ASSUME_NONNULL_END

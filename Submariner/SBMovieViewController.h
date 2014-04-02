//
//  SBMovieViewController.h
//  Submariner
//
//  Created by Rafaël Warnault on 10/12/11.
//  Copyright (c) 2011 Read-Write.fr. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>
#import "SBViewController.h"

@interface SBMovieViewController : SBViewController {
    QTMovie *movie;
    IBOutlet QTMovieView *movieView;
}

@property (nonatomic, retain) QTMovie *movie;

@end

//
//  SBTableView.m
//  Sub
//
//  Created by nark on 25/05/11.
//  Copyright 2011 OPALE. All rights reserved.
//

#import "SBTableView.h"
#import "RWTableHeaderCell.h"
#import "RWCornerView.h"


NSString *SBDeleteKeyPressedOnRowsNotification = @"SBDeleteKeyPressedOnRowsNotification";
NSString *SBEnterKeyPressedOnRowsNotification = @"SBEnterKeyPressedOnRowsNotification";


@implementation NSColor (ColorChangingFun)

+(NSArray*)controlAlternatingRowBackgroundColors
{
    return [NSArray arrayWithObjects:[NSColor colorWithDeviceWhite:0.95 alpha:1.0], [NSColor whiteColor], nil];
}

@end



@interface SBTableView (Notifications)

- (void)deleteKeyPressedOnRowsNotification:(NSNotification *)notification;
- (void)enterKeyPressedOnRowsNotification:(NSNotification *)notification;

@end





@implementation SBTableView

- (void)_setupHeaderCell
{
	for (NSTableColumn* column in [self tableColumns]) {
		NSTableHeaderCell* cell = [column headerCell];
		RWTableHeaderCell* newCell = [[RWTableHeaderCell alloc] initWithCell:cell];
		[column setHeaderCell:newCell];
		[newCell release];
	}
	
}


- (id)initWithCoder:(NSCoder *)aDecoder
{	
	self = [super initWithCoder:aDecoder];
	
	if (self) {
		[self _setupHeaderCell];
		
		RWCornerView *cornerView = [[[RWCornerView alloc] init] autorelease];
		[self setCornerView:cornerView];
	}
	return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SBDeleteKeyPressedOnRowsNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SBEnterKeyPressedOnRowsNotification object:nil];
    
    [super dealloc];
}

- (void)awakeFromNib {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(enterKeyPressedOnRowsNotification:) 
                                                 name:SBEnterKeyPressedOnRowsNotification 
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deleteKeyPressedOnRowsNotification:) 
                                                 name:SBDeleteKeyPressedOnRowsNotification 
                                               object:nil];
}



- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	if ([theEvent type] == NSRightMouseDown)
	{
		// get the current selections for the outline view. 
		NSIndexSet *selectedRowIndexes = [self selectedRowIndexes];
		
		// select the row that was clicked before showing the menu for the event
		NSPoint mousePoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		NSInteger row = [self rowAtPoint:mousePoint];
		
		// figure out if the row that was just clicked on is currently selected
		if (row >= 0 && [selectedRowIndexes containsIndex:row] == NO)
		{
			//[self selectRow:row byExtendingSelection:NO];
            [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            
            if([self delegate] && [[self delegate] respondsToSelector:@selector(tableView:menuForEvent:)]) {
                NSMenu *menu = [[self delegate] tableView:self menuForEvent:theEvent];
                if(menu != nil) {
                    return menu;
                }
            }
		} else {
            // you can disable this if you don't want clicking on an empty space to deselect all rows
            //[self deselectAll:self];
            if([self delegate] && [[self delegate] respondsToSelector:@selector(tableView:menuForEvent:)]) {
                NSMenu *menu = [[self delegate] tableView:self menuForEvent:theEvent];
                if(menu != nil) {
                    return menu;
                }
            }
        }
		// else that row is currently selected, so don't change anything.
	}
	
	return [super menuForEvent:theEvent];
}


- (void)keyDown:(NSEvent *)theEvent
{
	NSIndexSet *selectedIndexes = [self selectedRowIndexes];
	
	NSString *keyCharacters = [theEvent characters];
	
	//Make sure we have a selection
	if([selectedIndexes count]>0) {
		if([keyCharacters length]>0) {
			unichar firstKey = [keyCharacters characterAtIndex:0];
			if(firstKey==NSDeleteCharacter) {	
				//Post the notification
				[[NSNotificationCenter defaultCenter] postNotificationName:SBDeleteKeyPressedOnRowsNotification
																	object:self
																  userInfo:[NSDictionary dictionaryWithObject:selectedIndexes forKey:@"rows"]];
				
				return;
			}
            
            if(firstKey==NSEnterCharacter || firstKey == NSCarriageReturnCharacter || firstKey == NSNewlineCharacter) {	
				//Post the notification
				[[NSNotificationCenter defaultCenter] postNotificationName:SBEnterKeyPressedOnRowsNotification
																	object:self
																  userInfo:[NSDictionary dictionaryWithObject:selectedIndexes forKey:@"rows"]];
				
				return;
			}
		}
	}
	//We don't care about it
	[super keyDown:theEvent];
}



- (void)deleteKeyPressedOnRowsNotification:(NSNotification *)notification {
    if([notification object] == self) {
        if([self delegate] && [[self delegate] respondsToSelector:@selector(tableViewEnterKeyPressedNotification:)]) {
            [[self delegate] tableViewDeleteKeyPressedNotification:notification];
        }
    }
}


- (void)enterKeyPressedOnRowsNotification:(NSNotification *)notification {
    if([notification object] == self) {
        if([self delegate] && [[self delegate] respondsToSelector:@selector(tableViewDeleteKeyPressedNotification:)]) {
            [[self delegate] tableViewEnterKeyPressedNotification:notification];
        } 
    }
}

@end

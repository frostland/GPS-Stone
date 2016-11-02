//
//  MainView.m
//  GPS Stone Trip Recorder
//
//  Created by François on 7/10/09.
//  Copyright VSO-Software 2009. All rights reserved.
//

#import "MainView.h"

#import "Constants.h"

@implementation MainView

- (id)initWithFrame:(CGRect)frame {
	if (self = [super initWithFrame:frame]) {
	}
	return self;
}


- (void)drawRect:(CGRect)rect {
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
	[[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:VSO_NTF_VIEW_TOUCHED object:self]];
	return [super hitTest:point withEvent:event];
}


- (void)dealloc {
	[super dealloc];
}

@end

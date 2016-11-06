/*
 * VSOSettingsView.m
 * GPS Stone Trip Recorder
 *
 * Created by François on 7/10/09.
 * Copyright VSO-Software 2009. All rights reserved.
 */

#import "VSOSettingsView.h"

#import "Constants.h"



@implementation VSOSettingsView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
	[NSNotificationCenter.defaultCenter postNotification:[NSNotification notificationWithName:VSO_NTF_VIEW_TOUCHED object:self]];
	return [super hitTest:point withEvent:event];
}

@end

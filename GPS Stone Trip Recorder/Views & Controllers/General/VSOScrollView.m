/*
 * VSOScrollView.m
 * GPS Stone Trip Recorder
 *
 * Created by François on 7/11/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "VSOScrollView.h"

#import <MapKit/MapKit.h>



@implementation VSOScrollView

@synthesize delayScroll;

#if 0
- (BOOL)touchesShouldBegin:(NSSet *)touches withEvent:(UIEvent *)event inContentView:(UIView *)view
{
	NSDLog(@"1: %@", view);
/*	[touchStartDate release];
	touchStartDate = [[NSDate dateWithTimeIntervalSinceNow:0] retain];*/
	return YES;
}
#endif

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
	id result = [super hitTest:point withEvent:event];
	
	/* The following two lines should be in touchesShouldBegin:withEvent:inContentView:
	 * It seems there is a bug in the UIScrollView: when delaysContentTouches is set to NO, the method is never called!
	 * The only work-around I found was to put these lines here */
	touchStartDate = [NSDate dateWithTimeIntervalSinceNow:0];
	
	return result;
}

- (BOOL)touchesShouldCancelInContentView:(UIView *)view
{
	if (self.decelerating ||
		 !delayScroll || [touchStartDate timeIntervalSinceNow] < -VSO_DELAY_BEFORE_ALLOWING_SCROLL)
		return YES;
	
	return NO;
}

@end

/*
 * VSOBlankView.m
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 8/20/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "VSOBlankView.h"

#define ANIM_TIME 5.



@implementation VSOBlankView

- (id)initWithFrame:(CGRect)frame
{
	if (self = [super initWithFrame:frame]) {
		self.backgroundColor = [UIColor colorWithWhite:0. alpha:1.];
		self.userInteractionEnabled = YES;
	}
	return self;
}

- (void)showMsg
{
	if (labelBlankScreen == nil) {
		labelBlankScreen = [[UILabel alloc] initWithFrame:CGRectMake(0., 0., 0., 0.)];
		labelBlankScreen.text = NSLocalizedString(@"blank screen", nil);
		CGSize s = [labelBlankScreen.text sizeWithFont:labelBlankScreen.font];
		labelBlankScreen.frame = CGRectMake((self.bounds.size.width - s.width)/2., (self.bounds.size.height - s.height)/2., s.width, s.height);
		
		labelBlankScreen.textColor = [UIColor colorWithWhite:1. alpha:1.];
		labelBlankScreen.backgroundColor = [UIColor colorWithWhite:0. alpha:0.];
		[self addSubview:labelBlankScreen];
	} else {
		labelBlankScreen.alpha = 1.;
	}
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:ANIM_TIME];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
	labelBlankScreen.alpha = 0.;
	[UIView commitAnimations];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
	return self;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[[UIApplication sharedApplication] setStatusBarHidden:NO];
	[self removeFromSuperview];
}

@end

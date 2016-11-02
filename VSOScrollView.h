//
//  VSOScrollView.h
//  GPS Stone Trip Recorder
//
//  Created by François on 7/11/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "Constants.h"

/* When delayScroll is set to YES, this customed scroll view will let subviews get event until a certain delay.
 * When the delay is over, the scroll view keeps events and scrolls if necessary */

@interface VSOScrollView : UIScrollView {
	BOOL delayScroll;
	NSDate *touchStartDate;
}
@property(assign) BOOL delayScroll;

@end

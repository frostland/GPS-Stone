/*
 * XMLIntegerElement.h
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/30/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import <Foundation/Foundation.h>

#import "XMLElement.h"



@interface XMLIntegerElement : XMLElement {
	NSInteger value;
	
	NSString *buf;
}
@property() NSInteger value;

@end

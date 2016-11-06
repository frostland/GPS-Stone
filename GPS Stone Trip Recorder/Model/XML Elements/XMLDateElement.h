/*
 * XMLDateElement.h
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/29/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import <Foundation/Foundation.h>

#import "XMLElement.h"



@interface XMLDateElement : XMLElement {
	NSString *buf;
}

+ (id)dateElementWithElementName:(NSString *)en date:(NSDate *)d;

@property(nonatomic, retain) NSDate *date;

@end



@interface XMLYearElement : XMLDateElement

@property(nonatomic, readonly) NSInteger year;

@end

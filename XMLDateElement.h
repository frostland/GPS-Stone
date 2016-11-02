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
	NSDate *date;
	
	NSString *buf;
}
@property(nonatomic, retain) NSDate *date;
+ (id)dateElementWithElementName:(NSString *)en date:(NSDate *)d;

@end



@interface XMLYearElement : XMLDateElement {
}
- (NSInteger)year;

@end

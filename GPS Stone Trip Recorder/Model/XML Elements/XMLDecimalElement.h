/*
 * XMLDecimalElement.h
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/30/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import <Foundation/Foundation.h>

#import "XMLElement.h"



@interface XMLDecimalElement : XMLElement {
	NSString *buf;
}

+ (XMLDecimalElement *)decimalElementWithElementName:(NSString *)en value:(CGFloat)v;

@property(nonatomic, assign) CGFloat value;

@end

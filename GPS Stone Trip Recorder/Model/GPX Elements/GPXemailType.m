/*
 * email.m
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/30/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "GPXemailType.h"

#import "XMLStringElement.h"



@implementation GPXemailType

+ (NSMutableDictionary *)elementToClassRelations
{
	NSMutableDictionary *d = super.elementToClassRelations;
	[d setValue:XMLStringElement.class forKey:@"id"];
	[d setValue:XMLStringElement.class forKey:@"domain"];
	return d;
}

@end

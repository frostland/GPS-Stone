//
//  ptseg.m
//  GPS Stone Trip Recorder
//
//  Created by François Lamboley on 7/30/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import "GPXptsegType.h"

#import "GPXptType.h"

@implementation GPXptsegType

+ (NSMutableDictionary *)elementToClassRelations
{
	NSMutableDictionary *d = [super elementToClassRelations];
	[d setValue:[GPXptType class] forKey:@"pt"];
	return d;
}

- (id)initWithAttributes:(NSDictionary *)dic elementName:(NSString *)en
{
	if ((self = [super initWithAttributes:dic elementName:en]) != nil) {
	}
	
	return self;
}

@end

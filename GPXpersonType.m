//
//  person.m
//  GPS Stone Trip Recorder
//
//  Created by François Lamboley on 7/30/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import "GPXpersonType.h"

#import "XMLStringElement.h"
#import "GPXemailType.h"
#import "GPXlinkType.h"

@implementation GPXpersonType

+ (NSMutableDictionary *)elementToClassRelations
{
	NSMutableDictionary *d = [super elementToClassRelations];
	[d setValue:[XMLStringElement class] forKey:@"name"];
	[d setValue:[GPXemailType class] forKey:@"email"];
	[d setValue:[GPXlinkType class] forKey:@"link"];
	return d;
}

- (id)initWithAttributes:(NSDictionary *)dic elementName:(NSString *)en
{
	if ((self = [super initWithAttributes:dic elementName:en]) != nil) {
	}
	
	return self;
}

@end

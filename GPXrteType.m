//
//  rte.m
//  GPS Stone Trip Recorder
//
//  Created by François Lamboley on 7/30/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import "GPXrteType.h"

#import "XMLStringElement.h"
#import "XMLIntegerElement.h"
#import "GPXwptType.h"
#import "GPXlinkType.h"
#import "GPXextensionsType.h"

@implementation GPXrteType

+ (NSMutableDictionary *)elementToClassRelations
{
	NSMutableDictionary *d = [super elementToClassRelations];
	[d setValue:[XMLStringElement class] forKey:@"name"];
	[d setValue:[XMLStringElement class] forKey:@"cmt"];
	[d setValue:[XMLStringElement class] forKey:@"desc"];
	[d setValue:[XMLStringElement class] forKey:@"src"];
	[d setValue:[GPXlinkType class] forKey:@"link"];
	[d setValue:[XMLIntegerElement class] forKey:@"number"];
	[d setValue:[XMLStringElement class] forKey:@"type"];
	[d setValue:[GPXextensionsType class] forKey:@"extensions"];
	[d setValue:[GPXwptType class] forKey:@"rtept"];
	return d;
}

- (id)initWithAttributes:(NSDictionary *)dic elementName:(NSString *)en
{
	if ((self = [super initWithAttributes:dic elementName:en]) != nil) {
	}
	
	return self;
}
		
@end

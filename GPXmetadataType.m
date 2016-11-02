//
//  metadata.m
//  GPS Stone Trip Recorder
//
//  Created by François Lamboley on 7/29/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import "GPXmetadataType.h"

#import "XMLStringElement.h"
#import "XMLDateElement.h"
#import "GPXpersonType.h"
#import "GPXcopyrightType.h"
#import "GPXlinkType.h"
#import "GPXboundsType.h"
#import "GPXextensionsType.h"

@implementation GPXmetadataType

+ (NSMutableDictionary *)elementToClassRelations
{
	NSMutableDictionary *d = [super elementToClassRelations];
	[d setValue:[XMLStringElement class] forKey:@"name"];
	[d setValue:[XMLStringElement class] forKey:@"desc"];
	[d setValue:[GPXpersonType class] forKey:@"author"];
	[d setValue:[GPXcopyrightType class] forKey:@"copyright"];
	[d setValue:[GPXlinkType class] forKey:@"link"];
	[d setValue:[XMLDateElement class] forKey:@"time"];
	[d setValue:[XMLStringElement class] forKey:@"keywords"];
	[d setValue:[GPXboundsType class] forKey:@"bounds"];
	[d setValue:[GPXextensionsType class] forKey:@"extensions"];
	return d;
}

- (id)initWithAttributes:(NSDictionary *)dic elementName:(NSString *)en
{
	if ((self = [super initWithAttributes:dic elementName:en]) != nil) {
	}
	
	return self;
}

@end

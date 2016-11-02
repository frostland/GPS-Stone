//
//  pt.m
//  GPS Stone Trip Recorder
//
//  Created by François Lamboley on 7/30/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import "GPXptType.h"

#import "Constants.h"

#import "XMLDateElement.h"
#import "XMLDecimalElement.h"

@implementation GPXptType

@synthesize coords;

+ (NSMutableDictionary *)elementToClassRelations
{
	NSMutableDictionary *d = [super elementToClassRelations];
	[d setValue:[XMLDecimalElement class] forKey:@"ele"];
	[d setValue:[XMLDateElement class] forKey:@"time"];
	return d;
}

- (id)initWithAttributes:(NSDictionary *)dic elementName:(NSString *)en
{
	if ((self = [super initWithAttributes:dic elementName:en]) != nil) {
		NSString *latStr = [dic valueForKey:@"lat"];
		if (!latStr) NSXMLLog(@"Warning, invalid GPX file: No lat attribute in \"pt\"");
		else         coords.latitude = [latStr doubleValue];
		
		NSString *lonStr = [dic valueForKey:@"lon"];
		if (!lonStr) NSXMLLog(@"Warning, invalid GPX file: No lon attribute in \"pt\"");
		else         coords.longitude = [lonStr doubleValue];
	}
	
	return self;
}

- (NSData *)dataForElementAttributes
{
	return [[NSString stringWithFormat:@" lat=\""VSO_COORD_PRINT_FORMAT@"\" lon=\""VSO_COORD_PRINT_FORMAT@"\"", coords.latitude, coords.longitude] dataUsingEncoding:VSO_XML_ENCODING];
}

@end

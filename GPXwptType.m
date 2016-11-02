//
//  wpt.m
//  GPS Stone Trip Recorder
//
//  Created by François Lamboley on 7/29/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import "GPXwptType.h"

#import "Constants.h"

#import "XMLDateElement.h"
#import "XMLStringElement.h"
#import "XMLIntegerElement.h"
#import "XMLDecimalElement.h"
#import "GPXlinkType.h"
#import "GPXextensionsType.h"

@implementation GPXwptType

@synthesize coords;

+ (NSMutableDictionary *)elementToClassRelations
{
	NSMutableDictionary *d = [super elementToClassRelations];
	[d setValue:[XMLDecimalElement class] forKey:@"ele"];
	[d setValue:[XMLDateElement class] forKey:@"time"];
	[d setValue:[XMLDecimalElement class] forKey:@"magvar"];
	[d setValue:[XMLDecimalElement class] forKey:@"geoidheight"];
	[d setValue:[XMLStringElement class] forKey:@"name"];
	[d setValue:[XMLStringElement class] forKey:@"cmt"];
	[d setValue:[XMLStringElement class] forKey:@"desc"];
	[d setValue:[XMLStringElement class] forKey:@"src"];
	[d setValue:[GPXlinkType class] forKey:@"link"];
	[d setValue:[XMLStringElement class] forKey:@"sym"];
	[d setValue:[XMLStringElement class] forKey:@"type"];
	[d setValue:[XMLStringElement class] forKey:@"fix"];
	[d setValue:[XMLIntegerElement class] forKey:@"sat"];
	[d setValue:[XMLDecimalElement class] forKey:@"hdop"];
	[d setValue:[XMLDecimalElement class] forKey:@"vdop"];
	[d setValue:[XMLDecimalElement class] forKey:@"pdop"];
	[d setValue:[XMLDecimalElement class] forKey:@"ageofdgpsdata"];
	[d setValue:[XMLIntegerElement class] forKey:@"dgpsid"];
	[d setValue:[GPXextensionsType class] forKey:@"extensions"];
	
	/* Version 1.0 */
/*	[d setValue:[XMLDecimalElement class] forKey:@"speed"];*/
	return d;
}

+ (GPXwptType *)waypointWithElementName:(NSString *)en coordinates:(CLLocationCoordinate2D)c hAccuracy:(CLLocationAccuracy)hPrecision
										elevation:(CLLocationDistance)elevation vAccuracy:(CLLocationAccuracy)vPrecision
										  heading:(CLLocationDirection)heading date:(NSDate *)date
{
	GPXwptType *newWayPoint = [self new];
	newWayPoint.elementName = en;
	newWayPoint.coords = c;
	[newWayPoint addChild:[XMLDateElement dateElementWithElementName:@"time" date:date]];
	[newWayPoint addChild:[XMLDecimalElement decimalElementWithElementName:@"hdop" value:hPrecision]];
	if (heading >= 0.) [newWayPoint addChild:[XMLDecimalElement decimalElementWithElementName:@"magvar" value:heading]];
	if (vPrecision >= 0.) {
		[newWayPoint addChild:[XMLDecimalElement decimalElementWithElementName:@"ele" value:elevation]];
		[newWayPoint addChild:[XMLDecimalElement decimalElementWithElementName:@"vdop" value:vPrecision]];
	}
	
	return [newWayPoint autorelease];
}

- (id)initWithAttributes:(NSDictionary *)dic elementName:(NSString *)en
{
	if ((self = [super initWithAttributes:dic elementName:en]) != nil) {
		NSString *latStr = [dic valueForKey:@"lat"];
		if (!latStr) NSXMLLog(@"Warning, invalid GPX file: No lat attribute in \"wpt\"");
		else         coords.latitude = [latStr doubleValue];
		
		NSString *lonStr = [dic valueForKey:@"lon"];
		if (!lonStr) NSXMLLog(@"Warning, invalid GPX file: No lon attribute in \"wpt\"");
		else         coords.longitude = [lonStr doubleValue];
	}
	
	return self;
}

- (NSData *)dataForElementAttributes
{
	return [[NSString stringWithFormat:@" lat=\""VSO_COORD_PRINT_FORMAT@"\" lon=\""VSO_COORD_PRINT_FORMAT@"\"", coords.latitude, coords.longitude] dataUsingEncoding:VSO_XML_ENCODING];
}

- (BOOL)hasHAccuracy
{
	return ([[self childrenWithElementName:@"hdop"] count] != 0);
}

- (CLLocationAccuracy)hAccuracy
{
	return [(XMLDecimalElement *)[self lastChildWithElementName:@"hdop"] value];
}

- (BOOL)hasVAccuracy
{
	return ([[self childrenWithElementName:@"vdop"] count] != 0);
}

- (CLLocationAccuracy)vAccuracy
{
	return [(XMLDecimalElement *)[self lastChildWithElementName:@"vdop"] value];
}

- (BOOL)hasHeading
{
	return ([[self childrenWithElementName:@"magvar"] count] != 0);
}

- (CLLocationDirection)heading
{
	return [(XMLDecimalElement *)[self lastChildWithElementName:@"magvar"] value];
}

- (BOOL)hasElevation
{
	return ([[self childrenWithElementName:@"ele"] count] != 0);
}

- (CLLocationDistance)elevation
{
	return [(XMLDecimalElement *)[self lastChildWithElementName:@"ele"] value];
}

- (BOOL)hasDate
{
	return ([[self childrenWithElementName:@"time"] count] != 0);
}

- (NSDate *)date
{
	return [[self lastChildWithElementName:@"time"] date];
}

@end

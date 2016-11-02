/*
 * bounds.m
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/30/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "GPXboundsType.h"

#import "Constants.h"



@implementation GPXboundsType

@synthesize minCoords, maxCoords;

- (id)initWithAttributes:(NSDictionary *)dic elementName:(NSString *)en
{
	if ((self = [super initWithAttributes:dic elementName:en]) != nil) {
		NSString *str = [dic valueForKey:@"minlat"];
		if (!str) NSXMLLog(@"Warning, invalid GPX file: No minlat attribute in \"bounds\"");
		else      minCoords.latitude = [str doubleValue];
		
		str = [dic valueForKey:@"minlon"];
		if (!str) NSXMLLog(@"Warning, invalid GPX file: No minlon attribute in \"wpt\"");
		else      minCoords.longitude = [str doubleValue];
		
		str = [dic valueForKey:@"maxlat"];
		if (!str) NSXMLLog(@"Warning, invalid GPX file: No maxlat attribute in \"bounds\"");
		else      maxCoords.latitude = [str doubleValue];
		
		str = [dic valueForKey:@"maxlon"];
		if (!str) NSXMLLog(@"Warning, invalid GPX file: No maxlon attribute in \"wpt\"");
		else      maxCoords.longitude = [str doubleValue];
	}
	
	return self;
}

- (NSData *)dataForElementAttributes;
{
	return [[NSString stringWithFormat:@" minlat=\""VSO_COORD_PRINT_FORMAT@"\" minlon=\""VSO_COORD_PRINT_FORMAT@"\" maxlat=\""VSO_COORD_PRINT_FORMAT@"\" maxlon=\""VSO_COORD_PRINT_FORMAT@"\"", minCoords.latitude, minCoords.longitude, maxCoords.latitude, maxCoords.longitude] dataUsingEncoding:VSO_XML_ENCODING];
}

@end

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

- (id)initWithAttributes:(NSDictionary *)dic elementName:(NSString *)en
{
	if ((self = [super initWithAttributes:dic elementName:en]) != nil) {
		NSString *str = [dic valueForKey:@"minlat"];
		if (str == nil) NSXMLLog(@"Warning, invalid GPX file: No minlat attribute in \"bounds\"");
		else            _minCoords.latitude = [str doubleValue];
		
		str = [dic valueForKey:@"minlon"];
		if (str == nil) NSXMLLog(@"Warning, invalid GPX file: No minlon attribute in \"wpt\"");
		else            _minCoords.longitude = [str doubleValue];
		
		str = [dic valueForKey:@"maxlat"];
		if (str == nil) NSXMLLog(@"Warning, invalid GPX file: No maxlat attribute in \"bounds\"");
		else            _maxCoords.latitude = [str doubleValue];
		
		str = [dic valueForKey:@"maxlon"];
		if (str == nil) NSXMLLog(@"Warning, invalid GPX file: No maxlon attribute in \"wpt\"");
		else            _maxCoords.longitude = [str doubleValue];
	}
	
	return self;
}

- (NSData *)dataForElementAttributes;
{
	return [[NSString stringWithFormat:@" minlat=\""VSO_COORD_PRINT_FORMAT@"\" minlon=\""VSO_COORD_PRINT_FORMAT@"\" maxlat=\""VSO_COORD_PRINT_FORMAT@"\" maxlon=\""VSO_COORD_PRINT_FORMAT@"\"", self.minCoords.latitude, self.minCoords.longitude, self.maxCoords.latitude, self.maxCoords.longitude] dataUsingEncoding:VSO_XML_ENCODING];
}

@end

//
//  link.m
//  GPS Stone Trip Recorder
//
//  Created by François Lamboley on 7/30/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import "GPXlinkType.h"

#import "XMLStringElement.h"

@implementation GPXlinkType

@synthesize href;

+ (NSMutableDictionary *)elementToClassRelations
{
	NSMutableDictionary *d = [super elementToClassRelations];
	[d setValue:[XMLStringElement class] forKey:@"text"];
	[d setValue:[XMLStringElement class] forKey:@"type"];
	return d;
}

- (id)initWithAttributes:(NSDictionary *)dic elementName:(NSString *)en
{
	if ((self = [super initWithAttributes:dic elementName:en]) != nil) {
		self.href = [dic valueForKey:@"href"];
		if (!self.href) NSXMLLog(@"Invalid GPX file: no href in a link");
	}
	
	return self;
}

- (NSData *)dataForElementAttributes
{
	return [[NSString stringWithFormat:@" href=\"%@\"", href] dataUsingEncoding:VSO_XML_ENCODING];
}

- (void)dealloc
{
	[href release];
	
	[super dealloc];
}


@end

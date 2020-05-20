/*
 * copyright.m
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/30/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "GPXcopyrightType.h"

#import "XMLDateElement.h"
#import "XMLStringElement.h"



@implementation GPXcopyrightType

+ (NSMutableDictionary *)elementToClassRelations
{
	NSMutableDictionary *d = super.elementToClassRelations;
	[d setValue:XMLYearElement.class   forKey:@"year"];
	[d setValue:XMLStringElement.class forKey:@"license"];
	return d;
}

- (id)initWithAttributes:(NSDictionary *)dic elementName:(NSString *)en
{
	if ((self = [super initWithAttributes:dic elementName:en]) != nil) {
		self.author = [dic valueForKey:@"author"];
		if (self.author == nil) NSLog(@"Warning, invalid GPX file: no author in a copyright");
	}
	
	return self;
}

- (NSData *)dataForElementAttributes;
{
	return [[NSString stringWithFormat:@" author=\"%@\"", self.author] dataUsingEncoding:VSO_XML_ENCODING];
}

@end

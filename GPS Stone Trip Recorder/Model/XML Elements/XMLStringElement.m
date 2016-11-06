/*
 * XMLStringElement.m
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/29/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "XMLStringElement.h"



@implementation XMLStringElement

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	if (!self.content) self.content = string;
	else               self.content = [self.content stringByAppendingString:string];
	
	containsText = YES;
}

- (NSData *)dataForStuffBetweenTags:(NSUInteger)indent
{
	return [self.content dataUsingEncoding:VSO_XML_ENCODING];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ object; string = \"%@\"", self.elementName, self.content];
}

@end

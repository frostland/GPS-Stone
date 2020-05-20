/*
 * XMLIntegerElement.m
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/30/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "XMLIntegerElement.h"



@implementation XMLIntegerElement

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	if (buf == nil) buf = string;
	else            buf = [buf stringByAppendingString:string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	self.value = buf.integerValue;
	containsText = YES;
	
	[super parser:parser didEndElement:elementName namespaceURI:namespaceURI qualifiedName:qName];
}

- (NSData *)dataForStuffBetweenTags:(NSUInteger)indent
{
	return [[NSString stringWithFormat:@"%ld", (long)self.value] dataUsingEncoding:VSO_XML_ENCODING];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ object; integer value = \"%ld\"", self.elementName, (long)self.value];
}

@end

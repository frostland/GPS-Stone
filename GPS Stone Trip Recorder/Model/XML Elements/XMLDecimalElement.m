/*
 * XMLDecimalElement.m
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/30/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "XMLDecimalElement.h"



@implementation XMLDecimalElement

+ (XMLDecimalElement *)decimalElementWithElementName:(NSString *)en value:(CGFloat)v
{
	XMLDecimalElement *e = [XMLDecimalElement new];
	e.elementName = en;
	e.value = v;
	e->containsText = YES;
	
	return e;
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	if (buf == nil) buf = string;
	else            buf = [buf stringByAppendingString:string];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	self.value = (CGFloat)buf.doubleValue;
	containsText = YES;
	
	[super parser:parser didEndElement:elementName namespaceURI:namespaceURI qualifiedName:qName];
}

- (NSData *)dataForStuffBetweenTags:(NSUInteger)indent
{
	return [[NSString stringWithFormat:@"%f", self.value] dataUsingEncoding:VSO_XML_ENCODING];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ object; decimal value = \"%"CGFLOAT_FMT"\"", self.elementName, self.value];
}

@end

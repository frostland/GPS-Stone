/*
 * extensions.m
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/30/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "GPXextensionsType.h"



@implementation GPXextensionsType

- (id)initWithAttributes:(NSDictionary *)dic elementName:(NSString *)en
{
	if ((self = [super initWithAttributes:dic elementName:en]) != nil) {
		ignoreCount = 0;
	}
	
	return self;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
	ignoreCount++;
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if (ignoreCount == 0) [super parser:parser didEndElement:elementName namespaceURI:namespaceURI qualifiedName:qName];
	ignoreCount--;
}

@end

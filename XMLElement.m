//
//  XMLElement.m
//  GPS Stone Trip Recorder
//
//  Created by François Lamboley on 7/29/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import "XMLElement.h"

@implementation XMLElement

@synthesize elmntName, parent, children;

+ (XMLElement *)xmlElementWithElementName:(NSString *)en
{
	XMLElement *newElement = [self new];
	newElement.elementName = en;
	
	return [newElement autorelease];
}

+ (NSMutableDictionary *)elementToClassRelations;
{
	return [NSMutableDictionary dictionary];
}

- (id)init
{
	if ((self = [super init]) != nil) {
		children = [NSMutableArray new];
		
		childrenChanged = YES;
		containsText = NO;
	}
	
	return self;
}

- (id)initWithAttributes:(NSDictionary *)dic elementName:(NSString *)en
{
	if ((self = [self init]) != nil) {
		self.elementName = en;
		if (!self.elementName) self.elementName = NSStringFromClass([self class]);
	}
		
	return self;
}

- (NSString *)elementName
{
	if (!elmntName) return NSStringFromClass([self class]);
	
	return elmntName;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
	NSDictionary *elementToClassRelations = [[self class] elementToClassRelations];
	Class childClass = [elementToClassRelations valueForKey:elementName];
	if (!childClass) childClass = NSClassFromString(elementName);
	if (!childClass) {
		NSString *className = NSStringFromClass(childClass);
		if (!className) className = elementName;
		NSXMLLog(@"Warning: invalid file; no known element \"%@\" in \"%@\"", elementName, self.elementName);
		return;
	}
	id child = [[childClass alloc] initWithAttributes:attributeDict elementName:elementName];
	if (child != nil) {
		[child setParent:self];
		[children addObject:child];
		parser.delegate = child;
		childrenChanged = YES;
	} else NSXMLLog(@"Cannot create object of class \"%@\"", NSStringFromClass(childClass));
/*	[child release];*/
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if (![elementName isEqualToString:self.elementName]) {
		NSXMLLog(@"Warning: invalid file: closing element \"%@\" in a \"%@\"", elementName, self.elementName);
		return;
	}
	parser.delegate = self.parent;
}

- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock
{
	/* Ignored */
}

- (NSData *)dataForElementAttributes
{
	return [NSData data];
}

- (NSData *)dataForStuffBetweenTags:(NSUInteger)indent
{
	NSMutableData *dta = [NSMutableData data];
	
	for (XMLElement *child in children) [dta appendData:[child XMLOutput:indent+1]];
	
	return [[dta copy] autorelease];
}

- (NSData *)XMLOutputForTagOpening:(NSUInteger)indent
{
	NSMutableData *dta = [NSMutableData data];
	
	if (!parent) [dta appendData:[@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" dataUsingEncoding:VSO_XML_ENCODING]];
	for (NSUInteger i = 0; i<indent; i++)
		[dta appendData:[@"\t" dataUsingEncoding:VSO_XML_ENCODING]];
	[dta appendData:[[NSString stringWithFormat:@"<%@", self.elementName] dataUsingEncoding:VSO_XML_ENCODING]];
	[dta appendData:[self dataForElementAttributes]];
	[dta appendData:[@">" dataUsingEncoding:VSO_XML_ENCODING]];
	if (!containsText) [dta appendData:[@"\n" dataUsingEncoding:VSO_XML_ENCODING]];
	
	return dta;
}

- (NSData *)XMLOutputForTagClosing:(NSUInteger)indent
{
	NSMutableData *dta = [NSMutableData data];
	
	if (!containsText)
		for (NSUInteger i = 0; i<indent; i++)
			[dta appendData:[@"\t" dataUsingEncoding:VSO_XML_ENCODING]];
	
	[dta appendData:[[NSString stringWithFormat:@"</%@>\n", self.elementName] dataUsingEncoding:VSO_XML_ENCODING]];
	
	return dta;
}

- (NSData *)XMLOutput:(NSUInteger)indent
{
	NSMutableData *dta = [NSMutableData data];
	
	[dta appendData:[self XMLOutputForTagOpening:indent]];
	[dta appendData:[self dataForStuffBetweenTags:indent]];
	[dta appendData:[self XMLOutputForTagClosing:indent]];
	
	return [[dta copy] autorelease];
}

- (NSArray *)childrenWithElementName:(NSString *)en
{
	NSMutableArray *cp = [NSMutableArray new];
	for (XMLElement *curElement in self.children)
		if ([curElement.elementName isEqualToString:en])
			[cp addObject:curElement];
	
	return [[[cp autorelease] copy] autorelease];
}

- (id)lastChildWithElementName:(NSString *)en
{
	NSArray *chdrn = [self childrenWithElementName:en];
	
	if ([chdrn count] == 0) return nil;
	return [chdrn lastObject];
}

- (BOOL)insertChild:(XMLElement *)c atIndexOfElementType:(NSUInteger)idx
{
	BOOL added = NO;
	NSUInteger i, j = 0;
	NSUInteger n = [self.children count];
	
	if ([[[self class] elementToClassRelations] valueForKey:c.elementName] == nil) {
		NSDLog(@"Warning: trying to add a not known element \"%@\" in a \"%@\"", c.elementName, self.elementName);
		return NO;
	}
	
	for (i = 0; i<n && !added; i++) {
		XMLElement *curElement = [self.children objectAtIndex:i];
		if ([curElement.elementName isEqualToString:c.elementName]) {
			if (j++ == idx) {
				[self.children insertObject:c atIndex:i];
				childrenChanged = YES;
				added = YES;
			}
		}
	}
	if (!added && (idx == j || (n == 0 && idx == 0))) {
		[self.children addObject:c];
		childrenChanged = YES;
		added = YES;
	}
	if (added) c.parent = self;
	
	return added;
}

- (BOOL)addChild:(XMLElement *)c
{
	return [self insertChild:c atIndexOfElementType:[[self childrenWithElementName:c.elementName] count]];
}

- (void)removeAllChildrenWithElementName:(NSString *)en
{
	NSUInteger i;
	for (i = 0; i<[self.children count]; i++) {
		if ([[[self.children objectAtIndex:i] elementName] isEqualToString:en]) {
			[self.children removeObjectAtIndex:i--];
			childrenChanged = YES;
		}
	}
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"\"%@\" object; children = \"%@\"", self.elementName, self.children];
}

- (void)dealloc
{
	[elmntName release];
	[children release];
	
	[super dealloc];
}

@end

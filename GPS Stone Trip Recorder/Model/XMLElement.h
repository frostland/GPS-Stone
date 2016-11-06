/*
 * XMLElement.h
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/29/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import <Foundation/Foundation.h>

#import "VSOUtils.h"


#define VSO_XML_ENCODING NSUTF8StringEncoding


@interface XMLElement : NSObject <NSXMLParserDelegate> {
	/* Set this variable to YES in subclasses if no new line must be added between tag opening and closing */
	BOOL containsText;
	/* Gives the opportunity to subclasses to manage caches. When a child is added (or deleted), the following var is set to YES */
	BOOL childrenChanged;
}

@property(nonatomic, weak) XMLElement *parent;
@property(nonatomic, retain) NSString *elementName;
@property(nonatomic, retain) NSMutableArray *children;

+ (XMLElement *)xmlElementWithElementName:(NSString *)en;

/* This method should be overwritten by sublcasse (and they must call super!)
 * It provides the relation between elements names and their corresponding classes.
 * You may set the class to [NSNull class] if the element name is the same as the class name
 * The result of this function is mutable for performance only
 * (subclasses don't have to make a mutable copy of the dicitonary to modify it...) */
+ (NSMutableDictionary *)elementToClassRelations;

- (id)initWithAttributes:(NSDictionary *)dic elementName:(NSString *)en;
/* See the Apple doc "Constructing XML Tree Structures" for the explanation of the algorithm used to parse XML */
/* Subclasses who want to overwrite the two following method should call super */
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict;
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName;
/* By default, CDATA blocks are ignored. Subclasses can overwrite to treat them. */
- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock;

/* Subclasses should overwrite the two following method only
 * The second is overwritten only if there is text between the tags. This the place where you put it. Do not call super when overwriting this function. */
- (NSData *)dataForElementAttributes;
- (NSData *)dataForStuffBetweenTags:(NSUInteger)indent;
- (NSData *)XMLOutput:(NSUInteger)indent;
/* Method to enable partial XML writing */
- (NSData *)XMLOutputForTagOpening:(NSUInteger)indent;
- (NSData *)XMLOutputForTagClosing:(NSUInteger)indent;

/***** Accessing and setting children *****/

/* Not cached */
- (NSArray *)childrenWithElementName:(NSString *)en;
/* Will return nil if there is no children with the correct element name */
- (id)lastChildWithElementName:(NSString *)en;
/* The index where the child is added is computed taking into account only elements whose element name is the same as the inserted child.
 * Say for instance that I want to add an element <trkpt>new</trkpt> at index 2 into self which is as follow:
 *		<trkseg>
 *			<trkpt>...</trkpt>
 *			<name>...</name>
 *			<trkpt>...</trkpt>
 *			<trkpt>...</trkpt>
 *		</trkseg>
 * The result will be the following:
 *		<trkseg>
 *			<trkpt>...</trkpt>
 *			<name>...</name>
 *			<trkpt>...</trkpt>
 *			<trkpt>new</trkpt>
 *			<trkpt>...</trkpt>
 *		</trkseg>
 * If index was 1, there is no guarantee that the added element will be before or after the "name" element.
 */
- (BOOL)insertChild:(XMLElement *)c atIndexOfElementType:(NSUInteger)i;
- (BOOL)addChild:(XMLElement *)c;

- (void)removeAllChildrenWithElementName:(NSString *)en;

@end

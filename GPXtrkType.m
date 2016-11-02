/*
 * trk.m
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/30/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "GPXtrkType.h"

#import "XMLIntegerElement.h"
#import "XMLStringElement.h"
#import "GPXlinkType.h"
#import "GPXextensionsType.h"



@implementation GPXtrkType

+ (NSMutableDictionary *)elementToClassRelations
{
	NSMutableDictionary *d = [super elementToClassRelations];
	[d setValue:[XMLStringElement class] forKey:@"name"];
	[d setValue:[XMLStringElement class] forKey:@"cmt"];
	[d setValue:[XMLStringElement class] forKey:@"desc"];
	[d setValue:[XMLStringElement class] forKey:@"src"];
	[d setValue:[GPXlinkType class] forKey:@"link"];
	[d setValue:[XMLIntegerElement class] forKey:@"number"];
	[d setValue:[XMLStringElement class] forKey:@"type"];
	[d setValue:[GPXextensionsType class] forKey:@"extensions"];
	[d setValue:[GPXtrksegType class] forKey:@"trkseg"];
	return d;
}

- (id)initWithAttributes:(NSDictionary *)dic elementName:(NSString *)en
{
	if ((self = [super initWithAttributes:dic elementName:en]) != nil) {
	}
	
	return self;
}

- (GPXtrksegType *)firstTrackSegment
{
	if ([[self trackSegments] count] == 0) return nil;
	return [[self trackSegments] objectAtIndex:0];
}

- (GPXtrksegType *)lastTrackSegment
{
	NSUInteger n = [[self trackSegments] count];
	if (n == 0) return nil;
	return [[self trackSegments] objectAtIndex:n-1];
}

- (NSArray *)trackSegments
{
	if (cachedSegments && !childrenChanged) return cachedSegments;
	
	childrenChanged = NO;
	return (cachedSegments = [[self childrenWithElementName:@"trkseg"] copy]);
}

- (void)removeAllTrackSegments
{
	[self removeAllChildrenWithElementName:@"trkseg"];
}

- (BOOL)addTrackSegment
{
	return [self addChild:[GPXtrksegType xmlElementWithElementName:@"trkseg"]];
}

@end

/*
 * trkseg.m
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/30/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "GPXtrksegType.h"

#import "GPXextensionsType.h"



@implementation GPXtrksegType

+ (NSMutableDictionary *)elementToClassRelations
{
	NSMutableDictionary *d = [super elementToClassRelations];
	[d setValue:[GPXwptType class] forKey:@"trkpt"];
	[d setValue:[GPXextensionsType class] forKey:@"extensions"];
	return d;
}

- (id)initWithAttributes:(NSDictionary *)dic elementName:(NSString *)en
{
	if ((self = [super initWithAttributes:dic elementName:en]) != nil) {
	}
	
	return self;
}

- (GPXwptType *)firstTrackPoint
{
	if ([[self trackPoints] count] == 0) return nil;
	return [[self trackPoints] objectAtIndex:0];
}

- (GPXwptType *)lastTrackPoint
{
	if ([[self trackPoints] count] == 0) return nil;
	return [[self trackPoints] objectAtIndex:[[self trackPoints] count]-1];
}

- (NSArray *)trackPoints
{
	if (cachedPoints && !childrenChanged) return cachedPoints;
	
	childrenChanged = NO;
	return (cachedPoints = [[self childrenWithElementName:@"trkpt"] copy]);
}

- (void)removeAllTrackPoints
{
	NSDLog(@"Removing track points");
	[self removeAllChildrenWithElementName:@"trkpt"];
	NSDLog(@"Done removing track points");
}

- (BOOL)addTrackPointWithCoords:(CLLocationCoordinate2D)coords hPrecision:(CLLocationAccuracy)hPrecision
							 elevation:(CLLocationDistance)elevation vPrecision:(CLLocationAccuracy)vPrecision
								heading:(CLLocationDirection)heading date:(NSDate *)date
{
	return [self addChild:[GPXwptType waypointWithElementName:@"trkpt" coordinates:coords hAccuracy:hPrecision
																	elevation:elevation vAccuracy:vPrecision
																	  heading:heading date:date]];
}

@end

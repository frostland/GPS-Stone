/*
 * gpx.m
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/29/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import "GPXgpxType.h"

#import "GPXmetadataType.h"
#import "GPXwptType.h"
#import "GPXrteType.h"
#import "GPXextensionsType.h"



@implementation GPXgpxType

+ (NSMutableDictionary *)elementToClassRelations
{
	NSMutableDictionary *d = super.elementToClassRelations;
	[d setValue:GPXmetadataType.class   forKey:@"metadata"];
	[d setValue:GPXwptType.class        forKey:@"wpt"];
	[d setValue:GPXrteType.class        forKey:@"rte"];
	[d setValue:GPXtrkType.class        forKey:@"trk"];
	[d setValue:GPXextensionsType.class forKey:@"extensions"];
	return d;
}

- (id)initWithAttributes:(NSDictionary *)dic elementName:(NSString *)en
{
	if ((self = [super initWithAttributes:dic elementName:en]) != nil) {
		self.creator = [dic valueForKey:@"creator"];
		self.version = [dic valueForKey:@"version"];
		if (self.creator == nil) NSXMLLog(@"Warning: invalid GPX file; no name attribute to the gpx root element");
		if (self.version == nil) NSXMLLog(@"Warning: invalid GPX file; no version attribute to the gpx root element");
		if (![self.version isEqualToString:@"1.1"]) NSXMLLog(@"Warning: GPX file version is not 1.1. There may be errors when parsing it.");
	}
	
	return self;
}

- (NSData *)dataForElementAttributes;
{
	return [[NSString stringWithFormat:@" creator=\"%@\" version=\"1.1\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns=\"http://www.topografix.com/GPX/1/1\" xsi:schemaLocation=\"http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd\"", self.creator] dataUsingEncoding:VSO_XML_ENCODING];
}

- (GPXtrkType *)firstTrack
{
	return self.tracks.firstObject;
}

- (NSArray *)tracks
{
	if (cachedTracks && !childrenChanged) return cachedTracks;
	
	childrenChanged = NO;
	return (cachedTracks = [[self childrenWithElementName:@"trk"] copy]);
}

- (BOOL)addTrack
{
	return [self addChild:[GPXtrkType xmlElementWithElementName:@"trk"]];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"gpx object; creator = \"%@\"; version = \"%@\"; children = \"%@\"", self.creator, self.version, self.children];
}

@end

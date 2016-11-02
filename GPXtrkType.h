/*
 * trk.h
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/30/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import <Foundation/Foundation.h>

#import "XMLElement.h"
#import "GPXtrksegType.h"



@interface GPXtrkType : XMLElement {
	NSArray *cachedSegments;
}
- (GPXtrksegType *)firstTrackSegment;
- (GPXtrksegType *)lastTrackSegment;
- (NSArray *)trackSegments;
- (void)removeAllTrackSegments;
- (BOOL)addTrackSegment;

@end

/*
 * gpx.h
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/29/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import <Foundation/Foundation.h>
#import "XMLElement.h"

#import "GPXtrkType.h"



/* Root element of gpx files */
@interface GPXgpxType : XMLElement {
	NSString *version;
	NSString *creator;
	
	NSArray *cachedTracks;
}
@property(nonatomic, retain) NSString *version;
@property(nonatomic, retain) NSString *creator;

- (GPXtrkType *)firstTrack;
- (NSArray *)tracks;
- (BOOL)addTrack;

@end

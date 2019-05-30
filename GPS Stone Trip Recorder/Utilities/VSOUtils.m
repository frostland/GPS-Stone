/*
 *  VSOUtils.c
 *  GPS Stone Trip Recorder
 *
 *  Created by François Lamboley on 7/16/09.
 *  Copyright 2009 VSO-Software. All rights reserved.
 *
 */

#include <stdio.h>

#import "Constants.h"
#include "VSOUtils.h"


BOOL isDeviceScreenTallerThanOriginalIPhone() {
	return UIScreen.mainScreen.bounds.size.height > 480;
}

NSString *fullPathFromRelativeForGPXFile(NSString *relativePath) {
	return [c.urlToFolderWithGPXFiles stringByAppendingPathComponent:relativePath];
}

NSString *relativePathFromFullForGPXFile(NSString *fullPath) {
#ifndef NDEBUG
	if ([[fullPath pathComponents] count] != [[c.urlToFolderWithGPXFiles pathComponents] count] + 1) {
		NSLog(@"Error: [[fullPath pathComponents] count] != [[c.urlToFolderWithGPXFiles pathComponents] count] + 1 (in relativePathFromFullForGPXFile)");
		return nil;
	}
#endif
	return [fullPath lastPathComponent];
}

NSString *NSStringFromDegrees(CLLocationDegrees d, BOOL lat) {
	BOOL neg = (d < 0);
	
	d = ABS(d);
	NSUInteger degs = (NSUInteger)d;
	CLLocationDegrees minsDec = (d-degs)*60.;
	NSUInteger mins = (NSUInteger)minsDec;
	CLLocationDegrees secsDec = (minsDec-mins)*60.;
	
	NSString *output = [NSString stringWithFormat:@"%lu° %lu’ %.5f” ", (unsigned long)degs, (unsigned long)mins, secsDec];
	
	NSString *suffix;
	if (!neg) suffix = NSLocalizedString(lat? @"N": @"E", nil);
	else      suffix = NSLocalizedString(lat? @"S": @"W", nil);
	output = [output stringByAppendingString:suffix];
	
	return output;
}

NSString *NSStringFromDirection(CLLocationDirection d) {
	return [NSString stringWithFormat:NSLocalizedString(@"x degs", nil), d];
}

NSString *NSStringFromDate(NSDate *date) {
	NSDateFormatter *formater = [NSDateFormatter new];
	[formater setDateFormat:NSLocalizedString(@"read date format", nil)];
	
	return [formater stringFromDate:date];
}

/* speed is in m/s */
NSString *NSStringFromSpeed(CGFloat speed, BOOL showUnit) {
	BOOL miles = (distanceUnit() == VSODistanceUnitMiles);
	speed *= 3.6; /* speed is now in km/h */
	if (miles) speed /= c.oneMileInKilometer; /* speed is now in mph */
	
	NSString *formatNonLoc = [NSString stringWithFormat:@"x with arbitrary decimal precision%@",  showUnit? (miles? @" mph format": @" km/h format"): @""];
	return [NSString stringWithFormat:NSLocalizedString(formatNonLoc, nil), MAX(0, 2 - (NSInteger)(log10(speed))), speed];
}

NSString *NSStringFromTimeInterval(NSTimeInterval i) {
	NSUInteger h, m, s;
	h = i/3600; m = (i-h*3600)/60; s = i-h*3600-m*60;
	
	return [NSString stringWithFormat:@"%02lu:%02lu:%02lu", (unsigned long)h, (unsigned long)m, (unsigned long)s];
}

NSString *NSStringFromDistance(CLLocationDistance d) {
	if (distanceUnit() == VSODistanceUnitMiles) {
		CGFloat d2 = d/c.oneFootInMeters;
		if (d2 < 1000) return [NSString stringWithFormat:NSLocalizedString(@"n ft format", nil), (unsigned int)(d2 + 0.5)];
		d2 = (d/1000.)/c.oneMileInKilometer;
		return [NSString stringWithFormat:NSLocalizedString(@"x with arbitrary decimal precision mi format", nil), MAX(0, 2 - (NSInteger)(log10(d2))), d2];
	} else {
		if (d < 1000) return [NSString stringWithFormat:NSLocalizedString(@"n m format", nil), (unsigned int)(d + 0.5)];
		return [NSString stringWithFormat:NSLocalizedString(@"x with arbitrary decimal precision km format", nil), MAX(0, 2 - (NSInteger)(log10(d/1000.))), d/1000.];
	}
}

NSString *NSStringFromAltitude(CLLocationDistance a) {
	NSString *formatNonLoc = @"x m format (altitude)";
	if (distanceUnit() == VSODistanceUnitMiles) {
		a /= c.oneFootInMeters; /* a is now in feet */
		formatNonLoc = @"x ft format (altitude)";
	}
	
	return [NSString stringWithFormat:NSLocalizedString(formatNonLoc, nil), a + 0.5];
}

#pragma mark -
/* *************************** */
void *mallocTable(size_t size, size_t sizeOfElementsInTable) {
	void *b = malloc(size*sizeOfElementsInTable);
	if (!b) {
		fprintf(stderr, "Cannot malloc %ld bytes. Exiting now.\n", size*sizeOfElementsInTable);
		exit(1);
	}
	
	return b;
}

void **malloc2DTable(size_t xSize, size_t ySize, size_t sizeOfElementsInTable) {
	void **b = mallocTable(xSize, sizeof(void*));
	
	for (size_t i = 0; i<xSize; i++)
		b[i] = mallocTable(ySize, sizeOfElementsInTable);
	
	return b;
}

void ***malloc3DTable(size_t xSize, size_t ySize, size_t zSize, size_t sizeOfElementsInTable) {
	void ***b = (void ***)malloc2DTable(xSize, ySize, sizeof(void*));
	
	for (size_t i = 0; i<xSize; i++)
		for (size_t j = 0; j<ySize; j++)
			b[i][j] = mallocTable(zSize, sizeOfElementsInTable);
	
	return b;
}

void free2DTable(void **b, size_t xSize) {
	for (size_t i = 0; i<xSize; i++)
		free(b[i]);
	
	free(b);
}

void free3DTable(void ***b, size_t xSize, size_t ySize) {
	for (size_t i = 0; i<xSize; i++)
		free2DTable(b[i], ySize);
	
	free(b);
}

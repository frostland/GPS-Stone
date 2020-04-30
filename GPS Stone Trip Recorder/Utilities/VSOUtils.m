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


#define ONE_MILE_IN_KILOMETER (1.609344)
#define ONE_FOOT_IN_METERS    (0.3048)
#define COORD_PRINT_FORMAT    (@"%.10f")


BOOL isDeviceScreenTallerThanOriginalIPhone() {
	return UIScreen.mainScreen.bounds.size.height > 480;
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
NSString *NSStringFromSpeed(CLLocationSpeed speed, BOOL showUnit, BOOL useMiles) {
	speed *= 3.6; /* speed is now in km/h */
	if (useMiles) speed /= ONE_MILE_IN_KILOMETER; /* speed is now in mph */
	
#warning "TODO: Use a NumberFormatter (or a speed formatter?)"
	NSString *formatNonLoc = [NSString stringWithFormat:@"x with arbitrary decimal precision%@",  showUnit? (useMiles? @" mph format": @" km/h format"): @""];
	return [NSString stringWithFormat:NSLocalizedString(formatNonLoc, nil), MAX(0, 2 - (NSInteger)(log10(speed))), speed];
}

NSString *NSStringFromTimeInterval(NSTimeInterval i) {
	NSUInteger h, m, s;
	h = i/3600; m = (i-h*3600)/60; s = i-h*3600-m*60;
	
#warning "TODO: Use a DateFormatter (IIRC)"
	return [NSString stringWithFormat:@"%02lu:%02lu:%02lu", (unsigned long)h, (unsigned long)m, (unsigned long)s];
}

NSString *NSStringFromDistance(CLLocationDistance d, BOOL useMiles) {
#warning "TODO: Use a NumberFormatter (or a distance formatter?)"
	if (useMiles) {
		CGFloat d2 = d/ONE_FOOT_IN_METERS;
		if (d2 < 1000) return [NSString stringWithFormat:NSLocalizedString(@"n ft format", nil), (unsigned int)(d2 + 0.5)];
		d2 = (d/1000.)/ONE_MILE_IN_KILOMETER;
		return [NSString stringWithFormat:NSLocalizedString(@"x with arbitrary decimal precision mi format", nil), MAX(0, 2 - (NSInteger)(log10(d2))), d2];
	} else {
		if (d < 1000) return [NSString stringWithFormat:NSLocalizedString(@"n m format", nil), (unsigned int)(d + 0.5)];
		return [NSString stringWithFormat:NSLocalizedString(@"x with arbitrary decimal precision km format", nil), MAX(0, 2 - (NSInteger)(log10(d/1000.))), d/1000.];
	}
}

NSString *NSStringFromAltitude(CLLocationDistance a, BOOL useMiles) {
#warning "TODO: Use a NumberFormatter (or a distance formatter?)"
	NSString *formatNonLoc = @"x m format (altitude)";
	if (useMiles) {
		a /= ONE_FOOT_IN_METERS; /* a is now in feet */
		formatNonLoc = @"x ft format (altitude)";
	}
	
	return [NSString stringWithFormat:NSLocalizedString(formatNonLoc, nil), a + 0.5];
}

void objc_try(void (NS_NOESCAPE ^triedHandler)(void), void (NS_NOESCAPE ^caughtHandler)(NSException *e)) {
	@try {
		triedHandler();
	} @catch(NSException *e) {
		caughtHandler(e);
	}
}

#if 0
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
#endif

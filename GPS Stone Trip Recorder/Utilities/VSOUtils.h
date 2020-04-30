/*
 *  VSOUtils.h
 *  GPS Stone Trip Recorder
 *
 *  Created by François Lamboley on 7/16/09.
 *  Copyright 2009 VSO-Software. All rights reserved.
 *
 */

#import <CoreGraphics/CGBase.h>
#import <CoreLocation/CLLocation.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSString.h>
#include <stdlib.h>

#import "Constants.h"


/* Formats for NSLog for NSInteger, CGFloat, etc. */
#define CGFLOAT_FMT @"g"
/* See definition of NSUInteger to understand the test below */
#if __LP64__ || (TARGET_OS_EMBEDDED && !TARGET_OS_IPHONE) || TARGET_OS_WIN32 || NS_BUILD_32_LIKE_64
# define NSINT_FMT @"ld"
# define NSUINT_FMT @"lu"
#else
# define NSINT_FMT @"d"
# define NSUINT_FMT @"u"
#endif


#ifndef NDEBUG
# define NSDLog(format...) NSLog(format)
#else
# define NSDLog(format...) (void)NULL
#endif

/* One day, the XML log may be a file...
 * For now, replace 0 with 1 to have the XML logs! */
#if 1
# define NSXMLLog(format...) NSLog(format)
#else
# define NSXMLLog(format...) (void)NULL
#endif


BOOL isDeviceScreenTallerThanOriginalIPhone(void);

NSString *fullPathFromRelativeForGPXFile(NSString *relativePath);
NSString *relativePathFromFullForGPXFile(NSString *fullPath);

/* If lat is NO, we are treating longs! (used for the suffix: "N" or "E"... */
NSString *NSStringFromDegrees(CLLocationDegrees d, BOOL lat);
NSString *NSStringFromDirection(CLLocationDirection d);
NSString *NSStringFromDate(NSDate *date);
/* speed is in m/s */
NSString *NSStringFromSpeed(CLLocationSpeed speed, BOOL showUnit, BOOL useMiles);
/* i is assumed to be > 0 */
NSString *NSStringFromTimeInterval(NSTimeInterval i);
/* d is assumed to be > 0 */
NSString *NSStringFromDistance(CLLocationDistance d, BOOL useMiles);
NSString *NSStringFromAltitude(CLLocationDistance a, BOOL useMiles);


void objc_try(void (NS_NOESCAPE ^triedHandler)(void), void (NS_NOESCAPE ^caughtHandler)(NSException *e));

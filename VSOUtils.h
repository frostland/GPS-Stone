/*
 *  VSOUtils.h
 *  GPS Stone Trip Recorder
 *
 *  Created by François Lamboley on 7/16/09.
 *  Copyright 2009 VSO-Software. All rights reserved.
 *
 */

#import <Foundation/NSString.h>
#import <Foundation/NSDate.h>
#import <CoreLocation/CLLocation.h>
#include <stdlib.h>

#ifndef NDEBUG
#define NSDLog(format...) NSLog(format)
#else
#define NSDLog(format...) (void)NULL
#endif

/* One day, the XML log may be a file...
 * For now, replace 0 with 1 to have the XML logs! */
#if 1
#define NSXMLLog(format...) NSLog(format)
#else
#define NSXMLLog(format...) (void)NULL
#endif

NSString *fullPathFromRelativeForGPXFile(NSString *relativePath);
NSString *relativePathFromFullForGPXFile(NSString *fullPath);

/* If lat is NO, we are treating longs! (used for the suffix: "N" or "E"... */
NSString *NSStringFromDegrees(CLLocationDegrees d, BOOL lat);
NSString *NSStringFromDirection(CLLocationDirection d);
NSString *NSStringFromDate(NSDate *date);
/* speed is in m/s */
NSString *NSStringFromSpeed(CGFloat speed, BOOL showUnit);
/* i is assumed to be > 0 */
NSString *NSStringFromTimeInterval(NSTimeInterval i);
/* d is assumed to be > 0 */
NSString *NSStringFromDistance(CLLocationDistance d);
NSString *NSStringFromAltitude(CLLocationDistance a);

void *mallocTable(unsigned int size, size_t sizeOfElementsInTable);
void **malloc2DTable(unsigned int xSize, unsigned int ySize, size_t sizeOfElementsInTable);
void ***malloc3DTable(unsigned int xSize, unsigned int ySize, unsigned int zSize, size_t sizeOfElementsInTable);

void free2DTable(void **b, unsigned int xSize);
void free3DTable(void ***b, unsigned int xSize, unsigned int ySize);

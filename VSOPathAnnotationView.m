//
//  VSOPathAnnotationView.m
//  GPS Stone Trip Recorder
//
//  Created by François Lamboley on 8/7/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import <QuartzCore/CALayer.h>

#import "VSOPathAnnotationView.h"

#import "VSOUtils.h"
#import "Constants.h"

#define USER_LOCATION_VIEW_CENTER_DOT_SIZE 10.

@implementation VSOCurLocationAnnotationView

@synthesize precision;

- (id)initWithFrame:(CGRect)frame
{
	if (self = [super initWithFrame:frame]) {
		self.opaque = NO;
		self.contentMode = UIViewContentModeRedraw;
		self.backgroundColor = [UIColor clearColor];
		
		self.precision = 0.;
		self.layer.zPosition = 10000000.;
	}
	
	return self;
}

- (void)setFrame:(CGRect)f
{
	CGFloat s = MAX(USER_LOCATION_VIEW_CENTER_DOT_SIZE, precision + 3.);
	
	f.origin.x += (f.size.width -s)/2.;
	f.origin.y += (f.size.height-s)/2.;
	f.size.width = f.size.height = s;
	
	[super setFrame:f];
}

- (void)setPrecision:(CGFloat)p
{
	precision = p;
	
	[self setFrame:self.frame];
}

- (void)drawRect:(CGRect)rect
{
	NSDLog(@"Drawing a VSOCurLocationView with rect: %@", NSStringFromCGRect(rect));
	NSDLog(@"center is: %@", NSStringFromCGPoint(self.center));
	
	rect = self.bounds;
	CGPoint center = CGPointMake(rect.origin.x + rect.size.width/2., rect.origin.y + rect.size.height/2.);
	
	CGContextRef c = UIGraphicsGetCurrentContext();
	
	CGRect precisionRect = CGRectMake(center.x-precision/2., center.y-precision/2., precision, precision);
	UIColor *color = [UIColor colorWithRed:0.039215686 green:0.54509804 blue:1. alpha:1.];
	CGContextSetFillColorWithColor(c, [[color colorWithAlphaComponent:0.2] CGColor]);
	CGContextSetStrokeColorWithColor(c, [color CGColor]);
	CGContextSetLineWidth(c, 1.);
	
	CGContextFillEllipseInRect(c, precisionRect);
	CGContextStrokeEllipseInRect(c, precisionRect);
	
	CGContextSetFillColorWithColor(c, [color CGColor]);
	CGContextFillEllipseInRect(c, CGRectMake(center.x-USER_LOCATION_VIEW_CENTER_DOT_SIZE/2., center.y-USER_LOCATION_VIEW_CENTER_DOT_SIZE/2., USER_LOCATION_VIEW_CENTER_DOT_SIZE, USER_LOCATION_VIEW_CENTER_DOT_SIZE));
}

@end

#define VSO_BUFF_IMG_OFFSET 10
#define VSO_MAX_CACHE_IMAGE_SIDE 430
/*#define VSO_MAX_CACHE_IMAGE_SIDE 50*/

#pragma mark -
@interface VSOPathAnnotationView (Private)

- (void)setFrameRefreshingAnnotationCoordinate:(CGRect)newFrame;

- (void)addFirstPoint:(CGPoint)p;
- (void)setLineDash:(CGContextRef)c;
- (CGContextRef)getContextToDrawOffscreen:(CGPoint*)deltaToDrawCache sizeOfContext:(CGSize)s coordsOfLastPoint:(CGPoint)coordsOfLastPoint;
- (void)closeContextToDrawOffscreen:(CGContextRef)c;

@end

@implementation VSOPathAnnotationView (Private)

- (void)setFrameRefreshingAnnotationCoordinate:(CGRect)newFrame
{
	/* When changing the annotation.coordinate only, the view position is not changed!
	 * BUT, if we don't change the annotation.coordinate, when the map is scrolled, the frame is resetted so that
	 * the view is centered on annotation.coordinate */
	self.annotation.coordinate = [map convertPoint:CGPointMake(newFrame.origin.x + newFrame.size.width/2.,
																				  newFrame.origin.y + newFrame.size.height/2.)
									  toCoordinateFromView:self.superview];
	self.frame = newFrame;
}

- (void)addFirstPoint:(CGPoint)p
{
	assert(!firstPointAdded);
	
	firstPointAdded = YES;
	lastAddedPoint = CGPointMake(VSO_BUFF_IMG_OFFSET, VSO_BUFF_IMG_OFFSET);
	p.x -= VSO_BUFF_IMG_OFFSET;
	p.y -= VSO_BUFF_IMG_OFFSET;
	
	CGPoint origin = [self convertPoint:p toView:self.superview];
	[self setFrameRefreshingAnnotationCoordinate:CGRectMake(origin.x, origin.y, VSO_BUFF_IMG_OFFSET*2., VSO_BUFF_IMG_OFFSET*2.)];
}

- (void)setLineDash:(CGContextRef)c
{
	CGFloat dashDescr[2] = {12., 16.};
	CGContextSetLineDash(c, 0., dashDescr, sizeof(dashDescr)/sizeof(CGFloat));
}

- (CGContextRef)getContextToDrawOffscreen:(CGPoint*)deltaToDrawCache sizeOfContext:(CGSize)s coordsOfLastPoint:(CGPoint)coordsOfLastPoint
{
	CGRect r = CGRectMake(0., 0., s.width, s.height);
	if (s.width > VSO_MAX_CACHE_IMAGE_SIDE || s.height > VSO_MAX_CACHE_IMAGE_SIDE) {
		if (![[NSUserDefaults standardUserDefaults] boolForKey:VSO_UDK_MEMORY_WARNING_PATH_CUT_SHOWN]) {
			[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"memory performances", nil) message:NSLocalizedString(@"path cut", nil)
												delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"ok", nil), nil] show];
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:VSO_UDK_MEMORY_WARNING_PATH_CUT_SHOWN];
		}
		
		r.size = CGSizeMake(VSO_MAX_CACHE_IMAGE_SIDE, VSO_MAX_CACHE_IMAGE_SIDE);
		
		r.origin.x = MAX(0., coordsOfLastPoint.x - VSO_MAX_CACHE_IMAGE_SIDE/2.);
		r.origin.y = MAX(0., coordsOfLastPoint.y - VSO_MAX_CACHE_IMAGE_SIDE/2.);
		
		r.origin.x -= MAX(0., (r.origin.x+r.size.width)  - s.width);
		r.origin.y -= MAX(0., (r.origin.y+r.size.height) - s.height);
		
		deltaToDrawCache->x -= r.origin.x;
		deltaToDrawCache->y -= r.origin.y;
		
		[self setFrameRefreshingAnnotationCoordinate:CGRectMake(self.frame.origin.x + r.origin.x, self.frame.origin.y + r.origin.y, r.size.width, r.size.height)];
	}
	
	UIGraphicsBeginImageContext(r.size);
	CGContextRef c = UIGraphicsGetCurrentContext();
	
	/* Draw some red in bg for debug purpose */
/*	CGContextSetFillColorWithColor(c, [[UIColor colorWithRed:0.66078431 green:0.26862745 blue:0.4 alpha:0.75] CGColor]);
	CGContextFillRect(c, CGRectMake(0., 0., s.width, s.height));*/
	
	CGContextSetLineWidth(c, 5.);
	CGContextSetLineCap(c, kCGLineCapRound);
	CGContextSetLineJoin(c, kCGLineJoinRound);
	CGContextSetStrokeColorWithColor(c, [[UIColor colorWithRed:0.36078431 green:0.16862745 blue:0.6 alpha:0.75] CGColor]);
	
	[self.image drawAtPoint:*deltaToDrawCache];
	
	return c;
}

- (void)closeContextToDrawOffscreen:(CGContextRef)c
{
	/* Getting the image drawn */
	self.image = UIGraphicsGetImageFromCurrentImageContext();
	
#ifndef NDEBUG
	/* Saving PNG image for debugging purpose */
	[UIImagePNGRepresentation(self.image) writeToFile:@"/Users/francois/Desktop/tt.png" atomically:NO];
#endif
	/* Closing context */
	UIGraphicsEndImageContext();
	
	[self setNeedsDisplay];
}

@end

@implementation VSOPathAnnotationView

@synthesize map;
@dynamic annotation;

- (id)initWithFrame:(CGRect)frame
{
	if (self = [super initWithFrame:frame]) {
		self.opaque = NO;
		self.userInteractionEnabled = NO;
		self.backgroundColor = [UIColor clearColor];
		self.clearsContextBeforeDrawing = YES;
		
		self.image = [[UIImage new] autorelease];
		firstPointAdded = NO;
	}
	return self;
}

- (void)drawRect:(CGRect)r
{
	[self.image drawAtPoint:CGPointMake(0., 0.)];
	
#ifndef NDEBUG
	/* May be useful for debug purpose */
/*	CGContextRef c = UIGraphicsGetCurrentContext();
	CGContextSetFillColorWithColor(c, [[UIColor colorWithRed:0. green:0. blue:1. alpha:0.3] CGColor]);
	CGContextFillRect(c, r);*/
#endif
}

- (void)clearDrawnPoints
{
	firstPointAdded = NO;
	self.image = [[UIImage new] autorelease];
	[self setNeedsDisplay];
}

- (void)addCoords:(CLLocationCoordinate2D *)pts nCoords:(NSUInteger)nPoints bounds:(MKCoordinateRegion)bounds
{
	if (nPoints == 0) return;
	
	CGRect f = self.frame, nf;
	CGRect r = [map convertRegion:bounds toRectToView:self.superview];
	r.origin.x -= VSO_BUFF_IMG_OFFSET;
	r.origin.y -= VSO_BUFF_IMG_OFFSET;
	r.size.width  += 2.*VSO_BUFF_IMG_OFFSET;
	r.size.height += 2.*VSO_BUFF_IMG_OFFSET;
	nf.origin.x = MIN(r.origin.x, f.origin.x);
	nf.origin.y = MIN(r.origin.y, f.origin.y);
	if (r.origin.x + r.size.width > f.origin.x + f.size.width) nf.size.width = (r.origin.x + r.size.width) - nf.origin.x;
	else                                                       nf.size.width = (f.origin.x + f.size.width) - nf.origin.x;
	if (r.origin.y + r.size.height > f.origin.y + f.size.height) nf.size.height = (r.origin.y + r.size.height) - nf.origin.y;
	else                                                         nf.size.height = (f.origin.y + f.size.height) - nf.origin.y;
	[self setFrameRefreshingAnnotationCoordinate:nf];
	
	CGPoint delta = CGPointMake(f.origin.x - nf.origin.x, f.origin.y - nf.origin.y);
	CGContextRef c = [self getContextToDrawOffscreen:&delta sizeOfContext:nf.size coordsOfLastPoint:[map convertCoordinate:pts[nPoints-1] toPointToView:self]];
	
	[self setLineDash:c];
	CGPoint p = [map convertCoordinate:pts[0] toPointToView:self];
	if (firstPointAdded) {
		CGContextMoveToPoint(c, lastAddedPoint.x + delta.x, lastAddedPoint.y + delta.y);
		CGContextAddLineToPoint(c, p.x, p.y);
	}
	CGContextStrokePath(c);
	
	CGContextMoveToPoint(c, p.x, p.y);
	CGContextSetLineDash(c, 0., NULL, 0.);
	for (NSUInteger i = 1; i<nPoints; i++) {
		p = [map convertCoordinate:pts[i] toPointToView:self];
		CGContextAddLineToPoint(c, p.x, p.y);
	}
	CGContextStrokePath(c);
	
	lastAddedPoint = p;
	firstPointAdded = YES;
	
	[self closeContextToDrawOffscreen:c];
}

- (void)addPoint:(CGPoint)p createNewPath:(BOOL)createNew
{
	if (!firstPointAdded) {
		[self addFirstPoint:p];
		return;
	}
	
	CGRect f = self.frame;
	CGPoint delta = CGPointMake(0., 0.);
	if (p.x < VSO_BUFF_IMG_OFFSET) {
		delta.x = (NSUInteger)(-p.x + VSO_BUFF_IMG_OFFSET);
		f.origin.x -= delta.x;
		f.size.width += delta.x;
		p.x = VSO_BUFF_IMG_OFFSET;
	}
	if (p.y < VSO_BUFF_IMG_OFFSET) {
		delta.y = (NSUInteger)(-p.y + VSO_BUFF_IMG_OFFSET);
		f.origin.y -= delta.y;
		f.size.height += delta.y;
		p.y = VSO_BUFF_IMG_OFFSET;
	}
	if (p.x > f.size.width  - VSO_BUFF_IMG_OFFSET) f.size.width  = (NSUInteger)(p.x + VSO_BUFF_IMG_OFFSET);
	if (p.y > f.size.height - VSO_BUFF_IMG_OFFSET) f.size.height = (NSUInteger)(p.y + VSO_BUFF_IMG_OFFSET);
	[self setFrameRefreshingAnnotationCoordinate:f];
	
	CGPoint deltaAfterMaxCacheResize = delta;
	CGContextRef c = [self getContextToDrawOffscreen:&deltaAfterMaxCacheResize sizeOfContext:f.size coordsOfLastPoint:p];
	if (createNew) [self setLineDash:c];
	p.x -= delta.x - deltaAfterMaxCacheResize.x;
	p.y -= delta.y - deltaAfterMaxCacheResize.y;
	
	assert(firstPointAdded);
	CGContextMoveToPoint(c, lastAddedPoint.x + deltaAfterMaxCacheResize.x, lastAddedPoint.y + deltaAfterMaxCacheResize.y);
	CGContextAddLineToPoint(c, p.x, p.y);
	CGContextStrokePath(c);
	
	lastAddedPoint = p;
	
	[self closeContextToDrawOffscreen:c];
}

- (void)dealloc
{
	NSDLog(@"Deallocing a VSOPathAnnotationView");
	
	self.image = nil;
	/* map not release: assigned */
	
	[super dealloc];
}

@end

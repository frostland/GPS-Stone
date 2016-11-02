//
//  link.h
//  GPS Stone Trip Recorder
//
//  Created by François Lamboley on 7/30/09.
//  Copyright 2009 VSO-Software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XMLElement.h"

@interface GPXlinkType : XMLElement {
	NSString *href;
}
@property(nonatomic, retain) NSString *href;

@end

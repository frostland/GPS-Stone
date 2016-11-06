/*
 * XMLStringElement.h
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/29/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 */

#import <Foundation/Foundation.h>

#import "XMLElement.h"



@interface XMLStringElement : XMLElement

@property(nonatomic, retain) NSString *content;

@end

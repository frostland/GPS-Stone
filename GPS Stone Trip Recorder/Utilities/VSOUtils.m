/*
 * VSOUtils.m
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 7/16/09.
 * Copyright 2009 VSO-Software. All rights reserved.
 *
 */

#import <Foundation/Foundation.h>

#include "VSOUtils.h"



void objc_try(void (NS_NOESCAPE ^triedHandler)(void), void (NS_NOESCAPE ^caughtHandler)(NSException *e)) {
	@try {
		triedHandler();
	} @catch(NSException *e) {
		caughtHandler(e);
	}
}

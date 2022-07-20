/*
 * TimeSegment+Utils.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2020/5/15.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import Foundation



extension TimeSegment {
	
	var isOpen: Bool {
		return duration == nil
	}
	
	var endDate: Date? {
		guard let startDate = startDate, let duration = duration?.doubleValue else {
			return nil
		}
		guard duration.sign == .plus else {
			NSLog("***** ERROR - Got an invalid time segment (duration is not positive): %@", self)
			return nil
		}
		return startDate + TimeInterval(duration)
	}
	
	/**
	 The duration of a time segment, even if the time segment is unfinished.
	 
	 A time segment can have a `nil` duration, in which case it is considered “unfinished,”
	  and its effective duration is the time interval between the start date and now,
	  unless the time segment starts in the future, in which case its effective duration is 0.
	 
	 - Note: If the time segment does not have a start date (which is invalid), its effective duration will be 0 (and a message will be logged).
	 
	 - Note: No validation is done on the duration: if the time segment has an invalid duration (negative), the effectiveDuration _will_ be negative too. */
	var effectiveDuration: TimeInterval {
		if let effectiveDuration = duration?.doubleValue {
			return TimeInterval(effectiveDuration)
		} else {
			guard let startDate = startDate else {
				NSLog("***** ERROR - Got an invalid time segment (nil startDate): %@", self)
				return 0
			}
			return max(0, -startDate.timeIntervalSinceNow)
		}
	}
	
	func closeTimeSegment() {
		if let startDate = startDate {
			duration = NSNumber(value: -startDate.timeIntervalSinceNow)
		} else {
			NSLog("***** ERROR: Given time segment does not have a start date. We will set the time segment’s duration to an arbitrary 1s.")
			startDate = Date(timeIntervalSinceNow: -1)
			duration = NSNumber(value: 1)
		}
	}
	
	/**
	 Check whether the given date is contained in the receiver.
	 
	 - Returns: `true` if yes, `false` if no, `nil` if the receiver is invalid (does not have a start date). */
	func contains(_ date: Date) -> Bool? {
		guard let startDate = startDate else {
			return nil
		}
		guard date >= startDate else {return false}
		if let endDate = endDate {return date <= endDate}
		else                     {return false}
	}
	
	/**
	 Check whether the given time segment is contained in the receiver.
	 
	 - Returns: `true` if yes, `false` if no, `nil` if either time segment is invalid (does not have a start date). */
	func contains(_ otherTimeSegment: TimeSegment) -> Bool? {
		guard let myStartDate = startDate, let otherStartDate = otherTimeSegment.startDate else {
			return nil
		}
		
		guard myStartDate <= otherStartDate else {
			return false
		}
		
		switch (endDate, otherTimeSegment.endDate) {
		case (nil,            _):                 return true
		case (.some,          nil):               return false
		case (let myEndDate?, let otherEndDate?): return myEndDate >= otherEndDate
		}
	}
	
	/**
	 Check whether the given time segment intersects the receiver.
	 
	 - Returns: `true` if yes, `false` if no, `nil` if either time segment is invalid (does not have a start date). */
	func intersects(_ otherTimeSegment: TimeSegment) -> Bool? {
		guard let myStartDate = startDate, let otherStartDate = otherTimeSegment.startDate else {
			return nil
		}
		
		switch (endDate, otherTimeSegment.endDate) {
		case (nil,            nil):               return true
		case (nil,            let otherEndDate?): return otherEndDate >= myStartDate
		case (let myEndDate?, nil):               return myEndDate >= otherStartDate
		case (let myEndDate?, let otherEndDate?):
			/* This assert is valid thanks to the endDate implementation. */
			assert(myStartDate <= myEndDate && otherStartDate <= otherEndDate)
			return (
				(otherStartDate <= myStartDate && otherEndDate   >= myStartDate) || /* Cases 2 and 5 */
				(otherStartDate >= myStartDate && otherStartDate <= myEndDate)      /* Cases 3 and 4 */
				/* (Cases 1 and 6 are non-intersection cases.) */
			)
		}
	}
	
}

/*
 * LocationRecorder.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/5/31.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation



/* Inherits from NSObject to allow KVO on the instances */
class LocationRecorder : NSObject, CLLocationManagerDelegate {
	
	@objc dynamic private(set) var currentRecordingInfo: RecordingInfo?
	
	@objc dynamic private(set) var currentHeading: CLHeading?
	@objc dynamic private(set) var currentLocation: CLLocation?
	
	init(locationManager: CLLocationManager) {
		lm = locationManager
		
		super.init()
		
		lm.delegate = self
	}
	
	/* *********************************
	   MARK: - Location Manager Delegate
	   ********************************* */
	
	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		currentLocation = nil
	}
	
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		assert(Thread.isMainThread)
		
		guard let location = locations.last else {return}
		if location.horizontalAccuracy.sign == .plus {currentLocation = location}
		else                                         {currentLocation = nil}
	}
	
	func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
		assert(Thread.isMainThread)
		
		if newHeading.headingAccuracy.sign == .plus {currentHeading = newHeading}
		else                                        {currentHeading = nil}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private enum Status {
		
		case idle
		case trackingUserPosition
		
		var isTrackingUserPosition: Bool {
			switch self {
			case .idle:                 return false
			case .trackingUserPosition: return true
			}
		}
		
	}
	
	/* *** Dependencies *** */
	
	let lm: CLLocationManager
	
	private var status = Status.idle {
		willSet {
			if newValue.isTrackingUserPosition && !status.isTrackingUserPosition {
				lm.requestWhenInUseAuthorization()
				lm.startUpdatingLocation()
				lm.startUpdatingHeading()
			} else if !newValue.isTrackingUserPosition && status.isTrackingUserPosition {
				lm.stopUpdatingHeading()
				lm.stopUpdatingLocation()
			}
		}
	}
	
}

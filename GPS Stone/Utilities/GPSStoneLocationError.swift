/*
 * GPSStoneLocationError.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2020/8/9.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation



enum GPSStoneLocationError : Error {
	
	case locationNotFoundYet
	case locationManagerPausedUpdates
	case permissionDenied
	case locationServicesDisabled
	case unknown(underlyingError: Error)
	
	init(error: Error?) {
		if let error = error as NSError? {
			switch (error.domain, error.code, CLLocationManager.locationServicesEnabled()) {
				case (LocationRecorder.errorDomain, LocationRecorder.errorCodeLocationManagerPausedUpdates, _): self = .locationManagerPausedUpdates
				case (kCLErrorDomain, CLError.Code.locationUnknown.rawValue, _):                                self = .locationNotFoundYet
				case (kCLErrorDomain, CLError.Code.denied.rawValue, true):                                      self = .permissionDenied
				case (kCLErrorDomain, CLError.Code.denied.rawValue, false):                                     self = .locationServicesDisabled
				default:                                                                                        self = .unknown(underlyingError: error)
			}
		} else {
			self = .locationNotFoundYet
		}
	}
	
	var localizedDescription: String {
		switch self {
			case .locationNotFoundYet:          return NSLocalizedString("getting loc", comment: "The message shown to the user when no GPS info are available yet, but there are no errors getting the user’s position.")
			case .locationServicesDisabled:     return NSLocalizedString("location services disabled", comment: "The message shown to the user when no GPS info because the location services are disabled.")
			case .locationManagerPausedUpdates: return NSLocalizedString("location updates are paused", comment: "The message shown to the user when no GPS info because the system paused location updates for battery reasons.")
			case .permissionDenied:             return NSLocalizedString("error getting location: denied", comment: "The message shown to the user when no GPS info because the permission was denied.")
			case .unknown(let e):               return NSLocalizedString("unknown error getting location", comment: "The message shown to the user when no GPS info because of an unknown error.").applyingCommonTokens(simpleReplacement1: e.localizedDescription)
		}
	}
	
	var isLocationNotFoundYet: Bool {
		if case .locationNotFoundYet = self {return true}
		return false
	}
	
	var isPermissionDeniedError: Bool {
		if case .permissionDenied = self {return true}
		return false
	}
	
	var isUpdatesPaused: Bool {
		if case .locationManagerPausedUpdates = self {return true}
		return false
	}
	
}

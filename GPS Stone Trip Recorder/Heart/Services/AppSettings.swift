/*
 * AppSettings.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/5/30.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation
import MapKit



final class AppSettings {
	
	enum DistanceUnit : Int {
		case automatic = 255
		case metric    = 0
		case imperial  = 1
	}
	
	let ud: UserDefaults
	
	init(userDefaults: UserDefaults = .standard) {
		ud = userDefaults
	}
	
	func registerDefaultSettings() {
		/* Registering default user defaults */
		let defaultValues: [SettingsKey: Any?] = [
			.firstRun: true,
			.firstUnlock: true,
			
			.selectedPage: 0,
			.latestMapRect: nil,
			.followLocationOnMap: true,
			.mapSwipeWarningShown: false,
			
			.mapType: MKMapType.standard.rawValue,
			.mapRegion: nil,
			
			.showMemoryClearWarning: true,
			.memoryWarningPathCutShown: false,
			
			.pauseOnQuit: true,
			.skipNonAccuratePoints: false,
			.minPathDistance: CLLocationDistance(25),
			.minTimeForUpdate: TimeInterval(2),
			.distanceUnit: DistanceUnit.automatic.rawValue
		]
		
		/* Let’s make sure all the cases have been registered in the defaults. */
		for k in SettingsKey.allCases {
			switch defaultValues[k] {
				case .none: fatalError("No default value for default key “\(k)”")
				case .some: (/*nop*/)
			}
		}
		
		var defaultValuesNoNull = [String: Any]()
		for (key, val) in defaultValues {
			guard let val = val else {continue}
			defaultValuesNoNull[key.rawValue] = val
		}
		ud.register(defaults: defaultValuesNoNull)
	}
	
	func forceSettingsSynchronization() {
		ud.synchronize()
	}
	
	/* **************************
	   MARK: - Settings Accessors
	   ************************** */
	
	var firstRun: Bool {
		get {return ud.bool(forKey: SettingsKey.firstRun.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.firstRun.rawValue)}
	}
	
	var firstUnlock: Bool {
		get {return ud.bool(forKey: SettingsKey.firstRun.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.firstRun.rawValue)}
	}
	
	var selectedPage: Int {
		get {return ud.integer(forKey: SettingsKey.selectedPage.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.selectedPage.rawValue)}
	}
	
	var latestMapRect: MKCoordinateRegion? {
		get {
			guard let data = ud.data(forKey: SettingsKey.latestMapRect.rawValue) else {
				return nil
			}
			
			let unarchiver = NSKeyedUnarchiver(forReadingWith: data)
			defer {unarchiver.finishDecoding()}
			
			let latitude = unarchiver.decodeDouble(forKey: "latitude")
			let longitude = unarchiver.decodeDouble(forKey: "longitude")
			let latitudeDelta = unarchiver.decodeDouble(forKey: "latitudeDelta")
			let longitudeDelta = unarchiver.decodeDouble(forKey: "longitudeDelta")
			
			guard !latitude.isZero || !longitude.isZero || !latitudeDelta.isZero || !longitudeDelta.isZero else {
				return nil
			}
			
			return MKCoordinateRegion(
				center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
				span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
			)
		}
		set {
			guard let rect = newValue else {
				ud.removeObject(forKey: SettingsKey.latestMapRect.rawValue)
				return
			}
			
			let data = NSMutableData()
			let archiver = NSKeyedArchiver(forWritingWith: data)
			archiver.encode(rect.center.latitude, forKey: "latitude")
			archiver.encode(rect.center.longitude, forKey: "longitude")
			archiver.encode(rect.span.latitudeDelta, forKey: "latitudeDelta")
			archiver.encode(rect.span.longitudeDelta, forKey: "longitudeDelta")
			archiver.finishEncoding()
			
			ud.set(data, forKey: SettingsKey.latestMapRect.rawValue)
		}
	}
	
	var followLocationOnMap: Bool {
		get {return ud.bool(forKey: SettingsKey.followLocationOnMap.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.followLocationOnMap.rawValue)}
	}
	
	var mapSwipeWarningShown: Bool {
		get {return ud.bool(forKey: SettingsKey.mapSwipeWarningShown.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.mapSwipeWarningShown.rawValue)}
	}
	
	var mapType: MKMapType {
		get {return MKMapType(rawValue: UInt(ud.integer(forKey: SettingsKey.mapType.rawValue))) ?? .standard}
		set {ud.set(newValue.rawValue, forKey: SettingsKey.mapType.rawValue)}
	}
	
	var mapRegion: MKCoordinateRegion? {
		get {
			guard let data = ud.data(forKey: SettingsKey.mapRegion.rawValue) else {return nil}
			
			return data.withUnsafeBytes{ pointer in
				return pointer.bindMemory(to: MKCoordinateRegion.self).baseAddress!.pointee
			}
		}
		set {
			guard var region = newValue else {ud.removeObject(forKey: SettingsKey.mapRegion.rawValue); return}
			
			let data = Data(bytes: &region, count: MemoryLayout<MKCoordinateRegion>.size)
			ud.set(data, forKey: SettingsKey.mapRegion.rawValue)
		}
	}
	
	var showMemoryClearWarning: Bool {
		get {return ud.bool(forKey: SettingsKey.showMemoryClearWarning.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.showMemoryClearWarning.rawValue)}
	}
	
	var memoryWarningPathCutShown: Bool {
		get {return ud.bool(forKey: SettingsKey.memoryWarningPathCutShown.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.memoryWarningPathCutShown.rawValue)}
	}
	
	var pauseOnQuit: Bool {
		get {return ud.bool(forKey: SettingsKey.pauseOnQuit.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.pauseOnQuit.rawValue)}
	}
	
	var skipNonAccuratePoints: Bool {
		get {return ud.bool(forKey: SettingsKey.skipNonAccuratePoints.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.skipNonAccuratePoints.rawValue)}
	}
	
	var minPathDistance: CLLocationDistance {
		get {return ud.double(forKey: SettingsKey.minPathDistance.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.minPathDistance.rawValue)}
	}
	
	var minTimeForUpdate: TimeInterval {
		get {return ud.double(forKey: SettingsKey.minTimeForUpdate.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.minTimeForUpdate.rawValue)}
	}
	
	var distanceUnit: DistanceUnit {
		get {return DistanceUnit(rawValue: ud.integer(forKey: SettingsKey.distanceUnit.rawValue)) ?? .automatic}
		set {ud.set(newValue.rawValue, forKey: SettingsKey.distanceUnit.rawValue)}
	}
	
	var useMetricSystem: Bool {
		switch distanceUnit {
			case .metric:    return true
			case .imperial:  return false
			case .automatic: return Locale.autoupdatingCurrent.usesMetricSystem
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private enum SettingsKey : String, CaseIterable {
		
		case firstRun = "VSO First Run"
		case firstUnlock = "VSO Screen Never Locked While This App Is Launched"
		
		case selectedPage = "VSO Selected Page"
		case latestMapRect = "VSO Latest Map Rect"
		case followLocationOnMap = "VSO Follow Location On Map"
		case mapSwipeWarningShown = "VSO Map Swipe Warning Was Shown"
		
		case mapType = "VSO Map Type"
		case mapRegion = "VSO Map Region"
		
		case showMemoryClearWarning = "VSO Stored Points Clearing Wrarning"
		case memoryWarningPathCutShown = "VSO Path Cut Memory Warning Shown"
		
		case pauseOnQuit = "VSO Pause When Quitting Instead Of Stopping"
		case skipNonAccuratePoints = "VSO Skip Non Accurate Points"
		case minPathDistance = "VSO Min Distance Before Adding Point"
		case minTimeForUpdate = "VSO Min Time Between Updates"
		case distanceUnit = "VSO Distance Unit"
		
	}
	
}

/*
 * AppSettings.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2019/5/30.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation
import MapKit



/** A wrapper around UserDefaults for our App Settings.

Will post a notification when the settings are changed through this object. The
notification is posted whether the setting was actually changed or not. But will
**not** post a notification if the user defaults are modified without using this
object. */
final class AppSettings {
	
	static let changedNotification = Notification.Name(Constants.appDomain + ".AppSettings.ChangedNotif")
	
	enum DistanceUnit : Int {
		case automatic = 255
		case metric    = 0
		case imperial  = 1
	}
	
	let ud: UserDefaults
	let nc: NotificationCenter
	
	init(userDefaults: UserDefaults = .standard, notificationCenter: NotificationCenter = .default) {
		ud = userDefaults
		nc = notificationCenter
	}
	
	func registerDefaultSettings() {
		/* Registering default user defaults */
		let defaultValues: [SettingsKey: Any?] = [
			.selectedPage: 0,
			.latestMapRegion: nil,
			.followLocationOnMap: true,
			
			.mapType: MKMapType.standard.rawValue,
			.mapRegion: nil,
			
			.useBestGPSAccuracy: false,
			.distanceFilter: CLLocationDistance(5),
			.distanceUnit: DistanceUnit.automatic.rawValue,
			
			.askBeforePausingOrStopping: true,
			
			.lastVersionRateAsked: nil,
			.numberOfRecordingsSinceLastAskedToRate: 0
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
	
	var selectedPage: Int {
		get {ud.integer(forKey: SettingsKey.selectedPage.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.selectedPage.rawValue); nc.post(name: AppSettings.changedNotification, object: self)}
	}
	
	var latestMapRegion: MKCoordinateRegion? {
		get {
			guard let data = ud.data(forKey: SettingsKey.latestMapRegion.rawValue) else {
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
			defer {
				nc.post(name: AppSettings.changedNotification, object: self)
			}
			
			guard let rect = newValue else {
				ud.removeObject(forKey: SettingsKey.latestMapRegion.rawValue)
				return
			}
			
			let data = NSMutableData()
			let archiver = NSKeyedArchiver(forWritingWith: data)
			archiver.encode(rect.center.latitude, forKey: "latitude")
			archiver.encode(rect.center.longitude, forKey: "longitude")
			archiver.encode(rect.span.latitudeDelta, forKey: "latitudeDelta")
			archiver.encode(rect.span.longitudeDelta, forKey: "longitudeDelta")
			archiver.finishEncoding()
			
			ud.set(data, forKey: SettingsKey.latestMapRegion.rawValue)
		}
	}
	
	var followLocationOnMap: Bool {
		get {ud.bool(forKey: SettingsKey.followLocationOnMap.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.followLocationOnMap.rawValue); nc.post(name: AppSettings.changedNotification, object: self)}
	}
	
	var mapType: MKMapType {
		get {MKMapType(rawValue: UInt(ud.integer(forKey: SettingsKey.mapType.rawValue))) ?? .standard}
		set {ud.set(newValue.rawValue, forKey: SettingsKey.mapType.rawValue); nc.post(name: AppSettings.changedNotification, object: self)}
	}
	
	var mapRegion: MKCoordinateRegion? {
		get {
			guard let data = ud.data(forKey: SettingsKey.mapRegion.rawValue) else {return nil}
			
			return data.withUnsafeBytes{ pointer in
				return pointer.bindMemory(to: MKCoordinateRegion.self).baseAddress!.pointee
			}
		}
		set {
			defer {nc.post(name: AppSettings.changedNotification, object: self)}
			guard var region = newValue else {ud.removeObject(forKey: SettingsKey.mapRegion.rawValue); return}
			
			let data = Data(bytes: &region, count: MemoryLayout<MKCoordinateRegion>.size)
			ud.set(data, forKey: SettingsKey.mapRegion.rawValue)
		}
	}
	
	var useBestGPSAccuracy: Bool {
		get {ud.bool(forKey: SettingsKey.useBestGPSAccuracy.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.useBestGPSAccuracy.rawValue); nc.post(name: AppSettings.changedNotification, object: self)}
	}
	
	var askBeforePausingOrStopping: Bool {
		get {ud.bool(forKey: SettingsKey.askBeforePausingOrStopping.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.askBeforePausingOrStopping.rawValue); nc.post(name: AppSettings.changedNotification, object: self)}
	}
	
	var distanceFilter: CLLocationDistance {
		get {ud.double(forKey: SettingsKey.distanceFilter.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.distanceFilter.rawValue); nc.post(name: AppSettings.changedNotification, object: self)}
	}
	
	var distanceUnit: DistanceUnit {
		get {DistanceUnit(rawValue: ud.integer(forKey: SettingsKey.distanceUnit.rawValue)) ?? .automatic}
		set {ud.set(newValue.rawValue, forKey: SettingsKey.distanceUnit.rawValue); nc.post(name: AppSettings.changedNotification, object: self)}
	}
	
	var useMetricSystem: Bool {
		switch distanceUnit {
			case .metric:    return true
			case .imperial:  return false
			case .automatic: return Locale.autoupdatingCurrent.usesMetricSystem
		}
	}
	
	var lastVersionRateAsked: String? {
		get {ud.string(forKey: SettingsKey.lastVersionRateAsked.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.lastVersionRateAsked.rawValue)}
	}
	
	var numberOfRecordingsSinceLastAskedToRate: Int {
		get {ud.integer(forKey: SettingsKey.numberOfRecordingsSinceLastAskedToRate.rawValue)}
		set {ud.set(newValue, forKey: SettingsKey.numberOfRecordingsSinceLastAskedToRate.rawValue); nc.post(name: AppSettings.changedNotification, object: self)}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private enum SettingsKey : String, CaseIterable {
		
		case selectedPage = "VSO Selected Page"
		case latestMapRegion = "VSO Latest Map Region"
		case followLocationOnMap = "VSO Follow Location On Map"
		
		case mapType = "VSO Map Type"
		case mapRegion = "VSO Map Region"
		
		case useBestGPSAccuracy = "VSO Use Best GPS Accuracy"
		case distanceFilter = "VSO Distance Filter"
		case distanceUnit = "VSO Distance Unit"
		
		case askBeforePausingOrStopping = "VSO Ask Before Pausing or Stopping"
		
		case lastVersionRateAsked = "FRL Last Version Rate Asked"
		case numberOfRecordingsSinceLastAskedToRate = "FRL Number of Recordings Since Last Asked to Rate"
		
	}
	
}

/*
 * Constants.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/5/30.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation



final class Constants {
	
	/**
	The domain to use for notification names, error domains, etc. We do notuse
	the bundle ID of the app because the app is now owned by Frost Land, not VSO
	Software. */
	static let appDomain = "fr.frostland.GPSStone"
	
	let mainDataDir: URL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
	private(set) lazy var urlToCoreDataStore:        URL = { return mainDataDir.appendingPathComponent("db", isDirectory: false) }()
	private(set) lazy var urlToCurrentRecordingInfo: URL = { return mainDataDir.appendingPathComponent("Current Recording Info.plist", isDirectory: false) }()
	
	let accuracyWarningThreshold = CLLocationDistance(50)
	
	/* Constants for UI */
	let pageNumberWithMap = 2
	let pageNumberWithDetailedInfo = 1
	let animTime = TimeInterval(0.25)
	
}

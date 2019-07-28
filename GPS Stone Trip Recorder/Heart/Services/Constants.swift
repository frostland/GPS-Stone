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
	
	let mainDataDir: URL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
	private(set) lazy var urlToCoreDataStore:        URL = { return mainDataDir.appendingPathComponent("db", isDirectory: false) }()
	private(set) lazy var urlToNiceExitWitness:      URL = { return mainDataDir.appendingPathComponent("Unclean Exit Witness.witness", isDirectory: false) }()
	private(set) lazy var urlToCurrentRecordingInfo: URL = { return mainDataDir.appendingPathComponent("Current Recording Info.plist", isDirectory: false) }()
	private(set) lazy var urlToFolderWithGPXFiles:   URL = { return mainDataDir.appendingPathComponent("GPX Files", isDirectory: true) }()
	private(set) lazy var urlToPausedRecWitness:     URL = { return mainDataDir.appendingPathComponent("Last Recording Is Paused.witness", isDirectory: false) }()
	func urlToGPX(number: Int) -> URL {
		return urlToFolderWithGPXFiles.appendingPathComponent("Recording #\(number)", isDirectory: false).appendingPathExtension("gpx")
	}
	
	let maxAccuracyToRecordPoint = CLLocationDistance(50)
	
	/* Constants for UI */
	let pageNumberWithMap = 2
	let pageNumberWithDetailedInfo = 1
	let animTime = TimeInterval(0.3)
	
}

/*
 * Constants.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/5/30.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation



class Constants {
	
	let oneMileInKilometer = Double(1.609344)
	let oneFootInMeters = Double(0.3048)
	
	let coordPrintFormat = "%.10f"
	
	let mainDataDir: URL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
	private(set) lazy var urlToNiceExitWitness:    URL = { return mainDataDir.appendingPathComponent("Unclean Exit Witness.witness", isDirectory: false) }()
	private(set) lazy var urlToFolderWithGPXFiles: URL = { return mainDataDir.appendingPathComponent("GPX Files", isDirectory: true) }()
	private(set) lazy var urlToGPXList:            URL = { return urlToFolderWithGPXFiles.appendingPathComponent("GPX Files List Description.data", isDirectory: false) }()
	private(set) lazy var urlToPausedRecWitness:   URL = { return urlToFolderWithGPXFiles.appendingPathComponent("Last Recording Is Paused.witness", isDirectory: false) }()
	func urlToGPX(number: Int) -> URL {
		return urlToFolderWithGPXFiles.appendingPathComponent("Recording #\(number)", isDirectory: false).appendingPathExtension("gpx")
	}
	
	let maxAccuracyToRecordPoint = CLLocationDistance(50)
	
	/* Constants for the GPX List file format */
	let recListDateEndKey = "Date"
	let recListPathKey = "Rec Path"
	let recListNameKey = "Recording Name"
	let recListTotalRecTimeKey = "Total Record Time"
	let recListTotalRecTimeBeforeLastPauseKey = "Total Record Time Before Last Pause"
	let recListTotalRecDistanceKey = "Total Record Distance"
	let recListMaxSpeedKey = "Max Reached Speed"
	let recListAverageSpeedKey = "Average Speed"
	let recListNRegPointsKey = "N Points Recorded"
	let recListRecordStateKey = "Record State"
	func recListStoredPoints(for c: AnyClass) -> String {
		return "Stored Points For Class " + NSStringFromClass(c)
	}
	
	/* Constants for UI */
	let pageNumberWithMap = 2
	let pageNumberWithDetailedInfo = 1
	let animTime = TimeInterval(0.3)
	
	/* Constants for the names of the notifications */
	let ntfSettingsChanged = "VSO App Settings Changed"
}

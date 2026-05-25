import CoreLocation
import Foundation

import GlobalConfModule



final class Constants: Sendable {
	
	/**
	 The domain to use for notification names, error domains, etc.
	 We do not use the bundle ID of the app because the app is now owned by Frost Land, not VSO Software. */
	static let appDomain = "fr.frostland.GPSStone"
	
	let appID = Bundle.main.infoDictionary!["FRLAppleAppID"] as! String
	
	let mainDataDir: URL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
	let urlToCoreDataStore: URL
	let urlToCurrentRecordingInfo: URL
	
	let accuracyWarningThreshold = CLLocationDistance(50)
	
	/* Constants for UI. */
	let pageNumberWithMap = 2
	let pageNumberWithDetailedInfo = 1
	let animTime = TimeInterval(0.25)
	
	init() {
		self.urlToCoreDataStore        = mainDataDir.appendingPathComponent("db.sqlite", isDirectory: false)
		self.urlToCurrentRecordingInfo = mainDataDir.appendingPathComponent("Current Recording Info.plist", isDirectory: false)
	}
	
}


extension ConfKeys {
	#declareServiceKey(visibility: .internal, "constants", Constants.self, defaultValue: Constants())
}

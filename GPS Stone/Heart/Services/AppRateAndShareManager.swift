/*
 * AppRateAndShareManager.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2020/11/7.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import Foundation
import StoreKit



final class AppRateAndShareManager {
	
	init(constants: Constants, appSettings: AppSettings) {
		c = constants
		s = appSettings
	}
	
	func recordingDidStop() {
		guard s.lastVersionRateAsked != appVersion else {return}
		
		s.numberOfRecordingsSinceLastAskedToRate += 1
		if s.numberOfRecordingsSinceLastAskedToRate >= 3 {
			s.numberOfRecordingsSinceLastAskedToRate = 0
			askForReviewIfNotDoneAlreadyForThisRelease()
		}
	}
	
	func wentFromRecordingBackToList(after duration: TimeInterval) {
		/* We estimate if the user stayed on the recording for more than 5 secs he found something he liked, so we ask for review now. */
		if duration > 5 {
			askForReviewIfNotDoneAlreadyForThisRelease()
		}
	}
	
	var rateAppURL: URL {
		/* This URL apparently works for directly rating the app from iOS 8, all the way up to the current iOS version at the time of writing. */
		var urlComponents = URLComponents(url: baseAppAppStoreURL, resolvingAgainstBaseURL: true)!
		urlComponents.queryItems = (urlComponents.queryItems ?? []) + [URLQueryItem(name: "action", value: "write-review")]
		return urlComponents.url!
	}
	
	var shareAppURL: URL {
		return baseAppAppStoreURL
	}
	
	private let c: Constants
	private let s: AppSettings
	
	private var appVersion: String {
		return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
	}
	
	private var baseAppAppStoreURL: URL {
		let escapedAppID = c.appID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
		return URL(string: "itms-apps://itunes.apple.com/app/id\(escapedAppID)")!
	}
	
	private func askForReviewIfNotDoneAlreadyForThisRelease() {
		guard s.lastVersionRateAsked != appVersion else {return}
		if #available(iOS 10.3, *) {
			SKStoreReviewController.requestReview()
			s.lastVersionRateAsked = appVersion
		}
	}
	
}

/*
 * ServicesProvider.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/5/30.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import Foundation



/** Static class to give a convenient way of accessing the services provider. */
class S {
	
	static let sp = ServicesProvider()
	
}


/** The default services provider for GPS Stone Trip Recorder. */
class ServicesProvider {
	
	private(set) lazy var constants = Constants()
	private(set) lazy var appSettings = AppSettings(userDefaults: UserDefaults.standard)
	
}

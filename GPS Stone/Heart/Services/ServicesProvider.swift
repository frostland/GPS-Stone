/*
 * ServicesProvider.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2019/5/30.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation



/** Static class to give a convenient way of accessing the services provider. */
class S {
	
	static let sp = ServicesProvider()
	
}


/** The default services provider for GPS Stone. */
class ServicesProvider {
	
	private(set) lazy var constants = Constants()
	private(set) lazy var appSettings = AppSettings(userDefaults: UserDefaults.standard)
	
	private(set) lazy var dataHandler = DataHandler(constants: constants)
	private(set) lazy var recordingsManager = RecordingsManager(dataHandler: dataHandler)
	private(set) lazy var locationRecorder = LocationRecorder(locationManager: CLLocationManager(), recordingsManager: recordingsManager, dataHandler: dataHandler, appSettings: appSettings, constants: constants)
	
}

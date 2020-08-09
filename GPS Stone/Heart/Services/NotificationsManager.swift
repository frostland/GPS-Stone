/*
 * NotificationsManager.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2020/8/8.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import Foundation

import KVObserver



final class NotificationsManager {
	
	init(locationRecorder: LocationRecorder) {
		assert(Thread.isMainThread)
		lr = locationRecorder
		
		_ = kvObserver.observe(object: locationRecorder, keyPath: #keyPath(LocationRecorder.objc_recStatus), kvoOptions: [.initial], dispatchType: .asyncOnMainQueueDirectInitial, handler: { [weak self] _ in
			guard let self = self else {return}
			guard self.lr.recStatus.isRecording else {return}
			
			#warning("TODO: Ask for push authorization")
			print("ASK FOR PUSH")
		})
		
		/* This observer will trigger a notification when the system pauses
		 * location updates to keep the user up-to-date. */
		_ = kvObserver.observe(object: lr, keyPath: #keyPath(LocationRecorder.currentLocation), kvoOptions: [.initial, .old], dispatchType: .asyncOnMainQueueDirectInitial, handler: { [weak self] observationInfo in
			guard let self = self else {return}
			guard !self.lr.recStatus.isStopped else {return}
			guard self.lr.currentLocation == nil else {return}
			/* If the previous current location was already nil, we do nothing. */
			guard observationInfo?[.oldKey].flatMap({ ($0 as? NSNull) == nil }) ?? true else {return}
			
			let locError = GPSStoneLocationError(error: self.lr.currentLocationManagerError)
			guard locError.isUpdatesPaused else {return}
			
			/* Let’s show a notif to the user to inform it loc updates are paused. */
			#warning("TODO: Show the notif")
		})
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let kvObserver = KVObserver()
	
	/* *** Dependencies *** */
	
	private let lr: LocationRecorder
	
}

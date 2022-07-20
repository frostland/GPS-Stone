/*
 * NotificationsManager.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2020/8/8.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import Foundation
import UIKit /* For pre-iOS 10 notification registtration. */
import UserNotifications

import KVObserver



final class NotificationsManager {
	
	init(locationRecorder: LocationRecorder) {
		assert(Thread.isMainThread)
		lr = locationRecorder
		
		var isRecordingObservingId: KVObserver.ObservingId!
		isRecordingObservingId = kvObserver.observe(object: locationRecorder, keyPath: #keyPath(LocationRecorder.objc_recStatus), kvoOptions: [.initial], dispatchType: .asyncOnMainQueue, handler: { [weak self] _ in
			guard let self = self else {return}
			guard self.lr.recStatus.isRecording else {return}
			
			if #available(iOS 10.0, *) {
				let notifCenter = UNUserNotificationCenter.current()
				/* We do not want provisional notifications; either the user accepts or he doesn’t.
				 * No in-between. */
				notifCenter.requestAuthorization(options: [.alert/*, .provisional*/], completionHandler: { granted, error in
					/* We do nothing, whether the permissions were granted or not, or even in case of an error (to be fair I also have no idea what kind of error we could get).
					 *
					 * Note that we could _not_ observe the current location (disable observation block after this one) when the notification permission is not granted
					 *  because we won’t be able to post a notification anyway when location updates are paused.
					 * However, this would also require finding a way to re-enable the observation when the notifications are enabled again,
					 *  and I’m too lazy to do that now… */
				})
			} else {
				UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(types: [.alert], categories: nil))
			}
			
			/* We have asked for push permission, we do not need to observe the location recorder recording status anymore. */
			self.kvObserver.stopObserving(id: isRecordingObservingId)
		})
		
		/* This observer will trigger a notification when the system pauses location updates to keep the user up-to-date. */
		_ = kvObserver.observe(object: lr, keyPath: #keyPath(LocationRecorder.currentLocation), kvoOptions: [.initial, .old], dispatchType: .asyncOnMainQueueDirectInitial, handler: { [weak self] observationInfo in
			guard let self = self else {return}
			guard !self.lr.recStatus.isStopped else {return}
			guard self.lr.currentLocation == nil else {return}
			/* If the previous current location was already nil, we do nothing. */
			guard observationInfo?[.oldKey].flatMap({ ($0 as? NSNull) == nil }) ?? true else {return}
			
			let locError = GPSStoneLocationError(error: self.lr.currentLocationManagerError)
			guard locError.isUpdatesPaused else {return}
			
			/* Let’s show a notif to the user to inform it loc updates are paused. */
			if #available(iOS 10.0, *) {
				/* Perhaps TODO one day: add actions to the notif. */
				let content = UNMutableNotificationContent()
				content.title = NSLocalizedString("notif title: location updates paused", comment: "The title of the notification when location updates are paused by the system.")
				content.body = NSLocalizedString("notif body: location updates paused", comment: "The body of the notification when location updates are paused by the system.")
				let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
				UNUserNotificationCenter.current().add(request, withCompletionHandler: nil /* We don’t really care if the notif cannot be shown… */)
			} else {
				let notif = UILocalNotification()
				if #available(iOS 8.2, *) {
					notif.alertTitle = NSLocalizedString("notif title: location updates paused", comment: "The title of the notification when location updates are paused by the system.")
				}
				notif.alertBody = NSLocalizedString("notif body: location updates paused", comment: "The body of the notification when location updates are paused by the system.")
				UIApplication.shared.scheduleLocalNotification(notif)
			}
		})
	}
	
	deinit {
		kvObserver.stopObservingEverything()
	}
	
	func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
		/* Nothing to do here (see post-iOS 10 notif registration discussion for more information). */
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let kvObserver = KVObserver()
	
	/* *** Dependencies *** */
	
	private let lr: LocationRecorder
	
}

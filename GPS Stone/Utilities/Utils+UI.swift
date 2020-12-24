/*
 * Utils+UI.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2020/5/17.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import Foundation
import UIKit



extension Utils {
	
	static var isDeviceScreenTallerThanOriginalIPhone: Bool {
		return UIScreen.main.bounds.height > 480
	}
	
	static func executeOrShowAlertIn(_ viewController: UIViewController, _ block: () throws -> Void) {
		do {
			try block()
		} catch {
			let alertVC = UIAlertController(
				title: NSLocalizedString("error executing action", comment: "The generic alert view title for an error running an action."),
				message: error.localizedDescription,
				preferredStyle: .alert
			)
			alertVC.addAction(UIAlertAction(title: NSLocalizedString("ok button title", comment: ""), style: .default))
			viewController.present(alertVC, animated: true, completion: nil)
		}
	}
	
	static func confirmAndExecuteAction(in viewController: UIViewController, needsConfirmation: Bool, alertTitle: String, alertMessage: String, confirmButtonText: String, action: @escaping () -> Void) {
		guard needsConfirmation else {
			return action()
		}
		
		let alertVC = UIAlertController(title: alertTitle,message: alertMessage, preferredStyle: .alert)
		alertVC.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""),  style: .cancel))
		alertVC.addAction(UIAlertAction(title: confirmButtonText, style: .default, handler: { _ in action() }))
		viewController.present(alertVC, animated: true, completion: nil)
	}
	
	static func startOrResumeRecording(in viewController: UIViewController, using locationRecorder: LocationRecorder) {
		Utils.executeOrShowAlertIn(viewController){
			switch locationRecorder.recStatus {
				case .stopped: try locationRecorder.startNewRecording()
				case .paused:  try locationRecorder.resumeCurrentRecording()
				case .recording: (/*nop*/)
			}
		}
	}
	
	static func pauseRecording(in viewController: UIViewController, using locationRecorder: LocationRecorder, appSettings: AppSettings) {
		confirmAndExecuteAction(
			in: viewController,
			needsConfirmation: appSettings.askBeforePausingOrStopping,
			alertTitle:   NSLocalizedString("avt: pause the recording", comment:   "Title of the alert view before pausing a recording."),
			alertMessage: NSLocalizedString("avm: pause the recording", comment: "Message of the alert view before pausing a recording."),
			confirmButtonText: NSLocalizedString("avb: confirm pause the recording", comment: "Text of the button to confirm pausing the recording in the alert view before pausing a recording."),
			action: {
				Utils.executeOrShowAlertIn(viewController){
					switch locationRecorder.recStatus {
						case .recording: _ = try locationRecorder.pauseCurrentRecording()
						case .stopped, .paused: (/*nop*/)
					}
				}
			}
		)
	}
	
	static func stopRecording(in viewController: UIViewController, using locationRecorder: LocationRecorder, appSettings: AppSettings) {
		confirmAndExecuteAction(
			in: viewController,
			needsConfirmation: appSettings.askBeforePausingOrStopping,
			alertTitle:   NSLocalizedString("avt: stop the recording", comment:   "Title of the alert view before stopping a recording."),
			alertMessage: NSLocalizedString("avm: stop the recording", comment: "Message of the alert view before stopping a recording."),
			confirmButtonText: NSLocalizedString("avb: confirm stop the recording", comment: "Text of the button to confirm stopping the recording in the alert view before stopping a recording."),
			action: {
				Utils.executeOrShowAlertIn(viewController){
					switch locationRecorder.recStatus {
						case .recording, .paused: _ = try locationRecorder.stopCurrentRecording()
						case .stopped: (/*nop*/)
					}
				}
			}
		)
	}
	
}

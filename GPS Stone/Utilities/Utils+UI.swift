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
			alertVC.addAction(UIAlertAction(title: NSLocalizedString("ok button title", comment: ""), style: .default, handler: { _ in alertVC.dismiss(animated: true, completion: nil) }))
			viewController.present(alertVC, animated: true, completion: nil)
		}
	}
	
}

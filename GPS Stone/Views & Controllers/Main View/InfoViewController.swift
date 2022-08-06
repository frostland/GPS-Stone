/*
 * InfoViewController.swift
 * GPS Stone
 *
 * Created by François Lamboley on 18/06/2019.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import Foundation
import UIKit

import KVObserver



protocol InfoViewControllerDelegate : AnyObject {
	
	func showDetailedInfo()
	func showMap()
	
}


class InfoViewController : UIViewController {
	
	@IBOutlet var constraintMarginTopTitle: NSLayoutConstraint!
	@IBOutlet var labelTitle: UILabel!
	@IBOutlet var buttonRecord: UIButton!
	
	weak var delegate: InfoViewControllerDelegate?
	
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .lightContent
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		if #available(iOS 9, *) {} else {
			/* On iOS 8, I don’t know why, but the title font does not work… */
			labelTitle.font = UIFont.systemFont(ofSize: 27)
			buttonRecord.titleLabel?.font = UIFont.systemFont(ofSize: 22)
		}
		
		if !Utils.isDeviceScreenTallerThanOriginalIPhone {
			constraintMarginTopTitle.constant = 25
		}
		
		_ = kvObserver.observe(object: locationRecorder, keyPath: #keyPath(LocationRecorder.objc_recStatus), kvoOptions: [.initial], dispatchType: .asyncOnMainQueueDirectInitial, handler: { [weak self] _ in
			guard let self = self else {return}
			self.buttonRecord.isHidden = (self.locationRecorder.recStatus.isRecording || self.locationRecorder.recStatus.isPaused)
		})
	}
	
	@IBAction func showDetailedInfos(_ sender: Any) {
		delegate?.showDetailedInfo()
	}
	
	@IBAction func showPositionOnMap(_ sender: Any) {
		delegate?.showMap()
	}
	
	@IBAction func startRecording(_ sender: Any) {
		delegate?.showDetailedInfo()
		Utils.startOrResumeRecording(in: self, using: locationRecorder)
	}
	
	@IBAction func showEndOfLife(_ sender: Any) {
		UIApplication.shared.openURL(S.sp.constants.newAppURL)
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	@available(iOS, deprecated: 13, message: "In Xcode 11 apparently we can do injection from Storyboard. To be tested. (I put the warning here, it’s true everywhere indeed…)")
	private let locationRecorder = S.sp.locationRecorder
	
	private let kvObserver = KVObserver()
	
}

/*
 * RecordingDetailsViewController.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 19/06/2019.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import Foundation
import UIKit



class RecordingDetailsViewController : UIViewController {
	
	@IBOutlet var textFieldName: UITextField!
	@IBOutlet var labelInfos: UILabel!
	@IBOutlet var labelDate: UILabel!
	@IBOutlet var constraintNameKeyboard: NSLayoutConstraint!
	
	var recording: Recording!
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		switch segue.identifier {
		case "MapEmbed"?:
			guard let mapViewController = segue.destination as? MapViewController else {return}
			mapViewController.recording = recording
			
		default: (/*nop*/)
		}
	}
	
}

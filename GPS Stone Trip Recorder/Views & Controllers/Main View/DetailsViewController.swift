/*
 * DetailsViewController.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 18/06/2019.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import Foundation
import UIKit



class DetailsViewController : UIViewController {
	
	@IBOutlet var labelLat: UILabel!
	@IBOutlet var labelLong: UILabel!
	@IBOutlet var labelSpeed: UILabel!
	@IBOutlet var labelAverageSpeed: UILabel!
	@IBOutlet var labelMaxSpeed: UILabel!
	@IBOutlet var labelHorizontalAccuracy: UILabel!
	@IBOutlet var labelAltitude: UILabel!
	@IBOutlet var labelVerticalAccuracy: UILabel!
	@IBOutlet var labelNumberOfPoints: UILabel!
	@IBOutlet var labelTotalDistance: UILabel!
	@IBOutlet var labelElapsedTime: UILabel!
	@IBOutlet var labelTrackName: UILabel!
	@IBOutlet var labelKmph: UILabel!
	@IBOutlet var imageNorth: UIImageView!
	
	@IBOutlet var viewWithTrackInfos: UIView!
	
	@IBOutlet var buttonRecord: UIButton!
	
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .default
	}
	
}

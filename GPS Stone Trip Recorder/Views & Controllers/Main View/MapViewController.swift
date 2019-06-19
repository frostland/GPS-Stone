/*
 * MapViewController.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/6/19.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import Foundation
import MapKit
import UIKit



class MapViewController : UIViewController {
	
	@IBOutlet var buttonCenterMapOnCurLoc: UIButton!
	@IBOutlet var mapView: MKMapView!
	@IBOutlet var viewStatusBarBlur: UIView!
	
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .default
	}
	
}

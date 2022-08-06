/*
 * SettingsViewController.swift
 * GPS Stone
 *
 * Created by François Lamboley on 19/06/2019.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation
import UIKit

import XibLoc



class SettingsViewController : UITableViewController {
	
	@IBOutlet var segmentedCtrlMapType: UISegmentedControl!
	@IBOutlet var textFieldMinDist: UITextField!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		textFieldMinDist.text = XibLocNumber(Int(appSettings.distanceFilter+0.5)).localizedString
		
		switch appSettings.mapType {
			case .satellite, .satelliteFlyover: segmentedCtrlMapType.selectedSegmentIndex = 1
			case .hybrid, .hybridFlyover:       segmentedCtrlMapType.selectedSegmentIndex = 2
			case .standard: fallthrough
			default:
				segmentedCtrlMapType.selectedSegmentIndex = 0
		}
	}
	
	@IBAction func mapTypeChanged(_ sender: Any) {
		switch segmentedCtrlMapType.selectedSegmentIndex {
			case 1: appSettings.mapType = .satellite
			case 2: appSettings.mapType = .hybrid
			case 0: fallthrough
			default:
				/* Let's set the map type to standard for unknown segment. */
				appSettings.mapType = .standard
		}
	}
	
	@IBAction func minDistChanged(_ sender: UITextField) {
		guard let v = sender.text.flatMap({ Int($0) }) else {
			return
		}
		appSettings.distanceFilter = CLLocationDistance(v)
	}
	
	/* ****************************************************
	   MARK: - Table View Controller Data Source & Delegate
	   **************************************************** */
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = super.tableView(tableView, cellForRowAt: indexPath)
		switch indexPath.section {
			case 1:
				switch indexPath.row {
					case 1: cell.accessoryType = (appSettings.useBestGPSAccuracy         ? .checkmark : .none)
					case 2: cell.accessoryType = (appSettings.askBeforePausingOrStopping ? .checkmark : .none)
					default: (/*nop*/)
				}
				
			case 2:
				switch indexPath.row {
					case 0: cell.accessoryType = (appSettings.distanceUnit == .automatic ? .checkmark : .none)
					case 1: cell.accessoryType = (appSettings.distanceUnit == .metric    ? .checkmark : .none)
					case 2: cell.accessoryType = (appSettings.distanceUnit == .imperial  ? .checkmark : .none)
					default: fatalError()
				}
				
			default: (/*nop*/)
		}
		return cell
	}
	
	override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
		return (
			indexPath == IndexPath(row: 1, section: 1) ||
			indexPath == IndexPath(row: 2, section: 1) ||
			indexPath.section == 2 ||
			indexPath.section == 3
		)
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		/* NO call to super (not implemented in superclass). */
		tableView.deselectRow(at: indexPath, animated: true)
		
		switch indexPath.section {
			case 1:
				switch indexPath.row {
					case 1:
						appSettings.useBestGPSAccuracy = !appSettings.useBestGPSAccuracy
						tableView.cellForRow(at: indexPath)?.accessoryType = (appSettings.useBestGPSAccuracy ? .checkmark : .none)
					case 2:
						appSettings.askBeforePausingOrStopping = !appSettings.askBeforePausingOrStopping
						tableView.cellForRow(at: indexPath)?.accessoryType = (appSettings.askBeforePausingOrStopping ? .checkmark : .none)
					default: (/*nop*/)
				}
				
			case 2:
				tableView.cellForRow(at: IndexPath(row: 0, section: indexPath.section))?.accessoryType = .none
				tableView.cellForRow(at: IndexPath(row: 1, section: indexPath.section))?.accessoryType = .none
				tableView.cellForRow(at: IndexPath(row: 2, section: indexPath.section))?.accessoryType = .none
				tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
				switch indexPath.row {
					case 0: appSettings.distanceUnit = .automatic
					case 1: appSettings.distanceUnit = .metric
					case 2: appSettings.distanceUnit = .imperial
					default: fatalError()
				}
				
			case 3:
				switch indexPath.row {
					case 0:
						/* Rate the app. */
						UIApplication.shared.openURL(appRateAndShareManager.rateAppURL)
						
					case 1:
						/* Share the app. */
						let activityViewController = UIActivityViewController(activityItems: [appRateAndShareManager.shareAppURL], applicationActivities: nil)
						present(activityViewController, animated: true, completion: nil)
						
					default:
						(/*nop*/)
				}
				
			default:
				(/*nop*/)
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let appSettings = S.sp.appSettings
	private let appRateAndShareManager = S.sp.appRateAndShareManager
	
}

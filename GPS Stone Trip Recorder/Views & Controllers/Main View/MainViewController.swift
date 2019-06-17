/*
 * MainViewController.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/6/16.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import Foundation
import UIKit



class MainViewController : UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
	
	@IBOutlet var pageControl: UIPageControl!
	
	@IBOutlet var buttonRecord: UIButton!
	@IBOutlet var buttonPause: UIButton!
	@IBOutlet var buttonListRecords: UIButton!
	@IBOutlet var buttonStop: UIButton!

	@IBOutlet var viewMiniInfos: UIView!
	@IBOutlet var labelMiniInfosDistance: UILabel!
	@IBOutlet var labelMiniInfosRecordTime: UILabel!
	@IBOutlet var labelMiniInfosRecordingState: UILabel!
	
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .lightContent
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		switch segue.identifier {
		case "MainPageViewControllerSegue"?:
			let pageViewController = segue.destination as! UIPageViewController
			pageViewController.dataSource = self
			pageViewController.delegate = self
			
		default: (/*nop*/)
		}
	}
	
	/* ***************
	   MARK: - Actions
	   *************** */
	
	@IBAction func changePage(_ sender: UIPageControl) {
	}
	
	@IBAction func startRecording(_ sender: Any) {
	}
	
	@IBAction func pauseRecording(_ sender: Any) {
	}
	
	@IBAction func stopRecording(_ sender: Any) {
	}
	
	/* ***************************************************
	   MARK: - Page View Controller Data Source & Delegate
	   *************************************************** */
	
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
		return nil
	}
	
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
		return nil
	}
	
}

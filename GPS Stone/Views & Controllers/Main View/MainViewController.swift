/*
 * MainViewController.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2019/6/16.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import Foundation
import UIKit

import KVObserver



class MainViewController : UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
	
	@IBOutlet var pageControl: UIPageControl!
	
	@IBOutlet var buttonRecord: UIButton!
	@IBOutlet var buttonPause: UIButton!
	@IBOutlet var buttonListRecords: UIButton!
	@IBOutlet var buttonStop: UIButton!

	@IBOutlet var viewMiniInfos: UIView!
	#warning("TODO")
	@IBOutlet var labelMiniInfosDistance: UILabel!
	@IBOutlet var labelMiniInfosRecordTime: UILabel!
	@IBOutlet var labelMiniInfosRecordingState: UILabel!
	
	var pageViewController: UIPageViewController!
	
	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		fatalError("Unexpected init method")
	}
	
	required init?(coder: NSCoder) {
		viewControllers = [UIViewController?](repeating: nil, count: pageViewControllerIdentifiers.count)
		
		super.init(coder: coder)
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		
		let currentIdx = pageViewController.viewControllers?.first?.restorationIdentifier.flatMap{ pageViewControllerIdentifiers.firstIndex(of: $0) } ?? -1
		for i in 0..<viewControllers.count where i != currentIdx {
			viewControllers[i] = nil
		}
	}
	
	override var childForStatusBarStyle: UIViewController? {
		return pageViewController?.viewControllers?.first
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		/* Select the previously selected page */
		pageControl.currentPage = min(pageControl.numberOfPages, max(0, appSettings.selectedPage))
		pageViewController.setViewControllers([viewControllerForPage(atIndex: pageControl.currentPage)], direction: .forward, animated: false, completion: nil)
		setNeedsStatusBarAppearanceUpdate()
		
		_ = kvObserver.observe(object: locationRecorder, keyPath: #keyPath(LocationRecorder.objc_recStatus), kvoOptions: [.initial], dispatchType: .asyncOnMainQueueDirectInitial, handler: { [weak self] _ in
			guard let self = self else {return}
			
			self.viewMiniInfos.isHidden = self.locationRecorder.recStatus.isStopped
			
			switch self.locationRecorder.recStatus {
				case .stopped:
					self.buttonRecord.isHidden = false
					self.buttonStop.isHidden = true
					self.buttonPause.isHidden = true
					self.buttonListRecords.isHidden = false
					
				case .recording:
					self.buttonRecord.isHidden = true
					self.buttonStop.isHidden = false
					self.buttonPause.isHidden = false
					self.buttonListRecords.isHidden = true
					
				case .paused:
					self.buttonRecord.isHidden = false
					self.buttonStop.isHidden = false
					self.buttonPause.isHidden = true
					self.buttonListRecords.isHidden = true
			}
		})
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		switch segue.identifier {
			case "MainPageViewControllerSegue"?:
				pageViewController = (segue.destination as! UIPageViewController)
				pageViewController.dataSource = self
				pageViewController.delegate = self
				
				let viewController = viewControllerForPage(atIndex: 0)
				pageViewController.setViewControllers([viewController], direction: .forward, animated: false, completion: nil)
				setNeedsStatusBarAppearanceUpdate()
				
			default: (/*nop*/)
		}
	}
	
	/* ***************
	   MARK: - Actions
	   *************** */
	
	@IBAction func unwindSegueToMainViewController(_ sender: UIStoryboardSegue) {
	}
	
	@IBAction func changePage(_ sender: UIPageControl) {
		let newIdx = pageControl.currentPage
		let oldIdx = pageViewController.viewControllers?.first?.restorationIdentifier.flatMap{ pageViewControllerIdentifiers.firstIndex(of: $0) } ?? -1
		
		appSettings.selectedPage = newIdx
		
		let viewController = viewControllerForPage(atIndex: newIdx)
		pageViewController.setViewControllers([viewController], direction: oldIdx < newIdx ? .forward : .reverse, animated: true, completion: nil)
		setNeedsStatusBarAppearanceUpdate()
	}
	
	@IBAction func startRecording(_ sender: Any) {
		Utils.executeOrShowAlertIn(self){
			switch self.locationRecorder.recStatus {
			case .stopped: try locationRecorder.startNewRecording()
			default:       try locationRecorder.resumeCurrentRecording()
			}
		}
	}
	
	@IBAction func pauseRecording(_ sender: Any) {
		Utils.executeOrShowAlertIn(self, { try locationRecorder.pauseCurrentRecording() })
	}
	
	@IBAction func stopRecording(_ sender: Any) {
		Utils.executeOrShowAlertIn(self, { _ = try locationRecorder.stopCurrentRecording() })
	}
	
	/* ***************************************************
	   MARK: - Page View Controller Data Source & Delegate
	   *************************************************** */
	
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
		guard let id = viewController.restorationIdentifier, let idx = pageViewControllerIdentifiers.firstIndex(of: id), idx > 0 else {return nil}
		return viewControllerForPage(atIndex: idx-1)
	}
	
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
		guard let id = viewController.restorationIdentifier, let idx = pageViewControllerIdentifiers.firstIndex(of: id), idx < pageViewControllerIdentifiers.count-1 else {return nil}
		return viewControllerForPage(atIndex: idx+1)
	}
	
	func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
		/* Update the page control selected index */
		if let id = pageViewController.viewControllers?.first?.restorationIdentifier, let idx = pageViewControllerIdentifiers.firstIndex(of: id) {
			pageControl.currentPage = idx
			appSettings.selectedPage = idx
		}
		
		setNeedsStatusBarAppearanceUpdate()
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let appSettings = S.sp.appSettings
	
	private let locationRecorder = S.sp.locationRecorder
	
	private let kvObserver = KVObserver()
	
	private let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
	private let pageViewControllerIdentifiers = ["VSOInfoViewController", "VSODetailsViewController", "VSOMapViewController"]
	
	private var viewControllers: [UIViewController?]
	
	private func viewControllerForPage(atIndex index: Int) -> UIViewController {
		let ret = viewControllers[index] ?? mainStoryboard.instantiateViewController(withIdentifier: pageViewControllerIdentifiers[index])
		viewControllers[index] = ret
		
		switch ret {
			case let infoViewController as InfoViewController: infoViewController.delegate = self
			default: (/*nop*/)
		}
		
		return ret
	}
	
}


extension MainViewController : InfoViewControllerDelegate {
	
	func showDetailedInfo() {
		pageControl.currentPage = 1
		changePage(pageControl)
	}
	
	func showMap() {
		pageControl.currentPage = 2
		changePage(pageControl)
	}
	
}

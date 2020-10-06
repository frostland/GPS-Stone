/*
 * MainViewController.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2019/6/16.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreData
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
	
	var pageViewController: UIPageViewController!
	
	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		fatalError("Unexpected init method")
	}
	
	required init?(coder: NSCoder) {
		viewControllers = [UIViewController?](repeating: nil, count: pageViewControllerIdentifiers.count)
		
		super.init(coder: coder)
	}
	
	deinit {
		/* This removes the timer to refresh the duration shown of the recording,
		 * which needed before iOS 10 because the timer keeps a strong ref to the
		 * target until the timer is deallocated. */
		miniInfoViewController?.model = nil
		
		if let o = settingsObserver {
			NotificationCenter.default.removeObserver(o)
			settingsObserver = nil
		}
		
		kvObserver.stopObservingEverything()
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
		
		assert(settingsObserver == nil)
		settingsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main, using: { [weak self] _ in
			guard let self = self else {return}
			self.miniInfoViewController?.useMetricSystem = self.appSettings.useMetricSystem
		})
		miniInfoViewController?.useMetricSystem = appSettings.useMetricSystem
		
		_ = kvObserver.observe(object: locationRecorder, keyPath: #keyPath(LocationRecorder.objc_recStatus), kvoOptions: [.initial], dispatchType: .asyncOnMainQueueDirectInitial, handler: { [weak self] _ in
			guard let self = self else {return}
			
			self.currentRecording = self.locationRecorder.recStatus.recordingRef.flatMap{ self.recordingsManager.unsafeRecording(from: $0) }
			self.updateRecordingUI()
		})
		_ = kvObserver.observe(object: locationRecorder, keyPath: #keyPath(LocationRecorder.currentLocation), kvoOptions: [.initial], dispatchType: .asyncOnMainQueueDirectInitial, handler: { [weak self] _ in
			guard let self = self else {return}
			
			self.miniInfoViewController?.currentLocationError = (self.locationRecorder.currentLocation == nil ? GPSStoneLocationError(error: self.locationRecorder.currentLocationManagerError) : nil)
		})
		miniInfoViewController?.currentLocationError = (locationRecorder.currentLocation == nil ? GPSStoneLocationError(error: locationRecorder.currentLocationManagerError) : nil)
		updateRecordingUI()
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
			
			case "MiniInfoViewControllerSegue"?:
				miniInfoViewController = (segue.destination as! MiniInfoViewController)
				miniInfoViewController?.delegate = self
				updateRecordingUI()
				
			default: (/*nop*/)
		}
		
		super.prepare(for: segue, sender: sender)
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
	
	private let c = S.sp.constants
	private let appSettings = S.sp.appSettings
	private let locationRecorder = S.sp.locationRecorder
	private let recordingsManager = S.sp.recordingsManager
	
	private let kvObserver = KVObserver()
	private var settingsObserver: NSObjectProtocol?
	
	private let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
	private let pageViewControllerIdentifiers = ["VSOInfoViewController", "VSODetailsViewController", "VSOMapViewController"]
	
	private var viewControllers: [UIViewController?]
	
	private var miniInfoViewController: MiniInfoViewController?
	
	private var currentRecordingObservationId: NSObjectProtocol?
	private var currentRecording: Recording? {
		willSet {
			currentRecordingObservationId.flatMap{ NotificationCenter.default.removeObserver($0) }
			currentRecordingObservationId = nil
		}
		didSet  {
			guard let r = currentRecording, let c = r.managedObjectContext else {return}
			currentRecordingObservationId = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: c, queue: .main, using: { [weak self] notif in
				guard let updatedObjects = notif.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> else {return}
				guard updatedObjects.contains(r) else {return}
				self?.updateRecordingUI()
			})
		}
	}
	
	private func updateRecordingUI() {
		assert(Thread.isMainThread)
		guard isViewLoaded else {return}
		
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
		
		miniInfoViewController?.model = currentRecording.flatMap(MiniInfoViewController.Model.init)
		if currentRecording != nil {
			/* We show the recording controller and hide the recording button. */
			if viewMiniInfos.alpha < 0.5 {
				UIView.animate(withDuration: c.animTime, animations: {
					self.viewMiniInfos.alpha = 1
				})
			}
		} else {
			/* We hide the recording controller and show the recording button. */
			if viewMiniInfos.alpha > 0.5 {
				UIView.animate(withDuration: c.animTime, animations: {
					self.viewMiniInfos.alpha = 0
				})
			}
		}
	}
	
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


extension MainViewController : InfoViewControllerDelegate, MiniInfoViewControllerDelegate {
	
	func showDetailedInfo() {
		pageControl.currentPage = 1
		changePage(pageControl)
	}
	
	func showMap() {
		pageControl.currentPage = 2
		changePage(pageControl)
	}
	
}

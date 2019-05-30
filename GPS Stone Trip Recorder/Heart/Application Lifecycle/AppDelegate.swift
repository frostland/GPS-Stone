/*
 * AppDelegate.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/5/30.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import Foundation
import UIKit



@UIApplicationMain
class AppDelegate : NSObject, UIApplicationDelegate {
	
	static private(set) var sharedAppDelegate: AppDelegate!
	
	var window: UIWindow?
	
	override init() {
		super.init()
		
		if AppDelegate.sharedAppDelegate == nil {AppDelegate.sharedAppDelegate = self}
		else                                    {fatalError("The App Delegate must be instantiated only once!")}
		
		settings.registerDefaultSettings()
	}
	
	func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
		let fm = FileManager.default
		/* Creating data dir */
		try! fm.createDirectory(at: constants.urlToFolderWithGPXFiles, withIntermediateDirectories: true, attributes: nil)
		
//		rootViewController = (MainViewController *)self.window.rootViewController;
		
		if fm.fileExists(atPath: constants.urlToNiceExitWitness.path) {
			NSLog("Last exit was forced")
//			[rootViewController recoverFromCrash];
		}
		fm.createFile(atPath: constants.urlToNiceExitWitness.path, contents: nil, attributes: nil)
		return true
	}
	
	func applicationWillTerminate(_ application: UIApplication) {
//		[rootViewController saveRecordingListStoppingGPX:YES];
		_ = try? FileManager.default.removeItem(at: constants.urlToNiceExitWitness)
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/* Dependencies */
	private let settings = S.sp.appSettings
	private let constants = S.sp.constants
	
}

/*
 * AppDelegate.swift
 * GPS Stone
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
		/* Nothing to do! */
		return true
	}
	
	func applicationWillTerminate(_ application: UIApplication) {
		/* Nothing to do! */
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/* Dependencies */
	private let settings = S.sp.appSettings
	
}

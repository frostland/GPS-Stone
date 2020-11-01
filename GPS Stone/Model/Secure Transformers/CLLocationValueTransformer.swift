/*
 * CLLocationValueTransformer.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2020/11/1.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation



@objc(CLLocationValueTransformer)
final class CLLocationValueTransformer : NSSecureUnarchiveFromDataTransformer {
	
	static let name = NSValueTransformerName(rawValue: String(describing: CLLocationValueTransformer.self))
	
	override static var allowedTopLevelClasses: [AnyClass] {
		return [CLLocation.self]
	}
	
	public static func register() {
		let transformer = CLLocationValueTransformer()
		ValueTransformer.setValueTransformer(transformer, forName: name)
	}
	
}

/*
 * FRLSecureUnarchiveFromDataTransformer.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2020/11/1.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation



/**
An NSSecureUnarchiveFromDataTransformer subclass that allows more top level
classes. */
@objc(FRLSecureUnarchiveFromDataTransformer)
final class FRLSecureUnarchiveFromDataTransformer : NSSecureUnarchiveFromDataTransformer {
	
	static let name = NSValueTransformerName(rawValue: String(describing: FRLSecureUnarchiveFromDataTransformer.self))
	
	override static var allowedTopLevelClasses: [AnyClass] {
		return super.allowedTopLevelClasses + [CLLocation.self, CLHeading.self]
	}
	
	public static func register() {
		let transformer = FRLSecureUnarchiveFromDataTransformer()
		ValueTransformer.setValueTransformer(transformer, forName: name)
	}
	
}

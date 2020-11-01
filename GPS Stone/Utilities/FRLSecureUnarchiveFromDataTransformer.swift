/*
 * FRLSecureUnarchiveFromDataTransformer.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2020/11/1.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation



/* We could override NSSecureUnarchiveFromDataTransformer (see commit
 * 1f05fa28fb31f2f592b53d1c9dac08ff8bd39066), but it’s only available from
 * iOS 12. */

/**
An ValueTransformer subclass that allows secure decoding of the classes we need.

- Note: This implementation does not care if the object you give it are not of
the expected class, but decoding through this transformer _will_ fail if you try
and decode an archive containing an object of the incorrect class. */
@objc(FRLSecureUnarchiveFromDataTransformer)
final class FRLSecureUnarchiveFromDataTransformer : ValueTransformer {
	
	static let name = NSValueTransformerName(rawValue: String(describing: FRLSecureUnarchiveFromDataTransformer.self))
	
	public static func register() {
		let transformer = FRLSecureUnarchiveFromDataTransformer()
		ValueTransformer.setValueTransformer(transformer, forName: name)
	}
	
	override class func transformedValueClass() -> AnyClass {
		return NSData.self
	}
	
	override func transformedValue(_ value: Any?) -> Any? {
		return try? NSKeyedArchiver.archivedData(withRootObject: value as Any, requiringSecureCoding: true)
	}
	
	override func reverseTransformedValue(_ value: Any?) -> Any? {
		guard let value = value as? Data else {return nil}
		return try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [CLLocation.self, CLHeading.self], from: value)
	}
	
}

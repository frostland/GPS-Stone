/*
 * CLHeadingValueTransformer.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2020/11/1.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation



@objc(CLHeadingValueTransformer)
final class CLHeadingValueTransformer : NSSecureUnarchiveFromDataTransformer {
	
	static let name = NSValueTransformerName(rawValue: String(describing: CLHeadingValueTransformer.self))
	
	override static var allowedTopLevelClasses: [AnyClass] {
		return [CLHeading.self]
	}
	
	public static func register() {
		let transformer = CLHeadingValueTransformer()
		ValueTransformer.setValueTransformer(transformer, forName: name)
	}
	
}

/*
 * NSManagedObject+Utils.swift
 * GPS Stone
 *
 * Created by François Lamboley on 03/10/2020.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import CoreData
import Foundation



extension NSManagedObject {
	
	static func existingFrom(id: NSManagedObjectID, in context: NSManagedObjectContext) throws -> Self {
		guard let ret = try context.existingObject(with: id) as? Self else {
			throw NSError(domain: Constants.appDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot object with id \(id) does not have type \(self)"])
		}
		return ret
	}
	
}

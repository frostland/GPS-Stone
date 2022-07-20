/*
 * NSManagedObjectContext+Utils.swift
 * GPS Stone
 *
 * Created by François Lamboley on 04/10/2020.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import CoreData
import Foundation



extension NSManagedObjectContext {
	
	/* Should be declared as rethrows instead of throws, but did not find a way to do it, sadly. */
	func performAndWait<T>(_ block: () throws -> T) throws -> T {
		var ret: T?
		var err: Error?
		performAndWait{
			do    {ret = try block()}
			catch {err = error}
		}
		if let e = err {throw e}
		return ret!
	}
	
}

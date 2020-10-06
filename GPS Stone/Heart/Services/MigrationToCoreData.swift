/*
 * MigrationToCoreData.swift
 * GPS Stone
 *
 * Created by François Lamboley on 06/10/2020.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import CoreData
import Foundation



extension NSNotification.Name {
	
	static let MigrationToCoreDataHasEnded = NSNotification.Name(rawValue: Constants.appDomain + ".notif-name.migration-to-coredata-ended")
	
}


final class MigrationToCoreData {
	
	init(dataHandler: DataHandler) {
		dh = dataHandler
	}
	
	func startMigrationToCoreData() {
		/* Do we need to migrate anything? */
		
		var strongSelf: MigrationToCoreData? = self
		
		let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		context.persistentStoreCoordinator = dh.persistentStoreCoordinator
		if #available(iOS 10.0, *) {
			/* I think this is the default, but still… */
			context.automaticallyMergesChangesFromParent = false
		}
		
		/* After (and including) iOS 10, we can set
		 * automaticallyMergesChangesFromParent on the view context, and we would
		 * not have to observe this notification, but we’re compatible w/ iOS 8,
		 * so we have to do the observing…
		 * A note though: The property will automatically merge the saves from
		 * other contexts, but will _not_ save the context after the merge (see
		 * comment inside our merge implementation for more details). */
		let observer = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: context, queue: .main, using: { [weak self] n in
//			NSLog("%@", "before: \(String(describing: self?.dh.viewContext.hasChanges))")
			self?.dh.viewContext.mergeChanges(fromContextDidSave: n)
			/* If some objects were deleted, the merge changes will delete those
			 * objects in the destination context, but will not save the context.
			 * So we save it here.
			 * Note: For other changes in the context, AFAICT there are no need to
			 *       save the context. Which is consistent w/ what the doc says. */
			try? self?.dh.saveViewContextOrRollback()
//			NSLog("%@", "after: \(String(describing: self?.dh.viewContext.hasChanges))")
		})
		
		context.perform{
			defer {
				NotificationCenter.default.post(name: .MigrationToCoreDataHasEnded, object: nil)
				
				NotificationCenter.default.removeObserver(observer, name: .NSManagedObjectContextDidSave, object: context)
				strongSelf = nil
			}
			
			#warning("TODO: Remove this sleep")
			Thread.sleep(forTimeInterval: 7)
//			let s = NSEntityDescription.insertNewObject(forEntityName: "TimeSegment", into: context) as! TimeSegment
//			s.startDate = Date()
//
//			let r = NSEntityDescription.insertNewObject(forEntityName: "Recording", into: context) as! Recording
//			r.name = NSLocalizedString("new recording", comment: "Default name for a recording")
//			r.totalTimeSegment = s
//
//			s.closeTimeSegment()
//
//			try? context.save()
		}
	}
	
	private let dh: DataHandler
	
}

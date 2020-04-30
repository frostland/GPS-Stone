/*
 * DataHandler.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/7/27.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreData
import Foundation



final class DataHandler {
	
	init(constants: Constants) {
		c = constants
	}
	
	lazy var model: NSManagedObjectModel = {
		return NSManagedObjectModel(contentsOf: Bundle(for: Recording.self).url(forResource: "Model", withExtension: "momd")!)!
	}()
	
	lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
		let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
		
		/* Adding the cached data store to the coordinator */
		do {
			var tryCount = 0
			var error: Error?
			repeat {
				/* Uncomment to clear the cache (for debug, etc.) */
//				removeCachedDataModelFilesAndLinkedCachedFiles()
				
				error = nil
				tryCount += 1
				do {
//					NSLog("CoreData Store URL: %@", c.urlToCoreDataStore.absoluteString)
					try coordinator.addPersistentStore(
						ofType: NSSQLiteStoreType, configurationName: nil, at: c.urlToCoreDataStore,
						options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
					)
				} catch let err {
					error = err
					/* If the store cannot be created, the model file might be
					 * invalid. We delete it and try again. */
					removeCachedDataModelFilesAndLinkedCachedFiles()
				}
			} while error != nil && tryCount <= 1
			guard error == nil else {
				/* It might be nice to warn the user before crashing... */
				fatalError("Cannot create the cached data persistent store. The app cannot work. Got error \(error!).")
			}
		}
		
		return coordinator
	}()
	
	lazy var viewContext: NSManagedObjectContext = {
		let ret = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
		ret.persistentStoreCoordinator = persistentStoreCoordinator
		return ret
	}()
	
	func saveContextOrRollback() throws {
		do {try viewContext.save()}
		catch {
			viewContext.rollback()
			throw error
		}
	}
	
	private let c: Constants
	
	private func removeCachedDataModelFilesAndLinkedCachedFiles() {
		removeModelFilesWithBase(c.urlToCoreDataStore)
	}
	
	private func removeModelFilesWithBase(_ baseURL: URL) {
		let basePath = baseURL.path
		
		let fm = FileManager.default
		_ = try? fm.removeItem(atPath: basePath)
		_ = try? fm.removeItem(atPath: basePath + "-shm")
		_ = try? fm.removeItem(atPath: basePath + "-wal")
	}
	
}

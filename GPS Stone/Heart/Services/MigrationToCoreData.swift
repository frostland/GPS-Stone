/*
 * MigrationToCoreData.swift
 * GPS Stone
 *
 * Created by François Lamboley on 06/10/2020.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import CoreData
import CoreLocation
import Foundation



extension NSNotification.Name {
	
	static let MigrationToCoreDataHasEnded = NSNotification.Name(rawValue: Constants.appDomain + ".notif-name.migration-to-coredata-ended")
	
}


final class MigrationToCoreData {
	
	init(dataHandler: DataHandler) {
		dh = dataHandler
		
		urlToOldGPXFolder = (try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true))?.appendingPathComponent("GPX Files")
		urlToOldGPXListFile = urlToOldGPXFolder?.appendingPathComponent("GPX Files List Description.data")
	}
	
	func startMigrationToCoreData() {
		/* Do we need to migrate anything? */
		let migratedKey = "Migrated v1 to CoreData"
		let migrationErrorKey = "Migration v1 Error"
		guard let urlToOldGPXFolder = urlToOldGPXFolder, let urlToOldGPXListFile = urlToOldGPXListFile else {
			return
		}
		guard var oldRecordingList = NSKeyedUnarchiver.unarchiveObject(withFile: urlToOldGPXListFile.path) as? [[String: Any]] else {
			return
		}
		let oldRecordingListToMigrate = oldRecordingList.enumerated().filter{ !(($0.element[migratedKey] as? Bool) ?? false) }
		guard !oldRecordingListToMigrate.isEmpty else {
			return
		}
		
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
		
		/* Let’s keep a strong reference to ourselves while the migration is in
		 * progress. */
		var strongSelf: MigrationToCoreData? = self
		context.perform{
			defer {
				NotificationCenter.default.post(name: .MigrationToCoreDataHasEnded, object: nil)
				
				NotificationCenter.default.removeObserver(observer, name: .NSManagedObjectContextDidSave, object: context)
				strongSelf = nil
			}
			
			#warning("TODO: Remove this sleep")
			Thread.sleep(forTimeInterval: 5)
			for (index, var oldRecordingDescription) in oldRecordingListToMigrate {
				#warning("and this one")
				Thread.sleep(forTimeInterval: 1)
				
				/* We only process the recording if we have its path. If we don’t,
				 * or if we cannot create the XML parser for the given path there is
				 * probably nothing we can do, we’ll mark the recording as migrated… */
				NSLog("%@", "\(oldRecordingDescription)")
				if
					let recordingGPXPath = oldRecordingDescription["Rec Path"] as? String,
					let recordingParser = XMLParser(contentsOf: urlToOldGPXFolder.appendingPathComponent(recordingGPXPath))
				{
					let recordingName = oldRecordingDescription["Recording Name"] as? String ?? NSLocalizedString("new recording", comment: "Default name for a recording")
					let recordingMaxSpeed = oldRecordingDescription["Max Reached Speed"] as? Double
					
					let newSegmentHandler = {
						NSLog("%@", "new segment start")
					}
					let newPointHandler = { (_ location: CLLocation, _ heading: Double?) in
						NSLog("%@", "new point: \(location), \(heading)")
					}
					let parserDelegate = GPXParserDelegate(newSegmentHandler: newSegmentHandler, newPointHandler: newPointHandler)
					recordingParser.delegate = parserDelegate
					if recordingParser.parse() ||
						((recordingParser.parserError as NSError?)?.domain == XMLParser.errorDomain &&
						 (recordingParser.parserError as NSError?)?.code == 111 /* Error code on early EOF; we don’t fail on early EOF */)
					{
						NSLog("%@", "parse done")
					} else {
						/* If parsing the GPX failed, we still mark the GPX as
						 * imported because there is nothing we can do. */
						oldRecordingDescription[migrationErrorKey] = "GPX Parse Fail"
					}
				} else {
					oldRecordingDescription[migrationErrorKey] = "No Rec Path or Parser Creation Failed"
				}
				
				oldRecordingDescription["test key"] = true
				oldRecordingList[index] = oldRecordingDescription
				guard NSKeyedArchiver.archiveRootObject(oldRecordingList, toFile: urlToOldGPXListFile.path) else {
					return
				}
			}
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
	
	private let urlToOldGPXFolder: URL?
	private let urlToOldGPXListFile: URL?
	
}


private final class GPXParserDelegate : NSObject, XMLParserDelegate {
	
	typealias SegmentHandler = () -> Void
	typealias PointHandler = (_ location: CLLocation, _ magvar: Double?) -> Void
	
	let newSegmentHandler: SegmentHandler
	let newPointHandler: PointHandler
	
	var textBuffer = ""
	
	var curLat: Double?
	var curLon: Double?
	var curDate: Date?
	var curHorizontalAccuracy: Double?
	var curMagVar: Double?
	var curAltitude: Double?
	var curVerticalAccuracy: Double?
	
	init(newSegmentHandler segmentHandler: @escaping SegmentHandler, newPointHandler pointHandler: @escaping PointHandler) {
		newSegmentHandler = segmentHandler
		newPointHandler = pointHandler
	}
	
	func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
		NSLog("open %@", elementName)
		switch elementName {
			case "trkseg":
				newSegmentHandler()
			
			case "trkpt":
				guard
					curLat == nil, curLon == nil,
					let lat = attributeDict["lat"].flatMap({ Double($0) }),
					let lon = attributeDict["lon"].flatMap({ Double($0) })
				else {
					return parser.abortParsing()
				}
				curLat = lat
				curLon = lon
			
			default:
				(/*nop*/)
		}
		textBuffer = ""
	}
	
	func parser(_ parser: XMLParser, foundCharacters string: String) {
		textBuffer += string
	}
	
	func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		NSLog("close %@ - %@", elementName, textBuffer)
		switch elementName {
			case "trkpt":
				guard
					let date = curDate,
					let lat = curLat,
					let lon = curLon,
					let horizontalAccuracy = curHorizontalAccuracy
				else {
					return parser.abortParsing()
				}
				let location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), altitude: curAltitude ?? -1, horizontalAccuracy: horizontalAccuracy, verticalAccuracy: curVerticalAccuracy ?? -1, timestamp: date)
				newPointHandler(location, curMagVar)
				
				curLat = nil
				curLon = nil
				curDate = nil
				curHorizontalAccuracy = nil
				curMagVar = nil
				curAltitude = nil
				curVerticalAccuracy = nil
			
			case "time":
				guard curDate == nil else {
					return parser.abortParsing()
				}
				if #available(iOS 10.0, *) {
					let formatter = ISO8601DateFormatter()
					guard let date = formatter.date(from: textBuffer) else {
						return parser.abortParsing()
					}
					curDate = date
				} else {
					let dateFormatter = DateFormatter()
					dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
					dateFormatter.locale = Locale(identifier: "en_US_POSIX")
					dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
					guard let date = dateFormatter.date(from: textBuffer) else {
						return parser.abortParsing()
					}
					curDate = date
				}
			
			case "hdop":
				guard curHorizontalAccuracy == nil, let val = Double(textBuffer) else {
					return parser.abortParsing()
				}
				curHorizontalAccuracy = val
			
			case "magvar":
				guard curMagVar == nil, let val = Double(textBuffer) else {
					return parser.abortParsing()
				}
				curMagVar = val
			
			case "ele":
				guard curAltitude == nil, let val = Double(textBuffer) else {
					return parser.abortParsing()
				}
				curAltitude = val
			
			case "vdop":
				guard curVerticalAccuracy == nil, let val = Double(textBuffer) else {
					return parser.abortParsing()
				}
				curVerticalAccuracy = val
			
			default:
				(/*nop*/)
		}
		textBuffer = ""
	}
	
}

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
	
	deinit {
		NSLog("Deinit of the MigrationToCoreData object")
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
			
			for (index, var oldRecordingDescription) in oldRecordingListToMigrate {
				/* We only process the recording if we have its path. If we don’t,
				 * or if we cannot create the XML parser for the given path there is
				 * probably nothing we can do, we’ll mark the recording as migrated… */
//				NSLog("%@", "\(oldRecordingDescription)")
				if
					let recordingGPXPath = oldRecordingDescription["Rec Path"] as? String,
					let recordingParser = XMLParser(contentsOf: urlToOldGPXFolder.appendingPathComponent(recordingGPXPath))
				{
					let recordingName = oldRecordingDescription["Recording Name"] as? String
					let recordingMaxSpeed = oldRecordingDescription["Max Reached Speed"] as? Float
					
					let totalTimeSegment = NSEntityDescription.insertNewObject(forEntityName: "TimeSegment", into: context) as! TimeSegment
					let recording = NSEntityDescription.insertNewObject(forEntityName: "Recording", into: context) as! Recording
					recording.totalTimeSegment = totalTimeSegment
					
					recording.name = NSLocalizedString("|name| (migrated)", comment: "Template name for a migrated recording.")
						.applyingCommonTokens(simpleReplacement1: recordingName ?? NSLocalizedString("new recording", comment: "Default name for a recording"))
					recording.maxSpeed = recordingMaxSpeed ?? 0
					
					var curSegmentID: Int16 = -1
					var latestPoint: RecordingPoint?
					var latestPointInSegment: RecordingPoint?
					var latestPause: TimeSegment?
					
					let newSegmentHandler = { () -> Bool in
						guard curSegmentID >= 0 else {
							curSegmentID = 0
							return true
						}
						
						guard let previousLatestPoint = latestPointInSegment else {
							/* We ignore empty segments. */
							return true
						}
						
						curSegmentID += 1
						latestPointInSegment = nil
						if curSegmentID > 0 {
							let timeSegment = NSEntityDescription.insertNewObject(forEntityName: "TimeSegment", into: context) as! TimeSegment
							timeSegment.startDate = previousLatestPoint.date
							timeSegment.pauseSegmentRecording = recording
							latestPause = timeSegment
						}
						return true
					}
					let newPointHandler = { (_ location: CLLocation, _ heading: Double?) -> Bool in
//						NSLog("%@", "\(curSegmentID)")
						guard curSegmentID >= 0 else {
							return false
						}
						if latestPoint == nil {
							assert(curSegmentID == 0)
							/* We’re in the first segment, we must set the start date
							 * of the total time segment!
							 * We assume order of points in GPX is correct. */
							totalTimeSegment.startDate = location.timestamp
						}
						
						/* Add the point in the recording. */
						let recordingPoint = NSEntityDescription.insertNewObject(forEntityName: "RecordingPoint", into: context) as! RecordingPoint
						recordingPoint.date = location.timestamp
						recordingPoint.location = location
						recordingPoint.segmentID = curSegmentID
						recordingPoint.importedMagvar = heading.flatMap{ NSNumber(value: $0) }
						
//						recording.addToPoints(recordingPoint) /* Does not work on iOS 9, so we have to do the line below! */
						recording.mutableSetValue(forKey: #keyPath(Recording.points)).add(recordingPoint)
						recording.totalDistance += latestPointInSegment?.location.flatMap{ Float($0.distance(from: location)) } ?? 0
						
						latestPause?.duration = latestPause?.startDate.flatMap{ startDate in location.timestamp.timeIntervalSince(startDate) }.flatMap{ NSNumber(value: $0) }
						latestPause = nil
						
						latestPoint = recordingPoint
						latestPointInSegment = recordingPoint
						
						return true
					}
					let parserDelegate = GPXParserDelegate(newSegmentHandler: newSegmentHandler, newPointHandler: newPointHandler)
					recordingParser.delegate = parserDelegate
					if recordingParser.parse() ||
						((recordingParser.parserError as NSError?)?.domain == XMLParser.errorDomain &&
						 (recordingParser.parserError as NSError?)?.code == 111 /* Error code on early EOF; we don’t fail on early EOF */)
					{
						do {
							if let latestPoint = latestPoint {
								if latestPointInSegment == nil {
									/* The latest segment is empty. We remove it. */
									latestPause.flatMap{ context.delete($0) }
								}
								/* Compute the average speed & close total time segment. */
								let duration = latestPoint.location!.timestamp.timeIntervalSince(totalTimeSegment.startDate!)
								totalTimeSegment.duration = NSNumber(value: duration)
								let activeDuration = recording.activeRecordingDuration
								if activeDuration > 0 {
									recording.averageSpeed = recording.totalDistance/Float(activeDuration)
								}
								try context.save()
							} else {
								/* If condition above fails, that means no points have
								 * been added to the recording. We do not save it and
								 * mark it as migrated. */
								context.rollback()
							}
						} catch {
							/* If we cannot save the context we assume the error is a
							 * CoreData validation error and we continue to next
							 * recording, marking current one as migrated, w/ a
							 * migration error. */
							oldRecordingDescription[migrationErrorKey] = "Cannot Save Context: \(error)"
							context.rollback()
						}
					} else {
						/* If parsing the GPX failed, we still mark the GPX as
						 * imported because there is nothing we can do AFAICT. */
						oldRecordingDescription[migrationErrorKey] = "GPX Parse Fail"
						context.rollback()
					}
				} else {
					oldRecordingDescription[migrationErrorKey] = "No Rec Path or Parser Creation Failed"
				}
				
				oldRecordingDescription[migratedKey] = true
				oldRecordingList[index] = oldRecordingDescription
				guard NSKeyedArchiver.archiveRootObject(NSMutableArray(array: oldRecordingList), toFile: urlToOldGPXListFile.path) else {
					return
				}
			}
		}
	}
	
	private let dh: DataHandler
	
	private let urlToOldGPXFolder: URL?
	private let urlToOldGPXListFile: URL?
	
}


private final class GPXParserDelegate : NSObject, XMLParserDelegate {
	
	typealias SegmentHandler = () -> Bool
	typealias PointHandler = (_ location: CLLocation, _ magvar: Double?) -> Bool
	
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
		switch elementName {
			case "trkseg":
				guard newSegmentHandler() else {
					return parser.abortParsing()
				}
			
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
				guard newPointHandler(location, curMagVar) else {
					return parser.abortParsing()
				}
				
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

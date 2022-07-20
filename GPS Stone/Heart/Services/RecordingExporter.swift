/*
 * RecordingExporter.swift
 * GPS Stone
 *
 * Created by François Lamboley on 03/10/2020.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import CommonCrypto /* md5, before iOS 13. */
import CoreData
#if canImport(CryptoKit)
import CryptoKit /* md5 */
#endif
import Foundation

import XibLoc



final class RecordingExporter {
	
	static func recordingName(of recordingID: NSManagedObjectID, context: NSManagedObjectContext) -> String {
		return (try? context.performAndWait{ try Recording.existingFrom(id: recordingID, in: context).name }) ?? RecordingExporter.defaultRecordingName
	}
	
	init(dataHandler: DataHandler) {
		dh = dataHandler
	}
	
	func preparedExport(of recordingID: NSManagedObjectID, context: NSManagedObjectContext) throws -> URL? {
		let recordingName = try context.performAndWait{ try Recording.existingFrom(id: recordingID, in: context).name }
		let url = try urlForRecordingID(recordingID, recordingName: recordingName)
		
		var isDir = ObjCBool(true)
		let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
		
		return (exists && !isDir.boolValue ? url : nil)
	}
	
	/* Note: We assume here recordings do not change ever, and once a recording has been converted to GPX, if we have the converted version in the cache, we use it and return it directly. */
	func prepareExport(of recordingID: NSManagedObjectID, handler: @escaping (_ result: Result<URL, Error>) -> Void) -> Progress {
		let progress = Progress()
		let context = dh.bgContext
		context.perform{
			let r = Result{ try self.prepareExportSyncOnContext(of: recordingID, context: context, progress: progress) }
			DispatchQueue.main.async{ handler(r) }
		}
		return progress
	}
	
	func prepareExportSyncOnContext(of recordingID: NSManagedObjectID, context: NSManagedObjectContext, progress: Progress?) throws -> URL {
		let fileManager = FileManager.default
		let recording = try Recording.existingFrom(id: recordingID, in: context)
		
		let outputURL = try urlForRecordingID(recordingID, recordingName: recording.name)
		let inprogressOutputURL = outputURL.appendingPathExtension("inprogress")
		
		/* First let’s check if the file has not already been created.
		 * Note: We also check if the file existing, if it exists, is indeed a file and not a directory.
		 * If it is a directory, we’ll delete it. */
		var isDir = ObjCBool(true)
		let outputExists = fileManager.fileExists(atPath: outputURL.path, isDirectory: &isDir)
		guard !outputExists || isDir.boolValue else {
			return outputURL
		}
		
		if outputExists {try fileManager.removeItem(at: outputURL)}
		
		/* We now have a clean slate.
		 * Let’s work. */
		try Data().write(to: inprogressOutputURL)
		let fileHandle = try FileHandle(forWritingTo: inprogressOutputURL)
		defer {
			if #available(iOS 13.0, *) {_ = try? fileHandle.close()}
			else                       {fileHandle.closeFile()}
		}
		
		/* Write the preamble. */
		let creator = NSLocalizedString("gpx creator tag", comment: "The text in the “creator” field of the GPX exports.")
			.applyingCommonTokens(simpleReplacement1: (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap{ " " + $0 } ?? "")
		let preamble = """
			<?xml version="1.0" encoding="UTF-8"?>
			<gpx creator="\(xmlString(creator))" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.topografix.com/GPX/1/1" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
				<metadata>
					<name>\(xmlString(recording.name ?? RecordingExporter.defaultRecordingName))</name>
					<link href="https://frostland.fr/products/gpsstone/">
						<text>\(xmlString(NSLocalizedString("gps stone link text in gpx", comment: "The text for the GPS Stone link in a GPX export.")))</text>
						<type>text/html</type>
					</link>
					<time>\(xmlString(isoStringFromDate(recording.startDate ?? Date())))</time>
					<keywords>gpsstone,gps stone,gps,stone</keywords>
				</metadata>
				<trk>
			
			"""
		fileHandle.write(Data(preamble.utf8))
		
		/* Write the points. */
		var curSegment: Int16?
		let points = try recording.pointsSortedByDateAscending()
		progress?.totalUnitCount = Int64(points.count)
		for point in points {
			defer {progress?.completedUnitCount += 1}
			
			guard let pointLocation = point.location, pointLocation.horizontalAccuracy.sign == .plus else {continue}
			
			let rawMagvar = point.heading?.trueHeading ?? point.importedMagvar?.doubleValue ?? pointLocation.course
			let magvar = (rawMagvar.sign == .plus ? rawMagvar : nil)
			let altitude = (pointLocation.verticalAccuracy.sign == .plus ? pointLocation.altitude : nil)
			
			/* Write segment start, with previous segment end if needed. */
			if curSegment != point.segmentID {
				if curSegment != nil {
					let segmentEnd = """
								</trkseg>
						
						"""
					fileHandle.write(Data(segmentEnd.utf8))
				}
				let segmentStart = """
							<trkseg>
					
					"""
				fileHandle.write(Data(segmentStart.utf8))
			}
			curSegment = point.segmentID
			
			/* Write the segment point. */
			let latStr = String(format: "%.10f", pointLocation.coordinate.latitude)
			let lonStr = String(format: "%.10f", pointLocation.coordinate.longitude)
			let hdopStr = String(format: "%f", pointLocation.horizontalAccuracy)
			let magvarStr = magvar.flatMap{ String(format: "%f", $0) }
			let altitudeStr = altitude.flatMap{ String(format: "%f", $0) }
			let verticalAccuracyStr = altitude.flatMap{ _ in String(format: "%f", pointLocation.verticalAccuracy) }
			let pointLines = [
													  #"\#t\#t\#t<trkpt lat="\#(xmlString(latStr))" lon="\#(xmlString(lonStr))">"#,
				point.date.flatMap{          #"\#t\#t\#t\#t<time>\#(xmlString(isoStringFromDate($0)))</time>"# },
													  #"\#t\#t\#t\#t<hdop>\#(xmlString(hdopStr))</hdop>"#,
				magvarStr.flatMap{           #"\#t\#t\#t\#t<magvar>\#(xmlString($0))</magvar>"# },
				altitudeStr.flatMap{         #"\#t\#t\#t\#t<ele>\#(xmlString($0))</ele>"# },
				verticalAccuracyStr.flatMap{ #"\#t\#t\#t\#t<vdop>\#(xmlString($0))</vdop>"# },
													  #"\#t\#t\#t</trkpt>"#,
				""
				].compactMap{ $0 }
			fileHandle.write(Data(pointLines.joined(separator: "\n").utf8))
		}
		
		/* Write the end. */
		if curSegment != nil {
			let segmentEnd = """
						</trkseg>
				
				"""
			fileHandle.write(Data(segmentEnd.utf8))
		}
		let end = """
				</trk>
			</gpx>
			
			"""
		fileHandle.write(Data(end.utf8))
		
		try fileManager.moveItem(at: inprogressOutputURL, to: outputURL)
		
		return outputURL
	}
	
	static let defaultRecordingName = NSLocalizedString("default recording name", comment: "The name of a recording when no name is given.")
	
	private let dh: DataHandler
	
//	private let workQueue = DispatchQueue(label: Constants.appDomain + ".RecordingExporter.work-queue", qos: .background)
	
	private func urlForRecordingID(_ recordingID: NSManagedObjectID, recordingName: String?) throws -> URL {
		/* The hash will be the name of the folder we’ll use to store the GPX file. */
		func commonCryptoHash(_ data: Data) -> String {
			let checksumPointer = malloc(Int(CC_MD5_DIGEST_LENGTH))!.assumingMemoryBound(to: UInt8.self)
			let data = Data(recordingID.uriRepresentation().absoluteString.utf8)
			data.withUnsafeBytes{ dataBytes in
				_ = CC_MD5(dataBytes.baseAddress!, CC_LONG(dataBytes.count), checksumPointer)
			}
			return (0..<Int(CC_MD5_DIGEST_LENGTH)).reduce("", { $0 + String(format: "%02x", checksumPointer[$1]) })
		}
		
		let hash: String
		let hashedData = Data((recordingID.uriRepresentation().absoluteString + "_v2").utf8)
		if #available(iOS 13.0, *) {
			#if canImport(CryptoKit)
			hash = Insecure.MD5.hash(data: hashedData).reduce("", { $0 + String(format: "%02x", $1) })
			#else
			hash = commonCryptoHash(hashedData)
			#endif
		} else {
			hash = commonCryptoHash(hashedData)
		}
		
		let parent = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(hash)
		try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: nil)
		
		let safeRecordingName = (recordingName ?? RecordingExporter.defaultRecordingName).replacingOccurrences(of: "/", with: ":").replacingOccurrences(of: ".", with: "_", options: .anchored)
		return parent.appendingPathComponent(safeRecordingName).appendingPathExtension("gpx")
	}
	
	private func xmlString(_ string: String) -> String {
		return string
			.replacingOccurrences(of: "&",  with: "&amp;")
			.replacingOccurrences(of: "\"", with: "&quot;")
			.replacingOccurrences(of: "'",  with: "&#39;")
			.replacingOccurrences(of: ">",  with: "&gt;")
			.replacingOccurrences(of: "<",  with: "&lt;")
	}
	
	private func isoStringFromDate(_ date: Date) -> String {
		if #available(iOS 10.0, *) {
			let dateFormatter = ISO8601DateFormatter()
			dateFormatter.formatOptions = [.withFullDate, .withFullTime]
			return dateFormatter.string(from: date)
		} else {
			let dateFormatter = DateFormatter()
			dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
			dateFormatter.locale = Locale(identifier: "en_US_POSIX")
			dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
			return dateFormatter.string(from: date)
		}
	}
	
}

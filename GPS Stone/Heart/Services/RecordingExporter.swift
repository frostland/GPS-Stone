/*
 * RecordingExporter.swift
 * GPS Stone
 *
 * Created by François Lamboley on 03/10/2020.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import CommonCrypto /* md5, before iOS 13. */
import CoreData
import CryptoKit /* md5 */
import Foundation

import XibLoc



final class RecordingExporter {
	
	init(dataHandler: DataHandler) {
		dh = dataHandler
	}
	
	func preparedExport(of recordingID: NSManagedObjectID) throws -> URL? {
		let url = try urlForRecordingID(recordingID)
		
		var isDir = ObjCBool(true)
		let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
		
		return (exists && !isDir.boolValue ? url : nil)
	}
	
	/* Note: We assume here recordings do not change ever, and once a recording
	 *       has been converted to GPX, if we have the converted version in the
	 *       cache, we use it and return it directly. */
	func prepareExport(of recordingID: NSManagedObjectID, handler: @escaping (_ result: Result<URL, Error>) -> Void) -> Progress {
		let progress = Progress()
		let context = dh.bgContext
		context.perform{
			do {
				let fileManager = FileManager.default
				let recording = try Recording.existingFrom(id: recordingID, in: context)
				
				let outputURL = try self.urlForRecordingID(recordingID)
				let inprogressOutputURL = outputURL.appendingPathExtension("inprogress")
				
				/* First let’s check if the file has not already been created. Note:
				 * We also check if the file existing, if it exists, is indeed a
				 * file and not a directory. If it is a directory, we’ll delete it. */
				var isDir = ObjCBool(true)
				let outputExists = fileManager.fileExists(atPath: outputURL.path, isDirectory: &isDir)
				guard !outputExists || isDir.boolValue else {
					DispatchQueue.main.async{
						handler(.success(outputURL))
					}
					return
				}
				
				if outputExists {try fileManager.removeItem(at: outputURL)}
				
				/* We now have a clean slate. Let’s work. */
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
					<gpx creator="\(self.xmlString(creator))" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.topografix.com/GPX/1/1" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
						<trk>
					
					"""
				fileHandle.write(Data(preamble.utf8))
				
				/* Write the points. */
				var curSegment: Int16?
				let points = try recording.pointsSortedByDateAscending()
				progress.totalUnitCount = Int64(points.count)
				for point in points {
					defer {progress.completedUnitCount += 1}
					
					guard let pointLocation = point.location, pointLocation.horizontalAccuracy.sign == .plus else {continue}
					
					let rawMagvar = point.heading?.trueHeading ?? pointLocation.course
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
					let lonStr = String(format: "%.10f", pointLocation.coordinate.latitude)
					let hdopStr = String(format: "%f", pointLocation.horizontalAccuracy)
					let magvarStr = magvar.flatMap{ String(format: "%f", $0) }
					let altitudeStr = altitude.flatMap{ String(format: "%f", $0) }
					let verticalAccuracyStr = altitude.flatMap{ _ in String(format: "%f", pointLocation.verticalAccuracy) }
					let pointLines = [
						                             #"\#t\#t\#t<trkpt lat="\#(self.xmlString(latStr))" lon="\#(self.xmlString(lonStr))">"#,
						point.date.flatMap{          #"\#t\#t\#t\#t<time>\#(self.xmlString(self.isoStringFromDate($0)))</time>"# },
						                             #"\#t\#t\#t\#t<hdop>\#(self.xmlString(hdopStr))</hdop>"#,
						magvarStr.flatMap{           #"\#t\#t\#t\#t<magvar>\#(self.xmlString($0))</magvar>"# },
						altitudeStr.flatMap{         #"\#t\#t\#t\#t<ele>\#(self.xmlString($0))</ele>"# },
						verticalAccuracyStr.flatMap{ #"\#t\#t\#t\#t<vdop>\#(self.xmlString($0))</vdop>"# },
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
				
				DispatchQueue.main.async{
					handler(.success(outputURL))
				}
			} catch {
				DispatchQueue.main.async{
					handler(.failure(error))
				}
			}
		}
		return progress
	}
	
	private let dh: DataHandler
	
//	private let workQueue = DispatchQueue(label: Constants.appDomain + ".RecordingExporter.work-queue", qos: .background)
	
	private func urlForRecordingID(_ recordingID: NSManagedObjectID) throws -> URL {
		/* The hash will be the base id we’ll use to store the GPX file. */
		let hash: String
		if #available(iOS 13.0, *) {
			hash = Insecure.MD5.hash(data: Data(recordingID.uriRepresentation().absoluteString.utf8)).reduce("", { $0 + String(format: "%02x", $1) })
		} else {
			let checksumPointer = malloc(Int(CC_MD5_DIGEST_LENGTH))!.assumingMemoryBound(to: UInt8.self)
			let data = Data(recordingID.uriRepresentation().absoluteString.utf8)
			data.withUnsafeBytes{ dataBytes in
				_ = CC_MD5(dataBytes.baseAddress!, CC_LONG(dataBytes.count), checksumPointer)
			}
			hash = (0..<Int(CC_MD5_DIGEST_LENGTH)).reduce("", { $0 + String(format: "%02x", checksumPointer[$1]) })
		}
		return try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(hash).appendingPathExtension("gpx")
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

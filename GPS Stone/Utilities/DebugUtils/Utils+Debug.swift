/*
 * Utils+Debug.swift
 * GPS Stone
 *
 * Created by François Lamboley on 17/06/2020.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import Foundation



extension Utils {
	
	static let debugLogId: String = {
		let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
		return String(dateComponents.year!) + "-" + String(dateComponents.month!) + "-" + String(dateComponents.day!) + "@" + String(dateComponents.hour!) + "-" + String(dateComponents.minute!) + "-" + String(dateComponents.second!) + "_" + UUID().uuidString
	}()
	
	@available(*, deprecated, message: "This should not make it to prod!")
	static func debugLog(_ message: String, to: String) {
		let url = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(to + "_" + Utils.debugLogId).appendingPathExtension("txt")
		if !FileManager.default.fileExists(atPath: url.path) {
			FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
		}
		let fh = try! FileHandle(forUpdating: url)
		defer {fh.closeFile()}
		fh.seekToEndOfFile()
		fh.write(Data(("\(Date()): " + message + "\n\n").utf8))
	}
	
}

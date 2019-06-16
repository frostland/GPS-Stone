/*
 * RecordingsManager.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/6/8.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import Foundation



/* Inherits from NSObject to allow KVO on the instances.
 * TODO: Switch to Combine! */
class RecordingsManager : NSObject {
	
	/* KVObservable */
	private(set) var recordings: [RecordingInfo]
	
	init(constants: Constants) {
		c = constants
		
		let decoder = JSONDecoder()
		recordings = (try? decoder.decode([RecordingInfo].self, from: Data(contentsOf: constants.urlToGPXList))) ?? []
	}
	
	func addRecording(_ recordingInfo: RecordingInfo) {
		let idxSet = IndexSet(arrayLiteral: recordings.count)
		
		willChange(.insertion, valuesAt: idxSet, for: \.recordings)
		recordings.append(recordingInfo)
		didChange(.insertion, valuesAt: idxSet, for: \.recordings)
	}
	
	func deleteRecording(at index: Int) {
		let idxSet = IndexSet(arrayLiteral: index)
		
		willChange(.removal, valuesAt: idxSet, for: \.recordings)
		recordings.remove(at: index)
		didChange(.removal, valuesAt: idxSet, for: \.recordings)
	}
	
	func createNextGPXFile() -> URL {
		let fm = FileManager.default
		
		let url = (1...).lazy.map{ self.c.urlToGPX(number: $0) }.first{ !fm.fileExists(atPath: $0.path) }!
		/* TODO: This is bad, to just assume the file creation will work… */
		_ = fm.createFile(atPath: url.path, contents: nil, attributes: nil)
		return url
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/* *** Dependencies *** */
	
	let c: Constants
	
}

/*
 * MemoryEater.swift
 * Memory Eater
 *
 * Created by François Lamboley on 18/06/2020.
 * Copyright © 2020 Frizlab. All rights reserved.
 */

import Foundation



@available(*, deprecated, message: "This should not make it to prod!")
class MemoryEater {
	
	var eatingMemory: Bool {
		setEatingQueue.sync{ _eatingMemory }
	}
	
	func eatMemoryIfNotDoingIt() {
		guard setEatingMemory(true) else {
			return
		}
		
		eatQueue.addOperation(EatMemoryOperation())
	}
	
	private var eatQueue = OperationQueue()
	
	private var setEatingQueue = DispatchQueue(label: "me.frizlab.Memory-Eater.MemoryEater.setEatingQueue", qos: .userInteractive, attributes: [/*.serial*/])
	private var _eatingMemory = false
	
	private func setEatingMemory(_ newValue: Bool) -> Bool {
		setEatingQueue.sync{
			guard newValue != _eatingMemory else {return false}
			_eatingMemory = newValue
			return true
		}
	}
	
	private class EatMemoryOperation : Operation {
		
		override var isAsynchronous: Bool {
			return false
		}
		
		override func main() {
			let blockSize = 150 * 1024 * 1024
			
			defer {cleanup()}
			while !isCancelled {
				guard let ptr = malloc(blockSize) else {
					NSLog("%@", "Cannot allocate new memory block")
					return
				}
				NSLog("%@", "Allocated \(blockSize) new bytes")
				ptrDescs.append((ptr, blockSize))
				
				for i in 0..<blockSize {
					let v = ptr.advanced(by: i).load(as: Int8.self) &+ 1
					ptr.advanced(by: i).storeBytes(of: v, as: Int8.self)
				}
			}
		}
		
		private var ptrDescs = [(UnsafeMutableRawPointer, Int)]()
		
		private func cleanup() {
			for ptrDesc in ptrDescs {
				free(ptrDesc.0)
			}
			ptrDescs = []
		}
		
	}
	
}

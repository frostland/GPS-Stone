/*
 * MapViewController.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/6/19.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreData
import Foundation
import MapKit
import os.log
import UIKit

import KVObserver
import RetryingOperation



class MapViewController : UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
	
	@IBOutlet var buttonCenterMapOnCurLoc: UIButton!
	@IBOutlet var mapView: MKMapView!
	@IBOutlet var viewStatusBarBlur: UIView!
	
	var boundingMapRect: MKMapRect = .null
	var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
	
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .default
	}
	
	deinit {
		pointsProcessingQueue.cancelAllOperations()
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		_ = kvObserver.observe(object: locationRecorder, keyPath: #keyPath(LocationRecorder.objc_status), kvoOptions: [.initial], dispatchType: .asyncOnMainQueueDirectInitial, handler: { [weak self] _ in
			guard let self = self else {return}
			self.currentRecording = self.locationRecorder.status.recordingRef.flatMap{ self.recordingsManager.unsafeRecording(from: $0) }
		})
	}
	
	func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
		assert(overlay is MKPolyline)
		let r = MKPolylineRenderer(overlay: overlay)
		r.strokeColor = UIColor(red: 92/255, green: 43/255, blue: 153/255, alpha: 0.75)
		r.lineWidth = 5
		return r
	}
	
	/* *******************************************
	   MARK: - Fetched Results Controller Delegate
	   ******************************************* */
	
	func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		/* Note: We could use the controller did change section/object methods,
		 *       however, I don’t think we’d gain _anything at all_ in terms of
		 *       performance, so let’s just do this instead (which avoids having
		 *       to create non-trivial alorithms to reconcile the cache with the
		 *       change notification we’d get from the controller). */
		assert(controller === pointsFetchResultsController)
		pointsProcessingQueue.addOperation(createProcessPointsOperation())
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let c = S.sp.constants
	private let locationRecorder = S.sp.locationRecorder
	private let recordingsManager = S.sp.recordingsManager
	
	private let pointsProcessingQueue: OperationQueue = {
		let ret = OperationQueue()
		ret.name = "Points Processing Queue"
		ret.maxConcurrentOperationCount = 1
		return ret
	}()
	
	private let kvObserver = KVObserver()
	private var pointsFetchResultsController: NSFetchedResultsController<RecordingPoint>?
	
	private var polylinesCache = PolylinesCache()
	
	private var currentRecording: Recording? {
		willSet {
			pointsFetchResultsController?.delegate = nil
			pointsFetchResultsController = nil
			
			pointsProcessingQueue.cancelAllOperations()
			mapView.removeOverlays(mapView.overlays)
			polylinesCache = PolylinesCache()
		}
		didSet  {
			guard let r = currentRecording, let c = r.managedObjectContext else {return}
			
			let fetchRequest: NSFetchRequest<RecordingPoint> = RecordingPoint.fetchRequest()
			fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(RecordingPoint.recording), r)
			fetchRequest.sortDescriptors = [
				NSSortDescriptor(keyPath: \RecordingPoint.segmentId, ascending: true),
				NSSortDescriptor(keyPath: \RecordingPoint.date, ascending: true)
			]
			let ctrl = NSFetchedResultsController<RecordingPoint>(
				fetchRequest: fetchRequest, managedObjectContext: c,
				sectionNameKeyPath: #keyPath(RecordingPoint.segmentId),
				cacheName: r.objectID.uriRepresentation().absoluteString
			)
			
			do {
				try ctrl.performFetch()
				
				pointsFetchResultsController = ctrl
				ctrl.delegate = self
				
				pointsProcessingQueue.addOperation(createProcessPointsOperation())
			} catch {
				/* We do nothing in case of an error. The map will simply never be updated… */
			}
		}
	}
	
	private func createProcessPointsOperation() -> ProcessPointsOperation {
		#warning("In Swift 5.1 we’ll probably be able to remove the return in the line below")
		let getter = { [weak self] () -> PolylinesCache? in assert(Thread.isMainThread); return self?.polylinesCache }
		let setter = { [weak self] (c: PolylinesCache)   in assert(Thread.isMainThread); self?.polylinesCache = c; self?.processPendingPolylines() }
		return ProcessPointsOperation(fetchedResultsController: pointsFetchResultsController!, polylinesCacheGetter: getter, polylinesCacheSetter: setter)
	}
	
	private func processPendingPolylines() {
		assert(Thread.isMainThread)
//		print("-----")
//		print("current:    \(mapView.overlays.compactMap{ $0 as? MKPolyline }.map{ "\($0) (\($0.pointCount) points)" })")
//		print("n sections: \(polylinesCache.numberOfSections)")
//		print("npts/sctn:  \(polylinesCache.nPointsBySection.map{ String($0) }.joined(separator: ", "))")
//		print("remove:     \(polylinesCache.polylinesToRemoveFromMap.map{ "\($0) (\($0.pointCount) points)" })")
//		print("plain add:  \(polylinesCache.plainPolylinesToAddToMap.map{ "\($0) (\($0.pointCount) points)" })")
//		print("dotted add: \(polylinesCache.dottedPolylinesToAddToMap.map{ "\($0) (\($0.pointCount) points)" })")
		mapView.addOverlays(Array(polylinesCache.plainPolylinesToAddToMap))
		mapView.addOverlays(Array(polylinesCache.dottedPolylinesToAddToMap))
		mapView.removeOverlays(Array(polylinesCache.polylinesToRemoveFromMap))
		
		polylinesCache.polylinesToRemoveFromMap.removeAll()
		polylinesCache.plainPolylinesToAddToMap.removeAll()
		polylinesCache.dottedPolylinesToAddToMap.removeAll()
	}
	
}

fileprivate struct PolylinesCache {
	
	var numberOfSections = 0
	
	/* The number of points currently added in the cache for a given section. */
	var nPointsBySection = [Int]()
	/* We break down each section to polylines of 100 points in order to avoid
	 * having to redraw the whole path each time a new point is added. This is
	 * why polylinesBySection is an array of array of polylines instead of a
	 * simple array of polylines. */
	var polylinesBySection = [[MKPolyline]]()
	/* Between each sections we show a dotted line indicating missing information
	 * (the recording was paused). This variable contains these polylines. They
	 * are optional because some section might not have any points in them, in
	 * which case there are no dotted line to show, but we must still have an
	 * element in the array to have the correct count of objects in the array. */
	var interSectionPolylines = [MKPolyline?]()
	
	var polylinesToRemoveFromMap = Set<MKPolyline>()
	var plainPolylinesToAddToMap = Set<MKPolyline>()
	var dottedPolylinesToAddToMap = Set<MKPolyline>()
	
}

/* Note: We overwrite RetryingOperation instead of Operation mainly because I
 * have taken the habit of doing so, but in this case overwriting `main` in a
 * standard Operation would have been fine… */
fileprivate class ProcessPointsOperation : RetryingOperation {
	
	let polylinesCacheGetter: () -> PolylinesCache?
	let polylinesCacheSetter: (PolylinesCache) -> Void
	let fetchedResultsController: NSFetchedResultsController<RecordingPoint>
	
	init(fetchedResultsController frc: NSFetchedResultsController<RecordingPoint>, polylinesCacheGetter pcg: @escaping () -> PolylinesCache?, polylinesCacheSetter pcs: @escaping (PolylinesCache) -> Void) {
		assert(Thread.isMainThread)
		
		polylinesCacheGetter = pcg
		polylinesCacheSetter = pcs
		fetchedResultsController = frc
	}
	
	override var isAsynchronous: Bool {
		return false
	}
	
	override func startBaseOperation(isRetry: Bool) {
		defer {baseOperationEnded()}
		
		guard let computationResult = computePointsToProcess() else {return}
		var polylinesCache = computationResult.0
		let pointsToProcess = computationResult.1
		
		let startSectionIndex = max(polylinesCache.numberOfSections-1, 0)
		
		for (sectionDelta, var pointsInSection) in pointsToProcess.enumerated() {
			guard !isCancelled else {return}
			
			let sectionIndex = startSectionIndex + sectionDelta
			assert(sectionIndex <= polylinesCache.numberOfSections)
			
			/* Add a section in the cache if needed */
			if sectionIndex == polylinesCache.numberOfSections {
				polylinesCache.numberOfSections += 1
				polylinesCache.nPointsBySection.append(0)
				polylinesCache.polylinesBySection.append([])
				if sectionDelta+1 < pointsToProcess.count {
					if let p1 = pointsInSection.first, let p2 = pointsToProcess[sectionDelta+1].first {
						let l = MKPolyline(coordinates: [p1, p2], count: 2)
						polylinesCache.interSectionPolylines.append(l)
						polylinesCache.dottedPolylinesToAddToMap.insert(l)
					} else {
						polylinesCache.interSectionPolylines.append(nil)
					}
				}
			}
			
			/* Add the new points in the current section */
			let polylinesMaxPointCount = 3
			while pointsInSection.count > 0 {
				guard !isCancelled else {return}
				
				if let latestPolylineOfSection = polylinesCache.polylinesBySection[sectionIndex].last {
					assert(latestPolylineOfSection.pointCount > 0, "Got a polyline with no points in it for section \(sectionIndex) in cache \(polylinesCache)")
					let latestPoint = latestPolylineOfSection.points().advanced(by: latestPolylineOfSection.pointCount-1).pointee
					if latestPolylineOfSection.pointCount == polylinesMaxPointCount {
						/* The latest polyline for the section has the maximum number
						 * points allowed: we must create a new polyline. */
						let nPointsToAdd = min(pointsInSection.count, polylinesMaxPointCount-1)
						let pointsToAdd = [latestPoint.coordinate] + Array(pointsInSection[0..<nPointsToAdd])
						let polyline = MKPolyline(coordinates: pointsToAdd, count: pointsToAdd.count)
						polylinesCache.polylinesBySection[sectionIndex].append(polyline)
						polylinesCache.plainPolylinesToAddToMap.insert(polyline)
						polylinesCache.nPointsBySection[sectionIndex] += nPointsToAdd
						pointsInSection.removeFirst(nPointsToAdd)
					} else {
						/* We can shove more points in the latest polyline of the
						 * section. Let’s do it! */
						let currentPoints = (latestPolylineOfSection.points()..<latestPolylineOfSection.points().advanced(by: latestPolylineOfSection.pointCount)).map{ $0.pointee.coordinate }
						let nPointsToAdd = min(pointsInSection.count, polylinesMaxPointCount-latestPolylineOfSection.pointCount)
						let pointsToAdd = currentPoints + Array(pointsInSection[0..<nPointsToAdd])
						let polyline = MKPolyline(coordinates: pointsToAdd, count: pointsToAdd.count)
						polylinesCache.polylinesBySection[sectionIndex].removeLast()
						polylinesCache.polylinesBySection[sectionIndex].append(polyline)
						polylinesCache.polylinesToRemoveFromMap.insert(latestPolylineOfSection)
						polylinesCache.plainPolylinesToAddToMap.insert(polyline)
						polylinesCache.nPointsBySection[sectionIndex] += nPointsToAdd
						pointsInSection.removeFirst(nPointsToAdd)
					}
				} else {
					/* There are no polylines at all for the moment in the current
					 * section. We must add one. */
					let nPointsToAdd = min(pointsInSection.count, polylinesMaxPointCount)
					let pointsToAdd = Array(pointsInSection[0..<nPointsToAdd])
					let polyline = MKPolyline(coordinates: pointsToAdd, count: pointsToAdd.count)
					polylinesCache.polylinesBySection[sectionIndex].append(polyline)
					polylinesCache.plainPolylinesToAddToMap.insert(polyline)
					polylinesCache.nPointsBySection[sectionIndex] += nPointsToAdd
					pointsInSection.removeFirst(nPointsToAdd)
				}
			}
		}
		
		DispatchQueue.main.sync{ polylinesCacheSetter(polylinesCache) }
	}
	
	private func computePointsToProcess() -> (PolylinesCache, [[CLLocationCoordinate2D]])? {
		return DispatchQueue.main.sync{
			guard let pc = polylinesCacheGetter() else {
				return nil
			}
			
			guard let sections = fetchedResultsController.sections else {
				return (pc, [])
			}
			
			var pointsToProcessBuilding = [[CLLocationCoordinate2D]]()
			for i in max(pc.numberOfSections-1, 0)..<sections.count {
				let section = sections[i]
				guard let points = section.objects as! [RecordingPoint]? else {
					pointsToProcessBuilding.append([])
					continue
				}
				if pc.numberOfSections > i {pointsToProcessBuilding.append(points[pc.nPointsBySection[i]..<points.count].map{ $0.location!.coordinate })}
				else                       {pointsToProcessBuilding.append(                                       points.map{ $0.location!.coordinate })}
			}
			return (pc, pointsToProcessBuilding)
		}
	}
	
}

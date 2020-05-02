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
	
	var boundingMapRect: MKMapRect = .null
	var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
	
	var recording: Recording?
	
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .default
	}
	
	deinit {
		pointsProcessingQueue.cancelAllOperations()
		
		if let o = settingsObserver {
			NotificationCenter.default.removeObserver(o)
			settingsObserver = nil
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		mapView.mapType = appSettings.mapType
		
		assert(settingsObserver == nil)
		settingsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main, using: { [weak self] _ in
			guard let self = self else {return}
			self.mapView.mapType = self.appSettings.mapType
		})
		
		if recording == nil {
			_ = kvObserver.observe(object: locationRecorder, keyPath: #keyPath(LocationRecorder.objc_recStatus), kvoOptions: [.initial], dispatchType: .asyncOnMainQueueDirectInitial, handler: { [weak self] _ in
				guard let self = self else {return}
				self.currentRecording = self.locationRecorder.recStatus.recordingRef.flatMap{ self.recordingsManager.unsafeRecording(from: $0) }
			})
		} else {
			currentRecording = recording
		}
		
		centerMapOnCurLoc(self)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		locationRecorder.retainLocationTracking()
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		
		locationRecorder.releaseLocationTracking()
	}
	
	@IBAction func centerMapOnCurLoc(_ sender: Any) {
		appSettings.followLocationOnMap = true
		
		guard let pos = locationRecorder.currentLocation else {return}
		mapView.setRegion(MKCoordinateRegion(center: pos.coordinate, latitudinalMeters: 500, longitudinalMeters: 500), animated: true)
	}
	
	/* *************************
	   MARK: - Map View Delegate
	   ************************* */
	
	func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
		appSettings.latestMapRect = MKCoordinateRegion(mapView.visibleMapRect)
	}
	
	func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
		assert(overlay is MKPolyline)
		let r = MKPolylineRenderer(overlay: overlay)
		r.strokeColor = UIColor(red: 92/255, green: 43/255, blue: 153/255, alpha: 0.75)
		r.lineWidth = 5
		if polylinesCache.interSectionPolylines.contains(where: { $0 === overlay }) {
			r.strokeColor = UIColor(red: 92/255, green: 43/255, blue: 153/255, alpha: 0.5)
			r.lineDashPattern = [12, 16]
		}
		return r
	}
	
	/* *******************************************
	   MARK: - Fetched Results Controller Delegate
	   ******************************************* */
	
	func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		assert(controller === pointsFetchResultsController)
		/* Note: We could use the controller did change section/object methods,
		 *       however, I don’t think we’d gain _anything at all_ in terms of
		 *       performance, so let’s just do this instead (which avoids having
		 *       to create non-trivial alorithms to reconcile the cache with the
		 *       change notification we’d get from the controller). */
		pointsProcessingQueue.addOperation(createProcessPointsOperation())
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let c = S.sp.constants
	private let appSettings = S.sp.appSettings
	private let locationRecorder = S.sp.locationRecorder
	private let recordingsManager = S.sp.recordingsManager
	
	private let polylinesMaxPointCount = 100
	
	private let pointsProcessingQueue: OperationQueue = {
		let ret = OperationQueue()
		ret.name = "Points Processing Queue"
		ret.maxConcurrentOperationCount = 1
		return ret
	}()
	
	private let kvObserver = KVObserver()
	private var settingsObserver: NSObjectProtocol?
	private var pointsFetchResultsController: NSFetchedResultsController<RecordingPoint>?
	
	private var polylinesCache = PolylinesCache()
	
	private var currentRecording: Recording? {
		willSet {
			guard currentRecording != newValue else {return}
			
			pointsFetchResultsController?.delegate = nil
			pointsFetchResultsController = nil
			
			pointsProcessingQueue.cancelAllOperations()
			mapView.removeOverlays(mapView.overlays)
			polylinesCache = PolylinesCache()
		}
		didSet  {
			guard currentRecording != oldValue else {return}
			guard let r = currentRecording, let c = r.managedObjectContext else {return}
			
			let fetchRequest: NSFetchRequest<RecordingPoint> = RecordingPoint.fetchRequest()
			fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(RecordingPoint.recording), r)
			fetchRequest.sortDescriptors = [
				NSSortDescriptor(keyPath: \RecordingPoint.segmentID, ascending: true),
				NSSortDescriptor(keyPath: \RecordingPoint.date, ascending: true)
			]
			let ctrl = NSFetchedResultsController<RecordingPoint>(
				fetchRequest: fetchRequest, managedObjectContext: c,
				sectionNameKeyPath: #keyPath(RecordingPoint.segmentID),
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
		let getter = { [weak self] () -> PolylinesCache? in assert(Thread.isMainThread); return self?.polylinesCache }
		let setter = { [weak self] (c: PolylinesCache)   in assert(Thread.isMainThread); self?.polylinesCache = c; self?.processPendingPolylines() }
		return ProcessPointsOperation(fetchedResultsController: pointsFetchResultsController!, polylinesMaxPointCount: polylinesMaxPointCount, polylinesCacheGetter: getter, polylinesCacheSetter: setter)
	}
	
	private func processPendingPolylines() {
		assert(Thread.isMainThread)
		
//		print("-----")
//		print("current (on map): \(mapView.overlays.compactMap{ $0 as? MKPolyline }.map{ "\($0) (\($0.pointCount) points)" })")
//		print("n sections: \(polylinesCache.numberOfSections)")
//		print("npts/sctn:  \(polylinesCache.nPointsBySection.map{ String($0) }.joined(separator: ", "))")
//		print("remove:     \(polylinesCache.polylinesToRemoveFromMap.map{ "\($0) (\($0.pointCount) points)" })")
//		print("plain add:  \(polylinesCache.plainPolylinesToAddToMap.map{ "\($0) (\($0.pointCount) points)" })")
//		print("dotted add: \(polylinesCache.dottedPolylinesToAddToMap.map{ "\($0) (\($0.pointCount) points)" })")
		
		/* Let’s do a few basic checks on the polylines cache. */
		assert(polylinesCache.polylinesBySection.count == polylinesCache.numberOfSections)
		assert(polylinesCache.interSectionPolylines.count == max(0, polylinesCache.numberOfSections-1))
		assert(polylinesCache.polylinesBySection.allSatisfy{ $0.allSatisfy{ $0.pointCount <= polylinesMaxPointCount } })
		
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
	 * simple array of polylines.
	 * The count of this array should always be `numberOfSections`. */
	var polylinesBySection = [[MKPolyline]]()
	/* Between each sections we show a dotted line indicating missing information
	 * (the recording was paused). This variable contains these polylines. They
	 * are optional because some section might not have any points in them, in
	 * which case there are no dotted line to show, but we must still have an
	 * element in the array to have the correct count of objects in the array.
	 * The count of this array should always be `max(0, numberOfSections-1)`. */
	var interSectionPolylines = [MKPolyline?]()
	
	var polylinesToRemoveFromMap = Set<MKPolyline>()
	var plainPolylinesToAddToMap = Set<MKPolyline>()
	var dottedPolylinesToAddToMap = Set<MKPolyline>()
	
}

/* Note: We overwrite RetryingOperation instead of Operation mainly because I
 * have taken the habit of doing so, but in this case overwriting `main` in a
 * standard Operation would have been fine… */
fileprivate class ProcessPointsOperation : RetryingOperation {
	
	let polylinesMaxPointCount: Int
	
	let polylinesCacheGetter: () -> PolylinesCache?
	let polylinesCacheSetter: (PolylinesCache) -> Void
	let fetchedResultsController: NSFetchedResultsController<RecordingPoint>
	
	init(fetchedResultsController frc: NSFetchedResultsController<RecordingPoint>, polylinesMaxPointCount pmpc: Int, polylinesCacheGetter pcg: @escaping () -> PolylinesCache?, polylinesCacheSetter pcs: @escaping (PolylinesCache) -> Void) {
		assert(Thread.isMainThread)
		assert(pmpc > 1, "Invalid max point count per polylines (a polyline w/ 1 point does not make sense to draw a path!)")
		
		polylinesMaxPointCount = pmpc
		
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
			}
			
			/* Add the new points in the current section */
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
			
			/* Add an inter-section polyline if needed */
			if polylinesCache.interSectionPolylines.count == sectionIndex-1 {
				if
					let firstPolylineOfSection = polylinesCache.polylinesBySection[sectionIndex].first,
					let latestPolylineOfPreviousSection = polylinesCache.polylinesBySection[sectionIndex-1].last
				{
					assert(firstPolylineOfSection.pointCount > 0, "Got a polyline with no points in it for section \(sectionIndex) in cache \(polylinesCache)")
					assert(latestPolylineOfPreviousSection.pointCount > 0, "Got a polyline with no points in it for section \(sectionIndex-1) in cache \(polylinesCache)")
					let firstPointOfSection = firstPolylineOfSection.points().pointee
					let latestPointOfPreviousSection = latestPolylineOfPreviousSection.points().advanced(by: latestPolylineOfPreviousSection.pointCount-1).pointee
					let l = MKPolyline(coordinates: [latestPointOfPreviousSection.coordinate, firstPointOfSection.coordinate], count: 2)
					polylinesCache.interSectionPolylines.append(l)
					polylinesCache.dottedPolylinesToAddToMap.insert(l)
				} else {
					polylinesCache.interSectionPolylines.append(nil)
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
				if i < pc.numberOfSections {pointsToProcessBuilding.append(points[pc.nPointsBySection[i]...].map{ $0.location!.coordinate })}
				else                       {pointsToProcessBuilding.append(                           points.map{ $0.location!.coordinate })}
			}
			return (pc, pointsToProcessBuilding)
		}
	}
	
}

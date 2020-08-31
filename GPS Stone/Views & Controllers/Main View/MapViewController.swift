/*
 * MapViewController.swift
 * GPS Stone
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
	
	static let percentForMapBorders = CGFloat(15)
	static let dynamicPolylinesMaxPointCount = 100
	static let defaultMapSpan = CLLocationDistance(500)
	
	@IBOutlet var buttonCenterMapOnCurLoc: UIButton!
	@IBOutlet var mapView: MKMapView!
	
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
		
		/* Set later in view will appear and did disappear */
		mapView.showsUserLocation = false
		
		if let r = recording {
			buttonCenterMapOnCurLoc.isHidden = true
			currentRecording = recording
			
			/* Let’s compute the region to show for the recording */
			if let coordinates = (r.points as! Set<RecordingPoint>?)?.compactMap({ $0.location?.coordinate }), let startingPointCoord = coordinates.first {
				/* We have a recording which has at least one point. */
				var region = MKCoordinateRegion(center: startingPointCoord, latitudinalMeters: 1, longitudinalMeters: 1)
				for coordinate in coordinates.dropFirst() {
					let d1 = coordinate.latitude - (region.center.latitude - region.span.latitudeDelta/2)
					if d1 < 0 {
						region.center.latitude    -= -d1/2
						region.span.latitudeDelta += -d1
					}
					let d2 = coordinate.longitude - (region.center.longitude - region.span.longitudeDelta/2)
					if d2 < 0 {
						region.center.longitude    -= -d2/2
						region.span.longitudeDelta += -d2
					}
					let d3 = (region.center.latitude + region.span.latitudeDelta/2) - coordinate.latitude
					if d3 < 0 {
						region.center.latitude    += -d3/2
						region.span.latitudeDelta += -d3
					}
					let d4 = (region.center.longitude + region.span.longitudeDelta/2) - coordinate.longitude
					if d4 < 0 {
						region.center.longitude    += -d4/2
						region.span.longitudeDelta += -d4
					}
				}
				let borderInset = CGFloat(50)
				mapRegionSetByAppDate = Date()
				mapView.setRegion(region, animated: false)
				mapView.setVisibleMapRect(mapView.visibleMapRect, edgePadding: UIEdgeInsets(top: borderInset, left: borderInset, bottom: borderInset, right: borderInset), animated: false)
				mapRegionSetByAppDate = nil /* The delegate method should be called synchronously because we do not animate (tested on simulator on iOS 10.3.1). */
			}
		} else {
			if let region = appSettings.latestMapRegion {
				mapRegionSetByAppDate = Date()
				mapView.setRegion(region, animated: false)
				mapRegionSetByAppDate = nil /* The delegate method should be called synchronously because we do not animate (tested on simulator on iOS 10.3.1). */
			}
			restoredMapRegion = true
			
			_ = kvObserver.observe(object: locationRecorder, keyPath: #keyPath(LocationRecorder.objc_recStatus), kvoOptions: [.initial], dispatchType: .asyncOnMainQueueDirectInitial, handler: { [weak self] _ in
				guard let self = self else {return}
				self.currentRecording = self.locationRecorder.recStatus.recordingRef.flatMap{ self.recordingsManager.unsafeRecording(from: $0) }
			})
		}
		
		assert(settingsObserver == nil)
		settingsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main, using: { [weak self] _ in
			guard let self = self else {return}
			self.processUserDefaultsChange()
		})
		processUserDefaultsChange()
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		if recording == nil {
			mapView.showsUserLocation = true
			/* Note that we do not actually need location tracking on this view
			 * because we use the map user location view, however the map does not
			 * ask for user location permission. Retaining location tracking will
			 * do it if needed. */
			locationRecorder.retainLocationTracking()
		}
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		
		if recording == nil {
			mapView.showsUserLocation = false
			locationRecorder.releaseLocationTracking()
		}
	}
	
	@IBAction func followLocButtonTapped(_ sender: Any) {
		appSettings.followLocationOnMap = !appSettings.followLocationOnMap
	}
	
	/* *************************
	   MARK: - Map View Delegate
	   ************************* */
	
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
	
	func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
		if recording == nil && restoredMapRegion {
			appSettings.latestMapRegion = mapView.region
		}
		mapRegionSetByAppDate = nil
	}
	
	func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
		if !mapRegionBeingSetByApp {
			appSettings.followLocationOnMap = false
		}
	}
	
	func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
		/* Changing this property triggers the centring of the map if needed. */
		mapUserLocationCoords = userLocation.coordinate
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
	
	private lazy var polylinesMaxPointCount: Int = {
		if recording == nil {return Self.dynamicPolylinesMaxPointCount}
		else                {return Int.max}
	}()
	
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
	
	private var restoredMapRegion = false
	
	private var followingUserLocation = false
	private var mapUserLocationCoords: CLLocationCoordinate2D = kCLLocationCoordinate2DInvalid {
		didSet {centerMapIfNeeded(initialCenter: false)}
	}
	
	private var mapZoomSetDate: Date?
	private var mapRegionSetByAppDate: Date?
	private var mapRegionBeingSetByApp: Bool {
		if let date = mapRegionSetByAppDate {
			/* Sometimes the map view region did change delegate method might not
			 * be called after setting the map’s region (if, I think, the region we
			 * set is the same as the current region). We consider setting the
			 * region of the map will not take more 3 seconds, and thus, whatever
			 * happens, after 3 seconds we consider the map region is not set by
			 * the app anymore. */
			if date.timeIntervalSinceNow < -3.0 {
				NSLog("%@", "Got a map region set by app date older than 3 seconds. The region did change delegate method was probably skipped; considering the region is not being set anymore by the app.")
				return false
			}
			return true
		}
		return false
	}
	
	private var isCurMapLocOnBordersOfMap: Bool {
		guard CLLocationCoordinate2DIsValid(mapUserLocationCoords) else {return false}
		
		let p = mapView.convert(mapUserLocationCoords, toPointTo: mapView)
		if p.x < mapView.frame.width  * Self.percentForMapBorders/100 {return true}
		if p.y < mapView.frame.height * Self.percentForMapBorders/100 {return true}
		if p.x > mapView.frame.width  - mapView.frame.width  * Self.percentForMapBorders/100 {return true}
		if p.y > mapView.frame.height - mapView.frame.height * Self.percentForMapBorders/100 {return true}
		return false
	}
	
	private var currentRecording: Recording? {
		willSet {
			guard currentRecording != newValue else {return}
			
			pointsFetchResultsController?.delegate = nil
			pointsFetchResultsController = nil
			
			pointsProcessingQueue.cancelAllOperations()
			mapView.removeOverlays(mapView.overlays)
			polylinesCache = PolylinesCache()
		}
		didSet {
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
	
	private func centerMapIfNeeded(initialCenter: Bool) {
		guard followingUserLocation else {return}
		
		guard CLLocationCoordinate2DIsValid(mapUserLocationCoords) else {return}
		guard !locationRecorder.recStatus.isRecording || isCurMapLocOnBordersOfMap || initialCenter else {return}
		
		if !mapRegionBeingSetByApp {
			let expectedRegion = MKCoordinateRegion(center: mapUserLocationCoords, latitudinalMeters: Self.defaultMapSpan, longitudinalMeters: Self.defaultMapSpan)
			let zoom = shouldZoom(expectedRegion: expectedRegion)
			
			let ε = 10e-5
			func areCoordsEqual(_ c1: CLLocationCoordinate2D, _ c2: CLLocationCoordinate2D) -> Bool {
				return abs(c1.latitude - c2.latitude) < ε && abs(c1.longitude - c2.longitude) < ε
			}
			func areSpansEqual(_ s1: MKCoordinateSpan, _ s2: MKCoordinateSpan) -> Bool {
				return abs(s1.latitudeDelta - s2.latitudeDelta) < ε && abs(s1.longitudeDelta - s2.longitudeDelta) < ε
			}
			func areRegionsEqual(_ r1: MKCoordinateRegion, _ r2: MKCoordinateRegion) -> Bool {
				return areCoordsEqual(r1.center, r2.center) && areSpansEqual(r1.span, r2.span)
			}
			
			/* We do not move the map if the new region is too close to the old
			 * one. See comment in mapRegionBeingSetByApp accessor for more info. */
			if (zoom && !areRegionsEqual(mapView.region, expectedRegion)) || (!zoom && !areCoordsEqual(mapView.centerCoordinate, mapUserLocationCoords)) {
				mapRegionSetByAppDate = Date()
				/* We reset the zoom date if we will zoom, but also in the case of
				 * an initial region set. In the case of the initial region set, the
				 * user will probably see a big change in the map’s region, and thus
				 * unconsiously register the map’s zoom level at that time (source:
				 * none, idk if true). */
				if zoom || initialCenter {mapZoomSetDate = Date()}
				
				if zoom {mapView.setRegion(expectedRegion, animated: true)}
				else    {mapView.setCenter(mapUserLocationCoords, animated: true)}
			}
		}
	}
	
	/** We zoom only if the current zoom is too far out from the expected zoom,
	or if the latest time we zoomed was more than 1 minute ago. */
	private func shouldZoom(expectedRegion: MKCoordinateRegion) -> Bool {
		/* First we check the last zoom set date. If it’s more than 1 minute ago
		 * or is nil, we should zoom. */
		if let date = mapZoomSetDate, date.timeIntervalSinceNow < -(1*60) {
			return true
		} else if mapZoomSetDate == nil {
			return true
		}
		/* Next we check the current zoom level and compare it to the zoom level
		 * we want. If the diff is of a magnitude, we zoom. */
		let newSpan = expectedRegion.span
		let oldSpan = mapView.region.span
		if oldSpan.latitudeDelta > 0 && oldSpan.longitudeDelta > 0 {
			let spanRatio = max(newSpan.latitudeDelta / oldSpan.latitudeDelta, newSpan.longitudeDelta / oldSpan.longitudeDelta)
			if spanRatio < 0.1 || spanRatio > 10 {
				return true
			}
		}
		return false
	}
	
	private func processUserDefaultsChange() {
		assert(Thread.isMainThread)
		
		mapView.mapType = appSettings.mapType
		
		if recording == nil {
			if #available(iOS 13.0, *) {
				buttonCenterMapOnCurLoc.setImage(UIImage(systemName: appSettings.followLocationOnMap ? "location.fill" : "location"), for: .normal)
			} else {
				buttonCenterMapOnCurLoc.setImage(appSettings.followLocationOnMap ? #imageLiteral(resourceName: "sf_location·fill"): #imageLiteral(resourceName: "sf_location"), for: .normal)
			}
			
			if appSettings.followLocationOnMap && !followingUserLocation {
				followingUserLocation = true
				centerMapIfNeeded(initialCenter: true)
			} else if !appSettings.followLocationOnMap, followingUserLocation {
				followingUserLocation = false
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

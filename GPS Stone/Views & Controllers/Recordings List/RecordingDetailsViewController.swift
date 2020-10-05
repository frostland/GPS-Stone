/*
 * RecordingDetailsViewController.swift
 * GPS Stone
 *
 * Created by François Lamboley on 19/06/2019.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreLocation
import Foundation
import UIKit

import KVObserver
import XibLoc



class RecordingDetailsViewController : UIViewController {
	
	@IBOutlet var textFieldName: UITextField!
	@IBOutlet var labelInfo: UILabel!
	@IBOutlet var labelDate: UILabel!
	@IBOutlet var constraintTextFieldSpaceToBottom: NSLayoutConstraint!
	@IBOutlet var buttonExportGPX: UIButton!
	
	var recording: Recording! {
		didSet {
			nameObservingID.flatMap{ kvObserver.stopObserving(id: $0) }
			
			guard let r = recording else {return}
			nameObservingID = kvObserver.observe(object: r, keyPath: #keyPath(Recording.name), kvoOptions: .initial, dispatchType: .coreDataInferredSync, handler: { [weak self] _ in
				assert(Thread.isMainThread)
				self?.textFieldName?.text = r.name
			})
			/* We do not observe the distance, time and speed because they do not
			 * change for a finished recording. */
			updateInfoLines()
		}
	}
	
	deinit {
		keyboardFrameObserver.flatMap{ NotificationCenter.default.removeObserver($0, name: UIWindow.keyboardDidChangeFrameNotification, object: nil) }
		kvObserver.stopObservingEverything()
		nameObservingID = nil
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		/* The recording is on a view context, we can access it directly on the
		 * main thread. */
		textFieldName.text = recording.name
		
		infoLineFormat = labelInfo.text!
		updateInfoLines()
		
		updateExportGPXButton()
		
		keyboardFrameObserver = NotificationCenter.default.addObserver(forName: UIWindow.keyboardWillChangeFrameNotification, object: nil, queue: nil, using: { [weak self] n in
			guard let self = self else {return}
			guard let keyboardFrameInWindow = (n.userInfo?[UIWindow.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {return}
			let keyboardFrameInView = self.view.convert(keyboardFrameInWindow, from: nil)
			
			let overlap = self.view.bounds.maxY - keyboardFrameInView.minY + 8 /* Arbitrary margin */
			guard abs(self.constraintTextFieldSpaceToBottom.constant - overlap) > 0.5 else {return}
			
			UIView.animate(withDuration: self.constants.animTime, animations: {
				self.constraintTextFieldSpaceToBottom.constant = overlap
				self.view.layoutIfNeeded()
			})
		})
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		switch segue.identifier {
			case "MapEmbed"?:
				guard let mapViewController = segue.destination as? MapViewController else {return}
				mapViewController.recording = recording
				
			default: (/*nop*/)
		}
		
		super.prepare(for: segue, sender: sender)
	}
	
	@IBAction func finishedEditingRecordingName(_ sender: Any) {
		dataHandler.viewContext.performAndWait{
			recording.name = textFieldName.text
			_ = try? dataHandler.saveContextOrRollback()
		}
	}
	
	@IBAction func exportGPX(_ sender: Any) {
		guard gpxExportPreparationProgress == nil else {return}
		
		gpxExportPreparationProgress = recordingExporter.prepareExport(of: recording.objectID, handler: { [weak self] result in
			self?.gpxExportPreparationProgress = nil
			self?.updateExportGPXButton()
		})
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let constants = S.sp.constants
	private let appSettings = S.sp.appSettings
	private let dataHandler = S.sp.dataHandler
	private let recordingExporter = S.sp.recordingExporter
	
	private let kvObserver = KVObserver()
	private var nameObservingID: KVObserver.ObservingId?
	
	private var keyboardFrameObserver: NSObjectProtocol?
	
	private var infoLineFormat: String?
	
	private var gpxExportPreparationProgress: Progress?
	
	private func updateExportGPXButton() {
		assert(Thread.isMainThread)
		guard let buttonExportGPX = buttonExportGPX else {return}
		
		let buttonTitle: String
		let buttonEnabled: Bool
		if let progress = gpxExportPreparationProgress {
			/* The GPX is being prepared. */
			let formatter = NumberFormatter()
			formatter.numberStyle = .percent
			let progressPercentageString = formatter.xl_string(from: NSNumber(value: progress.fractionCompleted))
			
			buttonEnabled = false
			buttonTitle = NSLocalizedString("gpx export in progress button title", comment: "Title of the export GPX button while preparation is in progress.")
				.applyingCommonTokens(simpleReplacement1: progressPercentageString)
		} else if (try? recordingExporter.preparedExport(of: recording.objectID)) != nil {
			/* We’re ready to export the GPX. */
			buttonEnabled = true
			buttonTitle = NSLocalizedString("export gpx button title", comment: "Title of the export GPX button in the recordings list view.")
		} else {
			/* The GPX is neither ready nor being prepared. */
			buttonEnabled = true
			buttonTitle = NSLocalizedString("prepare gpx export button title", comment: "Title of the export GPX button in the recordings list view when the GPX file does not exist yet.")
		}
		
		buttonExportGPX.isEnabled = buttonEnabled
		buttonExportGPX.setTitle(buttonTitle, for: .normal)
	}
	
	private func updateInfoLines() {
		assert(Thread.isMainThread)
		guard let labelInfo = labelInfo else {return}
		
		labelInfo.text = infoLineFormat?.applyingGPSStoneTokens(
			simpleReplacement1: Utils.stringFrom(timeInterval: recording.activeRecordingDuration),
			simpleReplacement2: Utils.stringFrom(distance: CLLocationDistance(recording.totalDistance), useMetricSystem: appSettings.useMetricSystem),
			simpleReplacement3: Utils.stringFrom(speed: CLLocationSpeed(recording.averageSpeed), useMetricSystem: appSettings.useMetricSystem)
		)
		
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .medium
		dateFormatter.timeStyle = .short
		labelDate.text = recording.totalTimeSegment?.startDate.flatMap{ dateFormatter.string(from: $0) }
	}
	
}

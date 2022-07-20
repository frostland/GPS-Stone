/*
 * RecordingsListViewController.swift
 * GPS Stone
 *
 * Created by François Lamboley on 19/06/2019.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreData
import Foundation
import UIKit

import CollectionAndTableViewUpdateConveniences



class RecordingsListViewController : UITableViewController, NSFetchedResultsControllerDelegate {
	
	@IBOutlet var buttonDone: UIBarButtonItem!
	
	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		fatalError("Unexpected init method")
	}
	
	required init?(coder: NSCoder) {
		let fr: NSFetchRequest<Recording> = Recording.fetchRequest()
		fr.predicate = NSPredicate(format: "%K != NULL", #keyPath(Recording.totalTimeSegment.duration))
		fr.sortDescriptors = [NSSortDescriptor(keyPath: \Recording.totalTimeSegment?.startDate, ascending: false)]
		fetchedResultsController = NSFetchedResultsController<Recording>(fetchRequest: fr, managedObjectContext: dataHandler.viewContext, sectionNameKeyPath: nil, cacheName: nil)
		try! fetchedResultsController.performFetch()
		
		super.init(coder: coder)
		
		fetchedResultsController.delegate = self
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		navigationItem.rightBarButtonItem = editButtonItem
		
		tableView.fetchedResultsControllerMoveMode = .move(reloadMode: .standard)
		tableView.fetchedResultsControllerReloadMode = .handler{ [weak self] cell, object, tableViewIndexPath, dataSourceIndexPath in
			self?.setup(cell: cell, with: object as! Recording)
		}
		
		updateMigrationView()
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		tableView.reloadData()
		
		if let d = datePushedToSingleRecording {
			arasm.wentFromRecordingBackToList(after: -d.timeIntervalSinceNow)
			datePushedToSingleRecording = nil
		}
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		switch segue.identifier {
			case "ShowDetails"?:
				guard let detailsViewController = segue.destination as? RecordingDetailsViewController else {return}
				guard let indexPath = tableView.indexPathForSelectedRow ?? (sender as? UITableViewCell).flatMap({ tableView.indexPath(for: $0) }) else {return}
				
				detailsViewController.recording = fetchedResultsController.object(at: indexPath)
				
			default: (/*nop*/)
		}
		
		super.prepare(for: segue, sender: sender)
	}
	
	override func setEditing(_ editing: Bool, animated: Bool) {
		super.setEditing(editing, animated: animated)
		
		navigationItem.leftBarButtonItem = isEditing ? nil : buttonDone
	}
	
	/* *******************************************
	   MARK: - Table View Data Source and Delegate
	   ******************************************* */
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return fetchedResultsController.sections?.count ?? 0
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return fetchedResultsController.sections?[section].numberOfObjects ?? 0
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
		setup(cell: cell, with: fetchedResultsController.object(at: indexPath))
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		/* NO call to super (not implemented in superclass). */
		if datePushedToSingleRecording != nil {
			NSLog("datePushedToSingleRecording is not nil, but it should be")
		}
		datePushedToSingleRecording = Date()
	}
	
	/* ******************************************
	   MARK: - NSFetchedResultsControllerDelegate
	   ****************************************** */
	
	func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		guard tableView.superview != nil else {return}
		tableView.fetchedResultsControllerWillChangeContent()
	}
	
	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
		guard tableView.superview != nil else {return}
		tableView.fetchedResultsControllerDidChange(section: sectionInfo, atIndex: sectionIndex, forChangeType: type)
	}
	
	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
		guard tableView.superview != nil else {return}
		tableView.fetchedResultsControllerDidChange(object: anObject, atIndexPath: indexPath, forChangeType: type, newIndexPath: newIndexPath)
	}
	
	func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		guard tableView.superview != nil else {return}
		tableView.fetchedResultsControllerDidChangeContent()
	}
	
	override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
		return .delete
	}
	
	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		switch editingStyle {
			case .delete:
				/* We must perform and wait in order to be synchronous, in order to have a better animation! */
				dataHandler.viewContext.performAndWait{
					let recording = fetchedResultsController.object(at: indexPath)
					dataHandler.viewContext.delete(recording)
					_ = try? dataHandler.saveViewContextOrRollback()
				}
			
			default:
				super.tableView(tableView, commit: editingStyle, forRowAt: indexPath)
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let dataHandler = S.sp.dataHandler
	private let arasm = S.sp.appRateAndShareManager
	
	private let fetchedResultsController: NSFetchedResultsController<Recording>
	
	/* For app rate manager. */
	private var datePushedToSingleRecording: Date?
	
	private func setup(cell: UITableViewCell, with object: Recording) {
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .medium
		dateFormatter.timeStyle = .short
		
		cell.textLabel?.text = object.name
		cell.detailTextLabel?.text = object.startDate.flatMap{ dateFormatter.string(from: $0) }
	}
	
	private func updateMigrationView() {
		if S.sp.migrationToCoreData == nil {
			/* Migration is over. */
			tableView.tableFooterView = nil
		} else {
			/* Migration is in progress.
			 * No need to set the table footer view, it is set in the storyboard.
			 * We monitor however for migration end. */
			var observer: NSObjectProtocol?
			observer = NotificationCenter.default.addObserver(forName: .MigrationToCoreDataHasEnded, object: nil, queue: .main, using: { [weak self] _ in
				observer.flatMap{ NotificationCenter.default.removeObserver($0, name: .MigrationToCoreDataHasEnded, object: nil) }
				observer = nil
				
				self?.tableView.tableFooterView = nil
			})
		}
	}
	
}

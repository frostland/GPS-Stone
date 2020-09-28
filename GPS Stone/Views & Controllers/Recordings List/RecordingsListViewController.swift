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
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		tableView.reloadData()
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
				/* We must perform and wait in order to be synchronous, in order to
				 * have a better animation! */
				dataHandler.viewContext.performAndWait{
					let recording = fetchedResultsController.object(at: indexPath)
					dataHandler.viewContext.delete(recording)
					_ = try? dataHandler.saveContextOrRollback()
				}
			
			default:
				super.tableView(tableView, commit: editingStyle, forRowAt: indexPath)
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let dataHandler = S.sp.dataHandler
	
	private let fetchedResultsController: NSFetchedResultsController<Recording>
	
	private func setup(cell: UITableViewCell, with object: Recording) {
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .medium
		dateFormatter.timeStyle = .short
		
		cell.textLabel?.text = object.name
		cell.detailTextLabel?.text = object.totalTimeSegment?.startDate.flatMap{ dateFormatter.string(from: $0) }
	}
	
}

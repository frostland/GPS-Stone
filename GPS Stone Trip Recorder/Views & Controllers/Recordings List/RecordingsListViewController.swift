/*
 * RecordingsListViewController.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 19/06/2019.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import Foundation
import UIKit



class RecordingsListViewController : UITableViewController {
	
	@IBOutlet var buttonDone: UIBarButtonItem!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		navigationItem.rightBarButtonItem = editButtonItem
	}
	
	override func setEditing(_ editing: Bool, animated: Bool) {
		super.setEditing(editing, animated: animated)
		
		navigationItem.leftBarButtonItem = isEditing ? nil : buttonDone
	}
	
}

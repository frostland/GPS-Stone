/*
 * Recording+Utils.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/7/29.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import Foundation



extension Recording {
	
	var numberOfRecordedPoints: Int {
		return points?.count ?? 0
	}
	
}

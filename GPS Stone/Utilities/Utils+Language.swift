import CoreLocation
import Foundation

import XibLoc



private let oneFootInMeters = 0.3048
private let oneMileInKilometer = 1.609344


extension Utils {
	
	static func speedSymbol(usingMetricSystem: Bool) -> String {
		/* See stringFrom(speedValue:, useMiles:) for a rationale about not using formatter.string(from: useMetricSystem ? UnitSpeed.kilometersPerHour : .milesPerHour). */
		if usingMetricSystem {return NSLocalizedString("km/h", comment: "The kilometers per hour symbol in a speed (usually km/h). Will only be displayed next to the speed in the details view of the app. The system symbol (which we cannot easily retrieve) will be used anywhere else, so this value should be the same as the system symbol.")}
		else                 {return NSLocalizedString("mph",  comment: "The miles per hour symbol in a speed (mph in English). Will only be displayed next to the speed in the details view of the app. The system symbol (which we cannot easily retrieve) will be used anywhere else, so this value should be the same as the system symbol.")}
	}
	
	/* We could (should?) create a formatter for this, actually. */
	static func stringFrom(speedValue speed: CLLocationSpeed, useMetricSystem: Bool) -> String {
		let measurement = Measurement(value: speed, unit: UnitSpeed.metersPerSecond).converted(to: useMetricSystem ? .kilometersPerHour : .milesPerHour)
		let shownValue = measurement.value
		
		/* Using a MeasurementFormatter seems a good idea, but we cannot use it in our use case because we want to do something we shouldn’t:
		 *  we try and get the string representation of the value and the unit separately.
		 * This shouldn’t be done because we shouldn’t assume the measurement symbol will be on the right or left of the value.
		 * We have a UI where the km/h (or whatever unit symbol is used for the speed) has a different style than the speed value,
		 *  so we need this, but we shouldn’t, and Apple’s API won’t help.
		 * See more info in commented code below and at this link: <https://forums.developer.apple.com/thread/54360#165690>.
		 *
		 * Note: Apple probably could have given a way to retrieve the range(s) of the measurement symbol, but they didn’t.
		 * And we’re sad. */
//		let formatter = MeasurementFormatter()
//		formatter.unitStyle = .short
//		/* With a “en_US” locale, the line below returns “mi/hr”, though… */
//		let unit = formatter.string(from: UnitSpeed.milesPerHour)
//		/* … this (below the comment) returns “42mph”!
//		 * The unit symbol is not the same, though we use the same unitStyle :( */
//		let formattedSpeed = formatter.string(from: measurement)
		
		/* I could try and think to find the exact value, but I’ll say we will get the value wrong sufficently rarely so that “+ 0.01” is an acceptable hack
		 *  (case is 9.9 for instance; log is < 1, but when value is rounded, we’ll show 10 and should only show 1 fraction digit, not two). */
		let log = log10(shownValue + 0.1)
		let nFractionDigits = (log.isFinite && log.sign == .plus) ? max(0, 2 - Int(log)) : 0
		
		let numberFormatter = NumberFormatter()
		numberFormatter.numberStyle = .decimal
		numberFormatter.minimumFractionDigits = nFractionDigits
		numberFormatter.maximumFractionDigits = nFractionDigits
		return numberFormatter.xl_string(from: NSNumber(value: shownValue))
	}
	
	/* We could (should?) create a formatter for this, actually. */
	static func stringFrom(speed: CLLocationSpeed, useMetricSystem: Bool) -> String {
		let formatter = MeasurementFormatter()
		formatter.unitOptions = [.providedUnit]
		
		let measurement = Measurement(value: speed, unit: UnitSpeed.metersPerSecond)
		if useMetricSystem {return formatter.string(from: measurement.converted(to: .kilometersPerHour))}
		else               {return formatter.string(from: measurement.converted(to: .milesPerHour))}
	}
	
	/* We could (should?) create a formatter for this, actually. */
	static func stringFrom(latitudeDegrees degrees: CLLocationDegrees) -> String {
		let isPositive = (degrees.sign == .plus)
		
		let baseStr: String
		if isPositive {baseStr = NSLocalizedString("|degrees| /minutes/ -seconds- N", comment: "The format for a degrees minute seconds positive latitude.")}
		else          {baseStr = NSLocalizedString("|degrees| /minutes/ -seconds- S", comment: "The format for a degrees minute seconds negative latitude.")}
		return baseStr.applying(xibLocInfo: xibLocInfoForDegrees(degrees))
	}
	
	static func stringFrom(longitudeDegrees degrees: CLLocationDegrees) -> String {
		let isPositive = (degrees.sign == .plus)
		
		let baseStr: String
		if isPositive {baseStr = NSLocalizedString("|degrees| /minutes/ -seconds- E", comment: "The format for a degrees minute seconds positive longitude.")}
		else          {baseStr = NSLocalizedString("|degrees| /minutes/ -seconds- W", comment: "The format for a degrees minute seconds negative longitude.")}
		return baseStr.applying(xibLocInfo: xibLocInfoForDegrees(degrees))
	}
	
	static func xibLocInfoForDegrees(_ degrees: CLLocationDegrees) -> Str2StrXibLocInfo {
		let (degreesStr, minutesStr, secondsStr) = stringDegreesMinutesSecondsFrom(degrees: degrees)
		return Str2StrXibLocInfo(replacements: ["|": degreesStr, "/": minutesStr, "-": secondsStr])! /* We know the tokens are valid. */
	}
	
	static func stringDegreesMinutesSecondsFrom(degrees: CLLocationDegrees) -> (String, String, String) {
		let degrees = abs(degrees)
		
		let formatter = MeasurementFormatter()
		formatter.unitStyle = .short
		
		/* First we want numbers with no decimals. */
		formatter.numberFormatter.numberStyle = .none
		
		let degreesMeasurement = Measurement(value: degrees, unit: UnitAngle.degrees)
		let roundedDegreesMeasurement = Measurement(value: degrees.rounded(.towardZero), unit: UnitAngle.degrees)
		let degreesStr = formatter.string(from: roundedDegreesMeasurement)
		
		let minutesMeasurement = (degreesMeasurement - roundedDegreesMeasurement).converted(to: UnitAngle.arcMinutes)
		let roundedMinutesMeasurement = Measurement(value: minutesMeasurement.value.rounded(.towardZero), unit: UnitAngle.arcMinutes)
		let minutesStr = formatter.string(from: roundedMinutesMeasurement)
		
		/* Then we want 5 decimals. */
		formatter.numberFormatter.numberStyle = .decimal
		formatter.numberFormatter.minimumFractionDigits = 5
		formatter.numberFormatter.maximumFractionDigits = 5
		
		let secondsMeasurement = (minutesMeasurement - roundedMinutesMeasurement).converted(to: UnitAngle.arcSeconds)
		let secondsStr = formatter.string(from: secondsMeasurement)
		
		return (degreesStr, minutesStr, secondsStr)
	}
	
	static func stringFrom(distance: CLLocationDistance, useMetricSystem: Bool) -> String {
		let formatter = MeasurementFormatter()
		formatter.unitStyle = .medium
		formatter.unitOptions = [.providedUnit, .naturalScale]
		
		formatter.numberFormatter.numberStyle = .decimal
		formatter.numberFormatter.maximumFractionDigits = 2
		
		/* Note: This will not get us exactly the same results as the previous (pre-Swift, currently removed, was for pre-iOS 10) version.
		 * Previous version only supported meters/kilometers and miles/feet, and also did a “smart” thing for the number of fraction digits to show.
		 * Currently we only force to have a max of two fraction digits whatever the value. */
		let baseMeasurement = Measurement(value: distance, unit: UnitLength.meters)
		if useMetricSystem {return formatter.string(from: baseMeasurement)}
		else               {return formatter.string(from: baseMeasurement.converted(to: .miles))}
	}
	
	static func stringFrom(altitude: CLLocationDistance, useMetricSystem: Bool) -> String {
		let numberFormatter = NumberFormatter()
		numberFormatter.numberStyle = .none
		numberFormatter.positivePrefix = numberFormatter.plusSign
		
		let formatter = MeasurementFormatter()
		formatter.unitOptions = [.providedUnit]
		formatter.numberFormatter = numberFormatter
		
		let measurement = Measurement(value: altitude, unit: UnitLength.meters)
		if useMetricSystem {return formatter.string(from: measurement)}
		else               {return formatter.string(from: measurement.converted(to: .feet))}
	}
	
	static func stringFrom(timeInterval: TimeInterval) -> String {
		let formatter = DateComponentsFormatter()
		formatter.allowedUnits = [.hour, .minute, .second]
		formatter.zeroFormattingBehavior = .pad
		formatter.unitsStyle = .positional
		
		guard let formattedString = formatter.string(from: timeInterval) else {
			/* The date components formatter returns an optional…
			 * It shouldn’t return nil for our usage, but in case it does, we have a fallback!
			 * We don’t localize the fallback though. */
			let h = Int( timeInterval / 3600)
			let m = Int((timeInterval - Double(h*3600)) / 60)
			let s = Int( timeInterval - Double(h*3600) - Double(m*60))
			
			let numberFormatter = NumberFormatter()
			numberFormatter.numberStyle = .none
			
			return "|hh|:/mm/:-ss-".applying(xibLocInfo: Str2StrXibLocInfo(replacements: [
				"|": numberFormatter.xl_string(from: NSNumber(value: h)),
				"/": numberFormatter.xl_string(from: NSNumber(value: m)),
				"-": numberFormatter.xl_string(from: NSNumber(value: s))
			])!)
		}
		return formattedString
	}
	
}

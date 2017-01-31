//
//  NCUnitFormatter.swift
//  Neocom
//
//  Created by Artem Shimanski on 04.12.16.
//  Copyright © 2016 Artem Shimanski. All rights reserved.
//

import Foundation

class NCUnitFormatter: Formatter {
	enum Unit {
		case none
		case isk
		case skillPoints
		case gigaJoule
		case megaWatts
		case teraflops
		case kilogram
		case meter
		case custom(String, Bool)
		
		var useSIPrefix: Bool {
			switch self {
			case .isk, .skillPoints, .meter:
				return false
			case .gigaJoule, .megaWatts, .teraflops, .kilogram:
				return true
			case let .custom(_, bool):
				return bool
			default:
				return false
			}
		}
		
		var abbreviation: String {
			switch (self) {
			case .isk:
				return NSLocalizedString(" ISK", comment: "isk")
			case .skillPoints:
				return NSLocalizedString(" SP", comment: "skillPoints")
			case .gigaJoule:
				return NSLocalizedString(" GJ", comment: "gigaJoule")
			case .megaWatts:
				return NSLocalizedString(" MW", comment: "megaWatts")
			case .teraflops:
				return NSLocalizedString(" tf", comment: "teraflops")
			case .kilogram:
				return NSLocalizedString(" kg", comment: "kilogram")
			case .meter:
				return NSLocalizedString(" m", comment: "meter")
			case let .custom(string, _):
				return string

			default:
				return ""
			}
		}
	}
	
	enum Style: Int {
		case short
		case full
	}
	
	let unit: Unit
	let style: Style
	let useSIPrefix: Bool?
	
	private static let numberFormatter1: NumberFormatter = {
		let numberFormatter = NumberFormatter()
		numberFormatter.positiveFormat = "#,##0.##"
		numberFormatter.groupingSeparator = " "
		numberFormatter.decimalSeparator = "."
		return numberFormatter

	}()

	private static let numberFormatter2: NumberFormatter = {
		let numberFormatter = NumberFormatter()
		numberFormatter.positiveFormat = "#,##0"
		numberFormatter.groupingSeparator = " "
		numberFormatter.decimalSeparator = "."
		return numberFormatter
		
	}()
	
	init(unit: Unit = .none, style: Style = .full, useSIPrefix: Bool? = nil) {
		self.unit = unit
		self.style = style
		self.useSIPrefix = useSIPrefix
		super.init()
	}
	
	required init?(coder aDecoder: NSCoder) {
		//self.unit = Unit(rawValue: aDecoder.decodeInteger(forKey: "unit")) ?? .none
		self.unit = .none
		self.style = Style(rawValue: aDecoder.decodeInteger(forKey: "style")) ?? .full
		self.useSIPrefix = aDecoder.decodeObject(forKey: "useSIPrefix") as? Bool
		super.init(coder: aDecoder)
	}
	
	override func encode(with aCoder: NSCoder) {
		super.encode(with: aCoder)
		//aCoder.encode(unit.rawValue, forKey: "unit")
		aCoder.encode(style.rawValue, forKey: "style")
		aCoder.encode(useSIPrefix, forKey: "useSIPrefix")
	}
	
	class func localizedString(from number: Int32, unit: Unit, style: Style, useSIPrefix: Bool? = nil) -> String {
		return localizedString(from: Double(number), unit: unit, style: style)
	}


	class func localizedString(from number: Int, unit: Unit, style: Style, useSIPrefix: Bool? = nil) -> String {
		return localizedString(from: Double(number), unit: unit, style: style)
	}

	class func localizedString(from number: Float, unit: Unit, style: Style, useSIPrefix: Bool? = nil) -> String {
		return localizedString(from: Double(number), unit: unit, style: style)
	}

	class func localizedString(from number: Double, unit: Unit, style: Style, useSIPrefix: Bool? = nil) -> String {
		let unitAbbreviation: String = unit.abbreviation
		let useSIPrefix = useSIPrefix ?? unit.useSIPrefix
		
		var value = number
		let suffix: String
		if (style == .short) {
			if (value >= 10_000_000_000_000) {
				suffix = NSLocalizedString("T", comment: "trillion")
				value /= 1_000_000_000.0
			}
			else if (value >= 10_000_000_000) {
				if (useSIPrefix) {
					suffix = NSLocalizedString("G", comment: "billion")
				}
				else {
					suffix = NSLocalizedString("B", comment: "billion")
				}
				value /= 1_000_000_000.0
			}
			else if (value >= 10_000_000) {
				suffix = NSLocalizedString("M", comment:"million")
				value /= 1_000_000.0
			}
			else if (value >= 10_000) {
				suffix = NSLocalizedString("k", comment: "thousand")
				value /= 1000.0
			}
			else {
				suffix = ""
			}
		}
		else {
			suffix = ""
		}
		
		var s = ""
		if value < 10.0 {
			s = numberFormatter1.string(from: NSNumber(value: value))!
		}
		else {
			s = numberFormatter2.string(from: NSNumber(value: value))!
		}
		if !suffix.isEmpty {
			s += suffix
		}
		if !unitAbbreviation.isEmpty {
			s += "\(unitAbbreviation)"
		}
		return s;
	}

	/*class func localizedString(from number: (Double, Double?), unit: Unit, style: Style, useSIPrefix: Bool = false) -> String {
		let unitAbbreviation: String
		
		switch (unit) {
		case .isk:
			unitAbbreviation = NSLocalizedString("ISK", comment: "")
			break;
		case .skillPoints:
			unitAbbreviation = NSLocalizedString("SP", comment: "")
			break;
		default:
			unitAbbreviation = ""
			break;
		}
		
		var (v, m) = number
		
		let value = max(fabs(v), fabs(m ?? 0))
		let divider: Double
		let suffix: String
		if (style == .short) {
			if (value >= 10_000_000_000_000) {
				suffix = NSLocalizedString("T", comment: "trillion")
				divider = 1_000_000_000.0
			}
			else if (value >= 10_000_000_000) {
				if (useSIPrefix) {
					suffix = NSLocalizedString("G", comment: "billion")
				}
				else {
					suffix = NSLocalizedString("B", comment: "billion")
				}
				divider = 1_000_000_000.0
			}
			else if (value >= 10_000_000) {
				suffix = NSLocalizedString("M", comment:"million")
				divider = 1_000_000.0
			}
			else if (value >= 10_000) {
				suffix = NSLocalizedString("k", comment: "thousand")
				divider = 1000.0
			}
			else {
				suffix = ""
				divider = 1.0
			}
		}
		else {
			suffix = ""
			divider = 1.0
		}
		
		var s = ""
		v /= divider
		let formatter = v < 10.0 ? numberFormatter1 : numberFormatter2
		s = formatter.string(from: NSNumber(value: v))!
		m? /= divider
		if let m = m {
			s += "/\(formatter.string(from: NSNumber(value: m))!)"
		}
		
		if !suffix.isEmpty {
			s += suffix
		}
		if !unitAbbreviation.isEmpty {
			s += " \(unitAbbreviation)"
		}
		return s;
	}*/
	
	override func string(for obj: Any?) -> String? {
		switch obj {
		case let obj as Double:
			return NCUnitFormatter.localizedString(from: obj, unit: unit, style: style, useSIPrefix: true)
		case let obj as Float:
			return NCUnitFormatter.localizedString(from: obj, unit: unit, style: style, useSIPrefix: true)
		case let obj as Int:
			return NCUnitFormatter.localizedString(from: obj, unit: unit, style: style, useSIPrefix: true)
		case let obj as Int32:
			return NCUnitFormatter.localizedString(from: obj, unit: unit, style: style, useSIPrefix: true)
		default:
			return nil
		}
	}

}

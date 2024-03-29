/*
 * GPSStoneLocTokens.swift
 * GPS Stone
 *
 * Created by François Lamboley on 2020/5/17.
 * Copyright © 2020 Frost Land. All rights reserved.
 */

import Foundation

import XibLoc



public struct GPSStoneLocTokens : TokensGroup {
	
	public static let escapeToken = "~"
	public static let tokensExceptEscape = Set(arrayLiteral: "|", "#", "$")
	
	public var simpleReplacement1: String?
	public var simpleReplacement2: String?
	public var simpleReplacement3: String?
	
	public init(
		simpleReplacement1 r1: String? = nil,
		simpleReplacement2 r2: String? = nil,
		simpleReplacement3 r3: String? = nil
	) {
		simpleReplacement1 = r1
		simpleReplacement2 = r2
		simpleReplacement3 = r3
	}
	
	public var str2StrXibLocInfo: Str2StrXibLocInfo {
		return Str2StrXibLocInfo(
			defaultPluralityDefinition: XibLocConfig.defaultPluralityDefinition,
			escapeToken: Self.escapeToken,
			simpleSourceTypeReplacements: [:],
			orderedReplacements: [:],
			pluralGroups: [],
			attributesModifications: [:],
			simpleReturnTypeReplacements: [
				OneWordTokens(token: "|"): simpleReplacement1.flatMap{ r in { _ in r } },
				OneWordTokens(token: "#"): simpleReplacement2.flatMap{ r in { _ in r } },
				OneWordTokens(token: "$"): simpleReplacement3.flatMap{ r in { _ in r } }
			].compactMapValues{ $0 },
			identityReplacement: { $0 }
		)! /* We force unwrap because we _know_ these tokens are valid. */
	}
	
	public var str2AttrStrXibLocInfo: Str2AttrStrXibLocInfo {
		return Str2AttrStrXibLocInfo(strResolvingInfo: str2StrXibLocInfo)
	}
	
}

extension String {
	
	public func applyingGPSStoneTokens(
		simpleReplacement1: String? = nil,
		simpleReplacement2: String? = nil,
		simpleReplacement3: String? = nil
	) -> String {
		return applying(xibLocInfo: GPSStoneLocTokens(
			simpleReplacement1: simpleReplacement1,
			simpleReplacement2: simpleReplacement2,
			simpleReplacement3: simpleReplacement3
		).str2StrXibLocInfo)
	}
	
}

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
	public static let tokensExceptEscape = Set(arrayLiteral: "|")
	
	public var simpleReplacement1: String?
	
	public init(
		simpleReplacement1 r1: String? = nil
	) {
		simpleReplacement1 = r1
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
				OneWordTokens(token: "|"): simpleReplacement1.flatMap{ r in { _ in r } }
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
		simpleReplacement1: String? = nil
	) -> String {
		return applying(xibLocInfo: GPSStoneLocTokens(
			simpleReplacement1: simpleReplacement1
		).str2StrXibLocInfo)
	}
	
}

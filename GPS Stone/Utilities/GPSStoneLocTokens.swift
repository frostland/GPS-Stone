import Foundation

import GlobalConfModule
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
			defaultPluralityDefinition: Conf[\.xibLoc.defaultPluralityDefinition],
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
	
	@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
	public var str2AttrStrXibLocInfo: Str2AttrStrXibLocInfo {
		return Str2AttrStrXibLocInfo(strResolvingInfo: str2StrXibLocInfo)
	}
	
	public var str2NSAttrStrXibLocInfo: Str2NSAttrStrXibLocInfo {
		return Str2NSAttrStrXibLocInfo(strResolvingInfo: str2StrXibLocInfo)
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

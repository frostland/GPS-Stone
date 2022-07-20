#!/usr/bin/swift sh

import Foundation

import SwiftShell // @kareman ~> 5.1.0


/* swift-sh creates a binary whose path is not one we expect, so we cannot use main.path directly.
 * Using the _ env variable is **extremely** hacky, but seems to do the job…
 * See https://github.com/mxcl/swift-sh/issues/101 */
let filepath = ProcessInfo.processInfo.environment["_"] ?? main.path
main.currentdirectory = URL(fileURLWithPath: filepath).deletingLastPathComponent().appendingPathComponent("..").path



do {
	guard main.arguments.count == 0 else {
		exit(errormessage: "usage: \(filepath)")
	}
	
	try runAndPrint(
		"locmapper", "update_xcode_strings_from_code",
		"--colored-output",
		"--encoding=utf8", "--delete-missing-keys",
		"--unlocalized-xibs-files-list=.locmapper/unlocalized_xibs",
		"--unused-stringsfiles-files-list=.locmapper/unused_stringfiles",
		"--localizables-path=GPS Stone/Supporting Files/Localizables",
		"--exclude-list=.git/,gfx building/,App Store/,Scripts/",
		"."
	)
} catch {
	exit(error)
}

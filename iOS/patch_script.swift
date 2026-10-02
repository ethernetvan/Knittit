import Foundation

let path = "Knittit/Views/SocialFeedView.swift"
var file = try String(contentsOfFile: path)

let target = """
                            if #available(iOS 17.0, *), let urlStr = item.usdzFilePath, let url = URL(string: urlStr) {
"""

let newText = """
                            if #available(iOS 17.0, *), let url = item.usdzFilePath {
"""

file = file.replacingOccurrences(of: target, with: newText)
try file.write(toFile: path, atomically: true, encoding: .utf8)

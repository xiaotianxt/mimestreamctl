import AppKit
import ApplicationServices
import Foundation

private let bundleID = "com.mimestream.Mimestream"

private func fail(_ message: String, code: Int32 = 1) -> Never {
    fputs(message + "\n", stderr)
    exit(code)
}

private func copyAttribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
    guard error == .success else {
        return nil
    }
    return value
}

private func copyParameterizedNames(_ element: AXUIElement) -> [String] {
    var value: CFArray?
    let error = AXUIElementCopyParameterizedAttributeNames(element, &value)
    guard error == .success, let value else {
        return []
    }
    return (value as [AnyObject]).compactMap { $0 as? String }
}

private func copyParameterizedValue(_ element: AXUIElement, _ name: String, parameter: AnyObject) -> AnyObject? {
    var value: CFTypeRef?
    let error = AXUIElementCopyParameterizedAttributeValue(element, name as CFString, parameter, &value)
    guard error == .success else {
        return nil
    }
    return value
}

private func copyElementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
    copyAttribute(element, name) as! AXUIElement?
}

private func copyElementArrayAttribute(_ element: AXUIElement, _ name: String) -> [AXUIElement] {
    copyAttribute(element, name) as? [AXUIElement] ?? []
}

private func role(of element: AXUIElement) -> String? {
    copyAttribute(element, kAXRoleAttribute as String) as? String
}

private func children(of element: AXUIElement) -> [AXUIElement] {
    copyElementArrayAttribute(element, kAXChildrenAttribute as String)
}

private func firstChild(of element: AXUIElement, role wanted: String) -> AXUIElement? {
    for child in children(of: element) {
        if role(of: child) == wanted {
            return child
        }
    }
    return nil
}

private func lastChild(of element: AXUIElement, role wanted: String) -> AXUIElement? {
    for child in children(of: element).reversed() {
        if role(of: child) == wanted {
            return child
        }
    }
    return nil
}

private func findFirst(_ root: AXUIElement, role wanted: String, depth: Int = 0) -> AXUIElement? {
    if role(of: root) == wanted {
        return root
    }
    guard depth < 8 else {
        return nil
    }
    for child in children(of: root) {
        if let found = findFirst(child, role: wanted, depth: depth + 1) {
            return found
        }
    }
    return nil
}

private func collectStaticTexts(from root: AXUIElement, depth: Int = 0) -> [String] {
    guard depth < 24 else {
        return []
    }
    var results: [String] = []
    if role(of: root) == "AXStaticText",
       let value = copyAttribute(root, kAXValueAttribute as String) as? String ?? copyAttribute(root, kAXTitleAttribute as String) as? String {
        let normalized = value
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty {
            results.append(normalized)
        }
    }
    for child in children(of: root) {
        results.append(contentsOf: collectStaticTexts(from: child, depth: depth + 1))
    }
    return results
}

private func dedupeConsecutive(_ values: [String]) -> [String] {
    var output: [String] = []
    for value in values {
        if output.last != value {
            output.append(value)
        }
    }
    return output
}

guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
    fail("Mimestream is not running.")
}

let axApp = AXUIElementCreateApplication(app.processIdentifier)
let focusedWindow =
    copyElementAttribute(axApp, kAXFocusedWindowAttribute as String)
    ?? copyElementArrayAttribute(axApp, kAXWindowsAttribute as String).first
guard let focusedWindow else {
    fail("Could not find the focused Mimestream window.")
}

let directWebArea =
    firstChild(of: focusedWindow, role: "AXSplitGroup")
    .flatMap { lastChild(of: $0, role: "AXGroup") }
    .flatMap { firstChild(of: $0, role: "AXGroup") }
    .flatMap { firstChild(of: $0, role: "AXScrollArea") }
    .flatMap { firstChild(of: $0, role: "AXWebArea") }

guard let webArea = directWebArea ?? findFirst(focusedWindow, role: "AXWebArea") else {
    fail("Could not find a message web area in the current window.")
}

let bodyCarrier =
    children(of: webArea).first { findFirst($0, role: "AXScrollArea") != nil }
    ?? webArea

let bodyRoot =
    findFirst(bodyCarrier, role: "AXScrollArea")
    .flatMap { children(of: $0).first }
    ?? bodyCarrier

let staticTexts = dedupeConsecutive(collectStaticTexts(from: bodyRoot))
if !staticTexts.isEmpty {
    print(staticTexts.joined(separator: "\n"))
    exit(0)
}

let parameterizedNames = Set(copyParameterizedNames(webArea))
guard
    let start = copyAttribute(webArea, "AXStartTextMarker"),
    let end = copyAttribute(webArea, "AXEndTextMarker")
else {
    fail("Could not read the message text markers.")
}

let markers: [AnyObject] = [start, end]
let rangeValue =
    copyParameterizedValue(webArea, "AXTextMarkerRangeForUnorderedTextMarkers", parameter: markers as AnyObject)
    ?? copyParameterizedValue(webArea, "AXTextMarkerRangeForTextMarkers", parameter: markers as AnyObject)

guard let rangeValue else {
    fail("Could not construct a text range for the current message.")
}

if parameterizedNames.contains("AXStringForTextMarkerRange"),
   let stringValue = copyParameterizedValue(webArea, "AXStringForTextMarkerRange", parameter: rangeValue) as? String,
   !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
    print(stringValue)
    exit(0)
}

if parameterizedNames.contains("AXAttributedStringForTextMarkerRange"),
   let attrValue = copyParameterizedValue(webArea, "AXAttributedStringForTextMarkerRange", parameter: rangeValue) as? NSAttributedString {
    let text = attrValue.string.trimmingCharacters(in: .whitespacesAndNewlines)
    if !text.isEmpty {
        print(text)
        exit(0)
    }
}

fail("Could not extract text from the current message body.")

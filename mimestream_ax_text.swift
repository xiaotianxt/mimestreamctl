import AppKit
import ApplicationServices
import Foundation

private let bundleID = "com.mimestream.Mimestream"

struct Options {
    var emitJSON = false
    var includeFullMetadata = false
    var includeBody = true
}

struct BodyLink: Codable {
    var text: String
    var url: String
}

struct ReadPayload: Codable {
    var window: String?
    var body: String?
    var sender: String?
    var date: String?
    var subject: String?
    var preview: String?
    var bodyLinks: [BodyLink]?

    enum CodingKeys: String, CodingKey {
        case window
        case body
        case sender
        case date
        case subject
        case preview
        case bodyLinks = "body_links"
    }
}

private func fail(_ message: String, code: Int32 = 1) -> Never {
    fputs(message + "\n", stderr)
    exit(code)
}

private func parseOptions() -> Options {
    var options = Options()
    for argument in CommandLine.arguments.dropFirst() {
        switch argument {
        case "--json":
            options.emitJSON = true
        case "--full":
            options.includeFullMetadata = true
        case "--no-body":
            options.includeBody = false
        default:
            fail("Unknown argument: \(argument)")
        }
    }
    return options
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

private func parent(of element: AXUIElement) -> AXUIElement? {
    copyElementAttribute(element, kAXParentAttribute as String)
}

private func role(of element: AXUIElement) -> String? {
    copyAttribute(element, kAXRoleAttribute as String) as? String
}

private func boolAttribute(_ element: AXUIElement, _ name: String) -> Bool? {
    copyAttribute(element, name) as? Bool
}

private func stringAttribute(_ element: AXUIElement, _ name: String) -> String? {
    copyAttribute(element, name) as? String
}

private func urlStringAttribute(_ element: AXUIElement, _ name: String) -> String? {
    if let url = copyAttribute(element, name) as? URL {
        return url.absoluteString
    }
    if let url = copyAttribute(element, name) as? NSURL {
        return url.absoluteString
    }
    if let value = stringAttribute(element, name) {
        let normalized = normalizedString(value)
        if !normalized.isEmpty {
            return normalized
        }
    }
    return nil
}

private func normalizedString(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\u{00A0}", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func readableString(of element: AXUIElement) -> String? {
    let candidates = [
        kAXTitleAttribute as String,
        kAXValueAttribute as String,
        kAXDescriptionAttribute as String,
        kAXHelpAttribute as String,
    ]
    for name in candidates {
        if let value = stringAttribute(element, name) {
            let normalized = normalizedString(value)
            if !normalized.isEmpty {
                return normalized
            }
        }
    }
    return nil
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

private func findFirst(_ root: AXUIElement, role wanted: String, depth: Int = 0, maxDepth: Int = 10) -> AXUIElement? {
    if role(of: root) == wanted {
        return root
    }
    guard depth < maxDepth else {
        return nil
    }
    for child in children(of: root) {
        if let found = findFirst(child, role: wanted, depth: depth + 1, maxDepth: maxDepth) {
            return found
        }
    }
    return nil
}

private func collectReadableStrings(
    from root: AXUIElement,
    depth: Int = 0,
    maxDepth: Int = 32,
    includeRoot: Bool = true
) -> [String] {
    guard depth <= maxDepth else {
        return []
    }
    var results: [String] = []
    if includeRoot,
       let elementRole = role(of: root),
       ["AXStaticText", "AXLink", "AXButton", "AXHeading"].contains(elementRole),
       let value = readableString(of: root) {
        results.append(value)
    }
    for child in children(of: root) {
        results.append(contentsOf: collectReadableStrings(from: child, depth: depth + 1, maxDepth: maxDepth))
    }
    return results
}

private func collectRowParts(from root: AXUIElement, depth: Int = 0, maxDepth: Int = 2) -> [String] {
    guard depth <= maxDepth else {
        return []
    }
    var results: [String] = []
    for child in children(of: root) {
        if let value = readableString(of: child) {
            results.append(value)
        }
        results.append(contentsOf: collectRowParts(from: child, depth: depth + 1, maxDepth: maxDepth))
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

private func dedupeBodyLinks(_ links: [BodyLink]) -> [BodyLink] {
    var output: [BodyLink] = []
    var seen: Set<String> = []
    for link in links {
        let key = "\(link.text)\u{0000}\(link.url)"
        if seen.contains(key) {
            continue
        }
        seen.insert(key)
        output.append(link)
    }
    return output
}

private func linkText(for element: AXUIElement) -> String? {
    if let value = readableString(of: element) {
        return value
    }
    let descendantTexts = dedupeConsecutive(
        collectReadableStrings(from: element, maxDepth: 12, includeRoot: false)
    )
    let normalized = descendantTexts.joined(separator: " ")
    if normalized.isEmpty {
        return nil
    }
    return normalized
}

private func collectBodyLinks(from root: AXUIElement, depth: Int = 0, maxDepth: Int = 32) -> [BodyLink] {
    guard depth <= maxDepth else {
        return []
    }
    var results: [BodyLink] = []
    if role(of: root) == "AXLink" {
        let text = linkText(for: root)
        let url =
            urlStringAttribute(root, "AXURL")
            ?? urlStringAttribute(root, kAXURLAttribute as String)
        if let text, let url, !text.isEmpty, !url.isEmpty {
            results.append(BodyLink(text: text, url: url))
        }
    }
    for child in children(of: root) {
        results.append(contentsOf: collectBodyLinks(from: child, depth: depth + 1, maxDepth: maxDepth))
    }
    return results
}

private func stringForTextRange(from element: AXUIElement) -> String? {
    let parameterizedNames = Set(copyParameterizedNames(element))
    guard
        let start = copyAttribute(element, "AXStartTextMarker"),
        let end = copyAttribute(element, "AXEndTextMarker")
    else {
        return nil
    }

    let markers: [AnyObject] = [start, end]
    let rangeValue =
        copyParameterizedValue(element, "AXTextMarkerRangeForUnorderedTextMarkers", parameter: markers as AnyObject)
        ?? copyParameterizedValue(element, "AXTextMarkerRangeForTextMarkers", parameter: markers as AnyObject)
    guard let rangeValue else {
        return nil
    }

    if parameterizedNames.contains("AXStringForTextMarkerRange"),
       let stringValue = copyParameterizedValue(element, "AXStringForTextMarkerRange", parameter: rangeValue) as? String {
        let normalized = normalizedString(stringValue)
        if !normalized.isEmpty {
            return normalized
        }
    }

    if parameterizedNames.contains("AXAttributedStringForTextMarkerRange"),
       let attrValue = copyParameterizedValue(element, "AXAttributedStringForTextMarkerRange", parameter: rangeValue) as? NSAttributedString {
        let normalized = normalizedString(attrValue.string)
        if !normalized.isEmpty {
            return normalized
        }
    }

    return nil
}

private func findFocusedWindow(for app: AXUIElement) -> AXUIElement? {
    if let focusedWindow = copyElementAttribute(app, kAXFocusedWindowAttribute as String) {
        return focusedWindow
    }
    if let mainWindow = copyElementAttribute(app, kAXMainWindowAttribute as String) {
        return mainWindow
    }
    if let focusedElement = copyElementAttribute(app, kAXFocusedUIElementAttribute as String) {
        var current: AXUIElement? = focusedElement
        for _ in 0..<24 {
            guard let element = current else {
                break
            }
            if role(of: element) == kAXWindowRole as String {
                return element
            }
            current = parent(of: element)
        }
    }
    return copyElementArrayAttribute(app, kAXWindowsAttribute as String).first
}

private func findMessageWebArea(in focusedWindow: AXUIElement) -> AXUIElement? {
    let directWebArea =
        firstChild(of: focusedWindow, role: "AXSplitGroup")
        .flatMap { lastChild(of: $0, role: "AXGroup") }
        .flatMap { firstChild(of: $0, role: "AXGroup") }
        .flatMap { firstChild(of: $0, role: "AXScrollArea") }
        .flatMap { firstChild(of: $0, role: "AXWebArea") }

    return directWebArea ?? findFirst(focusedWindow, role: "AXWebArea", maxDepth: 12)
}

private func extractBody(from focusedWindow: AXUIElement) -> String? {
    guard let webArea = findMessageWebArea(in: focusedWindow) else {
        return nil
    }

    let bodyCarrier =
        children(of: webArea).first { findFirst($0, role: "AXScrollArea", maxDepth: 6) != nil }
        ?? webArea

    let bodyRoot =
        findFirst(bodyCarrier, role: "AXScrollArea", maxDepth: 6)
        .flatMap { children(of: $0).first }
        ?? bodyCarrier

    let textRoots = [bodyRoot, bodyCarrier, webArea]
    for root in textRoots {
        let texts = dedupeConsecutive(collectReadableStrings(from: root))
        if !texts.isEmpty {
            return texts.joined(separator: "\n")
        }
    }

    let markerRoots = [bodyRoot, bodyCarrier, webArea]
    for root in markerRoots {
        if let text = stringForTextRange(from: root) {
            return text
        }
    }

    return nil
}

private func extractBodyLinks(from focusedWindow: AXUIElement) -> [BodyLink] {
    guard let webArea = findMessageWebArea(in: focusedWindow) else {
        return []
    }

    let bodyCarrier =
        children(of: webArea).first { findFirst($0, role: "AXScrollArea", maxDepth: 6) != nil }
        ?? webArea

    let bodyRoot =
        findFirst(bodyCarrier, role: "AXScrollArea", maxDepth: 6)
        .flatMap { children(of: $0).first }
        ?? bodyCarrier

    let roots = [bodyRoot, bodyCarrier, webArea]
    var links: [BodyLink] = []
    for root in roots {
        links.append(contentsOf: collectBodyLinks(from: root))
        if !links.isEmpty {
            break
        }
    }
    return dedupeBodyLinks(links)
}

private func findMessageTable(in focusedWindow: AXUIElement) -> AXUIElement? {
    let splitGroup = firstChild(of: focusedWindow, role: "AXSplitGroup") ?? findFirst(focusedWindow, role: "AXSplitGroup", maxDepth: 6)
    guard let splitGroup else {
        return nil
    }

    for child in children(of: splitGroup) {
        guard role(of: child) == "AXScrollArea" else {
            continue
        }
        if let table = firstChild(of: child, role: "AXTable") ?? findFirst(child, role: "AXTable", maxDepth: 4) {
            return table
        }
    }

    return findFirst(splitGroup, role: "AXTable", maxDepth: 8)
}

private func selectedRow(in table: AXUIElement) -> AXUIElement? {
    let rows = copyElementArrayAttribute(table, kAXRowsAttribute as String)
    if let selected = rows.first(where: { boolAttribute($0, kAXSelectedAttribute as String) == true }) {
        return selected
    }

    return children(of: table).first {
        role(of: $0) == "AXRow" && boolAttribute($0, kAXSelectedAttribute as String) == true
    }
}

private func selectedRowMetadata(in focusedWindow: AXUIElement) -> (sender: String?, date: String?, subject: String?, preview: String?) {
    guard
        let table = findMessageTable(in: focusedWindow),
        let row = selectedRow(in: table)
    else {
        return (nil, nil, nil, nil)
    }

    let cell = firstChild(of: row, role: "AXCell") ?? children(of: row).first ?? row
    let parts = dedupeConsecutive(collectRowParts(from: cell))

    func value(at index: Int) -> String? {
        guard index < parts.count else {
            return nil
        }
        return parts[index]
    }

    return (
        sender: value(at: 0),
        date: value(at: 1),
        subject: value(at: 2),
        preview: value(at: 4)
    )
}

let options = parseOptions()

guard let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
    fail("Mimestream is not running.")
}

let axApp = AXUIElementCreateApplication(runningApp.processIdentifier)
guard let focusedWindow = findFocusedWindow(for: axApp) else {
    fail("Could not find the focused Mimestream window.")
}

let windowTitle = readableString(of: focusedWindow)
let body: String? = options.includeBody ? extractBody(from: focusedWindow) : nil
if options.includeBody && body == nil {
    fail("Could not extract text from the current message body.")
}

let metadata: (sender: String?, date: String?, subject: String?, preview: String?) =
    options.includeFullMetadata ? selectedRowMetadata(in: focusedWindow) : (nil, nil, nil, nil)
let bodyLinks = extractBodyLinks(from: focusedWindow)
let payload = ReadPayload(
    window: windowTitle,
    body: body,
    sender: metadata.sender,
    date: metadata.date,
    subject: metadata.subject,
    preview: metadata.preview,
    bodyLinks: bodyLinks.isEmpty ? nil : bodyLinks
)

if options.emitJSON {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(payload), let json = String(data: data, encoding: .utf8) else {
        fail("Could not encode the AX payload.")
    }
    print(json)
    exit(0)
}

if let body {
    print(body)
    exit(0)
}

fail("No output was produced.")

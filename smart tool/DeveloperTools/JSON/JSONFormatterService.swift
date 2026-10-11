//
//  JSONFormatterService.swift
//  Borno Pulse
//

import AppKit
import Foundation

public final class JSONFormatterService: Sendable {
    public static let shared = JSONFormatterService()
    
    private init() {}
    
    // MARK: - Format & Pretty Print
    public func prettyPrint(_ jsonString: String, spaces: Int = 2) throws -> String {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "JSONError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 encoding"])
        }
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        let options: JSONSerialization.WritingOptions = spaces == 2 ? [.prettyPrinted, .sortedKeys] : [.prettyPrinted, .sortedKeys]
        let prettyData = try JSONSerialization.data(withJSONObject: object, options: options)
        guard var formatted = String(data: prettyData, encoding: .utf8) else {
            throw NSError(domain: "JSONError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode formatted JSON"])
        }
        if spaces == 4 {
            formatted = formatted.replacingOccurrences(of: "\n  ", with: "\n    ")
        }
        return formatted
    }
    
    // MARK: - Minify
    public func minify(_ jsonString: String) throws -> String {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "JSONError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 encoding"])
        }
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        let compactData = try JSONSerialization.data(withJSONObject: object, options: [])
        guard let minified = String(data: compactData, encoding: .utf8) else {
            throw NSError(domain: "JSONError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode minified JSON"])
        }
        return minified
    }
    
    // MARK: - Validate
    public func validate(_ jsonString: String) -> JSONValidationResult {
        guard let data = jsonString.data(using: .utf8) else {
            return JSONValidationResult(isValid: false, errorMessage: "Invalid text encoding", line: 1, column: 1)
        }
        
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return JSONValidationResult(isValid: true)
        } catch let err as NSError {
            // Extract byte offset from error description if present (e.g. "around character 45" or in debugDescription)
            var line = 1
            var col = 1
            var offset: Int? = nil
            
            let desc = err.userInfo[NSDebugDescriptionErrorKey] as? String ?? err.localizedDescription
            if let regex = try? NSRegularExpression(pattern: "(character|offset) (\\d+)", options: .caseInsensitive),
               let match = regex.firstMatch(in: desc, range: NSRange(desc.startIndex..., in: desc)),
               let range = Range(match.range(at: 2), in: desc),
               let parsedOffset = Int(desc[range]) {
                offset = parsedOffset
                
                // Compute line & column from offset
                let prefix = jsonString.prefix(parsedOffset)
                let lines = prefix.split(separator: "\n", omittingEmptySubsequences: false)
                line = lines.count
                col = (lines.last?.count ?? 0) + 1
            }
            
            return JSONValidationResult(
                isValid: false,
                errorMessage: err.localizedDescription,
                line: line,
                column: col,
                byteOffset: offset
            )
        }
    }
    
    // MARK: - Tree Explorer
    public func buildTree(from jsonString: String) throws -> [JSONTreeNode] {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "JSONError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid text"])
        }
        let root = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return convertToNodes(key: "root", value: root)
    }
    
    private func convertToNodes(key: String, value: Any, parentPath: String = "") -> [JSONTreeNode] {
        let currentPath = parentPath.isEmpty ? key : "\(parentPath).\(key)"
        
        if let dict = value as? [String: Any] {
            let sortedKeys = dict.keys.sorted()
            let children = sortedKeys.flatMap { k in
                convertToNodes(key: k, value: dict[k]!, parentPath: currentPath)
            }
            return [
                JSONTreeNode(
                    id: currentPath,
                    key: key,
                    displayValue: "{ \(dict.count) items }",
                    type: .object,
                    childrenCount: dict.count,
                    children: children
                )
            ]
        } else if let arr = value as? [Any] {
            var children: [JSONTreeNode] = []
            for (idx, elem) in arr.enumerated() {
                children.append(contentsOf: convertToNodes(key: "[\(idx)]", value: elem, parentPath: currentPath))
            }
            return [
                JSONTreeNode(
                    id: currentPath,
                    key: key,
                    displayValue: "[ \(arr.count) items ]",
                    type: .array,
                    childrenCount: arr.count,
                    children: children
                )
            ]
        } else if let str = value as? String {
            return [JSONTreeNode(id: currentPath, key: key, displayValue: "\"\(str)\"", type: .string)]
        } else if let num = value as? NSNumber {
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                return [JSONTreeNode(id: currentPath, key: key, displayValue: num.boolValue ? "true" : "false", type: .boolean)]
            } else {
                return [JSONTreeNode(id: currentPath, key: key, displayValue: "\(num)", type: .number)]
            }
        } else if value is NSNull {
            return [JSONTreeNode(id: currentPath, key: key, displayValue: "null", type: .null)]
        } else {
            return [JSONTreeNode(id: currentPath, key: key, displayValue: "\(value)", type: .string)]
        }
    }
    
    // MARK: - JSON to CSV
    public func convertToCSV(_ jsonString: String) throws -> String {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "JSONError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid text"])
        }
        let root = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        
        let items: [[String: Any]]
        if let arr = root as? [[String: Any]] {
            items = arr
        } else if let dict = root as? [String: Any] {
            // Find any array inside dict
            if let firstArray = dict.values.first(where: { $0 is [[String: Any]] }) as? [[String: Any]] {
                items = firstArray
            } else {
                items = [dict]
            }
        } else {
            throw NSError(domain: "JSONError", code: 3, userInfo: [NSLocalizedDescriptionKey: "JSON must be an array of objects to convert to CSV"])
        }
        
        guard !items.isEmpty else { return "" }
        
        // Collect all distinct keys across all items
        var headerKeys: [String] = []
        for item in items {
            for k in item.keys where !headerKeys.contains(k) {
                headerKeys.append(k)
            }
        }
        headerKeys.sort()
        
        var csv = headerKeys.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",") + "\n"
        
        for item in items {
            let row = headerKeys.map { k -> String in
                guard let val = item[k] else { return "" }
                let strVal: String
                if let s = val as? String {
                    strVal = s
                } else if let n = val as? NSNumber {
                    strVal = "\(n)"
                } else if val is NSNull {
                    strVal = ""
                } else if let subData = try? JSONSerialization.data(withJSONObject: val, options: []),
                          let subStr = String(data: subData, encoding: .utf8) {
                    strVal = subStr
                } else {
                    strVal = "\(val)"
                }
                return "\"\(strVal.replacingOccurrences(of: "\"", with: "\"\""))\""
            }.joined(separator: ",")
            csv.append(row + "\n")
        }
        
        return csv
    }
    
    // MARK: - JSON Diff
    public func compare(jsonA: String, jsonB: String) throws -> [JSONDiffItem] {
        guard let dataA = jsonA.data(using: .utf8),
              let dataB = jsonB.data(using: .utf8) else {
            throw NSError(domain: "JSONError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid encoding"])
        }
        let rootA = try JSONSerialization.jsonObject(with: dataA, options: [.fragmentsAllowed])
        let rootB = try JSONSerialization.jsonObject(with: dataB, options: [.fragmentsAllowed])
        
        var diffs: [JSONDiffItem] = []
        computeDiff(valA: rootA, valB: rootB, path: "root", diffs: &diffs)
        return diffs
    }
    
    private func computeDiff(valA: Any?, valB: Any?, path: String, diffs: inout [JSONDiffItem]) {
        if valA == nil && valB != nil {
            diffs.append(JSONDiffItem(path: path, changeType: .added, oldValue: nil, newValue: stringify(valB!)))
            return
        }
        if valA != nil && valB == nil {
            diffs.append(JSONDiffItem(path: path, changeType: .removed, oldValue: stringify(valA!), newValue: nil))
            return
        }
        
        guard let a = valA, let b = valB else { return }
        
        if let dictA = a as? [String: Any], let dictB = b as? [String: Any] {
            let allKeys = Set(dictA.keys).union(dictB.keys).sorted()
            for k in allKeys {
                let subPath = "\(path).\(k)"
                computeDiff(valA: dictA[k], valB: dictB[k], path: subPath, diffs: &diffs)
            }
        } else if let arrA = a as? [Any], let arrB = b as? [Any] {
            let maxCount = max(arrA.count, arrB.count)
            for i in 0..<maxCount {
                let subPath = "\(path)[\(i)]"
                let elemA = i < arrA.count ? arrA[i] : nil
                let elemB = i < arrB.count ? arrB[i] : nil
                computeDiff(valA: elemA, valB: elemB, path: subPath, diffs: &diffs)
            }
        } else {
            let strA = stringify(a)
            let strB = stringify(b)
            if strA != strB {
                diffs.append(JSONDiffItem(path: path, changeType: .modified, oldValue: strA, newValue: strB))
            }
        }
    }
    
    private func stringify(_ value: Any) -> String {
        if let str = value as? String { return "\"\(str)\"" }
        if let num = value as? NSNumber { return "\(num)" }
        if value is NSNull { return "null" }
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "\(value)"
    }
}

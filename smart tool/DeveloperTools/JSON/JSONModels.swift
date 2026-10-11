//
//  JSONModels.swift
//  Borno Pulse
//

import Foundation

public enum JSONValueType: String, CaseIterable, Sendable {
    case object = "Object"
    case array = "Array"
    case string = "String"
    case number = "Number"
    case boolean = "Boolean"
    case null = "Null"
}

public struct JSONTreeNode: Identifiable, Sendable {
    public let id: String
    public let key: String
    public let displayValue: String
    public let type: JSONValueType
    public let childrenCount: Int
    public var children: [JSONTreeNode]
    
    public init(
        id: String = UUID().uuidString,
        key: String,
        displayValue: String,
        type: JSONValueType,
        childrenCount: Int = 0,
        children: [JSONTreeNode] = []
    ) {
        self.id = id
        self.key = key
        self.displayValue = displayValue
        self.type = type
        self.childrenCount = childrenCount
        self.children = children
    }
}

public struct JSONValidationResult: Sendable {
    public let isValid: Bool
    public let errorMessage: String?
    public let line: Int?
    public let column: Int?
    public let byteOffset: Int?
    
    public init(isValid: Bool, errorMessage: String? = nil, line: Int? = nil, column: Int? = nil, byteOffset: Int? = nil) {
        self.isValid = isValid
        self.errorMessage = errorMessage
        self.line = line
        self.column = column
        self.byteOffset = byteOffset
    }
}

public enum JSONDiffChangeType: String, Sendable {
    case added = "Added"
    case removed = "Removed"
    case modified = "Modified"
}

public struct JSONDiffItem: Identifiable, Sendable {
    public let id: UUID
    public let path: String
    public let changeType: JSONDiffChangeType
    public let oldValue: String?
    public let newValue: String?
    
    public init(id: UUID = UUID(), path: String, changeType: JSONDiffChangeType, oldValue: String?, newValue: String?) {
        self.id = id
        self.path = path
        self.changeType = changeType
        self.oldValue = oldValue
        self.newValue = newValue
    }
}

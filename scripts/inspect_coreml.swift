#!/usr/bin/env swift

import CoreML
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: inspect_coreml.swift <model.mlmodel>\n".utf8))
    exit(64)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let compiledURL = try MLModel.compileModel(at: sourceURL)
defer { try? FileManager.default.removeItem(at: compiledURL) }

let model = try MLModel(contentsOf: compiledURL)
let description = model.modelDescription

print("inputs")
for (name, feature) in description.inputDescriptionsByName.sorted(by: { $0.key < $1.key }) {
    print("  \(name): \(feature)")
}

print("outputs")
for (name, feature) in description.outputDescriptionsByName.sorted(by: { $0.key < $1.key }) {
    print("  \(name): \(feature)")
}

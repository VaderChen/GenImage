import Foundation

public struct WorkflowGraph: Sendable {
    public private(set) var assets: [ImageAsset]
    public private(set) var operations: [WorkflowOperation]

    public init(assets: [ImageAsset] = [], operations: [WorkflowOperation] = []) {
        self.assets = assets
        self.operations = operations
    }

    public mutating func append(asset: ImageAsset) {
        assets.append(asset)
    }

    public mutating func append(operation: WorkflowOperation) {
        operations.append(operation)
    }

    public func asset(id: UUID) -> ImageAsset? {
        assets.first { $0.id == id }
    }

    public func children(of assetID: UUID) -> [ImageAsset] {
        assets
            .filter { $0.parentAssetID == assetID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func lineage(of assetID: UUID) -> [ImageAsset] {
        var result: [ImageAsset] = []
        var currentID: UUID? = assetID
        var visited = Set<UUID>()

        while let id = currentID, visited.insert(id).inserted, let current = asset(id: id) {
            result.append(current)
            currentID = current.parentAssetID
        }

        return result.reversed()
    }
}

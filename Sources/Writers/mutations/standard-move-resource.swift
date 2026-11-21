import Foundation
import IO

public struct StandardMoveResource: Sendable, Codable, Hashable {
    public var source: URL
    public var destination: URL
    public var createParentDirectories: Bool

    public init(
        source: URL,
        destination: URL,
        createParentDirectories: Bool = true
    ) {
        self.source = source.standardizedFileURL
        self.destination = destination.standardizedFileURL
        self.createParentDirectories = createParentDirectories
    }
}

public struct StandardMoveResourceState: Sendable, Codable, Hashable {
    public let url: URL
    public let existed: Bool
    public let kind: FileKind?
    public let byteCount: Int?
    public let modifiedAt: Date?
    public let identity: FileIdentity?

    public init(
        snapshot: FileMetadataSnapshot
    ) {
        self.url = snapshot.url.standardizedFileURL
        self.existed = snapshot.existed
        self.kind = snapshot.kind
        self.byteCount = snapshot.byteCount
        self.modifiedAt = snapshot.modifiedAt
        self.identity = snapshot.identity
    }

    public static func inspect(
        _ url: URL
    ) throws -> Self {
        .init(
            snapshot: try FileInspector(
                url
            ).inspect()
        )
    }

    public static func missing(
        at url: URL
    ) -> Self {
        .init(
            snapshot: .init(
                url: url,
                existed: false,
                byteCount: nil,
                modifiedAt: nil,
                identity: nil,
                kind: nil
            )
        )
    }

    /// The same object at `url` after a move. A move across volumes is a
    /// copy: identity (device, inode) and modification time are new, and a
    /// directory's size is the filesystem's own, so only existence, kind and
    /// a file's byte count carry over; the rest is left unrecorded.
    public func relocating(
        to url: URL,
        acrossVolumes: Bool = false
    ) -> Self {
        .init(
            snapshot: .init(
                url: url,
                existed: existed,
                byteCount: acrossVolumes && kind != .file ? nil : byteCount,
                modifiedAt: acrossVolumes ? nil : modifiedAt,
                identity: acrossVolumes ? nil : identity,
                kind: kind
            )
        )
    }

    public func requireCurrent() throws {
        let current = try Self.inspect(
            url
        )

        // An existing object's unrecorded facts (nil) are not compared.
        guard current.existed == existed,
              current.kind == kind,
              !existed || byteCount == nil || current.byteCount == byteCount,
              !existed || modifiedAt == nil || current.modifiedAt == modifiedAt,
              !existed || identity == nil || current.identity == identity,
              existed || (current.byteCount == byteCount
                  && current.modifiedAt == modifiedAt
                  && current.identity == identity)
        else {
            throw StandardMutationError.metadata_drift_detected(
                target: url
            )
        }
    }
}

public struct StandardMovePlan: Sendable, Codable, Hashable {
    public let source: StandardMoveResourceState
    public let destination: StandardMoveResourceState

    public init(
        source: StandardMoveResourceState,
        destination: StandardMoveResourceState
    ) {
        self.source = source
        self.destination = destination
    }

    public func requireCurrent() throws {
        try source.requireCurrent()
        try destination.requireCurrent()
    }
}

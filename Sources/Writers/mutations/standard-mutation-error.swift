import Foundation

public enum StandardMutationError: Error, Sendable {
    case empty_entries
    case duplicate_target(URL)
    /// Two entries of one pass touch a directory and something inside it.
    case nested_targets(outer: URL, inner: URL)
    case target_missing(URL)
    case target_exists(URL)
    case target_not_text(URL)
    case target_not_copyable_resource(URL)
    case target_not_movable_resource(URL)
    case metadata_drift_detected(target: URL)
    case unsupported_rollback_action
    case drift_detected(
        target: URL,
        expected: StandardContentFingerprint?,
        actual: StandardContentFingerprint?
    )
    /// A file is larger than the destination volume can hold (FAT32: 4 GiB − 1).
    case exceeds_file_size_limit(source: URL, destination: URL, size: Int64, limit: Int64)
    /// The pass writes more to a volume than it has free.
    case insufficient_space(volume: URL, needed: Int64, available: Int64)
}

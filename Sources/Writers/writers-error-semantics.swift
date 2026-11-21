import Errors
import Foundation

private extension URL {
    var pathField: ErrorDiagnosticField {
        .init(key: .path, value: .string(standardizedFileURL.path), sensitivity: .potentially_sensitive)
    }
}

private func bytes(
    _ value: Int64
) -> String {
    ByteCountFormatter.string(fromByteCount: value, countStyle: .binary)
}

// MARK: - Mutation planning and publication

extension StandardMutationError: SemanticError, ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "writers.mutation"

    public var errorCode: String {
        switch self {
        case .empty_entries: return "empty_entries"
        case .duplicate_target: return "duplicate_target"
        case .nested_targets: return "nested_targets"
        case .target_missing: return "target_missing"
        case .target_exists: return "target_exists"
        case .target_not_text: return "target_not_text"
        case .target_not_copyable_resource: return "target_not_copyable"
        case .target_not_movable_resource: return "target_not_movable"
        case .metadata_drift_detected: return "metadata_drift"
        case .unsupported_rollback_action: return "unsupported_rollback_action"
        case .drift_detected: return "drift"
        case .exceeds_file_size_limit: return "exceeds_file_size_limit"
        case .insufficient_space: return "insufficient_space"
        }
    }

    public var errorPresentation: ErrorPresentation {
        switch self {
        case .empty_entries:
            return .init(message: "Mutation pass cannot be empty.")
        case .duplicate_target(let target):
            return .init(
                message: "Mutation pass names \(target.path) more than once.",
                recoverySuggestion: "Merge same-file changes into one entry.",
                messageSensitivity: .potentially_sensitive
            )
        case .nested_targets(let outer, let inner):
            return .init(
                message: "Mutation pass changes \(outer.path) and, in another entry, \(inner.path) inside it.",
                recoverySuggestion: "Split them into separate passes: first the entries inside, then the directory.",
                messageSensitivity: .potentially_sensitive
            )
        case .target_missing(let target):
            return .init(message: "Mutation target is missing: \(target.path).", messageSensitivity: .potentially_sensitive)
        case .target_exists(let target):
            return .init(
                message: "Mutation target already exists: \(target.path).",
                recoverySuggestion: "Choose another destination, or replace it explicitly.",
                messageSensitivity: .potentially_sensitive
            )
        case .target_not_text(let target):
            return .init(message: "Mutation target is not readable as text: \(target.path).", messageSensitivity: .potentially_sensitive)
        case .target_not_copyable_resource(let target):
            return .init(message: "Mutation source is not a copyable file or directory: \(target.path).", messageSensitivity: .potentially_sensitive)
        case .target_not_movable_resource(let target):
            return .init(message: "Mutation source is not a movable file or directory: \(target.path).", messageSensitivity: .potentially_sensitive)
        case .metadata_drift_detected(let target), .drift_detected(let target, _, _):
            return .init(
                message: "\(target.path) changed since the pass was planned.",
                recoverySuggestion: "Plan the pass again from the current state.",
                messageSensitivity: .potentially_sensitive
            )
        case .unsupported_rollback_action:
            return .init(message: "Mutation rollback action is not supported by this pass.")
        case .exceeds_file_size_limit(let source, let destination, let size, let limit):
            return .init(
                message: "\(source.path) holds a file of \(bytes(size)); the volume of \(destination.path) holds files up to \(bytes(limit)).",
                reason: "The destination volume's format limits file size (FAT32: 4 GiB − 1). Nothing was written.",
                recoverySuggestion: "Choose a destination on another volume, or one formatted exFAT or APFS.",
                messageSensitivity: .potentially_sensitive
            )
        case .insufficient_space(let volume, let needed, let available):
            return .init(
                message: "This pass writes \(bytes(needed)) to the volume of \(volume.path), which has \(bytes(available)) free.",
                reason: "Nothing was written.",
                recoverySuggestion: "Free space there, choose another destination, or split the pass.",
                messageSensitivity: .potentially_sensitive
            )
        }
    }

    public var errorDiagnosticFields: [ErrorDiagnosticField] {
        switch self {
        case .empty_entries, .unsupported_rollback_action:
            return []
        case .duplicate_target(let target), .target_missing(let target), .target_exists(let target),
             .target_not_text(let target), .target_not_copyable_resource(let target),
             .target_not_movable_resource(let target), .metadata_drift_detected(let target):
            return [target.pathField]
        case .nested_targets(let outer, let inner):
            return [outer.pathField, .init(key: "writers.inner_path", value: .string(inner.path), sensitivity: .potentially_sensitive)]
        case .drift_detected(let target, let expected, let actual):
            return [
                target.pathField,
                .init(key: "writers.expected", value: .string(expected.map(String.init(describing:)) ?? "missing")),
                .init(key: "writers.actual", value: .string(actual.map(String.init(describing:)) ?? "missing")),
            ]
        case .exceeds_file_size_limit(let source, _, let size, let limit):
            return [source.pathField, .init(key: "writers.file_bytes", value: .integer(Int(size))), .init(key: "writers.limit_bytes", value: .integer(Int(limit)))]
        case .insufficient_space(let volume, let needed, let available):
            return [volume.pathField, .init(key: "writers.needed_bytes", value: .integer(Int(needed))), .init(key: "writers.available_bytes", value: .integer(Int(available)))]
        }
    }

    public var errorDisposition: ErrorDisposition? {
        switch self {
        case .metadata_drift_detected, .drift_detected:
            return .transient
        case .unsupported_rollback_action:
            return .permanent
        default:
            return .invalid_input
        }
    }
}

extension StandardMutationCoordinationError: SemanticError, ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "writers.coordination"

    public var errorCode: String {
        switch self {
        case .unknown_participant: return "unknown_participant"
        case .closed_participant: return "closed_participant"
        case .unknown_submission: return "unknown_submission"
        case .submission_not_owned: return "submission_not_owned"
        case .submission_not_pending: return "submission_not_pending"
        case .conflict: return "conflict"
        case .unsupported_merge: return "unsupported_merge"
        case .incompatible_edit_options: return "incompatible_edit_options"
        case .overlapping_submission_footprints: return "overlapping_footprints"
        case .publication_attribution_missing: return "attribution_missing"
        case .unknown_publication: return "unknown_publication"
        case .publication_already_rolled_back: return "already_rolled_back"
        case .publication_not_rollbackable: return "not_rollbackable"
        case .staged_visibility_unsupported: return "staged_visibility_unsupported"
        case .review_changed: return "review_changed"
        case .requires_recovery: return "requires_recovery"
        }
    }

    public var errorPresentation: ErrorPresentation {
        switch self {
        case .conflict(let file, let blocking):
            return .init(
                message: "\(file.lastPathComponent) already has staged changes awaiting review (submission \(blocking)).",
                recoverySuggestion: "Report the staged change instead of retrying; it can change again once published or discarded.",
                messageSensitivity: .potentially_sensitive
            )
        case .unknown_participant(let id):
            return .init(message: "Unknown mutation participant \(id).")
        case .closed_participant(let id):
            return .init(message: "Mutation participant \(id) is closed.")
        case .unknown_submission(let id):
            return .init(message: "Unknown staged submission \(id).")
        case .submission_not_owned(let id):
            return .init(message: "Staged submission \(id) belongs to another participant.")
        case .submission_not_pending(let id):
            return .init(message: "Staged submission \(id) is no longer pending.")
        case .unsupported_merge(let file):
            return .init(message: "Staged changes to \(file.lastPathComponent) cannot be combined.", messageSensitivity: .potentially_sensitive)
        case .incompatible_edit_options(let file):
            return .init(message: "Staged edits to \(file.lastPathComponent) use incompatible options.", messageSensitivity: .potentially_sensitive)
        case .overlapping_submission_footprints(let file):
            return .init(
                message: "One plan changes \(file.lastPathComponent) through overlapping entries.",
                recoverySuggestion: "Split the overlapping entries into separate passes.",
                messageSensitivity: .potentially_sensitive
            )
        case .publication_attribution_missing(let file):
            return .init(message: "Publication of \(file.lastPathComponent) lost its attribution.", messageSensitivity: .potentially_sensitive)
        case .unknown_publication(let id):
            return .init(message: "Unknown publication \(id).")
        case .publication_already_rolled_back(let id):
            return .init(message: "Publication \(id) was already rolled back.")
        case .publication_not_rollbackable(let id):
            return .init(message: "Publication \(id) cannot be rolled back.")
        case .staged_visibility_unsupported(let file):
            return .init(message: "Staged copy or move of \(file.lastPathComponent) cannot be read as a file.", messageSensitivity: .potentially_sensitive)
        case .review_changed:
            return .init(message: "The staged changes changed since they were reviewed.", recoverySuggestion: "Review them again.")
        case .requires_recovery:
            return .init(
                message: "A failed publication needs recovery before further changes.",
                reason: "An earlier change may have stopped halfway; its effect on disk is uncertain.",
                recoverySuggestion: "Inspect the failed target, then have the owner recover the coordinator."
            )
        }
    }

    public var errorDiagnosticFields: [ErrorDiagnosticField] {
        switch self {
        case .conflict(let file, let blocking):
            return [file.pathField, .init(key: "writers.submission", value: .string(blocking.uuidString))]
        case .unsupported_merge(let file), .incompatible_edit_options(let file),
             .overlapping_submission_footprints(let file), .publication_attribution_missing(let file),
             .staged_visibility_unsupported(let file):
            return [file.pathField]
        case .unknown_participant(let id), .closed_participant(let id), .unknown_submission(let id),
             .submission_not_owned(let id), .submission_not_pending(let id), .unknown_publication(let id),
             .publication_already_rolled_back(let id), .publication_not_rollbackable(let id):
            return [.init(key: "writers.id", value: .string(id.uuidString))]
        case .review_changed, .requires_recovery:
            return []
        }
    }

    public var errorDisposition: ErrorDisposition? {
        switch self {
        case .incompatible_edit_options, .overlapping_submission_footprints:
            return .invalid_input
        case .review_changed:
            return .transient
        case .requires_recovery:
            return .requires_access
        case .conflict:
            return nil
        default:
            return .permanent
        }
    }
}

// MARK: - Errors whose own text already reads well: identity and disposition

extension SafeFileError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "writers.safe_file"

    public var errorCode: String {
        switch self {
        case .parentDirectoryMissing: return "parent_directory_missing"
        case .overwriteConflict: return "overwrite_conflict"
        case .backupNotFound: return "backup_not_found"
        case .nothingToRestore: return "nothing_to_restore"
        case .io: return "io"
        default: return "overwrite_conflict"
        }
    }

    public var errorDisposition: ErrorDisposition? {
        switch self {
        case .io: return nil
        default: return .invalid_input
        }
    }
}

extension SafePreflightError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "writers.preflight"
    public var errorCode: String { "refusing_to_overwrite" }
    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension FileWriteCommitError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "writers.commit"
    public var errorCode: String { "incomplete_write" }
    public var errorDisposition: ErrorDisposition? { nil }
}

extension WriteExecutionStalePlanError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "writers.stale_plan"

    public var errorCode: String {
        switch self {
        case .current_missing: return "current_missing"
        case .current_appeared: return "current_appeared"
        case .current_mismatch: return "current_mismatch"
        }
    }

    /// Planning again from the current file resolves it.
    public var errorDisposition: ErrorDisposition? { .transient }
}

extension StandardEditError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "writers.edit"

    public var errorCode: String {
        switch self {
        case .emptyMatchString: return "empty_match"
        case .matchNotFound: return "match_not_found"
        case .matchNotUnique: return "match_not_unique"
        case .lineOutOfBounds: return "line_out_of_bounds"
        case .lineRangeOutOfBounds: return "line_range_out_of_bounds"
        case .insertionLineOutOfBounds: return "insertion_line_out_of_bounds"
        case .lineMismatch: return "line_mismatch"
        case .lineRangeMismatch: return "line_range_mismatch"
        case .invalidPositionRange: return "invalid_position_range"
        case .positionRangeOutOfBounds: return "position_range_out_of_bounds"
        case .positionRangeMismatch: return "position_range_mismatch"
        case .insertionSiteMismatch: return "insertion_site_mismatch"
        case .invalidLogicalLine: return "invalid_logical_line"
        }
    }

    public var errorDisposition: ErrorDisposition? { .invalid_input }
}

extension StandardEditApplyError: ErrorNamespaced, ErrorDispositionProviding {
    public static let errorNamespace = "writers.edit_apply"
    public var errorCode: String { code.rawValue }

    public var errorDisposition: ErrorDisposition? {
        switch self {
        case .drift_detected: return .transient
        default: return .invalid_input
        }
    }
}

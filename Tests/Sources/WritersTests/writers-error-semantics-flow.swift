import Errors
import Foundation
import Testing
import Writers

extension WritersFlowSuite {
    /// Writers' errors end to end through the Errors library: identity,
    /// message, a field and the disposition.
    static var errorSemanticsFlow: TestFlow {
        TestFlow("error-semantics", tags: ["errors", "mutations"]) {
            Step("a planning refusal reads as an input to change") {
                let workspace = try TestWorkspace("error-semantics-nested")
                defer { workspace.remove() }
                let folder = workspace.file("Photos")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let inside = folder.appendingPathComponent("a.txt")
                _ = try StandardWriter(inside).write("a\n", options: .overwriteWithoutBackup)

                do {
                    _ = try StandardMutationPlanner().plan([
                        .move(.init(source: inside, destination: folder.appendingPathComponent("b.txt"))),
                        .move(.init(source: folder, destination: workspace.file("Album"))),
                    ])
                    throw StandardMutationError.empty_entries
                } catch let error as StandardMutationError {
                    try Expect.equal(error.errorIdentity.raw, "writers.mutation.nested_targets", "errors.identity")
                    try Expect.equal(error.errorDisposition, .invalid_input, "errors.disposition")
                    try Expect.true(error.explanation.contains("separate passes"), "errors.explanation_has_suggestion")
                    let report = error.report(for: .diagnostic)
                    try Expect.true(
                        report.diagnostic.fields.contains { $0.name == "path" && $0.sensitivity == .potentially_sensitive },
                        "errors.path_field_sensitive"
                    )
                }
            }

            Step("a coordinator awaiting recovery says who must act") {
                let error = StandardMutationCoordinationError.requires_recovery
                try Expect.equal(error.errorIdentity.raw, "writers.coordination.requires_recovery", "errors.recovery_identity")
                try Expect.equal(error.errorDisposition, .requires_access, "errors.recovery_disposition")
                try Expect.equal(
                    error.localizedDescription,
                    "A failed publication needs recovery before further changes.",
                    "errors.recovery_message"
                )
            }
        }
    }
}

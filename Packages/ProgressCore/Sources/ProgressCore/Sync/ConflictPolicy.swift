import Foundation

/// What to do with a row arriving from the server.
public enum PullDecision: Equatable, Sendable {
    /// The device has never seen this record.
    case insert
    /// The server copy is newer and the device has no unsent edits.
    case apply
    /// The device already has this version or a later one.
    case ignore
    /// Both the server and this device changed the record since they last agreed.
    case conflict
}

public enum ConflictPolicy {
    public static func decide(local: LocalSyncState?, remoteVersion: Int) -> PullDecision {
        guard let local else { return .insert }
        if remoteVersion <= local.baseVersion { return .ignore }
        return local.isDirty ? .conflict : .apply
    }

    /// True when a "conflict" is really the same content, e.g. two devices created the same
    /// default record, or a push succeeded but its response was lost.
    public static func isSameContent(local: LocalRecord, remote: RemoteRow) -> Bool {
        guard (local.deletedAt == nil) == (remote.deletedAt == nil) else { return false }
        for (key, value) in local.fields where remote.fields[key] != value {
            if let localDate = value.dateValue, let remoteDate = remote.fields[key]?.dateValue,
               abs(localDate.timeIntervalSince(remoteDate)) < 0.001 {
                continue
            }
            return false
        }
        return true
    }
}

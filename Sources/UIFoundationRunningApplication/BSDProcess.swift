#if RunningApplication && os(macOS)

import Darwin
import MachO
import Security

enum BSDProcess {
    static func allPIDs() -> [pid_t] {
        let bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bufferSize > 0 else { return [] }

        let pidCount = Int(bufferSize) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: pidCount)
        let actualSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, bufferSize)
        guard actualSize > 0 else { return [] }

        let actualCount = Int(actualSize) / MemoryLayout<pid_t>.size
        return Array(pids[0..<actualCount].filter { $0 > 0 })
    }

    static func name(for pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return buffer.withUnsafeBufferPointer { ptr in
            String(decoding: UnsafeRawBufferPointer(ptr).prefix(Int(length)), as: UTF8.self)
        }
    }

    static func executablePath(for pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return buffer.withUnsafeBufferPointer { ptr in
            String(decoding: UnsafeRawBufferPointer(ptr).prefix(Int(length)), as: UTF8.self)
        }
    }

    static func isRunning(pid: pid_t) -> Bool {
        // kill(pid, 0) returns 0 if we have permission, or -1 with EPERM if the process
        // exists but belongs to another user. Both cases mean the process is running.
        kill(pid, 0) == 0 || errno == EPERM
    }

    // MARK: - Architecture Detection

    // PROC_PIDARCHINFO is declared in <sys/proc_info.h> but not exposed to Swift.
    // It returns the kernel-tracked running architecture (cputype + cpusubtype) for
    // the process — automatically resolving the active slice of a Universal binary
    // and distinguishing arm64 from arm64e via cpusubtype.
    private static let PROC_PIDARCHINFO: Int32 = 19

    /// The raw CPU type and subtype the kernel is running this process as.
    ///
    /// Also used to pick the matching slice out of a universal binary, so it is exposed
    /// unmapped rather than only as an ``Architecture``.
    static func machOArchitecture(for pid: pid_t) -> MachOArchitecture? {
        var info = (cputype: cpu_type_t(0), cpusubtype: cpu_subtype_t(0))
        let size = Int32(MemoryLayout.size(ofValue: info))
        let bytesRead = withUnsafeMutablePointer(to: &info) { pointer in
            proc_pidinfo(pid, PROC_PIDARCHINFO, 0, UnsafeMutableRawPointer(pointer), size)
        }
        guard bytesRead == size else { return nil }
        return MachOArchitecture(cpuType: info.cputype, cpuSubtype: info.cpusubtype)
    }

    static func architecture(for pid: pid_t) -> Architecture? {
        machOArchitecture(for: pid).map(architecture(of:))
    }

    static func architecture(of machOArchitecture: MachOArchitecture) -> Architecture {
        // Strip CPU_SUBTYPE_MASK (0xff000000 capability bits) before matching.
        let subtype = machOArchitecture.cpuSubtypeWithoutCapabilities
        switch machOArchitecture.cpuType {
        case CPU_TYPE_ARM64:
            return subtype == CPU_SUBTYPE_ARM64E ? .arm64e : .arm64
        case CPU_TYPE_X86_64: return .x86_64
        case CPU_TYPE_I386: return .i386
        case CPU_TYPE_POWERPC: return .ppc
        case CPU_TYPE_POWERPC64: return .ppc64
        default: return .unknown
        }
    }

    // MARK: - Sandbox Detection

    static func isSandboxed(pid: pid_t) -> Bool {
        let attributes = [kSecGuestAttributePid: pid] as CFDictionary
        var code: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess,
              let code else { return false }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
              let staticCode else { return false }

        var info: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info
        ) == errSecSuccess, let info = info as? [String: Any] else { return false }

        guard let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any] else {
            return false
        }
        return entitlements["com.apple.security.app-sandbox"] as? Bool ?? false
    }
}

#endif

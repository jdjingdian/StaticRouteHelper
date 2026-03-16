//
//  PFRouteWriter.swift
//  cn.magicdian.staticrouter.helper
//

import Foundation
import Darwin

// MARK: - PFRouteWriter

/// Writes IPv4 routes directly to the kernel via PF_ROUTE socket (RTM_ADD / RTM_DELETE).
/// Requires the process to be running as root.
enum PFRouteWriter {

    // Monotonic sequence counter for rt_msghdr.rtm_seq
    private static var _seq: Int32 = 0
    private static func nextSeq() -> Int32 {
        _seq = _seq &+ 1
        return _seq
    }

    /// Add or remove an IPv4 route by writing an RTM_ADD / RTM_DELETE message to the PF_ROUTE socket.
    /// - Parameter request: The structured route write request.
    /// - Returns: A `RouteWriteReply` indicating success or describing the failure.
    static func write(request: RouteWriteRequest) -> RouteWriteReply {
        NSLog("PFRouteWriter: %@ %@ via %@ (%@)",
              request.add ? "ADD" : "DELETE",
              request.network,
              request.gateway,
              request.gatewayType == .interface ? "iface" : "ip")

        // Open PF_ROUTE raw socket (requires root)
        let sock = socket(PF_ROUTE, SOCK_RAW, AF_UNSPEC)
        guard sock >= 0 else {
            let msg = "Failed to open PF_ROUTE socket: \(String(cString: strerror(errno)))"
            NSLog("PFRouteWriter: %@", msg)
            return RouteWriteReply(success: false, errorMessage: msg)
        }
        defer { close(sock) }

        let rtmType: UInt8 = request.add ? UInt8(RTM_ADD) : UInt8(RTM_DELETE)

        switch request.gatewayType {
        case .ipAddress:
            return writeIPGatewayRoute(sock: sock,
                                       rtmType: rtmType,
                                       network: request.network,
                                       mask: request.mask,
                                       gateway: request.gateway)
        case .interface:
            return writeInterfaceRoute(sock: sock,
                                       rtmType: rtmType,
                                       network: request.network,
                                       mask: request.mask,
                                       ifaceName: request.gateway)
        }
    }

    // MARK: - IP Gateway Path

    /// Build and send RTM_ADD/RTM_DELETE with RTA_DST | RTA_GATEWAY | RTA_NETMASK.
    private static func writeIPGatewayRoute(sock: Int32,
                                            rtmType: UInt8,
                                            network: String,
                                            mask: String,
                                            gateway: String) -> RouteWriteReply {
        guard let dstSin = makeSockaddrIn(ip: network),
              let gwSin  = makeSockaddrIn(ip: gateway),
              let nmSin  = makeSockaddrIn(ip: mask) else {
            return RouteWriteReply(success: false,
                                   errorMessage: "Invalid IPv4 address in request (dst=\(network) gw=\(gateway) mask=\(mask))")
        }

        // Layout: rt_msghdr | sockaddr_in (dst) | sockaddr_in (gateway) | sockaddr_in (netmask)
        let hdrSize  = MemoryLayout<rt_msghdr>.size
        let sinSize  = MemoryLayout<sockaddr_in>.size
        let totalLen = hdrSize + sinSize * 3

        var buf = Data(count: totalLen)
        buf.withUnsafeMutableBytes { raw in
            // --- rt_msghdr ---
            var hdr = rt_msghdr()
            hdr.rtm_version = UInt8(RTM_VERSION)
            hdr.rtm_type    = rtmType
            hdr.rtm_msglen  = UInt16(totalLen)
            hdr.rtm_addrs   = Int32(RTA_DST | RTA_GATEWAY | RTA_NETMASK)
            hdr.rtm_flags   = Int32(RTF_UP | RTF_GATEWAY | RTF_STATIC)
            hdr.rtm_seq     = nextSeq()
            hdr.rtm_pid     = getpid()
            raw.storeBytes(of: hdr, toByteOffset: 0, as: rt_msghdr.self)

            // --- RTA_DST ---
            raw.storeBytes(of: dstSin, toByteOffset: hdrSize, as: sockaddr_in.self)
            // --- RTA_GATEWAY ---
            raw.storeBytes(of: gwSin,  toByteOffset: hdrSize + sinSize, as: sockaddr_in.self)
            // --- RTA_NETMASK ---
            raw.storeBytes(of: nmSin,  toByteOffset: hdrSize + sinSize * 2, as: sockaddr_in.self)
        }

        return sendBuffer(sock: sock, buf: buf)
    }

    // MARK: - Interface Gateway Path

    /// Build and send RTM_ADD/RTM_DELETE with RTA_DST | RTA_NETMASK | RTA_IFP.
    private static func writeInterfaceRoute(sock: Int32,
                                            rtmType: UInt8,
                                            network: String,
                                            mask: String,
                                            ifaceName: String) -> RouteWriteReply {
        // Resolve interface index
        let ifIndex = ifaceName.withCString { if_nametoindex($0) }
        guard ifIndex != 0 else {
            let msg = "Interface not found: \(ifaceName)"
            NSLog("PFRouteWriter: %@", msg)
            return RouteWriteReply(success: false, errorMessage: msg)
        }

        guard let dstSin = makeSockaddrIn(ip: network),
              let nmSin  = makeSockaddrIn(ip: mask) else {
            return RouteWriteReply(success: false,
                                   errorMessage: "Invalid IPv4 address in request (dst=\(network) mask=\(mask))")
        }

        // Build sockaddr_dl for the interface
        var sdl = sockaddr_dl()
        sdl.sdl_len    = UInt8(MemoryLayout<sockaddr_dl>.size)
        sdl.sdl_family = UInt8(AF_LINK)
        sdl.sdl_index  = UInt16(ifIndex)

        // Layout: rt_msghdr | sockaddr_in (dst) | sockaddr_in (netmask) | sockaddr_dl (ifp)
        let hdrSize  = MemoryLayout<rt_msghdr>.size
        let sinSize  = MemoryLayout<sockaddr_in>.size
        let sdlSize  = MemoryLayout<sockaddr_dl>.size
        let totalLen = hdrSize + sinSize * 2 + sdlSize

        var buf = Data(count: totalLen)
        buf.withUnsafeMutableBytes { raw in
            // --- rt_msghdr ---
            var hdr = rt_msghdr()
            hdr.rtm_version = UInt8(RTM_VERSION)
            hdr.rtm_type    = rtmType
            hdr.rtm_msglen  = UInt16(totalLen)
            hdr.rtm_addrs   = Int32(RTA_DST | RTA_NETMASK | RTA_IFP)
            hdr.rtm_flags   = Int32(RTF_UP | RTF_STATIC)
            hdr.rtm_seq     = nextSeq()
            hdr.rtm_pid     = getpid()
            raw.storeBytes(of: hdr, toByteOffset: 0, as: rt_msghdr.self)

            // --- RTA_DST ---
            raw.storeBytes(of: dstSin, toByteOffset: hdrSize, as: sockaddr_in.self)
            // --- RTA_NETMASK ---
            raw.storeBytes(of: nmSin,  toByteOffset: hdrSize + sinSize, as: sockaddr_in.self)
            // --- RTA_IFP ---
            raw.storeBytes(of: sdl,    toByteOffset: hdrSize + sinSize * 2, as: sockaddr_dl.self)
        }

        return sendBuffer(sock: sock, buf: buf)
    }

    // MARK: - Helpers

    /// Write the assembled buffer to the PF_ROUTE socket and map errno to a reply.
    private static func sendBuffer(sock: Int32, buf: Data) -> RouteWriteReply {
        let n = buf.withUnsafeBytes { ptr in
            Darwin.write(sock, ptr.baseAddress!, buf.count)
        }
        if n >= 0 {
            return RouteWriteReply(success: true, errorMessage: nil)
        }
        let err = errno
        let msg: String
        switch err {
        case EEXIST:
            msg = "Route already exists"
        case ESRCH:
            msg = "Route not found"
        default:
            msg = "Route operation failed: \(String(cString: strerror(err)))"
        }
        NSLog("PFRouteWriter: write failed errno=%d — %@", err, msg)
        return RouteWriteReply(success: false, errorMessage: msg)
    }

    /// Construct a `sockaddr_in` from a dotted-decimal IPv4 string.
    private static func makeSockaddrIn(ip: String) -> sockaddr_in? {
        var sin = sockaddr_in()
        sin.sin_len    = UInt8(MemoryLayout<sockaddr_in>.size)
        sin.sin_family = sa_family_t(AF_INET)
        let result = ip.withCString { inet_pton(AF_INET, $0, &sin.sin_addr) }
        guard result == 1 else { return nil }
        return sin
    }
}

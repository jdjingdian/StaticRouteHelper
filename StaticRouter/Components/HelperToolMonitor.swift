//
//  HelperToolMonitor.swift
//  Static Router
//
//  Created by 经典 on 9/1/2023.
//

import Foundation
import EmbeddedPropertyList

class HelperToolMonitor {
    struct StartReport {
        struct Failure {
            let directory: URL
            let errnoCode: Int32
        }

        let monitoredDirectoryCount: Int
        let activeSourceCount: Int
        let failures: [Failure]

        var hasActiveSources: Bool { activeSourceCount > 0 }
        var isDegraded: Bool { activeSourceCount == 0 }
    }

    struct InstallationStatus {
        enum HelperToolExecutable {
            /// The Helper tool exists in its expected location. Associated value is the helper tools bundle version
            case exists(BundleVersion)
            case missing
        }
        /// The helper tool is registered with launchd ( according to launchctl )
        let registeredWithLaunchd: Bool
        let registrationPropertyListExists: Bool
        let helperToolExecutable: HelperToolExecutable
    }
    
    private let monitoredDirs : [URL]
    private var dispatchSources = [URL: DispatchSourceFileSystemObject]()
    private let dirMonitorQUeue = DispatchQueue(label: "dirmonitor",attributes: .concurrent)
    private let constants: SharedConstant
    private var isStarted = false
    private(set) var lastStartReport: StartReport?
    
    /// Creates the monitor.
    init(constants: SharedConstant){
        self.constants = constants
        self.monitoredDirs = [constants.blessedLocation.deletingLastPathComponent(),constants.blessedPropertyListLocation.deletingLastPathComponent()]
    }
    
    @discardableResult
    func start(changeOccurred: @escaping (InstallationStatus) -> Void) -> StartReport {
        if isStarted, let lastStartReport {
            return lastStartReport
        }

        isStarted = true
        var failures = [StartReport.Failure]()

        for monitoredDir in monitoredDirs {
            let fileDescriptor = open((monitoredDir as NSURL).fileSystemRepresentation, O_EVTONLY)
            guard fileDescriptor >= 0 else {
                failures.append(
                    StartReport.Failure(
                        directory: monitoredDir,
                        errnoCode: errno
                    )
                )
                continue
            }

            let dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor,
                                                                           eventMask: .write,
                                                                           queue: dirMonitorQUeue)
            dispatchSources[monitoredDir] = dispatchSource
            dispatchSource.setEventHandler {
                changeOccurred(self.determineStatus())
            }
            dispatchSource.setCancelHandler {
                close(fileDescriptor)
            }
            dispatchSource.resume()
        }

        let report = StartReport(
            monitoredDirectoryCount: monitoredDirs.count,
            activeSourceCount: dispatchSources.count,
            failures: failures
        )
        lastStartReport = report

        for failure in failures {
            let message = String(cString: strerror(failure.errnoCode))
            print("[HelperToolMonitor] failed to watch '\(failure.directory.path)' errno=\(failure.errnoCode) message='\(message)' degraded=\(report.isDegraded)")
        }

        if report.isDegraded {
            print("[HelperToolMonitor] no active filesystem watcher source is available; fallback refresh is required")
        }

        return report
    }
    
    func stop(){
        guard isStarted else { return }
        for source in dispatchSources.values {
            source.cancel()
        }
        dispatchSources.removeAll()
        isStarted = false
        lastStartReport = nil
    }
    
    func determineStatus() -> InstallationStatus {
        Thread.sleep(forTimeInterval: 0.05)
        
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.arguments = ["print","system/\(constants.helperToolLabel)"]
        process.qualityOfService = QualityOfService.userInitiated
        process.standardOutput = nil
        process.standardError = nil
        process.launch()
        process.waitUntilExit()
        let registeredWithLaunchd = (process.terminationStatus == 0)
        let registrationPropertyListExists = FileManager.default.fileExists(atPath: constants.blessedPropertyListLocation.path)
        
        let helperToolExecutable: InstallationStatus.HelperToolExecutable
        
        do{
            let infoPropertyList = try HelperToolInfoPropertyList(from: constants.blessedLocation)
            helperToolExecutable = .exists(infoPropertyList.version)
        }catch{
            helperToolExecutable = .missing
        }
        
        
        return InstallationStatus(registeredWithLaunchd: registeredWithLaunchd, registrationPropertyListExists: registrationPropertyListExists, helperToolExecutable: helperToolExecutable)
    }
}


enum HelperToolInstallationState: Equatable {
    case installed
    case pendingActivation
    case needUpgrade
    case notCompatible
    case notInstalled
}

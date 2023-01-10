//
//  HelperToolMonitor.swift
//  Static Router
//
//  Created by 经典 on 9/1/2023.
//

import Foundation
import EmbeddedPropertyList

class HelperToolMonitor {
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
    
    /// Creates the monitor.
    init(constants: SharedConstant){
        self.constants = constants
        self.monitoredDirs = [constants.blessedLocation.deletingLastPathComponent(),constants.blessedPropertyListLocation.deletingLastPathComponent()]
    }
    
    func start(changeOccurred: @escaping (InstallationStatus) -> Void) {
        
        if dispatchSources.isEmpty {
            for monitoredDir in monitoredDirs {
                let fileDescriptor = open((monitoredDir as NSURL).fileSystemRepresentation, O_EVTONLY)
                let dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor,
                                                                               eventMask: .write,
                                                                               queue: dirMonitorQUeue)
                dispatchSources[monitoredDir] = dispatchSource
                dispatchSource.setEventHandler {
                    changeOccurred(self.determineStatus())
                }
                dispatchSource.setCancelHandler {
                    close(fileDescriptor)
                    self.dispatchSources.removeValue(forKey: monitoredDir)
                }
                dispatchSource.resume()
            }
        }
    }
    
    func stop(){
        for source in dispatchSources.values {
            source.cancel()
        }
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


enum HelperToolInstallationState {
    case installed
    case needUpgrade
    case notCompatible
    case notInstalled
}

//
//  LaunchOnStartupManager.swift
//  Transcrybe
//
//  Manages app launch on system startup via LaunchAgent
//

import Foundation
import Combine
import os
import ServiceManagement

class LaunchOnStartupManager: NSObject, ObservableObject {
    @Published var isEnabled = false

    private let logger = Logger(subsystem: "com.transcryb.launch", category: "manager")
    private let userDefaults = UserDefaults.standard
    private let launchOnStartupKey = "LaunchOnStartup"
    private let appIdentifier = "com.transcryb.Transcrybe"

    override init() {
        super.init()
        loadLaunchOnStartupSetting()
    }

    private func loadLaunchOnStartupSetting() {
        isEnabled = userDefaults.bool(forKey: launchOnStartupKey)
        logger.info("Loaded launch on startup setting: \(self.isEnabled)")
    }

    func setLaunchOnStartup(_ enabled: Bool) {
        do {
            if enabled {
                // Register app to launch on startup
                try SMAppService.mainApp.register()
                userDefaults.setValue(true, forKey: launchOnStartupKey)
                logger.info("✓ App registered to launch on startup")
            } else {
                // Unregister app from launch on startup
                try SMAppService.mainApp.unregister()
                userDefaults.setValue(false, forKey: launchOnStartupKey)
                logger.info("✓ App unregistered from launch on startup")
            }

            DispatchQueue.main.async {
                self.isEnabled = enabled
            }
        } catch {
            logger.error("Failed to update launch on startup: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.isEnabled = !enabled  // Revert on failure
            }
        }
    }
}

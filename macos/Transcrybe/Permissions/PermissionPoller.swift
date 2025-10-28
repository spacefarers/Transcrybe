//
//  PermissionPoller.swift
//  Transcrybe
//
//  Unified permission polling utility
//

import Foundation
import ApplicationServices

class PermissionPoller {
    /// Poll for accessibility trust with configurable attempts and interval
    static func pollAccessibilityTrust(
        maxAttempts: Int = 60,
        interval: TimeInterval = 0.5,
        completion: @escaping (Bool) -> Void
    ) {
        var attempts = 0
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            attempts += 1
            let trusted = PermissionChecker.isAccessibilityTrusted()
            if trusted || attempts >= maxAttempts {
                timer.invalidate()
                DispatchQueue.main.async {
                    completion(trusted)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }
}

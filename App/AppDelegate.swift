//
//  AppDelegate.swift
//  GeminiDesktop
//

import AppKit
    
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .openMainWindow, object: nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.panelX.rawValue)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.panelY.rawValue)
    }
}

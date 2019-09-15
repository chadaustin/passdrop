//
//  PassDropAppDelegate.swift
//  PassDrop
//
//  Created by Rudis Muiznieks on 1/30/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

import UIKit
import SwiftyDropbox

@UIApplicationMain
@objc(PassDropAppDelegate)
class PassDropAppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?
    @objc dynamic var navigationController: UINavigationController!
    @objc var splitController: MGSplitViewController?

    @objc var prefs: AppPrefs!
    @objc var dbManager: DatabaseManager!

    var bgTimer: Date?
    var isLocked = false

    var hide: HideViewController!
    
    @objc dynamic var rootView: RootViewController!

    var settingsView: SettingsViewController?
    
    // MARK: Application lifecycle
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Override point for customization after application launch.
        prefs = AppPrefs()
        prefs.load()
        
        DropboxClientsManager.setupWithAppKey(Globals.DROPBOX_KEY)
        
        dbManager = DatabaseManager()
        // If there is no linked DropboxClient, then clear the database.
        if DropboxClientsManager.authorizedClient == nil {
            dbManager.dropboxWasReset()
        }
        
        // Add the navigation controller's view to the window and display.
        if UIDevice.current.userInterfaceIdiom == .pad {
            splitController?.showsMasterInLandscape = true
            splitController?.showsMasterInPortrait = true
            window?.rootViewController = splitController
        } else {
            window?.rootViewController = navigationController
        }
        window?.makeKeyAndVisible()
        
        isLocked = true
        bgTimer = nil
        hide = HideViewController(nibName: "HideScreenView", bundle: nil)
        
        return true
    }
    
    func dropboxWasReset() {
        dbManager.dropboxWasReset()
        rootView.dropboxWasReset()
    }

    func applicationWillResignActive(_ application: UIApplication) {
        /*
         Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
         Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
         */
        let isHidden = navigationController.topViewController == hide || splitController?.presentedViewController == hide
        if !isHidden && dbManager.activeDatabase != nil && prefs.lockInBackgroundSeconds >= 0 {
            bgTimer = Date()
            if UIDevice.current.userInterfaceIdiom == .pad {
                let details = (splitController?.detailViewController as! UINavigationController).viewControllers
                if details.count > 1 {
                    if details[1].responds(to: #selector(EditGroupViewController.hideKeyboard)) {
                        details[1].performSelector(onMainThread: #selector(EditGroupViewController.hideKeyboard), with: nil, waitUntilDone: true)
                    }
                }
                splitController?.present(hide, animated: false, completion: nil)
            } else {
                navigationController.dismiss(animated: false, completion: nil)
                navigationController.pushViewController(hide, animated: false)
                navigationController.setNavigationBarHidden(true, animated: false)
            }
        }
    }
    
    func userUnlockedDatabase(_ database: Database) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            splitController?.dismiss(animated: false, completion: nil)
        } else {
            if navigationController.topViewController == hide {
                navigationController.popViewController(animated: false)
                navigationController.setNavigationBarHidden(false, animated: false)
            }
        }
    }
    
    func userClosedPasswordModal(_ database: Database) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            (splitController?.detailViewController as! UINavigationController).popToRootViewController(animated: false)
            rootView.navigationController?.popToRootViewController(animated: false)
            rootView.navigationController?.view.alpha = 1.0
            splitController?.dismiss(animated: false, completion: nil)
            dbManager.activeDatabase = nil
            rootView.removeLock(database)
        } else {
            if navigationController.topViewController == hide {
                navigationController.popViewController(animated: false)
                navigationController.setNavigationBarHidden(false, animated: false)
            }
            navigationController.popToRootViewController(animated: false)
            dbManager.activeDatabase = nil
            rootView.removeLock(database)
        }
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if let authResult = DropboxClientsManager.handleRedirectURL(url) {
            settingsView?.updateSettingsUI()
            switch authResult {
            case .success:
                NSLog("App linked successfully!")
            case .cancel:
                NSLog("Dropbox authentication flow cancelled")
            case .error(_, let description):
                NSLog("Failed to authenticate with Dropbox", description)
            }
            return true
        }
        return false
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        /*
         Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
         */
        if bgTimer != nil {
            let diff = fabs(bgTimer!.timeIntervalSinceNow)
            //[navigationController dismissModalViewControllerAnimated:NO];
            if diff > Double(prefs.lockInBackgroundSeconds) {
                showPasswordPrompt(message: nil)
            } else {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    splitController?.dismiss(animated: false, completion: nil)
                } else {
                    if navigationController.topViewController == hide {
                        navigationController.popViewController(animated: false)
                        navigationController.setNavigationBarHidden(false, animated: false)
                    }
                }
            }
            bgTimer = nil
        }
        
        if prefs.autoClearClipboard {
            UIPasteboard.general.string = ""
        }

        settingsView?.updateSettingsUI()
    }
    
    func showPasswordPrompt(message: String?) {
        let dialog = UIAlertController(title: "Enter Password", message: message, preferredStyle: .alert)
        dialog.addTextField { textField in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
        }
        dialog.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            guard let ss = self else { return }
            guard let activeDatabase = ss.dbManager.activeDatabase else { return }
            ss.userClosedPasswordModal(activeDatabase)
        })
        dialog.addAction(UIAlertAction(title: "Unlock", style: .default) { [weak self] _ in
            guard let ss = self else { return }
            guard let activeDatabase = ss.dbManager.activeDatabase else { return }
            let password = dialog.textFields?[0].text ?? ""
            if !password.isEmpty {
                if activeDatabase.load(withPassword: password) {
                    ss.userUnlockedDatabase(activeDatabase)
                } else {
                    ss.showPasswordPrompt(message: "Please try again.")
                }
            } else {
                ss.showPasswordPrompt(message: "You must enter the password.")
            }
        })
        self.rootView.present(dialog, animated: true)
    }
}

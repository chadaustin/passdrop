//
//  SettingsView.swift
//  PassDrop
//
//  Created by Rudis Muiznieks on 1/30/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

import UIKit
import SwiftyDropbox

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet var settingsTable: UITableView!
    var autoClearSwitch: UISwitch!
    var ignoreBackupSwitch: UISwitch!
    var aboutView: UIViewController!

    // MARK: view lifecycle
    
    // Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
    override func viewDidLoad() {
        let app = UIApplication.shared.delegate as! PassDropAppDelegate
        autoClearSwitch = UISwitch()
        ignoreBackupSwitch = UISwitch()
        
        autoClearSwitch.setOn(app.prefs.autoClearClipboard, animated: false)
        autoClearSwitch.addTarget(self, action: #selector(openLastSwitched), for: .valueChanged)
        
        ignoreBackupSwitch.setOn(app.prefs.ignoreBackup, animated: false)
        ignoreBackupSwitch.addTarget(self, action: #selector(ignoreBackupSwitched), for: .valueChanged)

        aboutView = AboutViewController()
        aboutView.title = "About"
        
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let app = UIApplication.shared.delegate as! PassDropAppDelegate
        app.settingsView = self
        super.viewDidAppear(animated)
        updateSettingsUI()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        let app = UIApplication.shared.delegate as! PassDropAppDelegate
        app.settingsView = nil
    }
    
    // MARK: ui actions
    
    @IBAction
    func dbButtonClicked() {
        if DropboxClientsManager.authorizedClient != nil {
            let unlinkConfirm = UIAlertController(title: "Unlink Dropbox", message: "Are you sure you want to unlink your Dropbox account? This will also remove all databases from your device.", preferredStyle: .alert)
            unlinkConfirm.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            unlinkConfirm.addAction(UIAlertAction(title: "Unlink Dropbox", style: .destructive) { [weak self] _ in
                let app = UIApplication.shared.delegate as! PassDropAppDelegate
                DropboxClientsManager.unlinkClients()
                app.dropboxWasReset()
                self?.updateSettingsUI()
            })
            present(unlinkConfirm, animated: true)
        } else {
            DropboxClientsManager.authorizeFromController(
                UIApplication.shared,
                controller: UIApplication.shared.keyWindow?.rootViewController
            ) { url in
                UIApplication.shared.openURL(url)
            }
        }
    }

    func updateSettingsUI() {
        settingsTable.reloadData()
    }

    @objc func openLastSwitched() {
        let app = UIApplication.shared.delegate as! PassDropAppDelegate
        app.prefs.autoClearClipboard = autoClearSwitch.isOn
        app.prefs.save()
    }
    
    @objc func ignoreBackupSwitched() {
        let app = UIApplication.shared.delegate as! PassDropAppDelegate
        app.prefs.ignoreBackup = ignoreBackupSwitch.isOn
        app.prefs.save()
    }

    // MARK: dropbox delegate
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    // MARK: table delegate
   
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Database Sources"
        case 1:
            return "PassDrop Settings"
        case 2:
            return nil
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1
        case 1: return 4
        case 2: return 1
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            dbButtonClicked()
            break;
        case 1:
            switch indexPath.row {
            case 2:
                // clear clipboard
                break;
            case 0:
                // lock in background
                let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

                let times = ["Immediately", "10 secs", "30 secs", "1 min", "5 mins", "10 mins", "30 mins", "1 hour", "2 hours", "Never"]
                for (buttonIndex, name) in times.enumerated() {
                    actionSheet.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                        guard let ss = self else { return }
                        let app = UIApplication.shared.delegate as! PassDropAppDelegate
                        app.prefs.lockInBackgroundSeconds = ss.convertArrayTimesIndexToSeconds(buttonIndex)
                        app.prefs.save()
                        ss.updateSettingsUI()
                    })
                }

                actionSheet.popoverPresentationController?.sourceView = view
                actionSheet.popoverPresentationController?.sourceRect = tableView.cellForRow(at: indexPath)!.frame
                
                present(actionSheet, animated: true)
                break
            case 1:
                let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                
                for (buttonIndex, name) in ["Writable", "Read Only", "Always Ask"].enumerated() {
                    actionSheet.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                        let app = UIApplication.shared.delegate as! PassDropAppDelegate
                        app.prefs.databaseOpenMode = buttonIndex
                        app.prefs.save()
                        self?.updateSettingsUI()
                    })
                }
                
                actionSheet.popoverPresentationController?.sourceView = view
                actionSheet.popoverPresentationController?.sourceRect = tableView.cellForRow(at: indexPath)!.frame
                
                present(actionSheet, animated: true)
                break
            case 4:
                // ignore backups
                break
            default:
                break
            }
            break;
        case 2:
            // show about screen
            navigationController?.pushViewController(aboutView, animated: true)
            break
        default:
            break
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: table data source
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        struct Static {
            static let cellIdentifier = "Cell"
            static let switchCellIdentifier = "SwitchCell"
            static let valueCellIdentifier = "ValueCell"
        }
        
        var cell: UITableViewCell!
        let app = UIApplication.shared.delegate as! PassDropAppDelegate
        
        if indexPath.section == 0 || (indexPath.section == 1 && indexPath.row < 2) {
            cell = tableView.dequeueReusableCell(withIdentifier: Static.valueCellIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .value1, reuseIdentifier: Static.valueCellIdentifier)
            }
            cell.accessoryType = .none
            if indexPath.section == 0 {
                cell.textLabel?.text = "Dropbox"
                if DropboxClientsManager.authorizedClient != nil {
                    cell.detailTextLabel?.text = "Linked"
                } else {
                    cell.detailTextLabel?.text = "Not Linked"
                }
            } else {
                switch indexPath.row {
                case 0:
                    cell.textLabel?.text = "Lock In Background"
                    cell.detailTextLabel?.text = convertSecondsToString(app.prefs.lockInBackgroundSeconds)
                    break;
                case 1:
                    cell.textLabel?.text = "Open Databases"
                    cell.detailTextLabel?.text = openModeStringForMode(app.prefs.databaseOpenMode)
                    break;
                default:
                    break
                }
            }
        } else if indexPath.section == 1 && (indexPath.row == 2 || indexPath.row == 3) {
            cell = tableView.dequeueReusableCell(withIdentifier: Static.switchCellIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .default, reuseIdentifier: Static.switchCellIdentifier)
                cell.selectionStyle = .none
            }
            if indexPath.row == 2 {
                cell.textLabel?.text = "Auto-Clear Clipboard"
                cell.accessoryView = autoClearSwitch
            } else {
                cell.textLabel?.text = "Search Ignores Backup"
                cell.accessoryView = ignoreBackupSwitch
            }
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: Static.cellIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .default, reuseIdentifier: Static.cellIdentifier)
            }
            cell.textLabel?.text = "About PassDrop"
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }

    // MARK: pref data conversion helpers
    
    func openModeStringForMode(_ openMode: Int) -> String? {
        switch Int32(openMode) {
        case kOpenModeWritable: return "Writable"
        case kOpenModeReadOnly: return "Read Only"
        case kOpenModeAlwaysAsk: return "Always Ask"
        default: return nil
        }
    }

    func convertArrayTimesIndexToSeconds(_ index: Int) -> NSInteger {
        switch index {
        case 0:
            return 0;
        case 1:
            return 10;
        case 2:
            return 30;
        case 3:
            return 60;
        case 4:
            return 300;
        case 5:
            return 600;
        case 6:
            return 1800;
        case 7:
            return 3600;
        case 8:
            return 7200;
        default:
            return -1
        }
    }
    
    func convertSecondsToString(_ seconds: Int) -> String {
        switch seconds {
        case -1:
            return "Never";
        case 0:
            return "Immediately";
        case 10:
            return "10 secs";
        case 30:
            return "30 secs";
        case 60:
            return "1 min";
        case 300:
            return "5 mins";
        case 600:
            return "10 mins";
        case 1800:
            return "30 mins";
        case 3600:
            return "1 hour";
        case 7200:
            return "2 hours";
        default:
            return String(format: "%d secs", seconds)
        }
    }

}

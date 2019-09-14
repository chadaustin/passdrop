//
//  RootViewController.swift
//  PassDrop
//
//  Created by Rudis Muiznieks on 1/30/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

import UIKit
import SwiftyDropbox

@objc(RootViewController)
class RootViewController: NetworkActivityViewController, DatabaseManagerDelegate, DatabaseDelegate, UITableViewDataSource, UITableViewDelegate {
    
    var settingsView: SettingsViewController!
    var dbManager: DatabaseManager!
    var dbRootView: DropboxBrowserController?
    var extraRows: Int = 0
    var loadingDb: Database!
    var tutorialShown: Bool = false
    
    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
            
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        self.navigationItem.rightBarButtonItem = self.editButtonItem
        self.title = "Databases"
        
        dbManager = app.dbManager
        dbManager.delegate = self
 
        settingsView = SettingsViewController()
        settingsView.title = "Settings"

        let settingsButtonItem = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(settingsButtonClicked))
        navigationItem.leftBarButtonItem = settingsButtonItem
        
        extraRows = 0
        tutorialShown = false
    }
    
    var app: PassDropAppDelegate {
        return UIApplication.shared.delegate as! PassDropAppDelegate
    }
    
    // hack to fix weird bug with the leftbarbuttonitems disappearing
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            let sb = navigationItem.leftBarButtonItem!
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: sb.title, style: sb.style, target: sb.target, action: sb.action)
        }
    }
    
    var dropboxIsLinked: Bool {
        return DropboxClientsManager.authorizedClient != nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.rightBarButtonItem?.isEnabled = dropboxIsLinked
        self.view.viewWithTag(1)?.isHidden = dropboxIsLinked
        
        // hack to fix issue with disappearing insert/delete control icons
        if tableView.isEditing {
            tableView.setEditing(false, animated: false)
            tableView.setEditing(true, animated: false)
        } else {
            tableView.reloadData()
        }
        navigationController?.setToolbarHidden(true, animated: animated)
    }

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if app.prefs.firstLoad && tutorialShown == false {
            app.prefs.save() // sets version
            tutorialShown = false
            if dbManager.databases.count == 0 {
                if !dropboxIsLinked {
                    let helpView = UIAlertController(title: "Tutorial", message: "Welcome to PassDrop! Since this is your first time using PassDrop, you will need enter your Dropbox credentials on the settings screen.", preferredStyle: .alert)
                    helpView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                    helpView.addAction(UIAlertAction(title: "Settings", style: .default) { [weak self] _ in
                        self?.settingsButtonClicked()
                        self?.tutorialShown = false
                    })
                    present(helpView, animated: true)
                } else {
                    let helpView = UIAlertController(title: "Tutorial", message: "Now that you have linked your Dropbox account, you need to create or choose a KeePass 1.x database to use with PassDrop.", preferredStyle: .alert)
                    helpView.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                    helpView.addAction(UIAlertAction(title: "Dropbox", style: .default) { [weak self] _ in
                        self?.gotoDropbox()
                        self?.tutorialShown = false
                    })
                    present(helpView, animated: true)
                }
            }
        }
        navigationController?.setToolbarHidden(true, animated: false)
    }

    override func viewDidDisappear(_ animated: Bool) {
        if tableView.isEditing {
            setEditing(false, animated: false)
        }
        super.viewDidDisappear(animated)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    override var shouldAutorotate: Bool {
        return true
    }

    // MARK: Subview Handling
    
    var tableView: UITableView {
        return view.viewWithTag(10) as! UITableView
    }
    
    // MARK: Actions
    
    @objc func settingsButtonClicked() {
        navigationController?.pushViewController(settingsView, animated: true)
    }
    
    func gotoDropbox() {
        if !dropboxIsLinked {
            let notified = UIAlertController(title: "Dropbox Not Linked", message: "Before you can add databases, you must link your Dropbox account from the settings screen. Do you want to do that now?", preferredStyle: .alert)
            notified.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            notified.addAction(UIAlertAction(title: "Settings", style: .default) { [weak self] _ in
                self?.settingsButtonClicked()
                self?.tutorialShown = false;
            })
            present(notified, animated: true)
        } else {
            if dbRootView == nil {
                dbRootView = DropboxBrowserController(path: "")
                dbRootView!.dbManager = dbManager
                dbRootView!.title = "Dropbox"
            }
            navigationController?.pushViewController(dbRootView!, animated: true)
        }
    }

    func databaseWasAdded(_ databaseName: String) {
        app.prefs.firstLoad = false
        app.prefs.save()
        while navigationController!.viewControllers.count > 1 {
            navigationController?.popViewController(animated: false)
        }
        tableView.insertRows(at: [IndexPath(row: dbManager.databases.count - 1, section: 0)], with: .fade)
    }
    
    func dropboxWasReset() {
        tableView.reloadData()
        dbRootView?.reset()
    }
    
    func removeLock(_ database: Database) {
        if !database.isReadOnly {
            self.loadingMessage = "Unlocking"
            self.networkRequestStarted()
            database.delegate = self
            database.removeLock()
        }
    }
    
    // MARK: Table view data source
    
    // Customize the number of sections in the table view.
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    // Customize the number of rows in the table view.
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dbManager.databases.count + extraRows
    }

    let kDatabaseName = "name"
    static let cellIdentifier = "Cell"
    
    // Customize the appearance of table view cells.
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        switch tableView.dequeueReusableCell(withIdentifier: RootViewController.cellIdentifier) {
        case .some(let c):
            cell = c
        case .none:
            cell = UITableViewCell(style: .default, reuseIdentifier: RootViewController.cellIdentifier)
        }
        
        if tableView.isEditing && indexPath.row == dbManager.databases.count {
            cell.imageView?.image = nil
            cell.accessoryType = .none
            cell.textLabel?.text = "Add Database"
        } else if indexPath.row < dbManager.databases.count {
            cell.imageView?.image = UIImage(named: "keepass_icon.png")
            cell.accessoryType = .disclosureIndicator
            cell.textLabel?.text = dbManager.databases[indexPath.row][kDatabaseName] as? String
        }
        
        return cell;
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        if indexPath.row == dbManager.databases.count {
            return .insert
        }
        return .delete
    }
    
    func tableView(_ tableView: UITableView, willBeginEditingRowAt willBeginEditingRowAtIndexPath: IndexPath) -> Void {
    }
    
    func tableView(_ tableView: UITableView, didEndEditingRowAt didEndEditingRowAtIndexPath: IndexPath?) -> Void {
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        if tableView.isEditing && extraRows == 0 {
            tableView.setEditing(false, animated: true)
            super.setEditing(false, animated: true)
        }
        tableView.setEditing(editing, animated: animated)
        super.setEditing(editing, animated: animated)
        tableView.allowsSelectionDuringEditing = true
        let paths = [IndexPath(row: dbManager.databases.count, section: 0)]
        if editing {
            extraRows = 1
            tableView.insertRows(at: paths, with: .fade)
        } else {
            extraRows = 0
            tableView.deleteRows(at: paths, with: .fade)
        }
    }

    // Override to support editing the table view.
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if dbManager.getDatabaseAtIndex(indexPath.row).isDirty {
                let deleteSheet = UIAlertController(title: "You have unsaved changes to this database that haven't been synced to Dropbox yet. Are you sure you want to delete it?", message: nil, preferredStyle: .actionSheet)
                deleteSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                deleteSheet.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
                    self?.dbManager.deleteDatabaseAtIndex(indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                })
                
                deleteSheet.popoverPresentationController?.sourceView = view
                deleteSheet.popoverPresentationController?.sourceRect = tableView.cellForRow(at: indexPath)!.frame

                present(deleteSheet, animated: true)
            } else {
                dbManager.deleteDatabaseAtIndex(indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
        }
        else if editingStyle == .insert {
            gotoDropbox()
        }
    }
    
    func tableView(
        _ tableView: UITableView,
        targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
        toProposedIndexPath proposedDestinationIndexPath: IndexPath
    ) -> IndexPath {
        if proposedDestinationIndexPath.row < dbManager.databases.count {
            return proposedDestinationIndexPath
        }
        return IndexPath(row: dbManager.databases.count - 1, section: 0)
    }
    
    // Override to support rearranging the table view.
    func tableView(
        _ tableView: UITableView,
        moveRowAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath
    ) {
        dbManager.moveDatabaseAtIndex(sourceIndexPath.row, toIndex: destinationIndexPath.row)
    }
    
    // Override to support conditional rearranging of the table view.
    func tableView(
        _ tableView: UITableView,
        canMoveRowAt indexPath: IndexPath
    ) -> Bool {
        // Return NO if you do not want the item to be re-orderable.
        if indexPath.row < dbManager.databases.count {
            return true
        }
        return false
    }
    
    // MARK: Table view delegate

    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        if tableView.cellForRow(at: indexPath)!.isEditing {
            if indexPath.row < dbManager.databases.count {
                let detailViewController = EditDatabaseViewController(nibName: "EditDatabaseViewController", bundle: nil)
                detailViewController.database = dbManager.getDatabaseAtIndex(indexPath.row)
                detailViewController.title = "Details"
                navigationController?.pushViewController(detailViewController, animated: true)
            } else {
                gotoDropbox()
            }
        } else {
            self.loadingDb = dbManager.getDatabaseAtIndex(indexPath.row)
            self.loadingDb.delegate = self
            
            switch(Int32(app.prefs.databaseOpenMode)){
            case kOpenModeReadOnly:
                self.loadingDb.isReadOnly = true
                self.completeLoad()
                break;
            case kOpenModeWritable:
                self.completeLoad()
                break;
            case kOpenModeAlwaysAsk:
                let openMode = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
                openMode.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                openMode.addAction(UIAlertAction(title: "Open Read-Only", style: .default) { [weak self] _ in
                    self?.loadingDb.isReadOnly = true
                    self?.completeLoad()
                })
                openMode.addAction(UIAlertAction(title: "Open Writable", style: .default) { [weak self] _ in
                    self?.completeLoad()
                })
                
                openMode.popoverPresentationController?.sourceView = view
                openMode.popoverPresentationController?.sourceRect = tableView.cellForRow(at: indexPath)!.frame
                
                present(openMode, animated: true)
                break;
            default:
                break
            }
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func completeLoad() {
        loadingMessage = "Updating"
        self.networkRequestStarted()
        self.loadingDb.update()
    }
    
    // MARK: database delegate
    
    func databaseWasLocked(forEditing database: Database!) {
        database.dbManager.activeDatabase = database // set the active database
        networkRequestStopped()
        let gvc = KdbGroupViewController(nibName: "KdbGroupViewController", bundle: nil)
        gvc.kdbGroup = database.rootGroup()
        gvc.title = database.name
        self.navigationController?.pushViewController(gvc, animated: true)
    }
    
    func databaseWasAlreadyLocked(_ database: Database!) {
        networkRequestStopped()
        
        let sheet = UIAlertController(title: "This database has already been locked by another process.", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.addAction(UIAlertAction(title: "Recover Lock", style: .destructive) { [weak self] _ in
            guard let ss = self else { return }
            ss.databaseWasLocked(forEditing: ss.loadingDb)
        })
        sheet.addAction(UIAlertAction(title: "Open Read-Only", style: .default) { [weak self] _ in
            guard let ss = self else { return }
            ss.loadingDb.isReadOnly = true
            ss.databaseWasLocked(forEditing: ss.loadingDb)
        })
        
        let row = dbManager.getIndexOfDatabase(database)
        if row >= 0 {
            sheet.popoverPresentationController?.sourceView = view
            sheet.popoverPresentationController?.sourceRect = tableView.cellForRow(at: IndexPath(row: row, section: 0))!.frame
        }
        
        present(sheet, animated: true)
    }
    
    func database(_ database: Database!, failedToLockWithReason reason: String!) {
        networkRequestStopped()
        let alert = UIAlertController(title: "Error", message: reason, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Okay", style: .cancel))
        present(alert, animated: true)
    }
    
    func databaseUpdateComplete(_ database: Database!) {
        networkRequestStopped()
        let unlocking: Database = database
        
        let dialog = UIAlertController(title: "Enter Password", message: nil, preferredStyle: .alert)
        dialog.addTextField { textField in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
        }
        dialog.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        dialog.addAction(UIAlertAction(title: "Unlock", style: .default) { [weak self] _ in
            let password = dialog.textFields?[0].text ?? ""
            if password != "" {
                if unlocking.load(withPassword: password) {
                    self?.userUnlockedDatabase(unlocking)
                } else {
                    let alert = UIAlertController(title: "Error", message: unlocking.lastError(), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Okay", style: .cancel))
                    self?.present(alert, animated: true)
                }
            } else {
                let alert = UIAlertController(title: "Error", message: "You must enter your password.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Okay", style: .cancel))
                self?.present(alert, animated: true)
            }
        })
        present(dialog, animated: true)
    }

    func databaseUpdateWouldOverwriteChanges(_ database: Database!) {
        networkRequestStopped()
        let unlocking: Database = database
        let alert = UIAlertController(title: "Update Cancelled", message: "The database on Dropbox has changes that would overwrite changes in your local copy. Open the database in writable mode and use the sync button to choose which copy to keep.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Okay", style: .cancel) { [weak self] _ in
            self?.databaseUpdateComplete(unlocking)
        })
        present(alert, animated: true)
    }
    
    func databaseWasDeleted(_ database: Database!) {
        networkRequestStopped()
        let sheet = UIAlertController(title: "This database has been deleted from your Dropbox account. What would you like to do?", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.addAction(UIAlertAction(title: "Open Local Copy", style: .default) { [weak self] _ in
            guard let ss = self else { return }
            ss.databaseUpdateComplete(ss.loadingDb)
        })

        let row = dbManager.getIndexOfDatabase(database)
        if row >= 0 {
            sheet.popoverPresentationController?.sourceView = view
            sheet.popoverPresentationController?.sourceRect = tableView.cellForRow(at: IndexPath(row: row, section: 0))!.frame
        }
        
        present(sheet, animated: true)
    }
    
    func database(_ database: Database!, updateFailedWithReason error: String!) {
        networkRequestStopped()

        let openMode = UIAlertController(title: error, message: nil, preferredStyle: .actionSheet)
        openMode.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        openMode.addAction(UIAlertAction(title: "Read Local Copy", style: .default) { [weak self] _ in
            guard let ss = self else { return }
            ss.loadingDb.isReadOnly = true
            ss.databaseUpdateComplete(ss.loadingDb)
        })
        
        let row = dbManager.getIndexOfDatabase(database)
        if row >= 0 {
            openMode.popoverPresentationController?.sourceView = view
            openMode.popoverPresentationController?.sourceRect = tableView.cellForRow(at: IndexPath(row: row, section: 0))!.frame
        }
        present(openMode, animated: true)
    }
    
    func databaseLockWasRemoved(_ database: Database!) {
        networkRequestStopped()
    }
    
    func database(_ database: Database!, failedToRemoveLockWithReason reason: String!) {
        networkRequestStopped()
        let error = UIAlertController(title: "Error", message: "The database lock was missing. It's possible that another instance recovered the lock and removed it already.", preferredStyle: .alert)
        error.addAction(UIAlertAction(title: "Okay", style: .cancel))
        present(error, animated: true)
    }
    
    // MARK: EnterPasswordDelegate
    
    func userUnlockedDatabase(_ database: Database) {
        if !database.isReadOnly {
            loadingMessage = "Locking"
            networkRequestStarted()
            
            loadingDb = database
            loadingDb.lockForEditing()
        } else {
            databaseWasLocked(forEditing: database)
        }
    }

}


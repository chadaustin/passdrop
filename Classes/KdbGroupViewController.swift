//
//  KdbGroupViewController.swift
//  PassDrop
//
//  Created by Rudis Muiznieks on 2/7/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

import UIKit

class KdbGroupViewController: NetworkActivityViewController, DatabaseDelegate,
        UITableViewDataSource, UITableViewDelegate, UISearchDisplayDelegate, UIAlertViewDelegate,
        UIActionSheetDelegate, UINavigationControllerDelegate {
    var kdbGroup: KdbGroup!
    var searchResults: NSMutableArray?
    var savedSearchTerm: String?
    var extraRows: Int = 0
    var extraSections: Int = 0
    var isDirty: Bool = false
    
    deinit {
        searchDisplayController?.delegate = nil
        searchDisplayController?.searchResultsDelegate = nil
        searchDisplayController?.searchResultsDataSource = nil
    }
    
    var app: PassDropAppDelegate {
        return UIApplication.shared.delegate as! PassDropAppDelegate
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if !kdbGroup.database.isReadOnly {
            self.navigationItem.rightBarButtonItem = self.editButtonItem
        }
        
        if kdbGroup.isRoot {
            let backButton = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(removeLock))
            self.navigationItem.leftBarButtonItem = backButton
        }
        //self.tableView.contentOffset = CGPointMake(0, self.searchDisplayController.searchBar.frame.size.height);
        perform(#selector(hideSearchBar), with: nil, afterDelay: 0.0)
        tableView.alwaysBounceVertical = true

        if let sst = self.savedSearchTerm {
            self.searchDisplayController?.searchBar.text = sst
        }
        
        extraRows = 0
        extraSections = 0
        isDirty = false

        let fspace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let syncButton = UIBarButtonItem(title: "Sync", style: .done, target: self, action: #selector(syncButtonClicked))
        syncButton.tintColor = UIColor(red: 0, green: 0.75, blue: 0, alpha: 1)

        self.navigationController?.toolbar.tintColor = .black
        self.setToolbarItems([fspace, syncButton], animated: false)
    }
    
    @objc
    func hideSearchBar() {
        tableView.contentOffset = CGPoint(x: 0, y: tableView.contentOffset.y + 44.0)
        //self.searchDisplayController.searchBar.frame.size.height);
    }

    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    override func viewWillAppear(_ animated: Bool) {
        tableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if kdbGroup.database.isDirty && !kdbGroup.database.isReadOnly && !self.isEditing {
            showSyncButton()
        }
        navigationController?.delegate = self
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        navigationController?.delegate = nil
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if UIDevice.current.userInterfaceIdiom == .pad && animated == true {
            // close the currently viewed entry when user moves between groups (animated is false when fg/bg swapping)
            (app.splitController?.detailViewController as? UINavigationController)?.popToRootViewController(animated: false)
        }
        navigationController.delegate = nil
    }
    
    @objc
    func removeLock() {
        navigationController?.setToolbarHidden(true, animated: false)
        if !kdbGroup.database.isReadOnly {
            loadingMessage = "Unlocking"
            networkRequestStarted()
            kdbGroup.database.delegate = self
            kdbGroup.database.removeLock()
        } else {
            databaseLockWasRemoved(kdbGroup.database)
        }
    }
    
    // MARK: Sync button stuff
    
    func showSyncButton() {
        navigationController?.setToolbarHidden(false, animated: true)
    }

    func hideSyncButton() {
        navigationController?.setToolbarHidden(true, animated: true)
    }

    @objc
    func syncButtonClicked(_ sender: Any?) {
        let syncSheet = UIActionSheet(title: "You have local changes that haven't been synced to Dropbox yet.", delegate: self, cancelButtonTitle: "Cancel", destructiveButtonTitle: "Discard Changes", otherButtonTitles: "Upload to Dropbox")
        syncSheet.tag = 1
        //[syncSheet showInView:self.view];
        syncSheet.show(from: sender as! UIBarButtonItem, animated: true)
    }
    
    func actionSheet(_ actionSheet: UIActionSheet, didDismissWithButtonIndex buttonIndex: Int) {
        if actionSheet.tag == 1 {
            switch buttonIndex {
            case 0: // revert
                let confirm = UIAlertView(title: "Revert Changes", message: "The database will now close. The next time you open it, a fresh copy will be retrieved from Dropbox. Continue?", delegate: self, cancelButtonTitle: "Cancel", otherButtonTitles: "Okay")
                confirm.tag = 2
                confirm.show()
                break;
            case 2: // upload
                self.loadingMessage = "Uploading"
                networkRequestStarted()
                kdbGroup.database.savingDelegate = self
                kdbGroup.database.sync(withForce: false)
                break;
            case 1: // cancel
                showSyncButton()
                break;
            default:
                break
            }
        } else if actionSheet.tag == 2 {
            if buttonIndex == 0 {
                networkRequestStarted()
                kdbGroup.database.sync(withForce: true)
            } else {
                showSyncButton()
            }
        }
    }
    
    func pushNewDetailsView(_ newView: UIViewController, disableMaster: Bool) {
        if let newView = newView as? EditGroupViewController {
            newView.masterView = self
        }
        if let newView = newView as? EditEntryViewController {
            newView.masterView = self
        }
        if UIDevice.current.userInterfaceIdiom == .pad {
            let nc = app.splitController?.detailViewController as? UINavigationController
            nc?.popToRootViewController(animated: false)
            nc?.pushViewController(newView, animated: false)
            if disableMaster {
                navigationController?.view.isUserInteractionEnabled = false
                UIView.beginAnimations(nil, context: nil)
                navigationController?.view.alpha = 0.5
                UIView.setAnimationDuration(0.3)
                UIView.commitAnimations()
            }
        } else {
            navigationController?.pushViewController(newView, animated: true)
        }
    }

    // MARK: Edit mode stuff

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if extraRows > 0 && indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1 {
            return .insert
        }
        return .delete
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !kdbGroup.database.isReadOnly
    }
    
    func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
    }
    
    func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        let offset = tableView.contentOffset
        tableView.setEditing(editing, animated: animated)
        super.setEditing(editing, animated: animated)
        tableView.allowsSelectionDuringEditing = true
        var paths: [IndexPath]
        if !kdbGroup.isRoot {
            paths = [
                IndexPath(row: kdbGroup.subGroups.count, section: 0),
                IndexPath(row: kdbGroup.entries.count, section: 1) ]
        } else {
            paths = [
                IndexPath(row: kdbGroup.subGroups.count, section: 0) ]
        }
        if editing {
            hideSyncButton()
            if kdbGroup.subGroups.count == 0 {
                extraSections += 1
                tableView.insertSections(IndexSet(integer: 0), with: .fade)
            }
            if kdbGroup.entries.count == 0 && !kdbGroup.isRoot {
                extraSections += 1
                tableView.insertSections(IndexSet(integer: 1), with: .fade)
            }
            extraRows = 1
            tableView.insertRows(at: paths, with: .fade)
        } else {
            extraRows = 0
            tableView.deleteRows(at: paths, with: .fade)

            var entrySection = 1
            if kdbGroup.subGroups.count == 0 {
                extraSections -= 1
                tableView.deleteSections(IndexSet(integer: 0), with: .fade)
                entrySection = 0
            }
            if kdbGroup.isRoot == false {
                if kdbGroup.entries.count == 0 {
                    extraSections -= 1
                    tableView.deleteSections(IndexSet(integer: entrySection), with: .fade)
                }
                extraSections = 0
            }
            if isDirty == true {
                self.loadingMessage = "Saving"
                networkRequestStarted()
                
                kdbGroup.database.savingDelegate = self
                kdbGroup.database.save()
            }
            if kdbGroup.database.isDirty {
                showSyncButton()
            }
        }
        self.tableView.contentOffset = offset
    }
    
    func databaseSaveComplete(_ database: Database!) {
        networkRequestStopped()
        isDirty = false
        if !self.isEditing {
            showSyncButton()
        }
    }
    
    func database(_ database: Database!, saveFailedWithReason error: String!) {
        networkRequestStopped()
        setWorking(false)
        let saveError = UIAlertView(title: "Save Failed", message: error, delegate: self, cancelButtonTitle: "Cancel")
        saveError.tag = 4
        saveError.show()
    }
    
    func alertView(_ alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
        if alertView.tag == 2 {
            if buttonIndex == 1 {
                // reverting changes
                kdbGroup.database.discardChanges()
                removeLock()
            } else {
                showSyncButton()
            }
        }
    }
    
    // Override to support editing the table view.
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        var save = true
        if editingStyle == .delete {
            tableView.beginUpdates()
            if indexPath.section == 0 && (kdbGroup.subGroups.count > 0 || self.isEditing) {
                if (kdbGroup.subGroups.count > 0 && !kdbGroup.isRoot) || (kdbGroup.subGroups.count > 1 && kdbGroup.isRoot) {
                    // delete group
                    kdbGroup.delete(at: Int32(indexPath.row))
                    tableView.deleteRows(at: [indexPath], with: .fade)
                    if kdbGroup.subGroups.count == 0 {
                        if self.isEditing {
                            extraSections += 1 // if it was the last group we need to keep the group section in edit mode
                        } else {
                            tableView.deleteSections(IndexSet(integer: indexPath.section), with: .fade)
                        }
                    }
                } else if kdbGroup.isRoot {
                    let error = UIAlertView(title: "Error", message: "You can't delete the last group in a database.", delegate: nil, cancelButtonTitle: "Okay")
                    error.show()
                    save = false
                }
            } else {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    // remove the entry they're viewing if it's the one they just deleted
                    let details = (app.splitController?.detailViewController as! UINavigationController).viewControllers
                    if details.count > 1 {
                        let curEntry = details[1]
                        if let kevc = curEntry as? KdbEntryViewController, kevc.kdbEntry == kdbGroup.entries[indexPath.row] as? KdbEntry {
                            (app.splitController?.detailViewController as! UINavigationController).popToRootViewController(animated: false)
                        }
                    }
                }
                // delete entry
                kdbGroup.deleteEntry(at: Int32(indexPath.row))
                tableView.deleteRows(at: [indexPath], with: .fade)
                if kdbGroup.entries.count == 0 {
                    if self.isEditing {
                        extraSections += 1
                    } else {
                        tableView.deleteSections(IndexSet(integer: indexPath.section), with: .fade)
                    }
                }
            }
            tableView.endUpdates()
            if save {
                self.loadingMessage = "Saving"
                networkRequestStarted()

                kdbGroup.database.savingDelegate = self
                kdbGroup.database.save()
            }
        }
        else if editingStyle == .insert {
            if indexPath.section == 0 {
                let egvc = EditGroupViewController(nibName: "EditViewController", bundle: nil)
                egvc.title = "Add Group"
                egvc.kdbGroup = kdbGroup
                egvc.editMode = false
                pushNewDetailsView(egvc, disableMaster: true)
            } else {
                let eevc = EditEntryViewController(nibName: "EditViewController", bundle: nil)
                eevc.title = "Add Entry"
                eevc.parentGroup = kdbGroup
                eevc.editMode = false
                pushNewDetailsView(eevc, disableMaster: true)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        switch sourceIndexPath.section {
        case 0:
            if proposedDestinationIndexPath.section == 1 || proposedDestinationIndexPath.row >= kdbGroup.subGroups.count {
                return IndexPath(row: kdbGroup.subGroups.count - 1, section: 0)
            }
            break
        case 1:
            if proposedDestinationIndexPath.section == 0 {
                return IndexPath(row: 0, section: 1)
            } else if proposedDestinationIndexPath.row >= kdbGroup.entries.count {
                return IndexPath(row: kdbGroup.entries.count - 1, section: 1)
            }
            break
        default:
            break
        }
        return proposedDestinationIndexPath;
    }
    
    // Override to support rearranging the table view.
    func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to toIndexPath: IndexPath) {
        switch fromIndexPath.section {
        case 0:
            kdbGroup.moveSubGroup(from: Int32(fromIndexPath.row), to: Int32(toIndexPath.row))
            break
        case 1:
            kdbGroup.moveEntry(from: Int32(fromIndexPath.row), to: Int32(toIndexPath.row))
            break
        default:
            break
        }
        isDirty = true
    }
    
    // Override to support conditional rearranging of the table view.
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return NO if you do not want the item to be re-orderable.
        switch indexPath.section {
        case 0:
            if kdbGroup.subGroups.count > 0 || extraSections > 0 {
                return indexPath.row < kdbGroup.subGroups.count
            } else {
                return indexPath.row < kdbGroup.entries.count
            }
        case 1:
            return indexPath.row < kdbGroup.entries.count
        default:
            break
        }
        return false
    }
    
    // MARK: DatabaseDelegate
    
    func databaseLockWasRemoved(_ database: Database!) {
        database.dbManager.activeDatabase = nil
        networkRequestStopped()
        navigationController?.popToRootViewController(animated: true)
        if UIDevice.current.userInterfaceIdiom == .pad {
            (app.splitController?.detailViewController as? UINavigationController)?.popToRootViewController(animated: false)
        }
    }

    func database(_ database: Database!, failedToRemoveLockWithReason reason: String!) {
        database.dbManager.activeDatabase = nil
        networkRequestStopped()
        let error = UIAlertView(title: "Error", message: reason, delegate: nil, cancelButtonTitle: "Okay")
        error.show()
        navigationController?.popViewController(animated: true)
    }
    
    func database(_ database: Database!, syncFailedWithReason error: String!) {
        networkRequestStopped()
        let alert = UIAlertView(title: "Error", message: error, delegate: nil, cancelButtonTitle: "Okay")
        alert.show()
    }
    
    func databaseSyncComplete(_ database: Database!) {
        networkRequestStopped()
        hideSyncButton()
    }
    
    func databaseSyncWouldOverwriteChanges(_ database: Database!) {
        networkRequestStopped()
        // show sliding alert asking if they want to overwrite remote changes
        let sheet = UIActionSheet(title: "The database on Dropbox has already been modified. Do you want to overwrite the newer file with this one?", delegate: self, cancelButtonTitle: "Cancel", destructiveButtonTitle: "Upload to Dropbox")
        sheet.tag = 2
        //[sheet showInView:self.view]
        sheet.show(from: toolbarItems![1], animated: true)
    }
    
    func databaseUpdateWouldOverwriteChanges(_ database: Database!) {
    }
    
    func databaseWasDeleted(_ database: Database!) {
        networkRequestStopped()
        // show sliding alert asking if they want to upload it
        let sheet = UIActionSheet(title: "The database has been deleted from your Dropbox account. Do you want to upload this file anyway?", delegate: self, cancelButtonTitle: "Cancel", destructiveButtonTitle: nil, otherButtonTitles: "Upload to Dropbox")
        sheet.tag = 2
        //[sheet showInView:self.view];
        sheet.show(from: toolbarItems![1], animated: true)
    }

    // MARK: tableview delegate

    var tableView: UITableView {
        return view.viewWithTag(1) as! UITableView
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.cellForRow(at: indexPath)?.isEditing == .some(true) {
            if indexPath.section == 0 && indexPath.row < kdbGroup.subGroups.count {
                // edit group
                let cellGroup = kdbGroup.subGroups[indexPath.row] as! KdbGroup
                let egvc = EditGroupViewController(nibName: "EditViewController", bundle: nil)
                egvc.title = cellGroup.groupName()
                egvc.kdbGroup = cellGroup
                egvc.editMode = true
                pushNewDetailsView(egvc, disableMaster: true)
            } else if indexPath.section == 1 && indexPath.row < kdbGroup.entries.count {
                // edit entry
                let cellEntry = kdbGroup.entries[indexPath.row] as! KdbEntry
                let eevc = EditEntryViewController(nibName: "EditViewController", bundle: nil)
                eevc.title = cellEntry.entryName()
                eevc.kdbEntry = cellEntry
                eevc.parentGroup = cellEntry.parent
                eevc.editMode = true
                pushNewDetailsView(eevc, disableMaster: true)
            } else {
                self.tableView(tableView, commit: .insert, forRowAt: indexPath)
            }
        } else {
            if tableView == searchDisplayController?.searchResultsTableView {
                let searchEntry = searchResults![indexPath.row] as! KdbEntry
                let svc = KdbEntryViewController(nibName: "KdbEntryViewController", bundle: nil)
                svc.title = searchEntry.entryName()
                svc.kdbEntry = searchEntry
                pushNewDetailsView(svc, disableMaster: false)
            } else {
                if indexPath.section == 0 && kdbGroup.subGroups.count > 0 {
                    // selected a group
                    let cellGroup = kdbGroup.subGroups[indexPath.row] as! KdbGroup
                    let gvc = KdbGroupViewController(nibName: "KdbGroupViewController", bundle: nil)
                    gvc.title = cellGroup.groupName()
                    gvc.kdbGroup = cellGroup
                    navigationController?.pushViewController(gvc, animated: true)
                } else {
                    // selected an entry
                    let cellEntry = kdbGroup.entries[indexPath.row] as! KdbEntry
                    let evc = KdbEntryViewController(nibName: "KdbEntryViewController", bundle: nil)
                    evc.title = cellEntry.entryName()
                    evc.kdbEntry = cellEntry
                    pushNewDetailsView(evc, disableMaster: false)
                }
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    @objc
    func reloadSection(_ section: Int) {
        // reset the extrasections variable before reloading the section (in case it was on a delete or new group/entry)
        if self.isEditing {
            extraSections = 0
            if kdbGroup.entries.count == 0 && !kdbGroup.isRoot {
                extraSections += 1
            }
            if kdbGroup.subGroups.count == 0 {
                extraSections += 1
            }
        } else {
            extraSections = 0
        }
        tableView.reloadSections(IndexSet(integer: section), with: UIDevice.current.userInterfaceIdiom == .pad ? .fade : .none)
    }
    
    // MARK: tableview datasource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if tableView == searchDisplayController?.searchResultsTableView {
            return 1
        } else {
            var sections = 0
            if kdbGroup.subGroups.count > 0 {
                sections += 1
            }
            if kdbGroup.entries.count > 0 {
                sections += 1
            }
            return sections + extraSections
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == searchDisplayController?.searchResultsTableView {
            return searchResults?.count ?? 0
        } else {
            switch section {
            case 0:
                if kdbGroup.subGroups.count > 0 || extraSections > 0 {
                    return kdbGroup.subGroups.count + extraRows
                } else {
                    return kdbGroup.entries.count + extraRows
                }
            case 1:
                if kdbGroup.isRoot == false {
                    return kdbGroup.entries.count + extraRows
                } else {
                    return 0
                }
            default:
                break
            }
        }
        return 0 + extraRows
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if tableView != searchDisplayController?.searchResultsTableView {
            switch section {
            case 0:
                if kdbGroup.subGroups.count > 0 || extraSections > 0 {
                    return "Groups"
                } else {
                    return "Entries"
                }
            case 1:
                return "Entries"
            default:
                break;
            }
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        struct Statics {
            static var CellIdentifier = "Cell";
        }

        var cell: UITableViewCell
        if let reused = tableView.dequeueReusableCell(withIdentifier: Statics.CellIdentifier) {
            cell = reused
        } else {
            cell = UITableViewCell(style: .default, reuseIdentifier: Statics.CellIdentifier)
        }
        
        cell.accessoryType = .disclosureIndicator
        
        if tableView == searchDisplayController?.searchResultsTableView {
            let searchEntry = searchResults?[indexPath.row] as! KdbEntry
            cell.textLabel?.text = searchEntry.entryName()
            cell.imageView?.image = searchEntry.entryIcon()
        } else {
            var groupCell = false
            if extraSections > 0 {
                if indexPath.section == 0 {
                    groupCell = true
                }
            } else {
                if kdbGroup.subGroups.count > 0 && indexPath.section == 0 {
                    groupCell = true
                }
            }
            if groupCell == true && indexPath.row < kdbGroup.subGroups.count {
                let cellGroup = kdbGroup.subGroups[indexPath.row] as! KdbGroup
                cell.textLabel?.text = cellGroup.groupName()
                cell.imageView?.image = cellGroup.groupIcon()
            } else if groupCell == false && indexPath.row < kdbGroup.entries.count {
                let cellEntry = kdbGroup.entries[indexPath.row] as! KdbEntry
                cell.textLabel?.text = cellEntry.entryName()
                cell.imageView?.image = cellEntry.entryIcon()
            } else {
                cell.imageView?.image = nil
                cell.accessoryType = .none
                if groupCell == true {
                    cell.textLabel?.text = "Add Group"
                } else {
                    cell.textLabel?.text = "Add Entry"
                }
            }
        }
        
        return cell
    }
    
    // MARK: search stuff
    
    func kdbEntry(_ entry: KdbEntry, isMatchForTerm searchTerm: String) -> Bool {
        if entry.entryName().lowercased().range(of: searchTerm.lowercased()) != nil {
            return true
        }
        if entry.entryUsername().lowercased().range(of: searchTerm.lowercased()) != nil {
            return true
        }
        if entry.entryUrl().lowercased().range(of: searchTerm.lowercased()) != nil {
            return true
        }
        if entry.entryNotes().lowercased().range(of: searchTerm.lowercased()) != nil {
            return true
        }
        return false
    }
    
    func getMatchingEntriesFromGroup(_ group: KdbGroup, forSearchTerm searchTerm: String) -> [KdbEntry] {
        var matches: [KdbEntry] = []
        for entry_ in group.entries {
            let entry = entry_ as! KdbEntry
            if kdbEntry(entry, isMatchForTerm: searchTerm) && !matches.contains(entry) {
                matches.append(entry)
            }
        }
        
        for subGroup_ in group.subGroups {
            let subGroup = subGroup_ as! KdbGroup
            if !kdbGroup.isRoot || !app.prefs.ignoreBackup || subGroup.groupName() != "Backup" {
                matches.append(contentsOf: getMatchingEntriesFromGroup(subGroup, forSearchTerm: searchTerm))
            }
        }
        
        return matches
    }
    
    func searchDisplayController(_ controller: UISearchDisplayController, shouldReloadTableForSearch searchString: String?) -> Bool {
        if let sr = searchResults {
            sr.removeAllObjects()
        } else {
            searchResults = []
        }
        searchResults?.addObjects(from: getMatchingEntriesFromGroup(kdbGroup, forSearchTerm: searchString!))
        return true
    }
    
    func searchDisplayControllerWillEndSearch(_ controller: UISearchDisplayController) {
        savedSearchTerm = nil
        tableView.reloadData()
    }

}


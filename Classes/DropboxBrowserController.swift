//
//  DropboxBrowserController.swift
//  PassDrop
//
//  Created by Rudis Muiznieks on 2/5/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

import UIKit
import SwiftyDropbox

class DropboxBrowserController: UIPullToReloadTableViewController, NewDatabaseDelegate {
    var dropboxClient: DropboxClient!
    var myPath: String
    var isLoaded = false
    var loadingView: LoadingView!
    var dirContents: [Files.Metadata]
    var dirBrowsers: [String: DropboxBrowserController]
    var dbManager: DatabaseManager!
    
    static var networkIndicatorReq = 0
    
    init(path: String) {
        self.myPath = path
        self.dirContents = []
        self.dirBrowsers = [:]
        super.init(nibName: nil, bundle: nil)
        DropboxBrowserController.networkIndicatorReq = 0
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Actions

    @objc func newButtonClicked() {
        let ndbvc = NewDatabaseViewController(nibName: "EditViewController", bundle: nil)
        ndbvc.location = myPath
        ndbvc.delegate = self
        navigationController?.pushViewController(ndbvc, animated: true)
    }
    
    func newDatabaseCreated() {
        // rather than fast-pathing new database creation, let's just refresh the entire directory
        refreshDirectory()
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dropboxClient = DropboxClientsManager.authorizedClient!
        let newButton = UIBarButtonItem(title: "New", style: .plain, target: self, action: #selector(newButtonClicked))
        navigationItem.rightBarButtonItem = newButton
        
        edgesForExtendedLayout = []
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !isLoaded {
            refreshDirectory()
        }
    }
    
    // MARK: PullDown implementation
    
    override func pullDownToReloadAction() {
        refreshDirectory()
    }
    
    func refreshDirectory() {
        networkRequestStarted()
        dropboxClient.files.listFolder(path: myPath).response { [weak self] response, error in
            guard let ss = self else { return }
            ss.networkRequestStopped()
            if let response = response {
                // TODO: response.hasMore support
                // dropboxClient.files.listFolderContinue(cursor: response.cursor)
                ss.isLoaded = true
                ss.dirContents = response.entries.sorted { lhs, rhs in
                    let lhsIsDir = lhs as? Files.FolderMetadata != nil
                    let rhsIsDir = rhs as? Files.FolderMetadata != nil
                    if lhsIsDir && !rhsIsDir {
                        return true
                    } else if !lhsIsDir && rhsIsDir {
                        return false
                    } else {
                        return (lhs.pathLower ?? "") < (rhs.pathLower ?? "")
                    }
                }
                
            } else if let error = error {
                ss.isLoaded = false
                ss.alertError(error.description)
                ss.dirContents = []
                
            }
            ss.tableView.reloadData()
        }
    }

    // MARK: Error UI
    
    func alertMessage(_ message: String, withTitle alertTitle: String) {
        let alert = UIAlertController(title: alertTitle, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }

    func alertError(_ errorMessage: String?) {
        let msg = errorMessage ?? "Dropbox reported an unknown error."
        let alert = UIAlertController(title: "Dropbox Error", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }

     // MARK: Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of rows in the section.
        return dirContents.count
    }
    
    // Customize the appearance of table view cells.
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        struct Static {
            static let CellIdentifier = "Cell"
        }
        
        let cell: UITableViewCell
        
        switch tableView.dequeueReusableCell(withIdentifier: Static.CellIdentifier) {
        case .some(let c):
            cell = c
        case .none:
            cell = UITableViewCell(style: .default, reuseIdentifier: Static.CellIdentifier)
            cell.textLabel?.textColor = UIColor.black
        }
        
        let cellData = dirContents[indexPath.row]
        let fileName = cellData.pathDisplay?.lastPathComponent ?? ""
        if let _ = cellData as? Files.FolderMetadata {
            cell.accessoryType = .disclosureIndicator
            cell.imageView?.image = UIImage(named: "folder_icon.png")
            cell.isUserInteractionEnabled = true
            cell.textLabel?.textColor = UIColor.black
        } else {
            if fileName.hasSuffix(".kdb") {
                cell.imageView?.image = UIImage(named: "keepass_icon.png")
                cell.isUserInteractionEnabled = true
                cell.textLabel?.textColor = UIColor.black
            } else {
                cell.imageView?.image = UIImage(named: "unknown_icon.png")
                //cell.userInteractionEnabled = NO;
                cell.textLabel?.textColor = UIColor.lightGray
            }
        }
        cell.textLabel?.text = fileName
        
        return cell
    }

    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }

    // MARK: Table view delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cellData = dirContents[indexPath.row]
        let cellPath = cellData.pathDisplay!
        if let _ = cellData as? Files.FolderMetadata {
            if dirBrowsers[cellPath] == nil {
                let dirBrowser = DropboxBrowserController(path: cellPath)
                dirBrowser.dbManager = dbManager
                dirBrowser.title = cellPath.lastPathComponent
                dirBrowsers[cellPath] = dirBrowser
            }
            navigationController?.pushViewController(dirBrowsers[cellPath]!, animated: true)
        } else {
            //if([cellData.path hasSuffix:@".kdb"]){
            if dbManager.databaseExists(dbManager.getIdentifierForDatabase(cellPath)) {
                alertMessage("That database has already been added. You cannot add the same database more than once.", withTitle: "Oops!")
            } else {
                let localFile = dbManager.getLocalFilenameForDatabase(dbManager.getIdentifierForDatabase(cellPath), forNewFile: true)
                networkRequestStarted()
                dropboxClient.files.download(path: cellPath, rev: nil, overwrite: true, destination: { temporaryURL, response in
                    return URL(fileURLWithPath: localFile)
                }).response { [weak self] response, error in
                    guard let ss = self else { return }
                    ss.networkRequestStopped()
                    if let (metadata, _) = response {
                        let dbId = ss.dbManager.getIdentifierForDatabase(cellPath)
                        ss.dbManager.createNewDatabaseNamed(
                            dbId.lastPathComponent,
                            withId: dbId,
                            withLocalPath: localFile,
                            lastModified: metadata.serverModified,
                            rev: metadata.rev)
                    } else if let error = error {
                        ss.alertError(error.description)
                    }
                }
            }
            //}
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: Dropbox/RestClient
    func setWorking(_ working: Bool) {
        view.isUserInteractionEnabled = !working
        self.navigationController?.view.isUserInteractionEnabled = !working
        if working {
            loadingView = LoadingView(title: "Loading")
            loadingView.show()
        } else {
            loadingView.dismiss(animated: false)
            loadingView = nil
        }
    }
    
    func networkRequestStarted() {
        let app = UIApplication.shared
        app.isNetworkActivityIndicatorVisible = true
        if DropboxBrowserController.networkIndicatorReq == 0 {
            setWorking(true)
        }
        DropboxBrowserController.networkIndicatorReq += 1
    }
    
    func networkRequestStopped() {
        DropboxBrowserController.networkIndicatorReq -= 1
        if DropboxBrowserController.networkIndicatorReq <= 0 {
            let app = UIApplication.shared
            app.isNetworkActivityIndicatorVisible = false
            setWorking(false)
            pullToReloadHeaderView.finishReloading(tableView, animated: true)
        }
    }
    
    // MARK: Memory management
    
    // TODO(chadaustin): this does not feel necessary to me
    func reset() {
        for browser in dirBrowsers.values {
            browser.reset()
        }
        dirBrowsers = [:]
        isLoaded = false
        dirContents = []
        tableView.reloadData()
    }
    
    deinit {
        reset()
    }
}

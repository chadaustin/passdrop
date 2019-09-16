//
//  NewDatabaseViewController.swift
//  PassDrop
//
//  Created by Rudis Muiznieks on 9/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

import UIKit
import SwiftyDropbox

@objc
protocol NewDatabaseDelegate {
    func newDatabaseCreated() -> Void
}

class NewDatabaseViewController: NetworkActivityViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {
    var dropboxClient: DropboxClient!
    var dbName: String = ""
    var password: String = ""
    var verifyPassword: String = ""
    var location: String!
    var delegate: NewDatabaseDelegate?
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    // MARK: Actions

    func showError(message: String) {
        let error = UIAlertController(title: "Error", message: "You must enter a file name.", preferredStyle: .alert)
        error.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(error, animated: true)
    }

    func showAlert(message: String) {
        let error = UIAlertController(title: "Error", message: "You must enter a file name.", preferredStyle: .alert)
        error.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(error, animated: true)
    }

    @objc func saveButtonClicked() {
        // Force field to synchronize its data into dbName, password, or verifyPassword.
        self.view.endEditing(true)
        
        if dbName.isEmpty {
            showError(message: "You must enter a file name.")
            return;
        }
        
        if (
            (dbName as NSString).rangeOfCharacter(
                from: NSCharacterSet(
                    charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                ).inverted
            )
        ).location != NSNotFound {
            showError(message: "The file name contains illegal characters. Please use only alphanumerics, spaces, dashes, or underscores.")
        }
        
        if password.isEmpty {
            showError(message: "You must enter a password.")
            return
        }

        if !(password == verifyPassword) {
            showError(message: "The passwords you entered did not match.")
            return
        }
        
        self.loadingMessage = "Creating"
        networkRequestStarted()
        
        dropboxClient.files.getMetadata(
            path: pathRoot.appendingPathComponent(dbName.appendingPathExtension("kdb")!),
            includeMediaInfo: false,
            includeDeleted: false
            //includeHasExplicitSharedMembers: false
        ).response {
            [weak self] response, error in
            guard let ss = self else { return }
            if let _ = response {
                ss.networkRequestStopped()
                ss.showError(message: "That file already exists. Please choose a different file name.")
            } else if let error = error {
                switch error {
                case .routeError(let box, _, _, _):
                    switch box.unboxed {
                    case .path(.notFound):
                        // file not found, means we're good to create it
                        ss.uploadTemplate()
                    default:
                        ss.networkRequestStopped()
                        ss.alertError(error.description)
                    }
                default:
                    ss.networkRequestStopped()
                    ss.alertError(error.description)
                }
            }
        }
    }
    
    func alertError(_ errorMessage: String?) {
        let error = UIAlertController(title: "Error", message: errorMessage ?? "Dropbox reported an unknown error.", preferredStyle: .alert)
        error.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(error, animated: true)
    }
    
    func uploadTemplate() {
        let path = Bundle.main.path(forResource: "template", ofType: "kdb")!
        let reader = KdbReader(kdbFile: path, usingPassword: "password")
        if reader.hasError {
            networkRequestStopped()
            showError(message: "There was a fatal error loading the database template. You may need to reinstall PassDrop.")
        } else {
            let tempFile = NSTemporaryDirectory().appendingPathComponent(dbName.appendingPathExtension("kdb")!)
            let kpdb = reader.kpDatabase
            let writer = KdbWriter()
            
            let cPw = password.cString(using: .utf8)
            let pwH = UnsafeMutablePointer<UInt8>.allocate(capacity: 32)
            kpass_hash_pw(kpdb, cPw, pwH)
            if !writer.saveDatabase(kpdb, withPassword: pwH, toFile: tempFile) {
                networkRequestStopped()
                showError(message: writer.lastError)
            } else {
                dropboxClient.files.upload(
                    path: pathRoot.appendingPathComponent(dbName.appendingPathExtension("kdb")!),
                    input: URL(fileURLWithPath: tempFile)
                ).response { [weak self] response, error in
                    guard let ss = self else { return }
                    ss.networkRequestStopped()
                    if let _ = response {
                        ss.delegate?.newDatabaseCreated()
                        ss.navigationController?.popViewController(animated: true)
                    } else if let error = error {
                        ss.showError(message: error.description)
                    }
                }
            }
        }
    }

    var pathRoot: String {
        return location.isEmpty ? "/" : location
    }
    
    func cleanup() {
        let fm = FileManager()
        let tempPath = NSTemporaryDirectory().appendingPathComponent(dbName.appendingPathExtension("kdb")!)
        if fm.fileExists(atPath: tempPath) {
            _ = try? fm.removeItem(atPath: tempPath)
        }
    }
    
    // MARK: View lifecycle
    
    // Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
    override func viewDidLoad() {
        self.title = "New File"
        
        let saveButton = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveButtonClicked))
        navigationItem.rightBarButtonItem = saveButton

        dropboxClient = DropboxClientsManager.authorizedClient!
        
        super.viewDidLoad()
    }

    // MARK: tableviewdatasource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch(section){
        case 0:
            return 1;
        case 1:
            return 2;
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "The .kdb extension will be added for you."
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        struct Static {
            static let CellIdentifier = "Cell"
        }

        var cell = tableView.dequeueReusableCell(withIdentifier: Static.CellIdentifier)
        var field: UITextField?

        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: Static.CellIdentifier)
            cell?.accessoryType = .none
            
            field = UITextField(frame: CGRect(
                x: 11,
                y: 0,
                width: cell!.contentView.frame.size.width - 11,
                height: cell!.contentView.frame.size.height))
            field?.autoresizingMask = .flexibleWidth
            field?.contentVerticalAlignment = .center
            cell?.contentView.addSubview(field!)
        }
        
        field = nil
        
        for i in 0..<cell!.contentView.subviews.count {
            if let subview = cell!.contentView.subviews[i] as? UITextField {
                field = subview
            }
        }
        
        field?.tag = ((indexPath.section + 1) * 10) + indexPath.row
        field?.font = UIFont.boldSystemFont(ofSize: 17)
        field?.adjustsFontSizeToFitWidth = true

        if indexPath.section == 0 {
            field?.text = dbName
            field?.placeholder = "Required"
        } else {
            field?.isSecureTextEntry = true
            if indexPath.row == 0 {
                field?.text = password
                field?.placeholder = "Password"
            } else {
                field?.text = verifyPassword
                field?.placeholder = "Verify Password"
            }
        }
        field?.returnKeyType = .done
        field?.keyboardType = .default
        field?.clearButtonMode = .whileEditing
        field?.delegate = self
        
        return cell!
    }

    // MARK: tableviewdelegate
    
    var tableView: UITableView {
        return view.viewWithTag(1) as! UITableView
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        view.viewWithTag((indexPath.section + 1) * 10 + indexPath.row)?.becomeFirstResponder()
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: TextField delegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        switch textField.tag {
        case 10:
            self.dbName = textField.text ?? ""
            break;
        case 20:
            self.password = textField.text ?? ""
            break;
        case 21:
            self.verifyPassword = textField.text ?? ""
            break;
        default:
            break
        }
    }
}

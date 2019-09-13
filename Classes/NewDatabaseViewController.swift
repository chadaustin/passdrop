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
    var password: String!
    var verifyPassword: String!
    var location: String!
    var currentFirstResponder: Int = 0
    var delegate: NewDatabaseDelegate?
    var oldKeyboardHeight: CGFloat = 0
    var keyboardShowing: Bool = false
    var scrollToPath: IndexPath!
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    override var shouldAutorotate: Bool {
        return true
    }

    // MARK: Actions

    @objc func hideKeyboard() {
        let fld = view.viewWithTag(currentFirstResponder)
        fld?.resignFirstResponder()
    }
    
    @objc func saveButtonClicked() {
        hideKeyboard()
        if dbName.isEmpty {
            let error = UIAlertView(title: "Error", message: "You must enter a file name.", delegate: nil, cancelButtonTitle: "Cancel")
            error.show()
            return;
        }
        
        if (
            (dbName as NSString).rangeOfCharacter(
                from: NSCharacterSet(
                    charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                ).inverted
            )
        ).location != NSNotFound {
            let error = UIAlertView(title: "Error", message: "The file name contains illegal characters. Please use only alphanumerics, spaces, dashes, or underscores.", delegate: nil, cancelButtonTitle: "Cancel")
            error.show()
        }
        
        if password == nil {
            let error = UIAlertView(title: "Error", message: "You must enter a password.", delegate: nil, cancelButtonTitle: "Cancel")
            error.show()
            return
        }

        if !(password == verifyPassword) {
            let error = UIAlertView(title: "Error", message: "The passwords you entered did not match.", delegate: nil, cancelButtonTitle: "Cancel")
            error.show()
            return;
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
                let alert = UIAlertView(title: "Error", message: "That file already exists. Please choose a different file name.", delegate: nil, cancelButtonTitle: "Cancel")
                alert.show()
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
        let msg = errorMessage ?? "Dropbox reported an unknown error."
        let alert = UIAlertView(title: "Dropbox Error", message: msg, delegate: nil, cancelButtonTitle: "OK")
        alert.show()
    }
    
    func uploadTemplate() {
        let path = Bundle.main.path(forResource: "template", ofType: "kdb")!
        let reader = KdbReader(kdbFile: path, usingPassword: "password")
        if reader.hasError {
            networkRequestStopped()
            let error = UIAlertView(title: "Error", message: "There was a fatal error loading the database template. You may need to reinstall PassDrop.", delegate: nil, cancelButtonTitle: "Cancel")
            error.show()
        } else {
            let tempFile = NSTemporaryDirectory().appendingPathComponent(dbName.appendingPathExtension("kdb")!)
            let kpdb = reader.kpDatabase
            let writer = KdbWriter()
            
            let cPw = password.cString(using: .utf8)
            let pwH = UnsafeMutablePointer<UInt8>.allocate(capacity: 32)
            kpass_hash_pw(kpdb, cPw, pwH)
            if !writer.saveDatabase(kpdb, withPassword: pwH, toFile: tempFile) {
                networkRequestStopped()
                let error = UIAlertView(title: "Error", message: writer.lastError, delegate: nil, cancelButtonTitle: "Cancel")
                error.show()
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
                        let error = UIAlertView(title: "Error", message: error.description, delegate: nil, cancelButtonTitle: "OK")
                        error.show()
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
        
        currentFirstResponder = 0
        
        oldKeyboardHeight = 0
        keyboardShowing = false

        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hideKeyboard), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        hideKeyboard()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func keyboardWillShow(_ note: NSNotification) {
        let keyboardBounds = (note.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)!.cgRectValue
        let keyboardHeight = UIInterfaceOrientationIsPortrait(UIApplication.shared.statusBarOrientation)
            ? keyboardBounds.size.height
            : keyboardBounds.size.width
        if keyboardShowing == false {
            keyboardShowing = true
            
            var frame = view.frame
            frame.size.height -= keyboardHeight
            
            oldKeyboardHeight = keyboardHeight

            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationBeginsFromCurrentState(true)
            UIView.setAnimationDuration(0.3)
            view.frame = frame
            tableView.scrollToRow(at: scrollToPath, at: .middle, animated: true)
            UIView.commitAnimations()
        } else if keyboardHeight != oldKeyboardHeight {
            let diff = keyboardHeight - oldKeyboardHeight
            var frame = view.frame
            frame.size.height -= CGFloat(diff)
            
            oldKeyboardHeight = keyboardHeight
            
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationBeginsFromCurrentState(true)
            UIView.setAnimationDuration(0.3)
            view.frame = frame
            tableView.scrollToRow(at: scrollToPath, at: .middle, animated: true)
            UIView.commitAnimations()
        }
    }

    @objc func keyboardWillHide(_ note: NSNotification) {
        let keyboardBounds = (note.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)!.cgRectValue
        let keyboardHeight = UIInterfaceOrientationIsPortrait(UIApplication.shared.statusBarOrientation)
            ? keyboardBounds.size.height
            : keyboardBounds.size.width
        if keyboardShowing {
            keyboardShowing = false
            var frame = self.view.frame
            frame.size.height += keyboardHeight
            
            oldKeyboardHeight = 0

            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationBeginsFromCurrentState(true)
            UIView.setAnimationDuration(0.3)
            view.frame = frame
            UIView.commitAnimations()
        }
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
        hideKeyboard()
        return false
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        scrollToPath = IndexPath(row: textField.tag % 10, section: (textField.tag / 10) - 1)
        currentFirstResponder = textField.tag
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        switch textField.tag {
        case 10:
            self.dbName = textField.text ?? ""
            break;
        case 20:
            self.password = textField.text
            break;
        case 21:
            self.verifyPassword = textField.text
            break;
        default:
            break
        }
        
        currentFirstResponder = 0
    }
}

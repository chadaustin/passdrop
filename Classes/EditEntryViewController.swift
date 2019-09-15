//
//  EditEntryViewController.h
//  PassDrop
//
//  Created by Rudis Muiznieks on 8/30/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

fileprivate let NO_ICON_SET: UInt32 = 9999

class EditEntryViewController : NetworkActivityViewController, ParentGroupPickerDelegate, UITextFieldDelegate, IconPickerDelegate, DatabaseDelegate, GeneratePasswordDelegate, UITextViewDelegate, UITableViewDelegate, UITableViewDataSource {
    
    var parentGroup: KdbGroup?
    var kdbEntry: KdbEntry?
    var neuName: String = ""
    var neuIcon: UIImage?
    var neuIconId: UInt32 = 0
    var neuUsername: String = ""
    var neuPassword: String = ""
    var verifyPassword: String = ""
    var neuUrl: String?
    var neuNotes: String?
    var neuExpireDate: Date = EditEntryViewController.neverExpires
    var editMode: Bool = false
    var currentFirstResponder: Int = 0
    var masterView: KdbGroupViewController?
    var iconPop: UIPopoverController?
    var scrollToPath: IndexPath?
    var oldkeyboardHeight: CGFloat = 0
    var keyboardShowing = false
    
    var tableView: UITableView {
        return view.viewWithTag(1) as! UITableView
    }
    
    var datePicker: UIDatePicker!
    var dateBar: UIToolbar?
    var app: PassDropAppDelegate?
    
    static var neverExpires: Date {
        var date = DateComponents()
        date.calendar = Calendar(identifier: .gregorian)
        date.day = 31
        date.month = 12
        date.year = 2999
        date.hour = 23
        date.minute = 59
        date.second = 59
        return date.date!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        app = UIApplication.shared.delegate as! PassDropAppDelegate
        
        var saveButton = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(saveEntry))
        navigationItem.rightBarButtonItem = saveButton
        currentFirstResponder = 0
        
        neuPassword = ""
        verifyPassword = ""
        
        datePicker = UIDatePicker()
        if UIDevice.current.userInterfaceIdiom != .pad {
            datePicker?.autoresizingMask = .flexibleHeight
        }
        datePicker?.datePickerMode = .dateAndTime

        dateBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: 44))
        dateBar?.barStyle = .blackTranslucent
        dateBar?.tintColor = .lightGray

        let cancelButton = UIBarButtonItem(title: "Cancel", style: .bordered, target: self, action: #selector(hideKeyboard))
        let fspace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Choose", style: .done, target: self, action: #selector(chooseButtonClicked))
        
        dateBar?.setItems([cancelButton, fspace, doneButton], animated: false)
        
        neuIconId = NO_ICON_SET
        tableView.autoresizesSubviews = true
        
        if editMode {
            neuIcon = kdbEntry!.entryIcon()
            neuName = kdbEntry!.entryName()
            neuUsername = kdbEntry!.entryUsername()
            neuUrl = kdbEntry!.entryUrl()
            neuNotes = kdbEntry!.entryNotes()
            neuExpireDate = kdbEntry!.expireDate()
        } else {
            neuIcon = parentGroup?.groupIcon()  //[UIImage imageNamed:@"0.png"];
            neuName = ""
            neuUsername = ""
            neuUrl = ""
            neuNotes = ""
            neuExpireDate = EditEntryViewController.neverExpires
        }
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            let closeButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(closeButtonClicked))
            navigationItem.leftBarButtonItem = closeButton
        }
        
        oldkeyboardHeight = 0
        keyboardShowing = false
    }
    
    // hack to fix weird bug with the leftbarbuttonitems disappearing
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            let sb = navigationItem.leftBarButtonItem!
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: sb.title, style: sb.style, target: sb.target, action: sb.action)
        }
    }
    
    @objc
    func closeButtonClicked() {
        navigationController?.popViewController(animated: false)
        if UIDevice.current.userInterfaceIdiom == .pad {
            UIView.beginAnimations(nil, context: nil)
            app?.splitController?.masterViewController.view.alpha = 1
            UIView.setAnimationDuration(0.3)
            UIView.commitAnimations()
                
            app?.splitController?.masterViewController.view.isUserInteractionEnabled = true
        }
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }

    override var shouldAutorotate: Bool {
        return true
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc
    func keyboardWillShow(_ note: NSNotification) {
        var keyboardBounds = CGRect()
        keyboardBounds = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as! CGRect
        let keyboardHeight = UIApplication.shared.statusBarOrientation.isPortrait
            ? keyboardBounds.size.height
            : keyboardBounds.size.width
        if !keyboardShowing {
            keyboardShowing = true
            var frame = view.frame
            frame.size.height -= keyboardHeight
            
            oldkeyboardHeight = keyboardHeight
            
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationBeginsFromCurrentState(true)
            UIView.setAnimationDuration(0.3)
            view.frame = frame
            if let scrollToPath = scrollToPath {
                tableView.scrollToRow(at: scrollToPath, at: .middle, animated: true)
            }
            UIView.commitAnimations()
        } else if keyboardHeight != oldkeyboardHeight {
            let diff = keyboardHeight - oldkeyboardHeight
            var frame = self.view.frame
            frame.size.height -= diff
            
            oldkeyboardHeight = keyboardHeight
            
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationBeginsFromCurrentState(true)
            UIView.setAnimationDuration(0.3)
            view.frame = frame
            if let scrollToPath = scrollToPath {
                tableView.scrollToRow(at: scrollToPath, at: .middle, animated: true)
            }
            UIView.commitAnimations()
        }
    }

    @objc
    func keyboardWillHide(_ note: NSNotification) {
        var keyboardBounds = CGRect()
        keyboardBounds = note.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as! CGRect
        let keyboardHeight = UIApplication.shared.statusBarOrientation.isPortrait ? keyboardBounds.size.height : keyboardBounds.size.width
        if keyboardShowing {
            keyboardShowing = false
            var frame = self.view.frame
            frame.size.height += keyboardHeight
            
            oldkeyboardHeight = 0
            
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationBeginsFromCurrentState(true)
            UIView.setAnimationDuration(0.3)
            view.frame = frame
            UIView.commitAnimations()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        navigationController?.setToolbarHidden(true, animated: false)
        super.viewDidAppear(animated)
    }
   
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideKeyboard()
        NotificationCenter.default.removeObserver(self)
        if UIDevice.current.userInterfaceIdiom == .pad {
            iconPop?.dismiss(animated: true)
        }
    }

    // MARK: actions
    
    func parentGroupSelected(_ group: KdbGroup!) {
        parentGroup = group
        tableView.reloadData()
    }

    func childGroup() -> KdbGroup? {
        return nil
    }
    
    func passwordGenerated(_ password: String!) {
        self.neuPassword = password
        self.verifyPassword = password
        self.tableView.reloadData()
    }
    
    func viewController() -> UIViewController! {
        return self
    }
    
    func iconSelected(_ icon: UIImage!, withId iconId: UInt32) {
        neuIcon = icon
        neuIconId = iconId
        tableView.reloadData()
        if UIDevice.current.userInterfaceIdiom == .pad {
            iconPop?.dismiss(animated: true)
        }
    }
   
    @objc
    func hideKeyboard() {
        let fld = view.viewWithTag(currentFirstResponder)
        fld?.resignFirstResponder()
        view.endEditing(true)
    }
    
    // MARK: DatePicker stuff

    @objc
    func chooseButtonClicked() {
        neuExpireDate = datePicker.date
        tableView.reloadRows(at: [IndexPath(row: 0, section: 6)], with: .none)
        hideKeyboard()
    }
    
    // MARK: Saving
    
    @objc
    func saveEntry() {
        // clear ui stuff
        //[self closeDatePicker];
        hideKeyboard()
    
        // input validation
        if neuName.isEmpty {
            let invalid = UIAlertView(title: "Error", message: "You must enter an entry name.", delegate: self, cancelButtonTitle: "Cancel")
            invalid.show()
        } else if neuPassword != verifyPassword {
            let invalid = UIAlertView(title: "Error", message: "The passwords you entered do not match.", delegate: self, cancelButtonTitle: "Cancel")
            invalid.show()
        } else {
            let iconId = neuIconId != NO_ICON_SET ? neuIconId : editMode ? kdbEntry!.kpEntry()!.pointee.image_id : parentGroup!.kpGroup().pointee.image_id

            if editMode {
                var setPassword: String? = neuPassword
                if neuPassword.isEmpty {
                    setPassword = nil
                }
                kdbEntry?.update(withParent: parentGroup, withTitle: neuName, withIcon: iconId, withUsername: neuUsername, withPassword: setPassword, withUrl: neuUrl, withNotes: neuNotes, withExpires: neuExpireDate)
            } else {
                kdbEntry = KdbEntry(parent: parentGroup, withTitle: neuName, withIcon: iconId, withUsername: neuUsername, withPassword: neuPassword, withUrl: neuUrl, withNotes: neuNotes, withExpires: neuExpireDate, for: parentGroup?.database)
            }
            
            loadingMessage = "Saving"
            networkRequestStarted()
            
            kdbEntry?.database.savingDelegate = self
            kdbEntry?.database.save()
        }
    }
    
    func databaseSaveComplete(_ database: Database!) {
        networkRequestStopped()
        masterView?.reloadSection(1)
        navigationController?.popViewController(animated: UIDevice.current.userInterfaceIdiom != .pad)
        if UIDevice.current.userInterfaceIdiom == .pad {
            UIView.beginAnimations(nil, context: nil)
            app?.splitController?.masterViewController.view.alpha = 1
            UIView.setAnimationDuration(0.3)
            UIView.commitAnimations()
            
            app?.splitController?.masterViewController.view.isUserInteractionEnabled = true
        }
    }

    func database(_ database: Database!, saveFailedWithReason error: String!) {
        networkRequestStopped()
        setWorking(false)
        let saveError = UIAlertView(title: "Save Failed", message: error, delegate: self, cancelButtonTitle: "Cancel")
        saveError.tag = 4
        saveError.show()
    }
    
    // MARK: TableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 7
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 1:
            return 2;
        case 3:
            return 3;
        case 0, 2, 4, 5, 6:
            return 1;
        default:
            return 0;
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Parent Group";
        case 1:
            return "Entry Name";
        case 2:
            return "Username";
        case 3:
            return "Password";
        case 4:
            return "URL";
        case 5:
            return "Notes";
        case 6:
            return "Expires";
        default:
            return nil
        }
    }
    
    static let CellIdentifier = "Cell"
    static let NoteCellIdentifier = "NoteCell"

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let TextCellIdentifier = "TextCell\(indexPath.section)\(indexPath.row)"
        
        var cell: UITableViewCell!
        var notes: UITextView?
        
        if indexPath.section == 0 || (indexPath.section == 1 && indexPath.row == 1) || (indexPath.section == 3 && indexPath.row == 2) { // disclosure cells
            cell = tableView.dequeueReusableCell(withIdentifier: EditEntryViewController.CellIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .default, reuseIdentifier: EditEntryViewController.CellIdentifier)
                cell?.accessoryType = .disclosureIndicator
            }
            
            switch indexPath.section {
            case 0:
                if parentGroup?.isRoot ?? true {
                    cell?.imageView?.image = nil
                    cell?.textLabel?.text = "None"
                } else {
                    cell?.imageView?.image = parentGroup?.groupIcon()
                    cell?.textLabel?.text = parentGroup?.groupName()
                }
            case 1:
                cell.imageView?.image = nil
                cell.textLabel?.text = "Choose Icon"
            case 3:
                cell.imageView?.image = nil
                cell.textLabel?.text = "Generate Password"
            default:
                break
            }
        } else if indexPath.section == 5 { // notes cell
            cell = tableView.dequeueReusableCell(withIdentifier: EditEntryViewController.NoteCellIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .default, reuseIdentifier: EditEntryViewController.NoteCellIdentifier)
                let notes = UITextView(frame: CGRect(x: 2, y: 2, width: cell!.contentView.frame.width - 4, height: cell.contentView.frame.height - 4))
                notes.backgroundColor = .clear
                notes.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                notes.font = UIFont.systemFont(ofSize: 17)
                notes.delegate = self
                notes.tag = 50
                cell?.contentView.addSubview(notes)
            }
            notes = cell?.viewWithTag(50) as? UITextView
            notes?.text = neuNotes
        } else { // text cells
            cell = tableView.dequeueReusableCell(withIdentifier: TextCellIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .default, reuseIdentifier: TextCellIdentifier)
                let field = UITextField(frame: CGRect(x: 11, y: 0, width: cell.contentView.frame.width - 11, height: cell.contentView.frame.height))
                field.autoresizingMask = [.flexibleWidth]
                field.contentVerticalAlignment = .center
                cell?.contentView.addSubview(field)
            }
            var field: UITextField?
            for subview in cell.contentView.subviews {
                if let textField = subview as? UITextField {
                    field = textField
                }
            }
            
            if let field = field {
                if indexPath.section == 5 {
                    field.returnKeyType = .default
                } else {
                    field.returnKeyType = .done
                }
                if indexPath.section == 6 {
                    field.clearButtonMode = .always;
                } else {
                    field.clearButtonMode = .whileEditing;
                }
                if indexPath.section == 4 {
                    field.keyboardType = .URL;
                    field.autocapitalizationType = .none;
                } else if(indexPath.section == 2){
                    field.keyboardType = .emailAddress;
                    field.autocapitalizationType = .none;
                } else {
                    field.keyboardType = .default;
                    field.autocapitalizationType = .sentences;
                }
                if(indexPath.section == 3){
                    field.isSecureTextEntry = true;
                } else {
                    field.isSecureTextEntry = false;
                }
                if indexPath.section == 1 && indexPath.row == 0 {
                    cell?.imageView?.image = neuIcon
                    var offset: CGFloat
                    if UIScreen.main.responds(to: #selector(UIScreen.displayLink(withTarget:selector:))) &&
                        UIScreen.main.scale == 2.0 {
                        offset = 47
                    } else {
                        offset = 36
                    }
                    offset += 16;
                    field.frame = CGRect(x: offset, y: 0, width: cell.contentView.frame.width - offset, height: cell.contentView.frame.height)
                } else {
                    cell.imageView?.image = nil
                }
                
                switch indexPath.section {
                case 1:
                    field.text = neuName
                    field.placeholder = "Required"
                    break;
                case 2:
                    field.text = neuUsername
                    field.placeholder = "None"
                    break;
                case 3:
                    if(indexPath.row == 0){
                        field.text = neuPassword;
                        field.placeholder = "New Password"
                    } else {
                        field.text = verifyPassword;
                        field.placeholder = "Verify Password"
                    }
                    break;
                case 4:
                    field.text = neuUrl
                    field.placeholder = "None"
                    break;
                case 6:
                    let comps = Calendar.current.dateComponents([.year], from: neuExpireDate)
                    if comps.year == 2999 {
                        field.text = ""
                    } else {
                        let formatter = DateFormatter()
                        formatter.timeStyle = .short
                        formatter.dateStyle = .medium
                        field.text = formatter.string(from: neuExpireDate)
                    }
                    field.placeholder = "Never";
                    field.inputView = datePicker;
                    field.inputAccessoryView = dateBar;
                    break;
                default:
                    break
                }
                
                field.font = UIFont.boldSystemFont(ofSize: 17)
                field.tag = indexPath.section * 10 + indexPath.row
                field.adjustsFontSizeToFitWidth = true
                field.delegate = self
            }
        }
        return cell!
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 5 {// need modified height for notes cell
            return (UIApplication.shared.statusBarOrientation.isPortrait || UIDevice.current.userInterfaceIdiom == .pad) ? 151 : 62;
        }
        return 44;
    }
    
    // MARK: TableView delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        scrollToPath = indexPath
        if indexPath.section == 0 {
            hideKeyboard()
            let pgp = ParentGroupPicker(nibName: "KdbGroupViewController", bundle: nil)
            pgp.title = "Select Parent";
            pgp.kdbGroup = parentGroup?.database.rootGroup()
            pgp.delegate = self
            pgp.showNone = false
            navigationController?.pushViewController(pgp, animated: true)
        } else if indexPath.section == 1 && indexPath.row == 1 {
            hideKeyboard()
            let ip = IconPicker(nibName: "ChooseIconView", bundle: nil)
            ip.delegate = self
            if UIDevice.current.userInterfaceIdiom == .pad {
                ip.preferredContentSize = CGSize(width: 320, height: 416)
                iconPop = UIPopoverController(contentViewController: ip)
                iconPop?.present(from: tableView.cellForRow(at: indexPath)!.frame, in: tableView, permittedArrowDirections: .any, animated: true)
            } else {
                let navBar = UINavigationController(rootViewController: ip)
                navigationController?.present(navBar, animated: true)
            }
        } else if indexPath.section == 3 && indexPath.row == 2 {
            hideKeyboard()
            let gpvc = GeneratePasswordViewController(nibName: "EditViewController", bundle: nil)
            gpvc.delegate = self
            navigationController?.pushViewController(gpvc, animated: true)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: TextView delegate
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        scrollToPath = nil
        currentFirstResponder = 50
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        neuNotes = textView.text
        currentFirstResponder = 0
    }

    // MARK: TextField delegate
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        if textField.tag == 60 {
            neuExpireDate = EditEntryViewController.neverExpires
            tableView.reloadRows(at: [IndexPath(row: 0, section: 6)], with: .none)
            return false
        } else {
            return true
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        hideKeyboard()
        return false
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField.tag == 60 {
            let comps = NSCalendar.current.dateComponents([.year], from: neuExpireDate)
            if comps.year == 2999 {
                datePicker?.setDate(Date(), animated: false)
            } else {
                datePicker?.setDate(neuExpireDate, animated: false)
            }
        }
        return true;
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        scrollToPath = IndexPath(row: 0, section: textField.tag / 10)
        currentFirstResponder = textField.tag
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        switch textField.tag {
        case 10:
            neuName = textField.text ?? ""
        case 20:
            neuUsername = textField.text ?? ""
        case 30:
            neuPassword = textField.text ?? ""
        case 31:
            verifyPassword = textField.text ?? ""
        case 40:
            neuUrl = textField.text
        default:
            break
        }
        
        currentFirstResponder = 0;
    }
}

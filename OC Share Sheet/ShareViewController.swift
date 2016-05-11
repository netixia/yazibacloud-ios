//
//  ShareViewController.swift
//  OC Share Sheet
//
//  Created by Gonzalo Gonzalez on 4/3/15.
//

/*
Copyright (C) 2015, ownCloud, Inc.
This code is covered by the GNU Public License Version 3.
For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
You should have received a copy of this license
along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
*/

import UIKit
import Social
import MobileCoreServices
import AVFoundation


@objc class ShareViewController: UIViewController, UITableViewDelegate, KKPasscodeViewControllerDelegate, CheckAccessToServerDelegate {
    
    @IBOutlet weak var navigationBar: UINavigationBar?
    @IBOutlet weak var shareTable: UITableView?
    @IBOutlet weak var destinyFolderButton: UIBarButtonItem?
    @IBOutlet weak var constraintTopTableView: NSLayoutConstraint?
    
    var filesSelected: [NSURL] = []
    var images: [UIImage] = []
    var currentRemotePath: String!
   
    let witdhFormSheet: CGFloat = 540.0
    let heighFormSheet: CGFloat = 620.0
    
    let witdhImageSize: CGFloat = 150.0
    let heighImageSize: CGFloat = 150.0
    
    
    override func viewDidLoad() {
        
        InitializeDatabase.initDataBase()
        
        var delay = 0.1
        
        if ManageAppSettingsDB.isPasscode(){
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
                self.showPasscode()
                if ManageAppSettingsDB.isTouchID(){
                    ManageTouchID.sharedSingleton().showTouchIDAuth()
                }
            }
            
            delay = delay * 2
            
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
            self.showShareIn()
        }
 
    }

    override func viewWillLayoutSubviews() {
        
        super.viewWillLayoutSubviews()
        
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            self.navigationController?.view.bounds = CGRectMake(0, 0, witdhFormSheet, heighFormSheet)
            self.constraintTopTableView?.constant = -20
        }
        
    }
    
    func showPasscode() {
        
        let passcodeView = KKPasscodeViewController(nibName: nil, bundle: nil)
        passcodeView.delegate = self
        passcodeView.mode = UInt(KKPasscodeModeEnter)
        
        passcodeView.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Cancel, target: self, action: Selector("cancelView"))
        
        let ocNavController = OCNavigationController(rootViewController: passcodeView)
        ocNavController.modalPresentationStyle = UIModalPresentationStyle.FormSheet
        
        self.presentViewController(ocNavController, animated: false) { () -> Void in
            print("Passcode presented")
        }
        
        
    }
    
    func showShareIn() {
        
        self.createCustomInterface()
        
        self.shareTable!.registerClass(FileSelectedCell.self, forCellReuseIdentifier: "cell")
        
        self.loadFiles()
        
    }
    
    func createCustomInterface(){
        
        let rightBarButton = UIBarButtonItem (title:NSLocalizedString("upload_label", comment: ""), style: .Plain, target: self, action:"sendTheFilesToOwnCloud")
        let leftBarButton = UIBarButtonItem (title:NSLocalizedString("cancel", comment: ""), style: .Plain, target: self, action:"cancelView")
        
        let appName = NSBundle.mainBundle().infoDictionary?["CFBundleDisplayName"] as! String

        self.navigationItem.title = appName

        
        self.navigationItem.leftBarButtonItem = leftBarButton
        self.navigationItem.rightBarButtonItem = rightBarButton
        self.navigationItem.hidesBackButton = true
        
        self.changeTheDestinyFolderWith(appName)


    }
    
    func changeTheDestinyFolderWith(folder: String){
        
        var nameFolder = folder
        let location = NSLocalizedString("location", comment: "comment")
        if folder.isEmpty {
            let appName = NSBundle.mainBundle().infoDictionary?["CFBundleDisplayName"] as! String
            nameFolder = appName
        }

        if (nameFolder.characters.count > 20) {
            let nameFolderNSString = nameFolder as NSString
            nameFolder = nameFolderNSString.substringWithRange(NSRange(location: 0, length: 20))
            nameFolder += "..."
        }

        print("nameFolder: \(nameFolder)")

        let destiny = "\(location) \(nameFolder)"
        
        self.destinyFolderButton?.title = destiny
    }
    
    func cancelView() {
       
        self.extensionContext?.completeRequestReturningItems(nil, completionHandler: nil)
        return
       
    }
    
    func sendTheFilesToOwnCloud() {
        
        print("sendTheFilesToOwnCloud")
        
        let user = ManageUsersDB.getActiveUser()
        
        if user != nil {
            
            var hasSomethingToUpload: Bool = false
            
           for (index, url): (Int, NSURL) in (self.filesSelected.enumerate()){
                
                //1º Get the future name of the file
                
                let ext = FileNameUtils.getExtension(url.lastPathComponent)
                let type = FileNameUtils.checkTheTypeOfFile(ext)
                
                var fileName:String!
                
                let urlOriginalPath :String = (url.path! as NSString).stringByDeletingLastPathComponent
                var destinyMovedFilePath :String = UtilsUrls.getTempFolderForUploadFiles()
                
                fileName = (url.path! as NSString).lastPathComponent
                if type == kindOfFileEnum.imageFileType.rawValue || type == kindOfFileEnum.videoFileType.rawValue {
                    
                    if  urlOriginalPath != String(destinyMovedFilePath.characters.dropLast()) {
                        fileName = FileNameUtils.getComposeNameFromPath(url.path)
                    }
                }
                
                //2º Check filename 
            
                if !FileNameUtils.isForbiddenCharactersInFileName(fileName, withForbiddenCharactersSupported: ManageUsersDB.hasTheServerOfTheActiveUserForbiddenCharactersSupport()){
                    
                    //2º Copy the file to the tmp folder
                    destinyMovedFilePath = destinyMovedFilePath + fileName
                    if (destinyMovedFilePath as NSString).stringByDeletingLastPathComponent != urlOriginalPath {
                        do {
                            try NSFileManager.defaultManager().copyItemAtPath(url.path!, toPath: destinyMovedFilePath)
                        } catch _ {
                        }
                    }
                    
                    if currentRemotePath == nil {
                        currentRemotePath = UtilsUrls.getFullRemoteServerPathWithWebDav(user)
                    }
                    
                    //3º Crete the upload objects
                    print("remotePath: \(currentRemotePath)")
                    
                    let fileLength = (try! NSFileManager.defaultManager().attributesOfItemAtPath(url.path!))[NSFileSize] as! Int
                    print("fileLength: \(fileLength)")
                    
                    let upload = UploadsOfflineDto()
                    
                    upload.originPath = destinyMovedFilePath
                    upload.destinyFolder = currentRemotePath
                    upload.uploadFileName = fileName
                    upload.kindOfError = enumKindOfError.notAnError.rawValue
                    upload.estimateLength = fileLength
                    upload.userId = user.idUser
                    upload.status = enumUpload.generatedByDocumentProvider.rawValue
                    upload.chunksLength = Int(k_lenght_chunk)
                    upload.isNotNecessaryCheckIfExist = false
                    upload.isInternalUpload = false
                    upload.taskIdentifier = 0
                    
                    if index + 1 == self.filesSelected.count{
                        upload.isLastUploadFileOfThisArray = true
                        
                    }else{
                        upload.isLastUploadFileOfThisArray = false
                    }
                    

                    ManageUploadsDB.insertUpload(upload)
                    
                    hasSomethingToUpload = true
                    
                }else{
                    
                    var msg:String!
                    msg = NSLocalizedString("forbidden_characters_from_server", comment: "")
                
                    showAlertView(msg)
                    
                }
                
            }
            
            if hasSomethingToUpload == true {
                self.cancelView()
            }
            
        } else {
            showAlertView(NSLocalizedString("error_login_doc_provider", comment: ""))
        }
    }
    
    @IBAction func destinyFolderButtonTapped(sender: UIBarButtonItem) {
        print("destiny folder tapped")
        
        let activeUser = ManageUsersDB.getActiveUser()
        
        if activeUser != nil {
            let rootFileDto = ManageFilesDB.getRootFileDtoByUser(activeUser)
            
            let selectFolderViewController = SelectFolderViewController(nibName: "SelectFolderViewController", onFolder: rootFileDto)
            
            let navigation = SelectFolderNavigation(rootViewController: selectFolderViewController)
            
            navigation.delegate = self
            navigation.modalPresentationStyle = UIModalPresentationStyle.FormSheet
            
            selectFolderViewController.parent = navigation;
            
            self.presentViewController(navigation, animated: true) { () -> Void in
                print("select folder presented")
                //We check the connection here because we need to accept the certificate on the self signed server
                let mCheckAccessToServer = CheckAccessToServer()
                mCheckAccessToServer.delegate = selectFolderViewController
                mCheckAccessToServer.isConnectionToTheServerByUrl(activeUser.url)
            }
        } else {
            showAlertView(NSLocalizedString("error_login_doc_provider", comment: ""))
        }
    }
    
    
    func loadFiles() {
        
        if let inputItems : [NSExtensionItem] = self.extensionContext?.inputItems as? [NSExtensionItem] {
            for item : NSExtensionItem in inputItems {
                if let attachments = item.attachments as? [NSItemProvider] {
                    
                    if attachments.isEmpty {
                        self.extensionContext?.completeRequestReturningItems(nil, completionHandler: nil)
                        return
                    }

                    for (index, current) in (attachments.enumerate()){

                        //Items
                        if current.hasItemConformingToTypeIdentifier(kUTTypeItem as String){
                            
                            current.loadItemForTypeIdentifier(kUTTypeItem as String, options: nil, completionHandler: {(item, error) -> Void in
                                
                                if error == nil {
                                    if let url = item as? NSURL{
                                        
                                        print("item as url: \(item)")
                                        
                                        self.filesSelected.append(url)
                                        
                                        if index+1 == attachments.count{
                                            
                                            self.showFilesSelected()
                                        }
                                    }
                                    
                                    if let image = item as? NSData{
                                        
                                        print("item as NSdata")
                                        
                                        let description = current.description
                               
                                        var fullNameArr = description.componentsSeparatedByString("\"")
                                        var fileExtArr = fullNameArr[1].componentsSeparatedByString(".")
                                        let ext = (fileExtArr[fileExtArr.count-1]).uppercaseString
                                        let dateFormatter = NSDateFormatter()
                                        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
                                        let fileName = "Photo_email_\(dateFormatter.stringFromDate(NSDate())).\(ext)"
                                        
                                        //2º Copy the file to the tmp folder
                                        var destinyMovedFilePath = UtilsUrls.getTempFolderForUploadFiles()
                                        destinyMovedFilePath = destinyMovedFilePath + fileName
                                        
                                        NSFileManager.defaultManager().createFileAtPath(destinyMovedFilePath,contents:image, attributes:nil)
                                        
                                        let url = NSURL(fileURLWithPath: destinyMovedFilePath)
                                        
                                        self.filesSelected.append(url)
                                        
                                        if index+1 == attachments.count{
                                            
                                            self.showFilesSelected()
                                        }

                                    }
                                    
                                } else {
                                    print("ERROR: \(error)")
                                }
                                
                            })
                        
                        } 
                    }
                }
            }
        }
    }
    
    
    func reloadListWithDelay(){
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
            
            func reloadDatabase () {
                self.shareTable?.reloadData()
            }
            
            reloadDatabase()
        }
    }
    
    
    func showFilesSelected (){
        
        
        if self.filesSelected.count > 0{
            
            for (index, url): (Int, NSURL) in (self.filesSelected.enumerate()){
                
                //Check the type of the file
                
                let ext = FileNameUtils.getExtension(url.lastPathComponent)
                let type = FileNameUtils.checkTheTypeOfFile(ext)
                
                print("Selecte file: \(url.path)")
                
                var image: UIImage?
                
                if type == kindOfFileEnum.imageFileType.rawValue{
                    image = UIImage(contentsOfFile: url.path!)
                   
                } else if type == kindOfFileEnum.videoFileType.rawValue {
                    print("Video Selected")
                    
                    let asset = AVURLAsset (URL: url, options: nil)
                    let imageGenerator = AVAssetImageGenerator (asset: asset)
                    imageGenerator.appliesPreferredTrackTransform = true
                    let time = CMTimeMakeWithSeconds(0.0, 600)
                
                    let imageRef: CGImage!
                    do {
                        imageRef = try imageGenerator.copyCGImageAtTime(time, actualTime: nil)
                    } catch _ {
                        imageRef = nil
                    }
                    image = UIImage (CGImage: imageRef)

                }
                
                if image != nil{
                    
                    var resizedImage:UIImage?
                    
                    image?.resize(CGSizeMake(witdhImageSize, heighImageSize), completionHandler: { (resizedImage, data) -> () in
                        
                        self.images.append(resizedImage)
                        
                        if index+1 == self.filesSelected.count{
                            
                            self.reloadListWithDelay()
                        }
                        
                    })
                    
                }else{
                    
                    if index+1 == self.filesSelected.count{
                        
                     self.reloadListWithDelay()
                        
                    }
                }
 
            }
            
        }else{
            //Error any file selected
        }
    }
    
    //MARK: TableView Delegate and Datasource methods
    
    func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int
    {
        return self.filesSelected.count
    }
    
    func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell!
    {
        let identifier = "FileSelectedCell"
        let cell: FileSelectedCell! = tableView.dequeueReusableCellWithIdentifier(identifier ,forIndexPath: indexPath) as! FileSelectedCell
        
        let row = indexPath.row
        let url = self.filesSelected[row] as NSURL
        
        cell.selectionStyle = UITableViewCellSelectionStyle.None
        
        //Choose the correct icon if the file is not an image
        let ext = FileNameUtils.getExtension(url.lastPathComponent)
        let type = FileNameUtils.checkTheTypeOfFile(ext)
        
        if (type == kindOfFileEnum.imageFileType.rawValue || type == kindOfFileEnum.videoFileType.rawValue){
            //Image
            let fileName: NSString = (url.path! as NSString).lastPathComponent
            if row < images.count {
                cell.imageForFile?.image = images[indexPath.row];
            }
            if  !fileName.containsString("Photo_email") {
                cell.title?.text = FileNameUtils.getComposeNameFromPath(url.path)
            } else {
                cell.title?.text = fileName as String
            }
        }else{
            //Not image
            let image = UIImage(named: FileNameUtils.getTheNameOfTheImagePreviewOfFileName(url.lastPathComponent))
            cell.imageForFile?.image = image
            cell.imageForFile?.backgroundColor = UIColor.whiteColor()
            cell.title?.text = (url.path! as NSString).lastPathComponent
        }
        

        let fileSizeInBytes = (try! NSFileManager.defaultManager().attributesOfItemAtPath(url.path!))[NSFileSize] as? Double
        
        
        if fileSizeInBytes > 0 {
            let formattedFileSize = NSByteCountFormatter.stringFromByteCount(
                Int64(fileSizeInBytes!),
                countStyle: NSByteCountFormatterCountStyle.File
            )
            cell.size?.text = "\(formattedFileSize)"
        }else{
            cell.size?.text = ""
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView!, canEditRowAtIndexPath indexPath: NSIndexPath!) -> Bool
    {
        return false
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        print("row = %d",indexPath.row)
    }
    
    //MARK: Select Folder Selected Delegate Methods
    
    func folderSelected(folder: NSString){
        
        print("Folder selected \(folder)")
        
        self.currentRemotePath = folder as String
        let name:NSString = folder.stringByReplacingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
        let user = ManageUsersDB.getActiveUser()
        let folderPath = UtilsUrls.getFilePathOnDBByFullPath(name as String, andUser: user)

        self.changeTheDestinyFolderWith((folderPath as NSString).lastPathComponent)
        
    }
    
    func cancelFolderSelected(){
        
        print("Cancel folder selected")
        
    }
    
    func showAlertView(title: String) {
        
        let alert = UIAlertController(title: title, message: "", preferredStyle: UIAlertControllerStyle.Alert)
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .Default, handler: { action in
            switch action.style{
            case .Default:
                self.cancelView()
            case .Cancel:
                print("cancel")
            case .Destructive:
                print("destructive")
            }
        }))
        
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    //MARK: KKPasscodeViewControllerDelegate
    
    func didPasscodeEnteredCorrectly(viewController: KKPasscodeViewController!) {
        print("Did passcode entered correctly")
    }
    
   
    func didPasscodeEnteredIncorrectly(viewController: KKPasscodeViewController!) {
        print("Did passcode entered incorrectly")
    }

}



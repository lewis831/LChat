//
//  ChatViewController.swift
//  GoChat
//
//  Created by Lewis Rashe on 4/13/17.
//  Copyright © 2017 Lewis Rashe. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import MobileCoreServices
import AVKit
import FirebaseDatabase
import FirebaseStorage
import FirebaseAuth
import SDWebImage

class ChatViewController: JSQMessagesViewController {
    
    var messages = [JSQMessage]()
    var avatarDict = [String: JSQMessagesAvatarImage]()
    var messageRef = FIRDatabase.database().reference().child("messages")

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let currentUser = FIRAuth.auth()?.currentUser
        {
            self.senderId = currentUser.uid
            
            if currentUser.isAnonymous == true
            {
                self.senderDisplayName = "anonymous"
            } else
            {
                self.senderDisplayName = "\(currentUser.displayName!)"
            }
            
        }
        
        observeMessages()
    }
    
    func observeUsers(_ id: String)
    {
        FIRDatabase.database().reference().child("users").child(id).observe(.value, with: {
            snapshot in
            if let dict = snapshot.value as? [String: AnyObject]
            {
                let avatarUrl = dict["profileUrl"] as! String
                
                self.setupAvatar(avatarUrl, messageId: id)
            }
        })
        
    }
    
    func setupAvatar(_ url: String, messageId: String)
    {
        if url != "" {
            let fileUrl = URL(string: url)
            let data = try? Data(contentsOf: fileUrl!)
            let image = UIImage(data: data!)
            let userImg = JSQMessagesAvatarImageFactory.avatarImage(with: image, diameter: 30)
            self.avatarDict[messageId] = userImg
            
        } else {
            avatarDict[messageId] = JSQMessagesAvatarImageFactory.avatarImage(with: UIImage(named: "profileImage"), diameter: 30)
        }
        collectionView.reloadData()
    }
    
    func observeMessages() {
        messageRef.observe(.childAdded, with: { snapshot in
            // print(snapshot.value)
            if let dict = snapshot.value as? [String: AnyObject] {
                let mediaType = dict["MediaType"] as! String
                let senderId = dict["senderId"] as! String
                let senderName = dict["senderName"] as! String
                //let startTime = CFAbsoluteTimeGetCurrent()
                
                self.observeUsers(senderId)
                
                switch mediaType {
                    
                case "TEXT":
                    
                    let text = dict["text"] as! String
                    self.messages.append(JSQMessage(senderId: senderId, displayName: senderName, text: text))
                    //print("Text message: \(CFAbsoluteTimeGetCurrent() - startTime)")
                    
                case "PHOTO":
                    
                    //Faster and easier than grand central dispatch which can be hard to use
                    //Link to this GitHub resource: https://github.com/lewis831/SDWebImage
                    //Uses import SDWebImage
                    let photo = JSQPhotoMediaItem(image: nil)
                    let fileUrl = dict["fileUrl"] as! String
                    let downloader = SDWebImageDownloader.shared()
                    downloader.downloadImage(with: URL(string: fileUrl)!, options: [], progress: nil, completed: { (image, data, error, finished) in
                        print(Thread())
                        DispatchQueue.main.async(execute: {
                            let image = UIImage(data: data!)
                            photo?.image = image
                            self.collectionView.reloadData()
                        })
                    })
                    
                    self.messages.append(JSQMessage(senderId: senderId, displayName: senderName, media: photo))
                    //print("Photo message: \(CFAbsoluteTimeGetCurrent() - startTime)")
                    
                    if self.senderId == senderId {
                        photo?.appliesMediaViewMaskAsOutgoing = true
                    } else {
                        photo?.appliesMediaViewMaskAsOutgoing = false
                    }
                    
                    
                case "VIDEO":
                    
                    let fileUrl = dict["fileUrl"] as! String
                    let video = URL(string: fileUrl)!
                    let videoItem = JSQVideoMediaItem(fileURL: video, isReadyToPlay: true)
                    self.messages.append(JSQMessage(senderId: senderId, displayName: senderName, media: videoItem))
                    //print("Video message: \(CFAbsoluteTimeGetCurrent() - startTime)")
                    
                    if self.senderId == senderId {
                        videoItem?.appliesMediaViewMaskAsOutgoing = true
                    } else {
                        videoItem?.appliesMediaViewMaskAsOutgoing = false
                    }
                    
                default:
                    print("unknown data type")
                    
                }
                
                self.collectionView.reloadData()
                
            }
        })
    }
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        //        messages.append(JSQMessage(senderId: senderId, displayName: senderDisplayName, text: text))
        //        collectionView.reloadData()
        //        print(messages)
        let newMessage = messageRef.childByAutoId()
        let messageData = ["text": text, "senderId": senderId, "senderName": senderDisplayName, "MediaType": "TEXT"]
        newMessage.setValue(messageData)
        self.finishSendingMessage()
    }
    
    override func didPressAccessoryButton(_ sender: UIButton!) {
        print("didPressAccessoryButton")
        
        let sheet = UIAlertController(title: "Media Messages", message: "Please select a media", preferredStyle: UIAlertControllerStyle.actionSheet)
        let cancel = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { (alert:UIAlertAction) in
            
        }
        
        let photoLibrary = UIAlertAction(title: "Photo Library", style: UIAlertActionStyle.default) { (alert: UIAlertAction) in
            self.getMediaFrom(kUTTypeImage)
        }
        
        let videoLibrary = UIAlertAction(title: "Video Library", style: UIAlertActionStyle.default) { (alert: UIAlertAction) in
            self.getMediaFrom(kUTTypeMovie)
            
        }
        
        
        sheet.addAction(photoLibrary)
        sheet.addAction(videoLibrary)
        sheet.addAction(cancel)
        self.present(sheet, animated: true, completion: nil)
        
        //        let imagePicker = UIImagePickerController()
        //        imagePicker.delegate = self
        //        self.presentViewController(imagePicker, animated: true, completion: nil)
    }
    
    func getMediaFrom(_ type: CFString) {
        print(type)
        let mediaPicker = UIImagePickerController()
        mediaPicker.delegate = self
        mediaPicker.mediaTypes = [type as String]
        self.present(mediaPicker, animated: true, completion: nil)
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item]
        let bubbleFactory = JSQMessagesBubbleImageFactory()
        if message.senderId == self.senderId {
            
            return bubbleFactory!.outgoingMessagesBubbleImage(with: .black)
        } else {
            
            return bubbleFactory!.incomingMessagesBubbleImage(with: .blue)
            
        }
        
        
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        let message = messages[indexPath.item]
        
        return avatarDict[message.senderId]
        //return JSQMessagesAvatarImageFactory.avatarImageWithImage(UIImage(named: "profileImage"), diameter: 30)
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print("number of item:\(messages.count)")
        return messages.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        
        return cell
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAt indexPath: IndexPath!) {
        print("didTapMessageBubbleAtIndexPath: \(indexPath.item)")
        let message = messages[indexPath.item]
        if message.isMediaMessage {
            if let mediaItem = message.media as? JSQVideoMediaItem {
                let player = AVPlayer(url: mediaItem.fileURL)
                let playerViewController = AVPlayerViewController()
                playerViewController.player = player
                self.present(playerViewController, animated: true, completion: nil)
                
            }
        }
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    @IBAction func logoutDidTapped(_ sender: AnyObject) {
        
        do {
            try FIRAuth.auth()?.signOut()
        } catch let error {
            print(error)
        }
        
        // Create a main storyboard instance
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        // From main storyboard instantiate a View controller
        let LogInVC = storyboard.instantiateViewController(withIdentifier: "LogInVC") as! LoginViewController
        
        // Get the app delegate
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        // Set LogIn View Controller as root view controller
        appDelegate.window?.rootViewController = LogInVC
    }
    
    func sendMedia(_ picture: UIImage?, video: URL?) {
        print(picture as Any)
        print(FIRStorage.storage().reference())
        if let picture = picture {
            let filePath = "\(String(describing: FIRAuth.auth()!.currentUser))/\(Date.timeIntervalSinceReferenceDate)"
            print(filePath)
            let data = UIImageJPEGRepresentation(picture, 0.1)
            let metadata = FIRStorageMetadata()
            metadata.contentType = "image/jpg"
            FIRStorage.storage().reference().child(filePath).put(data!, metadata: metadata) { (metadata, error)
                in
                if error != nil {
                    print(error?.localizedDescription as Any)
                    return
                }
                
                let fileUrl = metadata!.downloadURLs![0].absoluteString
                
                let newMessage = self.messageRef.childByAutoId()
                let messageData = ["fileUrl": fileUrl, "senderId": self.senderId, "senderName": self.senderDisplayName, "MediaType": "PHOTO"]
                newMessage.setValue(messageData)
                
            }
            
        } else if let video = video {
            let filePath = "\(String(describing: FIRAuth.auth()!.currentUser))/\(Date.timeIntervalSinceReferenceDate)"
            print(filePath)
            let data = try? Data(contentsOf: video)
            let metadata = FIRStorageMetadata()
            metadata.contentType = "video/mp4"
            FIRStorage.storage().reference().child(filePath).put(data!, metadata: metadata) { (metadata, error)
                in
                if error != nil {
                    print(error?.localizedDescription as Any)
                    return
                }
                
                let fileUrl = metadata!.downloadURLs![0].absoluteString
                
                let newMessage = self.messageRef.childByAutoId()
                let messageData = ["fileUrl": fileUrl, "senderId": self.senderId, "senderName": self.senderDisplayName, "MediaType": "VIDEO"]
                newMessage.setValue(messageData)
                
            }
        }
    }
}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        print("did finish picking")
        // get the image
        print(info)
        if let picture = info[UIImagePickerControllerOriginalImage] as? UIImage {
            
            sendMedia(picture, video: nil)
        }
        else if let video = info[UIImagePickerControllerMediaURL] as? URL {
            
            sendMedia(nil, video: video)
            
        }
        
        self.dismiss(animated: true, completion: nil)
        collectionView.reloadData()
        
        
    }
}




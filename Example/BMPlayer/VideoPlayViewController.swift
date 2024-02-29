//
//  VideoPlayViewController.swift
//  BMPlayer
//
//  Created by BrikerMan on 16/4/28.
//  Copyright © 2016年 CocoaPods. All rights reserved.
//

import UIKit
import BMPlayer
import AVFoundation
import NVActivityIndicatorView
import Photos
import MobileCoreServices

func delay(_ seconds: Double, completion:@escaping ()->()) {
    let popTime = DispatchTime.now() + Double(Int64( Double(NSEC_PER_SEC) * seconds )) / Double(NSEC_PER_SEC)
    
    DispatchQueue.main.asyncAfter(deadline: popTime) {
        completion()
    }
}

class VideoPlayViewController: UIViewController {
    
    //    @IBOutlet weak var player: BMPlayer!
    
    var player: BMPlayer!
    
    var index: IndexPath!
    
    var changeButton = UIButton()
    
    let defaultSession = URLSession(configuration: .default)
    var dataTask: URLSessionDataTask? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayerManager()
        preparePlayer()
        setupPlayerResource()
        
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        
        player.didPauseBlock = { [weak self] second in
            print("did pause \(second)")
        }
        
        player.didPlayBlock = { [weak self] second in
            print("did play \(second)")
        }
        
        player.didSeekBlock = { [weak self] from, to in
            print("did seek \(from) to \(to)")
        }
    }
    
    @objc func applicationWillEnterForeground() {
        
    }
    
    @objc func applicationDidEnterBackground() {
        player.pause(allowAutoPlay: false)
    }
    
    /**
     prepare playerView
     */
    func preparePlayer() {
        var controller: BMPlayerControlView? = nil
        
        if index.row == 0 && index.section == 2 {
            controller = BMPlayerCustomControlView()
        }
        
        if index.row == 1 && index.section == 2 {
            controller = BMPlayerCustomControlView2()
        }
        
        player = BMPlayer(customControlView: controller)
        view.addSubview(player)
        
        player.snp.makeConstraints { (make) in
            make.top.equalTo(view.snp.top)
            make.left.equalTo(view.snp.left)
            make.right.equalTo(view.snp.right)
            make.bottom.equalTo(view.snp.bottom)
        }
        
        player.delegate = self
        player.backBlock = { [unowned self] (isFullScreen) in
            if isFullScreen {
                return
            } else {
                self.dismiss(animated: true, completion: nil)
            }
        }
        
        player.downloadBlock = { [unowned self] url in
            self.downloadAndSaveVideoToGallery(videoURL: url)
        }
        
        changeButton.setTitle("Change Video", for: .normal)
        changeButton.addTarget(self, action: #selector(onChangeVideoButtonPressed), for: .touchUpInside)
        changeButton.backgroundColor = UIColor.red.withAlphaComponent(0.7)
        view.addSubview(changeButton)
        
        changeButton.snp.makeConstraints { (make) in
            make.top.equalTo(player.snp.bottom).offset(30)
            make.left.equalTo(view.snp.left).offset(10)
        }
        changeButton.isHidden = true
        self.view.layoutIfNeeded()
    }
    
    func downloadAndSaveVideoToGallery(videoURL: String) {
        guard let url = URL(string: videoURL) else { return }
        
        let configuration = URLSessionConfiguration.default
        let operationQueue = OperationQueue()
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: operationQueue)
        
        let downloadTask = session.downloadTask(with: url)
        downloadTask.resume()
        
    }
    
    @objc fileprivate func onChangeVideoButtonPressed() {
        let urls = ["http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"]
        let random = Int(arc4random_uniform(UInt32(urls.count)))
        let asset = BMPlayerResource(url: URL(string: urls[random])!, name: "Video @\(random)")
        player.setVideo(resource: asset)
    }
    
    
    func setupPlayerResource() {
        switch (index.section,index.row) {
            
        case (0,0):
            let str = Bundle.main.url(forResource: "SubtitleDemo", withExtension: "srt")!
            let url = URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!
            
            let subtitle = BMSubtitles(url: str)
            
            let asset = BMPlayerResource(url: url)
            
            // How to change subtiles
            //            delay(5, completion: {
            //                if let resource = self.player.currentResource {
            //                    resource.subtitle = nil
            //                    self.player.forceReloadSubtile()
            //                }
            //            })
            //
            //            delay(10, completion: {
            //                if let resource = self.player.currentResource {
            //                    resource.subtitle = BMSubtitles(url: Bundle.main.url(forResource: "SubtitleDemo2", withExtension: "srt")!)
            //                }
            //            })
            //
            //
            //            // How to change get current uel
            //            delay(5, completion: {
            //                if let resource = self.player.currentResource {
            //                    for i in resource.definitions {
            //                        print("video \(i.definition) url is \(i.url)")
            //                    }
            //                }
            //            })
            //
//            player.seek(30)
            player.setVideo(resource: asset)
            changeButton.isHidden = false
            
        case (0,1):
            let asset = self.preparePlayerItem()
            player.setVideo(resource: asset)
            
        case (0,2):
            let asset = self.preparePlayerItem()
            player.setVideo(resource: asset)
            
        case (2,0):
//            player.panGesture.isEnabled = false
            let asset = self.preparePlayerItem()
            player.setVideo(resource: asset)
            
        case (2,1):
            player.videoGravity = AVLayerVideoGravity.resizeAspect
            let asset = BMPlayerResource(url: URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!, name: "风格互换：原来你我相爱")
            player.setVideo(resource: asset)
            
        default:
            let asset = self.preparePlayerItem()
            player.setVideo(resource: asset)
        }
    }
    
    // 设置播放器单例，修改属性
    func setupPlayerManager() {
        resetPlayerManager()
        switch (index.section,index.row) {
            // 普通播放器
        case (0,0):
            break
        case (0,1):
            break
        case (0,2):
            // 设置播放器属性，此情况下若提供了cover则先展示封面图，否则黑屏。点击播放后开始loading
            BMPlayerConf.shouldAutoPlay = false
            
        case (1,0):
            // 设置播放器属性，此情况下若提供了cover则先展示封面图，否则黑屏。点击播放后开始loading
            BMPlayerConf.topBarShowInCase = .always
            
            
        case (1,1):
            BMPlayerConf.topBarShowInCase = .horizantalOnly
            
            
        case (1,2):
            BMPlayerConf.topBarShowInCase = .none
            
        case (1,3):
            BMPlayerConf.tintColor = UIColor.red
            
        default:
            break
        }
    }
    
    
    /**
     准备播放器资源model
     */
    func preparePlayerItem() -> BMPlayerResource {
        let res0 = BMPlayerResourceDefinition(url: URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!,
                                              definition: "高清")
        let res1 = BMPlayerResourceDefinition(url: URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!,
                                              definition: "标清")
        
        let asset = BMPlayerResource(name: "周末号外丨中国第一高楼",
                                     definitions: [res0, res1],
                                     cover: URL(string: "http://img.wdjimg.com/image/video/447f973848167ee5e44b67c8d4df9839_0_0.jpeg"))
        return asset
    }
    
    
    func resetPlayerManager() {
        BMPlayerConf.allowLog = false
//        BMPlayerConf.shouldAutoPlay = true
        BMPlayerConf.tintColor = UIColor.white
        BMPlayerConf.topBarShowInCase = .always
        BMPlayerConf.loaderType  = NVActivityIndicatorType.ballRotateChase
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.setStatusBarStyle(UIStatusBarStyle.default, animated: false)
        // If use the slide to back, remember to call this method
        // 使用手势返回的时候，调用下面方法
        player.pause(allowAutoPlay: true)
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.setStatusBarStyle(UIStatusBarStyle.lightContent, animated: false)
        // If use the slide to back, remember to call this method
        // 使用手势返回的时候，调用下面方法
        player.autoPlay()
    }
    
    deinit {
        // If use the slide to back, remember to call this method
        // 使用手势返回的时候，调用下面方法手动销毁
        player.prepareToDealloc()
        print("VideoPlayViewController Deinit")
    }
    
}

// MARK:- BMPlayerDelegate example
extension VideoPlayViewController: BMPlayerDelegate {
    // Call when player orinet changed
    func bmPlayer(player: BMPlayer, playerOrientChanged isFullscreen: Bool) {
        player.snp.remakeConstraints { (make) in
            make.top.equalTo(view.snp.top)
            make.left.equalTo(view.snp.left)
            make.right.equalTo(view.snp.right)
            make.bottom.equalTo(view.snp.bottom)
        }
    }
    
    // Call back when playing state changed, use to detect is playing or not
    func bmPlayer(player: BMPlayer, playerIsPlaying playing: Bool) {
        print("| BMPlayerDelegate | playerIsPlaying | playing - \(playing)")
    }
    
    // Call back when playing state changed, use to detect specefic state like buffering, bufferfinished
    func bmPlayer(player: BMPlayer, playerStateDidChange state: BMPlayerState) {
        print("| BMPlayerDelegate | playerStateDidChange | state - \(state)")
    }
    
    // Call back when play time change
    func bmPlayer(player: BMPlayer, playTimeDidChange currentTime: TimeInterval, totalTime: TimeInterval) {
        //        print("| BMPlayerDelegate | playTimeDidChange | \(currentTime) of \(totalTime)")
    }
    
    // Call back when the video loaded duration changed
    func bmPlayer(player: BMPlayer, loadedTimeDidChange loadedDuration: TimeInterval, totalDuration: TimeInterval) {
        //        print("| BMPlayerDelegate | loadedTimeDidChange | \(loadedDuration) of \(totalDuration)")
    }
}

extension VideoPlayViewController: URLSessionDownloadDelegate {
    
    func readDownloadedData(of url: URL) -> Data? {
        do {
            let reader = try FileHandle(forReadingFrom: url)
            let data = reader.readDataToEndOfFile()
            
            return data
        } catch {
            print(error)
            return nil
        }
    }
    
    // MARK: protocol stub for download completion tracking
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        let url = downloadTask.response?.url?.lastPathComponent
        if (url?.hasSuffix(".mp4"))! {
            guard let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            
            if !FileManager.default.fileExists(atPath: documentsDirectoryURL.appendingPathComponent((downloadTask.response?.url?.lastPathComponent)!).path) {
                
                let destinationURL = documentsDirectoryURL.appendingPathComponent(downloadTask.response?.suggestedFilename ?? ((downloadTask.response?.url)?.lastPathComponent)!)
                
                do {
                    try? FileManager.default.removeItem(at: destinationURL)
                    try FileManager.default.moveItem(at: location, to: destinationURL)
                    PHPhotoLibrary.requestAuthorization({(authorizationStatus: PHAuthorizationStatus) -> Void in
                        
                        // check if user authorized access photos for your app
                        if authorizationStatus == .authorized {
                            PHPhotoLibrary.shared().performChanges({
                                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: destinationURL)
                            })
                            {  completed, error in
                                if completed {
                                    DispatchQueue.main.async {
                                        print("Video saved")
                                    }
                                    
                                } else {
                                    print(error as Any)
                                }
                            }
                        }
                    })
                    
                } catch { print(error) }
                
            } else {
                
                let destinationURL = documentsDirectoryURL.appendingPathComponent(downloadTask.response?.suggestedFilename ?? ((downloadTask.response?.url)?.lastPathComponent)!)
                
                do {
                    try FileManager.default.removeItem(at: destinationURL)
                    try FileManager.default.moveItem(at: location, to: destinationURL)
                    PHPhotoLibrary.requestAuthorization({(authorizationStatus: PHAuthorizationStatus) -> Void in
                        // check if user authorized access photos for your app
                        if authorizationStatus == .authorized {
                            PHPhotoLibrary.shared().performChanges({
                                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: destinationURL)
                                
                            })
                            {  completed, error in
                                if completed {
                                    DispatchQueue.main.async {
                                        print("Video saved")
                                    }
                                    
                                } else {
                                    print(error as Any)
                                }
                            }
                        }
                    })
                } catch {print(error)}
                
            }
        } else {
            
        }
    }
    
    // MARK: protocol stubs for tracking download progress
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        let percentDownloaded = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        player.downloadProcess(percent: percentDownloaded)
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        
        player.downloadProcess(percent: 1.0)
    }
    
    
}

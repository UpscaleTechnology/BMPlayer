//
//  BMPlayerControlView.swift
//  Pods
//
//  Created by BrikerMan on 16/4/29.
//
//

import UIKit
import NVActivityIndicatorView


@objc public protocol BMPlayerControlViewDelegate: AnyObject {
    /**
     call when control view choose a definition
     
     - parameter controlView: control view
     - parameter index:       index of definition
     */
    func controlView(controlView: BMPlayerControlView, didChooseDefinition index: Int)
    
    /**
     call when control view pressed an button
     
     - parameter controlView: control view
     - parameter button:      button type
     */
    func controlView(controlView: BMPlayerControlView, didPressButton button: UIButton)
    
    /**
     call when slider action trigged
     
     - parameter controlView: control view
     - parameter slider:      progress slider
     - parameter event:       action
     */
    func controlView(controlView: BMPlayerControlView, slider: UISlider, onSliderEvent event: UIControl.Event)
    
    /**
     call when needs to change playback rate
     
     - parameter controlView: control view
     - parameter rate:        playback rate
     */
    @objc optional func controlView(controlView: BMPlayerControlView, didChangeVideoPlaybackRate rate: Float)
}

open class BMPlayerControlView: UIView {
    
    open weak var delegate: BMPlayerControlViewDelegate?
    open weak var player: BMPlayer?
    
    // MARK: Variables
    open var resource: BMPlayerResource?
    
    open var selectedIndex = 0
    open var isFullscreen  = false
    open var isMaskShowing = true
    
    open var totalDuration: TimeInterval = 0
    open var delayItem: DispatchWorkItem?
    
    var playerLastState: BMPlayerState = .notSetURL
    
    fileprivate var isSelectDefinitionViewOpened = false
    
    // MARK: UI Components
    /// main views which contains the topMaskView and bottom mask view
    open var mainMaskView   = UIView()
    open var topMaskView    = UIView()
    open var bottomMaskView = UIView()
    
    /// Image view to show video cover
    open var maskImageView = UIImageView()
    
    /// top views
    open var topWrapperView = UIView()
    open var backButton = UIButton(type : UIButton.ButtonType.custom)
    open var titleLabel = UILabel()
    open var chooseDefinitionView = UIView()
    open var moreButton = UIButton(type : UIButton.ButtonType.custom)
    
    /// bottom view
    open var bottomWrapperView = UIView()
    open var currentTimeLabel = UILabel()
    open var totalTimeLabel   = UILabel()
    
    /// Progress slider
    open var timeSlider = BMTimeSlider()
    
    /// load progress view
    open var progressView = UIProgressView()
    
    /// download progress view
    open var downloadProgressView = CircularProgressBarView()
    
    open var isDownloading: Bool = false
    
    /* play button
     playButton.isSelected = player.isPlaying
     */
    open var playButton = UIButton(type: UIButton.ButtonType.custom)
    
    /* fullScreen button
     fullScreenButton.isSelected = player.isFullscreen
     */
    open var downloadButton = UIButton(type: UIButton.ButtonType.custom)
    
    /* CC button for subtitle control
     ccButton.isSelected = subtitlesEnabled
     */
    open var ccButton = UIButton(type: UIButton.ButtonType.custom)
    
    open var subtitleLabel    = UILabel()
    open var subtitleBackView = UIView()
    open var subtileAttribute: [NSAttributedString.Key : Any]?
    
    /// Subtitle state management
    open var subtitlesEnabled: Bool = true {
        didSet {
            ccButton.isSelected = subtitlesEnabled
            if !subtitlesEnabled {
                subtitleBackView.isHidden = true
            }
            customizeUIComponents()
        }
    }
    
    /// Activty Indector for loading
    open var loadingIndicator  = NVActivityIndicatorView(frame:  CGRect(x: 0, y: 0, width: 30, height: 30))
    
    open var seekToView       = UIView()
    open var seekToViewImage  = UIImageView()
    open var seekToLabel      = UILabel()
    
    open var replayButton     = UIButton(type: UIButton.ButtonType.custom)
    
    /// Gesture used to show / hide control view
    open var tapGesture: UITapGestureRecognizer!
    open var doubleTapGesture: UITapGestureRecognizer!
    
    // MARK: - handle player state change
    /**
     call on when play time changed, update duration here
     
     - parameter currentTime: current play time
     - parameter totalTime:   total duration
     */
    open func playTimeDidChange(currentTime: TimeInterval, totalTime: TimeInterval) {
        currentTimeLabel.text = BMPlayer.formatSecondsToString(currentTime)
        totalTimeLabel.text   = BMPlayer.formatSecondsToString(totalTime)
        timeSlider.value      = Float(currentTime) / Float(totalTime)
        showSubtile(from: resource?.subtitle, at: currentTime)
    }
    
    
    /**
     change subtitle resource
     
     - Parameter subtitles: new subtitle object
     */
    open func update(subtitles: BMSubtitles?) {
        resource?.subtitle = subtitles
        
        // Update CC button visibility based on subtitle availability
//        ccButton.isHidden = subtitles == nil
        if subtitles != nil {
            subtitlesEnabled = true
        }
    }
    
    /**
     call on load duration changed, update load progressView here
     
     - parameter loadedDuration: loaded duration
     - parameter totalDuration:  total duration
     */
    open func loadedTimeDidChange(loadedDuration: TimeInterval, totalDuration: TimeInterval) {
        progressView.setProgress(Float(loadedDuration)/Float(totalDuration), animated: true)
    }
    
    open func playerStateDidChange(state: BMPlayerState) {
        switch state {
        case .readyToPlay:
            hideLoader()
            // Update subtitle position when video is ready
            updateSubtitlePosition()
            
        case .buffering:
            showLoader()
            
        case .bufferFinished:
            hideLoader()
            
        case .playedToTheEnd:
            playButton.isSelected = false
            showPlayToTheEndView()
            controlViewAnimation(isShow: true)
            
        default:
            break
        }
        playerLastState = state
    }
    
    /**
     Call when User use the slide to seek function
     
     - parameter toSecound:     target time
     - parameter totalDuration: total duration of the video
     - parameter isAdd:         isAdd
     */
    open func showSeekToView(to toSecound: TimeInterval, total totalDuration:TimeInterval, isAdd: Bool) {
        seekToView.isHidden = false
        seekToLabel.text    = BMPlayer.formatSecondsToString(toSecound)
        
        let rotate = isAdd ? 0 : CGFloat(Double.pi)
        seekToViewImage.transform = CGAffineTransform(rotationAngle: rotate)
        
        let targetTime = BMPlayer.formatSecondsToString(toSecound)
        timeSlider.value = Float(toSecound / totalDuration)
        currentTimeLabel.text = targetTime
    }
    
    // MARK: - UI update related function
    /**
     Update UI details when player set with the resource
     
     - parameter resource: video resouce
     - parameter index:    defualt definition's index
     */
    open func prepareUI(for resource: BMPlayerResource, selectedIndex index: Int) {
        self.resource = resource
        self.selectedIndex = index
        titleLabel.text = resource.name
        prepareChooseDefinitionView()
        
        // Show/hide CC button based on subtitle availability
//        ccButton.isHidden = resource.subtitle == nil
        subtitlesEnabled = resource.subtitle != nil
        
        autoFadeOutControlViewWithAnimation()
    }
    
    open func playStateDidChange(isPlaying: Bool) {
        autoFadeOutControlViewWithAnimation()
        playButton.isSelected = isPlaying
    }
    
    /**
     auto fade out controll view with animtion
     */
    open func autoFadeOutControlViewWithAnimation() {
        cancelAutoFadeOutAnimation()
        delayItem = DispatchWorkItem { [weak self] in
            if self?.playerLastState != .playedToTheEnd {
                self?.controlViewAnimation(isShow: false)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + BMPlayerConf.animateDelayTimeInterval,
                                      execute: delayItem!)
    }
    
    /**
     cancel auto fade out controll view with animtion
     */
    open func cancelAutoFadeOutAnimation() {
        delayItem?.cancel()
    }
    
    /**
     Implement of the control view animation, override if need's custom animation
     
     - parameter isShow: is to show the controlview
     */
    open func controlViewAnimation(isShow: Bool) {
        
        if isDownloading { return }
        
        let alpha: CGFloat = isShow ? 1.0 : 0.0
        self.isMaskShowing = isShow
        
        UIApplication.shared.setStatusBarHidden(!isShow, with: .fade)
        
        UIView.animate(withDuration: 0.3, animations: {[weak self] in
            guard let wSelf = self else { return }
            wSelf.topMaskView.alpha    = alpha
            wSelf.bottomMaskView.alpha = alpha
            wSelf.mainMaskView.backgroundColor = UIColor(white: 0, alpha: isShow ? 0.4 : 0.0)
            
            if isShow {
                if wSelf.isFullscreen { wSelf.chooseDefinitionView.alpha = 1.0 }
            } else {
                wSelf.replayButton.isHidden = true
                wSelf.chooseDefinitionView.snp.updateConstraints { (make) in
                    make.height.equalTo(35)
                }
                wSelf.chooseDefinitionView.alpha = 0.0
            }
            wSelf.layoutIfNeeded()
        }) { [weak self](_) in
            if isShow {
                self?.autoFadeOutControlViewWithAnimation()
            }
        }
    }
    
    /**
     Implement of the UI update when screen orient changed
     
     - parameter isForFullScreen: is for full screen
     */
    open func updateUI(_ isForFullScreen: Bool) {
        isFullscreen = isForFullScreen
        chooseDefinitionView.isHidden = !BMPlayerConf.enableChooseDefinition || !isForFullScreen
        if isForFullScreen {
            if BMPlayerConf.topBarShowInCase.rawValue == 2 {
                topMaskView.isHidden = true
            } else {
                topMaskView.isHidden = false
            }
        } else {
            if BMPlayerConf.topBarShowInCase.rawValue >= 1 {
                topMaskView.isHidden = true
            } else {
                topMaskView.isHidden = false
            }
        }
        
        // Update subtitle position when UI changes
        updateSubtitlePosition()
    }
    
    /**
     Call when video play's to the end, override if you need custom UI or animation when played to the end
     */
    open func showPlayToTheEndView() {
        replayButton.isHidden = false
    }
    
    open func hidePlayToTheEndView() {
        replayButton.isHidden = true
    }
    
    open func showLoader() {
        loadingIndicator.isHidden = false
        loadingIndicator.startAnimating()
    }
    
    open func hideLoader() {
        loadingIndicator.isHidden = true
    }
    
    open func hideSeekToView() {
        seekToView.isHidden = true
    }
    
    open func showCoverWithLink(_ cover:String) {
        self.showCover(url: URL(string: cover))
    }
    
    open func showCover(url: URL?) {
        if let url = url {
            DispatchQueue.global(qos: .default).async { [weak self] in
                let data = try? Data(contentsOf: url)
                DispatchQueue.main.async(execute: { [weak self] in
                    guard let `self` = self else { return }
                    if let data = data {
                        self.maskImageView.image = UIImage(data: data)
                    } else {
                        self.maskImageView.image = nil
                    }
                    self.hideLoader()
                });
            }
        }
    }
    
    open func hideCoverImageView() {
        self.maskImageView.isHidden = true
    }
    
    open func prepareChooseDefinitionView() {
        guard let resource = resource else {
            return
        }
        for item in chooseDefinitionView.subviews {
            item.removeFromSuperview()
        }
        
        for i in 0..<resource.definitions.count {
            let button = BMPlayerClearityChooseButton()
            
            if i == 0 {
                button.tag = selectedIndex
            } else if i <= selectedIndex {
                button.tag = i - 1
            } else {
                button.tag = i
            }
            
            button.setTitle("\(resource.definitions[button.tag].definition)", for: UIControl.State())
            chooseDefinitionView.addSubview(button)
            button.addTarget(self, action: #selector(self.onDefinitionSelected(_:)), for: UIControl.Event.touchUpInside)
            button.snp.makeConstraints({ [weak self](make) in
                guard self != nil else { return }
                make.top.equalTo(chooseDefinitionView.snp.top).offset(35 * i)
                make.width.equalTo(50)
                make.height.equalTo(25)
                make.centerX.equalTo(chooseDefinitionView)
            })
            
            if resource.definitions.count == 1 {
                button.isEnabled = false
                button.isHidden = true
            }
        }
    }
    
    open func prepareToDealloc() {
        self.delayItem = nil
    }
    
    // MARK: - Action Response
    /**
     Call when some action button Pressed
     
     - parameter button: action Button
     */
    @objc open func onButtonPressed(_ button: UIButton) {
        autoFadeOutControlViewWithAnimation()
        if let type = ButtonType(rawValue: button.tag) {
            switch type {
            case .play, .replay:
                if playerLastState == .playedToTheEnd {
                    hidePlayToTheEndView()
                }
            case .download:
                downloadButton.isHidden = true
                bottomWrapperView.addSubview(downloadProgressView)
                downloadProgressView.snp.makeConstraints { [unowned self](make) in
                    make.width.equalTo(30)
                    make.height.equalTo(30)
                    make.centerY.equalTo(self.currentTimeLabel)
                    make.right.equalTo(-8)
                }
            case .cc:
                if resource?.subtitle == nil {
                    // No subtitles, show toast and do not enable
                    ccButton.isSelected = false
                    if let view = self.window ?? self.superview {
                        let toast = UILabel()
                        toast.text = "No subtitles available"
                        toast.textColor = .white
                        toast.backgroundColor = UIColor.black.withAlphaComponent(0.8)
                        toast.textAlignment = .center
                        toast.font = UIFont.systemFont(ofSize: 14, weight: .medium)
                        toast.layer.cornerRadius = 8
                        toast.clipsToBounds = true
                        toast.alpha = 0
                        view.addSubview(toast)
                        toast.snp.makeConstraints { make in
                            make.centerX.equalTo(view)
                            make.bottom.equalTo(view).offset(-100)
                            make.width.lessThanOrEqualTo(view).offset(-40)
                        }
                        UIView.animate(withDuration: 0.3, animations: {
                            toast.alpha = 1
                        }) { _ in
                            UIView.animate(withDuration: 0.3, delay: 1.2, options: [], animations: {
                                toast.alpha = 0
                            }) { _ in
                                toast.removeFromSuperview()
                            }
                        }
                    }
                } else {
                    subtitlesEnabled.toggle()
                    // If subtitles are disabled, hide the subtitle view immediately
                    if !subtitlesEnabled {
                        subtitleBackView.isHidden = true
                    }
                }
            default:
                break
            }
        }
        delegate?.controlView(controlView: self, didPressButton: button)
    }
    
    /**
     Call when the tap gesture tapped
     
     - parameter gesture: tap gesture
     */
    @objc open func onTapGestureTapped(_ gesture: UITapGestureRecognizer) {
        if playerLastState == .playedToTheEnd {
            return
        }
        controlViewAnimation(isShow: !isMaskShowing)
    }
    
    @objc open func onDoubleTapGestureRecognized(_ gesture: UITapGestureRecognizer) {
        guard let player = player else { return }
        guard playerLastState == .readyToPlay || playerLastState == .buffering || playerLastState == .bufferFinished else { return }
        
        if player.isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }
    
    // MARK: - handle UI slider actions
    @objc func progressSliderTouchBegan(_ sender: UISlider)  {
        delegate?.controlView(controlView: self, slider: sender, onSliderEvent: .touchDown)
    }
    
    @objc func progressSliderValueChanged(_ sender: UISlider)  {
        hidePlayToTheEndView()
        cancelAutoFadeOutAnimation()
        let currentTime = Double(sender.value) * totalDuration
        currentTimeLabel.text = BMPlayer.formatSecondsToString(currentTime)
        delegate?.controlView(controlView: self, slider: sender, onSliderEvent: .valueChanged)
    }
    
    @objc func progressSliderTouchEnded(_ sender: UISlider)  {
        autoFadeOutControlViewWithAnimation()
        delegate?.controlView(controlView: self, slider: sender, onSliderEvent: .touchUpInside)
    }
    
    
    // MARK: - private functions
    fileprivate func showSubtile(from subtitle: BMSubtitles?, at time: TimeInterval) {
        print("[BMPlayer] showSubtile called at time: \(time), subtitle: \(subtitle != nil)")
        if let subtitle = subtitle, let group = subtitle.search(for: time), subtitlesEnabled {
            print("[BMPlayer] Subtitle found: \(group.text)")
            subtitleBackView.isHidden = false
            subtitleLabel.text = group.text
            
            // Update subtitle position based on video content bounds
            updateSubtitlePosition()
            
            // Adjust subtitle positioning for long text
            adjustSubtitlePosition(for: group.text)
        } else {
            print("[BMPlayer] No subtitle for this time.")
            subtitleBackView.isHidden = true
        }
    }
    
    open func updateSubtitlePosition() {
        let videoContentRect = videoRect()
        let subtitleOffset: CGFloat = isAudioFile() ? 150 : 10 // 50 for audio, 10 for video
        
        // Calculate subtitle position relative to video content
        let subtitleY = videoContentRect.maxY - subtitleOffset
        
        print("[BMPlayer] Video content rect: \(videoContentRect)")
        print("[BMPlayer] Subtitle Y position: \(subtitleY)")
        
        // Update subtitle constraints to use absolute positioning
        subtitleBackView.snp.remakeConstraints { [unowned self](make) in
            make.centerX.equalTo(self.snp.centerX)
            make.bottom.equalTo(self.snp.top).offset(subtitleY)
            make.width.lessThanOrEqualTo(self.snp.width).offset(-10)
        }
        
        // No animation, update immediately
        self.layoutIfNeeded()
    }
    
    private func adjustSubtitlePosition(for text: String) {
        // Calculate if subtitle is long (more than 2 lines)
        let lines = text.components(separatedBy: .newlines)
        let isLongSubtitle = lines.count > 2 || text.count > 100
        
        let videoContentRect = videoRect()
        let baseOffset: CGFloat = isAudioFile() ? 150 : 10 // 50 for audio, 10 for video
        let longSubtitleOffset: CGFloat = 40 // Additional offset for long subtitles
        
        let subtitleOffset = isLongSubtitle ? baseOffset + longSubtitleOffset : baseOffset
        let subtitleY = videoContentRect.maxY - subtitleOffset
        
        // Update subtitle constraints to use absolute positioning
        subtitleBackView.snp.remakeConstraints { [unowned self](make) in
            make.centerX.equalTo(self.snp.centerX)
            make.bottom.equalTo(self.snp.top).offset(subtitleY)
            make.width.lessThanOrEqualTo(self.snp.width).offset(-10)
        }
        
        // No animation, update immediately
        self.layoutIfNeeded()
    }
    
    @objc fileprivate func onDefinitionSelected(_ button:UIButton) {
        let height = isSelectDefinitionViewOpened ? 35 : resource!.definitions.count * 40
        chooseDefinitionView.snp.updateConstraints { (make) in
            make.height.equalTo(height)
        }
        
        UIView.animate(withDuration: 0.3, animations: {[weak self] in
            self?.layoutIfNeeded()
        })
        isSelectDefinitionViewOpened = !isSelectDefinitionViewOpened
        if selectedIndex != button.tag {
            selectedIndex = button.tag
            delegate?.controlView(controlView: self, didChooseDefinition: button.tag)
        }
        prepareChooseDefinitionView()
    }
    
    @objc fileprivate func onReplyButtonPressed() {
        replayButton.isHidden = true
    }
    
    // MARK: - Init
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupUIComponents()
        addSnapKitConstraint()
        customizeUIComponents()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupUIComponents()
        addSnapKitConstraint()
        customizeUIComponents()
    }
    
    /// Add Customize functions here
    open func customizeUIComponents() {
        // Update CC button style for ON (enabled)
        if subtitlesEnabled {
            ccButton.backgroundColor = UIColor.white
            ccButton.setTitleColor(UIColor.black, for: .normal)
            ccButton.setTitleColor(UIColor.black, for: .selected)
            ccButton.layer.borderWidth = 0
        } else {
            // OFF (disabled)
            ccButton.backgroundColor = UIColor.clear
            ccButton.setTitleColor(UIColor.white, for: .normal)
            ccButton.setTitleColor(UIColor.white, for: .selected)
            ccButton.layer.borderWidth = 2
            ccButton.layer.borderColor = UIColor.white.cgColor
        }
    }
    
    func setupUIComponents() {
        // Subtile view setup
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = UIColor.white
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        
        subtitleBackView.layer.cornerRadius = 4
        subtitleBackView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        subtitleBackView.addSubview(subtitleLabel)
        subtitleBackView.isHidden = true
        
        // Main mask view
        addSubview(mainMaskView)
        mainMaskView.addSubview(topMaskView)
        mainMaskView.addSubview(subtitleBackView)
        mainMaskView.addSubview(bottomMaskView)
        mainMaskView.insertSubview(maskImageView, at: 0)
        mainMaskView.clipsToBounds = true
        mainMaskView.backgroundColor = UIColor(white: 0, alpha: 0.4 )
        
        // Top views
        topMaskView.addSubview(topWrapperView)
        topWrapperView.addSubview(backButton)
        topWrapperView.addSubview(titleLabel)
        topWrapperView.addSubview(chooseDefinitionView)
        topWrapperView.addSubview(moreButton)
        
        backButton.tag = BMPlayerControlView.ButtonType.back.rawValue
        backButton.setImage(BMImageResourcePath("Pod_Asset_BMPlayer_back"), for: .normal)
        backButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .touchUpInside)
        
        moreButton.tag = BMPlayerControlView.ButtonType.more.rawValue
        moreButton.setImage(BMImageResourcePath("Pod_Asset_BMPlayer_43"), for: .normal)
        moreButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .touchUpInside)
        
        titleLabel.textColor = UIColor.white
        titleLabel.text      = ""
        titleLabel.font      = UIFont.systemFont(ofSize: 16)
        
        chooseDefinitionView.clipsToBounds = true
        
        // Bottom views
        bottomMaskView.addSubview(bottomWrapperView)
        bottomWrapperView.addSubview(playButton)
        bottomWrapperView.addSubview(currentTimeLabel)
        bottomWrapperView.addSubview(totalTimeLabel)
        bottomWrapperView.addSubview(progressView)
        bottomWrapperView.addSubview(timeSlider)
        bottomWrapperView.addSubview(ccButton)
        bottomWrapperView.addSubview(downloadButton)
        
        playButton.tag = BMPlayerControlView.ButtonType.play.rawValue
        playButton.setImage(BMImageResourcePath("Pod_Asset_BMPlayer_play"),  for: .normal)
        playButton.setImage(BMImageResourcePath("Pod_Asset_BMPlayer_pause"), for: .selected)
        playButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .touchUpInside)
        
        currentTimeLabel.textColor  = UIColor.white
        currentTimeLabel.font       = UIFont.systemFont(ofSize: 12)
        currentTimeLabel.text       = "00:00"
        currentTimeLabel.textAlignment = NSTextAlignment.center
        
        totalTimeLabel.textColor    = UIColor.white
        totalTimeLabel.font         = UIFont.systemFont(ofSize: 12)
        totalTimeLabel.text         = "00:00"
        totalTimeLabel.textAlignment   = NSTextAlignment.center
        
        timeSlider.maximumValue = 1.0
        timeSlider.minimumValue = 0.0
        timeSlider.value        = 0.0
        timeSlider.setThumbImage(BMImageResourcePath("Pod_Asset_BMPlayer_slider_thumb"), for: .normal)
        
        timeSlider.maximumTrackTintColor = UIColor.clear
        timeSlider.minimumTrackTintColor = BMPlayerConf.tintColor
        
        timeSlider.addTarget(self, action: #selector(progressSliderTouchBegan(_:)),
                             for: UIControl.Event.touchDown)
        
        timeSlider.addTarget(self, action: #selector(progressSliderValueChanged(_:)),
                             for: UIControl.Event.valueChanged)
        
        timeSlider.addTarget(self, action: #selector(progressSliderTouchEnded(_:)),
                             for: [UIControl.Event.touchUpInside,UIControl.Event.touchCancel, UIControl.Event.touchUpOutside])
        
        progressView.tintColor      = UIColor ( red: 1.0, green: 1.0, blue: 1.0, alpha: 0.6 )
        progressView.trackTintColor = UIColor ( red: 1.0, green: 1.0, blue: 1.0, alpha: 0.3 )
        
        downloadButton.tag = BMPlayerControlView.ButtonType.download.rawValue
        downloadButton.setImage(BMImageResourcePath("Pod_Asset_BMPlayer_fullscreen"),    for: .normal)
        downloadButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .touchUpInside)
        
        ccButton.tag = BMPlayerControlView.ButtonType.cc.rawValue
        ccButton.setTitle("CC", for: .normal)
        ccButton.setTitle("CC", for: .selected)
        ccButton.titleLabel?.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        ccButton.setTitleColor(UIColor.white.withAlphaComponent(0.6), for: .normal)
        ccButton.setTitleColor(UIColor.white, for: .selected)
        ccButton.backgroundColor = UIColor.clear
        ccButton.layer.cornerRadius = 4
        ccButton.layer.borderWidth = 1
        ccButton.layer.borderColor = UIColor.white.withAlphaComponent(1).cgColor
        ccButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .touchUpInside)
        ccButton.isSelected = subtitlesEnabled
        
        mainMaskView.addSubview(loadingIndicator)
        
        loadingIndicator.type  = BMPlayerConf.loaderType
        loadingIndicator.color = BMPlayerConf.tintColor
        
        // View to show when slide to seek
        addSubview(seekToView)
        seekToView.addSubview(seekToViewImage)
        seekToView.addSubview(seekToLabel)
        
        seekToLabel.font                = UIFont.systemFont(ofSize: 13)
        seekToLabel.textColor           = UIColor ( red: 0.9098, green: 0.9098, blue: 0.9098, alpha: 1.0 )
        seekToView.backgroundColor      = UIColor ( red: 0.0, green: 0.0, blue: 0.0, alpha: 0.7 )
        seekToView.layer.cornerRadius   = 4
        seekToView.layer.masksToBounds  = true
        seekToView.isHidden             = true
        
        seekToViewImage.image = BMImageResourcePath("Pod_Asset_BMPlayer_seek_to_image")
        
        addSubview(replayButton)
        replayButton.isHidden = true
        replayButton.setImage(BMImageResourcePath("Pod_Asset_BMPlayer_replay"), for: .normal)
        replayButton.addTarget(self, action: #selector(onButtonPressed(_:)), for: .touchUpInside)
        replayButton.tag = ButtonType.replay.rawValue
        
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(onTapGestureTapped(_:)))
        addGestureRecognizer(tapGesture)
        
        if BMPlayerManager.shared.enablePlayControlGestures {
            doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(onDoubleTapGestureRecognized(_:)))
            doubleTapGesture.numberOfTapsRequired = 2
            addGestureRecognizer(doubleTapGesture)
            
            tapGesture.require(toFail: doubleTapGesture)
        }
    }
    
    func addSnapKitConstraint() {
        // Main mask view
        mainMaskView.snp.makeConstraints { [unowned self](make) in
            make.edges.equalTo(self)
        }
        
        maskImageView.snp.makeConstraints { [unowned self](make) in
            make.edges.equalTo(self.mainMaskView)
        }
        
        topMaskView.snp.makeConstraints { [unowned self](make) in
            make.top.left.right.equalTo(self.mainMaskView)
        }
        
        topWrapperView.snp.makeConstraints { [unowned self](make) in
            make.height.equalTo(50)
            if #available(iOS 11.0, *) {
                make.top.left.right.equalTo(self.topMaskView.safeAreaLayoutGuide)
                make.bottom.equalToSuperview()
            } else {
                make.top.equalToSuperview().offset(15)
                make.bottom.left.right.equalToSuperview()
            }
        }
        
        bottomMaskView.snp.makeConstraints { [unowned self](make) in
            make.bottom.left.right.equalTo(self.mainMaskView)
        }
        
        bottomWrapperView.snp.makeConstraints { [unowned self](make) in
            make.height.equalTo(50)
            if #available(iOS 11.0, *) {
                make.bottom.left.right.equalTo(self.bottomMaskView.safeAreaLayoutGuide)
                make.top.equalToSuperview()
            } else {
                make.edges.equalToSuperview()
            }
        }
        
        // Top views
        backButton.snp.makeConstraints { (make) in
            make.width.height.equalTo(50)
            make.left.bottom.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { [unowned self](make) in
            make.left.equalTo(self.backButton.snp.right).offset(10)
            make.centerY.equalTo(self.backButton)
            make.right.lessThanOrEqualTo(self.chooseDefinitionView.snp.left).offset(-10)
        }
        
        chooseDefinitionView.snp.makeConstraints { [unowned self](make) in
            make.right.equalToSuperview().offset(-20)
            make.top.equalTo(self.titleLabel.snp.top).offset(-4)
            make.width.equalTo(60)
            make.height.equalTo(30)
        }
        
        moreButton.snp.makeConstraints { (make) in
            make.width.height.equalTo(50)
            make.right.bottom.equalToSuperview()
        }
        
        // Bottom views
        playButton.snp.makeConstraints { (make) in
            make.width.equalTo(50)
            make.height.equalTo(50)
            make.left.bottom.equalToSuperview()
        }
        
        currentTimeLabel.snp.makeConstraints { [unowned self](make) in
            make.left.equalTo(self.playButton.snp.right)
            make.centerY.equalTo(self.playButton)
            make.width.equalTo(40)
        }
        
        timeSlider.snp.makeConstraints { [unowned self](make) in
            make.centerY.equalTo(self.currentTimeLabel)
            make.left.equalTo(self.currentTimeLabel.snp.right).offset(10).priority(750)
            make.height.equalTo(30)
        }
        
        progressView.snp.makeConstraints { [unowned self](make) in
            make.centerY.left.right.equalTo(self.timeSlider)
            make.height.equalTo(2)
        }
        
        totalTimeLabel.snp.makeConstraints { [unowned self](make) in
            make.centerY.equalTo(self.currentTimeLabel)
            make.left.equalTo(self.timeSlider.snp.right).offset(5)
            make.width.equalTo(40)
        }
        
        ccButton.snp.makeConstraints { [unowned self](make) in
            make.width.equalTo(25)
            make.height.equalTo(25)
            make.centerY.equalTo(self.currentTimeLabel)
            make.left.equalTo(self.totalTimeLabel.snp.right).offset(5)
        }
        
        downloadButton.snp.makeConstraints { [unowned self](make) in
            make.width.equalTo(50)
            make.height.equalTo(50)
            make.centerY.equalTo(self.currentTimeLabel)
            make.left.equalTo(self.ccButton.snp.right)
            make.right.equalToSuperview()
        }
        
        loadingIndicator.snp.makeConstraints { [unowned self](make) in
            make.center.equalTo(self.mainMaskView)
        }
        
        // View to show when slide to seek
        seekToView.snp.makeConstraints { [unowned self](make) in
            make.center.equalTo(self.snp.center)
            make.width.equalTo(100)
            make.height.equalTo(40)
        }
        
        seekToViewImage.snp.makeConstraints { [unowned self](make) in
            make.left.equalTo(self.seekToView.snp.left).offset(15)
            make.centerY.equalTo(self.seekToView.snp.centerY)
            make.height.equalTo(15)
            make.width.equalTo(25)
        }
        
        seekToLabel.snp.makeConstraints { [unowned self](make) in
            make.left.equalTo(self.seekToViewImage.snp.right).offset(10)
            make.centerY.equalTo(self.seekToView.snp.centerY)
        }
        
        replayButton.snp.makeConstraints { [unowned self](make) in
            make.center.equalTo(self.mainMaskView)
            make.width.height.equalTo(50)
        }
        
        subtitleBackView.snp.makeConstraints { [unowned self](make) in
            make.centerX.equalTo(self.snp.centerX)
            make.bottom.equalTo(self.snp.top).offset(0)
            make.width.lessThanOrEqualTo(self.snp.width).offset(-10)
        }
        
        subtitleLabel.snp.makeConstraints { [unowned self](make) in
            make.left.equalTo(self.subtitleBackView.snp.left).offset(10)
            make.right.equalTo(self.subtitleBackView.snp.right).offset(-10)
            make.top.equalTo(self.subtitleBackView.snp.top).offset(2)
            make.bottom.equalTo(self.subtitleBackView.snp.bottom).offset(-2)
        }
    }
    
    fileprivate func BMImageResourcePath(_ fileName: String) -> UIImage? {
        let bundle = Bundle(for: BMPlayer.self)
        return UIImage(named: fileName, in: bundle, compatibleWith: nil)
    }
    
    // MARK: - Video content bounds calculation
    
    /**
     Calculate the actual video content bounds within the player view
     This accounts for video aspect ratio, letterboxing, and pillarboxing
     */
    open func videoRect() -> CGRect {
        guard let player = player,
              let playerLayer = player.playerLayer,
              let currentItem = playerLayer.player?.currentItem else {
            return bounds
        }
        
        guard let track = currentItem.asset.tracks(withMediaType: .video).first else {
            return bounds
        }
        
        // Get video natural size
        let videoSize = track.naturalSize
        
        // Get player view size
        let playerViewSize = bounds.size
        
        // Calculate aspect ratios
        let videoRatio = videoSize.width / videoSize.height
        let playerRatio = playerViewSize.width / playerViewSize.height
        
        var contentSize: CGSize
        var contentX: CGFloat
        var contentY: CGFloat
        
        // Calculate content bounds based on video gravity
        switch playerLayer.videoGravity {
        case .resizeAspect:
            // Maintain aspect ratio, may have letterboxing/pillarboxing
            if playerRatio > videoRatio {
                // Player is wider than video - pillarboxing
                contentSize = CGSize(
                    width: videoSize.width * playerViewSize.height / videoSize.height,
                    height: playerViewSize.height
                )
                contentX = (playerViewSize.width - contentSize.width) / 2
                contentY = 0
            } else {
                // Player is taller than video - letterboxing
                contentSize = CGSize(
                    width: playerViewSize.width,
                    height: videoSize.height * playerViewSize.width / videoSize.width
                )
                contentX = 0
                contentY = (playerViewSize.height - contentSize.height) / 2
            }
            
        case .resizeAspectFill:
            // Fill the player view, may crop video
            if playerRatio > videoRatio {
                // Player is wider - crop video width
                contentSize = CGSize(
                    width: playerViewSize.width,
                    height: videoSize.height * playerViewSize.width / videoSize.width
                )
                contentX = 0
                contentY = (playerViewSize.height - contentSize.height) / 2
            } else {
                // Player is taller - crop video height
                contentSize = CGSize(
                    width: videoSize.width * playerViewSize.height / videoSize.height,
                    height: playerViewSize.height
                )
                contentX = (playerViewSize.width - contentSize.width) / 2
                contentY = 0
            }
            
        case .resize:
            // Stretch to fill - no letterboxing/pillarboxing
            contentSize = playerViewSize
            contentX = 0
            contentY = 0
            
        default:
            // Fallback to player bounds
            contentSize = playerViewSize
            contentX = 0
            contentY = 0
        }
        
        return CGRect(x: contentX, y: contentY, width: contentSize.width, height: contentSize.height)
    }

    // Helper to check if file is audio
    private func isAudioFile() -> Bool {
        guard let ext = resource?.definitions.first?.url.pathExtension.lowercased() else { return false }
        return ["mp3", "m4a", "flac", "wav", "wma", "aac"].contains(ext)
    }
}

@IBDesignable open class CircularProgressBarView: UIControl {
    @IBInspectable var mainColor: UIColor = UIColor.gray {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    @IBInspectable var forgroundColor: UIColor = UIColor.white {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    @IBInspectable var progress: CGFloat = 0.0 {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    lazy var backLayer: CAShapeLayer? = {
        let layer = CAShapeLayer()
        layer.strokeColor = mainColor.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 2.0
        return layer
    }()
    
    lazy var foreLayer: CAShapeLayer? = {
        let layer = CAShapeLayer()
        layer.strokeColor = forgroundColor.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 2.0
        layer.lineCap = .round
        return layer
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.layer.addSublayer(self.backLayer!)
        self.layer.addSublayer(self.foreLayer!)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.backgroundColor = .clear
        self.layer.addSublayer(self.backLayer!)
        self.layer.addSublayer(self.foreLayer!)
        self.mainColor = UIColor.gray
        self.forgroundColor = UIColor.blue
        self.progress = 0.3
    }
    
    open override func awakeFromNib() {
        self.mainColor = UIColor.gray
        self.forgroundColor = UIColor.blue
        self.progress = 0.3
    }
    
    open override func draw(_ rect: CGRect) {
        self.backLayer?.frame = self.bounds.inset(by: UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1))
        self.foreLayer?.frame = self.bounds.inset(by: UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1))
        self.backLayer?.strokeColor = mainColor.cgColor
        self.foreLayer?.strokeColor = forgroundColor.cgColor
        
        let circle = UIBezierPath.init(ovalIn: self.backLayer!.bounds)
        self.backLayer?.path = circle.cgPath
        
        let center = CGPoint.init(x: self.foreLayer!.frame.size.width / 2,
                                  y: self.foreLayer!.frame.size.height / 2)
        let start = 0 - CGFloat(Double.pi / 2)
        let end = CGFloat(Double.pi) * 2 * progress - CGFloat(Double.pi / 2)
        let arc = UIBezierPath.init(arcCenter: center,
                                    radius: self.foreLayer!.frame.size.width / 2,
                                    startAngle: start, endAngle: end, clockwise: true)
        self.foreLayer!.path = arc.cgPath
    }
}


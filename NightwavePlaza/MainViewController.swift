//
//  ViewController.swift
//  NightwavePlaza
//
//  Created by Aleksey Garbarev on 24.05.2020.
//  Copyright © 2020 Aleksey Garbarev. All rights reserved.
//

import UIKit
import AVFoundation
import RxSwift
import MediaPlayer

class MainViewController: UIViewController {
    
    @IBOutlet weak var artImageView: UIImageView!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var songLabel: UILabel!
    
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var controlButton: UIButton!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var bgContainer: BackgroundView!
    @IBOutlet weak var nextBgButton: UIButton!
    @IBOutlet weak var prevBgButton: UIButton!
    
    private var disposeBag = DisposeBag()
    
    private var currentBg: Int = 0
    private var backgrounds: [[String: String]] = []
    
    private let playback: PlaybackService
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.playback = PlaybackService();
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        self.playback = PlaybackService();
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func onTriggerPlayButton(_ sender: Any) {
//        self.playback.toggle()
        self.controlButton.setTitle(self.playback.paused ? "Play" : "Pause", for: .normal)
    }
    
    private func updateBg() {
        
        let bgObj = self.backgrounds[self.currentBg];
        
        let url = URL(string: bgObj["video_src"]! )!;
        
        self.bgContainer.setUrl(url: url)
        
        self.prevBgButton.isEnabled = self.currentBg > 0;
        self.nextBgButton.isEnabled = self.currentBg < self.backgrounds.count - 1
    }
}


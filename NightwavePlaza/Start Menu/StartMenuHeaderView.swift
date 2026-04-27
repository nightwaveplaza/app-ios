//
//  StartMenuHeaderView.swift
//  NightwavePlaza
//
//  Created by Aleksey Garbarev on 06.09.2020.
//  Copyright © 2020 Aleksey Garbarev. All rights reserved.
//
import UIKit
import Foundation

class StartMenuHeaderView: UIView {
   
    var leftInset: CGFloat = 0
    var gradientLayer: CAGradientLayer!
    
    var fontSize: CGFloat {
        set {
            self.label.font = UIFont.boldSystemFont(ofSize: newValue)
        }
        get {
            return self.label.font.pointSize
        }
    }
    
    var leftPadding: CGFloat = 15 {
        didSet {
            self.setNeedsLayout()
        }
    }
    

    var label: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        
        self.translatesAutoresizingMaskIntoConstraints = false;
        self.autoresizesSubviews = false;
        
        setupGradient()
        
        self.label = UILabel()
        self.label.text = "Nightwave Plaza Second Edition"
        self.label.textColor = UIColor.white
        self.label.font = UIFont.boldSystemFont(ofSize: 19)
        self.addSubview(self.label)
    }
    
    func setupGradient() {
        let colorTop = UIColor(named: "StartGradientBlack")?.cgColor ?? UIColor.clear.cgColor
        let colorBottom = UIColor(named: "StartGradientBlue")?.cgColor ?? UIColor.clear.cgColor

        self.gradientLayer = CAGradientLayer()
        self.gradientLayer.colors = [colorTop, colorTop, colorBottom]
        self.gradientLayer.locations = [0.0, 0.3, 1.0]
        
        self.layer.addSublayer(self.gradientLayer)
    }
    
    
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.gradientLayer.frame = self.layer.bounds

        self.label.transform = CGAffineTransform(rotationAngle: -(CGFloat.pi / 2))
        self.label.frame = CGRect(x: 0, y: 0, width: self.bounds.size.width, height: self.bounds.size.height - leftInset - self.leftPadding)
    }
    
}

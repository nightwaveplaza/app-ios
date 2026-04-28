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
   
    var leftInset: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }
    var leftPadding: CGFloat = 19 {
        didSet { setNeedsLayout() }
    }
    var fontSize: CGFloat = 19 {
        didSet {
            self.label.font = UIFont.systemFont(ofSize: fontSize, weight: .heavy)
        }
    }
    
    private let label: UILabel = {
        let lbl = UILabel()
        lbl.text = "Nightwave Plaza Second Edition"
        lbl.textColor = .white
        lbl.font = .boldSystemFont(ofSize: 19)
        return lbl
    }()
    
    private let gradientLayer = CAGradientLayer()
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        let colorTop = UIColor(named: "StartGradientBlack")?.cgColor ?? UIColor.clear.cgColor
        let colorBottom = UIColor(named: "StartGradientBlue")?.cgColor ?? UIColor.clear.cgColor
        
        gradientLayer.colors = [colorTop, colorTop, colorBottom]
        gradientLayer.locations = [0.0, 0.3, 1.0]
        layer.addSublayer(gradientLayer)
        
        addSubview(label)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        gradientLayer.frame = bounds
        label.transform = .identity
        
        let labelWidth = bounds.height - leftInset - leftPadding
        let labelHeight = bounds.width
        
        label.bounds = CGRect(x: 0, y: 0, width: labelWidth, height: labelHeight)
        
        let centerY = (bounds.height - leftInset - leftPadding) / 2
        label.center = CGPoint(x: bounds.midX, y: centerY)
        
        label.transform = CGAffineTransform(rotationAngle: -.pi / 2)
    }
    
}

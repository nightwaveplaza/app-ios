//
//  StartMenuView.swift
//  NightwavePlaza
//
//  Created by Aleksey Garbarev on 06.09.2020.
//  Copyright © 2020 Aleksey Garbarev. All rights reserved.
//

import UIKit
import Foundation

class StartMenuView: UIView {
    
    let itemHeight: CGFloat = 44.0
    let itemSeparator: CGFloat = 1
    let fontSize: CGFloat = 14
    let iconSize: CGFloat = 32.0
    let iconPadding: CGFloat = 10
    let menuWidth: CGFloat = 200
    let headerWidth: CGFloat = 25
    let headerFontSize: CGFloat = 19
    let headerLeftPadding: CGFloat = 5
    
    var onClick: ((_ item: StartMenuItem) -> Void)?
    
    func setup(items: [StartMenuItem], viewController: UIViewController) {
        self.backgroundColor = UIColor(named: "StartBackground")
        
        let bottomInset = viewController.view.safeAreaInsets.bottom
        let width = menuWidth
        
        self.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stackView)
        
        for item in items {
            let itemView = self.createViewForItem(item)
            stackView.addArrangedSubview(itemView)
        }
        
        let titleView = self.createTitleView(leftInset: bottomInset)
        titleView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(titleView)
        
        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalToConstant: width),
            
            titleView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            titleView.topAnchor.constraint(equalTo: self.topAnchor),
            titleView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            titleView.widthAnchor.constraint(equalToConstant: headerWidth),
            
            stackView.leadingAnchor.constraint(equalTo: titleView.trailingAnchor),
            stackView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: self.topAnchor),

            stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -bottomInset)
        ])
    }
    
    func createViewForItem(_ item: StartMenuItem) -> UIControl {
        let control = UIControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView()
        imageView.image = item.icon
        imageView.translatesAutoresizingMaskIntoConstraints = false
        control.addSubview(imageView)
        
        let label = UILabel()
        label.text = item.title
        label.font = UIFont.systemFont(ofSize: fontSize)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        control.addSubview(label)
        
        NSLayoutConstraint.activate([
            control.heightAnchor.constraint(equalToConstant: itemHeight),
            
            imageView.centerYAnchor.constraint(equalTo: control.centerYAnchor),
            imageView.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: iconPadding),
            imageView.widthAnchor.constraint(equalToConstant: iconSize),
            imageView.heightAnchor.constraint(equalToConstant: iconSize),
      
            label.centerYAnchor.constraint(equalTo: control.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: iconPadding),
            label.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -iconPadding)
        ])
        
        if item.hasBottomLine {
            let separator = UIView()
            separator.backgroundColor = UIColor(named: "StartDivider")
            separator.translatesAutoresizingMaskIntoConstraints = false
            control.addSubview(separator)
            
            NSLayoutConstraint.activate([
                separator.heightAnchor.constraint(equalToConstant: itemSeparator),
                separator.leadingAnchor.constraint(equalTo: control.leadingAnchor),
                separator.trailingAnchor.constraint(equalTo: control.trailingAnchor),
                separator.bottomAnchor.constraint(equalTo: control.bottomAnchor)
            ])
        }
        
        let action = UIAction { [weak self] _ in
            self?.onClick?(item)
        }
        control.addAction(action, for: .touchUpInside)
        
        return control
    }
    
    func createTitleView(leftInset: CGFloat) -> UIView {
        let view = StartMenuHeaderView()
        view.fontSize = self.headerFontSize
        view.leftPadding = self.headerLeftPadding
        view.leftInset = leftInset
        return view
    }
}

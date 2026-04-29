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
    
    // MARK: - Layout Constants
    let itemHeight: CGFloat = 44.0
    let itemSeparator: CGFloat = 1
    let fontSize: CGFloat = 14
    let iconSize: CGFloat = 32.0
    let iconPadding: CGFloat = 6
    let menuWidth: CGFloat = 200
    let headerWidth: CGFloat = 24
    let headerFontSize: CGFloat = 16
    let headerLeftPadding: CGFloat = 6
    
    // MARK: - Properties
    var onClick: ((_ item: StartMenuItem) -> Void)?
    
    private let stackView = UIStackView()
    
    // MARK: - Setup
        
    // Initializes the main layout of the menu, positioning the vertical stack for items
    // and the rotated header view on the left edge
    func setup(items: [StartMenuItem], viewController: UIViewController) {
        self.backgroundColor = UIColor(named: "StartBackground")
        
        // Calculates the bottom safe area to prevent menu items from overlapping the Home Indicator
        let bottomInset = viewController.view.safeAreaInsets.bottom
        let width = menuWidth
        
        self.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stackView)
        
        self.updateItems(items)
        
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
    
    // MARK: - Content Updates
        
    // Clears the current menu stack and rebuilds it with new items
    // This ensures no duplicate or stale views remain in the view hierarchy
    func updateItems(_ items: [StartMenuItem]) {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        
        for item in items {
            let itemView = self.createViewForItem(item)
            stackView.addArrangedSubview(itemView)
        }
    }
    
    // MARK: - UI Builders
        
    // Constructs a clickable row for a given menu item, positioning its icon and title.
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
        
        // Conditionally appends a visual divider at the bottom of specific group items
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
        
        // Binds the row selection to the parent's onClick router
        let action = UIAction { [weak self] _ in
            self?.onClick?(item)
        }
        control.addAction(action, for: .touchUpInside)
        
        return control
    }
    
    // Initializes the decorative side header with the app's title
    func createTitleView(leftInset: CGFloat) -> UIView {
        let view = StartMenuHeaderView()
        view.fontSize = self.headerFontSize
        view.leftPadding = self.headerLeftPadding
        view.leftInset = leftInset
        return view
    }
}

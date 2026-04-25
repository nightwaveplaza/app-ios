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
    
    let itemHeight: CGFloat = 50.0
    let itemSeparator: CGFloat = 1
    let fontSize: CGFloat = 14
    let iconSize: CGFloat = 32.0
    let iconPadding: CGFloat = 10
    
    let menuWidth: CGFloat = 200
    
    let headerWidth: CGFloat = 25
    let headerFontSize: CGFloat = 19
    let headerLeftPadding: CGFloat = 5
    
    var onClick: ((_ item: StartMenuItem) -> Void)?
    
    func setup(items: [StartMenuItem], viewController: UIViewController) -> Void {
        self.backgroundColor = UIColor(hex: "CBCBCB")
        
        let bottomInset = viewController.bottomLayoutGuide.length
        var width =  CGFloat(viewController.view.bounds.size.width) / 2
        width = menuWidth // Hardcoded width for now..
        
        self.autoSetDimension(.height, toSize: CGFloat(CGFloat(items.count) * itemHeight + bottomInset))
        self.autoSetDimension(.width, toSize: width)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        var lastView: UIView?
        
        for item in items {
            let view = self.createViewForItem(item)
            self.addSubview(view)
            view.autoPinEdge(toSuperviewEdge: .left, withInset: headerWidth)
            view.autoPinEdge(toSuperviewEdge: .right)
            view.autoSetDimension(.height, toSize: itemHeight)

            if let viewToPin = lastView {
                view.autoPinEdge(.top, to: .bottom, of: viewToPin)
            } else {
                view.autoPinEdge(toSuperviewEdge: .top)
            }
            
            view.onTap({recognizer in
                if (recognizer.state == .ended) {
                    self.onClick?(item)
                }
            })
            
            lastView = view

        }
        
        let view = self.createTitleView(leftInset: bottomInset)
        self.addSubview(view)
        view.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .right)
        view.autoSetDimension(.width, toSize: headerWidth)
        
    }
    
    
    func createViewForItem(_ item: StartMenuItem) -> UIView {
        
        let view = UIView()
        
        let imageView = UIImageView()
        imageView.image = item.icon
        
        view.addSubview(imageView)
        imageView.autoSetDimensions(to: CGSize(width: iconSize, height: iconSize))
        imageView.autoAlignAxis(toSuperviewAxis: .horizontal)
        imageView.autoPinEdge(toSuperviewEdge: .left, withInset: iconPadding)
        
        let label = UILabel()
        label.text = item.title
        label.font = UIFont.systemFont(ofSize: fontSize)
        label.textColor = .black
        
        view.addSubview(label)
        label.autoAlignAxis(toSuperviewAxis: .horizontal)
        label.autoPinEdge(.left, to: .right, of: imageView, withOffset: iconPadding)
        
        if (item.hasBottomLine) {
            let separator = UIView()
            separator.backgroundColor = UIColor(hex: "AEAEAE")
            view.addSubview(separator)
            separator.autoSetDimension(.height, toSize: itemSeparator)
            separator.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        }
        
        return view
        
    }
    
    func createTitleView(leftInset: CGFloat) -> UIView {
        let view = StartMenuHeaderView()
        view.fontSize = self.headerFontSize
        view.leftPadding = self.headerLeftPadding
        view.leftInset = leftInset
        return view;
    }
    
    
}

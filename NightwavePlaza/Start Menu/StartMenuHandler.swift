//
//  StartMenuHandler.swift
//  NightwavePlaza
//
//  Created by Aleksey Garbarev on 06.09.2020.
//  Copyright © 2020 Aleksey Garbarev. All rights reserved.
//

import Foundation
import UIKit

class StartMenuHandler {
    
    weak var viewController: UIViewController!
    var view: StartMenuView!
    let darkView = UIView()
    var left: NSLayoutConstraint?;
    
    var isMenuOpened = false
    
    var openMenuGesture: UIPanGestureRecognizer!
    
    var onSelect: ((_ action: String) -> Void)?

    
    func setup(inViewController viewController: UIViewController, onSelect block: @escaping (_ action: String) -> Void) {
         self.viewController = viewController
        openMenuGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        self.viewController!.view.addGestureRecognizer(openMenuGesture)
        self.onSelect = block
    }
    
    func setupMenuIfNeeded() {
        
        if view != nil {
            return
        }
        
        UIView.setAnimationsEnabled(false)
        
        view = StartMenuView()
        
        view.setup(items: self.menuItems(), viewController: self.viewController)
        
        darkView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        
        self.viewController.view.addSubview(darkView);
        darkView.autoPinEdgesToSuperviewEdges()
        
        self.viewController.view.addSubview(view);
        
        NSLayoutConstraint.autoSetPriority(.defaultHigh) {
            left = view.autoPinEdge(toSuperviewEdge: .left)
        }
        
        view.autoPinEdge(toSuperviewEdge: .bottom)
        view.updateConstraints()
        view.layoutIfNeeded()
        left?.constant = -view.bounds.size.width;
        
        self.viewController.view.layoutIfNeeded()
       
        
        darkView.onTap { [unowned self] (handler) in
            self.dissmiss()
        }
        
        view.onClick = { item in
            self.onSelect?(item.targetAction)
            self.dissmiss()
        }
        
        UIView.setAnimationsEnabled(true)
        
    }
    
    func menuItems() -> [StartMenuItem] {
        return [
            StartMenuItem(icon: UIImage(named: "ic_ratings"), title: "Ratings", targetAction: "ratings", hasBottomLine: false),
            StartMenuItem(icon: UIImage(named: "ic_history"), title: "Play History", targetAction: "history", hasBottomLine: true),
            StartMenuItem(icon: UIImage(named: "ic_favorites"), title: "My Favorites", targetAction: "user-favorites", hasBottomLine: false),
            StartMenuItem(icon: UIImage(named: "ic_profile"), title: "My Profile", targetAction: "user", hasBottomLine: true),
            StartMenuItem(icon: UIImage(named: "ic_settings"), title: "Settings", targetAction: "settings", hasBottomLine: false),
            StartMenuItem(icon: UIImage(named: "ic_help"), title: "About", targetAction: "about", hasBottomLine: false),
            StartMenuItem(icon: UIImage(named: "ic_launcher"), title: "Donate", targetAction: "donate", hasBottomLine: true)
        ]
    }
    
    func show() {
        self.setupMenuIfNeeded()
        
        viewController!.view.bringSubviewToFront(self.darkView)
        viewController!.view.bringSubviewToFront(self.view)
        self.darkView.isHidden = false
        
        viewController!.view.layoutIfNeeded()
        UIView.setAnimationCurve(.easeInOut)
        UIView.animate(withDuration: 0.2, animations: { [unowned self] in
            self.darkView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            self.left?.constant = 0;
            self.viewController!.view.layoutIfNeeded()
        }) {  [unowned self] (finished) in
            self.isMenuOpened = true
        }
    }
    
    func dissmiss() {
        self.viewController!.view.layoutIfNeeded()
        UIView.setAnimationCurve(.easeInOut)
        UIView.animate(withDuration: 0.2, animations: { [unowned self] in
            self.darkView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
            self.left?.constant = -self.view.bounds.size.width;
            self.view.superview!.layoutIfNeeded()
        }) {  [unowned self] (finished) in
            self.darkView.isHidden = true
            self.isMenuOpened = false
        }
    }
    
    func toggleMenu() {
        
        if isMenuOpened {
            self.darkView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
            self.left?.constant = -self.view.bounds.size.width;
            self.view.superview!.layoutIfNeeded()
        } else {
            self.darkView.isHidden = false
            self.darkView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            self.left?.constant = 0;
            self.viewController!.view.layoutIfNeeded()
        }
    }
    
    func updateForCurrentState() {
        self.setupMenuIfNeeded()
        viewController!.view.bringSubviewToFront(self.darkView)
        viewController!.view.bringSubviewToFront(self.view)
        
        if isMenuOpened {
            self.left?.constant = 0;
            self.darkView.isHidden = false
        } else {
            self.left?.constant = -self.view.bounds.size.width;
            self.darkView.isHidden = true
        }
        self.view.superview!.layoutIfNeeded()
    }
    
    private var animator: UIViewPropertyAnimator!

    @objc private func handlePan(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            var shouldCancel = false
            if !isMenuOpened && recognizer.location(in: recognizer.view).x > 50 {
                shouldCancel = true
            }
            if self.animator != nil {
                shouldCancel = true
            }
            if shouldCancel {
                recognizer.isEnabled = false
                recognizer.isEnabled = true
                break
            }
            self.updateForCurrentState()
            animator = UIViewPropertyAnimator(duration: 0.5, curve: .easeOut, animations: {
                self.toggleMenu()
            })
            animator.startAnimation()
            animator.pauseAnimation()
            break
        case .changed:
            var fraction = recognizer.translation(in: recognizer.view).x / self.view.bounds.size.width
            if self.isMenuOpened {
                fraction = -fraction;
            }
            animator.fractionComplete = fraction
            break
        case .ended:
            animator.isReversed = animator.fractionComplete < 0.3
            animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
            animator.addCompletion { [unowned self] (position) in
                if self.animator.isReversed == false {
                    self.isMenuOpened = !self.isMenuOpened
                }
                self.updateForCurrentState()
                self.animator = nil
            }
            break
        @unknown default:
            ()
        }
    }
    
}

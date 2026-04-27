//
//  StartMenuHandler.swift
//  NightwavePlaza
//
//  Created by Aleksey Garbarev on 06.09.2020.
//  Copyright © 2020 Aleksey Garbarev. All rights reserved.
//

import UIKit
import Foundation

class StartMenuHandler {
    
    weak var viewController: UIViewController?
    var view: StartMenuView?
    let darkView = UIView()
    var leftConstraint: NSLayoutConstraint?
    
    var isMenuOpened = false
    var openMenuGesture: UIPanGestureRecognizer!
    var onSelect: ((_ action: String) -> Void)?
    
    func setup(inViewController viewController: UIViewController, onSelect block: @escaping (_ action: String) -> Void) {
        self.viewController = viewController
        openMenuGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        self.viewController?.view.addGestureRecognizer(openMenuGesture)
        self.onSelect = block
    }
    
    func setupMenuIfNeeded() {
        guard view == nil, let vc = viewController else { return }

        UIView.setAnimationsEnabled(false)
        
        let menuView = StartMenuView()
        self.view = menuView
        
        menuView.setup(items: self.menuItems(), viewController: vc)
        
        darkView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        
        darkView.translatesAutoresizingMaskIntoConstraints = false
        menuView.translatesAutoresizingMaskIntoConstraints = false
        
        vc.view.addSubview(darkView)
        vc.view.addSubview(menuView)
        
        let left = menuView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor)
        left.priority = .defaultHigh
        self.leftConstraint = left
        
        NSLayoutConstraint.activate([
            darkView.topAnchor.constraint(equalTo: vc.view.topAnchor),
            darkView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
            darkView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            darkView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            
            menuView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
            left
        ])
        
        vc.view.layoutIfNeeded()
        leftConstraint?.constant = -menuView.bounds.size.width
        vc.view.layoutIfNeeded()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissMenu))
        darkView.addGestureRecognizer(tapGesture)
        
        menuView.onClick = { [weak self] item in
            self?.onSelect?(item.targetAction)
            self?.dismissMenu()
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
        setupMenuIfNeeded()
        guard let vc = viewController, let menuView = view else { return }
                
        vc.view.bringSubviewToFront(darkView)
        vc.view.bringSubviewToFront(menuView)
        darkView.isHidden = false
        
        vc.view.layoutIfNeeded()
        
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut], animations: { [weak self] in
            guard let self = self else { return }
            self.darkView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            self.leftConstraint?.constant = 0
            self.viewController?.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            self?.isMenuOpened = true
        })
    }
    
    @objc func dismissMenu() { // Добавлен @objc для доступа из UITapGestureRecognizer
        guard let vc = viewController, let menuView = view else { return }
        
        vc.view.layoutIfNeeded()
        
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut], animations: { [weak self] in
            guard let self = self else { return }
            self.darkView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
            self.leftConstraint?.constant = -menuView.bounds.size.width
            menuView.superview?.layoutIfNeeded()
        }, completion: { [weak self] _ in
            self?.darkView.isHidden = true
            self?.isMenuOpened = false
        })
    }
        
    func toggleMenu() {
        guard let menuView = view else { return }
        if isMenuOpened {
            darkView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
            leftConstraint?.constant = -menuView.bounds.size.width
            menuView.superview?.layoutIfNeeded()
        } else {
            darkView.isHidden = false
            darkView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            leftConstraint?.constant = 0
            viewController?.view.layoutIfNeeded()
        }
    }
    
    func updateForCurrentState() {
        setupMenuIfNeeded()
        guard let vc = viewController, let menuView = view else { return }
        
        vc.view.bringSubviewToFront(darkView)
        vc.view.bringSubviewToFront(menuView)
        
        if isMenuOpened {
            leftConstraint?.constant = 0
            darkView.isHidden = false
        } else {
            leftConstraint?.constant = -menuView.bounds.size.width
            darkView.isHidden = true
        }
        menuView.superview?.layoutIfNeeded()
    }
    
    private var animator: UIViewPropertyAnimator?

    @objc private func handlePan(recognizer: UIPanGestureRecognizer) {
        guard let menuView = view else { return }
        
        switch recognizer.state {
        case .began:
            var shouldCancel = false
            if !isMenuOpened && recognizer.location(in: recognizer.view).x > 50 {
                shouldCancel = true
            }
            if animator != nil {
                shouldCancel = true
            }
            if shouldCancel {
                recognizer.isEnabled = false
                recognizer.isEnabled = true
                break
            }
            updateForCurrentState()
            animator = UIViewPropertyAnimator(duration: 0.5, curve: .easeOut, animations: { [weak self] in
                self?.toggleMenu()
            })
            animator?.startAnimation()
            animator?.pauseAnimation()
            
        case .changed:
            var fraction = recognizer.translation(in: recognizer.view).x / menuView.bounds.size.width
            if isMenuOpened {
                fraction = -fraction
            }
            animator?.fractionComplete = fraction
            
        case .ended:
            guard let animator = animator else { return }
            animator.isReversed = animator.fractionComplete < 0.3
            animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
            
            animator.addCompletion { [weak self] _ in
                guard let self = self else { return }
                if !self.animator!.isReversed {
                    self.isMenuOpened.toggle()
                }
                self.updateForCurrentState()
                self.animator = nil
            }
            
        @unknown default:
            break
        }
    }
    
}

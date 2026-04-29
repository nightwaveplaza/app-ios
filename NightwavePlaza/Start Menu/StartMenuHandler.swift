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
    
    // MARK: - Properties
    
    weak var viewController: UIViewController?
    var view: StartMenuView?
    let darkView = UIView()
    var leftConstraint: NSLayoutConstraint?
    private var animator: UIViewPropertyAnimator?
    
    var isMenuOpened = false
    var openMenuGesture: UIPanGestureRecognizer!
    var onSelect: ((_ action: String) -> Void)?
    
    // MARK: - Initialization
        
    // Binds the handler to the host view controller and attaches the global pan gesture for edge swiping
    func setup(inViewController viewController: UIViewController, onSelect block: @escaping (_ action: String) -> Void) {
        self.viewController = viewController
        openMenuGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        self.viewController?.view.addGestureRecognizer(openMenuGesture)
        self.onSelect = block
    }
    
    // MARK: - Layout Configuration
        
    // Lazily constructs the side menu hierarchy on first presentation to optimize initial memory footprint
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
        
        // Forces initial layout off-screen before any animations begin to prevent visual tearing
        vc.view.layoutIfNeeded()
        leftConstraint?.constant = -menuView.bounds.size.width
        vc.view.layoutIfNeeded()
        
        // Binds the background overlay tap to dismiss the menu
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissMenu))
        darkView.addGestureRecognizer(tapGesture)
        
        menuView.onClick = { [weak self] item in
            self?.onSelect?(item.targetAction)
            self?.dismissMenu()
        }
        
        UIView.setAnimationsEnabled(true)
    }
    
    // Re-injects the menu dataset to apply localized strings without tearing down the entire view hierarchy
    func reloadLanguage() {
        let newItems = self.menuItems()
        self.view?.updateItems(newItems)
    }
    
    // Defines the routing payload and visual configuration for the drawer items
    func menuItems() -> [StartMenuItem] {
        return [
            StartMenuItem(icon: UIImage(named: "ic_ratings"), title: "Ratings".localized, targetAction: "ratings", hasBottomLine: false),
            StartMenuItem(icon: UIImage(named: "ic_history"), title: "Play History".localized, targetAction: "history", hasBottomLine: true),
            StartMenuItem(icon: UIImage(named: "ic_favorites"), title: "My Favorites".localized, targetAction: "user-favorites", hasBottomLine: false),
            StartMenuItem(icon: UIImage(named: "ic_profile"), title: "My Profile".localized, targetAction: "user", hasBottomLine: true),
            StartMenuItem(icon: UIImage(named: "ic_settings"), title: "Settings".localized, targetAction: "settings", hasBottomLine: false),
            StartMenuItem(icon: UIImage(named: "ic_help"), title: "About".localized, targetAction: "about", hasBottomLine: false),
            StartMenuItem(icon: UIImage(named: "ic_launcher"), title: "Support Us".localized, targetAction: "support", hasBottomLine: true)
        ]
    }
    
    // MARK: - Visibility Control
        
    // Triggers the programmatic presentation of the drawer, animating both the translation and background dimming
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
    
    @objc func dismissMenu() {
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
        
    // Pre-calculates positions for the property animator during an interactive drag.
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
    
    // Enforces the correct visual layout constraints after an interrupted gesture or state change
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
    

    // MARK: - Interactive Gestures
        
    // Drives the interactive swipe physics using a property animator.
    // Correlates the user's touch translation directly to the animation completion fraction.
    @objc private func handlePan(recognizer: UIPanGestureRecognizer) {
        guard let menuView = view else { return }
        
        switch recognizer.state {
        case .began:
            var shouldCancel = false
            
            // Prevents opening the menu if the swipe didn't originate from the left screen edge
            if !isMenuOpened && recognizer.location(in: recognizer.view).x > 50 {
                shouldCancel = true
            }
            
            // Blocks overlapping animations if the user rapidly swipes multiple times
            if animator != nil {
                shouldCancel = true
            }
            if shouldCancel {
                recognizer.isEnabled = false
                recognizer.isEnabled = true
                break
            }
            
            updateForCurrentState()
            
            // Initializes the interruptible animation state machine
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
            
            // Commits or reverts the animation based on distance threshold (30%)
            animator.isReversed = animator.fractionComplete < 0.3
            animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
            
            animator.addCompletion { [weak self] _ in
                guard let self = self else { return }
                // Safe unwrap to prevent a crash if the animator is deallocated early
                if !self.animator!.isReversed {
                    self.isMenuOpened.toggle()
                }
                self.updateForCurrentState()
                self.animator = nil
            }
            
        default:
            break
        }
    }
    
}

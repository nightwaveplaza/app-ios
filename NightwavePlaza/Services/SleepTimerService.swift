//
//  SleepTimerService.swift
//  NightwavePlaza
//
//  Created by Alexander on 28.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//


import Foundation
import Combine

final class SleepTimerService {
    static let shared = SleepTimerService()
    
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    
    private let playerService = PlayerService.shared
    
    var onSleep: (() -> Void)?
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        playerService.$isPlaying
            .receive(on: DispatchQueue.main)
            .filter { !$0 }
            .sink { [weak self] _ in
                self?.cleanupTimer()
            }
            .store(in: &cancellables)
    }
  
    func sleepAt(timestamp: Double) {
        cleanupTimer()
        
        guard timestamp > 0 else { return }
        
        let fireDate = Date(timeIntervalSince1970: timestamp / 1000)
        let interval = fireDate.timeIntervalSince(Date())
     
        guard interval > 0 else {
            executeSleep()
            return
        }
        
        let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            self?.executeSleep()
        }
        
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    
    private func executeSleep() {
        playerService.pause()
        onSleep?()
        cleanupTimer()
    }
    
    func getRemainingMillis() -> Double {
        guard let fireDate = timer?.fireDate else { return 0 }
        let remaining = fireDate.timeIntervalSince(Date())
        return max(0, remaining * 1000)
    }
    
    private func cleanupTimer() {
        timer?.invalidate()
        timer = nil
    }
}

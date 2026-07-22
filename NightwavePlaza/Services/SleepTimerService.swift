//
//  SleepTimerService.swift
//  NightwavePlaza
//
//  Created by Alexander on 28.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//


import Foundation

final class SleepTimerService {
    static let shared = SleepTimerService()

    private var timer: Timer?

    private let playerService = PlayerService.shared

    private init() {}

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
        cleanupTimer()
    }

    private func cleanupTimer() {
        timer?.invalidate()
        timer = nil
    }
}

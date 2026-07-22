//
//  BackgroundView.swift
//  NightwavePlaza
//
//  Created by Aleksey Garbarev on 30.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//

import AVFoundation
import UIKit

class BackgroundView: UIView {
    private let displayLayer = AVSampleBufferDisplayLayer()
    private var displayLink: CADisplayLink?
    
    // A dedicated serial queue ensures thread safety for all media-related operations
    // (reading buffers, swapping readers), preventing race conditions
    private let mediaQueue = DispatchQueue(label: "plaza.background.media", qos: .userInteractive)
    
    private var currentReader: AVAssetReader?
    private var currentOutput: AVAssetReaderTrackOutput?
    private var nextReader: AVAssetReader?
    private var nextOutput: AVAssetReaderTrackOutput?
    
    // Used to continuously increment timestamps for the seamless looping mechanism
    private var cumulativePTSOffset: CMTime = .zero
    private var assetDuration: CMTime = .zero
    
    private var activeToken: PlaybackToken?
    private var asset: AVURLAsset?
    private var cache = BackgroundCacheManager.shared
    private var downloadTask: Task<Void, Never>?
    
    private var isDecoding = false

    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        displayLayer.videoGravity = .resizeAspectFill
        displayLayer.magnificationFilter = .nearest
        layer.addSublayer(displayLayer)

        // Observing lifecycle events to manually manage GPU resources and playback state
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Disabling implicit CoreAnimation actions to ensure the display layer
        // resizes instantly with the view, preventing visual lag during rotation or layout changes
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.frame = bounds
        CATransaction.commit()
    }

    // MARK: - Public Pipeline

    func setUrl(url: URL) {
        downloadTask?.cancel()
                
        downloadTask = Task { [weak self] in
            guard let self else { return }
            
            do {
                let localUrl = try await cache.getLocalUrl(remoteUrl: url)
                
                // Preventing a race condition: verifying the task wasn't cancelled
                // while waiting for the network/cache response
                guard !Task.isCancelled else { return }
                
                // UI and layer updates must always be routed back to the Main thread
                await MainActor.run { self.setLocalUrl(url: localUrl) }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run { self.clearVideo() }
                }
            }
        }
    }

    func clearVideo() {
        downloadTask?.cancel()
        
        stopPlayback()
        asset = nil
        displayLayer.isHidden = true
    }

    // MARK: - Playback Core

    private func setLocalUrl(url: URL) {
        stopPlayback()
        
        displayLayer.isHidden = false
        
        let newAsset = AVURLAsset(url: url)
        self.asset = newAsset
        self.assetDuration = newAsset.duration
        
        startPlayback(with: newAsset)
    }

    private func startPlayback(with asset: AVURLAsset) {
        let token = PlaybackToken()
        self.activeToken = token
        self.cumulativePTSOffset = .zero
        
        displayLayer.flushAndRemoveImage()
        
        mediaQueue.async { [weak self] in
            guard let self, !token.isCancelled else { return }
            self.prepareInitialReaders(for: asset)
        }
        
        // Deriving the target frame rate from the asset to optimize display link callbacks
        let trackFps = asset.tracks(withMediaType: .video).first?.nominalFrameRate ?? 30.0
        let targetFps = min(max(trackFps > 0 ? trackFps : 30.0, 24.0), 30.0)

        let proxy = DisplayLinkProxy(target: self, selector: #selector(onVSync))
        displayLink = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.onVSync))
        
        // Tying the rendering loop to the device's screen refresh rate
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 30, preferred: targetFps)
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func onVSync() {
        guard let token = activeToken, !token.isCancelled else { return }
        
        // Dropping frames if the previous decoding cycle is still running
        guard !isDecoding else { return }
        isDecoding = true
        
        mediaQueue.async { [weak self] in
            defer { self?.isDecoding = false }
            
            guard let self, !token.isCancelled else { return }
            self.decodeAndEnqueue()
        }
    }

    private func decodeAndEnqueue() {
        // Internal buffer check to prevent memory overflow if the layer isn't consuming frames fast enough
        guard displayLayer.isReadyForMoreMediaData else { return }
        
        if let reader = currentReader, let output = currentOutput, reader.status == .reading {
            if let rawBuffer = output.copyNextSampleBuffer() {
                if let shiftedBuffer = shiftPTS(for: rawBuffer, offset: cumulativePTSOffset) {
                    displayLayer.enqueue(shiftedBuffer)
                }
                return
            }
        }

        // Seamless Loop Implementation
        if currentReader?.status == .completed || currentReader?.status == .failed || currentReader == nil {
            
            // Accumulating total time to offset PTS of the incoming loop
            // AVSampleBufferDisplayLayer requires a strictly monotonically increasing timeline
            cumulativePTSOffset = CMTimeAdd(cumulativePTSOffset, assetDuration)
            
            // Fallback: If the pre-warmed reader isn't ready (e.g., extremely short videos), initialize it synchronously
            if nextReader == nil || nextReader?.status != .reading {
                if let asset = self.asset, let pair = makeReader(for: asset) {
                    nextReader = pair.0
                    nextOutput = pair.1
                }
            }
            
            // Hot-swapping the active reader with the pre-warmed one
            currentReader = nextReader
            currentOutput = nextOutput
            nextReader = nil
            nextOutput = nil
            
            // Immediately push the first frame of the new cycle to prevent a visual stutter
            if let rawBuffer = currentOutput?.copyNextSampleBuffer(),
               let shiftedBuffer = shiftPTS(for: rawBuffer, offset: cumulativePTSOffset) {
                displayLayer.enqueue(shiftedBuffer)
            }
            
            // Pre-warming the reader for the NEXT loop cycle to guarantee zero latency during the swap
            if let asset = self.asset {
                let pair = makeReader(for: asset)
                nextReader = pair?.0
                nextOutput = pair?.1
            }
        }
    }

    private func stopPlayback() {
        activeToken?.isCancelled = true
        activeToken = nil
        
        displayLink?.invalidate()
        displayLink = nil
        
        mediaQueue.async { [weak self] in
            guard let self else { return }
            
            self.currentReader?.cancelReading()
            self.nextReader?.cancelReading()
            self.currentReader = nil
            self.nextReader = nil
            self.currentOutput = nil
            self.nextOutput = nil
            
            // Safe to flush the layer on the Main thread only after all media queue operations
            // have completed, ensuring no late frames are enqueued after the flush
            DispatchQueue.main.async {
                // Skip the flush if a new playback session has already started
                guard self.activeToken == nil else { return }
                self.displayLayer.flushAndRemoveImage()
            }
        }
    }

    // MARK: - App Lifecycle

    @objc private func didEnterBackground() {
        // App goes to background: hardware decoders and GPU contexts are usually suspended
        // Hard stopping the playback avoids crashes related to background OpenGL/Metal usage
        stopPlayback()
    }

    @objc private func willEnterForeground() {
        // Re-initializing the playback pipeline from scratch when returning to foreground
        if let asset = self.asset {
            startPlayback(with: asset)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopPlayback()
    }
    
    // MARK: - Helpers
    
    private func prepareInitialReaders(for asset: AVURLAsset) {
        if let pair = makeReader(for: asset) {
            currentReader = pair.0
            currentOutput = pair.1
        }
        if let pair = makeReader(for: asset) {
            nextReader = pair.0
            nextOutput = pair.1
        }
    }
    
    private func makeReader(for asset: AVURLAsset) -> (AVAssetReader, AVAssetReaderTrackOutput)? {
        guard let track = asset.tracks(withMediaType: .video).first,
              let reader = try? AVAssetReader(asset: asset) else { return nil }
        
        // Requesting uncompressed BGRA buffers for optimal CoreAnimation rendering
        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        
        if reader.canAdd(output) {
            reader.add(output)
        }
        reader.startReading()
        return (reader, output)
    }
    
    // Adjusts the Presentation Time Stamp (PTS) and Decode Time Stamp (DTS) of a sample buffer
    // This is the core mechanism that tricks the AVSampleBufferDisplayLayer into treating
    // multiple looped playbacks as a single continuous video stream
    private func shiftPTS(for sampleBuffer: CMSampleBuffer, offset: CMTime) -> CMSampleBuffer? {
        if offset == .zero { return sampleBuffer }
        
        var count: CMItemCount = 0
        var status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count)
        guard status == noErr, count > 0 else { return sampleBuffer }
        
        var timingInfo = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: Int(count))
        status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: count, arrayToFill: &timingInfo, entriesNeededOut: &count)
        guard status == noErr else { return sampleBuffer }
        
        for i in 0..<Int(count) {
            if timingInfo[i].presentationTimeStamp.isValid {
                timingInfo[i].presentationTimeStamp = CMTimeAdd(timingInfo[i].presentationTimeStamp, offset)
            }
            if timingInfo[i].decodeTimeStamp.isValid {
                timingInfo[i].decodeTimeStamp = CMTimeAdd(timingInfo[i].decodeTimeStamp, offset)
            }
        }
        
        var newBuffer: CMSampleBuffer?
        status = CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault,
                                                       sampleBuffer: sampleBuffer,
                                                       sampleTimingEntryCount: count,
                                                       sampleTimingArray: timingInfo,
                                                       sampleBufferOut: &newBuffer)
        return status == noErr ? newBuffer : sampleBuffer
    }
}

// MARK: - Utilities

// Breaks the retain cycle between CADisplayLink and its target
// CADisplayLink strongly retains its target, which would prevent BackgroundView from deallocating
class DisplayLinkProxy {
    private weak var target: AnyObject?
    private let selector: Selector
    
    init(target: AnyObject, selector: Selector) {
        self.target = target
        self.selector = selector
    }
    
    @objc func onVSync() {
        _ = target?.perform(selector)
    }
}

// A reference-type token used to safely check cancellation state
// inside asynchronously dispatched blocks on the media queue
final class PlaybackToken {
    var isCancelled = false
}

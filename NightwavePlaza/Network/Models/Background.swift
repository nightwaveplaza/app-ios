//
//  Background.swift
//  NightwavePlaza
//

struct Background: Decodable, Equatable {
    let id: Int
    let filename: String
    let src: String
    let videoSrc: String
    let author: String
    let authorLink: String
    let source: String
    let sourceLink: String
}

/// API response wrapper for the /v2/backgrounds endpoint
struct BackgroundResponse: Decodable {
    let data: [Background]
}

//
//  Song.swift
//  NightwavePlaza
//
//  Created by Alexander on 25.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//

struct Song: Decodable {
    let id: String
    let artist: String
    let album: String
    let title: String
    let length: Int
    let artworkSrc: String
    let artworkSmSrc: String
    let previewSrc: String
}

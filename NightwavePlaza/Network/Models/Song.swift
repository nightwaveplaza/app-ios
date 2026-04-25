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
    let artwork_src: String
    let arwork_sm_src: String
    let preview_src: String
}

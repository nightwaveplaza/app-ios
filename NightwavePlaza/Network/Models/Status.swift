//
//  Status.swift
//  NightwavePlaza
//
//  Created by Alexander on 25.04.2026.
//  Copyright © 2026 Alexander Morozov. All rights reserved.
//

struct Status: Decodable {
    let song: Song
    let listeners: Int
    let reactions: Int
    let position: Int
    let updatedAt: Int
}

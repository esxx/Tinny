// Copyright 2026 Eldar Shaidullin. All rights reserved.
// Source code is shared for reference and learning purposes only.

import Foundation

struct Sound: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let fileName: String
    let isCustom: Bool
    
    init(id: String, name: String, fileName: String, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.isCustom = isCustom
    }
    
    static func builtInSound(_ id: String) -> Sound {
        return Sound(id: id, name: "", fileName: "\(id).caf")
    }
    
    static func customSound(id: String, name: String, fileName: String) -> Sound {
        return Sound(id: id, name: name, fileName: fileName, isCustom: true)
    }
}

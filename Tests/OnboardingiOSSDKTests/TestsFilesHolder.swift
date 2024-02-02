//
//  File.swift
//  
//
//  Created by Oleg Kuplin on 02.02.2024.
//

import Foundation

final class TestsFilesHolder {
    
    static let shared = TestsFilesHolder()
   
    private var cache: [String: URL] = [:] // Save all local files in this cache
    private let baseURL = urlForRestServicesTestsDir()
    
    init() {
        guard let enumerator = FileManager.default.enumerator(
            at: baseURL,
            includingPropertiesForKeys: [.nameKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: nil) else {
            fatalError("Could not enumerate \(baseURL)")
        }
        
        for case let url as URL in enumerator where url.isFileURL {
            cache[url.lastPathComponent] = url
        }
    }
    
    func url(for fileName: String) -> URL? {
        return cache[fileName]
    }
    
    private static func urlForRestServicesTestsDir() -> URL {
        let currentFileURL = URL(fileURLWithPath: "\(#file)", isDirectory: false)
        return currentFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
    
}

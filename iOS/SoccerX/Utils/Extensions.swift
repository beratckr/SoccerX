import Foundation
import FirebaseFirestore
import CryptoKit
import Compression

// MARK: - Codable Extensions for Firestore

// UserStats extension moved to Models/User.swift to avoid duplicates

// GameEvent and MVPScoreBreakdown extensions moved to Models/Game.swift to avoid duplicates

// MARK: - Data Extensions

extension Data {
    // MARK: - SHA256 Hash
    var sha256Hash: String {
        let hash = SHA256.hash(data: self)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Compression
    func compressed(using algorithm: SoccerXCompressionAlgorithm = .zlib) -> Data? {
        return self.compress(withAlgorithm: algorithm)
    }
    
    func decompressed(using algorithm: SoccerXCompressionAlgorithm = .zlib) -> Data? {
        return self.decompress(withAlgorithm: algorithm)
    }
    
    // MARK: - Compression Implementation
    func compress(withAlgorithm algorithm: SoccerXCompressionAlgorithm) -> Data? {
        return self.withUnsafeBytes { bytes in
            guard let bytes = bytes.bindMemory(to: UInt8.self).baseAddress else { return nil }
            
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
            defer { destinationBuffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(
                destinationBuffer, count,
                bytes, count,
                nil, algorithm.algorithm
            )
            
            guard compressedSize > 0 else { return nil }
            return Data(bytes: destinationBuffer, count: compressedSize)
        }
    }
    
    func decompress(withAlgorithm algorithm: SoccerXCompressionAlgorithm) -> Data? {
        return self.withUnsafeBytes { bytes in
            guard let bytes = bytes.bindMemory(to: UInt8.self).baseAddress else { return nil }
            
            // Allocate a buffer that's 4x the compressed size as initial guess
            let destinationBufferSize = count * 4
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationBufferSize)
            defer { destinationBuffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                destinationBuffer, destinationBufferSize,
                bytes, count,
                nil, algorithm.algorithm
            )
            
            guard decompressedSize > 0 else { return nil }
            return Data(bytes: destinationBuffer, count: decompressedSize)
        }
    }
}

// MARK: - Compression Algorithm
enum SoccerXCompressionAlgorithm {
    case zlib
    case lzfse
    case lz4
    case lzma
    
    var algorithm: compression_algorithm {
        switch self {
        case .zlib:
            return COMPRESSION_ZLIB
        case .lzfse:
            return COMPRESSION_LZFSE
        case .lz4:
            return COMPRESSION_LZ4
        case .lzma:
            return COMPRESSION_LZMA
        }
    }
}
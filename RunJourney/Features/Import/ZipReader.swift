import Foundation
import Compression

/// 最小限のZIP解凍。Garmin Connect Bulk Export等の単一エントリZIPに最適化。
/// - 複数エントリ: 全部スキャンして配列で返す
/// - 圧縮方式: stored (0) / deflate (8)
/// - ZIP64 / 暗号化 / マルチパート: 非対応
enum ZipReader {

    struct Entry {
        let name: String
        let data: Data
    }

    /// ZIP内のエントリを全部抽出。central directory は使わず local file header をシーケンシャルに走査。
    static func extractAll(from data: Data) throws -> [Entry] {
        var entries: [Entry] = []
        var offset = 0

        while offset + 30 <= data.count {
            let sig = data.subdata(in: offset..<offset + 4).withUnsafeBytes {
                $0.load(as: UInt32.self).littleEndian
            }
            // Local file header signature
            guard sig == 0x04034b50 else {
                // central directory (0x02014b50) や end-of-central-directory (0x06054b50) に到達 → 終了
                break
            }

            // Local file header layout (LE):
            //   4: signature
            //   6: version needed
            //   8: general purpose bit flag (uint16)
            //  10: compression method (uint16)  [0=stored, 8=deflate]
            //  12: last mod time
            //  14: last mod date
            //  16: crc-32
            //  20: compressed size (uint32)
            //  24: uncompressed size (uint32)
            //  28: file name length (uint16)
            //  30: extra field length (uint16)
            let bitFlag = readUInt16LE(data: data, at: offset + 6)
            let method = readUInt16LE(data: data, at: offset + 8)
            let compressedSize = Int(readUInt32LE(data: data, at: offset + 18))
            let uncompressedSize = Int(readUInt32LE(data: data, at: offset + 22))
            let nameLen = Int(readUInt16LE(data: data, at: offset + 26))
            let extraLen = Int(readUInt16LE(data: data, at: offset + 28))

            // Encrypted (bit0 of GP flag)
            if bitFlag & 0x0001 != 0 {
                throw ImportError.parseFailed("ZIP: encrypted entries are not supported")
            }
            // Data descriptor (bit3): sizes = 0 in header, descriptor follows data
            // We can't know compressed size in advance; scanning becomes complex. Skip.
            if bitFlag & 0x0008 != 0 && compressedSize == 0 {
                throw ImportError.parseFailed("ZIP: streaming entries with data descriptor are not supported")
            }

            let nameStart = offset + 30
            let nameEnd = nameStart + nameLen
            guard nameEnd <= data.count else {
                throw ImportError.parseFailed("ZIP: truncated entry name")
            }
            let name = String(data: data.subdata(in: nameStart..<nameEnd), encoding: .utf8) ?? "(unknown)"

            let dataStart = nameEnd + extraLen
            let dataEnd = dataStart + compressedSize
            guard dataEnd <= data.count else {
                throw ImportError.parseFailed("ZIP: truncated entry data (\(name))")
            }
            let chunk = data.subdata(in: dataStart..<dataEnd)

            // ディレクトリエントリは name 末尾が "/" → スキップ
            if !name.hasSuffix("/") {
                let payload: Data
                switch method {
                case 0: // stored
                    payload = chunk
                case 8: // deflate
                    payload = try inflate(chunk, expectedSize: uncompressedSize)
                default:
                    throw ImportError.parseFailed("ZIP: unsupported compression method \(method) for \(name)")
                }
                entries.append(Entry(name: name, data: payload))
            }

            offset = dataEnd
        }

        if entries.isEmpty {
            throw ImportError.parseFailed("ZIP: no usable entries found")
        }
        return entries
    }

    /// 拡張子で最初に見つかるエントリを返す。
    static func firstEntry(from data: Data, withExtension ext: String) throws -> Entry {
        let entries = try extractAll(from: data)
        let lower = ext.lowercased()
        if let match = entries.first(where: { ($0.name as NSString).pathExtension.lowercased() == lower }) {
            return match
        }
        throw ImportError.parseFailed("ZIP: 拡張子 .\(ext) のファイルが見つかりません（含まれるファイル: \(entries.map(\.name).joined(separator: ", "))）")
    }

    // MARK: - Helpers

    private static func readUInt16LE(data: Data, at offset: Int) -> UInt16 {
        return data.subdata(in: offset..<offset + 2).withUnsafeBytes {
            $0.load(as: UInt16.self).littleEndian
        }
    }

    private static func readUInt32LE(data: Data, at offset: Int) -> UInt32 {
        return data.subdata(in: offset..<offset + 4).withUnsafeBytes {
            $0.load(as: UInt32.self).littleEndian
        }
    }

    /// raw deflate を Compression framework で解凍。ZLIB アルゴリズムで raw deflate を扱える。
    private static func inflate(_ compressed: Data, expectedSize: Int) throws -> Data {
        // 出力バッファサイズ。expectedSize が 0 (ZIPで未指定) の場合は推定値で開始。
        let bufferSize = max(expectedSize, max(compressed.count * 8, 1024))
        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { dst.deallocate() }

        let result = compressed.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Int in
            guard let src = srcPtr.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(
                dst, bufferSize,
                src, compressed.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        if result == 0 {
            throw ImportError.parseFailed("ZIP: deflate decode failed (buffer may be too small or data corrupt)")
        }
        return Data(bytes: dst, count: result)
    }
}

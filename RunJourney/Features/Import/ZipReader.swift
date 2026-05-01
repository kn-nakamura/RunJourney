import Foundation
import Compression

/// 最小限のZIP解凍。Garmin Connect Bulk Export の data descriptor 形式（streaming）にも対応。
///
/// **対応**: stored(0), deflate(8), single-disk archives, EOCD-based central directory
/// **非対応**: ZIP64, encryption, multi-volume
///
/// 実装方針: End of Central Directory Record (EOCD) を末尾から検索 →
/// Central Directory を辿って各エントリのサイズ・local header offset を信頼度高く取得する。
/// (Local file header の compressed_size = 0 を含む streaming 形式でも安全に解凍できる)
enum ZipReader {

    struct Entry {
        let name: String
        let data: Data
    }

    static func extractAll(from data: Data) throws -> [Entry] {
        guard let eocdOffset = findEOCD(in: data) else {
            throw ImportError.parseFailed("ZIP: End of Central Directory が見つかりません（破損したZIPの可能性）")
        }

        // EOCD layout (LE):
        //   0: signature 0x06054b50
        //   4: disk number
        //   6: disk where central directory starts
        //   8: number of central directory records on this disk
        //  10: total number of central directory records
        //  12: size of central directory (uint32)
        //  16: offset of central directory (uint32)
        //  20: comment length (uint16)
        let totalEntries = Int(readUInt16LE(data: data, at: eocdOffset + 10))
        let cdOffset = Int(readUInt32LE(data: data, at: eocdOffset + 16))

        var entries: [Entry] = []
        var pos = cdOffset

        for _ in 0..<totalEntries {
            guard pos + 46 <= data.count else {
                throw ImportError.parseFailed("ZIP: central directory が破損しています")
            }
            let sig = readUInt32LE(data: data, at: pos)
            guard sig == 0x02014b50 else {
                // Central directory entry signature 不一致 → 終了
                break
            }

            // Central directory entry layout (抜粋):
            //  10: compression method (uint16)
            //  20: compressed size (uint32)
            //  24: uncompressed size (uint32)
            //  28: file name length (uint16)
            //  30: extra field length (uint16)
            //  32: file comment length (uint16)
            //  42: relative offset of local header (uint32)
            //  46: file name (variable)
            let method = readUInt16LE(data: data, at: pos + 10)
            let compressedSize = Int(readUInt32LE(data: data, at: pos + 20))
            let uncompressedSize = Int(readUInt32LE(data: data, at: pos + 24))
            let nameLen = Int(readUInt16LE(data: data, at: pos + 28))
            let extraLen = Int(readUInt16LE(data: data, at: pos + 30))
            let commentLen = Int(readUInt16LE(data: data, at: pos + 32))
            let localOffset = Int(readUInt32LE(data: data, at: pos + 42))

            let nameStart = pos + 46
            let nameEnd = nameStart + nameLen
            guard nameEnd <= data.count else {
                throw ImportError.parseFailed("ZIP: ファイル名がはみ出しています")
            }
            let name = String(data: data.subdata(in: nameStart..<nameEnd), encoding: .utf8) ?? "(unknown)"

            // 次のエントリの開始位置
            pos = nameEnd + extraLen + commentLen

            // ディレクトリ自身はスキップ
            if name.hasSuffix("/") { continue }

            // Local file header から data の正確な開始位置を求める
            guard localOffset + 30 <= data.count else {
                throw ImportError.parseFailed("ZIP: local header offset が不正 (\(name))")
            }
            let localSig = readUInt32LE(data: data, at: localOffset)
            guard localSig == 0x04034b50 else {
                throw ImportError.parseFailed("ZIP: local file header signature 不一致 (\(name))")
            }
            let localNameLen = Int(readUInt16LE(data: data, at: localOffset + 26))
            let localExtraLen = Int(readUInt16LE(data: data, at: localOffset + 28))

            let dataStart = localOffset + 30 + localNameLen + localExtraLen
            let dataEnd = dataStart + compressedSize
            guard dataEnd <= data.count else {
                throw ImportError.parseFailed("ZIP: 圧縮データがはみ出しています (\(name))")
            }
            let chunk = data.subdata(in: dataStart..<dataEnd)

            let payload: Data
            switch method {
            case 0: // stored
                payload = chunk
            case 8: // deflate
                payload = try inflate(chunk, expectedSize: uncompressedSize)
            default:
                throw ImportError.parseFailed("ZIP: 未対応の圧縮方式 \(method) (\(name))")
            }
            entries.append(Entry(name: name, data: payload))
        }

        if entries.isEmpty {
            throw ImportError.parseFailed("ZIP: 取り込み可能なファイルが見つかりません")
        }
        return entries
    }

    static func firstEntry(from data: Data, withExtension ext: String) throws -> Entry {
        let entries = try extractAll(from: data)
        let lower = ext.lowercased()
        if let match = entries.first(where: { ($0.name as NSString).pathExtension.lowercased() == lower }) {
            return match
        }
        throw ImportError.parseFailed("ZIP: .\(ext) が見つかりません — 含まれるファイル: \(entries.map(\.name).joined(separator: ", "))")
    }

    // MARK: - Private helpers

    /// EOCD signature を末尾から探す。コメントは最大 65535 バイトなので最大 65557 バイト遡る。
    private static func findEOCD(in data: Data) -> Int? {
        let signature: [UInt8] = [0x50, 0x4b, 0x05, 0x06]
        let minOffset = max(0, data.count - 22 - 65535)
        var i = data.count - 22
        while i >= minOffset {
            if data[i] == signature[0] && data[i + 1] == signature[1]
                && data[i + 2] == signature[2] && data[i + 3] == signature[3] {
                return i
            }
            i -= 1
        }
        return nil
    }

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

    /// raw deflate を Compression framework で解凍。
    /// COMPRESSION_ZLIB は raw deflate (zlib header無し) を扱える。
    /// expectedSize が 0 の場合（古い ZIP）でも数倍のバッファで再試行する。
    private static func inflate(_ compressed: Data, expectedSize: Int) throws -> Data {
        var bufferSize = expectedSize > 0 ? expectedSize : compressed.count * 8
        if bufferSize < 1024 { bufferSize = 1024 }

        for attempt in 0..<3 {
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
            if result > 0 {
                // 出力バッファが満杯（=サイズ不足）なら次でリトライ
                if result < bufferSize || attempt == 2 {
                    return Data(bytes: dst, count: result)
                }
            } else if attempt == 2 {
                throw ImportError.parseFailed("ZIP: deflate decode failed (出力\(bufferSize)bytes でも不足、または破損)")
            }
            bufferSize *= 4
        }
        throw ImportError.parseFailed("ZIP: deflate decode failed")
    }
}

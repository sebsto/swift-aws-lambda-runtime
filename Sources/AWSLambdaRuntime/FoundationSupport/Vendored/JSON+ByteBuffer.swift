//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAWSLambdaRuntime open source project
//
// Copyright (c) 2017-2022 Apple Inc. and the SwiftAWSLambdaRuntime project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAWSLambdaRuntime project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2019-2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if FoundationJSONSupport
import NIOCore

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension ByteBuffer {
    /// Attempts to decode the `length` bytes from `index` using the `JSONDecoder` `decoder` as `T`.
    ///
    /// - parameters:
    ///    - type: The type type that is attempted to be decoded.
    ///    - decoder: The `JSONDecoder` that is used for the decoding.
    ///    - index: The index of the first byte to decode.
    ///    - length: The number of bytes to decode.
    /// - returns: The decoded value if successful or `nil` if there are not enough readable bytes available.
    @inlinable
    func getJSONDecodable<T: Decodable>(
        _ type: T.Type,
        decoder: JSONDecoder = JSONDecoder(),
        at index: Int,
        length: Int
    ) throws -> T? {
        guard let data = self.getData(at: index, length: length, byteTransferStrategy: .noCopy) else {
            return nil
        }
        return try decoder.decode(T.self, from: data)
    }

    /// Encodes `value` using the `JSONEncoder` `encoder` and set the resulting bytes into this `ByteBuffer` at the
    /// given `index`.
    ///
    /// - note: The `writerIndex` remains unchanged.
    ///
    /// - parameters:
    ///     - value: An `Encodable` value to encode.
    ///     - encoder: The `JSONEncoder` to encode `value` with.
    /// - returns: The number of bytes written.
    @inlinable
    @discardableResult
    mutating func setJSONEncodable<T: Encodable>(
        _ value: T,
        encoder: JSONEncoder = JSONEncoder(),
        at index: Int
    ) throws -> Int {
        let data = try encoder.encode(value)
        return self.setBytes(data, at: index)
    }

    /// Encodes `value` using the `JSONEncoder` `encoder` and writes the resulting bytes into this `ByteBuffer`.
    ///
    /// If successful, this will move the writer index forward by the number of bytes written.
    ///
    /// - parameters:
    ///     - value: An `Encodable` value to encode.
    ///     - encoder: The `JSONEncoder` to encode `value` with.
    /// - returns: The number of bytes written.
    @inlinable
    @discardableResult
    mutating func writeJSONEncodable<T: Encodable>(
        _ value: T,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> Int {
        let result = try self.setJSONEncodable(value, encoder: encoder, at: self.writerIndex)
        self.moveWriterIndex(forwardBy: result)
        return result
    }
}

extension JSONDecoder {
    /// Returns a value of the type you specify, decoded from a JSON object inside the readable bytes of a `ByteBuffer`.
    ///
    /// If the `ByteBuffer` does not contain valid JSON, this method throws the
    /// `DecodingError.dataCorrupted(_:)` error. If a value within the JSON
    /// fails to decode, this method throws the corresponding error.
    ///
    /// - note: The provided `ByteBuffer` remains unchanged, neither the `readerIndex` nor the `writerIndex` will move.
    ///         If you would like the `readerIndex` to move, consider using `ByteBuffer.readJSONDecodable(_:length:)`.
    ///
    /// - parameters:
    ///     - type: The type of the value to decode from the supplied JSON object.
    ///     - buffer: The `ByteBuffer` that contains JSON object to decode.
    /// - returns: The decoded object.
    func decode<T: Decodable>(_ type: T.Type, from buffer: ByteBuffer) throws -> T {
        try buffer.getJSONDecodable(
            T.self,
            decoder: self,
            at: buffer.readerIndex,
            length: buffer.readableBytes
        )!  // must work, enough readable bytes// must work, enough readable bytes
    }
}

extension JSONEncoder {
    /// Writes a JSON-encoded representation of the value you supply into the supplied `ByteBuffer`.
    ///
    /// - parameters:
    ///     - value: The value to encode as JSON.
    ///     - buffer: The `ByteBuffer` to encode into.
    @inlinable
    func encode<T: Encodable>(
        _ value: T,
        into buffer: inout ByteBuffer
    ) throws {
        try buffer.writeJSONEncodable(value, encoder: self)
    }

    /// Writes a JSON-encoded representation of the value you supply into a `ByteBuffer` that is freshly allocated.
    ///
    /// - parameters:
    ///     - value: The value to encode as JSON.
    ///     - allocator: The `ByteBufferAllocator` which is used to allocate the `ByteBuffer` to be returned.
    /// - returns: The `ByteBuffer` containing the encoded JSON.
    func encodeAsByteBuffer<T: Encodable>(_ value: T, allocator: ByteBufferAllocator) throws -> ByteBuffer {
        let data = try self.encode(value)
        var buffer = allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        return buffer
    }
}
#endif  // trait: FoundationJSONSupport

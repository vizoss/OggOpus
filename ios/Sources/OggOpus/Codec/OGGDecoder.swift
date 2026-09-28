import YbridOgg
import YbridOpus

// 16KHz 单声道
class OGGDecoder {

    var sampleRate: Int32 = 16000
    var pcmData = Data()

    private let MAX_FRAME_SIZE = Int32(10 * 1024)

    private var streamState: ogg_stream_state  // state of ogg stream
    private var syncState: ogg_sync_state  // tracks the status of data during decoding
    private var packet: ogg_packet  // packet within a stream passing information

    private var decoder: OpaquePointer  // decoder to convert opus to pcm

    private var pageNo = 0
    private var pagePacketNo = 0

    init(audioData: Data) throws {
        // set properties
        streamState = ogg_stream_state()
        syncState = ogg_sync_state()
        packet = ogg_packet()
        var page = ogg_page()

        let numChannels = 1
        // status to catch errors when creating decoder
        var status = Int32(0)
        decoder = opus_decoder_create(sampleRate, Int32(numChannels), &status)
        if status != noErr {
            throw CocoaError(.ubiquitousFileUbiquityServerNotAvailable)
        }

        // initialize ogg sync state
        ogg_sync_init(&syncState)
        ogg_stream_init(&streamState, 0)
        var processedByteCount = 0

        pageNo = 0
        pagePacketNo = 0
        while processedByteCount < audioData.count {
            // determine the size of the buffer to ask for
            var bufferSize: Int
            if audioData.count - processedByteCount > 4096 {
                bufferSize = 4096
            } else {
                bufferSize = audioData.count - processedByteCount
            }

            // obtain a buffer from the syncState
            var bufferData: UnsafeMutablePointer<Int8>
            bufferData = ogg_sync_buffer(&syncState, bufferSize)

            // write data from the service into the syncState buffer
            bufferData.withMemoryRebound(to: UInt8.self, capacity: bufferSize) { bufferDataUInt8 in
                audioData.copyBytes(
                    to: bufferDataUInt8, from: processedByteCount..<processedByteCount + bufferSize)
            }
            processedByteCount += bufferSize
            // notify syncState of number of bytes we actually wrote
            status = ogg_sync_wrote(&syncState, bufferSize)
            if status == -1 {
                break
            }

            // attempt to get a page from the data that we wrote
            while ogg_sync_pageout(&syncState, &page) == 1 {
                if pagePacketNo == 0 {
                    if page.body_len == 19 || page.body_len == 80 {
                        ogg_stream_reset_serialno(&streamState, ogg_page_serialno(&page))
                        pagePacketNo += 1
                        streamState.packetno = ogg_int64_t(pagePacketNo)
                        pageNo += 1
                    }

                } else if pagePacketNo == 1 {
                    pagePacketNo += 1
                    streamState.packetno = ogg_int64_t(pagePacketNo)
                    pageNo += 1
                } else {
                    streamState.pageno = pageNo
                    // add page to the ogg stream
                    status = ogg_stream_pagein(&streamState, &page)
                    if status == -1 {
                        break
                    }

                    // extract packets from the ogg stream until no packets are left
                    pageNo += 1
                    try extractPacket(&streamState, &packet)
                }
            }
        }

        // perform cleanup
        opus_decoder_destroy(decoder)
        ogg_stream_clear(&streamState)
        ogg_sync_clear(&syncState)
    }

    // Extract a packet from the ogg stream and store the extracted data within the packet object.
    private func extractPacket(_ streamState: inout ogg_stream_state, _ packet: inout ogg_packet)
        throws
    {
        // attempt to extract a packet from the ogg stream
        while ogg_stream_packetout(&streamState, &packet) == 1 {
            // execute if initial stream header
            let pcmDataBuffer = UnsafeMutablePointer<Int16>.allocate(capacity: 8196)
            let decodeCount = opus_decode(
                decoder, packet.packet, Int32(packet.bytes), pcmDataBuffer, 8196, 0)
            if decodeCount > 0 {
                let bufferPointer = UnsafeBufferPointer(
                    start: pcmDataBuffer, count: Int(decodeCount))
                pcmData.append(bufferPointer)
                pagePacketNo += 1
            }
            pcmDataBuffer.deallocate()
        }

    }
}

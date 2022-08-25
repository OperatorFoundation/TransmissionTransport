import Foundation
import Transport
import Chord
import Datable
import Transmission
import Net
import Logging
import SwiftHexTools

public class TransportToTransmissionConnection: Transmission.Connection
{
    let id: Int
    let log: Logger?
    let states: BlockingQueue<Bool> = BlockingQueue<Bool>()
    let connectLock = DispatchGroup()
    let readLock = DispatchGroup()
    let writeLock = DispatchGroup()
    
    var buffer: Data = Data()
    var connection: Transport.Connection
    var connectionClosed = false

    
    public convenience init?(logger: Logger? = nil, _ connectionFactory: @escaping () -> Transport.Connection?)
    {
        guard let connection = connectionFactory() else
        {return nil}
        
        self.init(connection, logger: logger)
    }

    public init?(_ connection: Transport.Connection, logger: Logger? = nil)
    {
        self.connection = connection
        self.log = logger
        self.id = Int.random(in: 0..<Int.max)
        self.connection.stateUpdateHandler = self.handleState
        self.connection.start(queue: .global())
        let success = self.states.dequeue()
        
        guard success else
        {return nil}
    }

    public func read(size: Int) -> Data?
    {
        readLock.enter()

        if size == 0
        {
            log?.error("TransportTransmission read size was zero")
            readLock.leave()
            
            return nil
        }

        if size <= buffer.count
        {
            let result = Data(buffer[0..<size])
            buffer = Data(buffer[size..<buffer.count])
            readLock.leave()
            
            return result
        }

        guard let data = networkRead(size: size) else
        {
            log?.error("transmission read's network read failed")
            readLock.leave()
            return nil
        }

        buffer.append(data)

        guard size <= buffer.count else
        {
            log?.error("TransportTransmission read asked for more bytes than available in the buffer")
            readLock.leave()
            return nil
        }

        let result = Data(buffer[0..<size])
        buffer = Data(buffer[size..<buffer.count])
        readLock.leave()
        
        return result
    }

    public func read(maxSize: Int) -> Data?
    {
        readLock.enter()

        if maxSize == 0
        {
            readLock.leave()
            return nil
        }

        let size = maxSize <= buffer.count ? maxSize : buffer.count

        if size > 0
        {
            let result = Data(buffer[0..<size])
            buffer = Data(buffer[size..<buffer.count])

            readLock.leave()
            return result
        }
        else
        {
            // Buffer is empty, so we need to do a network read
            var data: Data?
            let transportLock = DispatchGroup()
            transportLock.enter()
            
            self.connection.receive(minimumIncompleteLength: 1, maximumLength: maxSize)
            {
                maybeData, maybeContext, isComplete, maybeError in

                guard let transportData = maybeData else
                {
                    data = nil
                    return
                }

                guard maybeError == nil else
                {
                    data = nil
                    return
                }

                data = transportData
            }

            guard let bytes = data else
            {
                readLock.leave()
                return nil
            }

            buffer.append(bytes)
            let targetSize = min(maxSize, buffer.count)
            let result = Data(buffer[0..<targetSize])
            buffer = Data(buffer[targetSize..<buffer.count])
            readLock.leave()
            
            return result
        }
    }

    public func readWithLengthPrefix(prefixSizeInBits: Int) -> Data?
    {
        readLock.enter()

        var maybeLength: Int? = nil

        switch prefixSizeInBits
        {
            case 8:
                guard let lengthData = networkRead(size: prefixSizeInBits/8) else
                {
                    readLock.leave()
                    return nil
                }

                guard let boundedLength = UInt8(maybeNetworkData: lengthData) else
                {
                    readLock.leave()
                    return nil
                }

                maybeLength = Int(boundedLength)
            case 16:
                guard let lengthData = networkRead(size: prefixSizeInBits/8) else
                {
                    readLock.leave()
                    return nil
                }

                guard let boundedLength = UInt16(maybeNetworkData: lengthData) else
                {
                    readLock.leave()
                    return nil
                }

                maybeLength = Int(boundedLength)
            case 32:
                guard let lengthData = networkRead(size: prefixSizeInBits/8) else
                {
                    readLock.leave()
                    return nil
                }

                guard let boundedLength = UInt32(maybeNetworkData: lengthData) else
                {
                    readLock.leave()
                    return nil
                }

                maybeLength = Int(boundedLength)
            case 64:
                guard let lengthData = networkRead(size: prefixSizeInBits/8) else
                {
                    readLock.leave()
                    return nil
                }

                guard let boundedLength = UInt64(maybeNetworkData: lengthData) else
                {
                    readLock.leave()
                    return nil
                }

                maybeLength = Int(boundedLength)
            default:
                readLock.leave()
                return nil
        }

        guard let length = maybeLength else
        {
            readLock.leave()
            return nil
        }

        guard let data = networkRead(size: length) else
        {
            readLock.leave()
            return nil
        }

        return data
    }

    public func write(string: String) -> Bool
    {
        writeLock.enter()
        let data = string.data
        writeLock.leave()
        
        return write(data: data)
    }

    public func write(data: Data) -> Bool
    {
        writeLock.enter()
        let success = networkWrite(data: data)
        writeLock.leave()

        return success
    }

    public func writeWithLengthPrefix(data: Data, prefixSizeInBits: Int) -> Bool
    {
        writeLock.enter()

        let length = data.count

        var maybeLengthData: Data? = nil

        switch prefixSizeInBits
        {
            case 8:
                let boundedLength = UInt8(length)
                maybeLengthData = boundedLength.maybeNetworkData
            case 16:
                let boundedLength = UInt16(length)
                maybeLengthData = boundedLength.maybeNetworkData
            case 32:
                let boundedLength = UInt32(length)
                maybeLengthData = boundedLength.maybeNetworkData
            case 64:
                let boundedLength = UInt64(length)
                maybeLengthData = boundedLength.maybeNetworkData
            default:
                maybeLengthData = nil
        }

        guard let lengthData = maybeLengthData else
        {
            writeLock.leave()
            return false
        }

        let atomicData = lengthData + data
        let success = networkWrite(data: atomicData)
        writeLock.leave()
        return success
    }

    func handleState(state: NWConnection.State)
    {
        connectLock.wait()

        switch state
        {
            case .ready:
                self.states.enqueue(element: true)
                return
            case .cancelled:
                self.states.enqueue(element: false)
                self.close()
                return
            case .failed(_):
                self.states.enqueue(element: false)
                self.failConnect()
                return
            case .waiting(_):
                self.states.enqueue(element: false)
                self.close()
                return
            default:
                return
        }
    }

    func failConnect()
    {
        self.log?.debug("TransmissionTransport: TransportTransmission - received a cancelled state update. Closing the connection.")
        self.close()
    }
    
    public func close()
    {
        if !connectionClosed
        {
            self.log?.debug("TransmissionTransport: TransportTransmission.close - Closing the connection.")
            connectionClosed = true
            self.connection.cancel()
            self.connection.stateUpdateHandler = nil
        }
        else
        {
            self.log?.debug("TransmissionTransport: TransportTransmission.close - ignoring a close connection request, the connection is already closed.")
        }
        
    }

    func networkRead(size: Int) -> Data?
    {
        var data: Data?

        let transportLock = DispatchGroup()
        transportLock.enter()
        self.connection.receive(minimumIncompleteLength: size, maximumLength: size)
        {
            maybeData, maybeContext, isComplete, maybeError in

            guard let transportData = maybeData else
            {
                data = nil
                return
            }

            guard maybeError == nil else
            {
                data = nil
                return
            }

            data = transportData
        }

        return data
    }

    func networkWrite(data: Data) -> Bool
    {
        var success = false
        let lock = DispatchGroup()
        lock.enter()
        self.connection.send(content: data, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed(
            {
                error in

                guard error == nil else
                {
                    success = false
                    lock.leave()
                    return
                }

                success = true
                lock.leave()
                return
            }))
        lock.wait()

        return success
    }
}

public func maybeLog(message: String, logger: Logger? = nil) {
    if logger != nil {
        logger!.debug("\(message)")
    } else {
        print(message)
    }
}

func makeTransmissionConnection(_ connectionFactory: @escaping () -> Transport.Connection?) -> Transmission.Connection?
{
    return TransportToTransmissionConnection(connectionFactory)
}

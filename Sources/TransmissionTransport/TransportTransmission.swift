import Foundation
import Logging

import Chord
import Datable
import Net
import Straw
import SwiftHexTools
import Transmission
import Transport

public class TransportToTransmissionConnection: Transmission.Connection
{
    let id: Int
    let log: Logger?
    let states: BlockingQueue<Bool> = BlockingQueue<Bool>()
    let connectLock = DispatchSemaphore(value: 1)
    let readLock = DispatchSemaphore(value: 1)
    let writeLock = DispatchSemaphore(value: 1)
    let straw = Straw()
    
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
        readLock.wait()

        if size == 0
        {
            log?.error("TransportTransmission read size was zero")

            readLock.signal()
            return nil
        }

        if size <= self.straw.count
        {
            let result = try? self.straw.read(size: size)

            readLock.signal()
            return result
        }

        guard let data = networkRead(size: size - self.straw.count) else
        {
            log?.error("transmission read's network read failed")

            readLock.signal()
            return nil
        }

        straw.write(data)

        let result = try? self.straw.read(size: size)

        readLock.signal()
        return result
    }

    public func unsafeRead(size: Int) -> Data?
    {
        if size == 0
        {
            log?.error("TransportTransmission read size was zero")

            return nil
        }

        if size <= self.straw.count
        {
            let result = try? self.straw.read(size: size)

            return result
        }

        guard let data = networkRead(size: size - self.straw.count) else
        {
            log?.error("transmission read's network read failed")

            return nil
        }

        straw.write(data)

        let result = try? self.straw.read(size: size)

        return result
    }

    public func read(maxSize: Int) -> Data?
    {
        readLock.wait()

        if maxSize == 0
        {
            log?.error("TransportTransmission read size was zero")

            readLock.signal()
            return nil
        }

        if self.straw.isEmpty
        {
            guard let data = networkRead(maxSize: maxSize) else
            {
                log?.error("transmission read's network read failed")

                readLock.signal()
                return nil
            }

            straw.write(data)
        }

        let result = try? self.straw.read(maxSize: maxSize)

        readLock.signal()
        return result
    }

    public func readWithLengthPrefix(prefixSizeInBits: Int) -> Data?
    {
        return TransmissionTypes.readWithLengthPrefix(prefixSizeInBits: prefixSizeInBits, connection: self)
    }

    public func write(string: String) -> Bool
    {
        let data = string.data

        return write(data: data)
    }

    public func write(data: Data) -> Bool
    {
        writeLock.wait()

        let success = networkWrite(data: data)

        writeLock.signal()
        return success
    }

    public func writeWithLengthPrefix(data: Data, prefixSizeInBits: Int) -> Bool
    {
        return TransmissionTypes.writeWithLengthPrefix(data: data, prefixSizeInBits: prefixSizeInBits, connection: self)
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
        let transportLock = DispatchSemaphore(value: 0)

        var maybeResult: Data? = nil
        self.connection.receive(minimumIncompleteLength: size, maximumLength: size)
        {
            maybeData, maybeContext, isComplete, maybeError in

            guard let transportData = maybeData else
            {
                transportLock.signal()
                return
            }

            guard maybeError == nil else
            {
                transportLock.signal()
                return
            }

            maybeResult = transportData

            transportLock.signal()
            return
        }

        transportLock.wait()

        return maybeResult
    }

    func networkRead(maxSize: Int) -> Data?
    {
        let transportLock = DispatchSemaphore(value: 0)

        var maybeResult: Data? = nil
        self.connection.receive(minimumIncompleteLength: 1, maximumLength: maxSize)
        {
            maybeData, maybeContext, isComplete, maybeError in

            guard let transportData = maybeData else
            {
                transportLock.signal()
                return
            }

            guard maybeError == nil else
            {
                transportLock.signal()
                return
            }

            maybeResult = transportData

            transportLock.signal()
            return
        }

        transportLock.wait()

        return maybeResult
    }

    func networkWrite(data: Data) -> Bool
    {
        var success = false
        let lock = DispatchSemaphore(value: 0)

        self.connection.send(content: data, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed(
            {
                error in

                guard error == nil else
                {
                    success = false
                    lock.signal()
                    return
                }

                success = true
                lock.signal()
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

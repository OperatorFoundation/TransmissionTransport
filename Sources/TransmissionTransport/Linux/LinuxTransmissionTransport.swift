// This only compiles on Linux
#if os(Linux)

import Foundation
import Transport
import Chord
import Datable
import TransmissionLinux
import NetworkLinux

public struct TransmissionToTransportConnection: Transport.Connection
{
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?

    let conn: TransmissionLinux.Connection
    var dispatch: DispatchQueue?

    public init(_ conn: TransmissionLinux.Connection)
    {
        self.conn = conn
    }

    public func start(queue: DispatchQueue)
    {
        self.dispatch = queue
    }

    public func cancel()
    {
    }

    public func send(content: Data?, contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
    {
        let error = NWError.posix(POSIXErrorCode.ECONNABORTED)

        guard let queue = self.dispatch else {
            switch completion
            {
                case .idempotent:
                    return
                case .contentProcessed(let callback):
                    callback(error)
                    return
                default:
                    return
            }
        }

        queue.async
        {
            guard let data = content else
            {
                switch completion
                {
                    case .idempotent:
                        return
                    case .contentProcessed(let callback):
                        callback(error)
                        return
                    default:
                        return
                }
            }

            guard self.conn.write(data: data) else
            {
                switch completion
                {
                    case .idempotent:
                        return
                    case .contentProcessed(let callback):
                        callback(error)
                        return
                    default:
                        return
                }
            }

            switch completion
            {
                case .idempotent:
                    return
                case .contentProcessed(let callback):
                    callback(nil)
                    return
                default:
                    return
            }
        }
    }

    public func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        let error = NWError.posix(POSIXErrorCode.ECONNABORTED)
        guard let queue = self.dispatch else {return}

        queue.async
        {
            let length = minimumIncompleteLength
            guard length > 0 else
            {
                completion(nil, .defaultMessage, true, error)
                return
            }

            guard let data = self.conn.read(size: length) else
            {
                completion(nil, .defaultMessage, true, error)
                return
            }

            completion(data, .defaultMessage, false, nil)
        }
    }
}

func makeTransportConnection(_ connection: TransmissionLinux.Connection) -> Transport.Connection
{
    return TransmissionToTransportConnection(connection)
}
#endif

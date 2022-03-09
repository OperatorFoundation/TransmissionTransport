import Foundation
import Transport
import Chord
import Datable
import Transmission
import Net

public class TransmissionToTransportConnection: Transport.Connection
{
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?

    let connectionFactory: () -> Transmission.Connection?
    var conn: Transmission.Connection?
    var dispatch: DispatchQueue?

    public init(_ connectionFactory: @escaping () -> Transmission.Connection?)
    {
        self.connectionFactory = connectionFactory
    }

    public func start(queue: DispatchQueue)
    {
        self.dispatch = queue
        if let conn = connectionFactory()
        {
            self.conn = conn

            if let handler = self.stateUpdateHandler
            {
                handler(.ready)
            }
        }
        else
        {
            if let handler = self.stateUpdateHandler
            {
                handler(.failed(NWError.posix(POSIXErrorCode.ECONNREFUSED)))
            }
        }
    }

    public func cancel()
    {
        if let conn = self.conn
        {
            conn.close()
        }
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

            guard let conn = self.conn else
            {
                switch completion
                {
                    case .idempotent:
                        return
                    case .contentProcessed(let callback):
                        callback(NWError.posix(.ECONNREFUSED))
                        return
                    default:
                        return
                }
            }

            guard conn.write(data: data) else
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

            guard let conn = self.conn else
            {
                completion(nil, .defaultMessage, true, NWError.posix(.ECONNREFUSED))
                return
            }

            guard let data = conn.read(size: length) else
            {
                completion(nil, .defaultMessage, true, error)
                return
            }

            completion(data, .defaultMessage, false, nil)
        }
    }
}

func makeTransportConnection(_ connectionFactory: @escaping () -> Transmission.Connection?) -> Transport.Connection
{
    return TransmissionToTransportConnection(connectionFactory)
}

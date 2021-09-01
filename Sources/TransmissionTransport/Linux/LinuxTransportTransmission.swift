// This only compiles on Linux
#if os(Linux)

import Foundation
import Transport
import Chord
import Datable
import TransmissionLinux
import NetworkLinux

struct TransportToTransmissionConnection: TransmissionLinux.Connection
{
    let conn: Transport.Connection

    public init(_ conn: Transport.Connection)
    {
        self.conn = conn
    }

    public func read(size: Int) -> Data?
    {
        return Synchronizer.sync({callback in return asyncRead(size: size, callback: callback)})
    }

    func asyncRead(size: Int, callback: @escaping (Data?) -> Void)
    {
        self.conn.receive(minimumIncompleteLength: size, maximumLength: size)
        {
            (data: Data?, context: NWConnection.ContentContext?, isComplete: Bool, maybeError: NWError?) in

            if maybeError != nil
            {
                callback(nil)
                return
            }

            callback(data)
            return
        }
    }

    public func write(string: String) -> Bool
    {
        return write(data: string.data)
    }

    public func write(data: Data) -> Bool
    {
        return Synchronizer.sync({callback in return asyncWrite(data: data, callback: callback)})
    }

    public func asyncWrite(data: Data, callback: @escaping (Bool) -> Void)
    {
        self.conn.send(content: data, contentContext: NWConnection.ContentContext.defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed({
            maybeError in

            if maybeError != nil
            {
                callback(false)
                return
            }

            callback(true)
            return
        }))
    }
    
    public func identifier() -> Int {
            return Int(self.socket.socketfd)
    }
}

func makeTransmissionConnection(_ connection: Transport.Connection) -> TransmissionLinux.Connection
{
    return TransportToTransmissionConnection(connection)
}

#endif

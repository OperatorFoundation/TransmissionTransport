// This only compiles on macOS
#if os(macOS)

import Foundation
import Transport
import Chord
import Datable
import Transmission
import Network

public class TransmissionToTransportConnection: Transport.Connection
{
  public var stateUpdateHandler: ((NWConnection.State) -> Void)?
  public var viabilityUpdateHandler: ((Bool) -> Void)?
  public var dispatch: DispatchQueue?

  let conn: Transmission.Connection

  public init(_ conn: Transmission.Connection)
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
    guard let queue = self.dispatch  else {
        return
    }
    
    queue.async {
        guard let data = content else {
            return
        }
        self.conn.write(data: data)
        
        switch completion {
            case .idempotent:
                return
            case .contentProcessed(let callback):
                callback(nil)
                return
        
        }
    }
  }

  public func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
  {
  }
}

func makeTransportConnection(_ connection: Transmission.Connection) -> Transport.Connection
{
  return TransmissionToTransportConnection(connection)
}

func makeTransmissionConnection(_ connection: Transport.Connection) -> Transmission.Connection?
{
    guard let newConnection = connection as? NWConnection
    else { return nil }
    return Transmission.Connection(connection: newConnection)
}
#endif

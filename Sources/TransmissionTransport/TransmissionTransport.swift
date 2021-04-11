import Foundation
import Transport
import Chord
import Datable

#if os(Linux)
import TransmissionLinux
import NetworkLinux
#else
import Transmission
import Network
#endif

#if os(Linux)
public struct TransmissionToTransportConnection: Transport.Connection
{
  public var stateUpdateHandler: ((NWConnection.State) -> Void)?
  public var viabilityUpdateHandler: ((Bool) -> Void)?

  let conn: TransmissionLinux.Connection

  public init(_ conn: TransmissionLinux.Connection)
  {
    self.conn = conn
  }

  public func start(queue: DispatchQueue)
  {
  }

  public func cancel()
  {
  }

  public func send(content: Data?, contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
  {
  }

  public func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
  {
  }
}

func makeTransportConnection(_ connection: TransmissionLinux.Connection) -> Transport.Connection
{
  return TransmissionToTransportConnection(connection)
}
#else
public struct TransmissionToTransportConnection: Transport.Connection
{
  public var stateUpdateHandler: ((NWConnection.State) -> Void)?
  public var viabilityUpdateHandler: ((Bool) -> Void)?

  let conn: Transmission.Connection

  public init(_ conn: Transmission.Connection)
  {
    self.conn = conn
  }

  public func start(queue: DispatchQueue)
  {
  }

  public func cancel()
  {
  }

  public func send(content: Data?, contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
  {
  }

  public func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
  {
  }
}

func makeTransportConnection(_ connection: Transmission.Connection) -> Transport.Connection
{
  return TransmissionToTransportConnection(connection)
}
#endif

#if os(Linux)
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
}

func makeTransmissionConnection(_ connection: Transport.Connection) -> TransmissionLinux.Connection
{
  return TransportToTransmissionConnection(connection)
}
#else
func makeTransmissionConnection(_ connection: Transport.Connection) -> Transmission.Connection
{
  return Transmission.Connection(connection)
}
#endif

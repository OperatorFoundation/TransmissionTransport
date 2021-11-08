//// This only compiles on Linux
//#if os(Linux)
//
//import Foundation
//import Transport
//import Chord
//import Datable
//import Transmission
//import Net
//
//struct TransportToTransmissionConnection: TransmissionLinux.Connection
//{
//    let conn: Transport.Connection
//
//    public init(_ conn: Transport.Connection)
//    {
//        self.conn = conn
//    }
//
//    public func read(size: Int) -> Data?
//    {
//        print("TransmissionTransport read called")
//        return Synchronizer.sync({callback in return asyncRead(size: size, callback: callback)})
//    }
//
//    func asyncRead(size: Int, callback: @escaping (Data?) -> Void)
//    {
//        print("TransmissionTransport asyncRead called")
//        self.conn.receive(minimumIncompleteLength: size, maximumLength: size)
//        {
//            (data: Data?, context: NWConnection.ContentContext?, isComplete: Bool, maybeError: NWError?) in
//
//            if maybeError != nil
//            {
//                callback(nil)
//                return
//            }
//
//            callback(data)
//            return
//        }
//    }
//
//    public func write(string: String) -> Bool
//    {
//        print("TransmissionTransport string write called")
//        return write(data: string.data)
//    }
//
//    public func write(data: Data) -> Bool
//    {
//        print("TransmissionTransport data write called")
//        return Synchronizer.sync({callback in return asyncWrite(data: data, callback: callback)})
//    }
//
//    public func asyncWrite(data: Data, callback: @escaping (Bool) -> Void)
//    {
//        //FIXME: remove this print when the debugging is done
//        print("TransmissionTransport asyncWrite data write called: \(data.string)")
//        self.conn.send(content: data, contentContext: NWConnection.ContentContext.defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed({
//            maybeError in
//
//            if maybeError != nil
//            {
//                callback(false)
//                return
//            }
//
//            callback(true)
//            return
//        }))
//    }
//
//    public func identifier() -> Int {
//            return 0
//    }
//}
//
//func makeTransmissionConnection(_ connection: Transport.Connection) -> TransmissionLinux.Connection
//{
//    return TransportToTransmissionConnection(connection)
//}
//
//#endif

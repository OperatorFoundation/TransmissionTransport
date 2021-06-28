// This only compiles on macOS
#if os(macOS)

import Foundation
import Transport
import Chord
import Datable
import Transmission
import Network

func makeTransmissionConnection(_ connection: Transport.Connection) -> Transmission.Connection?
{
    guard let newConnection = connection as? NWConnection
    else { return nil }
    return Transmission.Connection(connection: newConnection)
}
#endif

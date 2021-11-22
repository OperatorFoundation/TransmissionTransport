import Foundation
import Transport
import Chord
import Datable
import Transmission
import Net

public func makeTransmissionConnection(_ connection: Transport.Connection) -> Transmission.Connection?
{
    guard let newConnection = connection as? NWConnection
    else { return nil }
    return TransmissionConnection(transport: newConnection, logger: nil)
}

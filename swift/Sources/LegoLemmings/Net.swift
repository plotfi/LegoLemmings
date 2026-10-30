import Foundation
import Network

/// The four counters the two players trade back and forth.
struct NetStats {
  var released = 0
  var out = 0
  var saved = 0
  var dead = 0
  var nuke = false
}

/// One end of a two-player game.
///
/// This replaces the original's four classes (`NetServer`, `NetServerThread`,
/// `NetClient`, `NetClientThread`), which between them had the host open a
/// server socket and then connect a second client back to itself over loopback
/// to talk to its own listener.
///
/// The wire format is unchanged, so this is still compatible with the Java
/// build: newline-delimited text, where the client opens with a line holding
/// its user number and both sides then stream
/// `1 <released> <out> <saved> <dead>`, with a trailing ` YES` meaning the
/// sender nuked their level.
final class NetPeer {

  private let queue = DispatchQueue(label: "LegoLemmings.net")
  private let lock = NSLock()

  private var listener: NWListener?
  private var connection: NWConnection?
  private var inbox = Data()
  private var stats = NetStats()

  /// The opponent's latest numbers. Safe to read from the main thread.
  var opponent: NetStats {
    lock.lock()
    defer { lock.unlock() }
    return stats
  }

  private(set) var statusMessage = "Waiting for the other player..."

  // MARK: - Setup

  /// Listens for the other player to connect.
  init?(hostingOn port: Int) {
    guard let port = NWEndpoint.Port(rawValue: UInt16(exactly: port) ?? 0) else {
      FileHandle.standardError.write(Data("Could not listen on port: \(port)\n".utf8))
      return nil
    }

    do {
      let listener = try NWListener(using: .tcp, on: port)
      self.listener = listener

      listener.newConnectionHandler = { [weak self] connection in
        guard let self else { return }
        // One opponent at a time; a later arrival replaces an abandoned game.
        self.connection?.cancel()
        self.connection = connection
        self.setStatus("Connected.")
        connection.start(queue: self.queue)
        self.receive(on: connection)
      }
      listener.start(queue: queue)
    } catch {
      FileHandle.standardError.write(
        Data("Could not listen on port \(port): \(error)\n".utf8))
      return nil
    }
  }

  /// Connects to a player who is hosting.
  init?(connectingTo host: String, port: Int) {
    guard !host.isEmpty, let port = NWEndpoint.Port(rawValue: UInt16(exactly: port) ?? 0) else {
      FileHandle.standardError.write(Data("Don't know about host \(host):\(port)\n".utf8))
      return nil
    }

    let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
    self.connection = connection

    connection.stateUpdateHandler = { [weak self] state in
      guard let self else { return }
      switch state {
      case .ready:
        self.setStatus("Connected.")
        self.send(line: "2")  // the client's user number, as the original sent
        self.receive(on: connection)
      case .failed(let error):
        self.setStatus("Connection failed: \(error.localizedDescription)")
      case .cancelled:
        self.setStatus("Disconnected.")
      default:
        break
      }
    }
    connection.start(queue: queue)
  }

  func close() {
    connection?.cancel()
    listener?.cancel()
  }

  // MARK: - Sending

  func sendStats(released: Int, out: Int, saved: Int, dead: Int, nuke: Bool) {
    var line = "1 \(released) \(out) \(saved) \(dead)"
    if nuke { line += " YES" }
    send(line: line)
  }

  private func send(line: String) {
    guard let connection, connection.state == .ready else { return }
    connection.send(
      content: Data((line + "\n").utf8), completion: .contentProcessed { _ in })
  }

  // MARK: - Receiving

  private func receive(on connection: NWConnection) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) {
      [weak self] data, _, isComplete, error in
      guard let self else { return }

      if let data, !data.isEmpty {
        self.inbox.append(data)
        self.drainInbox()
      }
      if isComplete || error != nil {
        self.setStatus("Disconnected.")
        return
      }
      self.receive(on: connection)
    }
  }

  /// Pulls whole lines out of the buffer and parses them.
  private func drainInbox() {
    while let newline = inbox.firstIndex(of: UInt8(ascii: "\n")) {
      let line = String(decoding: inbox[inbox.startIndex..<newline], as: UTF8.self)
      inbox.removeSubrange(inbox.startIndex...newline)
      parse(line)
    }
  }

  /// `<user> <released> <out> <saved> <dead> [YES]` — anything shorter just
  /// leaves the missing fields at their previous values, as the original's
  /// `StringTokenizer` walk did.
  private func parse(_ line: String) {
    let fields = line.split(separator: " ").map(String.init)
    guard fields.count > 1 else { return }  // the opening user-number line

    lock.lock()
    if fields.count > 1, let value = Int(fields[1]) { stats.released = value }
    if fields.count > 2, let value = Int(fields[2]) { stats.out = value }
    if fields.count > 3, let value = Int(fields[3]) { stats.saved = value }
    if fields.count > 4, let value = Int(fields[4]) { stats.dead = value }
    if fields.count > 5 { stats.nuke = true }
    lock.unlock()
  }

  private func setStatus(_ message: String) {
    lock.lock()
    statusMessage = message
    lock.unlock()
  }
}

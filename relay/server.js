// FPS Zone — WebSocket Relay Server
//
// Deploy to Render.com (free tier):
//   1. Push this `relay/` folder to a GitHub repo
//   2. New Web Service → connect repo → Root Directory: relay
//   3. Build: npm install   Start: node server.js
//   4. Render gives you a URL like https://fps-relay.onrender.com
//   5. Copy that URL into NetworkManager.gd → RELAY_URL (change wss:// not https://)
//
// Free tier note: spins down after 15 min idle. First connect after idle takes ~30s.

const { WebSocketServer } = require('ws');

const PORT = process.env.PORT || 4433;

// rooms: code (string) → Map<peer_id (int), WebSocket>
const rooms = new Map();
let nextPeerId = 2;

const wss = new WebSocketServer({ port: PORT });
console.log(`[Relay] Running on port ${PORT}`);

wss.on('connection', (ws) => {
  let peerId = null;
  let roomCode = null;
  let room = null;

  ws.on('message', (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }

    if (msg.type === 'join') {
      // Validate room code: letters/digits only, max 8 chars
      roomCode = String(msg.room || '').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 8);
      if (!roomCode) { ws.send(JSON.stringify({ type: 'error', reason: 'invalid_room' })); return; }

      if (!rooms.has(roomCode)) rooms.set(roomCode, new Map());
      room = rooms.get(roomCode);

      // First in the room becomes peer 1 (the Godot "server")
      peerId = (room.size === 0) ? 1 : nextPeerId++;
      room.set(peerId, ws);

      ws.send(JSON.stringify({ type: 'assigned', peer_id: peerId }));

      // Cross-announce with existing peers
      for (const [id, sock] of room) {
        if (id === peerId) continue;
        // Tell existing peer about the newcomer
        if (sock.readyState === 1) sock.send(JSON.stringify({ type: 'peer_connected', peer_id: peerId }));
        // Tell newcomer about the existing peer
        ws.send(JSON.stringify({ type: 'peer_connected', peer_id: id }));
      }

      console.log(`[Relay] Room ${roomCode}: peer ${peerId} joined (${room.size} total)`);
    }

    else if (msg.type === 'packet' && room && peerId !== null) {
      const to = (msg.to == null) ? 0 : Number(msg.to);
      const payload = JSON.stringify({ type: 'packet', from: peerId, data: msg.data });

      if (to === 0) {
        // Broadcast to everyone else in the room
        for (const [id, sock] of room) {
          if (id !== peerId && sock.readyState === 1) sock.send(payload);
        }
      } else {
        const target = room.get(to);
        if (target && target.readyState === 1) target.send(payload);
      }
    }
  });

  ws.on('close', () => {
    if (!room || peerId === null) return;
    room.delete(peerId);
    console.log(`[Relay] Room ${roomCode}: peer ${peerId} left (${room.size} remaining)`);
    const msg = JSON.stringify({ type: 'peer_disconnected', peer_id: peerId });
    for (const [, sock] of room) {
      if (sock.readyState === 1) sock.send(msg);
    }
    if (room.size === 0) {
      rooms.delete(roomCode);
      console.log(`[Relay] Room ${roomCode} closed`);
    }
  });

  ws.on('error', () => ws.terminate());
});

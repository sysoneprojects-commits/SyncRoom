export interface Env {
  ROOM_HUB: DurableObjectNamespace;
  DB: D1Database;
  APP_ENV?: string;
}

type RoomMeta = {
  id: string;
  code: string;
  name: string;
  hostUserId: string;
  hostName: string;
  sourceType: 'youtube' | 'local' | 'screen_share';
  sourceValue?: string | null;
};

type PlaybackState = {
  position: number;
  playing: boolean;
  updatedAt: number;
};

type SessionAttachment = {
  userId?: string;
  name?: string;
  isHost?: boolean;
};

const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), {
  status,
  headers: {
    'content-type': 'application/json; charset=utf-8',
    'access-control-allow-origin': '*',
    'access-control-allow-headers': 'content-type',
    'access-control-allow-methods': 'GET,POST,OPTIONS',
  },
});

function roomCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = new Uint8Array(6);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, b => alphabet[b % alphabet.length]).join('');
}

function roomStub(env: Env, code: string) {
  return env.ROOM_HUB.get(env.ROOM_HUB.idFromName(code.toUpperCase()));
}

async function readJson<T>(request: Request): Promise<T> {
  try { return await request.json() as T; }
  catch { throw new Error('Invalid JSON body'); }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') return json({ ok: true });
    const url = new URL(request.url);

    if (url.pathname === '/health') {
      return json({ ok: true, service: 'syncroom-api', env: env.APP_ENV ?? 'dev', version: '0.1.0' });
    }

    if (request.method === 'POST' && url.pathname === '/api/v1/rooms') {
      const body = await readJson<Partial<RoomMeta>>(request);
      if (!body.name || !body.hostUserId || !body.hostName || !body.sourceType) {
        return json({ error: 'name, hostUserId, hostName and sourceType are required' }, 400);
      }
      if (!['youtube', 'local', 'screen_share'].includes(String(body.sourceType))) {
        return json({ error: 'Invalid sourceType' }, 400);
      }
      const code = roomCode();
      const meta: RoomMeta = {
        id: crypto.randomUUID(),
        code,
        name: String(body.name).slice(0, 80),
        hostUserId: String(body.hostUserId),
        hostName: String(body.hostName).slice(0, 50),
        sourceType: body.sourceType,
        sourceValue: body.sourceValue == null ? null : String(body.sourceValue),
      };
      const stub = roomStub(env, code);
      const initRes = await stub.fetch('https://room.internal/init', {
        method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(meta),
      });
      if (!initRes.ok) return json({ error: 'Failed to initialize room' }, 500);

      await env.DB.prepare(`INSERT INTO rooms (id, code, name, host_user_id, host_name, source_type, source_value)
        VALUES (?, ?, ?, ?, ?, ?, ?)`)
        .bind(meta.id, meta.code, meta.name, meta.hostUserId, meta.hostName, meta.sourceType, meta.sourceValue ?? null)
        .run();
      return json(meta, 201);
    }

    const match = url.pathname.match(/^\/api\/v1\/rooms\/([A-Za-z0-9]+)(\/ws)?$/);
    if (match) {
      const code = match[1].toUpperCase();
      const stub = roomStub(env, code);
      if (match[2] === '/ws') {
        return stub.fetch(new Request('https://room.internal/ws', request));
      }
      if (request.method === 'GET') {
        return stub.fetch('https://room.internal/room');
      }
    }

    return json({ error: 'Not found' }, 404);
  }
};

export class RoomHub {
  constructor(private state: DurableObjectState, private env: Env) {}

  private async room(): Promise<RoomMeta | undefined> {
    return this.state.storage.get<RoomMeta>('room');
  }

  private async playback(): Promise<PlaybackState> {
    return (await this.state.storage.get<PlaybackState>('playback')) ?? { position: 0, playing: false, updatedAt: Date.now() };
  }

  private send(ws: WebSocket, type: string, payload: unknown) {
    try { ws.send(JSON.stringify({ type, payload, serverTime: Date.now() })); } catch {}
  }

  private broadcast(type: string, payload: unknown, except?: WebSocket) {
    for (const ws of this.state.getWebSockets()) {
      if (ws === except) continue;
      this.send(ws, type, payload);
    }
  }

  private sendToUser(userId: string, type: string, payload: unknown) {
    for (const ws of this.state.getWebSockets()) {
      const a = ws.deserializeAttachment<SessionAttachment>() ?? {};
      if (a.userId === userId) {
        this.send(ws, type, payload);
        return true;
      }
    }
    return false;
  }

  private members() {
    return this.state.getWebSockets().map(ws => ws.deserializeAttachment<SessionAttachment>() ?? {})
      .filter(a => a.userId)
      .map(a => ({ userId: a.userId, name: a.name ?? 'Guest', isHost: !!a.isHost }));
  }

  private broadcastMembers() {
    this.broadcast('members.snapshot', { members: this.members() });
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'POST' && url.pathname === '/init') {
      const room = await readJson<RoomMeta>(request);
      await this.state.storage.put('room', room);
      await this.state.storage.put('playback', { position: 0, playing: false, updatedAt: Date.now() } satisfies PlaybackState);
      return json({ ok: true });
    }

    if (request.method === 'GET' && url.pathname === '/room') {
      const room = await this.room();
      return room ? json(room) : json({ error: 'Room not found' }, 404);
    }

    if (url.pathname === '/ws') {
      if (request.headers.get('Upgrade') !== 'websocket') {
        return new Response('Expected WebSocket', { status: 426 });
      }
      const room = await this.room();
      if (!room) return json({ error: 'Room not found' }, 404);
      const pair = new WebSocketPair();
      const client = pair[0];
      const server = pair[1];
      this.state.acceptWebSocket(server);
      server.serializeAttachment({});
      const playback = await this.playback();
      this.send(server, 'state.snapshot', { room, playback });
      return new Response(null, { status: 101, webSocket: client } as ResponseInit & { webSocket: WebSocket });
    }

    return json({ error: 'Not found' }, 404);
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer) {
    const raw = typeof message === 'string' ? message : new TextDecoder().decode(message);
    let incoming: { type?: string; payload?: Record<string, unknown> };
    try { incoming = JSON.parse(raw); } catch { return; }
    const type = incoming.type ?? '';
    const payload = incoming.payload ?? {};
    const room = await this.room();
    if (!room) return;

    if (type === 'member.join') {
      const userId = String(payload.userId ?? '');
      const name = String(payload.name ?? 'Guest').slice(0, 50);
      const isHost = userId === room.hostUserId;
      ws.serializeAttachment({ userId, name, isHost });
      this.broadcast('member.joined', { userId, name, isHost });
      this.broadcastMembers();
      return;
    }

    const attachment = ws.deserializeAttachment<SessionAttachment>() ?? {};
    if (!attachment.userId) return;

    if (type === 'sync.play' || type === 'sync.pause' || type === 'sync.seek') {
      if (!attachment.isHost) {
        this.send(ws, 'error', { code: 'HOST_ONLY', message: 'Only host can control playback' });
        return;
      }
      const position = Math.max(0, Number(payload.position ?? 0));
      const previous = await this.playback();
      const next: PlaybackState = {
        position,
        playing: type === 'sync.play' ? true : type === 'sync.pause' ? false : previous.playing,
        updatedAt: Date.now(),
      };
      await this.state.storage.put('playback', next);
      this.broadcast(type, next, ws);
      return;
    }

    if (type === 'chat.message') {
      const text = String(payload.text ?? '').trim().slice(0, 800);
      if (!text) return;
      const out = { userId: attachment.userId, name: attachment.name ?? 'Guest', text, at: Date.now() };
      this.broadcast('chat.message', out);
      await this.env.DB.prepare('INSERT INTO room_events (room_id, event_type, payload_json) VALUES (?, ?, ?)')
        .bind(room.id, 'chat.message', JSON.stringify(out)).run();
      return;
    }

    if (type === 'reaction') {
      const emoji = String(payload.emoji ?? '❤️').slice(0, 16);
      this.broadcast('reaction', { userId: attachment.userId, name: attachment.name ?? 'Guest', emoji, at: Date.now() });
      return;
    }


    if (type === 'rtc.viewer.ready') {
      if (attachment.isHost) return;
      this.sendToUser(room.hostUserId, 'rtc.viewer.ready', {
        fromUserId: attachment.userId,
        name: attachment.name ?? 'Guest',
      });
      return;
    }

    if (type === 'rtc.offer' || type === 'rtc.answer' || type === 'rtc.ice') {
      const targetUserId = String(payload.targetUserId ?? '');
      if (!targetUserId) return;
      const routed = { ...payload, fromUserId: attachment.userId, fromName: attachment.name ?? 'Guest' };
      this.sendToUser(targetUserId, type, routed);
      return;
    }

    if (type === 'screen.started') {
      if (attachment.isHost) this.broadcast('screen.started', { userId: attachment.userId, at: Date.now() }, ws);
      return;
    }
  }

  async webSocketClose(ws: WebSocket, code: number, reason: string, wasClean: boolean) {
    const attachment = ws.deserializeAttachment<SessionAttachment>() ?? {};
    if (attachment.userId) {
      this.broadcast('member.left', { userId: attachment.userId, name: attachment.name ?? 'Guest', code, reason, wasClean });
      this.broadcastMembers();
    }
  }
}

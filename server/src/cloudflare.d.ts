interface D1PreparedStatement {
  bind(...values: unknown[]): D1PreparedStatement;
  run(): Promise<unknown>;
  first<T = unknown>(): Promise<T | null>;
}
interface D1Database { prepare(query: string): D1PreparedStatement; }
interface DurableObjectStorage {
  get<T = unknown>(key: string): Promise<T | undefined>;
  put<T = unknown>(key: string, value: T): Promise<void>;
}
interface DurableObjectId {}
interface DurableObjectStub { fetch(input: Request | string, init?: RequestInit): Promise<Response>; }
interface DurableObjectNamespace {
  idFromName(name: string): DurableObjectId;
  get(id: DurableObjectId): DurableObjectStub;
}
interface DurableObjectState {
  storage: DurableObjectStorage;
  acceptWebSocket(ws: WebSocket): void;
  getWebSockets(): WebSocket[];
}
interface WebSocket {
  serializeAttachment(value: unknown): void;
  deserializeAttachment<T = unknown>(): T | null;
}
declare class WebSocketPair {
  0: WebSocket;
  1: WebSocket;
}

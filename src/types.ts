export interface SSLPinningConfig {
  /** The hostname or IP of the server */
  hostname: string;
  /** Public key hashes in SHA256 format (base64) */
  publicKeyHashes: string[];
  /** Include subdomains in validation */
  includeSubdomains?: boolean;
  /** Timeout for SSL validation in milliseconds */
  timeout?: number;
}

export interface WebSocketConfig {
  /** WebSocket URL (ws:// or wss://) */
  url: string;
  /** Optional WebSocket protocols */
  protocols?: string | string[];
  /** SSL Pinning configuration (required for wss://) */
  sslPinning?: SSLPinningConfig;
  /** Connection timeout in milliseconds */
  connectionTimeout?: number;
  /** Additional options for connection */
  options?: {
    /** Ignore certificate errors (development only) */
    allowSelfSignedCerts?: boolean;
  };
}

// Specific event types for each WebSocket event type
export interface WebSocketOpenEvent {
  type: 'open';
}

export interface WebSocketMessageEvent {
  type: 'message';
  /** Received data (string, ArrayBuffer, or Blob) */
  data: string | ArrayBuffer | Blob;
}

/** Specific error codes for SSL WebSocket */
export enum SSLWebSocketErrorCode {
  /** General WebSocket error */
  WEBSOCKET_ERROR = 1000,
  /** WebSocket not in correct state */
  INVALID_STATE = 1001,
  /** Data sending error */
  SEND_ERROR = 1002,
  /** SSL Certificate Pinning failure */
  SSL_PINNING_FAILED = 1003,
  /** Invalid WebSocket URL */
  INVALID_URL = 1004,
  /** WebSocket already exists */
  WEBSOCKET_EXISTS = 1005,
  /** Connection failure */
  CONNECTION_FAILED = 1006,
}

/** Error types to differentiate SSL errors from classic WebSocket errors */
export type SSLWebSocketErrorType =
  | 'websocket'      // Classic WebSocket error
  | 'ssl_pinning'    // SSL pinning specific error
  | 'network'        // Network error
  | 'validation'     // Parameter validation error
  | 'connection';    // Connection error

export interface WebSocketErrorEvent {
  type: 'error';
  /** Error that occurred */
  error: Error;
  /** Error message */
  message: string;
  /** Specific SSL WebSocket error code */
  code?: SSLWebSocketErrorCode;
  /** Error type for differentiation */
  errorType?: SSLWebSocketErrorType;
  /** Additional information for SSL errors */
  sslInfo?: {
    hostname?: string;
    expectedHashes?: string[];
    foundHash?: string;
  };
}

export interface WebSocketCloseEvent {
  type: 'close';
  /** Close code */
  code: number;
  /** Close reason */
  reason: string;
  /** Indicates if the close was clean */
  wasClean: boolean;
}

// Union type for all events
export type WebSocketEvent =
  | WebSocketOpenEvent
  | WebSocketMessageEvent
  | WebSocketErrorEvent
  | WebSocketCloseEvent;

export interface SSLValidationResult {
  /** Validation success */
  success: boolean;
  /** Validated hostname */
  hostname: string;
  /** Found public key hash */
  foundKeyHash?: string;
  /** Expected hash */
  expectedKeyHashes: string[];
  /** Error message if failure */
  error?: string;
}

export enum WebSocketReadyState {
  CONNECTING = 0,
  OPEN = 1,
  CLOSING = 2,
  CLOSED = 3,
}

// Event types with inference
type EventListener<T extends WebSocketEvent = WebSocketEvent> = (event: T) => void;

// Specific types for addEventListener
interface EventListenerMap {
  'open': EventListener<WebSocketOpenEvent>;
  'message': EventListener<WebSocketMessageEvent>;
  'error': EventListener<WebSocketErrorEvent>;
  'close': EventListener<WebSocketCloseEvent>;
}

// Main interface
interface SSLWebSocketInterface {
  /** Current connection state */
  readyState: WebSocketReadyState;

  /** Connection URL */
  url: string;

  /** Protocol used */
  protocol: string;

  /** Connect the WebSocket */
  connect(): void;

  /** Close the connection */
  close(code?: number, reason?: string): void;

  /** Send data */
  send(data: string | ArrayBuffer | Blob): void;

  /** Add event listener with specific typing */
  addEventListener<K extends keyof EventListenerMap>(type: K, listener: EventListenerMap[K]): void;

  /** Remove event listener with specific typing */
  removeEventListener<K extends keyof EventListenerMap>(type: K, listener: EventListenerMap[K]): void;

  /** Get SSL validation result */
  getSSLValidationResult(): Promise<SSLValidationResult | null>;
}

export type {
  EventListener,
  EventListenerMap,
  SSLWebSocketInterface,
};

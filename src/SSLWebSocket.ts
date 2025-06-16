// @ts-ignore
import NativeSSLWebSocket from './NativeSSLWebSocket';
import type {
  WebSocketConfig,
  WebSocketEvent,
  SSLValidationResult,
  EventListener,
  SSLWebSocketInterface,
  EventListenerMap,
  SSLWebSocketErrorType,
} from './types';
import { WebSocketReadyState, SSLWebSocketErrorCode } from './types';

// Type assertion to avoid TypeScript errors
// @ts-ignore
const NativeModule: any = NativeSSLWebSocket;

/**
 * Helper function to parse error type and code from error message
 */
function parseErrorDetails(errorMessage: string): {
  errorType: SSLWebSocketErrorType;
  code: SSLWebSocketErrorCode;
} {
  const message = errorMessage.toLowerCase();

  // Check for SSL pinning errors first
  if (message.includes('ssl_pinning_failed') ||
      message.includes('ssl') ||
      message.includes('pinning') ||
      message.includes('certificate')) {
    return { errorType: 'ssl_pinning', code: SSLWebSocketErrorCode.SSL_PINNING_FAILED };
  }

  if (message.includes('network') || message.includes('timeout')) {
    return { errorType: 'network', code: SSLWebSocketErrorCode.CONNECTION_FAILED };
  }

  if (message.includes('invalid url')) {
    return { errorType: 'validation', code: SSLWebSocketErrorCode.INVALID_URL };
  }

  if (message.includes('already exists')) {
    return { errorType: 'validation', code: SSLWebSocketErrorCode.WEBSOCKET_EXISTS };
  }

  // Default case
  return { errorType: 'websocket', code: SSLWebSocketErrorCode.WEBSOCKET_ERROR };
}

export class SSLWebSocket implements SSLWebSocketInterface {
  private _id: string;
  private _url: string;
  private _protocol: string = '';
  private _readyState: WebSocketReadyState = WebSocketReadyState.CLOSED;
  private _listeners: Map<string, Set<EventListener>> = new Map();
  private _config: WebSocketConfig;
  private _pollingInterval: NodeJS.Timeout | null = null;
  private _pollingActive: boolean = false;

  constructor(config: WebSocketConfig) {
    this._id = this._generateId();
    this._url = config.url;
    this._config = config;

    // Don't setup event listeners in constructor - wait for connect()
  }

  get readyState(): WebSocketReadyState {
    return this._readyState;
  }

  get url(): string {
    return this._url;
  }

  get protocol(): string {
    return this._protocol;
  }

  // Getters for testing purposes
  get _testId(): string {
    return this._id;
  }

  get _testReadyState(): WebSocketReadyState {
    return this._readyState;
  }

  get _testListeners(): Map<string, Set<EventListener>> {
    return this._listeners;
  }

  // Setter for testing purposes
  set _testReadyState(state: WebSocketReadyState) {
    this._readyState = state;
  }

  async connect(): Promise<void> {
    if (this._readyState !== WebSocketReadyState.CLOSED) {
      // Emit an error via event listener instead of throw
      const errorObj = new Error('WebSocket is already connecting or connected');
      this._emitEvent({
        type: 'error',
        error: errorObj,
        message: errorObj.message,
        code: SSLWebSocketErrorCode.WEBSOCKET_EXISTS,
        errorType: 'validation',
      });
      return;
    }

    this._readyState = WebSocketReadyState.CONNECTING;

    const protocols = Array.isArray(this._config.protocols)
      ? this._config.protocols
      : this._config.protocols
      ? [this._config.protocols]
      : undefined;

    try {
      // Create the WebSocket
      await NativeModule.createWebSocket(
        this._id,
        this._config.url,
        protocols,
        this._config.sslPinning,
        this._config.options
      );

      // Start polling for events
      this._startEventPolling();
    } catch (error: any) {
        // If createWebSocket fails immediately (ex: invalid parameters),
        // emit the error via events
        this._readyState = WebSocketReadyState.CLOSED;
        const errorObj = error instanceof Error ? error : new Error(String(error));

        const { errorType, code } = parseErrorDetails(errorObj.message);

        this._emitEvent({
          type: 'error',
          error: errorObj,
          message: errorObj.message,
          code,
          errorType,
        });
    }
  }

  close(code?: number, reason?: string): void {
    if (this._readyState === WebSocketReadyState.CLOSED) {
      return;
    }

    this._readyState = WebSocketReadyState.CLOSING;

    // Stop event polling
    this._stopEventPolling();

    // Handle potential errors during closure
    try {
      NativeModule.closeWebSocket(this._id, code, reason)
        .catch((error: any) => {
          // If closure fails, force closed state and emit close event
          console.warn('Error closing WebSocket:', error);
          this._readyState = WebSocketReadyState.CLOSED;
          this._emitEvent({
            type: 'close',
            code: code || 1000,
            reason: reason || 'Connection forcibly closed',
            wasClean: false,
          });
        });
    } catch (error) {
      // Synchronous error during call
      console.warn('Synchronous error closing WebSocket:', error);
      this._readyState = WebSocketReadyState.CLOSED;
      this._emitEvent({
        type: 'close',
        code: code || 1000,
        reason: reason || 'Connection forcibly closed',
        wasClean: false,
      });
    }
  }

  send(data: string | ArrayBuffer | Blob): void {
    if (this._readyState !== WebSocketReadyState.OPEN) {
      throw new Error('WebSocket is not open');
    }

    let stringData: string;

    if (typeof data === 'string') {
      stringData = data;
    } else if (data instanceof ArrayBuffer) {
      // Convert ArrayBuffer to base64
      const uint8Array = new Uint8Array(data);
      const binaryString = Array.from(uint8Array, (byte) => String.fromCharCode(byte)).join('');
      stringData = btoa(binaryString);
    } else if (data instanceof Blob) {
      throw new Error('Blob data type is not yet supported');
    } else {
      throw new Error('Unsupported data type');
    }

    NativeModule.sendData(this._id, stringData);
  }

  addEventListener<K extends keyof EventListenerMap>(type: K, listener: EventListenerMap[K]): void {
    if (!this._listeners.has(type)) {
      this._listeners.set(type, new Set());
    }
    this._listeners.get(type)!.add(listener as EventListener);
  }

  removeEventListener<K extends keyof EventListenerMap>(type: K, listener: EventListenerMap[K]): void {
    const listeners = this._listeners.get(type);
    if (listeners) {
      listeners.delete(listener as EventListener);
      if (listeners.size === 0) {
        this._listeners.delete(type);
      }
    }
  }

  /**
   * Get SSL validation result for debugging purposes
   * @returns Promise<SSLValidationResult | null>
   */
  async getSSLValidationResult(): Promise<SSLValidationResult | null> {
    try {
      const result = await NativeModule.getSSLValidationResult(this._id);
      return result || null;
    } catch {
      return null;
    }
  }

  /**
   * Start intelligent event polling
   */
  private _startEventPolling(): void {
    if (this._pollingActive) {
      return;
    }

    this._pollingActive = true;

    const poll = async () => {
      if (!this._pollingActive) {
        return;
      }

      try {
        const events = await NativeModule.pollEvents(this._id);

        if (Array.isArray(events) && events.length > 0) {
          for (const event of events) {
            this._handleWebSocketEvent(event, 'polling');
          }
        }

        // Adaptive polling: faster when active, slower when idle
        const delay = this._readyState === WebSocketReadyState.OPEN ? 100 : 500;
        this._pollingInterval = setTimeout(poll, delay);
      } catch (error) {
        console.error('[SSLWebSocket] Error during event polling:', error);

        // Continue polling even if there are errors, unless we're explicitly stopped
        // Only stop if polling was explicitly deactivated
        if (this._pollingActive) {
          // Retry after longer delay on error
          this._pollingInterval = setTimeout(poll, 1000);
        }
      }
    };

    // Start polling immediately
    poll();
  }

  /**
   * Stop event polling
   */
  private _stopEventPolling(): void {
    if (!this._pollingActive) {
      return;
    }

    this._pollingActive = false;

    if (this._pollingInterval) {
      clearTimeout(this._pollingInterval);
      this._pollingInterval = null;
    }
  }

  private _generateId(): string {
    return `ws_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  private _emitEvent(event: WebSocketEvent): void {
    const listeners = this._listeners.get(event.type);
    if (listeners) {
      listeners.forEach((listener) => {
        try {
          listener(event);
        } catch (error) {
          console.error('Error in WebSocket event listener:', error);
        }
      });
    }
  }

  /**
   * Handle WebSocket events from native polling
   */
  private _handleWebSocketEvent(event: any, _source: string): void {
    // Check if this event is for our WebSocket instance
    if (event.id !== this._id) {
      return;
    }

    if (event.type === 'open') {
      this._readyState = WebSocketReadyState.OPEN;
      this._protocol = event.protocol || '';
      this._emitEvent({
        type: 'open',
      });
    } else if (event.type === 'message') {
      this._emitEvent({
        type: 'message',
        data: event.data,
      });
    } else if (event.type === 'error') {
      this._readyState = WebSocketReadyState.CLOSED;

      const errorObj = event.error ? new Error(event.error) : new Error('Unknown WebSocket error');
      const { errorType, code } = parseErrorDetails(errorObj.message);

      this._emitEvent({
        type: 'error',
        error: errorObj,
        message: errorObj.message,
        code,
        errorType,
        sslInfo: undefined,
      });

      // Continue polling briefly to catch any close events that might follow
    } else if (event.type === 'close') {
      this._readyState = WebSocketReadyState.CLOSED;
      this._emitEvent({
        type: 'close',
        code: event.code || 1000,
        reason: event.reason || '',
        wasClean: event.code === 1000,
      });

      // Stop polling after processing close event
      this._stopEventPolling();
    }
  }

  /**
   * Clean up resources (to be called when the WebSocket is no longer used)
   */
  cleanup(): void {
    // Stop event polling immediately
    this._stopEventPolling();

    // Close connection if not already closed
    if (this._readyState !== WebSocketReadyState.CLOSED) {
      this.close(1000, 'Cleanup');
    }

    // Clean up listeners
    this._listeners.clear();

    // Clean up native side with error handling
    try {
      NativeModule.cleanup(this._id)
        .catch((error: any) => {
          console.warn('Error during native cleanup:', error);
        });
    } catch (error) {
      console.warn('Synchronous error during native cleanup:', error);
    }

    // Force closed state
    this._readyState = WebSocketReadyState.CLOSED;
  }
}

// Utility function to create a WebSocket with SSL Pinning
export function createSSLWebSocket(config: WebSocketConfig): SSLWebSocket {
  return new SSLWebSocket(config);
}

// Utility function to extract hostname from a WebSocket URL
export function extractHostname(url: string): string {
  try {
    const urlObj = new URL(url);
    return urlObj.hostname;
  } catch {
    throw new Error('Invalid WebSocket URL');
  }
}

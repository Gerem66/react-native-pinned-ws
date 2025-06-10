import { DeviceEventEmitter, NativeEventEmitter } from 'react-native';
// @ts-ignore
import NativeSSLWebSocket from './NativeSSLWebSocket';
import type {
  WebSocketConfig,
  WebSocketEvent,
  SSLValidationResult,
  EventListener,
  SSLWebSocketInterface,
  EventListenerMap,
  WebSocketOpenEvent,
  WebSocketMessageEvent,
  WebSocketErrorEvent,
  WebSocketCloseEvent,
  SSLWebSocketErrorType,
} from './types';
import { WebSocketReadyState, SSLWebSocketErrorCode } from './types';

// Type assertion to avoid TypeScript errors
// @ts-ignore
const NativeModule: any = NativeSSLWebSocket;

export class SSLWebSocket implements SSLWebSocketInterface {
  private _id: string;
  private _url: string;
  private _protocol: string = '';
  private _readyState: WebSocketReadyState = WebSocketReadyState.CLOSED;
  private _listeners: Map<string, Set<EventListener>> = new Map();
  private _config: WebSocketConfig;
  private _nativeEventSubscription: any;
  private _deviceEventSubscription: any;

  constructor(config: WebSocketConfig) {
    this._id = this._generateId();
    this._url = config.url;
    this._config = config;
    
    this._setupEventListeners();
    this._setupDirectCallback();
  }

  private _setupDirectCallback(): void {
    // Configure direct callback as ultimate fallback
    try {
      NativeModule.registerEventCallback(this._id, (event: any) => {
        this._handleWebSocketEvent(event, 'DirectCallback');
      });
    } catch (error) {
      // Direct callback not available, use only DeviceEventEmitter
    }
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

  connect(): void {
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

    // Call createWebSocket without await - all events will go through listeners
    NativeModule.createWebSocket(
      this._id,
      this._config.url,
      protocols,
      this._config.sslPinning,
      this._config.options
    ).catch((error: any) => {
      // If createWebSocket fails immediately (ex: invalid parameters),
      // emit the error via events
      this._readyState = WebSocketReadyState.CLOSED;
      const errorObj = error instanceof Error ? error : new Error(String(error));
      
      // Parse error type based on message
      let errorType: SSLWebSocketErrorType = 'connection';
      let code: SSLWebSocketErrorCode | undefined;
      
      const errorMessage = errorObj.message.toLowerCase();
      
      if (errorMessage.includes('ssl') || errorMessage.includes('pinning') || errorMessage.includes('certificate')) {
        errorType = 'ssl_pinning';
        code = SSLWebSocketErrorCode.SSL_PINNING_FAILED;
      } else if (errorMessage.includes('network') || errorMessage.includes('timeout')) {
        errorType = 'network';
        code = SSLWebSocketErrorCode.CONNECTION_FAILED;
      } else if (errorMessage.includes('invalid url')) {
        errorType = 'validation';
        code = SSLWebSocketErrorCode.INVALID_URL;
      } else if (errorMessage.includes('already exists')) {
        errorType = 'validation';
        code = SSLWebSocketErrorCode.WEBSOCKET_EXISTS;
      } else {
        errorType = 'websocket';
        code = SSLWebSocketErrorCode.CONNECTION_FAILED;
      }
      
      this._emitEvent({
        type: 'error',
        error: errorObj,
        message: errorObj.message,
        code,
        errorType,
      });
    });
  }

  close(code?: number, reason?: string): void {
    if (this._readyState === WebSocketReadyState.CLOSED) {
      return;
    }

    this._readyState = WebSocketReadyState.CLOSING;
    
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
      // Erreur synchrone lors de l'appel
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
      throw new Error('WebSocket is not in OPEN state');
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

  async getSSLValidationResult(): Promise<SSLValidationResult | null> {
    return await NativeModule.getSSLValidationResult(this._id);
  }

  private _generateId(): string {
    return `ws_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  private _setupEventListeners(): void {
    // Essayer d'abord DeviceEventEmitter (plus simple)
    this._deviceEventSubscription = DeviceEventEmitter.addListener('SSLWebSocket_Event', (event: any) => {
      this._handleWebSocketEvent(event, 'DeviceEventEmitter');
    });
    
    // Essayer aussi NativeEventEmitter comme fallback
    try {
      const eventEmitter = new NativeEventEmitter(NativeModule);
      this._nativeEventSubscription = eventEmitter.addListener('SSLWebSocket_Event', (event: any) => {
        this._handleWebSocketEvent(event, 'NativeEventEmitter');
      });
    } catch (error) {
      // NativeEventEmitter non disponible
    }
  }

  private _handleWebSocketEvent(event: any, source: string): void {
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
      if (this._readyState === WebSocketReadyState.CONNECTING) {
        this._readyState = WebSocketReadyState.CLOSED;
      }
      const errorObj = event.error ? new Error(event.error) : new Error('Unknown WebSocket error');
      
      // Parse error type for native events
      let errorType: SSLWebSocketErrorType = 'websocket';
      let code: SSLWebSocketErrorCode | undefined;
      let sslInfo: any = undefined;
      
      const errorMessage = errorObj.message.toLowerCase();
      
      if (errorMessage.includes('ssl') || errorMessage.includes('pinning') || errorMessage.includes('certificate')) {
        errorType = 'ssl_pinning';
        code = SSLWebSocketErrorCode.SSL_PINNING_FAILED;
      } else if (errorMessage.includes('network') || errorMessage.includes('timeout')) {
        errorType = 'network';
        code = SSLWebSocketErrorCode.CONNECTION_FAILED;
      } else {
        errorType = 'websocket';
        code = SSLWebSocketErrorCode.WEBSOCKET_ERROR;
      }
      
      this._emitEvent({
        type: 'error',
        error: errorObj,
        message: errorObj.message,
        code,
        errorType,
        sslInfo,
      });
    } else if (event.type === 'close') {
      this._readyState = WebSocketReadyState.CLOSED;
      this._emitEvent({
        type: 'close',
        code: event.code || 1000,
        reason: event.reason || '',
        wasClean: event.code === 1000,
      });
    }
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
   * Nettoyer les ressources (à appeler quand le WebSocket n'est plus utilisé)
   */
  cleanup(): void {
    // Close connection if not already closed
    if (this._readyState !== WebSocketReadyState.CLOSED) {
      this.close(1000, 'Cleanup');
    }
    
    // Clean up listeners
    this._listeners.clear();
    
    // Supprimer les subscriptions avec gestion d'erreur
    try {
      if (this._deviceEventSubscription) {
        this._deviceEventSubscription.remove();
        this._deviceEventSubscription = null;
      }
    } catch (error) {
      console.warn('Error removing device event subscription:', error);
    }
    
    try {
      if (this._nativeEventSubscription) {
        this._nativeEventSubscription.remove();
        this._nativeEventSubscription = null;
      }
    } catch (error) {
      console.warn('Error removing native event subscription:', error);
    }
    
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

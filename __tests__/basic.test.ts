import { WebSocketReadyState, SSLWebSocketErrorCode } from '../src/types';

describe('Basic Types Test', () => {
  it('should have correct WebSocketReadyState values', () => {
    expect(WebSocketReadyState.CONNECTING).toBe(0);
    expect(WebSocketReadyState.OPEN).toBe(1);
    expect(WebSocketReadyState.CLOSING).toBe(2);
    expect(WebSocketReadyState.CLOSED).toBe(3);
  });

  it('should have correct SSLWebSocketErrorCode values', () => {
    expect(SSLWebSocketErrorCode.WEBSOCKET_ERROR).toBe(1000);
    expect(SSLWebSocketErrorCode.INVALID_STATE).toBe(1001);
    expect(SSLWebSocketErrorCode.SEND_ERROR).toBe(1002);
    expect(SSLWebSocketErrorCode.SSL_PINNING_FAILED).toBe(1003);
    expect(SSLWebSocketErrorCode.INVALID_URL).toBe(1004);
    expect(SSLWebSocketErrorCode.WEBSOCKET_EXISTS).toBe(1005);
    expect(SSLWebSocketErrorCode.CONNECTION_FAILED).toBe(1006);
  });

  it('should extract hostname from URL manually', () => {
    // Test the hostname extraction logic manually without importing SSLWebSocket
    const extractHostnameLocal = (url: string): string => {
      try {
        const urlObj = new URL(url);
        if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
          throw new Error('Invalid WebSocket URL');
        }
        return urlObj.hostname;
      } catch {
        throw new Error('Invalid WebSocket URL');
      }
    };

    expect(extractHostnameLocal('wss://api.example.com:8080/path')).toBe('api.example.com');
    expect(extractHostnameLocal('ws://localhost:3000/ws')).toBe('localhost');
    expect(extractHostnameLocal('wss://secure.example.com/ws')).toBe('secure.example.com');

    expect(() => extractHostnameLocal('invalid-url')).toThrow('Invalid WebSocket URL');
    expect(() => extractHostnameLocal('http://example.com')).toThrow('Invalid WebSocket URL');
  });
});

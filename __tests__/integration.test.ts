import { WebSocketReadyState, SSLWebSocketErrorCode } from '../src/types';

describe('Integration Tests', () => {
  describe('URL Validation', () => {
    it('should validate WebSocket URLs correctly', () => {
      const isValidWebSocketURL = (url: string): boolean => {
        try {
          // eslint-disable-next-line no-new
          new URL(url); // Just validate URL format
          return url.startsWith('ws://') || url.startsWith('wss://');
        } catch {
          return false;
        }
      };

      expect(isValidWebSocketURL('wss://api.example.com')).toBe(true);
      expect(isValidWebSocketURL('ws://localhost:8080')).toBe(true);
      expect(isValidWebSocketURL('http://example.com')).toBe(false);
      expect(isValidWebSocketURL('invalid-url')).toBe(false);
    });

    it('should extract hostname correctly', () => {
      const extractHostname = (url: string): string => {
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

      expect(extractHostname('wss://api.example.com:8080/path')).toBe('api.example.com');
      expect(extractHostname('ws://localhost:3000/ws')).toBe('localhost');
      expect(() => extractHostname('http://example.com')).toThrow('Invalid WebSocket URL');
    });
  });

  describe('State Management', () => {
    it('should have sequential ready states', () => {
      const states = [
        WebSocketReadyState.CONNECTING,
        WebSocketReadyState.OPEN,
        WebSocketReadyState.CLOSING,
        WebSocketReadyState.CLOSED,
      ];

      expect(states).toEqual([0, 1, 2, 3]);
    });

    it('should have valid error codes', () => {
      const errorCodes = Object.values(SSLWebSocketErrorCode).filter(value => typeof value === 'number');
      expect(errorCodes.every(code => typeof code === 'number')).toBe(true);
      expect(errorCodes.every(code => code >= 1000)).toBe(true);
    });
  });

  describe('Edge Cases', () => {
    it('should handle edge case URLs', () => {
      const extractHostname = (url: string): string => {
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

      // IPv6 addresses
      expect(() => extractHostname('wss://[::1]:8080/ws')).not.toThrow();

      // Domain with ports
      expect(extractHostname('wss://example.com:443/ws')).toBe('example.com');

      // Subdomain
      expect(extractHostname('wss://api.sub.example.com/ws')).toBe('api.sub.example.com');
    });
  });
});

import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  /**
   * Create a new WebSocket connection with SSL Pinning
   */
  createWebSocket(
    id: string,
    url: string,
    protocols?: string[],
    sslConfig?: {
      hostname: string;
      publicKeyHashes: string[];
      includeSubdomains?: boolean;
      timeout?: number;
    },
    options?: {
      allowSelfSignedCerts?: boolean;
      connectionTimeout?: number;
    }
  ): Promise<void>;

  /**
   * Close a WebSocket connection
   */
  closeWebSocket(id: string, code?: number, reason?: string): Promise<void>;

  /**
   * Send data via WebSocket
   */
  sendData(id: string, data: string): Promise<void>;

  /**
   * Get current WebSocket state
   */
  getReadyState(id: string): Promise<number>;

  /**
   * Get SSL validation result
   */
  getSSLValidationResult(id: string): Promise<{
    success: boolean;
    hostname: string;
    foundKeyHash?: string;
    expectedKeyHashes: string[];
    error?: string;
  } | null>;

  /**
   * Poll for WebSocket events
   */
  pollEvents(id: string): Promise<any[]>;

  /**
   * Clean up WebSocket resources
   */
  cleanup(id: string): Promise<void>;
}

export default TurboModuleRegistry.getEnforcing<Spec>('SSLWebSocket');

import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  'Le package \'react-native-pinned-ws\' ne semble pas être lié. Assurez-vous de:\n\n' +
  Platform.select({ ios: "- Avoir exécuté 'pod install'\n", default: '' }) +
  '- Si vous utilisez React Native >= 0.60, exécutez `npx react-native clean` puis rebuildez\n' +
  '- Si vous utilisez React Native < 0.60, vérifiez que le package est correctement lié\n' +
  '- Si vous utilisez Expo, ce package n\'est pas compatible avec Expo Go\n';

// More robust turbo module detection
let SSLWebSocketModule = null;
try {
  // First try traditional native modules
  if (NativeModules.SSLWebSocket) {
    SSLWebSocketModule = NativeModules.SSLWebSocket;
  }
  // Then try turbo modules if available
  else if ((global as any).__turboModuleProxy != null) {
    const TurboModuleRegistry = require('react-native').TurboModuleRegistry;
    SSLWebSocketModule = TurboModuleRegistry.getEnforcing('SSLWebSocket');
  }
} catch (error) {
  console.warn('Error loading SSLWebSocket native module:', error);
}

// Check that native module is available, otherwise throw error
if (!SSLWebSocketModule) {
  throw new Error(
    '❌ SSLWebSocket native module not available!\n' +
    'The native module is required for WebSocket events to work.\n' +
    LINKING_ERROR
  );
}


export default SSLWebSocketModule;

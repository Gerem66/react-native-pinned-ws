# React Native SSL WebSocket

> **Attention** : Cette bibliothèque a été entièrement conçue et générée par IA. Bien que fonctionnelle, une review humaine est recommandée avant utilisation en production.

WebSocket sécurisé avec SSL Public Key Pinning pour React Native.
Support complet des connexions `ws://` et `wss://`.

## Installation

```bash
npm install react-native-pinned-ws
```

## Usage

```typescript
import { SSLWebSocket } from 'react-native-pinned-ws';

const ws = new SSLWebSocket({
  url: 'wss://api.example.com/ws',
  protocols: 'echo-protocol',
  connectionTimeout: 5000,
  sslPinning: {
    hostname: 'api.example.com',
    publicKeyHashes: ['AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=']
  }
});

ws.addEventListener('open', () => console.log('Connected'));
ws.addEventListener('message', (event) => console.log('Data:', event.data));
ws.addEventListener('error', (event) => console.log('Error:', event.message));
ws.addEventListener('close', (event) => console.log('Closed:', event.code));

ws.connect();
```

## API

| Export | Description |
|--------|-------------|
| `SSLWebSocket` | Classe principale WebSocket |
| `createSSLWebSocket()` | Factory alternative |
| `extractHostname()` | Utilitaire d'extraction hostname |

## Types

- `WebSocketConfig` - Configuration complète
- `SSLPinningConfig` - Configuration SSL Public Key Pinning  
- `WebSocket*Event` - Types d'événements typés
- `SSLValidationResult` - Résultat validation SSL

---

*Code généré par IA - Utilisez avec précaution*

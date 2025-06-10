# React Native SSL WebSocket

> **Attention** : Cette bibliothèque a été entièrement conçue et générée par IA. Bien que fonctionnelle, une review humaine est recommandée avant utilisation en production.

WebSocket sécurisé avec SSL Certificate Pinning pour React Native.

## Installation

```bash
npm install react-native-ssl-websocket
```

## Usage

```typescript
import { SSLWebSocket } from 'react-native-ssl-websocket';

const ws = new SSLWebSocket({
  url: 'wss://api.example.com/ws',
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
- `SSLPinningConfig` - Configuration SSL Pinning  
- `WebSocket*Event` - Types d'événements typés
- `SSLValidationResult` - Résultat validation SSL

---

*Code généré par IA - Utilisez avec précaution*

package com.sslwebsocket;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;

import java.security.MessageDigest;
import java.security.cert.Certificate;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.concurrent.TimeUnit;

import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.SSLPeerUnverifiedException;
import javax.net.ssl.SSLSession;
import javax.net.ssl.X509TrustManager;

import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.WebSocket;
import okhttp3.WebSocketListener;
import okio.ByteString;

public class SSLWebSocketConnection {
    public interface EventListener {
        void onEvent(String wsId, WritableMap event);
        void onClose(String wsId, int code, String reason);
    }

    private static final int CONNECTING = 0;
    private static final int OPEN = 1;
    private static final int CLOSING = 2;
    private static final int CLOSED = 3;

    private final String wsId;
    private final String url;
    private final ReadableArray protocols;
    private final ReadableMap sslConfig;
    private final ReadableMap options;
    private final EventListener eventListener;

    private WebSocket webSocket;
    private OkHttpClient client;
    private int readyState = CLOSED;
    private WritableMap sslValidationResult;

    public SSLWebSocketConnection(
            String wsId,
            String url,
            ReadableArray protocols,
            ReadableMap sslConfig,
            ReadableMap options,
            EventListener eventListener
    ) {
        this.wsId = wsId;
        this.url = url;
        this.protocols = protocols;
        this.sslConfig = sslConfig;
        this.options = options;
        this.eventListener = eventListener;
        this.sslValidationResult = Arguments.createMap();
    }

    public void connect() {
        if (readyState != CLOSED) {
            WritableMap event = Arguments.createMap();
            event.putString("type", "error");
            event.putString("error", "WebSocket is not in CLOSED state");
            event.putString("code", "invalid_state");
            eventListener.onEvent(wsId, event);
            return;
        }

        readyState = CONNECTING;
        
        try {
            OkHttpClient.Builder clientBuilder = new OkHttpClient.Builder();

            // Timeout configuration
            int timeout = 30000; // 30 seconds default
            if (options != null && options.hasKey("connectionTimeout")) {
                timeout = options.getInt("connectionTimeout");
            }
            clientBuilder.connectTimeout(timeout, TimeUnit.MILLISECONDS);
            clientBuilder.readTimeout(timeout, TimeUnit.MILLISECONDS);
            clientBuilder.writeTimeout(timeout, TimeUnit.MILLISECONDS);

            // SSL Pinning configuration for WSS
            if (url.startsWith("wss://") && sslConfig != null) {
                setupSSLPinning(clientBuilder);
            }

            client = clientBuilder.build();

            Request.Builder requestBuilder = new Request.Builder().url(url);

            // Add custom headers
            if (options != null && options.hasKey("headers")) {
                ReadableMap headers = options.getMap("headers");
                if (headers != null) {
                    for (String key : headers.toHashMap().keySet()) {
                        Object value = headers.toHashMap().get(key);
                        if (value instanceof String) {
                            requestBuilder.addHeader(key, (String) value);
                        }
                    }
                }
            }

            // Add WebSocket protocols
            if (protocols != null && protocols.size() > 0) {
                StringBuilder protocolHeader = new StringBuilder();
                for (int i = 0; i < protocols.size(); i++) {
                    if (i > 0) protocolHeader.append(", ");
                    protocolHeader.append(protocols.getString(i));
                }
                requestBuilder.addHeader("Sec-WebSocket-Protocol", protocolHeader.toString());
            }

            Request request = requestBuilder.build();

            webSocket = client.newWebSocket(request, new WebSocketListener() {
                @Override
                public void onOpen(@NonNull WebSocket webSocket, @NonNull Response response) {
                    readyState = OPEN;
                    WritableMap event = Arguments.createMap();
                    event.putString("type", "open");
                    
                    String protocol = response.header("Sec-WebSocket-Protocol");
                    event.putString("protocol", protocol != null ? protocol : "");
                    
                    eventListener.onEvent(wsId, event);
                }

                @Override
                public void onMessage(@NonNull WebSocket webSocket, @NonNull String text) {
                    WritableMap event = Arguments.createMap();
                    event.putString("type", "message");
                    event.putString("data", text);
                    eventListener.onEvent(wsId, event);
                }

                @Override
                public void onMessage(@NonNull WebSocket webSocket, @NonNull ByteString bytes) {
                    WritableMap event = Arguments.createMap();
                    event.putString("type", "message");
                    event.putString("data", bytes.base64());
                    eventListener.onEvent(wsId, event);
                }

                @Override
                public void onClosing(@NonNull WebSocket webSocket, int code, @NonNull String reason) {
                    readyState = CLOSING;

                    // Send close event immediately when closing starts
                    // This ensures we don't miss close events if onClosed is never called
                    eventListener.onClose(wsId, code, reason);
                }

                @Override
                public void onClosed(@NonNull WebSocket webSocket, int code, @NonNull String reason) {
                    readyState = CLOSED;

                    // onClosed might be called after onClosing, but we already sent the close event in onClosing
                    // So we don't need to send it again here to avoid duplicates
                }

                @Override
                public void onFailure(@NonNull WebSocket webSocket, @NonNull Throwable t, @Nullable Response response) {
                    readyState = CLOSED;

                    // Send error event first
                    WritableMap event = Arguments.createMap();
                    event.putString("type", "error");
                    event.putString("error", t.getMessage());
                    event.putString("code", "connection_failed");
                    eventListener.onEvent(wsId, event);

                    // Then send close event to ensure proper cleanup
                    eventListener.onClose(wsId, 1006, "Connection failed: " + t.getMessage());
                }
            });

        } catch (Exception e) {
            readyState = CLOSED;
            // Send error via event instead of Promise
            WritableMap event = Arguments.createMap();
            event.putString("type", "error");
            event.putString("error", e.getMessage());
            event.putString("code", "connection_setup_failed");
            eventListener.onEvent(wsId, event);
        }
    }

    private void setupSSLPinning(OkHttpClient.Builder clientBuilder) {
        if (sslConfig == null || !sslConfig.hasKey("publicKeyHashes")) {
            return;
        }

        ReadableArray hashes = sslConfig.getArray("publicKeyHashes");
        if (hashes == null || hashes.size() == 0) {
            return;
        }

        List<String> expectedHashes = new ArrayList<>();
        for (int i = 0; i < hashes.size(); i++) {
            expectedHashes.add(hashes.getString(i));
        }

        String hostname = sslConfig.hasKey("hostname") ? sslConfig.getString("hostname") : extractHostname(url);

        // Create custom trust manager for SSL Pinning
        X509TrustManager trustManager = new SSLPinningTrustManager(expectedHashes, hostname, sslValidationResult);
        
        // Create custom hostname verifier
        HostnameVerifier hostnameVerifier = new HostnameVerifier() {
            @Override
            public boolean verify(String hostname, SSLSession session) {
                // Let trust manager handle validation
                return true;
            }
        };

        try {
            clientBuilder.sslSocketFactory(
                new SSLPinningSocketFactory(trustManager),
                trustManager
            );
            clientBuilder.hostnameVerifier(hostnameVerifier);
        } catch (Exception e) {
            throw new RuntimeException("Failed to setup SSL pinning", e);
        }
    }

    private String extractHostname(String url) {
        try {
            return java.net.URI.create(url).getHost();
        } catch (Exception e) {
            return "unknown";
        }
    }

    public void close(int code, String reason) {
        if (readyState == CLOSED) {
            return;
        }

        readyState = CLOSING;
        if (webSocket != null) {
            webSocket.close(code, reason);
        }
    }

    public void sendData(String data, Promise promise) {
        if (readyState != OPEN) {
            promise.reject("invalid_state", "WebSocket is not in OPEN state");
            return;
        }

        if (webSocket != null) {
            boolean success = webSocket.send(data);
            if (success) {
                promise.resolve(null);
            } else {
                promise.reject("send_failed", "Failed to send message");
            }
        } else {
            promise.reject("websocket_null", "WebSocket is null");
        }
    }

    public int getReadyState() {
        return readyState;
    }

    public WritableMap getSSLValidationResult() {
        return sslValidationResult;
    }

    public void cleanup() {
        if (webSocket != null) {
            webSocket.cancel();
            webSocket = null;
        }
        if (client != null) {
            client.dispatcher().executorService().shutdown();
            client.connectionPool().evictAll();
            client = null;
        }
        readyState = CLOSED;
    }
}

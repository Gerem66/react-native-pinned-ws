package com.sslwebsocket;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

public class SSLWebSocketModule extends ReactContextBaseJavaModule {
    public static final String NAME = "SSLWebSocket";
    private final ConcurrentHashMap<String, SSLWebSocketConnection> connections = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, Callback> eventCallbacks = new ConcurrentHashMap<>();

    public SSLWebSocketModule(ReactApplicationContext reactContext) {
        super(reactContext);
    }

    @Override
    @NonNull
    public String getName() {
        return NAME;
    }

    @ReactMethod
    public void createWebSocket(
            String wsId,
            String url,
            @Nullable ReadableArray protocols,
            @Nullable ReadableMap sslConfig,
            @Nullable ReadableMap options,
            Promise promise
    ) {
        android.util.Log.d("SSLWebSocket", "Création WebSocket - ID: " + wsId + ", URL: " + url);
        try {
            if (connections.containsKey(wsId)) {
                android.util.Log.w("SSLWebSocket", "WebSocket existe déjà: " + wsId);
                promise.reject("websocket_exists", "WebSocket with this ID already exists");
                return;
            }

            SSLWebSocketConnection connection = new SSLWebSocketConnection(
                    wsId,
                    url,
                    protocols,
                    sslConfig,
                    options,
                    new SSLWebSocketConnection.EventListener() {
                        @Override
                        public void onEvent(String wsId, WritableMap event) {
                            android.util.Log.d("SSLWebSocket", "Événement reçu du WebSocket: " + event.toString());
                            
                            // Check that connection still exists
                            if (connections.containsKey(wsId)) {
                                sendWebSocketEvent(wsId, event);
                            } else {
                                android.util.Log.d("SSLWebSocket", "Connection already removed for: " + wsId + ", ignored event");
                            }
                        }

                        @Override
                        public void onClose(String wsId, int code, String reason) {
                            android.util.Log.d("SSLWebSocket", "WebSocket fermé: " + wsId + ", code: " + code);
                            connections.remove(wsId);
                            
                            WritableMap event = Arguments.createMap();
                            event.putString("type", "close");
                            event.putInt("code", code);
                            event.putString("reason", reason != null ? reason : "");
                            sendWebSocketEvent(wsId, event);
                        }
                    }
            );

            connections.put(wsId, connection);
            android.util.Log.d("SSLWebSocket", "Connexion WebSocket créée, démarrage...");
            connection.connect();
            
            // Resolve Promise once connection is created and initialized
            promise.resolve(null);

        } catch (Exception e) {
            android.util.Log.e("SSLWebSocket", "Erreur création WebSocket: " + e.getMessage(), e);
            // Rejeter la Promise en cas d'erreur
            promise.reject("connection_failed", e.getMessage(), e);
        }
    }

    @ReactMethod
    public void registerEventCallback(String wsId, Callback callback) {
        android.util.Log.d("SSLWebSocket", "Enregistrement callback pour WebSocket: " + wsId);
        eventCallbacks.put(wsId, callback);
    }

    @ReactMethod
    public void closeWebSocket(String wsId, @Nullable Integer code, @Nullable String reason, Promise promise) {
        try {
            android.util.Log.d("SSLWebSocket", "Fermeture WebSocket: " + wsId + ", code: " + code);
            
            SSLWebSocketConnection connection = connections.get(wsId);
            if (connection == null) {
                android.util.Log.w("SSLWebSocket", "WebSocket non trouvé pour fermeture: " + wsId);
                promise.reject("websocket_not_found", "WebSocket not found");
                return;
            }

            // Fermer la connexion
            connection.close(code != null ? code : 1000, reason);
            
            // Immediately remove connection from map to avoid leaks
            connections.remove(wsId);
            
            // Remove associated callback
            eventCallbacks.remove(wsId);
            
            android.util.Log.d("SSLWebSocket", "WebSocket fermé et nettoyé: " + wsId);
            promise.resolve(null);

        } catch (Exception e) {
            android.util.Log.e("SSLWebSocket", "Erreur fermeture WebSocket: " + e.getMessage(), e);
            promise.reject("close_failed", e.getMessage(), e);
        }
    }

    @ReactMethod
    public void sendData(String wsId, String data, Promise promise) {
        try {
            SSLWebSocketConnection connection = connections.get(wsId);
            if (connection == null) {
                promise.reject("websocket_not_found", "WebSocket not found");
                return;
            }

            connection.sendData(data, promise);

        } catch (Exception e) {
            promise.reject("send_failed", e.getMessage(), e);
        }
    }

    @ReactMethod
    public void getReadyState(String wsId, Promise promise) {
        try {
            SSLWebSocketConnection connection = connections.get(wsId);
            if (connection == null) {
                promise.reject("websocket_not_found", "WebSocket not found");
                return;
            }

            promise.resolve(connection.getReadyState());

        } catch (Exception e) {
            promise.reject("get_state_failed", e.getMessage(), e);
        }
    }

    @ReactMethod
    public void getSSLValidationResult(String wsId, Promise promise) {
        try {
            SSLWebSocketConnection connection = connections.get(wsId);
            if (connection == null) {
                promise.reject("websocket_not_found", "WebSocket not found");
                return;
            }

            WritableMap result = connection.getSSLValidationResult();
            promise.resolve(result);

        } catch (Exception e) {
            promise.reject("get_validation_failed", e.getMessage(), e);
        }
    }

    @ReactMethod
    public void cleanup(String wsId, Promise promise) {
        try {
            android.util.Log.d("SSLWebSocket", "Début nettoyage WebSocket: " + wsId);
            
            // Remove callback first to avoid calls after cleanup
            eventCallbacks.remove(wsId);
            
            // Then remove and cleanup connection
            SSLWebSocketConnection connection = connections.remove(wsId);
            if (connection != null) {
                connection.cleanup();
                android.util.Log.d("SSLWebSocket", "Connection cleaned up for: " + wsId);
            } else {
                android.util.Log.d("SSLWebSocket", "No connection to clean up for: " + wsId);
            }
            
            android.util.Log.d("SSLWebSocket", "Nettoyage WebSocket terminé: " + wsId);
            promise.resolve(null);

        } catch (Exception e) {
            android.util.Log.e("SSLWebSocket", "Erreur lors du nettoyage: " + e.getMessage(), e);
            promise.reject("cleanup_failed", e.getMessage(), e);
        }
    }

    private void sendEvent(String eventName, WritableMap params) {
        android.util.Log.d("SSLWebSocket", "Émission événement: " + eventName + " avec params: " + params.toString());
        if (getReactApplicationContext().hasActiveReactInstance()) {
            try {
                getReactApplicationContext()
                        .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                        .emit(eventName, params);
                android.util.Log.d("SSLWebSocket", "Événement émis avec succès via DeviceEventEmitter");
            } catch (Exception e) {
                android.util.Log.e("SSLWebSocket", "Erreur DeviceEventEmitter: " + e.getMessage(), e);
            }
        } else {
            android.util.Log.w("SSLWebSocket", "Pas d'instance React active, événement non émis");
        }
    }

    private void sendWebSocketEvent(String wsId, WritableMap event) {
        event.putString("id", wsId);
        
        // Essayer d'abord le callback direct si disponible
        Callback callback = eventCallbacks.get(wsId);
        if (callback != null) {
            android.util.Log.d("SSLWebSocket", "Envoi événement via callback direct: " + event.toString());
            try {
                // Appeler directement le callback sans changement de thread
                callback.invoke(event);
                android.util.Log.d("SSLWebSocket", "Callback direct appelé avec succès");
                return; // Success, no need for DeviceEventEmitter
            } catch (Exception e) {
                android.util.Log.e("SSLWebSocket", "Erreur callback direct: " + e.getMessage(), e);
                // Continue vers DeviceEventEmitter en cas d'erreur
            }
        }
        
        // Fallback vers DeviceEventEmitter
        android.util.Log.d("SSLWebSocket", "Envoi événement via DeviceEventEmitter: " + event.toString());
        sendEvent("SSLWebSocket_Event", event);
    }

    @Override
    public Map<String, Object> getConstants() {
        final Map<String, Object> constants = new HashMap<>();
        constants.put("CONNECTING", 0);
        constants.put("OPEN", 1);
        constants.put("CLOSING", 2);
        constants.put("CLOSED", 3);
        return constants;
    }

    // Methods required for NativeEventEmitter
    private int listenerCount = 0;

    @ReactMethod
    public void addListener(String eventName) {
        // Incrementer le compteur de listeners
        listenerCount++;
    }

    @ReactMethod
    public void removeListeners(Integer count) {
        // Decrement listener counter
        listenerCount = Math.max(0, listenerCount - count);
    }
}

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
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.Queue;
import java.util.List;
import java.util.ArrayList;

public class SSLWebSocketModule extends ReactContextBaseJavaModule {
    public static final String NAME = "SSLWebSocket";
    private final ConcurrentHashMap<String, SSLWebSocketConnection> connections = new ConcurrentHashMap<>();
    
    // Event queue for polling-based approach
    private final Queue<WritableMap> eventQueue = new ConcurrentLinkedQueue<>();

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
        try {
            if (connections.containsKey(wsId)) {
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
                            // Check that connection still exists
                            if (connections.containsKey(wsId)) {
                                sendWebSocketEvent(wsId, event);
                            }
                        }

                        @Override
                        public void onClose(String wsId, int code, String reason) {
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
            connection.connect();
            
            // Resolve Promise once connection is created and initialized
            promise.resolve(null);

        } catch (Exception e) {
            promise.reject("connection_failed", e.getMessage(), e);
        }
    }

    @ReactMethod
    public void closeWebSocket(String wsId, @Nullable Integer code, @Nullable String reason, Promise promise) {
        try {
            SSLWebSocketConnection connection = connections.get(wsId);
            if (connection == null) {
                promise.reject("websocket_not_found", "WebSocket not found");
                return;
            }

            // Close connection
            connection.close(code != null ? code : 1000, reason);
            
            // Immediately remove connection from map to avoid leaks
            connections.remove(wsId);
            
            promise.resolve(null);

        } catch (Exception e) {
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
            // Then remove and cleanup connection
            SSLWebSocketConnection connection = connections.remove(wsId);
            if (connection != null) {
                connection.cleanup();
            }
            
            promise.resolve(null);

        } catch (Exception e) {
            promise.reject("cleanup_failed", e.getMessage(), e);
        }
    }

    @ReactMethod
    public void pollEvents(Promise promise) {
        try {
            List<WritableMap> events = new ArrayList<>();
            
            // Get all available events from queue
            WritableMap event;
            while ((event = eventQueue.poll()) != null) {
                events.add(event);
            }
            
            // Convert list to WritableArray
            WritableArray eventsArray = Arguments.createArray();
            for (WritableMap e : events) {
                eventsArray.pushMap(e);
            }
            
            promise.resolve(eventsArray);
            
        } catch (Exception e) {
            promise.reject("polling_failed", e.getMessage(), e);
        }
    }

    private void sendEvent(String eventName, WritableMap params) {
        if (getReactApplicationContext().hasActiveReactInstance()) {
            try {
                getReactApplicationContext()
                        .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                        .emit(eventName, params);
            } catch (Exception e) {
                android.util.Log.e("SSLWebSocket", "DeviceEventEmitter error: " + e.getMessage(), e);
            }
        } else {
            android.util.Log.w("SSLWebSocket", "No active React instance, event not emitted");
        }
    }

    private void sendWebSocketEvent(String wsId, WritableMap event) {
        event.putString("id", wsId);
        
        // Add to event queue for polling (primary approach)
        WritableMap queueEvent = Arguments.createMap();
        queueEvent.merge(event);
        eventQueue.offer(queueEvent);
        
        // Also try DeviceEventEmitter (backup approach)
        String eventName = "SSLWebSocket_Event_" + wsId;
        
        // Create a copy for the instance-specific event to avoid "Map already consumed" error
        WritableMap eventCopy = Arguments.createMap();
        eventCopy.merge(event);
        sendEvent(eventName, eventCopy);
        
        // Also send to global event for backward compatibility using original event
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
        // Increment listener counter
        listenerCount++;
    }

    @ReactMethod
    public void removeListeners(Integer count) {
        // Decrement listener counter
        listenerCount = Math.max(0, listenerCount - count);
    }
}

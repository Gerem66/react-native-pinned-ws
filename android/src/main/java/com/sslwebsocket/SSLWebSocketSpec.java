package com.sslwebsocket;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.turbomodule.core.interfaces.TurboModule;

/**
 * TurboModule spec for SSLWebSocket module
 */
public interface SSLWebSocketSpec extends TurboModule {
    void createWebSocket(String wsId, String url, ReadableArray protocols, ReadableMap sslConfig, ReadableMap options, Promise promise);
    void closeWebSocket(String wsId, Integer code, String reason, Promise promise);
    void sendData(String wsId, String data, Promise promise);
    void getReadyState(String wsId, Promise promise);
    void getSSLValidationResult(String wsId, Promise promise);
    void pollEvents(String wsId, Promise promise);
    void cleanup(String wsId, Promise promise);
    void addListener(String eventName);
    void removeListeners(double count);
}

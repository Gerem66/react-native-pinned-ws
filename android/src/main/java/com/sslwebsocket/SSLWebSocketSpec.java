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
    void send(String wsId, String message, Promise promise);
    void close(String wsId, Integer code, String reason, Promise promise);
    Integer getState(String wsId);
    void pollEvents(String wsId, Promise promise);
}

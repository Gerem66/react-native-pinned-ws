package com.sslwebsocket;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;

public interface NativeSSLWebSocketSpec {
    String getName();
    void createWebSocket(String wsId, String url, ReadableArray protocols, ReadableMap sslConfig, ReadableMap options, Promise promise);
    void send(String wsId, String message, Promise promise);
    void close(String wsId, Integer code, String reason, Promise promise);
    Integer getState(String wsId);
}

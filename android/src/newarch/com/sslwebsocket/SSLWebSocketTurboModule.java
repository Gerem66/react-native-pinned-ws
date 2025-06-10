package com.sslwebsocket;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.turbomodule.core.interfaces.TurboModule;
import com.facebook.react.module.annotations.ReactModule;

@ReactModule(name = SSLWebSocketModule.NAME)
public class SSLWebSocketTurboModule extends SSLWebSocketModule implements SSLWebSocketSpec {
    
    public SSLWebSocketTurboModule(ReactApplicationContext reactContext) {
        super(reactContext);
    }

    // Implementation remains the same as in SSLWebSocketModule
    // The spec interface will route the calls appropriately
}

package com.sslwebsocket;

import android.util.Log;
import androidx.annotation.Nullable;

import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.module.model.ReactModuleInfo;
import com.facebook.react.module.model.ReactModuleInfoProvider;
import com.facebook.react.TurboReactPackage;

import java.util.HashMap;
import java.util.Map;

/**
 * Package that creates native modules for both legacy and new architecture.
 * When the new architecture is enabled, it provides a TurboModule implementation.
 */
public class SSLWebSocketTurboPackage extends TurboReactPackage {
    private static final String TAG = "SSLWebSocketTurboPackage";

    @Nullable
    @Override
    public NativeModule getModule(String name, ReactApplicationContext reactContext) {
        if (name.equals(SSLWebSocketModule.NAME)) {
            return new SSLWebSocketModule(reactContext);
        } else {
            return null;
        }
    }

    @Override
    public ReactModuleInfoProvider getReactModuleInfoProvider() {
        return () -> {
            final Map<String, ReactModuleInfo> moduleInfos = new HashMap<>();
            boolean isTurboModule = BuildConfig.IS_NEW_ARCHITECTURE_ENABLED;
            
            moduleInfos.put(
                    SSLWebSocketModule.NAME,
                    new ReactModuleInfo(
                            SSLWebSocketModule.NAME,
                            SSLWebSocketModule.NAME,
                            false, // canOverrideExistingModule
                            false, // needsEagerInit
                            true,  // hasConstants
                            false, // isCxxModule
                            isTurboModule // isTurboModule
                    )
            );
            return moduleInfos;
        };
    }
}

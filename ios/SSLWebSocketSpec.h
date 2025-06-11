//
//  SSLWebSocketSpec.h
//  react-native-pinned-ws
//
//  Created by GameLife Team on 2025-06-06.
//

#pragma once

#include <ReactCommon/TurboModule.h>
#include <react/bridging/Bridging.h>

namespace facebook::react {

class JSI_EXPORT NativeSSLWebSocketSpecJSI : public TurboModule {
protected:
  NativeSSLWebSocketSpecJSI(std::shared_ptr<CallInvoker> jsInvoker);

public:
  virtual jsi::Value createWebSocket(jsi::Runtime &rt, const jsi::Value &thisValue, const jsi::Value *arguments, size_t count) = 0;
  virtual jsi::Value closeWebSocket(jsi::Runtime &rt, const jsi::Value &thisValue, const jsi::Value *arguments, size_t count) = 0;
  virtual jsi::Value sendData(jsi::Runtime &rt, const jsi::Value &thisValue, const jsi::Value *arguments, size_t count) = 0;
  virtual jsi::Value getReadyState(jsi::Runtime &rt, const jsi::Value &thisValue, const jsi::Value *arguments, size_t count) = 0;
  virtual jsi::Value getSSLValidationResult(jsi::Runtime &rt, const jsi::Value &thisValue, const jsi::Value *arguments, size_t count) = 0;
  virtual jsi::Value cleanup(jsi::Runtime &rt, const jsi::Value &thisValue, const jsi::Value *arguments, size_t count) = 0;
  virtual jsi::Value addListener(jsi::Runtime &rt, const jsi::Value &thisValue, const jsi::Value *arguments, size_t count) = 0;
  virtual jsi::Value removeListeners(jsi::Runtime &rt, const jsi::Value &thisValue, const jsi::Value *arguments, size_t count) = 0;
};

} // namespace facebook::react

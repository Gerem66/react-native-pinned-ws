// Jest setup file
// import 'react-native-gesture-handler/jestSetup';

jest.mock('react-native', () => {
  return {
    NativeModules: {
      SSLWebSocketModule: {
        addListener: jest.fn(),
        removeListeners: jest.fn(),
        connect: jest.fn(),
        send: jest.fn(),
        close: jest.fn(),
        getReadyState: jest.fn(),
      },
    },
    NativeEventEmitter: jest.fn().mockImplementation(() => ({
      addListener: jest.fn(),
      removeAllListeners: jest.fn(),
      removeSubscription: jest.fn(),
    })),
    Platform: {
      OS: 'ios',
      select: jest.fn((obj) => obj.ios),
    },
  };
});

// Silence the warning: Animated: `useNativeDriver` is not supported
// jest.mock('react-native/Libraries/Animated/NativeAnimatedHelper');

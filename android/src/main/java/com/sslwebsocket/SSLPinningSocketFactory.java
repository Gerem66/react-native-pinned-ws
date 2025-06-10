package com.sslwebsocket;

import java.io.IOException;
import java.net.InetAddress;
import java.net.Socket;
import java.security.SecureRandom;

import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

public class SSLPinningSocketFactory extends SSLSocketFactory {
    private final SSLSocketFactory delegate;

    public SSLPinningSocketFactory(X509TrustManager trustManager) throws Exception {
        SSLContext sslContext = SSLContext.getInstance("TLS");
        sslContext.init(null, new TrustManager[]{trustManager}, new SecureRandom());
        this.delegate = sslContext.getSocketFactory();
    }

    @Override
    public String[] getDefaultCipherSuites() {
        return delegate.getDefaultCipherSuites();
    }

    @Override
    public String[] getSupportedCipherSuites() {
        return delegate.getSupportedCipherSuites();
    }

    @Override
    public Socket createSocket() throws IOException {
        return enableTLSOnSocket(delegate.createSocket());
    }

    @Override
    public Socket createSocket(Socket s, String host, int port, boolean autoClose) throws IOException {
        return enableTLSOnSocket(delegate.createSocket(s, host, port, autoClose));
    }

    @Override
    public Socket createSocket(String host, int port) throws IOException {
        return enableTLSOnSocket(delegate.createSocket(host, port));
    }

    @Override
    public Socket createSocket(String host, int port, InetAddress localHost, int localPort) throws IOException {
        return enableTLSOnSocket(delegate.createSocket(host, port, localHost, localPort));
    }

    @Override
    public Socket createSocket(InetAddress host, int port) throws IOException {
        return enableTLSOnSocket(delegate.createSocket(host, port));
    }

    @Override
    public Socket createSocket(InetAddress address, int port, InetAddress localAddress, int localPort) throws IOException {
        return enableTLSOnSocket(delegate.createSocket(address, port, localAddress, localPort));
    }

    private Socket enableTLSOnSocket(Socket socket) {
        if (socket instanceof SSLSocket) {
            SSLSocket sslSocket = (SSLSocket) socket;
            // Enable modern TLS protocols
            sslSocket.setEnabledProtocols(new String[]{"TLSv1.2", "TLSv1.3"});
            
            // Optional: configure recommended cipher suites
            String[] supportedCipherSuites = sslSocket.getSupportedCipherSuites();
            String[] preferredCipherSuites = filterCipherSuites(supportedCipherSuites);
            if (preferredCipherSuites.length > 0) {
                sslSocket.setEnabledCipherSuites(preferredCipherSuites);
            }
        }
        return socket;
    }

    private String[] filterCipherSuites(String[] supportedCipherSuites) {
        // Filter to keep only secure cipher suites
        java.util.List<String> preferredSuites = new java.util.ArrayList<>();
        
        for (String suite : supportedCipherSuites) {
            // Prefer ECDHE for perfect forward secrecy and AES-GCM for authentication
            if (suite.contains("ECDHE") && suite.contains("AES") && suite.contains("GCM")) {
                preferredSuites.add(suite);
            }
        }
        
        // If no preferred suite is found, use all supported suites
        return preferredSuites.isEmpty() ? supportedCipherSuites : preferredSuites.toArray(new String[0]);
    }
}

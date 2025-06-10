package com.sslwebsocket;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.WritableMap;

import java.security.MessageDigest;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.util.Base64;
import java.util.List;

import javax.net.ssl.X509TrustManager;

public class SSLPinningTrustManager implements X509TrustManager {
    private static final String TAG = "SSLPinningTrustManager";
    
    private final List<String> expectedHashes;
    private final String hostname;
    private final WritableMap validationResult;

    public SSLPinningTrustManager(List<String> expectedHashes, String hostname, WritableMap validationResult) {
        this.expectedHashes = expectedHashes;
        this.hostname = hostname;
        this.validationResult = validationResult;
    }

    @Override
    public void checkClientTrusted(X509Certificate[] chain, String authType) throws CertificateException {
        // For a client trust manager, generally we do nothing
        // or delegate to another trust manager if necessary
    }

    @Override
    public void checkServerTrusted(X509Certificate[] chain, String authType) throws CertificateException {
        
        if (chain == null || chain.length == 0) {
            throw new CertificateException("Certificate chain is empty");
        }

        // Get leaf certificate (first in chain)
        X509Certificate leafCert = chain[0];

        try {
            // Extract public key
            byte[] publicKeyBytes = leafCert.getPublicKey().getEncoded();

            // Calculate SHA256 hash
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(publicKeyBytes);

            // Convert to base64
            String publicKeyHash = Base64.getEncoder().encodeToString(hash);

            // Store validation information
            validationResult.putString("hostname", hostname);
            validationResult.putString("foundKeyHash", publicKeyHash);
            
            // Convert expected hash list to WritableArray
            validationResult.putArray("expectedKeyHashes", Arguments.fromList(expectedHashes));

            // Check if hash matches
            boolean isValid = expectedHashes.contains(publicKeyHash);
            validationResult.putBoolean("success", isValid);

            if (!isValid) {
                validationResult.putString("error", "Public key hash does not match expected values");
                throw new CertificateException("SSL Pinning failed: Public key hash mismatch");
            } else {
            }

        } catch (Exception e) {
            validationResult.putBoolean("success", false);
            validationResult.putString("error", "SSL validation error: " + e.getMessage());
            throw new CertificateException("SSL Pinning validation failed", e);
        }
    }

    @Override
    public X509Certificate[] getAcceptedIssuers() {
        return new X509Certificate[0];
    }
}

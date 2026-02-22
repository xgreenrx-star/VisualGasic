// VGCrypto — VB6-style cryptographic utilities
// Wraps Godot's built-in Crypto, HashingContext, AESContext, and Marshalls classes
//
// Usage in VisualGasic:
//   ' Hash a string
//   Dim hash As String
//   hash = Crypto.SHA256("Hello World")
//
//   ' Base64 encode/decode
//   Dim encoded As String
//   encoded = Crypto.Base64Encode(myBytes)
//
//   ' AES encryption
//   Dim encrypted As Variant
//   encrypted = Crypto.EncryptAES(dataBytes, "my-secret-key-32-characters-long")
//
//   ' Random bytes
//   Dim rnd As Variant
//   rnd = Crypto.RandomBytes(16)
//
//   ' Generate UUID
//   Dim id As String
//   id = Crypto.GenerateUUID()

#ifndef VISUAL_GASIC_CRYPTO_H
#define VISUAL_GASIC_CRYPTO_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

class VGCrypto : public RefCounted {
    GDCLASS(VGCrypto, RefCounted);

protected:
    static void _bind_methods();

public:
    // Hashing — returns hex string
    static String md5_string(const String &p_text);
    static String sha1_string(const String &p_text);
    static String sha256_string(const String &p_text);

    // Hashing — returns raw bytes
    static PackedByteArray md5_bytes(const PackedByteArray &p_data);
    static PackedByteArray sha1_bytes(const PackedByteArray &p_data);
    static PackedByteArray sha256_bytes(const PackedByteArray &p_data);

    // Encoding
    static String base64_encode(const PackedByteArray &p_data);
    static PackedByteArray base64_decode(const String &p_base64);
    static String hex_encode(const PackedByteArray &p_data);
    static PackedByteArray hex_decode(const String &p_hex);

    // Simple encrypt/decrypt (AES-256-CBC)
    static PackedByteArray encrypt_aes(const PackedByteArray &p_data, const String &p_key);
    static PackedByteArray decrypt_aes(const PackedByteArray &p_data, const String &p_key);

    // Random
    static PackedByteArray random_bytes(int p_count);
    static String generate_uuid();

    // HMAC
    static PackedByteArray hmac_sha256(const PackedByteArray &p_data, const PackedByteArray &p_key);
};

#endif // VISUAL_GASIC_CRYPTO_H

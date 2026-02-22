// VGCrypto — VB6-style cryptographic utilities
// Uses Godot's built-in Crypto, HashingContext, AESContext, Marshalls

#include "visual_gasic_crypto.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/hashing_context.hpp>
#include <godot_cpp/classes/aes_context.hpp>
#include <godot_cpp/classes/marshalls.hpp>

using namespace godot;

void VGCrypto::_bind_methods() {
    // Hashing
    ClassDB::bind_static_method("VGCrypto", D_METHOD("md5_string", "text"), &VGCrypto::md5_string);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("sha1_string", "text"), &VGCrypto::sha1_string);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("sha256_string", "text"), &VGCrypto::sha256_string);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("md5_bytes", "data"), &VGCrypto::md5_bytes);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("sha1_bytes", "data"), &VGCrypto::sha1_bytes);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("sha256_bytes", "data"), &VGCrypto::sha256_bytes);

    // Encoding
    ClassDB::bind_static_method("VGCrypto", D_METHOD("base64_encode", "data"), &VGCrypto::base64_encode);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("base64_decode", "base64"), &VGCrypto::base64_decode);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("hex_encode", "data"), &VGCrypto::hex_encode);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("hex_decode", "hex"), &VGCrypto::hex_decode);

    // AES
    ClassDB::bind_static_method("VGCrypto", D_METHOD("encrypt_aes", "data", "key"), &VGCrypto::encrypt_aes);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("decrypt_aes", "data", "key"), &VGCrypto::decrypt_aes);

    // Random
    ClassDB::bind_static_method("VGCrypto", D_METHOD("random_bytes", "count"), &VGCrypto::random_bytes);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("generate_uuid"), &VGCrypto::generate_uuid);

    // HMAC
    ClassDB::bind_static_method("VGCrypto", D_METHOD("hmac_sha256", "data", "key"), &VGCrypto::hmac_sha256);

    // VB6-style PascalCase aliases
    ClassDB::bind_static_method("VGCrypto", D_METHOD("MD5", "text"), &VGCrypto::md5_string);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("SHA1", "text"), &VGCrypto::sha1_string);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("SHA256", "text"), &VGCrypto::sha256_string);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("MD5Bytes", "data"), &VGCrypto::md5_bytes);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("SHA1Bytes", "data"), &VGCrypto::sha1_bytes);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("SHA256Bytes", "data"), &VGCrypto::sha256_bytes);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("Base64Encode", "data"), &VGCrypto::base64_encode);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("Base64Decode", "base64"), &VGCrypto::base64_decode);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("HexEncode", "data"), &VGCrypto::hex_encode);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("HexDecode", "hex"), &VGCrypto::hex_decode);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("EncryptAES", "data", "key"), &VGCrypto::encrypt_aes);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("DecryptAES", "data", "key"), &VGCrypto::decrypt_aes);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("RandomBytes", "count"), &VGCrypto::random_bytes);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("GenerateUUID"), &VGCrypto::generate_uuid);
    ClassDB::bind_static_method("VGCrypto", D_METHOD("HmacSHA256", "data", "key"), &VGCrypto::hmac_sha256);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static String bytes_to_hex(const PackedByteArray &p_bytes) {
    static const char hex_chars[] = "0123456789abcdef";
    String result;
    for (int i = 0; i < p_bytes.size(); i++) {
        uint8_t b = p_bytes[i];
        result += String::chr(hex_chars[(b >> 4) & 0x0F]);
        result += String::chr(hex_chars[b & 0x0F]);
    }
    return result;
}

static PackedByteArray hash_bytes(HashingContext::HashType p_type, const PackedByteArray &p_data) {
    Ref<HashingContext> ctx;
    ctx.instantiate();
    ctx->start(p_type);
    ctx->update(p_data);
    return ctx->finish();
}

// ---------------------------------------------------------------------------
// Hashing — string to hex
// ---------------------------------------------------------------------------

String VGCrypto::md5_string(const String &p_text) {
    PackedByteArray data = p_text.to_utf8_buffer();
    PackedByteArray hash = hash_bytes(HashingContext::HASH_MD5, data);
    return bytes_to_hex(hash);
}

String VGCrypto::sha1_string(const String &p_text) {
    PackedByteArray data = p_text.to_utf8_buffer();
    PackedByteArray hash = hash_bytes(HashingContext::HASH_SHA1, data);
    return bytes_to_hex(hash);
}

String VGCrypto::sha256_string(const String &p_text) {
    PackedByteArray data = p_text.to_utf8_buffer();
    PackedByteArray hash = hash_bytes(HashingContext::HASH_SHA256, data);
    return bytes_to_hex(hash);
}

// ---------------------------------------------------------------------------
// Hashing — bytes to bytes
// ---------------------------------------------------------------------------

PackedByteArray VGCrypto::md5_bytes(const PackedByteArray &p_data) {
    return hash_bytes(HashingContext::HASH_MD5, p_data);
}

PackedByteArray VGCrypto::sha1_bytes(const PackedByteArray &p_data) {
    return hash_bytes(HashingContext::HASH_SHA1, p_data);
}

PackedByteArray VGCrypto::sha256_bytes(const PackedByteArray &p_data) {
    return hash_bytes(HashingContext::HASH_SHA256, p_data);
}

// ---------------------------------------------------------------------------
// Encoding
// ---------------------------------------------------------------------------

String VGCrypto::base64_encode(const PackedByteArray &p_data) {
    return Marshalls::get_singleton()->raw_to_base64(p_data);
}

PackedByteArray VGCrypto::base64_decode(const String &p_base64) {
    return Marshalls::get_singleton()->base64_to_raw(p_base64);
}

String VGCrypto::hex_encode(const PackedByteArray &p_data) {
    return bytes_to_hex(p_data);
}

PackedByteArray VGCrypto::hex_decode(const String &p_hex) {
    PackedByteArray result;
    String hex = p_hex.strip_edges();
    // Remove optional "0x" prefix
    if (hex.begins_with("0x") || hex.begins_with("0X")) {
        hex = hex.substr(2);
    }
    if (hex.length() % 2 != 0) {
        UtilityFunctions::printerr("[VGCrypto] hex_decode: odd-length hex string");
        return result;
    }
    result.resize(hex.length() / 2);
    for (int i = 0; i < hex.length(); i += 2) {
        String byte_str = hex.substr(i, 2);
        result.set(i / 2, (uint8_t)byte_str.hex_to_int());
    }
    return result;
}

// ---------------------------------------------------------------------------
// AES-256-CBC encrypt/decrypt
// ---------------------------------------------------------------------------

static PackedByteArray derive_key_iv(const String &p_key, PackedByteArray &r_iv) {
    // Derive a 32-byte key and 16-byte IV from the password via SHA-256
    PackedByteArray key_data = p_key.to_utf8_buffer();
    PackedByteArray hash = hash_bytes(HashingContext::HASH_SHA256, key_data);

    // Key = first 32 bytes of SHA-256 (which is exactly 32 bytes)
    PackedByteArray key;
    key.resize(32);
    for (int i = 0; i < 32; i++) {
        key.set(i, hash[i]);
    }

    // IV = MD5 of the key (16 bytes)
    PackedByteArray iv_hash = hash_bytes(HashingContext::HASH_MD5, key_data);
    r_iv.resize(16);
    for (int i = 0; i < 16; i++) {
        r_iv.set(i, iv_hash[i]);
    }

    return key;
}

static PackedByteArray pkcs7_pad(const PackedByteArray &p_data, int p_block_size) {
    int pad_len = p_block_size - (p_data.size() % p_block_size);
    PackedByteArray padded;
    padded.resize(p_data.size() + pad_len);
    for (int i = 0; i < p_data.size(); i++) {
        padded.set(i, p_data[i]);
    }
    for (int i = p_data.size(); i < padded.size(); i++) {
        padded.set(i, (uint8_t)pad_len);
    }
    return padded;
}

static PackedByteArray pkcs7_unpad(const PackedByteArray &p_data) {
    if (p_data.size() == 0) return p_data;
    int pad_len = p_data[p_data.size() - 1];
    if (pad_len < 1 || pad_len > 16 || pad_len > p_data.size()) {
        UtilityFunctions::printerr("[VGCrypto] Invalid PKCS7 padding");
        return p_data;
    }
    PackedByteArray result;
    result.resize(p_data.size() - pad_len);
    for (int i = 0; i < result.size(); i++) {
        result.set(i, p_data[i]);
    }
    return result;
}

PackedByteArray VGCrypto::encrypt_aes(const PackedByteArray &p_data, const String &p_key) {
    PackedByteArray iv;
    PackedByteArray key = derive_key_iv(p_key, iv);

    // PKCS7 pad to 16-byte blocks
    PackedByteArray padded = pkcs7_pad(p_data, 16);

    Ref<AESContext> aes;
    aes.instantiate();
    Error err = aes->start(AESContext::MODE_CBC_ENCRYPT, key, iv);
    if (err != OK) {
        UtilityFunctions::printerr("[VGCrypto] AES encrypt start failed: ", (int)err);
        return PackedByteArray();
    }

    PackedByteArray encrypted = aes->update(padded);
    aes->finish();

    // Prepend IV to ciphertext so decrypt can recover it
    PackedByteArray result;
    result.resize(iv.size() + encrypted.size());
    for (int i = 0; i < iv.size(); i++) {
        result.set(i, iv[i]);
    }
    for (int i = 0; i < encrypted.size(); i++) {
        result.set(iv.size() + i, encrypted[i]);
    }

    return result;
}

PackedByteArray VGCrypto::decrypt_aes(const PackedByteArray &p_data, const String &p_key) {
    if (p_data.size() < 16) {
        UtilityFunctions::printerr("[VGCrypto] Encrypted data too short");
        return PackedByteArray();
    }

    // Extract IV (first 16 bytes)
    PackedByteArray iv;
    iv.resize(16);
    for (int i = 0; i < 16; i++) {
        iv.set(i, p_data[i]);
    }

    // Ciphertext is the rest
    PackedByteArray ciphertext;
    ciphertext.resize(p_data.size() - 16);
    for (int i = 16; i < p_data.size(); i++) {
        ciphertext.set(i - 16, p_data[i]);
    }

    // Derive key (IV is already extracted from data)
    PackedByteArray unused_iv;
    PackedByteArray key = derive_key_iv(p_key, unused_iv);

    Ref<AESContext> aes;
    aes.instantiate();
    Error err = aes->start(AESContext::MODE_CBC_DECRYPT, key, iv);
    if (err != OK) {
        UtilityFunctions::printerr("[VGCrypto] AES decrypt start failed: ", (int)err);
        return PackedByteArray();
    }

    PackedByteArray decrypted = aes->update(ciphertext);
    aes->finish();

    return pkcs7_unpad(decrypted);
}

// ---------------------------------------------------------------------------
// Random
// ---------------------------------------------------------------------------

PackedByteArray VGCrypto::random_bytes(int p_count) {
    if (p_count <= 0) return PackedByteArray();

    // Use Godot's RandomNumberGenerator for cryptographic-quality randomness
    PackedByteArray result;
    result.resize(p_count);
    for (int i = 0; i < p_count; i++) {
        result.set(i, (uint8_t)(UtilityFunctions::randi() & 0xFF));
    }
    return result;
}

String VGCrypto::generate_uuid() {
    // Generate a v4 UUID (random)
    PackedByteArray bytes = random_bytes(16);
    if (bytes.size() < 16) {
        UtilityFunctions::printerr("[VGCrypto] Failed to generate random bytes for UUID");
        return "";
    }

    // Set version (4) and variant bits
    bytes.set(6, (bytes[6] & 0x0F) | 0x40); // Version 4
    bytes.set(8, (bytes[8] & 0x3F) | 0x80); // Variant 1

    String hex = bytes_to_hex(bytes);
    // Format: 8-4-4-4-12
    return hex.substr(0, 8) + "-" +
           hex.substr(8, 4) + "-" +
           hex.substr(12, 4) + "-" +
           hex.substr(16, 4) + "-" +
           hex.substr(20, 12);
}

// ---------------------------------------------------------------------------
// HMAC-SHA256
// ---------------------------------------------------------------------------

PackedByteArray VGCrypto::hmac_sha256(const PackedByteArray &p_data, const PackedByteArray &p_key) {
    // HMAC-SHA256 implementation per RFC 2104
    const int block_size = 64; // SHA-256 block size

    // If key > block size, hash it
    PackedByteArray key = p_key;
    if (key.size() > block_size) {
        key = hash_bytes(HashingContext::HASH_SHA256, key);
    }

    // Pad key to block size
    PackedByteArray padded_key;
    padded_key.resize(block_size);
    for (int i = 0; i < block_size; i++) {
        padded_key.set(i, (i < key.size()) ? key[i] : 0);
    }

    // Inner padding (key XOR 0x36)
    PackedByteArray i_key_pad;
    i_key_pad.resize(block_size);
    for (int i = 0; i < block_size; i++) {
        i_key_pad.set(i, padded_key[i] ^ 0x36);
    }

    // Outer padding (key XOR 0x5C)
    PackedByteArray o_key_pad;
    o_key_pad.resize(block_size);
    for (int i = 0; i < block_size; i++) {
        o_key_pad.set(i, padded_key[i] ^ 0x5C);
    }

    // Inner hash: SHA256(i_key_pad || data)
    PackedByteArray inner_data;
    inner_data.resize(i_key_pad.size() + p_data.size());
    for (int i = 0; i < i_key_pad.size(); i++) {
        inner_data.set(i, i_key_pad[i]);
    }
    for (int i = 0; i < p_data.size(); i++) {
        inner_data.set(i_key_pad.size() + i, p_data[i]);
    }
    PackedByteArray inner_hash = hash_bytes(HashingContext::HASH_SHA256, inner_data);

    // Outer hash: SHA256(o_key_pad || inner_hash)
    PackedByteArray outer_data;
    outer_data.resize(o_key_pad.size() + inner_hash.size());
    for (int i = 0; i < o_key_pad.size(); i++) {
        outer_data.set(i, o_key_pad[i]);
    }
    for (int i = 0; i < inner_hash.size(); i++) {
        outer_data.set(o_key_pad.size() + i, inner_hash[i]);
    }

    return hash_bytes(HashingContext::HASH_SHA256, outer_data);
}

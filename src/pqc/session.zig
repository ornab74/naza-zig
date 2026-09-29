const std = @import("std");

const ml_kem = std.crypto.kem.ml_kem;
const sha3 = std.crypto.hash.sha3;

/// NAZA's first post-quantum session profile.
///
/// The wire identifier is intentionally NAZA-local. It is not a NIST, IANA,
/// TLS, HPKE, or other standards-registry code point.
pub const Algorithm = enum(u8) {
    ml_kem_768 = 1,
};

pub const algorithm: Algorithm = .ml_kem_768;
pub const Kem = ml_kem.MLKem768;
pub const PublicKey = Kem.PublicKey;
pub const SecretKey = Kem.SecretKey;
pub const KeyPair = Kem.KeyPair;
pub const Ciphertext = [Kem.ciphertext_length]u8;
pub const SessionKey = [32]u8;

pub const Encapsulation = struct {
    ciphertext: Ciphertext,
    session_key: SessionKey,
};

const kdf_label = "NAZA-PQC-SESSION-v1";

/// Generate a fresh ML-KEM-768 key pair using Zig's cryptographic RNG.
pub fn generateKeyPair() KeyPair {
    return KeyPair.generate();
}

/// Encapsulate to `public_key` and bind the resulting session key to
/// application-controlled context.
///
/// `context` should identify the protocol purpose and, where available, the
/// peer/session transcript. Reusing the same ML-KEM shared secret under a
/// different context therefore produces a different application session key.
pub fn encapsulate(public_key: PublicKey, context: []const u8) Encapsulation {
    const result = public_key.encaps(null);
    return .{
        .ciphertext = result.ciphertext,
        .session_key = deriveSessionKey(&result.shared_secret, context),
    };
}

/// Decapsulate an ML-KEM-768 ciphertext and derive the same context-bound
/// application session key.
///
/// FIPS 203 implicit rejection remains inside the KEM: malformed ciphertexts
/// produce a pseudorandom replacement secret rather than a validity oracle.
pub fn decapsulate(
    secret_key: SecretKey,
    ciphertext: *const Ciphertext,
    context: []const u8,
) !SessionKey {
    const shared_secret = try secret_key.decaps(ciphertext);
    return deriveSessionKey(&shared_secret, context);
}

/// Domain-separated key derivation for the NAZA PQC session profile.
///
/// This deliberately derives an application key instead of exposing the raw
/// ML-KEM shared secret to callers. ML-KEM's shared secret is fixed at 32 bytes,
/// so the concatenation boundary after `context` is unambiguous.
pub fn deriveSessionKey(shared_secret: *const [Kem.shared_length]u8, context: []const u8) SessionKey {
    var out: SessionKey = undefined;
    var h = sha3.Sha3_256.init(.{});
    h.update(kdf_label);
    h.update(&[_]u8{@intFromEnum(algorithm)});
    h.update(context);
    h.update(shared_secret);
    h.final(&out);
    return out;
}

test "ML-KEM-768 session peers derive the same key" {
    const key_pair = generateKeyPair();
    const context = "naza:test:session-agreement";
    const initiator = encapsulate(key_pair.public_key, context);
    const responder = try decapsulate(key_pair.secret_key, &initiator.ciphertext, context);
    try std.testing.expectEqualSlices(u8, &initiator.session_key, &responder);
}

test "session KDF separates contexts" {
    const key_pair = generateKeyPair();
    const encapsulated = key_pair.public_key.encaps(null);
    const a = deriveSessionKey(&encapsulated.shared_secret, "naza:channel:a");
    const b = deriveSessionKey(&encapsulated.shared_secret, "naza:channel:b");
    try std.testing.expect(!std.mem.eql(u8, &a, &b));
}

test "tampered ciphertext does not recover valid session key" {
    const key_pair = generateKeyPair();
    const context = "naza:test:implicit-rejection";
    const valid = encapsulate(key_pair.public_key, context);

    var tampered = valid.ciphertext;
    tampered[0] ^= 0x01;
    const rejected = try decapsulate(key_pair.secret_key, &tampered, context);
    try std.testing.expect(!std.mem.eql(u8, &valid.session_key, &rejected));
}

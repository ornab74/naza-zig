const std = @import("std");
const session = @import("pqc/session.zig");

const ml_kem = std.crypto.kem.ml_kem;

const SelfTestError = error{
    SharedSecretMismatch,
    SerializationRoundTripMismatch,
    ImplicitRejectionFailed,
    SessionKeyMismatch,
    ContextSeparationFailed,
};

fn exerciseKem(comptime Kem: type, verbose: bool) !void {
    const key_pair = Kem.KeyPair.generate();

    // Fresh encapsulation / decapsulation must agree.
    const encapsulated = key_pair.public_key.encaps(null);
    const recovered = try key_pair.secret_key.decaps(&encapsulated.ciphertext);
    if (!std.mem.eql(u8, &encapsulated.shared_secret, &recovered)) {
        return SelfTestError.SharedSecretMismatch;
    }

    // Exercise the public serialization boundary instead of only testing the
    // in-memory representation. This catches layout/parse regressions that an
    // ordinary round trip would otherwise miss.
    const public_bytes = key_pair.public_key.toBytes();
    const secret_bytes = key_pair.secret_key.toBytes();
    const restored_public = try Kem.PublicKey.fromBytes(&public_bytes);
    const restored_secret = try Kem.SecretKey.fromBytes(&secret_bytes);

    const serialized_encapsulation = restored_public.encaps(null);
    const serialized_recovered = try restored_secret.decaps(&serialized_encapsulation.ciphertext);
    if (!std.mem.eql(u8, &serialized_encapsulation.shared_secret, &serialized_recovered)) {
        return SelfTestError.SerializationRoundTripMismatch;
    }

    // FIPS 203 decapsulation uses implicit rejection. A modified ciphertext
    // must not reproduce the valid shared secret. This test intentionally does
    // not expect an error: a KEM decapsulator returns a replacement secret for
    // an invalid ciphertext rather than exposing ciphertext validity.
    var tampered = encapsulated.ciphertext;
    tampered[0] ^= 0x01;
    const rejected_secret = try key_pair.secret_key.decaps(&tampered);
    if (std.mem.eql(u8, &encapsulated.shared_secret, &rejected_secret)) {
        return SelfTestError.ImplicitRejectionFailed;
    }

    if (verbose) {
        std.debug.print(
            "{s}: pk={}B sk={}B ct={}B ss={}B [roundtrip + serialization + implicit rejection: OK]\n",
            .{
                Kem.name,
                Kem.PublicKey.bytes_length,
                Kem.SecretKey.bytes_length,
                Kem.ciphertext_length,
                Kem.shared_length,
            },
        );
    }
}

fn exerciseSession(verbose: bool) !void {
    const key_pair = session.generateKeyPair();
    const context = "naza:pqc-selftest:session-v1";
    const initiator = session.encapsulate(key_pair.public_key, context);
    const responder = try session.decapsulate(key_pair.secret_key, &initiator.ciphertext, context);
    if (!std.mem.eql(u8, &initiator.session_key, &responder)) {
        return SelfTestError.SessionKeyMismatch;
    }

    const other_context_key = try session.decapsulate(
        key_pair.secret_key,
        &initiator.ciphertext,
        "naza:pqc-selftest:different-context",
    );
    if (std.mem.eql(u8, &initiator.session_key, &other_context_key)) {
        return SelfTestError.ContextSeparationFailed;
    }

    if (verbose) {
        std.debug.print(
            "NAZA session profile: {s}, algorithm-id={} [agreement + context separation: OK]\n",
            .{ session.Kem.name, @intFromEnum(session.algorithm) },
        );
    }
}

pub fn runAll(verbose: bool) !void {
    try exerciseKem(ml_kem.MLKem512, verbose);
    try exerciseKem(ml_kem.MLKem768, verbose);
    try exerciseKem(ml_kem.MLKem1024, verbose);
    try exerciseSession(verbose);
}

pub fn main() !void {
    std.debug.print("NAZA FIPS-203 ML-KEM self-test\n", .{});
    try runAll(true);
    std.debug.print("All ML-KEM parameter sets and the NAZA session profile passed.\n", .{});
}

test "FIPS-203 ML-KEM-512" {
    try exerciseKem(ml_kem.MLKem512, false);
}

test "FIPS-203 ML-KEM-768" {
    try exerciseKem(ml_kem.MLKem768, false);
}

test "FIPS-203 ML-KEM-1024" {
    try exerciseKem(ml_kem.MLKem1024, false);
}

test "NAZA ML-KEM-768 session profile" {
    try exerciseSession(false);
}

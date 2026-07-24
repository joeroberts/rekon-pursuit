# SQLCipher dependency evidence

## Selected source

| Item | Evidence |
| --- | --- |
| Component | SQLCipher Community Edition |
| Release | `v4.17.0` |
| Immutable Git revision | `810db22f575ee7cf94ea96a3e91622b5fcece3dc` |
| Release tag object | `f9788efa8ac4dfed75c03e4756b1666a1d0845da` |
| Source | <https://github.com/sqlcipher/sqlcipher> |
| License | BSD 3-Clause; source `LICENSE.md` retained in the upstream release |
| Crypto provider | Apple CommonCrypto and Security.framework (`SQLCIPHER_CRYPTO_CC`) |
| Entitlement effect | None. The static library uses platform frameworks only; it adds no network, helper, telemetry, or dynamic-code capability. |

## Tracked build outputs

`lib/libsqlcipher.a` is a universal static archive. It is intentionally checked in so a clean Xcode checkout does not download or execute third-party build code.

| Artifact | SHA-256 | Architectures |
| --- | --- | --- |
| `lib/libsqlcipher.a` | `4e78fd57b76cea9bcde7c3b862818aae5cef2579111d7f82c03a3b5d04b8534a` | `arm64`, `x86_64` |
| `include/sqlite3.h` | `e564d0492e7556a8ad2f30c8ec645b5a6abb89f32f7b40465a3032d937596401` | API header |

The archive exports both `sqlite3_key` and `sqlcipher_cc_setup` for each architecture. The app target links it statically with `Security.framework`, `CoreFoundation.framework`, and `libz`.

## Rebuild recipe

Validated with Xcode 26.6 (build `17F113`) and the macOS 26.5 SDK, targeting macOS 14.0. Build each architecture in a separate empty build directory from the checked-out source revision, then combine the two static archives:

```sh
git clone https://github.com/sqlcipher/sqlcipher.git sqlcipher
git -C sqlcipher checkout 810db22f575ee7cf94ea96a3e91622b5fcece3dc

SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
CC="$(xcrun --find clang) -arch arm64" \
CFLAGS="-arch arm64 -isysroot $SDKROOT -mmacosx-version-min=14.0 -DSQLITE_HAS_CODEC -DSQLITE_TEMP_STORE=2 -DSQLITE_EXTRA_INIT=sqlcipher_extra_init -DSQLITE_EXTRA_SHUTDOWN=sqlcipher_extra_shutdown -DSQLCIPHER_CRYPTO_CC" \
LDFLAGS="-arch arm64 -isysroot $SDKROOT -mmacosx-version-min=14.0 -framework Security -framework CoreFoundation" \
../sqlcipher/configure --host=arm-apple-darwin --with-tempstore=yes --disable-shared --enable-static --enable-fts5
make -j4 libsqlite3.a
```

Repeat from a separate build directory using `x86_64` in `CC`, `CFLAGS`, `LDFLAGS`, and `--host=x86_64-apple-darwin`, then run:

```sh
lipo -create arm64/libsqlite3.a x86_64/libsqlite3.a -output libsqlcipher.a
lipo -info libsqlcipher.a
shasum -a 256 libsqlcipher.a sqlite3.h
```

## Feasibility verification

The focused local XCTest target proves all three required at-rest behaviors against a synthetic temporary database:

1. The correct 32-byte key creates and reopens the database.
2. A different 32-byte key is rejected after SQLCipher validates the encrypted first page.
3. `/usr/bin/sqlite3` cannot read the closed encrypted database.

Command:

```sh
xcodebuild test -project RekonPursuit.xcodeproj -scheme RekonPursuit \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -only-testing:RekonPursuitTests/EncryptedDatabaseTests
```

Result: 3 tests passed on 2026-07-24. This task establishes only the encrypted database boundary. Workspace schema, Keychain storage, backup/recovery, exports, and all network integrations remain outside this task.

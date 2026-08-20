# Membangun APK Release (Per-ABI)

Panduan untuk membangun dan mendistribusikan APK release aplikasi ini.

## Kenapa APK besar?

Build APK release biasa (`flutter build apk --release`) menghasilkan satu file
"fat APK" yang berisi **3 arsitektur (ABI)** sekaligus:

- `arm64-v8a` (HP modern)
- `armeabi-v7a` (HP 32-bit lama)
- `x86_64` (emulator saja)

Total native library bisa mencapai ~55 MB, sehingga APK release menjadi ~63 MB.
Padahal setiap perangkat hanya butuh **satu** ABI saja.

Solusinya: gunakan `--split-per-abi` agar menghasilkan APK terpisah per ABI.

## Prasyarat

- Flutter SDK terpasang dan ada di `PATH`.
- File keystore ada di `android/ruang_pribadi-key.jks`.
- File `android/key.properties` berisi konfigurasi signing (sudah diatur).

## Membangun

Jalankan dari root proyek:

```bash
flutter build apk --release --split-per-abi
```

Hasilnya ada di `build/app/outputs/flutter-apk/`:

| File | Ukuran (kira-kira) | Untuk |
|------|--------------------|-------|
| `app-arm64-v8a-release.apk` | ~27 MB | HP modern (distribusikan ini) |
| `app-armeabi-v7a-release.apk` | ~25 MB | HP 32-bit lama |
| `app-x86_64-release.apk` | ~28 MB | Emulator saja |

## Distribusi

- **Sebagian besar pengguna** → distribusikan `app-arm64-v8a-release.apk`.
- Hanya jika menargetkan HP lama → `app-armeabi-v7a-release.apk`.
- Jangan distribusikan `app-x86_64-release.apk` (hanya untuk emulator).

## Catatan penting

### Keystore / signing

`android/key.properties` harus menunjuk ke file keystore dengan benar.
Karena `build.gradle` me-resolve path relatif terhadap folder `android/app`,
maka gunakan `../`:

```
storeFile=../ruang_pribadi-key.jks
```

Jika path salah, build akan gagal dengan error:
`Keystore file '...' not found for signing config 'release'`.

### Font Noto Sans JP (~9 MB)

Font `Noto_Sans_JP` (9.14 MB) ikut dibundel karena dideklarasikan di
`pubspec.yaml`. Jika tidak dipakai untuk teks Jepang, hapus blok berikut untuk
menghemat ~9 MB:

```yaml
  - family: Noto_Sans_JP
    fonts:
      - asset: assets\fonts\noto_sans_jp\noto-sans-jp.ttf
```

Setelah dihapus, ukuran APK arm64 turun menjadi sekitar ~18 MB.

### Peringatan build (tidak fatal)

- Peringatan tentang `path_provider`/`shared_preferences` linux/windows plugin
  tidak memengaruhi build Android dan bisa diabaikan.
- Peringatan Kotlin Gradle Plugin (KGP) dari `file_picker` adalah peringatan
  kompatibilitas untuk versi Flutter mendatang, bukan error saat ini.

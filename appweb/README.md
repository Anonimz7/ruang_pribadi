# Super App - Web Frontend

Frontend web murni (HTML, CSS, JavaScript) untuk Super App tanpa framework.

## Struktur Folder

```
appweb/
├── css/
│   └── style.css          # Stylesheet utama dengan CSS variables
├── js/
│   ├── api.js             # API client untuk komunikasi dengan FastAPI
│   ├── auth.js            # Manajemen autentikasi dan session
│   ├── storage.js         # LocalStorage wrapper
│   ├── ui.js              # UI utilities (toast, helpers)
│   └── icons.js           # Kumpulan SVG icons
├── pages/
│   ├── translator.html    # Halaman penerjemah
│   ├── quiz.html          # Kuis matematika
│   ├── password.html      # Generator password
│   ├── gacha.html         # Gacha keberuntungan
│   ├── decision.html      # Rolling ya/tidak (TODO)
│   ├── diagram.html       # Diagram kode (TODO)
│   ├── download.html      # Downloader video (TODO)
│   ├── news.html          # Berita & saham (TODO)
│   ├── admin.html         # Admin dashboard (TODO)
│   └── settings.html      # Pengaturan (TODO)
├── assets/
│   └── icons/             # Icon files (optional)
├── index.html             # Dashboard utama
├── login.html             # Halaman login
└── README.md              # Dokumentasi ini
```

## Fitur

### Core Modules
- **API Client**: HTTP client dengan JWT authentication
- **Auth Manager**: Login/logout/session management
- **Storage**: LocalStorage wrapper dengan cache expiry
- **UI Utils**: Toast notifications, formatters, helpers
- **Icons**: 40+ SVG icons tanpa emoji

### Pages
- ✅ Dashboard dengan stats dan quick actions
- ✅ Login page dengan remember me
- ✅ Penerjemah multi-bahasa
- ✅ Kuis matematika dengan timer
- ✅ Generator password dengan strength meter
- ✅ Gacha keberuntungan
- ⏳ Rolling Ya/Tidak
- ⏳ Diagram PlantUML
- ⏳ Downloader Video
- ⏳ Berita & Saham
- ⏳ Admin Dashboard
- ⏳ Settings

## Cara Menggunakan

### Development
1. Pastikan backend FastAPI berjalan di port yang sama
2. Buka `login.html` di browser
3. Login dengan kredensial yang valid
4. Akses fitur-fitur dari sidebar

### Integrasi dengan Backend
Semua API calls menggunakan base URL yang sama dengan frontend:
```javascript
const API_BASE_URL = window.location.origin;
```

Endpoint yang digunakan:
- `POST /api/auth/login` - Login user
- `GET /api/users/me` - Get current user
- `POST /api/translate` - Translate text
- Dan lainnya sesuai kebutuhan fitur

## Design System

### Colors
- Primary: `#2563eb` (Blue)
- Success: `#10b981` (Green)
- Warning: `#f59e0b` (Amber)
- Danger: `#ef4444` (Red)

### Spacing
- xs: 4px
- sm: 8px
- md: 16px
- lg: 24px
- xl: 32px

### Dark Mode
Support dark mode dengan CSS variables:
```css
[data-theme="dark"] {
    --bg-body: #0f172a;
    --bg-card: #1e293b;
    /* ... */
}
```

## Anti-Slop Principles

1. **No inline styles** - Semua styling di CSS file
2. **Consistent naming** - BEM-like convention
3. **Single responsibility** - Setiap module punya satu tugas
4. **No magic numbers** - Gunakan CSS variables
5. **Documented code** - JSDoc comments untuk functions
6. **Reusable components** - DRY principle
7. **No emojis in UI** - Gunakan SVG icons
8. **Accessible** - Semantic HTML, proper labels

## Browser Support

- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)

## License

Internal use only.

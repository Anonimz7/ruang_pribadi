/**
 * Storage Module
 * Menangani penyimpanan lokal (LocalStorage dan IndexedDB)
 */

class StorageManager {
    constructor() {
        this.prefix = 'app_';
    }

    /**
     * Set item ke LocalStorage
     */
    setItem(key, value) {
        try {
            const serializedValue = JSON.stringify(value);
            localStorage.setItem(`${this.prefix}${key}`, serializedValue);
            return true;
        } catch (error) {
            console.error('Error saving to localStorage:', error);
            return false;
        }
    }

    /**
     * Get item dari LocalStorage
     */
    getItem(key, defaultValue = null) {
        try {
            const item = localStorage.getItem(`${this.prefix}${key}`);
            return item ? JSON.parse(item) : defaultValue;
        } catch (error) {
            console.error('Error reading from localStorage:', error);
            return defaultValue;
        }
    }

    /**
     * Remove item dari LocalStorage
     */
    removeItem(key) {
        localStorage.removeItem(`${this.prefix}${key}`);
    }

    /**
     * Clear semua item dengan prefix app
     */
    clear() {
        const keys = Object.keys(localStorage).filter(key => key.startsWith(this.prefix));
        keys.forEach(key => localStorage.removeItem(key));
    }

    /**
     * Set preference user (tema, bahasa, dll)
     */
    setPreference(key, value) {
        return this.setItem(`pref_${key}`, value);
    }

    /**
     * Get preference user
     */
    getPreference(key, defaultValue = null) {
        return this.getItem(`pref_${key}`, defaultValue);
    }

    /**
     * Set cache data dengan expiry
     */
    setCache(key, value, ttlMinutes = 60) {
        const now = new Date();
        const item = {
            value: value,
            expiry: now.getTime() + (ttlMinutes * 60 * 1000)
        };
        return this.setItem(`cache_${key}`, item);
    }

    /**
     * Get cache data (cek expiry dulu)
     */
    getCache(key, defaultValue = null) {
        const item = this.getItem(`cache_${key}`);
        
        if (!item) {
            return defaultValue;
        }

        const now = new Date();
        if (now.getTime() > item.expiry) {
            this.removeItem(`cache_${key}`);
            return defaultValue;
        }

        return item.value;
    }

    /**
     * Simpan riwayat kuis
     */
    addQuizHistory(quizData) {
        const history = this.getItem('quiz_history', []);
        history.unshift({
            ...quizData,
            timestamp: new Date().toISOString()
        });
        
        // Batasi hanya 50 riwayat terakhir
        if (history.length > 50) {
            history.splice(50);
        }
        
        return this.setItem('quiz_history', history);
    }

    /**
     * Dapatkan riwayat kuis
     */
    getQuizHistory(limit = 10) {
        const history = this.getItem('quiz_history', []);
        return history.slice(0, limit);
    }

    /**
     * Simpan hasil gacha
     */
    addGachaResult(result) {
        const results = this.getItem('gacha_results', []);
        results.unshift({
            ...result,
            timestamp: new Date().toISOString()
        });
        
        // Batasi hanya 20 hasil terakhir
        if (results.length > 20) {
            results.splice(20);
        }
        
        return this.setItem('gacha_results', results);
    }

    /**
     * Dapatkan hasil gacha terakhir
     */
    getGachaResults(limit = 5) {
        const results = this.getItem('gacha_results', []);
        return results.slice(0, limit);
    }

    /**
     * Toggle dark mode
     */
    toggleDarkMode() {
        const currentTheme = this.getPreference('theme', 'light');
        const newTheme = currentTheme === 'light' ? 'dark' : 'light';
        this.setPreference('theme', newTheme);
        this.applyTheme(newTheme);
        return newTheme;
    }

    /**
     * Apply theme ke document
     */
    applyTheme(theme) {
        if (theme === 'dark') {
            document.documentElement.setAttribute('data-theme', 'dark');
        } else {
            document.documentElement.removeAttribute('data-theme');
        }
    }

    /**
     * Initialize theme dari storage
     */
    initTheme() {
        const theme = this.getPreference('theme', 'light');
        this.applyTheme(theme);
        return theme;
    }
}

// Instance global
const storage = new StorageManager();

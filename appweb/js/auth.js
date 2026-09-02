/**
 * Auth Module
 * Menangani autentikasi dan manajemen sesi user
 */

class AuthManager {
    constructor() {
        this.token = localStorage.getItem('jwt_token');
        this.user = JSON.parse(localStorage.getItem('user_data') || 'null');
    }

    /**
     * Cek apakah user sudah login
     */
    isAuthenticated() {
        return !!this.token;
    }

    /**
     * Cek apakah user adalah admin
     */
    isAdmin() {
        return this.user?.role === 'admin';
    }

    /**
     * Login dengan username dan password
     */
    async login(username, password) {
        try {
            const response = await api.post('/api/auth/login', { 
                username, 
                password 
            }, false); // includeAuth = false karena belum punya token
            
            if (response.access_token) {
                this.setToken(response.access_token);
                
                // Ambil data user
                const userData = await api.get('/api/users/me');
                this.setUser(userData);
                
                return { success: true };
            }
            
            return { success: false, error: 'Invalid response from server' };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    /**
     * Logout
     */
    logout() {
        api.clearToken();
        this.token = null;
        this.user = null;
        window.location.href = '/login.html';
    }

    /**
     * Set token
     */
    setToken(token) {
        this.token = token;
        api.setToken(token);
    }

    /**
     * Set user data
     */
    setUser(userData) {
        this.user = userData;
        localStorage.setItem('user_data', JSON.stringify(userData));
    }

    /**
     * Ganti password
     */
    async changePassword(oldPassword, newPassword) {
        try {
            await api.put('/api/users/change-password', {
                old_password: oldPassword,
                new_password: newPassword
            });
            return { success: true };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    /**
     * Update profil user
     */
    async updateProfile(profileData) {
        try {
            const updatedUser = await api.put('/api/users/me', profileData);
            this.setUser(updatedUser);
            return { success: true };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    /**
     * Dapatkan data user saat ini
     */
    getCurrentUser() {
        return this.user;
    }

    /**
     * Dapatkan role user
     */
    getRole() {
        return this.user?.role || 'user';
    }
}

// Instance global
const auth = new AuthManager();

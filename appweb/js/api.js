/**
 * API Client Module
 * Menangani semua komunikasi dengan backend FastAPI
 */

const API_BASE_URL = window.location.origin; // Menggunakan origin yang sama dengan backend

class ApiClient {
    constructor() {
        this.baseURL = API_BASE_URL;
        this.token = localStorage.getItem('jwt_token');
    }

    /**
     * Set JWT token
     */
    setToken(token) {
        this.token = token;
        localStorage.setItem('jwt_token', token);
    }

    /**
     * Clear token (logout)
     */
    clearToken() {
        this.token = null;
        localStorage.removeItem('jwt_token');
        localStorage.removeItem('user_data');
    }

    /**
     * Get headers dengan authentication
     */
    getHeaders(includeAuth = true) {
        const headers = {
            'Content-Type': 'application/json',
        };

        if (includeAuth && this.token) {
            headers['Authorization'] = `Bearer ${this.token}`;
        }

        return headers;
    }

    /**
     * Handle response
     */
    async handleResponse(response) {
        if (!response.ok) {
            if (response.status === 401) {
                this.clearToken();
                window.location.href = '/login.html';
                throw new Error('Session expired. Please login again.');
            }

            const errorData = await response.json().catch(() => ({}));
            throw new Error(errorData.detail || `HTTP error! status: ${response.status}`);
        }

        return response.json();
    }

    /**
     * GET request
     */
    async get(endpoint, includeAuth = true) {
        const response = await fetch(`${this.baseURL}${endpoint}`, {
            method: 'GET',
            headers: this.getHeaders(includeAuth),
        });

        return this.handleResponse(response);
    }

    /**
     * POST request
     */
    async post(endpoint, data, includeAuth = true) {
        const response = await fetch(`${this.baseURL}${endpoint}`, {
            method: 'POST',
            headers: this.getHeaders(includeAuth),
            body: JSON.stringify(data),
        });

        return this.handleResponse(response);
    }

    /**
     * PUT request
     */
    async put(endpoint, data, includeAuth = true) {
        const response = await fetch(`${this.baseURL}${endpoint}`, {
            method: 'PUT',
            headers: this.getHeaders(includeAuth),
            body: JSON.stringify(data),
        });

        return this.handleResponse(response);
    }

    /**
     * DELETE request
     */
    async delete(endpoint, includeAuth = true) {
        const response = await fetch(`${this.baseURL}${endpoint}`, {
            method: 'DELETE',
            headers: this.getHeaders(includeAuth),
        });

        return this.handleResponse(response);
    }

    /**
     * Upload file
     */
    async uploadFile(endpoint, file, includeAuth = true) {
        const formData = new FormData();
        formData.append('file', file);

        const headers = this.getHeaders(includeAuth);
        delete headers['Content-Type']; // Browser akan set otomatis untuk FormData

        const response = await fetch(`${this.baseURL}${endpoint}`, {
            method: 'POST',
            headers,
            body: formData,
        });

        return this.handleResponse(response);
    }

    /**
     * Download file dengan progress
     */
    async downloadFile(endpoint, onProgress) {
        const response = await fetch(`${this.baseURL}${endpoint}`, {
            headers: this.getHeaders(),
        });

        if (!response.ok) {
            throw new Error(`Download failed: ${response.status}`);
        }

        const contentLength = response.headers.get('content-length');
        const total = contentLength ? parseInt(contentLength, 10) : 0;
        let loaded = 0;

        const reader = response.body.getReader();
        const chunks = [];

        while (true) {
            const { done, value } = await reader.read();
            if (done) break;

            chunks.push(value);
            loaded += value.length;

            if (onProgress && total > 0) {
                onProgress(loaded, total);
            }
        }

        const blob = new Blob(chunks);
        return blob;
    }
}

// Instance global
const api = new ApiClient();

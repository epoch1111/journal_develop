/**
 * Echo 日记 - API 通信层
 * 所有后端请求集中在此，外部通过 window.EchoAPI 调用
 */
window.EchoAPI = {
    // ===== 服务器地址（支持 ngrok 等公网穿透） =====

    _getServerUrl() {
        return localStorage.getItem('echo_server_url') || '';
    },

    getServerUrl() {
        return this._getServerUrl();
    },

    setServerUrl(url) {
        url = (url || '').trim().replace(/\/$/, '');  // 去掉末尾斜杠
        if (url) {
            localStorage.setItem('echo_server_url', url);
        } else {
            localStorage.removeItem('echo_server_url');
        }
    },

    _url(path) {
        const base = this._getServerUrl();
        return base ? base + path : path;
    },

    // ===== Token 管理 =====

    getToken() {
        return localStorage.getItem('echo_access_token') || '';
    },

    setToken(token) {
        if (token) {
            localStorage.setItem('echo_access_token', token);
        } else {
            localStorage.removeItem('echo_access_token');
        }
    },

    async _authFetch(url, options = {}) {
        const token = this.getToken();
        const headers = options.headers || {};
        if (token) {
            headers['Authorization'] = `Bearer ${token}`;
        }
        const res = await fetch(this._url(url), { ...options, headers });
        if (res.status === 401) {
            this.setToken('');
            window.EchoAuth && window.EchoAuth.showLogin();
            throw new Error('请先登录');
        }
        if (!res.ok) {
            const text = await res.text();
            let detail = text;
            try { detail = JSON.parse(text).detail || text; } catch (_) {}
            throw new Error(detail);
        }
        return res;
    },

    // ===== 认证 =====

    async register(username, password, email = '') {
        const res = await fetch(this._url('/api/auth/register'), {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password, email }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.detail || `HTTP ${res.status}`);
        if (data.access_token) this.setToken(data.access_token);
        return data;
    },

    async login(username, password) {
        const res = await fetch(this._url('/api/auth/login'), {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.detail || `HTTP ${res.status}`);
        if (data.access_token) this.setToken(data.access_token);
        return data;
    },

    async fetchCurrentUser() {
        const res = await this._authFetch('/api/auth/me');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async changePassword(currentPassword, newPassword) {
        const res = await this._authFetch('/api/auth/change-password', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ current_password: currentPassword, new_password: newPassword }),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.detail || data.message || `HTTP ${res.status}`);
        return data;
    },

    logout() {
        const token = this.getToken();
        if (token) {
            fetch(this._url('/api/auth/logout'), {
                method: 'POST',
                headers: { Authorization: `Bearer ${token}` },
            }).catch(() => {});
        }
        this.setToken('');
        location.reload();
    },

    // ===== 日记 CRUD =====

    async fetchDiaries(date, keyword) {
        const qs = new URLSearchParams();
        if (date) qs.set('date', date);
        if (keyword) qs.set('keyword', keyword);
        const url = `/api/diaries?${qs.toString()}`;
        const res = await this._authFetch(url);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchStats() {
        const res = await this._authFetch('/api/stats');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchTreeholeRandom() {
        const res = await fetch(this._url('/api/treehole/random'));
        if (res.status === 404) return null;
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async createTreehole(data) {
        const res = await this._authFetch('/api/treehole', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchTreeholeDetail(id) {
        const res = await this._authFetch(`/api/treehole/${id}`);
        if (res.status === 404) return null;
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchDiariesByDate(dateStr) {
        const res = await this._authFetch(`/api/diaries/date/${dateStr}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async saveDiary(data) {
        const res = await this._authFetch('/api/save', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async analyzeDiary(content, persona) {
        const res = await this._authFetch('/api/analyze', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ content, persona }),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async uploadImage(file) {
        const token = this.getToken();
        const headers = {};
        if (token) headers['Authorization'] = `Bearer ${token}`;
        const formData = new FormData();
        formData.append('file', file, 'image.jpg');
        const res = await fetch(this._url('/api/upload'), { method: 'POST', body: formData, headers });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async hugDiary(diaryId) {
        const res = await this._authFetch(`/api/treehole/${diaryId}/hug`, { method: 'POST' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async unhugDiary(diaryId) {
        const res = await this._authFetch(`/api/treehole/${diaryId}/hug`, { method: 'DELETE' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchDiaryById(id) {
        const res = await this._authFetch(`/api/diaries/${id}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async updateDiary(id, data) {
        const res = await this._authFetch(`/api/diaries/${id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async deleteDiary(id) {
        const res = await this._authFetch(`/api/diaries/${id}`, {
            method: 'DELETE',
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    // ===== 公开日记广场 =====

    async fetchPublicDiaries(params = {}) {
        const qs = new URLSearchParams();
        if (params.page) qs.set('page', params.page);
        if (params.page_size) qs.set('page_size', params.page_size);
        if (params.mood) qs.set('mood', params.mood);
        if (params.tag) qs.set('tag', params.tag);
        if (params.keyword) qs.set('keyword', params.keyword);
        if (params.client_id) qs.set('client_id', params.client_id);
        const res = await fetch(this._url(`/api/public/diaries?${qs.toString()}`));
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchPublicDiaryById(id, clientId) {
        const qs = clientId ? `?client_id=${clientId}` : '';
        const res = await this._authFetch(`/api/public/diaries/${id}${qs}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async likePublicDiary(id, clientId) {
        const res = await fetch(this._url(`/api/public/diaries/${id}/like`), {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ client_id: clientId }),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async unlikePublicDiary(id, clientId) {
        const res = await fetch(this._url(`/api/public/diaries/${id}/like?client_id=${clientId}`), {
            method: 'DELETE',
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async commentPublicDiary(id, data) {
        const res = await this._authFetch(`/api/public/diaries/${id}/comments`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchPublicDiaryComments(id, limit = 20) {
        const res = await this._authFetch(`/api/public/diaries/${id}/comments?limit=${limit}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async likeComment(commentId) {
        const res = await this._authFetch(`/api/public/diaries/comments/${commentId}/like`, { method: 'POST' });
        const data = await res.json();
        if (!res.ok) throw new Error(data?.detail || `HTTP ${res.status}`);
        return data;
    },

    async unlikeComment(commentId) {
        const res = await this._authFetch(`/api/public/diaries/comments/${commentId}/like`, { method: 'DELETE' });
        const data = await res.json();
        if (!res.ok) throw new Error(data?.detail || `HTTP ${res.status}`);
        return data;
    },

    // ===== 用户主页 =====

    async fetchMyProfile() {
        const res = await this._authFetch('/api/profile/me');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async updateMyProfile(data) {
        const res = await this._authFetch('/api/profile/me', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async uploadAvatar(file) {
        const formData = new FormData();
        formData.append('file', file);
        const token = this.getToken();
        const headers = {};
        if (token) headers['Authorization'] = `Bearer ${token}`;
        const res = await fetch(this._url('/api/profile/avatar'), {
            method: 'POST',
            headers,
            body: formData,
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchUserProfile(userId) {
        const token = this.getToken();
        const headers = {};
        if (token) headers['Authorization'] = `Bearer ${token}`;
        const res = await fetch(this._url(`/api/profile/${userId}`), { headers });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    // ===== 关注系统 =====

    async followUser(userId) {
        const res = await this._authFetch(`/api/users/${userId}/follow`, { method: 'POST' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async unfollowUser(userId) {
        const res = await this._authFetch(`/api/users/${userId}/follow`, { method: 'DELETE' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchFollowStatus(userId) {
        const token = this.getToken();
        const headers = {};
        if (token) headers['Authorization'] = `Bearer ${token}`;
        const res = await fetch(this._url(`/api/users/${userId}/follow-status`), { headers });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async searchUsers(keyword) {
        const res = await this._authFetch(`/api/users/search?keyword=${encodeURIComponent(keyword)}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchMyFollowing() {
        const res = await this._authFetch('/api/me/following');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchMyFollowers() {
        const res = await this._authFetch('/api/me/followers');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchFollowingFeed(params = {}) {
        const qs = new URLSearchParams();
        if (params.page) qs.set('page', params.page);
        if (params.page_size) qs.set('page_size', params.page_size);
        const res = await this._authFetch(`/api/me/following-feed?${qs.toString()}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    // ===== 通知中心 =====

    async fetchNotifications(params = {}) {
        const qs = new URLSearchParams();
        if (params.page) qs.set('page', params.page);
        if (params.page_size) qs.set('page_size', params.page_size);
        if (params.unread_only) qs.set('unread_only', 'true');
        const res = await this._authFetch(`/api/notifications?${qs.toString()}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchUnreadNotificationCount() {
        const res = await this._authFetch('/api/notifications/unread-count');
        if (!res.ok) return { unread_count: 0 };
        return res.json();
    },

    async markNotificationRead(id) {
        const res = await this._authFetch(`/api/notifications/${id}/read`, { method: 'POST' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async markAllNotificationsRead() {
        const res = await this._authFetch('/api/notifications/read-all', { method: 'POST' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async deleteNotification(id) {
        const res = await this._authFetch(`/api/notifications/${id}`, { method: 'DELETE' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    // ===== 打招呼系统 =====

    async createGreetRequest(data) {
        const res = await this._authFetch('/api/greet/requests', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchGreetStatus(userId) {
        const res = await this._authFetch(`/api/greet/status/${userId}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchReceivedGreetRequests(status) {
        const qs = status ? `?status=${status}` : '';
        const res = await this._authFetch(`/api/greet/requests/received${qs}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchSentGreetRequests(status) {
        const qs = status ? `?status=${status}` : '';
        const res = await this._authFetch(`/api/greet/requests/sent${qs}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchGreetRequestDetail(id) {
        const res = await this._authFetch(`/api/greet/requests/${id}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async acceptGreetRequest(id) {
        const res = await this._authFetch(`/api/greet/requests/${id}/accept`, { method: 'POST' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async rejectGreetRequest(id) {
        const res = await this._authFetch(`/api/greet/requests/${id}/reject`, { method: 'POST' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async cancelGreetRequest(id) {
        const res = await this._authFetch(`/api/greet/requests/${id}/cancel`, { method: 'POST' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchGreetPendingCount() {
        const res = await this._authFetch('/api/greet/pending-count');
        if (!res.ok) return { pending_count: 0 };
        return res.json();
    },

    // ===== 联系人 =====

    async fetchMessageContacts() {
        const res = await this._authFetch('/api/messages/contacts');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    // ===== 私信系统 =====

    async fetchConversations() {
        const res = await this._authFetch('/api/messages/conversations');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async startConversation(userId) {
        const res = await this._authFetch('/api/messages/conversations', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ user_id: userId }),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchMessages(conversationId, params = {}) {
        const qs = new URLSearchParams();
        if (params.page) qs.set('page', params.page);
        if (params.page_size) qs.set('page_size', params.page_size);
        const res = await this._authFetch(`/api/messages/conversations/${conversationId}/messages?${qs.toString()}`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async sendMessage(conversationId, data) {
        const res = await this._authFetch(`/api/messages/conversations/${conversationId}/messages`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async markConversationRead(conversationId) {
        const res = await this._authFetch(`/api/messages/conversations/${conversationId}/read`, { method: 'POST' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchMessageUnreadCount() {
        const res = await this._authFetch('/api/messages/unread-count');
        if (!res.ok) return { unread_count: 0 };
        return res.json();
    },

    // ===== 树洞回复 =====

    async replyTreehole(diaryId, content, parentReplyId = null, replyToIdentityId = null, clientId = '', imageUrls = '') {
        const body = { content, client_id: clientId };
        if (parentReplyId !== null) body.parent_reply_id = parentReplyId;
        if (replyToIdentityId !== null) body.reply_to_identity_id = replyToIdentityId;
        if (imageUrls && imageUrls.length) body.image_urls = imageUrls;
        const res = await this._authFetch(`/api/treehole/${diaryId}/reply`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async likeTreeholeReply(replyId) {
        const res = await this._authFetch(`/api/treehole/replies/${replyId}/like`, { method: 'POST' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async unlikeTreeholeReply(replyId) {
        const res = await this._authFetch(`/api/treehole/replies/${replyId}/like`, { method: 'DELETE' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    // ===== 安全中心 =====

    async blockUser(userId, data = {}) {
        const res = await this._authFetch(`/api/users/${userId}/block`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
        const body = await res.json();
        if (!res.ok) throw new Error(body.detail || `HTTP ${res.status}`);
        return body;
    },

    async unblockUser(userId) {
        const res = await this._authFetch(`/api/users/${userId}/block`, { method: 'DELETE' });
        const body = await res.json();
        if (!res.ok) throw new Error(body.detail || `HTTP ${res.status}`);
        return body;
    },

    async fetchBlockStatus(userId) {
        const res = await this._authFetch(`/api/users/${userId}/block-status`);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchBlockedUsers() {
        const res = await this._authFetch('/api/me/blocked-users');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async createReport(data) {
        const res = await this._authFetch('/api/reports', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
        const body = await res.json();
        if (!res.ok) throw new Error(body.detail || `HTTP ${res.status}`);
        return body;
    },

    async fetchMyReports() {
        const res = await this._authFetch('/api/reports/my');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

    async fetchBlockedUsers() {
        const res = await this._authFetch('/api/me/blocked-users');
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
    },

};

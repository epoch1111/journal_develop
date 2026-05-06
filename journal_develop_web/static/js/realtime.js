/**
 * Echo 日记 - WebSocket 实时推送客户端（单机内存模式）
 * 提供实时消息、通知、未读数推送，WebSocket 失败时自动降级到 HTTP 拉取
 */
window.EchoRealtime = {
    socket: null,
    reconnectTimer: null,
    reconnectAttempts: 0,
    heartbeatTimer: null,
    manuallyClosed: false,
    maxReconnectDelay: 30000,  // 最大重连间隔 30s
    heartbeatInterval: 30000, // 心跳间隔 30s

    /** 建立 WebSocket 连接 */
    connect() {
        const token = window.EchoAPI ? window.EchoAPI.getToken() : '';
        if (!token) {
            console.log('[WS] 未登录，跳过连接');
            return;
        }
        if (this.socket && this.socket.readyState === WebSocket.OPEN) {
            console.log('[WS] 已连接，跳过');
            return;
        }

        this.manuallyClosed = false;
        const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${location.host}/ws/messages?token=${encodeURIComponent(token)}`;

        console.log('[WS] 正在连接...');
        try {
            this.socket = new WebSocket(wsUrl);
        } catch (e) {
            console.warn('[WS] 连接创建失败:', e.message);
            this.scheduleReconnect();
            return;
        }

        this.socket.onopen = () => {
            console.log('[WS] 已连接');
            this.reconnectAttempts = 0;
            this._startHeartbeat();
        };

        this.socket.onmessage = (event) => {
            try {
                const payload = JSON.parse(event.data);
                console.log('[WS] received payload type:', payload.type, 'full:', payload);
                this.handleMessage(payload);
            } catch (e) {
                console.warn('[WS] 消息解析失败:', e.message);
            }
        };

        this.socket.onclose = (event) => {
            console.log(`[WS] 已断开 (code=${event.code})`);
            this._stopHeartbeat();
            this.socket = null;
            if (!this.manuallyClosed) {
                this.scheduleReconnect();
            }
        };

        this.socket.onerror = (e) => {
            console.warn('[WS] 连接错误');
        };
    },

    /** 主动断开 */
    disconnect() {
        this.manuallyClosed = true;
        this._stopHeartbeat();
        this._clearReconnect();
        if (this.socket) {
            this.socket.close(1000);
            this.socket = null;
        }
        console.log('[WS] 已主动断开');
    },

    /** 发送 JSON 消息 */
    send(payload) {
        if (this.socket && this.socket.readyState === WebSocket.OPEN) {
            this.socket.send(JSON.stringify(payload));
        }
    },

    /** 处理收到的消息 */
    handleMessage(payload) {
        const type = payload.type || '';
        switch (type) {
            case 'new_message':
                this._onNewMessage(payload);
                break;
            case 'message_sent':
                // 发送方确认，无需 UI 变化
                break;
            case 'message_unread_count_update':
                this._onMessageUnreadUpdate(payload);
                break;
            case 'new_notification':
                this._onNewNotification(payload);
                break;
            case 'notification_unread_count_update':
                this._onNotifUnreadUpdate(payload);
                break;
            case 'conversation_read':
                break;
            case 'pong':
                break;
            default:
                console.warn('[WS] 未知消息类型:', type);
        }
    },

    /** 自动重连（指数退避） */
    scheduleReconnect() {
        if (this.reconnectTimer) return;
        const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), this.maxReconnectDelay);
        this.reconnectAttempts++;
        console.log(`[WS] ${delay / 1000}s 后重连 (第${this.reconnectAttempts}次)`);
        this.reconnectTimer = setTimeout(() => {
            this.reconnectTimer = null;
            this.connect();
        }, delay);
    },

    _clearReconnect() {
        if (this.reconnectTimer) {
            clearTimeout(this.reconnectTimer);
            this.reconnectTimer = null;
        }
    },

    _startHeartbeat() {
        this._stopHeartbeat();
        this.heartbeatTimer = setInterval(() => {
            this.send({ type: 'ping' });
        }, this.heartbeatInterval);
    },

    _stopHeartbeat() {
        if (this.heartbeatTimer) {
            clearInterval(this.heartbeatTimer);
            this.heartbeatTimer = null;
        }
    },

    isConnected() {
        return this.socket && this.socket.readyState === WebSocket.OPEN;
    },

    // ===== 事件处理 =====

    _onNewMessage(payload) {
        const msg = payload.message || {};
        const conv = payload.conversation || {};
        const convId = payload.conversation_id;
        const msgId = msg.id;

        console.log('[WS] _onNewMessage received:', { convId, msgId, currentConvId, currentConvIdType: typeof currentConvId });

        // 检查是否已在聊天窗口
        const isCurrentChat = (currentConvId != null && currentConvId === convId);
        console.log('[WS] isCurrentChat check:', { currentConvId, convId, isCurrentChat });
        const chatMessagesEl = document.getElementById('chatMessages');

        if (isCurrentChat && chatMessagesEl && chatMessagesEl.style.display !== 'none') {
            // 去重：检查是否已有同 ID 消息
            const existing = chatMessagesEl.querySelector(`[data-msg-id="${msgId}"]`);
            if (!existing) {
                const isMine = msg.sender_id === (typeof myProfileData !== 'undefined' ? myProfileData.id : -1);
                const bubbleClass = isMine
                    ? 'bg-emerald-100 text-gray-700 ml-auto rounded-br-md'
                    : 'bg-white border border-gray-100 text-gray-700 mr-auto rounded-bl-md';
                const alignClass = isMine ? 'justify-end' : 'justify-start';
                const content = (typeof escapeHtml === 'function') ? escapeHtml(msg.content || '') : (msg.content || '');
                const time = (typeof formatDate === 'function') ? formatDate(msg.created_at || '') : (msg.created_at || '');

                const div = document.createElement('div');
                div.className = `flex ${alignClass}`;
                div.setAttribute('data-msg-id', msgId);
                div.innerHTML = `<div class="max-w-[75%] px-4 py-2.5 rounded-2xl ${bubbleClass} shadow-sm">
                    <p class="text-sm leading-relaxed whitespace-pre-wrap break-words">${content}</p>
                    <span class="text-[10px] text-gray-400 mt-1 block text-right">${time}</span>
                </div>`;
                chatMessagesEl.appendChild(div);
                chatMessagesEl.scrollTop = chatMessagesEl.scrollHeight;

                // 标记已读
                if (!isMine && typeof EchoAPI !== 'undefined') {
                    EchoAPI.markConversationRead(convId).catch(() => {});
                }
            }
        } else {
            // 未打开该会话：更新红点和会话列表
            if (typeof updateMsgUnreadBadge === 'function') {
                // 触发未读数更新
            }
            if (typeof showToast === 'function') {
                showToast('你收到一条新消息');
            }
        }

        // 更新会话列表中的 last_message（如果该函数存在）
        if (typeof loadConvList === 'function' && typeof currentConvId === 'undefined') {
            // 不在消息中心时不更新
        }
    },

    _onMessageUnreadUpdate(payload) {
        const count = payload.unread_count || 0;
        if (typeof updateMsgUnreadBadge === 'function') {
            updateMsgUnreadBadge(count);
        }
    },

    _onNewNotification(payload) {
        // 更新通知铃铛红点
        if (typeof fetchUnreadCount === 'function') {
            fetchUnreadCount();
        }
        // 如果通知中心已打开，prepend 到列表
        const notifList = document.getElementById('notificationList');
        if (notifList && window.getComputedStyle(notifList.parentElement).display !== 'none') {
            // 简单处理：下次打开时通过 HTTP 刷新
        }
    },

    _onNotifUnreadUpdate(payload) {
        const count = payload.unread_count || 0;
        const notificationBadge = document.getElementById('notificationBadge');
        if (notificationBadge) {
            if (count > 0) {
                notificationBadge.textContent = count > 99 ? '99+' : count;
                notificationBadge.classList.remove('hidden');
            } else {
                notificationBadge.classList.add('hidden');
            }
        }
    },
};

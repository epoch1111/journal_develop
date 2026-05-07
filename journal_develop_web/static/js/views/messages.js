/**
 * Messages View - 消息中心 + 通知 + 私信
 */
(function() {
    'use strict';

    // State variables
    let currentConvId = null;
    let currentChatPartner = null;
    let chatMsgPage = 1;
    let notificationPage = 1;
    let notificationPageSize = 20;

    // === Functions ===

    window.fetchMsgUnreadCount = async function() {
        if (!EchoAPI.getToken()) return;
        try {
            const data = await EchoAPI.fetchMessageUnreadCount();
            window.updateMsgUnreadBadge(data.unread_count || 0);
        } catch (e) { /* ignore */ }
    };

    window.updateMsgUnreadBadge = function(count) {
        const messageUnreadBadge = document.getElementById('messageUnreadBadge');
        const btnMessageCenter = document.getElementById('btnMessageCenter');
        if (count > 0) {
            messageUnreadBadge.textContent = count > 99 ? '99+' : count;
            messageUnreadBadge.classList.remove('hidden');
            btnMessageCenter.classList.remove('text-gray-400');
            btnMessageCenter.classList.add('text-indigo-500');
            // 消息 Tab badge
            const msgTabBadge = document.getElementById('msgTabChatBadge');
            if (msgTabBadge) {
                msgTabBadge.textContent = count > 99 ? '99+' : count;
                msgTabBadge.classList.remove('hidden');
            }
        } else {
            messageUnreadBadge.classList.add('hidden');
            btnMessageCenter.classList.add('text-gray-400');
            btnMessageCenter.classList.remove('text-indigo-500');
            const msgTabBadge = document.getElementById('msgTabChatBadge');
            if (msgTabBadge) msgTabBadge.classList.add('hidden');
        }
    };

    window.openMessageCenter = function() {
        const msgCenterOverlay = document.getElementById('messageCenterOverlay');
        const convListView = document.getElementById('convListView');
        const chatDetailView = document.getElementById('chatDetailView');
        if (!EchoAPI.getToken()) { showAuth('login'); return; }
        msgCenterOverlay.classList.remove('opacity-0', 'pointer-events-none');
        msgCenterOverlay.classList.add('opacity-100');
        convListView.style.display = '';
        chatDetailView.classList.add('hidden');
        chatDetailView.style.display = 'none';
        window.currentConvId = null;
        window.loadConvList();
        lucide.createIcons();
    };

    window.closeMessageCenter = function() {
        const msgCenterOverlay = document.getElementById('messageCenterOverlay');
        msgCenterOverlay.classList.add('opacity-0', 'pointer-events-none');
        msgCenterOverlay.classList.remove('opacity-100');
    };

    window.loadConvList = async function() {
        const convListContent = document.getElementById('convListContent');
        convListContent.innerHTML = '<div class="flex items-center justify-center py-20"><span class="loader w-6 h-6 border-2 border-emerald-400 border-t-transparent rounded-full inline-block"></span></div>';
        try {
            const convs = await EchoAPI.fetchConversations();
            if (!convs || convs.length === 0) {
                convListContent.innerHTML = `<div class="flex flex-col items-center justify-center py-20 text-gray-300">
                    <i data-lucide="message-circle" class="w-16 h-16 mb-4 text-gray-200"></i>
                    <p class="text-sm text-gray-400 mb-1">还没有私信</p>
                    <p class="text-xs text-gray-300 mb-4">和已认识的人开始第一句问候吧</p>
                    <button id="btnGoAcquaintances" class="px-5 py-2.5 bg-emerald-100 text-emerald-600 rounded-full text-sm font-medium hover:bg-emerald-200 active:scale-95 transition-all">去已认识列表</button>
                </div>`;
                setTimeout(() => {
                    const btn = document.getElementById('btnGoAcquaintances');
                    if (btn) btn.addEventListener('click', () => { window.closeMessageCenter(); window.openAcquaintancesModal(); });
                }, 100);
            } else {
                convListContent.innerHTML = convs.map(c => {
                    const other = c.other_user || {};
                    const avatar = other.avatar || '🐰';
                    const name = escapeHtml(other.nickname || '小兔');
                    const lastMsg = escapeHtml(c.last_message || '开始聊天吧');
                    const time = formatDate(c.last_message_at || '');
                    const unread = c.unread_count || 0;
                    return `<div class="flex items-center gap-3 p-4 rounded-2xl bg-white border border-gray-50 shadow-sm cursor-pointer hover:shadow-md active:scale-[0.98] transition-all conv-item" data-conv-id="${c.id}" data-partner='${JSON.stringify({id: other.id, nickname: other.nickname, avatar: other.avatar}).replace(/'/g, "&#39;")}'>
                        ${renderAvatar(avatar, 36)}
                        <div class="flex-1 min-w-0">
                            <div class="flex items-center justify-between mb-0.5">
                                <span class="text-sm font-medium text-gray-800">${name}</span>
                                ${unread > 0 ? `<span class="min-w-[20px] h-[20px] rounded-full bg-red-400 text-white text-[10px] font-bold flex items-center justify-center px-1">${unread > 99 ? '99+' : unread}</span>` : ''}
                            </div>
                            <p class="text-xs text-gray-400 truncate">${lastMsg}</p>
                            <span class="text-[10px] text-gray-300">${time}</span>
                        </div>
                    </div>`;
                }).join('');

                convListContent.querySelectorAll('.conv-item').forEach(item => {
                    item.addEventListener('click', () => {
                        const convId = parseInt(item.dataset.convId);
                        let partner = {};
                        try { partner = JSON.parse(item.dataset.partner.replace(/&#39;/g, "'")); } catch(e) {}
                        window.openChatDetail(convId, partner);
                    });
                });
            }
        } catch (e) {
            convListContent.innerHTML = '<p class="text-center text-gray-400 py-20">加载失败，请稍后再试</p>';
        }
        lucide.createIcons();
    };

    window.openChatDetail = async function(convId, partner) {
        const chatPartnerAvatar = document.getElementById('chatPartnerAvatar');
        const chatPartnerAvatarImg = document.getElementById('chatPartnerAvatarImg');
        const chatPartnerName = document.getElementById('chatPartnerName');
        const convListView = document.getElementById('convListView');
        const chatDetailView = document.getElementById('chatDetailView');
        const chatMessages = document.getElementById('chatMessages');
        const chatInput = document.getElementById('chatInput');
        window.currentConvId = convId;
        window.currentChatPartner = partner;
        setAvatarElements(chatPartnerAvatar, chatPartnerAvatarImg, partner.avatar);
        chatPartnerName.textContent = partner.nickname || '小兔';
        convListView.style.display = 'none';
        chatDetailView.classList.remove('hidden');
        chatDetailView.style.display = '';
        window.chatMsgPage = 1;
        chatMessages.innerHTML = '<p class="text-xs text-gray-300 text-center py-10">加载中...</p>';
        chatInput.value = '';
        await window.loadChatMessages();
        lucide.createIcons();
        requestAnimationFrame(() => {
            chatMessages.scrollTop = chatMessages.scrollHeight;
        });
    };

    window.backToConvList = function() {
        const convListView = document.getElementById('convListView');
        const chatDetailView = document.getElementById('chatDetailView');
        const chatMessages = document.getElementById('chatMessages');
        convListView.style.display = '';
        chatDetailView.classList.add('hidden');
        chatDetailView.style.display = 'none';
        window.currentConvId = null;
        window.loadConvList();
        window.fetchMsgUnreadCount();
        lucide.createIcons();
    };

    window.loadChatMessages = async function() {
        const chatMessages = document.getElementById('chatMessages');
        if (!window.currentConvId) return;
        try {
            const allMsgs = [];
            let page = 1;
            let hasMore = true;
            while (hasMore) {
                const data = await EchoAPI.fetchMessages(window.currentConvId, { page, page_size: 30 });
                const items = data.items || [];
                allMsgs.push(...items);
                hasMore = data.has_more === true;
                page++;
                if (!data.has_more) break;
            }
            if (allMsgs.length === 0) {
                chatMessages.innerHTML = '<p class="text-xs text-gray-300 text-center py-10">还没有聊天记录<br>从一句温柔的问候开始吧</p>';
            } else {
                window.renderChatMessages(allMsgs);
            }
        } catch (e) {
            chatMessages.innerHTML = '<p class="text-xs text-gray-400 text-center py-10">加载失败</p>';
        }
    };

    window.renderChatMessages = function(msgs) {
        const chatMessages = document.getElementById('chatMessages');
        chatMessages.innerHTML = msgs.map(m => {
            const isMine = m.sender_id === (myProfileData && myProfileData.id);
            const bubbleClass = isMine
                ? 'bg-emerald-100 text-gray-700 ml-auto rounded-br-md'
                : 'bg-white border border-gray-100 text-gray-700 mr-auto rounded-bl-md';
            const alignClass = isMine ? 'justify-end' : 'justify-start';
            return `<div class="flex ${alignClass}">
                <div class="max-w-[75%] px-4 py-2.5 rounded-2xl ${bubbleClass} shadow-sm">
                    <p class="text-sm leading-relaxed whitespace-pre-wrap break-words">${escapeHtml(m.content || '')}</p>
                    <span class="text-[10px] text-gray-400 mt-1 block text-right">${formatDate(m.created_at)}</span>
                </div>
            </div>`;
        }).join('');
        chatMessages.scrollTop = chatMessages.scrollHeight;
    };

    // 从外部打开与某人的聊天
    window.openChatWithUser = async function(userId, nickname, avatar) {
        window.openMessageCenter();
        try {
            const res = await EchoAPI.startConversation(userId);
            const conv = res.conversation;
            const partner = { id: userId, nickname: nickname, avatar: avatar || '🐰' };
            // 等待列表加载完成后再进入聊天
            setTimeout(() => {
                window.openChatDetail(conv.id, partner);
            }, 400);
        } catch (e) {
            showToast(e.message || '无法发起聊天');
        }
    };

    window.openAcquaintancesModal = async function() {
        const contactsModalOverlay = document.getElementById('contactsModalOverlay');
        const contactsListContent = document.getElementById('contactsListContent');
        if (!EchoAPI.getToken()) { showAuth('login'); return; }
        contactsModalOverlay.classList.remove('opacity-0', 'pointer-events-none');
        contactsModalOverlay.classList.add('opacity-100');
        contactsListContent.innerHTML = '<div class="flex items-center justify-center py-20"><span class="loader w-6 h-6 border-2 border-emerald-400 border-t-transparent rounded-full inline-block"></span></div>';
        try {
            const data = await EchoAPI.fetchMessageContacts();
            const contacts = data.contacts || [];
            if (contacts.length === 0) {
                contactsListContent.innerHTML = `<div class="flex flex-col items-center justify-center py-20 text-gray-300">
                    <i data-lucide="users" class="w-16 h-16 mb-4 text-gray-200"></i>
                    <p class="text-sm text-gray-400 mb-1">还没有已认识的人</p>
                    <p class="text-xs text-gray-300">和感兴趣的人打个招呼吧</p>
                </div>`;
            } else {
                contactsListContent.innerHTML = contacts.map(c => {
                    const avatar = c.avatar || '🐰';
                    const name = escapeHtml(c.nickname || c.username);
                    const bio = escapeHtml(c.bio || '');
                    const interests = escapeHtml(c.interests || '');
                    const subtitle = bio || interests || '';
                    const convId = c.has_conversation ? c.conversation_id : null;
                    return `<div class="flex items-center gap-3 p-4 rounded-2xl bg-white border border-gray-50 shadow-sm">
                        ${renderAvatar(avatar, 36)}
                        <div class="flex-1 min-w-0">
                            <span class="text-sm font-medium text-gray-800">${name}</span>
                            ${subtitle ? `<p class="text-xs text-gray-400 truncate mt-0.5">${subtitle}</p>` : ''}
                        </div>
                        <button data-user-id="${c.id}" data-nickname="${escapeHtml(c.nickname || c.username)}" data-avatar="${escapeHtml(c.avatar || '🐰')}" class="shrink-0 w-9 h-9 rounded-full bg-emerald-50 text-emerald-400 flex items-center justify-center hover:bg-emerald-100 active:scale-95 transition-all acquaintance-chat-btn" title="发消息">
                            <i data-lucide="message-circle" class="w-4 h-4"></i>
                        </button>
                    </div>`;
                }).join('');

                contactsListContent.querySelectorAll('.acquaintance-chat-btn').forEach(btn => {
                    btn.addEventListener('click', async (e) => {
                        e.stopPropagation();
                        const userId = parseInt(btn.dataset.userId);
                        const nickname = btn.dataset.nickname;
                        const avatar = btn.dataset.avatar;
                        btn.disabled = true;
                        try {
                            window.closeContactsModal();
                            await window.openChatWithUser(userId, nickname, avatar);
                        } catch (err) {
                            showToast(err.message || '无法发起聊天');
                        } finally {
                            btn.disabled = false;
                        }
                    });
                });
            }
            if (typeof lucide !== 'undefined') lucide.createIcons();
        } catch (e) {
            console.error('contacts error:', e);
            contactsListContent.innerHTML = `<p class="text-xs text-gray-400 text-center py-20">加载失败，请重试<br><span class="text-[10px] text-gray-300 mt-1">${escapeHtml(e.message || '未知错误')}</span></p>`;
        }
    };

    window.closeContactsModal = function() {
        const contactsModalOverlay = document.getElementById('contactsModalOverlay');
        contactsModalOverlay.classList.add('opacity-0', 'pointer-events-none');
        contactsModalOverlay.classList.remove('opacity-100');
    };

    window.fetchUnreadCount = async function() {
        if (!EchoAPI.getToken()) return;
        try {
            const data = await EchoAPI.fetchUnreadNotificationCount();
            window.updateNotificationBadge(data.unread_count || 0);
        } catch (e) {
            // 静默失败
        }
    };

    window.updateNotificationBadge = function(count) {
        const notificationBadge = document.getElementById('notificationBadge');
        const btnNotificationBell = document.getElementById('btnNotificationBell');
        if (count > 0) {
            notificationBadge.textContent = count > 99 ? '99+' : count;
            notificationBadge.classList.remove('hidden', 'badge-pulse');
            void notificationBadge.offsetWidth;
            notificationBadge.classList.add('badge-pulse');
            btnNotificationBell.classList.remove('text-gray-400');
            btnNotificationBell.classList.add('text-amber-500');
            const msgTabBadge = document.getElementById('msgTabNotifBadge');
            if (msgTabBadge) {
                msgTabBadge.textContent = count > 99 ? '99+' : count;
                msgTabBadge.classList.remove('hidden');
            }
        } else {
            notificationBadge.classList.add('hidden');
            notificationBadge.classList.remove('badge-pulse');
            btnNotificationBell.classList.add('text-gray-400');
            btnNotificationBell.classList.remove('text-amber-500');
            const msgTabBadge = document.getElementById('msgTabNotifBadge');
            if (msgTabBadge) msgTabBadge.classList.add('hidden');
        }
    };

    window.openNotificationCenter = async function() {
        const notificationOverlay = document.getElementById('notificationCenterOverlay');
        if (!EchoAPI.getToken()) {
            window.EchoAuth && window.EchoAuth.showLogin();
            return;
        }
        notificationOverlay.classList.remove('opacity-0', 'pointer-events-none');
        notificationOverlay.classList.add('opacity-100');
        window.notificationPage = 1;
        await window.loadNotificationList();
        lucide.createIcons();
    };

    window.closeNotificationCenter = function() {
        const notificationOverlay = document.getElementById('notificationCenterOverlay');
        notificationOverlay.classList.add('opacity-0', 'pointer-events-none');
        notificationOverlay.classList.remove('opacity-100');
    };

    window.loadNotificationList = async function() {
        const notificationList = document.getElementById('notificationList');
        const notificationEmpty = document.getElementById('notificationEmpty');
        notificationList.innerHTML = '<div class="flex items-center justify-center py-20"><span class="loader w-6 h-6 border-2 border-emerald-400 border-t-transparent rounded-full inline-block"></span></div>';
        notificationEmpty.classList.add('hidden');
        try {
            const data = await EchoAPI.fetchNotifications({ page: window.notificationPage, page_size: window.notificationPageSize });
            const items = data.items || [];
            if (items.length === 0) {
                notificationList.innerHTML = '';
                notificationEmpty.classList.remove('hidden');
            } else {
                notificationEmpty.classList.add('hidden');
                window.renderNotificationItems(items);
            }
        } catch (e) {
            notificationList.innerHTML = '<div class="flex items-center justify-center py-20 text-gray-400 text-sm">加载失败，请稍后再试</div>';
        }
    };

    window.renderNotificationItems = function(items) {
        const notificationList = document.getElementById('notificationList');
        const notificationEmpty = document.getElementById('notificationEmpty');
        notificationList.innerHTML = items.map(n => {
            const isUnread = !n.is_read;
            const bgClass = isUnread ? 'bg-emerald-50/50 border-emerald-100/50' : 'bg-white border-gray-50';
            const timeStr = formatDate(n.created_at);
            const actorHtml = n.actor
                ? `${renderAvatar(n.actor.avatar, 22)}`
                : '<span class="w-9 h-9 rounded-full bg-gradient-to-br from-purple-100 to-indigo-100 flex items-center justify-center text-lg shrink-0 shadow-sm select-none">👻</span>';
            const actorName = n.actor ? escapeHtml(n.actor.nickname || '') : '匿名小伙伴';
            const clickAction = window.getNotificationClickAction(n);
            return `
            <div class="flex items-start gap-3 p-3.5 rounded-2xl border ${bgClass} cursor-pointer hover:shadow-sm transition-all notif-item ${clickAction ? 'clickable-notif' : ''}"
                 data-notif-id="${n.id}" data-is-read="${n.is_read ? '1' : '0'}">
                ${actorHtml}
                <div class="flex-1 min-w-0" data-click="${clickAction || ''}">
                    <div class="flex items-center gap-2 mb-0.5">
                        <span class="text-[13px] font-medium text-gray-800">${escapeHtml(n.title || '')}</span>
                        ${isUnread ? '<span class="w-2 h-2 rounded-full bg-emerald-400 shrink-0"></span>' : ''}
                    </div>
                    <p class="text-[12px] text-gray-500 leading-relaxed line-clamp-2">${escapeHtml(n.content || '')}</p>
                    <span class="text-[10px] text-gray-300 mt-1 block">${timeStr}</span>
                </div>
                <button class="notif-delete-btn shrink-0 text-gray-300 hover:text-red-400 active:scale-95 transition-all p-1" data-notif-id="${n.id}" title="删除">
                    <i data-lucide="trash-2" class="w-3.5 h-3.5"></i>
                </button>
            </div>`;
        }).join('');

        // 绑定通知点击（跳转 + 标记已读）
        notificationList.querySelectorAll('.clickable-notif [data-click]').forEach(el => {
            el.addEventListener('click', async (e) => {
                e.stopPropagation();
                const notifEl = el.closest('.notif-item');
                const notifId = parseInt(notifEl.dataset.notifId);
                const clickData = el.dataset.click;
                // 标记已读
                try {
                    await EchoAPI.markNotificationRead(notifId);
                    notifEl.dataset.isRead = '1';
                    notifEl.querySelector('.w-2.h-2')?.remove();
                    notifEl.classList.remove('bg-emerald-50/50', 'border-emerald-100/50');
                    notifEl.classList.add('bg-white', 'border-gray-50');
                    await window.fetchUnreadCount();
                } catch (e) { /* ignore */ }
                // 跳转
                window.handleNotificationClick(clickData);
            });
        });

        // 绑定删除按钮
        notificationList.querySelectorAll('.notif-delete-btn').forEach(btn => {
            btn.addEventListener('click', async (e) => {
                e.stopPropagation();
                const notifId = parseInt(btn.dataset.notifId);
                try {
                    await EchoAPI.deleteNotification(notifId);
                    btn.closest('.notif-item')?.remove();
                    await window.fetchUnreadCount();
                    // 检查是否为空
                    if (!notificationList.querySelector('.notif-item')) {
                        notificationEmpty.classList.remove('hidden');
                    }
                } catch (e) { /* ignore */ }
            });
        });

        lucide.createIcons();
    };

    window.getNotificationClickAction = function(n) {
        // 返回点击跳转标识：格式 "type:entity_id"
        if (n.entity_type === 'conversation') {
            return `conv:${n.entity_id}`;
        }
        if (n.entity_type === 'greet') {
            return `greet:${n.entity_id}`;
        }
        if (n.type === 'follow' && n.entity_type === 'user' && n.actor) {
            return `user:${n.actor.id}`;
        }
        if ((n.type === 'public_diary_like' || n.type === 'public_diary_comment') && n.entity_type === 'diary') {
            return `diary:${n.entity_id}`;
        }
        if ((n.type === 'treehole_hug' || n.type === 'treehole_reply') && n.entity_type === 'treehole') {
            return `treehole:${n.entity_id}`;
        }
        return '';
    };

    window.handleNotificationClick = function(clickData) {
        if (!clickData) return;
        const [type, id] = clickData.split(':');
        if (type === 'conv') {
            window.closeNotificationCenter();
            window.openMessageCenter();
        } else if (type === 'greet') {
            openGreetCenter('received');
        } else if (type === 'user' && id) {
            openAuthorProfile(parseInt(id));
        } else if (type === 'diary' && id) {
            openDiscDetail(parseInt(id));
        } else if (type === 'treehole' && id) {
            switchTab('treehole');
        }
        window.closeNotificationCenter();
    };

    window.refreshMessageTabBadges = function() {
        window.fetchMsgUnreadCount();
        window.fetchUnreadCount();
    };

    // === Event listeners ===

    document.getElementById('btnCloseMsgCenter').addEventListener('click', window.closeMessageCenter);
    document.getElementById('messageCenterOverlay').addEventListener('click', (e) => { if (e.target === document.getElementById('messageCenterOverlay')) window.closeMessageCenter(); });

    document.getElementById('btnBackToConvList').addEventListener('click', window.backToConvList);

    document.getElementById('btnChatSend').addEventListener('click', async () => {
        const chatInput = document.getElementById('chatInput');
        const content = chatInput.value.trim();
        if (!content || !window.currentConvId) return;
        document.getElementById('btnChatSend').disabled = true;
        try {
            await EchoAPI.sendMessage(window.currentConvId, { content });
            chatInput.value = '';
            await window.loadChatMessages();
        } catch (e) {
            if (e.message && e.message.includes('403')) {
                showToast('由于安全设置，暂时不能发送消息');
            } else {
                showToast(e.message || '发送失败');
            }
        } finally {
            document.getElementById('btnChatSend').disabled = false;
        }
    });

    document.getElementById('chatInput').addEventListener('keydown', (e) => {
        if (e.key === 'Enter') document.getElementById('btnChatSend').click();
    });

    document.getElementById('btnCloseContactsModal').addEventListener('click', window.closeContactsModal);
    document.getElementById('contactsModalOverlay').addEventListener('click', (e) => { if (e.target === document.getElementById('contactsModalOverlay')) window.closeContactsModal(); });

    document.getElementById('btnNotificationBell').addEventListener('click', () => switchTab('messages'));
    document.getElementById('btnCloseNotificationCenter').addEventListener('click', window.closeNotificationCenter);
    document.getElementById('notificationCenterOverlay').addEventListener('click', (e) => {
        if (e.target === document.getElementById('notificationCenterOverlay')) window.closeNotificationCenter();
    });
    document.getElementById('btnMarkAllRead').addEventListener('click', async () => {
        try {
            await EchoAPI.markAllNotificationsRead();
            window.updateNotificationBadge(0);
            await window.loadNotificationList();
        } catch (e) { /* ignore */ }
    });

    // === 消息 Tab 入口点击 ===
    document.getElementById('msgEntryChat').addEventListener('click', () => {
        if (!EchoAPI.getToken()) { showAuth('login'); return; }
        window.openMessageCenter();
    });
    document.getElementById('msgEntryGreet').addEventListener('click', () => {
        if (!EchoAPI.getToken()) { showAuth('login'); return; }
        window.openGreetCenter('received');
    });
    document.getElementById('msgEntryNotif').addEventListener('click', () => {
        if (!EchoAPI.getToken()) { showAuth('login'); return; }
        window.openNotificationCenter();
    });

    // === 刷新消息 Tab 角标 ===
    window.refreshMessageTabBadges = function() {
        window.fetchMsgUnreadCount();
        window.fetchUnreadCount();
        window.fetchMyGreetPendingCount();
    };

})();

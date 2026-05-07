/**
 * Modals View - 时光胶囊 / 联系人 / 通知 / 认证 / 举报弹窗
 */
(function() {
    'use strict';

    // ========== 时光胶囊 ==========

    const capsuleOverlay      = document.getElementById('capsuleOverlay');
    const capsuleDate         = document.getElementById('capsuleDate');
    const capsuleContent      = document.getElementById('capsuleContent');
    const capsuleMoodBtns     = document.querySelectorAll('.capsule-mood-btn');
    const btnCloseCapsule     = document.getElementById('btnCloseCapsule');
    const btnSaveCapsule      = document.getElementById('btnSaveCapsule');
    const capsuleImageInput   = document.getElementById('capsuleImageInput');
    const btnCapsulePickImage = document.getElementById('btnCapsulePickImage');
    const capsuleUploadStatus = document.getElementById('capsuleUploadStatus');
    const capsuleImagePreview = document.getElementById('capsuleImagePreview');
    const capsuleImageThumbnails = document.getElementById('capsuleImageThumbnails');
    const planeOverlay        = document.getElementById('planeOverlay');
    const planeIcon          = document.getElementById('planeIcon');
    const planeToast         = document.getElementById('planeToast');
    let capsuleImageUrls = [];

    window.openCapsuleModal = function() {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        const minDate = `${tomorrow.getFullYear()}-${String(tomorrow.getMonth() + 1).padStart(2, '0')}-${String(tomorrow.getDate()).padStart(2, '0')}`;
        capsuleDate.min = minDate;
        capsuleDate.value = minDate;
        capsuleContent.value = '';
        capsuleImageUrls = [];
        capsuleImageThumbnails.innerHTML = '';
        capsuleImagePreview.classList.add('hidden');
        capsuleUploadStatus.textContent = '';
        capsuleUploadStatus.className = 'text-[10px] text-gray-300 hidden';
        btnCapsulePickImage.innerHTML = '<i data-lucide="image" class="w-4 h-4"></i> 添加图片';
        btnCapsulePickImage.disabled = false;
        capsuleMoodBtns.forEach(b => b.classList.remove('active'));
        capsuleMoodBtns[0].classList.add('active');
        btnSaveCapsule.disabled = false;
        btnSaveCapsule.innerHTML = '<i data-lucide="lock" class="w-5 h-5"></i> 封存胶囊';
        capsuleOverlay.classList.remove('opacity-0', 'pointer-events-none');
        capsuleOverlay.classList.add('opacity-100', 'pointer-events-auto');
        document.body.style.overflow = 'hidden';
        lucide.createIcons();
    };

    window.closeCapsuleModal = function() {
        capsuleOverlay.classList.add('opacity-0', 'pointer-events-none');
        capsuleOverlay.classList.remove('opacity-100', 'pointer-events-auto');
        document.body.style.overflow = '';
    };

    btnCloseCapsule.addEventListener('click', window.closeCapsuleModal);
    capsuleOverlay.addEventListener('click', (e) => { if (e.target === capsuleOverlay) window.closeCapsuleModal(); });

    capsuleMoodBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            capsuleMoodBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
        });
    });

    function renderCapsuleThumbnails() {
        capsuleImageThumbnails.innerHTML = capsuleImageUrls.map((url, i) => `
            <div class="relative inline-block">
                <img src="${url}" class="h-20 rounded-xl object-cover shadow-sm border border-gray-100" alt="">
                <button class="capsule-img-remove-btn absolute -top-1.5 -right-1.5 w-5 h-5 rounded-full bg-gray-700/70 text-white text-[10px] flex items-center justify-center hover:bg-gray-800/80 active:scale-95 transition-all" data-index="${i}">
                    <i data-lucide="x" class="w-3 h-3"></i>
                </button>
            </div>
        `).join('');
        if (capsuleImageUrls.length > 0) {
            capsuleImagePreview.classList.remove('hidden');
            btnCapsulePickImage.innerHTML = '<i data-lucide="image" class="w-4 h-4"></i> 继续添加';
        } else {
            capsuleImagePreview.classList.add('hidden');
            btnCapsulePickImage.innerHTML = '<i data-lucide="image" class="w-4 h-4"></i> 添加图片';
        }
        capsuleImageThumbnails.querySelectorAll('.capsule-img-remove-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                capsuleImageUrls.splice(parseInt(btn.dataset.index), 1);
                renderCapsuleThumbnails();
                lucide.createIcons();
            });
        });
        lucide.createIcons();
    }

    btnCapsulePickImage.addEventListener('click', () => capsuleImageInput.click());
    capsuleImageInput.addEventListener('change', async () => {
        const file = capsuleImageInput.files[0];
        if (!file) return;
        capsuleUploadStatus.textContent = '压缩上传中...';
        capsuleUploadStatus.classList.remove('hidden');
        btnCapsulePickImage.disabled = true;
        try {
            const blob = await compressImage(file);
            const data = await EchoAPI.uploadImage(blob);
            capsuleImageUrls.push(data.url);
            renderCapsuleThumbnails();
            capsuleUploadStatus.textContent = '已上传';
            capsuleUploadStatus.classList.add('text-emerald-500');
        } catch (e) {
            console.error('图片上传失败:', e);
            capsuleUploadStatus.textContent = '上传失败';
            capsuleUploadStatus.classList.add('text-red-400');
        } finally {
            btnCapsulePickImage.disabled = false;
            capsuleImageInput.value = '';
            setTimeout(() => {
                capsuleUploadStatus.classList.add('hidden');
                capsuleUploadStatus.className = 'text-[10px] text-gray-300 hidden';
            }, 2000);
        }
    });

    btnSaveCapsule.addEventListener('click', async () => {
        const content = capsuleContent.value.trim();
        if (!content) { alert('先写点什么吧～'); return; }
        const unlockDate = capsuleDate.value;
        if (!unlockDate) { alert('请选择一个拆封日期～'); return; }
        const mood = document.querySelector('.capsule-mood-btn.active')?.dataset.mood || '😊';

        btnSaveCapsule.disabled = true;
        btnSaveCapsule.innerHTML = '<span class="loader w-5 h-5 border-2 border-white border-t-transparent rounded-full inline-block"></span> 封存中...';
        try {
            await EchoAPI.saveDiary({
                mood, content,
                ai_summary: '', ai_message: '', tags: '',
                is_public: false,
                image_url: capsuleImageUrls[0] || '',
                image_urls: capsuleImageUrls,
                unlock_date: unlockDate,
            });
            planeIcon.style.animation = 'none';
            void planeIcon.offsetWidth;
            planeIcon.style.animation = 'planeTakeoff 1.5s ease-out forwards';
            planeToast.textContent = '🔒 胶囊已封存，将在未来准时抵达';
            planeOverlay.classList.remove('opacity-0', 'pointer-events-none');
            planeOverlay.classList.add('opacity-100');
            btnSaveCapsule.disabled = false;
            btnSaveCapsule.innerHTML = '<i data-lucide="lock" class="w-5 h-5"></i> 封存胶囊';
            lucide.createIcons();
            await new Promise(r => setTimeout(r, 1600));
            planeOverlay.classList.add('opacity-0', 'pointer-events-none');
            planeOverlay.classList.remove('opacity-100');
            window.closeCapsuleModal();
            // 刷新当前视图
            if (typeof loadCapsules === 'function') await loadCapsules();
            if (typeof loadDiaries === 'function') await loadDiaries();
        } catch (e) {
            console.error('保存胶囊失败:', e);
            alert('保存失败，请稍后再试～');
            btnSaveCapsule.disabled = false;
            btnSaveCapsule.innerHTML = '<i data-lucide="lock" class="w-5 h-5"></i> 封存胶囊';
            lucide.createIcons();
        }
    });

    // ========== 联系人 ==========

    const contactsModalOverlay = document.getElementById('contactsModalOverlay');
    const contactsListContent = document.getElementById('contactsListContent');

    window.openAcquaintancesModal = async function() {
        if (!EchoAPI.getToken()) { window.EchoAuth && window.EchoAuth.showLogin(); return; }
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
                            window.showToast && window.showToast(err.message || '无法发起聊天');
                        } finally {
                            btn.disabled = false;
                        }
                    });
                });
            }
            lucide.createIcons();
        } catch (e) {
            console.error('contacts error:', e);
            contactsListContent.innerHTML = `<p class="text-xs text-gray-400 text-center py-20">加载失败，请重试</p>`;
        }
    };

    window.closeContactsModal = function() {
        contactsModalOverlay.classList.add('opacity-0', 'pointer-events-none');
        contactsModalOverlay.classList.remove('opacity-100');
    };

    document.getElementById('btnCloseContactsModal').addEventListener('click', window.closeContactsModal);
    contactsModalOverlay.addEventListener('click', (e) => { if (e.target === contactsModalOverlay) window.closeContactsModal(); });

    // ========== 通知中心 ==========

    const notificationOverlay = document.getElementById('notificationCenterOverlay');
    const notificationList = document.getElementById('notificationList');
    const notificationEmpty = document.getElementById('notificationEmpty');
    const notificationBadge = document.getElementById('notificationBadge');
    const btnNotificationBell = document.getElementById('btnNotificationBell');
    const btnCloseNotificationCenter = document.getElementById('btnCloseNotificationCenter');
    const btnMarkAllRead = document.getElementById('btnMarkAllRead');

    let notificationPage = 1;
    const notificationPageSize = 20;

    window.fetchUnreadCount = async function() {
        if (!EchoAPI.getToken()) return;
        try {
            const data = await EchoAPI.fetchUnreadNotificationCount();
            window.updateNotificationBadge(data.unread_count || 0);
        } catch (e) { /* 静默失败 */ }
    };

    window.updateNotificationBadge = function(count) {
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
        if (!EchoAPI.getToken()) { window.EchoAuth && window.EchoAuth.showLogin(); return; }
        notificationOverlay.classList.remove('opacity-0', 'pointer-events-none');
        notificationOverlay.classList.add('opacity-100');
        notificationPage = 1;
        await window.loadNotificationList();
        lucide.createIcons();
    };

    window.closeNotificationCenter = function() {
        notificationOverlay.classList.add('opacity-0', 'pointer-events-none');
        notificationOverlay.classList.remove('opacity-100');
    };

    window.loadNotificationList = async function() {
        notificationList.innerHTML = '<div class="flex items-center justify-center py-20"><span class="loader w-6 h-6 border-2 border-emerald-400 border-t-transparent rounded-full inline-block"></span></div>';
        notificationEmpty.classList.add('hidden');
        try {
            const data = await EchoAPI.fetchNotifications({ page: notificationPage, page_size: notificationPageSize });
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
        notificationList.innerHTML = items.map(n => {
            const isUnread = !n.is_read;
            const bgClass = isUnread ? 'bg-emerald-50/50 border-emerald-100/50' : 'bg-white border-gray-50';
            const timeStr = formatDate(n.created_at);
            const actorHtml = n.actor
                ? `${renderAvatar(n.actor.avatar, 22)}`
                : '<span class="w-9 h-9 rounded-full bg-gradient-to-br from-purple-100 to-indigo-100 flex items-center justify-center text-lg shrink-0 shadow-sm select-none">👻</span>';
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

        notificationList.querySelectorAll('.clickable-notif [data-click]').forEach(el => {
            el.addEventListener('click', async (e) => {
                e.stopPropagation();
                const notifEl = el.closest('.notif-item');
                const notifId = parseInt(notifEl.dataset.notifId);
                const clickData = el.dataset.click;
                try {
                    await EchoAPI.markNotificationRead(notifId);
                    notifEl.classList.remove('bg-emerald-50/50', 'border-emerald-100/50');
                    notifEl.classList.add('bg-white', 'border-gray-50');
                    notifEl.querySelector('.w-2\\.h-2')?.remove();
                    await window.fetchUnreadCount();
                } catch (e) { /* ignore */ }
                window.handleNotificationClick && window.handleNotificationClick(clickData);
            });
        });

        notificationList.querySelectorAll('.notif-delete-btn').forEach(btn => {
            btn.addEventListener('click', async (e) => {
                e.stopPropagation();
                const notifId = parseInt(btn.dataset.notifId);
                try {
                    await EchoAPI.deleteNotification(notifId);
                    btn.closest('.notif-item')?.remove();
                    await window.fetchUnreadCount();
                    if (!notificationList.querySelector('.notif-item')) notificationEmpty.classList.remove('hidden');
                } catch (e) { /* ignore */ }
            });
        });

        lucide.createIcons();
    };

    window.getNotificationClickAction = function(n) {
        if (n.entity_type === 'conversation') return `conv:${n.entity_id}`;
        if (n.entity_type === 'greet') return `greet:${n.entity_id}`;
        if (n.type === 'follow' && n.entity_type === 'user' && n.actor) return `user:${n.actor.id}`;
        if ((n.type === 'public_diary_like' || n.type === 'public_diary_comment') && n.entity_type === 'diary') return `diary:${n.entity_id}`;
        if ((n.type === 'treehole_hug' || n.type === 'treehole_reply') && n.entity_type === 'treehole') return `treehole:${n.entity_id}`;
        return '';
    };

    window.handleNotificationClick = function(clickData) {
        if (!clickData) return;
        const [type, id] = clickData.split(':');
        if (type === 'conv') { window.openMessageCenter && window.openMessageCenter(); }
        else if (type === 'greet') { window.openGreetCenter && window.openGreetCenter('received'); }
        else if (type === 'user' && id) { window.openAuthorProfile && window.openAuthorProfile(parseInt(id)); }
        else if (type === 'diary' && id) { window.openDiscDetail && window.openDiscDetail(parseInt(id)); }
        else if (type === 'treehole' && id) { window.switchTab && window.switchTab('treehole'); }
        window.closeNotificationCenter && window.closeNotificationCenter();
    };

    btnNotificationBell.addEventListener('click', () => { if (window.switchTab) window.switchTab('messages'); });
    btnCloseNotificationCenter.addEventListener('click', window.closeNotificationCenter);
    notificationOverlay.addEventListener('click', (e) => { if (e.target === notificationOverlay) window.closeNotificationCenter(); });
    btnMarkAllRead.addEventListener('click', async () => {
        try {
            await EchoAPI.markAllNotificationsRead();
            window.updateNotificationBadge(0);
            await window.loadNotificationList();
        } catch (e) { /* ignore */ }
    });

    // ========== 认证 ==========

    const authOverlay = document.getElementById('authOverlay');

    window.EchoAuth = {
        showLogin() { window.showAuth && window.showAuth('login'); },
        showRegister() { window.showAuth && window.showAuth('register'); },
        isLoggedIn() { return !!EchoAPI.getToken(); },
    };

    window.showAuth = function(tab) {
        if (EchoAPI.getToken()) return;
        authOverlay.classList.remove('opacity-0', 'pointer-events-none');
        authOverlay.classList.add('opacity-100');
        window.switchAuthTab(tab);
    };

    window.hideAuth = function() {
        authOverlay.classList.add('opacity-0', 'pointer-events-none');
        authOverlay.classList.remove('opacity-100');
    };

    window.switchAuthTab = function(tab) {
        const isLogin = tab === 'login';
        document.getElementById('authTabLogin').className = isLogin
            ? 'flex-1 py-2.5 rounded-full text-sm font-medium bg-white text-gray-800 shadow-sm transition-all'
            : 'flex-1 py-2.5 rounded-full text-sm font-medium text-gray-400 transition-all';
        document.getElementById('authTabRegister').className = !isLogin
            ? 'flex-1 py-2.5 rounded-full text-sm font-medium bg-white text-gray-800 shadow-sm transition-all'
            : 'flex-1 py-2.5 rounded-full text-sm font-medium text-gray-400 transition-all';
        document.getElementById('authFormLogin').classList.toggle('hidden', !isLogin);
        document.getElementById('authFormRegister').classList.toggle('hidden', isLogin);
        document.getElementById('loginError').classList.add('hidden');
        document.getElementById('regError').classList.add('hidden');
    };

    document.getElementById('authTabLogin').addEventListener('click', () => window.switchAuthTab('login'));
    document.getElementById('authTabRegister').addEventListener('click', () => window.switchAuthTab('register'));
    document.getElementById('switchToRegister').addEventListener('click', (e) => { e.preventDefault(); window.switchAuthTab('register'); });
    document.getElementById('switchToLogin').addEventListener('click', (e) => { e.preventDefault(); window.switchAuthTab('login'); });
    document.getElementById('btnCloseAuth').addEventListener('click', window.hideAuth);

    document.getElementById('btnLogin').addEventListener('click', async function() {
        const btn = this;
        const username = document.getElementById('loginUsername').value.trim();
        const password = document.getElementById('loginPassword').value;
        const errEl = document.getElementById('loginError');
        errEl.classList.add('hidden');
        if (!username || !password) { errEl.textContent = '请填写用户名和密码'; errEl.classList.remove('hidden'); return; }
        btn.disabled = true;
        btn.textContent = '登录中...';
        try {
            const data = await EchoAPI.login(username, password);
            window.hideAuth();
            await window.onLoginSuccess(data.user);
        } catch (e) {
            errEl.textContent = e.message || '登录失败';
            errEl.classList.remove('hidden');
        } finally {
            btn.disabled = false;
            btn.textContent = '登录';
        }
    });

    document.getElementById('btnRegister').addEventListener('click', async function() {
        const btn = this;
        const username = document.getElementById('regUsername').value.trim();
        const password = document.getElementById('regPassword').value;
        const email = document.getElementById('regEmail').value.trim();
        const errEl = document.getElementById('regError');
        errEl.classList.add('hidden');
        if (!username || !password) { errEl.textContent = '请填写用户名和密码'; errEl.classList.remove('hidden'); return; }
        if (username.length < 2) { errEl.textContent = '用户名至少 2 个字符'; errEl.classList.remove('hidden'); return; }
        if (password.length < 6) { errEl.textContent = '密码至少 6 个字符'; errEl.classList.remove('hidden'); return; }
        btn.disabled = true;
        btn.textContent = '注册中...';
        try {
            const data = await EchoAPI.register(username, password, email);
            window.hideAuth();
            await window.onLoginSuccess(data.user);
        } catch (e) {
            errEl.textContent = e.message || '注册失败';
            errEl.classList.remove('hidden');
        } finally {
            btn.disabled = false;
            btn.textContent = '注册';
        }
    });

    document.getElementById('loginPassword').addEventListener('keydown', (e) => { if (e.key === 'Enter') document.getElementById('btnLogin').click(); });
    document.getElementById('regPassword').addEventListener('keydown', (e) => { if (e.key === 'Enter') document.getElementById('btnRegister').click(); });

    // 登录弹窗远程连接
    const btnToggleServerConn = document.getElementById('btnToggleServerConn');
    const serverConnPanel = document.getElementById('serverConnPanel');
    const serverConnArrow = document.getElementById('serverConnArrow');
    if (btnToggleServerConn) {
        btnToggleServerConn.addEventListener('click', () => {
            const hidden = serverConnPanel.classList.toggle('hidden');
            if (serverConnArrow) serverConnArrow.style.transform = hidden ? '' : 'rotate(180deg)';
        });
    }
    const savedUrl2 = EchoAPI.getServerUrl();
    const authServerStatus = document.getElementById('authServerUrlStatus');
    const authServerInput = document.getElementById('authServerUrlInput');
    if (savedUrl2 && authServerStatus) { authServerStatus.textContent = '已连接: ' + savedUrl2; authServerStatus.className = 'text-[10px] mt-2 text-blue-400'; }
    if (authServerInput) authServerInput.value = savedUrl2 || '';
    document.getElementById('authBtnConnectServer').addEventListener('click', () => {
        const url = (document.getElementById('authServerUrlInput').value || '').trim();
        EchoAPI.setServerUrl(url);
        const status = document.getElementById('authServerUrlStatus');
        if (url) {
            if (status) { status.textContent = '已连接: ' + url; status.className = 'text-[10px] mt-2 text-blue-400'; }
            window.showToast && window.showToast('连接成功，页面将重新加载', 'success');
            setTimeout(() => location.reload(), 800);
        } else {
            if (status) { status.textContent = '未设置（使用本地服务）'; status.className = 'text-[10px] mt-2 text-gray-400'; }
            window.showToast && window.showToast('已切换回本地服务', 'success');
            setTimeout(() => location.reload(), 800);
        }
    });

    // 密码显示/隐藏
    function setupPwdToggle(btnId, inputId) {
        const btn = document.getElementById(btnId);
        const input = document.getElementById(inputId);
        if (!btn || !input) return;
        btn.addEventListener('click', () => {
            const isPwd = input.type === 'password';
            input.type = isPwd ? 'text' : 'password';
            const icon = btn.querySelector('i');
            if (icon) icon.setAttribute('data-lucide', isPwd ? 'eye-off' : 'eye');
            if (typeof lucide !== 'undefined') lucide.createIcons();
        });
    }
    setupPwdToggle('btnToggleLoginPwd', 'loginPassword');
    setupPwdToggle('btnToggleRegPwd', 'regPassword');

    // ========== 举报弹窗 ==========

    const reportModalOverlay = document.getElementById('reportModalOverlay');
    const reportTargetInfo = document.getElementById('reportTargetInfo');
    const reportReason = document.getElementById('reportReason');
    const reportDescription = document.getElementById('reportDescription');
    const reportError = document.getElementById('reportError');
    const reportCharCount = document.getElementById('reportCharCount');
    let reportTargetType = '';
    let reportTargetId = 0;

    window.openReportModal = function(type, id, info) {
        if (!EchoAPI.getToken()) { window.showAuth && window.showAuth('login'); return; }
        reportTargetType = type;
        reportTargetId = id;
        reportTargetInfo.textContent = info || '';
        reportReason.value = '';
        reportDescription.value = '';
        reportError.classList.add('hidden');
        reportCharCount.textContent = '0';
        document.querySelectorAll('#reportReasonGrid .report-reason-btn').forEach(b => {
            b.classList.remove('bg-amber-100', 'text-amber-600');
            b.classList.add('bg-gray-50', 'text-gray-500');
        });
        reportModalOverlay.classList.remove('opacity-0', 'pointer-events-none');
        reportModalOverlay.classList.add('opacity-100');
    };

    window.closeReportModal = function() {
        reportModalOverlay.classList.add('opacity-0', 'pointer-events-none');
        reportModalOverlay.classList.remove('opacity-100');
    };

    document.getElementById('btnCloseReportModal').addEventListener('click', window.closeReportModal);
    reportModalOverlay.addEventListener('click', (e) => { if (e.target === reportModalOverlay) window.closeReportModal(); });

    document.querySelectorAll('#reportReasonGrid .report-reason-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('#reportReasonGrid .report-reason-btn').forEach(b => {
                b.classList.remove('bg-amber-100', 'text-amber-600');
                b.classList.add('bg-gray-50', 'text-gray-500');
            });
            btn.classList.remove('bg-gray-50', 'text-gray-500');
            btn.classList.add('bg-amber-100', 'text-amber-600');
            reportReason.value = btn.dataset.reason;
        });
    });

    reportDescription.addEventListener('input', () => {
        reportCharCount.textContent = reportDescription.value.length;
    });

    document.getElementById('btnSubmitReport').addEventListener('click', async () => {
        if (!reportReason.value) {
            reportError.textContent = '请选择举报原因';
            reportError.classList.remove('hidden');
            return;
        }
        reportError.classList.add('hidden');
        document.getElementById('btnSubmitReport').disabled = true;
        try {
            const result = await EchoAPI.createReport({
                target_type: reportTargetType,
                target_id: reportTargetId,
                reason: reportReason.value,
                description: reportDescription.value.trim(),
            });
            if (result.ok) {
                window.showToast && window.showToast('举报已提交');
                window.closeReportModal();
            }
        } catch (e) {
            reportError.textContent = e.message || '提交失败';
            reportError.classList.remove('hidden');
        } finally {
            document.getElementById('btnSubmitReport').disabled = false;
        }
    });

    // ========== 设置弹窗 ==========
    const settingsOverlay = document.getElementById('settingsOverlay');
    const changePwdOverlay = document.getElementById('changePwdOverlay');

    window.openSettings = function () {
        settingsOverlay.style.visibility = 'visible';
        settingsOverlay.classList.remove('opacity-0', 'pointer-events-none');
        settingsOverlay.classList.add('opacity-100');
        // 同步当前连接状态
        const savedUrl = EchoAPI.getServerUrl();
        const status = document.getElementById('settingsServerUrlStatus');
        const input = document.getElementById('settingsServerUrlInput');
        if (input) input.value = savedUrl || '';
        if (status) {
            if (savedUrl) {
                status.textContent = '已连接: ' + savedUrl;
                status.className = 'text-[10px] mt-2 text-blue-400';
            } else {
                status.textContent = '未设置（使用本地服务）';
                status.className = 'text-[10px] mt-2 text-gray-400';
            }
        }
        lucide.createIcons();
    };

    document.getElementById('btnMyProfile').addEventListener('click', window.openSettings);
    document.getElementById('btnCloseSettings').addEventListener('click', () => {
        settingsOverlay.style.visibility = 'hidden';
        settingsOverlay.classList.add('opacity-0', 'pointer-events-none');
        settingsOverlay.classList.remove('opacity-100');
    });
    settingsOverlay.addEventListener('click', (e) => {
        if (e.target === settingsOverlay) {
            settingsOverlay.style.visibility = 'hidden';
            settingsOverlay.classList.add('opacity-0', 'pointer-events-none');
            settingsOverlay.classList.remove('opacity-100');
        }
    });

    // 设置 - 连接服务器
    document.getElementById('settingsBtnConnectServer').addEventListener('click', () => {
        const url = (document.getElementById('settingsServerUrlInput').value || '').trim();
        EchoAPI.setServerUrl(url);
        const status = document.getElementById('settingsServerUrlStatus');
        if (url) {
            if (status) { status.textContent = '已连接: ' + url; status.className = 'text-[10px] mt-2 text-blue-400'; }
            window.showToast && window.showToast('连接成功，页面将重新加载', 'success');
            setTimeout(() => location.reload(), 800);
        } else {
            if (status) { status.textContent = '未设置（使用本地服务）'; status.className = 'text-[10px] mt-2 text-gray-400'; }
            window.showToast && window.showToast('已切换回本地服务', 'success');
            setTimeout(() => location.reload(), 800);
        }
    });

    // 设置 - 退出登录
    document.getElementById('settingsBtnLogout').addEventListener('click', () => {
        if (!confirm('确定要退出登录吗？')) return;
        EchoAPI.logout();
    });

    // 设置 - 修改密码
    document.getElementById('btnChangePassword').addEventListener('click', () => {
        document.getElementById('curPwdInput').value = '';
        document.getElementById('newPwdInput').value = '';
        document.getElementById('confirmPwdInput').value = '';
        document.getElementById('changePwdError').classList.add('hidden');
        changePwdOverlay.style.visibility = 'visible';
        changePwdOverlay.classList.remove('opacity-0', 'pointer-events-none');
        changePwdOverlay.classList.add('opacity-100');
    });

    document.getElementById('btnCloseChangePwd').addEventListener('click', () => {
        changePwdOverlay.style.visibility = 'hidden';
        changePwdOverlay.classList.add('opacity-0', 'pointer-events-none');
        changePwdOverlay.classList.remove('opacity-100');
    });
    changePwdOverlay.addEventListener('click', (e) => {
        if (e.target === changePwdOverlay) {
            changePwdOverlay.style.visibility = 'hidden';
            changePwdOverlay.classList.add('opacity-0', 'pointer-events-none');
            changePwdOverlay.classList.remove('opacity-100');
        }
    });

    document.getElementById('btnSavePassword').addEventListener('click', async () => {
        const curPwd = document.getElementById('curPwdInput').value;
        const newPwd = document.getElementById('newPwdInput').value;
        const confirmPwd = document.getElementById('confirmPwdInput').value;
        const errEl = document.getElementById('changePwdError');
        errEl.classList.add('hidden');
        if (!curPwd || !newPwd) { errEl.textContent = '请填写所有密码字段'; errEl.classList.remove('hidden'); return; }
        if (newPwd !== confirmPwd) { errEl.textContent = '两次新密码不一致'; errEl.classList.remove('hidden'); return; }
        if (newPwd.length < 6) { errEl.textContent = '新密码至少6位'; errEl.classList.remove('hidden'); return; }
        const btn = document.getElementById('btnSavePassword');
        btn.disabled = true;
        btn.textContent = '保存中...';
        try {
            await EchoAPI.changePassword(curPwd, newPwd);
            changePwdOverlay.style.visibility = 'hidden';
            changePwdOverlay.classList.add('opacity-0', 'pointer-events-none');
            window.showToast && window.showToast('密码修改成功');
        } catch (e) {
            errEl.textContent = e.message || '修改失败';
            errEl.classList.remove('hidden');
        } finally {
            btn.disabled = false;
            btn.textContent = '保存';
        }
    });

    // 修改密码 - 眼睛切换
    function setupPwdToggle2(btnId, inputId) {
        const btn = document.getElementById(btnId);
        const input = document.getElementById(inputId);
        if (!btn || !input) return;
        btn.addEventListener('click', () => {
            const isPwd = input.type === 'password';
            input.type = isPwd ? 'text' : 'password';
            const icon = btn.querySelector('i');
            if (icon) icon.setAttribute('data-lucide', isPwd ? 'eye-off' : 'eye');
            if (typeof lucide !== 'undefined') lucide.createIcons();
        });
    }
    setupPwdToggle2('btnToggleCurPwd', 'curPwdInput');
    setupPwdToggle2('btnToggleNewPwd', 'newPwdInput');
    setupPwdToggle2('btnToggleConfirmPwd', 'confirmPwdInput');

    // 全局事件代理：点击头像/名字 → 跳转作者主页
    // 元素添加 data-open-profile 属性即可自动响应点击
    document.addEventListener('click', (e) => {
        const btn = e.target.closest('[data-open-profile]');
        if (!btn) return;
        const uid = parseInt(btn.dataset.userId);
        if (!uid || uid <= 0) return;
        if (window.closeSafetyCenter) window.closeSafetyCenter();
        if (window.closeNotificationCenter) window.closeNotificationCenter();
        window.openAuthorProfile && window.openAuthorProfile(uid);
    });
})();

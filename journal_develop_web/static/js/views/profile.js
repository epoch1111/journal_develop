(function() {
    'use strict';

    // ===== DOM 元素获取 =====
    const myProfileOverlay = document.getElementById('myProfileOverlay');
    const myProfileContent = document.getElementById('myProfileContent');
    const authorProfileOverlay = document.getElementById('authorProfileOverlay');
    const authorProfileContent = document.getElementById('authorProfileContent');
    const editProfileOverlay = document.getElementById('editProfileOverlay');
    const followListOverlay = document.getElementById('followListOverlay');
    const followListContent = document.getElementById('followListContent');
    const greetModalOverlay = document.getElementById('greetModalOverlay');
    const greetModalTitle = document.getElementById('greetModalTitle');
    const greetMessageInput = document.getElementById('greetMessageInput');
    const greetCharCount = document.getElementById('greetCharCount');
    const greetError = document.getElementById('greetError');
    const btnSendGreet = document.getElementById('btnSendGreet');
    const greetCenterOverlay = document.getElementById('greetCenterOverlay');
    const greetCenterContent = document.getElementById('greetCenterContent');
    const greetTabReceived = document.getElementById('greetTabReceived');
    const greetTabSent = document.getElementById('greetTabSent');
    const greetTabAccepted = document.getElementById('greetTabAccepted');
    const safetyCenterOverlay = document.getElementById('safetyCenterOverlay');
    const safetyCenterContent = document.getElementById('safetyCenterContent');
    const blockedListContent = document.getElementById('blockedListContent');
    const reportListContent = document.getElementById('reportListContent');

    let currentGreetReceiverId = null;
    let greetCenterTab = 'received';

    // ===== 我的主页弹窗 =====

    function openMyProfile() {
        myProfileOverlay.classList.remove('opacity-0', 'pointer-events-none');
        myProfileOverlay.classList.add('opacity-100');
        loadMyProfile();
    }

    function closeMyProfile() {
        myProfileOverlay.classList.add('opacity-0', 'pointer-events-none');
        myProfileOverlay.classList.remove('opacity-100');
    }

    async function loadMyProfile() {
        myProfileContent.innerHTML = '<div class="flex items-center justify-center py-20"><span class="loader w-8 h-8 border-2 border-emerald-300 border-t-transparent rounded-full inline-block"></span></div>';
        try {
            const data = await EchoAPI.fetchMyProfile();
            myProfileData = data;
            renderMyProfile(data);
            setAvatarElements(
                document.getElementById('headerAvatar'),
                document.getElementById('headerAvatarImg'),
                data.avatar
            );
        } catch (e) {
            console.error('加载主页失败:', e);
            myProfileContent.innerHTML = '<p class="text-center text-gray-400 py-20">加载失败，请稍后再试</p>';
        }
    }

    function renderMyProfile(data) {
        const tags = data.interests ? data.interests.split(',').filter(Boolean) : [];
        const tagHtml = tags.map(t => `<span class="text-xs px-3 py-1 rounded-full bg-emerald-50 text-emerald-600 font-medium">#${t.trim()}</span>`).join(' ');
        const keywordsHtml = (data.mood_keywords || []).map(k => `<span class="text-xs px-3 py-1 rounded-full bg-amber-50 text-amber-600 font-medium">${k}</span>`).join(' ');
        const recentHtml = (data.recent_public_diaries || []).length === 0
            ? '<p class="text-xs text-gray-300 text-center py-6">还没有公开日记，去分享一篇吧</p>'
            : (data.recent_public_diaries || []).map(d => `
                <div class="bg-gray-50 rounded-2xl p-4 space-y-1.5 cursor-pointer hover:bg-gray-100 active:scale-[0.98] transition-all" data-diary-id="${d.id}">
                    <div class="flex items-center gap-2">
                        <span class="text-lg">${d.mood || '📝'}</span>
                        <span class="text-xs text-gray-400">${formatDate(d.created_at)}</span>
                    </div>
                    <p class="text-sm text-gray-600 line-clamp-2">${escapeHtml(d.content || '')}</p>
                    ${d.tags ? `<div class="flex flex-wrap gap-1">${d.tags.split(',').filter(Boolean).map(t => `<span class="text-[10px] text-gray-400">#${t.trim()}</span>`).join(' ')}</div>` : ''}
                </div>
            `).join('');

        const followingCount = data.following_count ?? 0;
        const followerCount = data.follower_count ?? 0;
        myProfileContent.innerHTML = `
            <div class="flex flex-col items-center">
                ${renderAvatar(data.avatar, 80)}
                <h3 class="text-lg font-semibold text-gray-800">${escapeHtml(data.nickname || '小兔')}</h3>
                <p class="text-[10px] text-gray-300 mt-0.5">UID: ${data.id}</p>
                <p class="text-sm text-gray-500 mt-1 text-center">${escapeHtml(data.bio || '')}</p>
                ${tagHtml ? `<div class="flex flex-wrap justify-center gap-2 mt-4">${tagHtml}</div>` : ''}
            </div>
            <div class="grid grid-cols-3 gap-3">
                <div class="bg-amber-50 rounded-2xl p-3 text-center">
                    <p class="text-xl font-bold text-amber-600">${data.stats?.diary_count || 0}</p>
                    <p class="text-[10px] text-gray-400 mt-0.5">日记</p>
                </div>
                <div class="bg-emerald-50 rounded-2xl p-3 text-center cursor-pointer hover:shadow-md active:scale-95 transition-all" id="btnMyFollowing">
                    <p class="text-xl font-bold text-emerald-600">${followingCount}</p>
                    <p class="text-[10px] text-gray-400 mt-0.5">正在关注</p>
                </div>
                <div class="bg-pink-50 rounded-2xl p-3 text-center cursor-pointer hover:shadow-md active:scale-95 transition-all" id="btnMyFollowers">
                    <p class="text-xl font-bold text-pink-500">${followerCount}</p>
                    <p class="text-[10px] text-gray-400 mt-0.5">粉丝</p>
                </div>
            </div>
            <div id="btnMyGreetCenter" class="bg-purple-50 rounded-2xl p-4 text-center cursor-pointer hover:shadow-md active:scale-95 transition-all">
                <div class="flex items-center justify-center gap-2">
                    <span class="text-xl font-bold text-purple-500">打招呼</span>
                    <span id="myGreetPendingBadge" class="hidden min-w-[20px] h-[20px] rounded-full bg-red-400 text-white text-[10px] font-bold flex items-center justify-center px-1">0</span>
                </div>
                <p class="text-[10px] text-gray-400 mt-0.5">收到的申请</p>
            </div>
            <div id="btnMySafetyCenter" class="bg-red-50 rounded-2xl p-4 text-center cursor-pointer hover:shadow-md active:scale-95 transition-all">
                <div class="flex items-center justify-center gap-2">
                    <span class="text-xl font-bold text-red-400">安全中心</span>
                </div>
                <p class="text-[10px] text-gray-400 mt-0.5">拉黑与举报</p>
            </div>
            <div class="bg-blue-50 rounded-2xl p-4">
                <div class="flex items-center justify-center gap-2 mb-2">
                    <span class="text-base font-bold text-blue-400">🌐 远程连接</span>
                </div>
                <p class="text-[10px] text-gray-400 mt-0.5 text-center mb-3">ngrok 等内网穿透场景使用</p>
                <div class="flex gap-2">
                    <input id="serverUrlInput" type="text" placeholder="https://xxxx.ngrok.io"
                           class="flex-1 px-3 py-2 rounded-xl bg-white text-xs text-gray-700 border border-blue-100 focus:ring-2 focus:ring-blue-200 focus:outline-none">
                    <button id="btnConnectServer" class="px-3 py-2 rounded-xl bg-blue-400 text-white text-xs font-medium shrink-0 active:scale-95 transition-all">
                        连接
                    </button>
                </div>
                <p id="serverUrlStatus" class="text-[10px] text-center mt-2 text-gray-400">
                    未设置（使用本地服务）
                </p>
            </div>
            ${keywordsHtml ? `
            <div>
                <p class="text-xs text-gray-400 mb-3">🧠 情绪关键词</p>
                <div class="flex flex-wrap gap-2">${keywordsHtml}</div>
            </div>` : ''}
            <div>
                <p class="text-xs text-gray-400 mb-3">📖 最近公开日记</p>
                <div class="space-y-2.5">${recentHtml}</div>
            </div>
        `;
        // 绑定关注/粉丝列表 + 打招呼中心 + 安全中心按钮
        setTimeout(() => {
            const btnF = document.getElementById('btnMyFollowing');
            const btnR = document.getElementById('btnMyFollowers');
            const btnG = document.getElementById('btnMyGreetCenter');
            const btnS = document.getElementById('btnMySafetyCenter');
            if (btnF) btnF.addEventListener('click', () => openFollowList('following'));
            if (btnR) btnR.addEventListener('click', () => openFollowList('followers'));
            if (btnG) btnG.addEventListener('click', () => openGreetCenter('received'));
            if (btnS) btnS.addEventListener('click', () => openSafetyCenter());
            // 最近公开日记点击 → 打开详情
            document.querySelectorAll('#myProfileContent [data-diary-id]').forEach(el => {
                el.addEventListener('click', () => {
                    const diaryId = parseInt(el.dataset.diaryId);
                    if (window.openDetailModal) window.openDetailModal(diaryId);
                });
            });
            // 获取打招呼待处理数
            fetchMyGreetPendingCount();
            // 远程连接设置
            const btnConnect = document.getElementById('btnConnectServer');
            const serverUrlInput = document.getElementById('serverUrlInput');
            const serverUrlStatus = document.getElementById('serverUrlStatus');
            if (serverUrlStatus) {
                const saved = window.EchoAPI.getServerUrl();
                if (saved) {
                    serverUrlStatus.textContent = '已连接: ' + saved;
                    serverUrlStatus.className = 'text-[10px] text-center mt-2 text-blue-400';
                }
            }
            if (btnConnect && serverUrlInput) {
                btnConnect.addEventListener('click', () => {
                    const url = (serverUrlInput.value || '').trim();
                    window.EchoAPI.setServerUrl(url);
                    if (url) {
                        if (serverUrlStatus) { serverUrlStatus.textContent = '已连接: ' + url; serverUrlStatus.className = 'text-[10px] text-center mt-2 text-blue-400'; }
                        showToast('连接成功，页面将重新加载', 'success');
                        setTimeout(() => location.reload(), 800);
                    } else {
                        if (serverUrlStatus) { serverUrlStatus.textContent = '未设置（使用本地服务）'; serverUrlStatus.className = 'text-[10px] text-center mt-2 text-gray-400'; }
                        showToast('已切换回本地服务', 'success');
                        setTimeout(() => location.reload(), 800);
                    }
                });
            }
        }, 0);
        lucide.createIcons();
    }

    async function fetchMyGreetPendingCount() {
        if (!EchoAPI.getToken()) return;
        try {
            const data = await EchoAPI.fetchGreetPendingCount();
            updateMyGreetBadge(data.pending_count || 0);
        } catch (e) { /* ignore */ }
    }

    function updateMyGreetBadge(count) {
        const badge = document.getElementById('myGreetPendingBadge');
        if (badge) {
            if (count > 0) {
                badge.textContent = count > 99 ? '99+' : count;
                badge.classList.remove('hidden');
            } else {
                badge.classList.add('hidden');
            }
        }
        const msgTabBadge = document.getElementById('msgTabGreetBadge');
        if (msgTabBadge) {
            if (count > 0) {
                msgTabBadge.textContent = count > 99 ? '99+' : count;
                msgTabBadge.classList.remove('hidden');
            } else {
                msgTabBadge.classList.add('hidden');
            }
        }
    }

    // 编辑资料
    document.getElementById('btnEditProfile').addEventListener('click', () => {
        if (!myProfileData) return;
        document.getElementById('editNickname').value = myProfileData.nickname || '';
        document.getElementById('editBio').value = myProfileData.bio || '';
        document.getElementById('editInterests').value = myProfileData.interests || '';
        updateAvatarPreview(myProfileData.avatar || '🐰');
        buildDefaultAvatarGrid(myProfileData.avatar || '🐰');
        document.getElementById('avatarUploadStatus').classList.add('hidden');
        editProfileOverlay.classList.remove('opacity-0', 'pointer-events-none');
        editProfileOverlay.classList.add('opacity-100');
    });

    document.getElementById('btnCloseEditProfile').addEventListener('click', () => {
        editProfileOverlay.classList.add('opacity-0', 'pointer-events-none');
        editProfileOverlay.classList.remove('opacity-100');
    });

    document.getElementById('btnSaveProfile').addEventListener('click', async () => {
        const nickname = document.getElementById('editNickname').value.trim();
        if (!nickname) { alert('昵称不能为空～'); return; }
        const btn = document.getElementById('btnSaveProfile');
        btn.disabled = true;
        btn.textContent = '保存中...';
        try {
            await EchoAPI.updateMyProfile({
                nickname,
                avatar: document.getElementById('editAvatar').value.trim(),
                bio: document.getElementById('editBio').value.trim(),
                interests: document.getElementById('editInterests').value.trim(),
            });
            editProfileOverlay.classList.add('opacity-0', 'pointer-events-none');
            editProfileOverlay.classList.remove('opacity-100');
            await loadMyProfile();
            // 如果当前在"我的" Tab，刷新内容
            if (currentTab === 'profile') loadProfileTabContent();
            // 显示提示
            const toast = document.createElement('div');
            toast.className = 'fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 z-[70] bg-gray-800/90 text-white text-sm px-5 py-2.5 rounded-2xl shadow-xl pointer-events-none';
            toast.textContent = '资料已保存';
            document.body.appendChild(toast);
            setTimeout(() => toast.remove(), 1500);
        } catch (e) {
            console.error('保存资料失败:', e);
            alert('保存失败，请稍后再试～');
        } finally {
            btn.disabled = false;
            btn.textContent = '保存';
        }
    });

    // 关闭我的主页
    document.getElementById('btnCloseMyProfile').addEventListener('click', closeMyProfile);
    myProfileOverlay.addEventListener('click', (e) => { if (e.target === myProfileOverlay) closeMyProfile(); });

    // 兔子头像点击 → 切换到"我的" Tab
    document.getElementById('btnMyProfile').addEventListener('click', () => switchTab('profile'));

    // ===== 作者主页弹窗 =====

    function openAuthorProfile(userId) {
        authorProfileOverlay.classList.remove('opacity-0', 'pointer-events-none');
        authorProfileOverlay.classList.add('opacity-100');
        loadAuthorProfile(userId);
    }

    function closeAuthorProfile() {
        authorProfileOverlay.classList.add('opacity-0', 'pointer-events-none');
        authorProfileOverlay.classList.remove('opacity-100');
    }

    async function loadAuthorProfile(userId) {
        authorProfileContent.innerHTML = '<div class="flex items-center justify-center py-20"><span class="loader w-8 h-8 border-2 border-emerald-300 border-t-transparent rounded-full inline-block"></span></div>';
        try {
            const data = await EchoAPI.fetchUserProfile(userId);
            renderAuthorProfile(data);
        } catch (e) {
            console.error('加载作者主页失败:', e);
            authorProfileContent.innerHTML = '<p class="text-center text-gray-400 py-20">加载失败，请稍后再试</p>';
        }
    }

    function renderAuthorProfile(data) {
        // 被拉黑时显示简化状态
        if (data.blocked) {
            authorProfileContent.innerHTML = `
                <div class="flex flex-col items-center py-10">
                    ${renderAvatar(data.avatar, 80)}
                    <h3 class="text-lg font-semibold text-gray-800">${escapeHtml(data.nickname || '小兔')}</h3>
                    <p class="text-sm text-gray-400 mt-4 text-center">${escapeHtml(data.message || '由于安全设置，暂时无法查看该用户主页')}</p>
                    <div class="flex gap-3 mt-6">
                        <button id="btnAuthorUnblock" data-uid="${data.id}" class="px-6 py-2.5 rounded-2xl bg-gray-100 text-gray-500 text-sm font-medium hover:bg-gray-200 active:scale-95 transition-all">
                            解除拉黑
                        </button>
                        <button id="btnAuthorReport" data-uid="${data.id}" class="px-6 py-2.5 rounded-2xl bg-red-50 text-red-400 text-sm font-medium hover:bg-red-100 active:scale-95 transition-all">
                            举报 TA
                        </button>
                    </div>
                </div>
            `;
            lucide.createIcons();
            setTimeout(() => {
                const unblockBtn = document.getElementById('btnAuthorUnblock');
                const reportBtn = document.getElementById('btnAuthorReport');
                if (unblockBtn) unblockBtn.addEventListener('click', async () => {
                    try {
                        await EchoAPI.unblockUser(data.id);
                        showToast('已解除拉黑');
                        loadAuthorProfile(data.id);
                    } catch (e) { showToast(e.message || '操作失败'); }
                });
                if (reportBtn) reportBtn.addEventListener('click', () => {
                    openReportModal('user', data.id, `举报用户 @${data.nickname}`);
                });
            }, 0);
            return;
        }

        const tags = data.interests ? data.interests.split(',').filter(Boolean) : [];
        const tagHtml = tags.map(t => `<span class="text-xs px-3 py-1 rounded-full bg-emerald-50 text-emerald-600 font-medium">#${t.trim()}</span>`).join(' ');
        const keywordsHtml = (data.mood_keywords || []).map(k => `<span class="text-xs px-3 py-1 rounded-full bg-amber-50 text-amber-600 font-medium">${k}</span>`).join(' ');
        const score = data.same_frequency_score || 86;
        const recentHtml = (data.recent_public_diaries || []).length === 0
            ? '<p class="text-xs text-gray-300 text-center py-6">TA 还没有公开日记</p>'
            : (data.recent_public_diaries || []).map(d => `
                <div class="bg-gray-50 rounded-2xl p-4 space-y-1.5">
                    <div class="flex items-center gap-2">
                        <span class="text-lg">${d.mood || '📝'}</span>
                        <span class="text-xs text-gray-400">${formatDate(d.created_at)}</span>
                    </div>
                    <p class="text-sm text-gray-600 line-clamp-2">${escapeHtml(d.content || '')}</p>
                    ${d.tags ? `<div class="flex flex-wrap gap-1">${d.tags.split(',').filter(Boolean).map(t => `<span class="text-[10px] text-gray-400">#${t.trim()}</span>`).join(' ')}</div>` : ''}
                </div>
            `).join('');

        const isMe = myProfileData && myProfileData.id === data.id;
        const isFollowing = data.is_following || false;
        const followerCount = data.follower_count ?? 0;
        const followingCount = data.following_count ?? 0;
        const followBtnHtml = isMe ? '' : `
            <button id="btnAuthorFollow" data-uid="${data.id}" data-following="${isFollowing}"
                    class="w-full py-3 rounded-2xl font-medium text-sm active:scale-95 transition-all shadow-sm ${isFollowing ? 'bg-emerald-50 text-emerald-600' : 'bg-emerald-400 text-white'}">
                ${isFollowing ? '✓ 已关注' : '+ 关注 TA'}
            </button>
        `;

        // 安全操作按钮
        const safetyBtnsHtml = isMe ? '' : `
            <div class="flex gap-2">
                <button id="btnAuthorBlock" data-uid="${data.id}" class="flex-1 py-2.5 rounded-2xl bg-gray-50 text-gray-400 text-xs font-medium hover:bg-red-50 hover:text-red-400 active:scale-95 transition-all">
                    拉黑 TA
                </button>
                <button id="btnAuthorReport" data-uid="${data.id}" class="flex-1 py-2.5 rounded-2xl bg-gray-50 text-gray-400 text-xs font-medium hover:bg-amber-50 hover:text-amber-500 active:scale-95 transition-all">
                    举报 TA
                </button>
            </div>
        `;

        // 保存当前作者数据
        window._currentAuthorData = data;

        authorProfileContent.innerHTML = `
            <div class="flex flex-col items-center">
                ${renderAvatar(data.avatar, 80)}
                <h3 class="text-lg font-semibold text-gray-800">${escapeHtml(data.nickname || '小兔')}</h3>
                <p class="text-sm text-gray-500 mt-1 text-center">${escapeHtml(data.bio || '')}</p>
                ${tagHtml ? `<div class="flex flex-wrap justify-center gap-2 mt-4">${tagHtml}</div>` : ''}
            </div>
            <div class="grid grid-cols-2 gap-3">
                <div class="bg-pink-50 rounded-2xl p-3 text-center">
                    <p class="text-xl font-bold text-pink-500">${followerCount}</p>
                    <p class="text-[10px] text-gray-400 mt-0.5">粉丝</p>
                </div>
                <div class="bg-emerald-50 rounded-2xl p-3 text-center">
                    <p class="text-xl font-bold text-emerald-600">${followingCount}</p>
                    <p class="text-[10px] text-gray-400 mt-0.5">TA 关注</p>
                </div>
            </div>
            ${followBtnHtml}
            ${safetyBtnsHtml}
            <button id="btnAuthorGreet" data-uid="${data.id}" class="w-full py-3 rounded-2xl font-medium text-sm active:scale-95 transition-all shadow-sm bg-purple-50 text-purple-500" style="${isMe ? 'display:none' : ''}">
                打个招呼
            </button>
            <button id="btnAuthorMessage" data-uid="${data.id}" class="hidden w-full py-3 rounded-2xl font-medium text-sm active:scale-95 transition-all shadow-sm bg-indigo-50 text-indigo-500" style="display:none">
                发消息
            </button>
            <div class="bg-gradient-to-r from-emerald-50 to-amber-50 rounded-2xl p-4 text-center">
                <p class="text-2xl font-bold text-emerald-600">${score}<span class="text-lg font-normal text-gray-400">%</span></p>
                <p class="text-xs text-gray-500 mt-1">你们有 ${score}% 的同频感</p>
            </div>
            <div>
                <p class="text-xs text-gray-400 mb-3">🧠 情绪关键词</p>
                <div class="flex flex-wrap gap-2">${keywordsHtml || '<span class="text-xs text-gray-300">暂无数据</span>'}</div>
            </div>
            <div>
                <p class="text-xs text-gray-400 mb-3">📖 TA 最近的公开日记（${data.public_diary_count || 0}篇）</p>
                <div class="space-y-2.5">${recentHtml}</div>
            </div>
        `;
        lucide.createIcons();

        // 绑定关注按钮
        setTimeout(() => {
            const btn = document.getElementById('btnAuthorFollow');
            if (btn) btn.addEventListener('click', handleAuthorFollow);
        }, 0);

        // 绑定打招呼按钮并更新状态
        if (!isMe) {
            setTimeout(async () => {
                const greetBtn = document.getElementById('btnAuthorGreet');
                if (!greetBtn) return;
                try {
                    const gs = await EchoAPI.fetchGreetStatus(data.id);
                    updateAuthorGreetBtn(greetBtn, gs, data.nickname);
                } catch (e) { /* ignore */ }
            }, 50);

            // 绑定拉黑和举报按钮
            setTimeout(() => {
                const blockBtn = document.getElementById('btnAuthorBlock');
                const reportBtn = document.getElementById('btnAuthorReport');
                if (blockBtn) blockBtn.addEventListener('click', async () => {
                    if (!confirm('确定要拉黑 TA 吗？拉黑后 TA 将无法关注、打招呼或给你发消息。')) return;
                    try {
                        await EchoAPI.blockUser(data.id, { reason: '' });
                        showToast('已拉黑该用户');
                        loadAuthorProfile(data.id);
                    } catch (e) { showToast(e.message || '操作失败'); }
                });
                if (reportBtn) reportBtn.addEventListener('click', () => {
                    openReportModal('user', data.id, `举报用户 @${data.nickname}`);
                });
            }, 100);
        }
    }

    // 关闭作者主页
    document.getElementById('btnCloseAuthorProfile').addEventListener('click', closeAuthorProfile);
    authorProfileOverlay.addEventListener('click', (e) => { if (e.target === authorProfileOverlay) closeAuthorProfile(); });

    // ===== 关注操作 =====

    async function handleAuthorFollow(e) {
        const btn = e.currentTarget;
        const uid = parseInt(btn.dataset.uid);
        if (!uid) return;

        if (!EchoAPI.getToken()) {
            showAuth('login');
            return;
        }

        const isFollowing = btn.dataset.following === 'true';
        btn.disabled = true;
        try {
            if (isFollowing) {
                // 取消关注
                if (!confirm('确定要取消关注吗？')) { btn.disabled = false; return; }
                const res = await EchoAPI.unfollowUser(uid);
                if (res.ok) {
                    btn.dataset.following = 'false';
                    btn.className = 'w-full py-3 rounded-2xl font-medium text-sm active:scale-95 transition-all shadow-sm bg-emerald-400 text-white';
                    btn.textContent = '+ 关注 TA';
                    // 更新粉丝数
                    const countEl = authorProfileContent.querySelector('.grid .text-pink-500');
                    if (countEl) countEl.textContent = res.follower_count;
                    showToast('已取消关注');
                }
            } else {
                const res = await EchoAPI.followUser(uid);
                if (res.ok) {
                    btn.dataset.following = 'true';
                    btn.className = 'w-full py-3 rounded-2xl font-medium text-sm active:scale-95 transition-all shadow-sm bg-emerald-50 text-emerald-600';
                    btn.textContent = '✓ 已关注';
                    const countEl = authorProfileContent.querySelector('.grid .text-pink-500');
                    if (countEl) countEl.textContent = res.follower_count;
                    if (!res.already_followed) showToast('已关注 TA');
                }
            }
        } catch (e) {
            console.error('关注操作失败:', e);
            showToast(e.message || '操作失败');
        } finally {
            btn.disabled = false;
        }
    }

    function updateAuthorGreetBtn(btn, gs, nickname) {
        const s = gs.status || 'none';
        const dir = gs.direction || 'none';
        btn.classList.remove('hidden');
        btn.style.display = '';

        // 检查是否已认识，显示发消息按钮
        const msgBtn = document.getElementById('btnAuthorMessage');
        if (s === 'accepted' && msgBtn) {
            msgBtn.classList.remove('hidden');
            msgBtn.style.display = '';
            const uid = parseInt(btn.dataset.uid);
            msgBtn.onclick = () => window.openChatWithUser(uid, nickname, window._currentAuthorData?.avatar);
        } else if (msgBtn) {
            msgBtn.classList.add('hidden');
            msgBtn.style.display = 'none';
        }

        if (s === 'self') {
            btn.style.display = 'none';
        } else if (s === 'none') {
            btn.className = 'w-full py-3 rounded-2xl font-medium text-sm active:scale-95 transition-all shadow-sm bg-purple-50 text-purple-500';
            btn.textContent = '打个招呼';
            btn.onclick = () => openGreetModal(parseInt(btn.dataset.uid), nickname);
        } else if (s === 'pending' && dir === 'sent') {
            btn.className = 'w-full py-3 rounded-2xl font-medium text-sm active:scale-95 transition-all shadow-sm bg-amber-50 text-amber-600';
            btn.textContent = '等待回应';
            btn.onclick = () => openGreetCenter('sent');
        } else if (s === 'pending' && dir === 'received') {
            btn.className = 'w-full py-3 rounded-2xl font-medium text-sm active:scale-95 transition-all shadow-sm bg-emerald-50 text-emerald-600';
            btn.textContent = '回应 TA';
            btn.onclick = () => openGreetCenter('received');
        } else if (s === 'accepted') {
            btn.className = 'w-full py-3 rounded-2xl font-medium text-sm active:scale-95 transition-all shadow-sm bg-emerald-100 text-emerald-700';
            btn.textContent = '已认识';
            btn.onclick = () => openGreetCenter('accepted');
        } else {
            // rejected / cancelled
            btn.className = 'w-full py-3 rounded-2xl font-medium text-sm active:scale-95 transition-all shadow-sm bg-purple-50 text-purple-500';
            btn.textContent = '重新打招呼';
            btn.onclick = () => openGreetModal(parseInt(btn.dataset.uid), nickname);
        }
    }

    function showToast(msg) {
        const toast = document.createElement('div');
        toast.className = 'fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 z-[70] bg-gray-800/90 text-white text-sm px-5 py-2.5 rounded-2xl shadow-xl pointer-events-none';
        toast.style.animation = 'toastFadeIn 0.3s ease-out';
        toast.textContent = msg;
        document.body.appendChild(toast);
        setTimeout(() => toast.remove(), 1500);
    }

    // ===== 关注/粉丝列表 =====

    async function openFollowList(type) {
        if (!EchoAPI.getToken()) {
            showAuth('login');
            return;
        }
        const isFollowing = type === 'following';
        const title = isFollowing ? '我的关注' : '我的粉丝';

        // 创建列表弹窗
        let listOverlay = document.getElementById('followListOverlay');
        if (!listOverlay) {
            listOverlay = document.createElement('div');
            listOverlay.id = 'followListOverlay';
            listOverlay.className = 'fixed inset-0 z-[60] bg-black/40 backdrop-blur-sm flex items-end sm:items-center justify-center opacity-0 pointer-events-none transition-opacity duration-300';
            listOverlay.innerHTML = `
                <div class="relative w-full sm:max-w-[420px] bg-white rounded-t-[2rem] sm:rounded-[2rem] h-[80vh] flex flex-col shadow-2xl">
                    <div class="shrink-0 flex items-center justify-between px-6 pt-6 pb-3">
                        <button class="w-10 h-10 flex items-center justify-center rounded-full hover:bg-gray-100 transition-colors" id="btnCloseFollowList">
                            <i data-lucide="x" class="w-6 h-6 text-gray-500"></i>
                        </button>
                        <span class="text-sm font-semibold text-gray-700" id="followListTitle">${title}</span>
                        <span class="w-10"></span>
                    </div>
                    <div id="followListContent" class="flex-1 overflow-y-auto hide-scrollbar px-6 pb-8 space-y-3">
                        <div class="flex items-center justify-center py-20"><span class="loader w-8 h-8 border-2 border-emerald-300 border-t-transparent rounded-full inline-block"></span></div>
                    </div>
                </div>
            `;
            document.body.appendChild(listOverlay);
            listOverlay.addEventListener('click', function (e) { if (e.target === listOverlay) closeFollowList(); });
            document.getElementById('btnCloseFollowList').addEventListener('click', closeFollowList);
        } else {
            document.getElementById('followListTitle').textContent = title;
        }

        listOverlay.classList.remove('opacity-0', 'pointer-events-none');
        listOverlay.classList.add('opacity-100');
        if (typeof lucide !== 'undefined' && lucide.createIcons) lucide.createIcons();

        const content = document.getElementById('followListContent');
        content.innerHTML = '<div class="flex items-center justify-center py-20"><span class="loader w-8 h-8 border-2 border-emerald-300 border-t-transparent rounded-full inline-block"></span></div>';

        try {
            const data = isFollowing ? await EchoAPI.fetchMyFollowing() : await EchoAPI.fetchMyFollowers();
            if (data.length === 0) {
                content.innerHTML = '<p class="text-center text-gray-400 py-20">' + (isFollowing ? '还没有关注任何人' : '还没有粉丝') + '</p>';
            } else {
                content.innerHTML = data.map(u => `
                    <div class="flex items-center gap-3 bg-gray-50 rounded-2xl p-4 cursor-pointer hover:bg-gray-100 active:scale-[0.98] transition-all follow-user-card" data-uid="${u.id}">
                        ${renderAvatar(u.avatar, 36)}
                        <div class="flex-1 min-w-0">
                            <p class="text-sm font-medium text-gray-800">${escapeHtml(u.nickname || '')}</p>
                            <p class="text-xs text-gray-400 truncate">${escapeHtml(u.bio || '')}</p>
                        </div>
                    </div>
                `).join('');
                // 点击进入作者主页
                content.querySelectorAll('.follow-user-card').forEach(card => {
                    card.addEventListener('click', function () {
                        const uid = parseInt(this.dataset.uid);
                        closeFollowList();
                        openAuthorProfile(uid);
                    });
                });
            }
        } catch (e) {
            console.error('加载关注列表失败:', e);
            content.innerHTML = '<p class="text-center text-gray-400 py-20">加载失败，请稍后再试</p>';
        }
    }

    function closeFollowList() {
        const listOverlay = document.getElementById('followListOverlay');
        if (listOverlay) {
            listOverlay.classList.add('opacity-0', 'pointer-events-none');
            listOverlay.classList.remove('opacity-100');
        }
    }

    // ===== 打招呼系统 =====

    // -- 打招呼弹窗 --

    greetMessageInput.addEventListener('input', () => {
        greetCharCount.textContent = greetMessageInput.value.length;
    });

    function openGreetModal(receiverId, nickname) {
        if (!EchoAPI.getToken()) { showAuth('login'); return; }
        currentGreetReceiverId = receiverId;
        greetModalTitle.textContent = `向 ${nickname || 'TA'} 打个招呼`;
        greetMessageInput.value = '';
        greetCharCount.textContent = '0';
        greetError.classList.add('hidden');
        btnSendGreet.disabled = false;
        btnSendGreet.textContent = '发送';
        greetModalOverlay.classList.remove('opacity-0', 'pointer-events-none');
        greetModalOverlay.classList.add('opacity-100');
        setTimeout(() => greetMessageInput.focus(), 300);
        lucide.createIcons();
    }

    function closeGreetModal() {
        greetModalOverlay.classList.add('opacity-0', 'pointer-events-none');
        greetModalOverlay.classList.remove('opacity-100');
    }

    document.getElementById('btnCloseGreetModal').addEventListener('click', closeGreetModal);
    greetModalOverlay.addEventListener('click', (e) => { if (e.target === greetModalOverlay) closeGreetModal(); });

    btnSendGreet.addEventListener('click', async () => {
        const message = greetMessageInput.value.trim();
        if (!message) { greetError.textContent = '请输入打招呼内容'; greetError.classList.remove('hidden'); return; }
        greetError.classList.add('hidden');
        btnSendGreet.disabled = true;
        btnSendGreet.textContent = '发送中...';
        try {
            const res = await EchoAPI.createGreetRequest({ receiver_id: currentGreetReceiverId, message });
            closeGreetModal();
            showToast('招呼已经送到 TA 的星球啦 ✨');
            // 刷新作者主页按钮状态
            if (window._currentAuthorData) {
                loadAuthorProfile(window._currentAuthorData.id);
            }
            fetchUnreadCount();
        } catch (e) {
            greetError.textContent = e.message || '发送失败';
            greetError.classList.remove('hidden');
        } finally {
            btnSendGreet.disabled = false;
            btnSendGreet.textContent = '发送';
        }
    });

    // -- 打招呼中心 --

    function openGreetCenter(tab) {
        if (!EchoAPI.getToken()) { showAuth('login'); return; }
        greetCenterTab = tab || 'received';
        updateGreetTabs();
        greetCenterOverlay.classList.remove('opacity-0', 'pointer-events-none');
        greetCenterOverlay.classList.add('opacity-100');
        loadGreetCenterContent();
        lucide.createIcons();
    }

    function closeGreetCenter() {
        greetCenterOverlay.classList.add('opacity-0', 'pointer-events-none');
        greetCenterOverlay.classList.remove('opacity-100');
    }

    document.getElementById('btnCloseGreetCenter').addEventListener('click', closeGreetCenter);
    greetCenterOverlay.addEventListener('click', (e) => { if (e.target === greetCenterOverlay) closeGreetCenter(); });

    greetTabReceived.addEventListener('click', () => { greetCenterTab = 'received'; updateGreetTabs(); loadGreetCenterContent(); });
    greetTabSent.addEventListener('click', () => { greetCenterTab = 'sent'; updateGreetTabs(); loadGreetCenterContent(); });
    greetTabAccepted.addEventListener('click', () => { greetCenterTab = 'accepted'; updateGreetTabs(); loadGreetCenterContent(); });

    function updateGreetTabs() {
        [greetTabReceived, greetTabSent, greetTabAccepted].forEach(b => {
            b.className = 'flex-1 py-2.5 rounded-xl text-sm font-medium bg-gray-50 text-gray-400 active:scale-95 transition-all';
        });
        const active = greetCenterTab === 'received' ? greetTabReceived : greetCenterTab === 'sent' ? greetTabSent : greetTabAccepted;
        active.className = 'flex-1 py-2.5 rounded-xl text-sm font-medium bg-emerald-50 text-emerald-600 active:scale-95 transition-all';
    }

    async function loadGreetCenterContent() {
        greetCenterContent.innerHTML = '<div class="flex items-center justify-center py-20"><span class="loader w-6 h-6 border-2 border-emerald-400 border-t-transparent rounded-full inline-block"></span></div>';
        try {
            let items;
            if (greetCenterTab === 'received') {
                items = await EchoAPI.fetchReceivedGreetRequests();
            } else if (greetCenterTab === 'sent') {
                items = await EchoAPI.fetchSentGreetRequests();
            } else {
                const received = await EchoAPI.fetchReceivedGreetRequests('accepted');
                const sent = await EchoAPI.fetchSentGreetRequests('accepted');
                items = [...received, ...sent].sort((a, b) => b.created_at.localeCompare(a.created_at));
            }
            renderGreetCenterItems(items);
        } catch (e) {
            greetCenterContent.innerHTML = '<p class="text-center text-gray-400 py-20">加载失败，请稍后再试</p>';
        }
        lucide.createIcons();
    }

    function renderGreetCenterItems(items) {
        if (!items || items.length === 0) {
            greetCenterContent.innerHTML = `<div class="flex flex-col items-center justify-center py-20 text-gray-300">
                <i data-lucide="mail" class="w-16 h-16 mb-4 text-gray-200"></i>
                <p class="text-sm text-gray-400">${greetCenterTab === 'received' ? '还没有人向你打招呼' : greetCenterTab === 'sent' ? '你还没有向任何人打招呼' : '还没有互相认识的人'}</p>
            </div>`;
            return;
        }

        greetCenterContent.innerHTML = items.map(item => {
            const isReceived = greetCenterTab === 'received' || (greetCenterTab === 'accepted' && item.requester);
            const person = isReceived ? (item.requester || {}) : (item.receiver || {});
            const avatar = person.avatar || '🐰';
            const nickname = escapeHtml(person.nickname || '小兔');
            const bio = escapeHtml(person.bio || '');
            const status = item.status;
            const timeStr = formatDate(item.created_at);

            let statusBadge = '';
            if (status === 'pending') statusBadge = '<span class="text-[10px] px-2 py-0.5 rounded-full bg-amber-50 text-amber-600 font-medium">等待回应</span>';
            else if (status === 'accepted') statusBadge = '<span class="text-[10px] px-2 py-0.5 rounded-full bg-emerald-50 text-emerald-600 font-medium">已通过</span>';
            else if (status === 'rejected') statusBadge = '<span class="text-[10px] px-2 py-0.5 rounded-full bg-gray-100 text-gray-500 font-medium">已拒绝</span>';
            else if (status === 'cancelled') statusBadge = '<span class="text-[10px] px-2 py-0.5 rounded-full bg-gray-100 text-gray-400 font-medium">已取消</span>';

            let actionHtml = '';
            if (isReceived && status === 'pending') {
                actionHtml = `<div class="flex gap-2 mt-3">
                    <button class="greet-accept-btn flex-1 py-2 rounded-xl bg-emerald-400 text-white text-xs font-medium active:scale-95 transition-all" data-req-id="${item.id}">愿意认识</button>
                    <button class="greet-reject-btn flex-1 py-2 rounded-xl bg-gray-100 text-gray-400 text-xs font-medium active:scale-95 transition-all" data-req-id="${item.id}">暂时不了</button>
                </div>`;
            } else if (!isReceived && status === 'pending') {
                actionHtml = `<div class="mt-3">
                    <button class="greet-cancel-btn w-full py-2 rounded-xl bg-gray-100 text-gray-400 text-xs font-medium active:scale-95 transition-all" data-req-id="${item.id}">取消招呼</button>
                </div>`;
            } else if (status === 'accepted') {
                const pId = person.id || 0;
                const pNick = person.nickname || '';
                const pAv = person.avatar || '🐰';
                actionHtml = `<div class="mt-3">
                    <button class="greet-chat-btn w-full py-2 rounded-xl bg-indigo-50 text-indigo-500 text-xs font-medium active:scale-95 transition-all" data-uid="${pId}" data-nick="${escapeHtml(pNick)}" data-av="${pAv}">开始聊天</button>
                </div>`;
            }

            return `<div class="bg-white rounded-2xl p-4 border border-gray-50 shadow-sm">
                <div class="flex items-start gap-3">
                    ${renderAvatar(avatar, 32)}
                    <div class="flex-1 min-w-0">
                        <div class="flex items-center gap-2 mb-1">
                            <span class="text-sm font-medium text-gray-800">${nickname}</span>
                            ${statusBadge}
                        </div>
                        <p class="text-xs text-gray-400 line-clamp-1">${bio}</p>
                        <p class="text-[13px] text-gray-600 mt-2 leading-relaxed bg-gray-50 rounded-xl px-3 py-2">${escapeHtml(item.message || '')}</p>
                        <span class="text-[10px] text-gray-300 mt-1 block">${timeStr}</span>
                        ${actionHtml}
                    </div>
                </div>
            </div>`;
        }).join('');

        // 绑定事件
        greetCenterContent.querySelectorAll('.greet-accept-btn').forEach(btn => {
            btn.addEventListener('click', async () => {
                const rid = parseInt(btn.dataset.reqId);
                try {
                    await EchoAPI.acceptGreetRequest(rid);
                    showToast('你们已经认识啦 ✨');
                    loadGreetCenterContent();
                    fetchUnreadCount();
                } catch (e) { showToast(e.message || '操作失败'); }
            });
        });
        greetCenterContent.querySelectorAll('.greet-reject-btn').forEach(btn => {
            btn.addEventListener('click', async () => {
                const rid = parseInt(btn.dataset.reqId);
                try {
                    await EchoAPI.rejectGreetRequest(rid);
                    showToast('已拒绝');
                    loadGreetCenterContent();
                    fetchUnreadCount();
                } catch (e) { showToast(e.message || '操作失败'); }
            });
        });
        greetCenterContent.querySelectorAll('.greet-cancel-btn').forEach(btn => {
            btn.addEventListener('click', async () => {
                const rid = parseInt(btn.dataset.reqId);
                try {
                    await EchoAPI.cancelGreetRequest(rid);
                    showToast('已取消');
                    loadGreetCenterContent();
                } catch (e) { showToast(e.message || '操作失败'); }
            });
        });
        greetCenterContent.querySelectorAll('.greet-chat-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const uid = parseInt(btn.dataset.uid);
                const nick = btn.dataset.nick || '';
                const av = btn.dataset.av || '🐰';
                closeGreetCenter();
                setTimeout(() => window.openChatWithUser(uid, nick, av), 300);
            });
        });
    }

    // 暴露打招呼相关函数到 window（供 messages.js 调用）
    window.openGreetCenter = openGreetCenter;
    window.closeGreetCenter = closeGreetCenter;
    window.openGreetModal = openGreetModal;
    window.fetchMyGreetPendingCount = fetchMyGreetPendingCount;
    window.updateMyGreetBadge = updateMyGreetBadge;
    window.openMyProfile = openMyProfile;
    window.renderMyProfile = renderMyProfile;

    // ===== 覆盖 openMyProfile（添加登录检查） =====
    const _origOpenMyProfile = openMyProfile;
    window.openMyProfile = async function () {
        if (!EchoAPI.getToken()) {
            showAuth('login');
            return;
        }
        _origOpenMyProfile();
    };

    // 覆盖 renderMyProfile（在底部添加退出按钮）
    const _origRenderMyProfile = renderMyProfile;
    window.renderMyProfile = function (data) {
        _origRenderMyProfile(data);
        const container = document.getElementById('myProfileContent');
        if (container && !container.querySelector('#btnLogout')) {
            const logoutDiv = document.createElement('div');
            logoutDiv.className = 'pt-4 border-t border-gray-100';
            logoutDiv.innerHTML = `<button id="btnLogout" class="w-full py-3 rounded-2xl bg-red-50 text-red-400 font-medium text-sm hover:bg-red-100 active:scale-95 transition-all">退出登录</button>`;
            container.appendChild(logoutDiv);
            document.getElementById('btnLogout').addEventListener('click', () => {
                EchoAPI.logout();
            });
        }
    };

    window.showToast = showToast;
    window.openFollowList = openFollowList;

    // ========== 安全中心 ==========
    let safetyTab = 'blocked';
    const _safetyOverlay = document.getElementById('safetyCenterOverlay');
    const _safetyContent = document.getElementById('safetyCenterContent');

    window.openSafetyCenter = function () {
        if (!EchoAPI.getToken()) { window.showAuth && window.showAuth('login'); return; }
        safetyTab = 'blocked';
        _safetyOverlay.style.visibility = 'visible';
        _safetyOverlay.classList.remove('opacity-0', 'pointer-events-none');
        _safetyOverlay.classList.add('opacity-100');
        updateSafetyTabs();
        loadSafetyContent();
        lucide.createIcons();
    };

    window.closeSafetyCenter = function () {
        _safetyOverlay.style.visibility = 'hidden';
        _safetyOverlay.classList.add('opacity-0', 'pointer-events-none');
        _safetyOverlay.classList.remove('opacity-100');
    };

    document.getElementById('btnCloseSafetyCenter').addEventListener('click', window.closeSafetyCenter);
    _safetyOverlay.addEventListener('click', (e) => { if (e.target === _safetyOverlay) window.closeSafetyCenter(); });

    document.getElementById('safetyTabBlocked').addEventListener('click', () => { safetyTab = 'blocked'; updateSafetyTabs(); loadSafetyContent(); });
    document.getElementById('safetyTabReports').addEventListener('click', () => { safetyTab = 'reports'; updateSafetyTabs(); loadSafetyContent(); });

    function updateSafetyTabs() {
        document.getElementById('safetyTabBlocked').className = 'flex-1 py-2.5 rounded-full text-sm font-medium ' + (safetyTab === 'blocked' ? 'bg-white text-gray-800 shadow-sm' : 'text-gray-400') + ' transition-all';
        document.getElementById('safetyTabReports').className = 'flex-1 py-2.5 rounded-full text-sm font-medium ' + (safetyTab === 'reports' ? 'bg-white text-gray-800 shadow-sm' : 'text-gray-400') + ' transition-all';
    }

    async function loadSafetyContent() {
        _safetyContent.innerHTML = '<div class="flex items-center justify-center py-20"><span class="loader w-8 h-8 border-2 border-emerald-300 border-t-transparent rounded-full inline-block"></span></div>';
        try {
            if (safetyTab === 'blocked') {
                const data = await EchoAPI.fetchBlockedUsers();
                if (!data || data.length === 0) {
                    _safetyContent.innerHTML = '<p class="text-center text-gray-400 py-20">还没有拉黑任何人</p>';
                } else {
                    _safetyContent.innerHTML = data.map(u => `
                        <div class="blocked-user-card flex items-center gap-3 bg-gray-50 rounded-2xl p-4 cursor-pointer hover:bg-gray-100 active:scale-[0.98] transition-all" data-uid="${u.id}">
                            ${renderAvatar(u.avatar || '🐰', 40)}
                            <div class="flex-1 min-w-0">
                                <p class="text-sm font-medium text-gray-800">${escapeHtml(u.nickname || '')}</p>
                                <p class="text-xs text-gray-400 truncate">${escapeHtml(u.bio || '')}</p>
                            </div>
                            <i data-lucide="chevron-right" class="w-4 h-4 text-gray-300 shrink-0"></i>
                        </div>
                    `).join('');
                    _safetyContent.querySelectorAll('.blocked-user-card').forEach(card => {
                        card.addEventListener('click', () => {
                            const uid = parseInt(card.dataset.uid);
                            closeSafetyCenter();
                            setTimeout(() => openAuthorProfile(uid), 300);
                        });
                    });
                }
            } else {
                const data = await EchoAPI.fetchMyReports();
                if (!data || data.length === 0) {
                    _safetyContent.innerHTML = '<p class="text-center text-gray-400 py-20">还没有举报记录</p>';
                } else {
                    const typeLabel = { diary: '日记', comment: '评论', user: '用户', treehole: '树洞', treehole_reply: '树洞回复' };
                    const reasonLabel = { harassment: '骚扰', spam: '垃圾信息', sexual: '色情/低俗', violence: '暴力/血腥', privacy: '隐私泄露', scam: '诈骗', other: '其他' };
                    const statusClass = {
                        'pending': 'bg-amber-50 text-amber-500',
                        'reviewed': 'bg-blue-50 text-blue-500',
                        'resolved': 'bg-emerald-50 text-emerald-500',
                        'dismissed': 'bg-gray-100 text-gray-400',
                    };
                    _safetyContent.innerHTML = data.map(r => `
                        <div class="bg-gray-50 rounded-2xl p-4 space-y-2">
                            <div class="flex items-center justify-between">
                                <div class="flex items-center gap-2">
                                    <span class="text-xs px-2 py-0.5 rounded-full bg-red-50 text-red-400 font-medium">${typeLabel[r.target_type] || r.target_type}</span>
                                    <span class="text-xs px-2 py-0.5 rounded-full font-medium ${statusClass[r.status] || statusClass['pending']}">${r.status_label || '待处理'}</span>
                                </div>
                                <span class="text-[10px] text-gray-300">${formatDate(r.created_at)}</span>
                            </div>
                            ${r.target_nickname ? `
                            <div class="flex items-center gap-2">
                                <div class="w-6 h-6 rounded-full bg-gradient-to-br from-emerald-50 to-teal-50 flex items-center justify-center text-xs shadow-sm shrink-0 hover:scale-110 active:scale-95 transition-transform report-user-avatar" data-uid="${r.target_user_id}" data-avatar="${escapeHtml(r.target_avatar || '🐰')}" data-name="${escapeHtml(r.target_username || r.target_nickname)}">
                                    ${r.target_avatar && r.target_avatar.startsWith('/') ? '<img src="'+r.target_avatar+'" class="w-full h-full rounded-full object-cover">' : (r.target_avatar || '🐰')}
                                </div>
                                <span class="text-xs text-gray-500 hover:text-emerald-500 transition-colors cursor-pointer report-user-name" data-uid="${r.target_user_id}">@${escapeHtml(r.target_username || r.target_nickname)}</span>
                            </div>` : ''}
                            ${r.target_excerpt ? `<p class="text-xs text-gray-400 bg-white rounded-xl px-3 py-2 line-clamp-2">${escapeHtml(r.target_excerpt)}</p>` : ''}
                            <p class="text-sm text-gray-600">${reasonLabel[r.reason] || r.reason || ''}</p>
                        </div>
                    `).join('');
                    // 举报记录中点击用户头像/名字 → 跳转个人主页
                    _safetyContent.querySelectorAll('.report-user-avatar, .report-user-name').forEach(el => {
                        el.addEventListener('click', () => {
                            const uid = parseInt(el.dataset.uid);
                            closeSafetyCenter();
                            setTimeout(() => openAuthorProfile(uid), 300);
                        });
                    });
                }
            }
        } catch (e) {
            _safetyContent.innerHTML = '<p class="text-center text-gray-400 py-20">加载失败，请稍后再试</p>';
        }
        lucide.createIcons();
    }

    // 暴露给 window 供其他模块调用
    window.openAuthorProfile = openAuthorProfile;

})();
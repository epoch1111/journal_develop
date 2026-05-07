/**
 * Discover View - 发现广场 + 日记详情 + 评论
 */
(function() {
    'use strict';

    // Element references
    const discoverList = document.getElementById('discoverList');
    const discoverLoadMore = document.getElementById('discoverLoadMore');
    const discoverNoMore = document.getElementById('discoverNoMore');
    const discoverEmpty = document.getElementById('discoverEmpty');
    const btnLoadMore = document.getElementById('btnLoadMore');
    const discoverSearch = document.getElementById('discoverSearch');

    // 发现广场详情弹窗
    const discoverDetailOverlay = document.getElementById('discoverDetailOverlay');
    const discDetailContent = document.getElementById('discoverDetailContent');
    const discCommentInput = document.getElementById('discCommentInput');
    const btnDiscCommentSend = document.getElementById('btnDiscCommentSend');
    const discReplyIndicator = document.getElementById('discReplyIndicator');
    const discReplyTargetName = document.getElementById('discReplyTargetName');
    const btnDiscCancelReply = document.getElementById('btnDiscCancelReply');
    const btnCloseDiscDetail = document.getElementById('btnCloseDiscDetail');
    const btnDiscCommentImage = document.getElementById('btnDiscCommentImage');
    const discCommentImageInput = document.getElementById('discCommentImageInput');
    const discCommentThumbnails = document.getElementById('discCommentThumbnails');

    // 筛选条
    const moodFilterBar = document.getElementById('moodFilterBar');
    const tagFilterBar = document.getElementById('tagFilterBar');
    const discoverSearchArea = document.getElementById('discoverSearchArea');

    // 发现页动态类型切换按钮
    const btnFeedAll = document.getElementById('discoverFeedAll');
    const btnFeedFollowing = document.getElementById('discoverFeedFollowing');

    // State variables
    let discFeedMode = 'all'; // 'all' | 'following'
    let discMood = '';
    let discTag = '';
    let discKeyword = '';
    let discPage = 1;
    let discHasMore = false;
    let discItems = []; // 缓存当前列表用于乐观更新
    let discCommentImageUrls = [];  // 评论多图数组

    let discCurrentDiaryId = null;
    let discCurrentData = null;
    // 评论回复模式状态
    let discReplyToCommentId = null;  // 正在回复哪条评论（parent_comment_id）
    let discReplyToUserId = null;     // 回复给谁（reply_to_user_id）
    let discReplyToNickname = '';     // 回复对象的昵称（用于 UI 显示）

    // client_id 生成（点亮去重 + 评论归属）
    let echoClientId = localStorage.getItem('echo_client_id');
    if (!echoClientId) {
        echoClientId = 'echo_browser_' + Date.now() + '_' + Math.random().toString(36).slice(2);
        localStorage.setItem('echo_client_id', echoClientId);
    }

    // 启用筛选条横向拖拽滚动
    if (moodFilterBar) enableHorizontalDragScroll(moodFilterBar);
    if (tagFilterBar)  enableHorizontalDragScroll(tagFilterBar);

    // === 发现页动态类型切换 ===
    window.switchDiscoverFeed = function(mode) {
        discFeedMode = mode;
        if (mode === 'all') {
            btnFeedAll.className = 'flex-1 py-2.5 rounded-xl text-sm font-medium bg-emerald-400 text-white transition-all active:scale-95';
            btnFeedFollowing.className = 'flex-1 py-2.5 rounded-xl text-sm font-medium text-gray-400 transition-all active:scale-95';
            discoverSearchArea.classList.remove('hidden');
            moodFilterBar.classList.remove('hidden');
            tagFilterBar.classList.remove('hidden');
        } else {
            if (!EchoAPI.getToken()) { showAuth('login'); return; }
            btnFeedAll.className = 'flex-1 py-2.5 rounded-xl text-sm font-medium text-gray-400 transition-all active:scale-95';
            btnFeedFollowing.className = 'flex-1 py-2.5 rounded-xl text-sm font-medium bg-emerald-400 text-white transition-all active:scale-95';
            discoverSearchArea.classList.add('hidden');
            moodFilterBar.classList.add('hidden');
            tagFilterBar.classList.add('hidden');
        }
        discPage = 1;
        window.loadDiscover(true);
    };
    btnFeedAll.addEventListener('click', () => window.switchDiscoverFeed('all'));
    btnFeedFollowing.addEventListener('click', () => window.switchDiscoverFeed('following'));

    // === 加载发现页数据 ===
    window.loadDiscover = async function(reset = true) {
        if (reset) { discPage = 1; discoverList.innerHTML = ''; }
        discoverEmpty.classList.add('hidden');
        discoverLoadMore.classList.add('hidden');
        discoverNoMore.classList.add('hidden');

        // 关注动态模式需要登录
        if (discFeedMode === 'following' && !EchoAPI.getToken()) {
            showAuth('login');
            window.switchDiscoverFeed('all');
            return;
        }

        try {
            let data;
            if (discFeedMode === 'following') {
                data = await EchoAPI.fetchFollowingFeed({ page: discPage, page_size: 10 });
            } else {
                data = await EchoAPI.fetchPublicDiaries({
                    page: discPage, page_size: 10,
                    mood: discMood || undefined,
                    tag: discTag || undefined,
                    keyword: discKeyword || undefined,
                    client_id: echoClientId,
                });
            }
            discHasMore = data.has_more;
            if (discPage === 1 && data.items.length === 0) {
                discoverEmpty.classList.remove('hidden');
                const emptyTitle = discoverEmpty.querySelector('.disc-empty-title');
                const emptySub = discoverEmpty.querySelector('.disc-empty-sub');
                if (discKeyword) {
                    if (emptyTitle) emptyTitle.textContent = '没有找到相关公开日记';
                    if (emptySub) emptySub.textContent = '换个关键词、心情或标签试试';
                } else if (discFeedMode === 'following') {
                    if (emptyTitle) emptyTitle.textContent = '关注的人还没有公开日记';
                    if (emptySub) emptySub.textContent = '去发现广场看看吧';
                } else {
                    if (emptyTitle) emptyTitle.textContent = '还没有公开日记';
                    if (emptySub) emptySub.textContent = '成为第一个分享的人吧';
                }
            } else {
                if (discFeedMode === 'following') {
                    window.renderDiscoverFollowingItems(data.items, discPage > 1);
                } else {
                    discItems = data.items;
                    window.renderDiscoverItems(data.items, discPage > 1);
                }
                if (discHasMore) {
                    discoverLoadMore.classList.remove('hidden');
                } else {
                    discoverNoMore.classList.remove('hidden');
                }
            }
        } catch (e) {
            console.error('加载发现页失败:', e);
            discoverList.innerHTML = '<p class="text-center text-gray-400 py-10">加载失败，请稍后再试</p>';
        }
        lucide.createIcons();
    };

    // === 关注动态渲染（简化版，无点赞） ===
    window.renderDiscoverFollowingItems = function(items, append = false) {
        if (!append) discoverList.innerHTML = '';
        items.forEach((d, i) => {
            const moodInfo = MOOD_MAP[d.mood] || MOOD_MAP['😊'];
            const tags = d.tags ? d.tags.split(',').filter(Boolean) : [];
            const tagHtml = tags.map(t => `<span class="text-[10px] px-2 py-0.5 rounded-full bg-gray-100 text-gray-400">#${t.trim()}</span>`).join(' ');
            const card = document.createElement('article');
            card.className = 'bg-white rounded-3xl p-5 shadow-sm card-enter cursor-pointer hover:shadow-md transition-all';
            card.style.animationDelay = `${i * 0.05}s`;
            card.innerHTML = `
                <div class="flex items-center justify-between mb-3">
                    <button class="disc-author-btn flex items-center gap-2 hover:opacity-80 active:scale-95 transition-all" data-user-id="${d.user_id || 1}">
                        ${renderAvatar(d.author_avatar, 22)}
                        <span class="text-xs font-medium text-gray-600">${d.author_name || '小兔'}</span>
                    </button>
                    <div class="flex items-center gap-2">
                        <span class="text-2xl select-none">${d.mood || '📝'}</span>
                        <span class="text-[10px] text-white px-2 py-0.5 rounded-full" style="background:${moodInfo.border}">${moodInfo.label}</span>
                    </div>
                </div>
                <p class="text-[14px] text-gray-600 leading-relaxed mb-3 line-clamp-3">${escapeHtml(d.content || '')}</p>
                ${tagHtml ? `<div class="flex flex-wrap items-center gap-1.5 mb-3">${tagHtml}</div>` : ''}
                <div class="flex items-center justify-between text-xs text-gray-400">
                    <time>${formatDate(d.created_at)}</time>
                    <div class="flex items-center gap-3">
                        <span class="inline-flex items-center gap-1"><i data-lucide="heart" class="w-3.5 h-3.5"></i> ${d.like_count || 0}</span>
                        <span class="inline-flex items-center gap-1"><i data-lucide="message-circle" class="w-3.5 h-3.5"></i> ${d.comment_count || 0}</span>
                    </div>
                </div>
            `;
            card.addEventListener('click', (e) => {
                if (e.target.closest('.disc-author-btn') || e.target.closest('button')) return;
                window.openDiscDetail(d.id);
            });
            const authorBtn = card.querySelector('.disc-author-btn');
            if (authorBtn) authorBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                openAuthorProfile(d.user_id || 1);
            });
            discoverList.appendChild(card);
        });
    };

    // === 公开日记列表渲染 ===
    window.renderDiscoverItems = function(items, append = false) {
        if (!append) discoverList.innerHTML = '';
        items.forEach((d, i) => {
            const moodInfo = MOOD_MAP[d.mood] || MOOD_MAP['😊'];
            const tags = d.tags ? d.tags.split(',').filter(Boolean) : [];
            const tagHtml = tags.map(t => `<span class="text-[10px] px-2 py-0.5 rounded-full bg-gray-100 text-gray-400">#${t.trim()}</span>`).join(' ');
            const liked = !!d.liked;
            const card = document.createElement('article');
            card.className = 'bg-white rounded-3xl p-5 shadow-sm card-enter cursor-pointer hover:shadow-md transition-all';
            card.style.animationDelay = `${i * 0.05}s`;
            card.setAttribute('data-disc-id', d.id);
            card.innerHTML = `
                <div class="flex items-center justify-between mb-3">
                    <button class="disc-author-btn flex items-center gap-2 hover:opacity-80 active:scale-95 transition-all" data-user-id="${d.user_id || 1}">
                        ${renderAvatar(d.author_avatar, 22)}
                        <span class="text-xs font-medium text-gray-600">${d.author_name || '小兔'}</span>
                        ${d.anonymous ? '<span class="text-[10px] text-gray-300">· 匿名</span>' : ''}
                    </button>
                    <div class="flex items-center gap-2">
                        <span class="text-2xl select-none">${d.mood || '📝'}</span>
                        <span class="text-[10px] text-white px-2 py-0.5 rounded-full" style="background:${moodInfo.border}">${moodInfo.label}</span>
                    </div>
                </div>
                ${renderImageGallery(d.image_urls || (d.image_url ? [d.image_url] : []), { maxHeight: 'h-28', objectFit: 'contain' })}
                <p class="text-[14px] text-gray-600 leading-relaxed mb-3 line-clamp-3">${escapeHtml(d.content || '')}</p>
                ${tagHtml ? `<div class="flex flex-wrap items-center gap-1.5 mb-3">${tagHtml}</div>` : ''}
                <div class="flex items-center justify-between text-xs text-gray-400">
                    <time>${formatDate(d.created_at)}</time>
                    <div class="flex items-center gap-3">
                        <button class="disc-like-btn inline-flex items-center gap-1 ${liked ? 'text-pink-400' : 'text-gray-400'} hover:text-pink-400 active:scale-95 transition-all select-none" data-diary-id="${d.id}">
                            <i data-lucide="heart" class="w-3.5 h-3.5 ${liked ? 'fill-pink-400' : ''}"></i>
                            <span class="disc-like-count">${d.like_count || 0}</span>
                        </button>
                        <span class="inline-flex items-center gap-1">
                            <i data-lucide="message-circle" class="w-3.5 h-3.5"></i> ${d.comment_count || 0}
                        </span>
                    </div>
                </div>
            `;
            // 点击卡片 → 打开详情（跳过按钮点击）
            card.addEventListener('click', (e) => {
                if (e.target.closest('.disc-like-btn') || e.target.closest('.disc-author-btn') || e.target.closest('button')) return;
                window.openDiscDetail(d.id);
            });
            // 点击作者 → 打开作者主页
            const authorBtn = card.querySelector('.disc-author-btn');
            if (authorBtn) authorBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                openAuthorProfile(d.user_id || 1);
            });
            // 点亮按钮
            const likeBtn = card.querySelector('.disc-like-btn');
            if (likeBtn) likeBtn.addEventListener('click', async (e) => {
                e.stopPropagation();
                const btn = e.currentTarget;
                const icon = btn.querySelector('i');
                const countSpan = btn.querySelector('.disc-like-count');
                const item = discItems.find(item => item.id === d.id);
                if (!item) return;
                const oldLiked = item.liked;
                const oldCount = item.like_count || 0;
                // 立即变
                item.liked = !oldLiked;
                item.like_count = oldLiked ? oldCount - 1 : oldCount + 1;
                window.renderOneDiscoverCard(d.id, item);
                try {
                    const result = item.liked
                        ? await EchoAPI.likePublicDiary(d.id, echoClientId)
                        : await EchoAPI.unlikePublicDiary(d.id, echoClientId);
                    item.liked = result.liked;
                    item.like_count = result.like_count;
                    window.renderOneDiscoverCard(d.id, item);
                } catch (err) {
                    // 回滚
                    item.liked = oldLiked;
                    item.like_count = oldCount;
                    window.renderOneDiscoverCard(d.id, item);
                    alert('点亮失败: ' + (err.message || err));
                }
            });
            discoverList.appendChild(card);
        });
        lucide.createIcons();
    };

    // === 单卡重渲染（用于点赞乐观更新后刷新单卡） ===
    window.renderOneDiscoverCard = function(diaryId, d) {
        const card = discoverList.querySelector(`[data-disc-id="${diaryId}"]`);
        if (!card) return;
        const moodInfo = MOOD_MAP[d.mood] || MOOD_MAP['😊'];
        const tags = d.tags ? d.tags.split(',').filter(Boolean) : [];
        const tagHtml = tags.map(t => `<span class="text-[10px] px-2 py-0.5 rounded-full bg-gray-100 text-gray-400">#${t.trim()}</span>`).join(' ');
        const liked = !!d.liked;
        const oldCard = card;
        const newCard = document.createElement('article');
        newCard.className = 'bg-white rounded-3xl p-5 shadow-sm card-enter cursor-pointer hover:shadow-md transition-all';
        newCard.setAttribute('data-disc-id', diaryId);
        newCard.innerHTML = `
            <div class="flex items-center justify-between mb-3">
                <button class="disc-author-btn flex items-center gap-2 hover:opacity-80 active:scale-95 transition-all" data-user-id="${d.user_id || 1}">
                    ${renderAvatar(d.author_avatar, 22)}
                    <span class="text-xs font-medium text-gray-600">${d.author_name || '小兔'}</span>
                    ${d.anonymous ? '<span class="text-[10px] text-gray-300">· 匿名</span>' : ''}
                </button>
                <div class="flex items-center gap-2">
                    <span class="text-2xl select-none">${d.mood || '📝'}</span>
                    <span class="text-[10px] text-white px-2 py-0.5 rounded-full" style="background:${moodInfo.border}">${moodInfo.label}</span>
                </div>
            </div>
            ${renderImageGallery(d.image_urls || (d.image_url ? [d.image_url] : []), { maxHeight: 'h-28', objectFit: 'contain' })}
            <p class="text-[14px] text-gray-600 leading-relaxed mb-3 line-clamp-3">${escapeHtml(d.content || '')}</p>
            ${tagHtml ? `<div class="flex flex-wrap items-center gap-1.5 mb-3">${tagHtml}</div>` : ''}
            <div class="flex items-center justify-between text-xs text-gray-400">
                <time>${formatDate(d.created_at)}</time>
                <div class="flex items-center gap-3">
                    <button class="disc-like-btn inline-flex items-center gap-1 ${liked ? 'text-pink-400' : 'text-gray-400'} hover:text-pink-400 active:scale-95 transition-all select-none" data-diary-id="${d.id}">
                        <i data-lucide="heart" class="w-3.5 h-3.5 ${liked ? 'fill-pink-400' : ''}"></i>
                        <span class="disc-like-count">${d.like_count || 0}</span>
                    </button>
                    <span class="inline-flex items-center gap-1">
                        <i data-lucide="message-circle" class="w-3.5 h-3.5"></i> ${d.comment_count || 0}
                    </span>
                </div>
            </div>`;
        // 点击卡片 → 打开详情
        newCard.addEventListener('click', (e) => {
            if (e.target.closest('.disc-like-btn') || e.target.closest('.disc-author-btn') || e.target.closest('button')) return;
            window.openDiscDetail(d.id);
        });
        // 点击作者 → 打开作者主页
        const authorBtn = newCard.querySelector('.disc-author-btn');
        if (authorBtn) authorBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            openAuthorProfile(d.user_id || 1);
        });
        const likeBtn = newCard.querySelector('.disc-like-btn');
        if (likeBtn) likeBtn.addEventListener('click', async (e) => {
            e.stopPropagation();
            const btn = e.currentTarget;
            const icon = btn.querySelector('i');
            const countSpan = btn.querySelector('.disc-like-count');
            const item = discItems.find(item => item.id === d.id);
            if (!item) return;
            const oldLiked = item.liked;
            const oldCount = item.like_count || 0;
            item.liked = !oldLiked;
            item.like_count = oldLiked ? oldCount - 1 : oldCount + 1;
            window.renderOneDiscoverCard(d.id, item);
            try {
                const result = item.liked
                    ? await EchoAPI.likePublicDiary(d.id, echoClientId)
                    : await EchoAPI.unlikePublicDiary(d.id, echoClientId);
                item.liked = result.liked;
                item.like_count = result.like_count;
                window.renderOneDiscoverCard(d.id, item);
            } catch (err) {
                item.liked = oldLiked;
                item.like_count = oldCount;
                window.renderOneDiscoverCard(d.id, item);
                alert('点亮失败: ' + (err.message || err));
            }
        });
        oldCard.replaceWith(newCard);
        lucide.createIcons();
    };

    // === 筛选：心情 ===
    document.querySelectorAll('.discover-mood-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.discover-mood-btn').forEach(b => {
                b.classList.remove('bg-emerald-100', 'text-emerald-600', 'font-medium');
                b.classList.add('bg-gray-100', 'text-gray-400');
            });
            btn.classList.remove('bg-gray-100', 'text-gray-400');
            btn.classList.add('bg-emerald-100', 'text-emerald-600', 'font-medium');
            discMood = btn.dataset.mood;
            window.loadDiscover();
        });
    });

    // === 筛选：标签 ===
    document.querySelectorAll('.discover-tag-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.discover-tag-btn').forEach(b => {
                b.classList.remove('bg-emerald-100', 'text-emerald-600', 'font-medium');
                b.classList.add('bg-gray-100', 'text-gray-400');
            });
            btn.classList.remove('bg-gray-100', 'text-gray-400');
            btn.classList.add('bg-emerald-100', 'text-emerald-600', 'font-medium');
            discTag = btn.dataset.tag;
            window.loadDiscover();
        });
    });

    // === 搜索 ===
    let discSearchTimer;
    discoverSearch.addEventListener('input', () => {
        clearTimeout(discSearchTimer);
        discSearchTimer = setTimeout(() => {
            discKeyword = discoverSearch.value.trim();
            window.loadDiscover();
        }, 300);
    });
    discoverSearch.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            clearTimeout(discSearchTimer);
            discKeyword = discoverSearch.value.trim();
            window.loadDiscover();
        }
    });

    // === 加载更多 ===
    btnLoadMore.addEventListener('click', async () => {
        discPage++;
        await window.loadDiscover(false);
    });

    // === 打开广场详情弹窗 ===
    window.openDiscDetail = function(diaryId) {
        discCurrentDiaryId = diaryId;
        discDetailContent.innerHTML = '<div class="flex items-center justify-center py-20"><span class="loader w-8 h-8 border-2 border-emerald-400 border-t-transparent rounded-full inline-block"></span></div>';
        discCommentInput.value = '';
        window.exitDiscReplyMode();
        discoverDetailOverlay.classList.remove('opacity-0', 'pointer-events-none');
        discoverDetailOverlay.classList.add('opacity-100', 'pointer-events-auto');
        document.body.style.overflow = 'hidden';
        window.loadDiscDetail(diaryId);
        lucide.createIcons();
    };

    // === 加载日记详情 ===
    window.loadDiscDetail = async function(diaryId) {
        try {
            const d = await EchoAPI.fetchPublicDiaryById(diaryId, echoClientId);
            discCurrentData = d;
            window.renderDiscDetail(d);
        } catch (e) {
            console.error('加载广场详情失败:', e);
            discDetailContent.innerHTML = '<p class="text-center text-gray-400 py-20">加载失败</p>';
        }
        lucide.createIcons();
    };

    // === 渲染日记详情 ===
    window.renderDiscDetail = function(d) {
        const moodInfo = MOOD_MAP[d.mood] || MOOD_MAP['😊'];
        const tags = d.tags ? d.tags.split(',').filter(Boolean) : [];
        const tagHtml = tags.map((t, ti) =>
            `<span class="sticker-${ti % 5} text-xs font-medium px-2.5 py-1 rounded-xl shadow-sm">#${t.trim()}</span>`
        ).join(' ');
        const liked = !!d.liked;
        const comments = d.comments || [];
        let totalCommentCount = 0;

        function renderCommentItem(c, isChild = false) {
            const liked = !!c.liked;
            const authorName = escapeHtml(c.author_name || '小兔');
            const authorAvatar = escapeHtml(c.author_avatar || '🐰');
            const userId = c.user_id || 0;
            const replyToName = escapeHtml(c.reply_to_nickname || '');
            const childReplies = c.replies || [];
            totalCommentCount++;

            let html = `
            <div class="disc-comment-item ${isChild ? 'ml-8 pl-3 border-l-2 border-emerald-100' : ''}" data-comment-id="${c.id || 0}" data-user-id="${userId}" data-author-name="${escapeHtml(authorName)}">
                <div class="flex items-start gap-2.5">
                    <button class="disc-comment-author-btn ${isChild ? 'w-7 h-7 text-xs' : 'w-8 h-8 text-sm'} rounded-full bg-gradient-to-br from-emerald-50 to-teal-50 flex items-center justify-center shrink-0 shadow-sm select-none hover:scale-110 active:scale-95 transition-transform" data-user-id="${userId}">${authorAvatar}</button>
                    <div class="${isChild ? 'bg-gray-50/70' : 'bg-gray-50'} rounded-2xl rounded-tl-sm px-4 py-3 flex-1">
                        <div class="flex items-center justify-between mb-1">
                            <div class="flex items-center gap-1.5">
                                <button class="disc-comment-author-btn text-[11px] font-medium text-gray-500 hover:text-emerald-500 transition-colors" data-user-id="${userId}">${authorName}</button>
                                ${c.is_author ? '<span class="text-[9px] px-1.5 py-px rounded-full bg-amber-100 text-amber-600 font-medium ml-0.5">作者</span>' : ''}
                                ${replyToName ? `<span class="text-[10px] text-emerald-400">回复 ${replyToName}</span>` : ''}
                                <span class="text-[10px] text-gray-300">· ${formatDate(c.created_at)}</span>
                            </div>
                            <div class="flex items-center gap-1.5">
                                <button class="disc-comment-reply-btn text-[10px] text-gray-300 hover:text-emerald-400 transition-colors"
                                    data-comment-id="${c.id || 0}" data-user-id="${userId}" data-author-name="${escapeHtml(authorName)}">
                                    回复
                                </button>
                                <button class="disc-comment-report-btn inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-gray-50 text-gray-400 text-[10px] hover:bg-red-50 hover:text-red-400 active:scale-95 transition-all select-none" data-comment-id="${c.id || 0}"><i data-lucide="flag" class="w-3 h-3"></i>举报</button>
                            </div>
                        </div>
                        <p class="text-[13px] text-gray-600 leading-relaxed mb-1.5">${escapeHtml(c.content)}</p>
                        ${(c.image_urls && c.image_urls.length) ? `<div class="flex flex-wrap gap-1 mb-2">${c.image_urls.map(u => `<img src="${escapeHtml(u)}" class="w-20 h-20 rounded-xl object-contain shadow-sm bg-gray-50 cursor-pointer gallery-img" data-gallery="${btoa(encodeURIComponent(JSON.stringify(c.image_urls)))}" data-idx="${c.image_urls.indexOf(u)}" alt="">`).join('')}</div>` : ''}
                        <div class="flex items-center justify-end">
                            <button class="disc-comment-like-btn inline-flex items-center gap-0.5 text-[10px] ${liked ? 'text-pink-400' : 'text-gray-300'} hover:text-pink-400 transition-colors" data-comment-id="${c.id || 0}">
                                <i data-lucide="heart" class="w-3 h-3 ${liked ? 'fill-pink-400' : ''}"></i>
                                <span class="disc-comment-like-count">${c.like_count || 0}</span>
                            </button>
                        </div>
                    </div>
                </div>
            </div>`;

            // 子回复（二级，递归渲染）
            if (childReplies.length > 0) {
                html += '<div class="mt-2">';
                childReplies.forEach(cr => { html += renderCommentItem(cr, true); });
                html += '</div>';
            }
            return html;
        }

        let commentHtml = '';
        comments.forEach(c => { commentHtml += renderCommentItem(c, false); });

        discDetailContent.innerHTML = `
            <div class="flex items-center justify-between mb-4">
                <button class="disc-detail-author-btn flex items-center gap-2 hover:opacity-80 active:scale-95 transition-all" data-user-id="${d.user_id || 1}">
                    ${renderAvatar(d.author_avatar, 22)}
                    <span class="text-sm font-medium text-gray-600">${d.author_name || '小兔'}</span>
                </button>
                <div class="flex items-center gap-2">
                    <span class="text-3xl select-none">${d.mood || '📝'}</span>
                    <span class="text-[11px] text-white px-2 py-0.5 rounded-full" style="background:${moodInfo.border}">${moodInfo.label}</span>
                </div>
            </div>
            ${renderImageGallery(d.image_urls || (d.image_url ? [d.image_url] : []), { maxHeight: 'h-32', objectFit: 'contain' })}
            <p class="text-[15px] text-gray-700 leading-relaxed mb-4 whitespace-pre-wrap">${escapeHtml(d.content || '')}</p>
            ${d.ai_message ? `
            <div class="flex items-start gap-2.5 mb-4">
                <div class="w-8 h-8 rounded-full bg-gradient-to-br from-amber-100 to-amber-200 flex items-center justify-center text-lg shrink-0 shadow-sm select-none">🐰</div>
                <div class="relative bubble-left bg-[#F2F7F5] border border-emerald-100 rounded-2xl rounded-tl-sm px-4 py-3 shadow-sm flex-1">
                    <p class="text-[13px] text-gray-600 leading-relaxed">${escapeHtml(d.ai_message || '')}</p>
                    ${d.ai_summary ? `<p class="text-[11px] text-gray-400 mt-1.5 italic">📌 ${escapeHtml(d.ai_summary)}</p>` : ''}
                </div>
            </div>` : ''}
            ${tagHtml ? `<div class="flex flex-wrap gap-2 mb-4">${tagHtml}</div>` : ''}
            <time class="text-xs text-gray-400 block mb-4">${formatDate(d.created_at)}</time>
            <!-- 操作栏 -->
            <div class="flex items-center gap-4 mb-6 pt-3 border-t border-gray-50">
                <button id="discDetailLikeBtn" class="inline-flex items-center gap-1.5 px-4 py-2 rounded-full ${liked ? 'bg-pink-50 text-pink-400' : 'bg-gray-50 text-gray-400'} text-sm font-medium hover:bg-pink-50 hover:text-pink-400 active:scale-95 transition-all select-none">
                    <i data-lucide="heart" class="w-4 h-4 ${liked ? 'fill-pink-400' : ''}"></i>
                    <span id="discDetailLikeCount">${d.like_count || 0}</span>
                </button>
                <span class="inline-flex items-center gap-1 text-sm text-gray-400">
                    <i data-lucide="message-circle" class="w-4 h-4"></i> ${totalCommentCount} 条评论
                </span>
            </div>
            <!-- 评论列表 -->
            ${commentHtml ? `<div class="space-y-3 mb-4">${commentHtml}</div>` : '<p class="text-center text-gray-300 text-sm py-4">还没有评论，来写第一条吧</p>'}
        `;

        // 详情中作者按钮 + 评论人按钮（事件委托）
        discDetailContent.addEventListener('click', (e) => {
            const authorBtn = e.target.closest('.disc-detail-author-btn, .disc-comment-author-btn');
            if (authorBtn) {
                const uid = authorBtn.dataset.userId;
                if (uid && parseInt(uid) > 0) openAuthorProfile(parseInt(uid));
            }
        });

        // 详情中点亮按钮
        document.getElementById('discDetailLikeBtn').addEventListener('click', async () => {
            const btn = document.getElementById('discDetailLikeBtn');
            const cnt = document.getElementById('discDetailLikeCount');
            const icon = btn.querySelector('i');
            const liked = btn.classList.contains('bg-pink-50');
            try {
                let result;
                if (liked) {
                    result = await EchoAPI.unlikePublicDiary(d.id, echoClientId);
                    btn.className = btn.className.replace('bg-pink-50 text-pink-400', 'bg-gray-50 text-gray-400');
                    if (icon) icon.classList.remove('fill-pink-400');
                } else {
                    result = await EchoAPI.likePublicDiary(d.id, echoClientId);
                    btn.className = btn.className.replace('bg-gray-50 text-gray-400', 'bg-pink-50 text-pink-400');
                    if (icon) icon.classList.add('fill-pink-400');
                }
                cnt.textContent = result.like_count || 0;
            } catch (e) { console.error('点亮失败:', e); }
        });

        lucide.createIcons();
    };

    // === 关闭详情弹窗 ===
    window.closeDiscDetail = function() {
        discoverDetailOverlay.classList.add('opacity-0', 'pointer-events-none');
        discoverDetailOverlay.classList.remove('opacity-100', 'pointer-events-auto');
        document.body.style.overflow = '';
        discCurrentDiaryId = null;
        discCurrentData = null;
        window.exitDiscReplyMode();
        clearDiscCommentImages();
    };
    btnCloseDiscDetail.addEventListener('click', window.closeDiscDetail);
    discoverDetailOverlay.addEventListener('click', (e) => { if (e.target === discoverDetailOverlay) window.closeDiscDetail(); });

    // === 退出回复模式 ===
    window.exitDiscReplyMode = function() {
        discReplyToCommentId = null;
        discReplyToUserId = null;
        discReplyToNickname = '';
        discReplyIndicator.classList.add('hidden');
        discCommentInput.placeholder = '写一句温柔的回应吧';
        clearDiscCommentImages();
    };
    btnDiscCancelReply.addEventListener('click', window.exitDiscReplyMode);

    // === 发送评论（支持回复模式） ===
    btnDiscCommentSend.addEventListener('click', async () => {
        const content = discCommentInput.value.trim();
        if (!content && !discCommentImageUrls.length) return;
        if (!discCurrentDiaryId) return;
        btnDiscCommentSend.disabled = true;
        try {
            const body = { client_id: echoClientId, content };
            if (discReplyToCommentId) {
                body.parent_comment_id = discReplyToCommentId;
                body.reply_to_user_id = discReplyToUserId;
            }
            if (discCommentImageUrls.length) body.image_urls = discCommentImageUrls;
            await EchoAPI.commentPublicDiary(discCurrentDiaryId, body);
            discCommentInput.value = '';
            clearDiscCommentImages();
            window.exitDiscReplyMode();
            await window.loadDiscDetail(discCurrentDiaryId);
        } catch (e) {
            console.error('评论失败:', e);
            alert('评论失败，请稍后再试～');
        } finally {
            btnDiscCommentSend.disabled = false;
        }
    });
    discCommentInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') btnDiscCommentSend.click();
    });

    // === 评论多图上传 ===
    function renderDiscCommentThumbnails() {
        if (!discCommentThumbnails) return;
        if (discCommentImageUrls.length === 0) {
            discCommentThumbnails.classList.add('hidden');
            discCommentThumbnails.innerHTML = '';
            return;
        }
        discCommentThumbnails.classList.remove('hidden');
        discCommentThumbnails.innerHTML = discCommentImageUrls.map((url, i) => `
            <div class="relative">
                <img src="${escapeHtml(url)}" class="w-16 h-16 rounded-xl object-cover shadow-sm border border-gray-100">
                <button class="disc-img-remove absolute -top-1 -right-1 w-5 h-5 rounded-full bg-gray-700/80 text-white text-[10px] flex items-center justify-center hover:bg-gray-800" data-index="${i}">
                    <i data-lucide="x" class="w-2.5 h-2.5"></i>
                </button>
            </div>
        `).join('');
        if (typeof lucide !== 'undefined' && lucide.createIcons) lucide.createIcons();
    }

    function removeDiscCommentImage(index) {
        discCommentImageUrls.splice(index, 1);
        renderDiscCommentThumbnails();
    }

    function clearDiscCommentImages() {
        discCommentImageUrls = [];
        renderDiscCommentThumbnails();
    }

    if (btnDiscCommentImage) {
        btnDiscCommentImage.addEventListener('click', () => discCommentImageInput.click());
    }
    if (discCommentImageInput) {
        discCommentImageInput.addEventListener('change', async () => {
            const files = Array.from(discCommentImageInput.files);
            if (!files.length) return;
            discCommentImageInput.disabled = true;
            try {
                for (const file of files) {
                    const blob = await compressImage(file);
                    const uploaded = await EchoAPI.uploadImage(blob);
                    discCommentImageUrls.push(uploaded.url);
                }
                renderDiscCommentThumbnails();
            } catch (e) {
                console.error('图片上传失败:', e);
                alert('图片上传失败，请重试～');
            }
            discCommentImageInput.value = '';
            discCommentImageInput.disabled = false;
        });
    }
    // 事件委托：删除图片
    if (discCommentThumbnails) {
        discCommentThumbnails.addEventListener('click', (e) => {
            const btn = e.target.closest('.disc-img-remove');
            if (btn) removeDiscCommentImage(parseInt(btn.dataset.index));
        });
    }

    // === 评论回复/点赞按钮：事件委托 ===
    discDetailContent.addEventListener('click', async (e) => {
        const replyBtn = e.target.closest('.disc-comment-reply-btn');
        if (replyBtn) {
            e.stopPropagation();
            const commentId = parseInt(replyBtn.dataset.commentId);
            const userId = parseInt(replyBtn.dataset.userId);
            const authorName = replyBtn.dataset.authorName || '';
            if (commentId) {
                discReplyToCommentId = commentId;
                discReplyToUserId = userId || null;
                discReplyToNickname = authorName;
                discReplyTargetName.textContent = authorName;
                discReplyIndicator.classList.remove('hidden');
                discCommentInput.placeholder = `回复 ${authorName}…`;
                discCommentInput.focus();
            }
        }

        const likeBtn = e.target.closest('.disc-comment-like-btn');
        if (likeBtn) {
            e.stopPropagation();
            const commentId = parseInt(likeBtn.dataset.commentId);
            if (!commentId) return;
            const liked = likeBtn.classList.contains('text-pink-400');
            try {
                if (liked) {
                    await EchoAPI.unlikeComment(commentId);
                } else {
                    await EchoAPI.likeComment(commentId);
                }
                // 重新加载评论列表以获取最新 like_count 和 liked 状态
                if (discCurrentDiaryId && discCurrentData) {
                    const updatedComments = await EchoAPI.fetchPublicDiaryComments(discCurrentDiaryId);
                    if (Array.isArray(updatedComments)) {
                        discCurrentData.comments = updatedComments;
                        const detailHtml = window.renderDiscDetail(discCurrentData);
                        if (detailHtml) {
                            discDetailContent.innerHTML = detailHtml;
                        }
                    }
                }
            } catch (err) {
                const msg = (err && err.message) || String(err);
                console.error('评论点赞失败:', err, msg);
                alert('点赞失败: ' + msg);
            }
        }
    });

    // === 打开发布公开日记弹窗 ===
    window.openPublicCompose = function() {
        resetModal();
        window.composeMode = 'public';
        writingPrompt.textContent = '🫧 分享你的心情，让更多人感受到～';
        openModal();
    };

    // ===== 覆盖 renderDiscDetail（添加举报按钮） =====
    const _origRenderDiscDetail = window.renderDiscDetail;
    window.renderDiscDetail = function(d) {
        _origRenderDiscDetail(d);
        // 同步添加举报按钮（innerHTML 已设置，opBar 已在 DOM 中）
        if (!discDetailContent.querySelector('#discDetailReportBtn')) {
            const opBar = discDetailContent.querySelector('.border-t.border-gray-50');
            if (opBar) {
                const reportBtn = document.createElement('button');
                reportBtn.id = 'discDetailReportBtn';
                reportBtn.className = 'inline-flex items-center gap-1 px-3 py-1.5 rounded-full bg-gray-50 text-gray-400 text-xs hover:bg-red-50 hover:text-red-400 active:scale-95 transition-all select-none ml-auto';
                reportBtn.innerHTML = '<i data-lucide="flag" class="w-3.5 h-3.5"></i> 举报';
                reportBtn.addEventListener('click', () => {
                    openReportModal('diary', d.id, `举报日记 #${d.id}`);
                });
                opBar.appendChild(reportBtn);
                if (typeof lucide !== 'undefined' && lucide.createIcons) lucide.createIcons();
            }
        }
    };

    // ===== 评论举报通过事件委托处理 =====
    discDetailContent.addEventListener('click', (e) => {
        const reportBtn = e.target.closest('.disc-comment-report-btn');
        if (reportBtn) {
            e.stopPropagation();
            const commentId = parseInt(reportBtn.dataset.commentId);
            if (commentId) openReportModal('comment', commentId, `举报评论 #${commentId}`);
        }
    });

})();
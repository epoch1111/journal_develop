/**
 * Echo 日记 - 组件渲染层
 * 统一的卡片工厂函数，消除所有重复渲染逻辑
 */

/**
 * 生成公开日记卡片 DOM 元素
 * 供发现页、关注动态等所有公开日记卡片使用
 *
 * @param {Object} d - 日记数据
 * @param {Object} opts - 配置
 * @param {number}   opts.index          - 列表索引（用于动画延迟）
 * @param {Function} opts.onDetail       - 点击卡片回调 (diaryId)
 * @param {Function} opts.onAuthor       - 点击作者回调 (userId)
 * @param {Function} opts.onLike        - 点击点赞回调 (diaryId, btn, icon, countSpan)
 * @param {boolean}  opts.isDetail      - 是否详情模式（不显示「阅读更多」等）
 */
function createPublicDiaryCard(d, opts) {
    opts = opts || {};
    const idx = opts.index || 0;
    const moodInfo = (typeof MOOD_MAP !== 'undefined' ? MOOD_MAP[d.mood] : null) || { label: '分享', border: '#9CA3AF' };
    const tags = d.tags ? d.tags.split(',').filter(Boolean) : [];
    const tagHtml = tags.map(t => `<span class="text-[10px] px-2 py-0.5 rounded-full bg-gray-100 text-gray-400">#${t.trim()}</span>`).join(' ');
    const liked = !!d.liked;
    const imageUrls = d.image_urls || (d.image_url ? [d.image_url] : []);

    const card = document.createElement('article');
    card.className = 'bg-white rounded-3xl p-5 shadow-sm card-enter cursor-pointer hover:shadow-md transition-all';
    card.style.animationDelay = `${idx * 0.05}s`;
    card.setAttribute('data-disc-id', d.id);

    const imgHtml = (typeof renderImageGallery !== 'undefined')
        ? renderImageGallery(imageUrls, { maxHeight: 'h-28', objectFit: 'contain' })
        : '';

    card.innerHTML = `
        <div class="flex items-center justify-between mb-3">
            <button class="disc-author-btn flex items-center gap-2 hover:opacity-80 active:scale-95 transition-all" data-user-id="${d.user_id || 1}">
                <span class="w-5.5 h-5.5 rounded-full bg-gradient-to-br from-emerald-100 to-teal-100 flex items-center justify-center text-base shrink-0 select-none">${escapeHtml(d.author_avatar || '🐰')}</span>
                <span class="text-xs font-medium text-gray-600">${escapeHtml(d.author_name || '小兔')}</span>
                ${d.anonymous ? '<span class="text-[10px] text-gray-300">· 匿名</span>' : ''}
            </button>
            <div class="flex items-center gap-2">
                <span class="text-2xl select-none">${d.mood || '📝'}</span>
                <span class="text-[10px] text-white px-2 py-0.5 rounded-full" style="background:${moodInfo.border}">${moodInfo.label}</span>
            </div>
        </div>
        ${imgHtml}
        <p class="text-[14px] text-gray-600 leading-relaxed mb-3 line-clamp-3">${escapeHtml(d.content || '')}</p>
        ${tagHtml ? `<div class="flex flex-wrap items-center gap-1.5 mb-3">${tagHtml}</div>` : ''}
        <div class="flex items-center justify-between text-xs text-gray-400">
            <time>${formatDate(d.created_at)}</time>
            <div class="flex items-center gap-3">
                ${opts.onLike ? `<button class="disc-like-btn inline-flex items-center gap-1 ${liked ? 'text-pink-400' : 'text-gray-400'} hover:text-pink-400 active:scale-95 transition-all select-none" data-diary-id="${d.id}">
                    <i data-lucide="heart" class="w-3.5 h-3.5 ${liked ? 'fill-pink-400' : ''}"></i>
                    <span class="disc-like-count">${d.like_count || 0}</span>
                </button>` : `<span class="inline-flex items-center gap-1 text-gray-400"><i data-lucide="heart" class="w-3.5 h-3.5"></i> ${d.like_count || 0}</span>`}
                <span class="inline-flex items-center gap-1"><i data-lucide="message-circle" class="w-3.5 h-3.5"></i> ${d.comment_count || 0}</span>
            </div>
        </div>`;

    // 点击卡片 → 打开详情
    card.addEventListener('click', (e) => {
        if (e.target.closest('.disc-like-btn') || e.target.closest('.disc-author-btn') || e.target.closest('button')) return;
        if (opts.onDetail) opts.onDetail(d.id);
    });

    // 点击作者
    const authorBtn = card.querySelector('.disc-author-btn');
    if (authorBtn) authorBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        if (opts.onAuthor) opts.onAuthor(d.user_id || 1);
    });

    // 点击点赞
    if (opts.onLike) {
        const likeBtn = card.querySelector('.disc-like-btn');
        if (likeBtn) likeBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            opts.onLike(d.id);
        });
    }

    return card;
}

/**
 * 生成日记卡片内部 HTML（不含外层 article 标签）
 * 用于已解锁胶囊和普通日记的内容区域
 */
function renderDiaryCardInner(d) {
    const tags = d.tags ? d.tags.split(',').filter(Boolean) : [];
    const tagHtml = tags.map((t, ti) => `
        <span class="sticker-${ti % 5} text-xs font-medium px-2.5 py-1 rounded-xl shadow-sm select-none">#${t.trim()}</span>
    `).join('');
    const moodInfo = MOOD_MAP[d.mood] || MOOD_MAP['😊'];
    const isPublicDiary = !!(d.is_public);
    const hugCount = d.hug_count || 0;
    const hugBadge = (isPublicDiary && hugCount > 0) ? `
        <span class="inline-flex items-center gap-1 bg-red-50 text-red-400 px-2 py-1 rounded-full text-[11px] font-medium">
            ❤️ 收到了 ${hugCount} 个抱抱
        </span>` : '';
    // 已解锁时光胶囊徽章
    const unlockDate = d.unlock_date || '';
    const daysLeft = unlockDate ? calculateDaysLeft(unlockDate) : null;
    const isUnlockedCapsule = (unlockDate && daysLeft !== null && daysLeft <= 0);
    const capsuleBadge = isUnlockedCapsule ? `
        <span class="inline-flex items-center gap-1 bg-yellow-100 text-yellow-700 px-2 py-1 rounded-full text-[11px] font-bold">
            🕰️ 时光胶囊已解锁
        </span>` : '';
    return `
        <div class="flex items-start justify-between mb-3">
            <div class="flex items-center gap-2">
                <span class="text-3xl select-none">${d.mood || '📝'}</span>
                <span class="text-[11px] text-white px-2 py-0.5 rounded-full" style="background:${moodInfo.border}">${moodInfo.label}</span>
            </div>
            <div class="flex items-center gap-2">
                ${capsuleBadge}
                ${hugBadge}
                <time class="text-xs text-gray-400 mt-1">${formatDate(d.created_at)}</time>
            </div>
        </div>
        ${d.image_url ? `<img src="${escapeHtml(d.image_url)}" class="w-full h-48 object-contain rounded-2xl mb-3 shadow-sm border border-gray-50" alt="日记图片">` : ''}
        <p class="text-[15px] text-gray-700 leading-relaxed mb-4 whitespace-pre-wrap">${escapeHtml(d.content)}</p>
        <div class="flex items-start gap-2.5">
            <div class="w-8 h-8 rounded-full bg-gradient-to-br from-amber-100 to-amber-200 flex items-center justify-center text-lg shrink-0 shadow-sm select-none">🐰</div>
            <div class="relative bubble-left bg-white border border-gray-100 rounded-2xl rounded-tl-sm px-4 py-3 shadow-sm flex-1">
                <p class="text-[13px] text-gray-600 leading-relaxed">${escapeHtml(d.ai_message || '感谢你的分享～')}</p>
                ${d.ai_summary ? `<p class="text-[11px] text-gray-400 mt-1.5 italic">📌 ${escapeHtml(d.ai_summary)}</p>` : ''}
            </div>
        </div>
        ${tags.length ? `<div class="flex flex-wrap gap-2 mt-3 ml-11">${tagHtml}</div>` : ''}
        <div class="flex items-center justify-end gap-2 mt-4 pt-3 border-t border-gray-50">
            <button class="diary-action-edit inline-flex items-center gap-1 px-3 py-1.5 rounded-full bg-gray-50 text-gray-400 text-xs hover:bg-emerald-50 hover:text-emerald-500 active:scale-95 transition-all select-none" data-diary-id="${d.id}">
                <i data-lucide="pencil" class="w-3.5 h-3.5"></i> 编辑
            </button>
            <button class="diary-action-delete inline-flex items-center gap-1 px-3 py-1.5 rounded-full bg-gray-50 text-gray-400 text-xs hover:bg-red-50 hover:text-red-400 active:scale-95 transition-all select-none" data-diary-id="${d.id}">
                <i data-lucide="trash-2" class="w-3.5 h-3.5"></i> 删除
            </button>
        </div>
    `;
}

/**
 * 终极卡片工厂函数
 * 根据日记数据自动判断 3 种状态并返回对应的 DOM 元素
 *
 * @param {Object} d - 日记数据对象
 * @param {Object} options - 可选配置
 * @param {number} options.index - 用于入场动画延迟 (默认 0)
 * @param {number} options.animationDelay - 每项延迟秒数 (默认 0.08)
 * @returns {HTMLElement} article 元素，已附加事件监听器
 */
function createDiaryCard(d, options = {}) {
    const idx = options.index || 0;
    const delay = options.animationDelay || 0.08;
    const unlockDate = d.unlock_date || '';
    const daysLeft = unlockDate ? calculateDaysLeft(unlockDate) : null;
    const isLocked = (unlockDate && daysLeft !== null && daysLeft > 0);

    const card = document.createElement('article');
    card.style.animationDelay = `${idx * delay}s`;

    if (isLocked) {
        // 状态 1：未到期的时光胶囊 — 锁定 UI
        card.className = 'bg-gradient-to-br from-indigo-50 to-purple-100 rounded-[2.5rem] p-6 shadow-sm card-enter flex flex-col items-center justify-center min-h-[160px] cursor-pointer select-none';
        card.innerHTML = `
            <i data-lucide="lock" class="w-10 h-10 text-indigo-300 mb-3" style="stroke-width:1.5"></i>
            <p class="text-sm font-medium text-indigo-400 mb-1">一封寄往 <span class="text-indigo-500 font-semibold">${unlockDate}</span> 的信</p>
            <p class="text-xs text-indigo-300">距离拆封还有 <span class="font-semibold text-indigo-400">${daysLeft}</span> 天</p>
        `;
        card.addEventListener('click', () => shakeCard(card));
    } else {
        // 状态 2 & 3：已解锁胶囊 / 普通日记 — 正常卡片
        const moodInfo = MOOD_MAP[d.mood] || MOOD_MAP['😊'];
        card.className = `bg-white rounded-3xl p-5 shadow-sm card-enter border-l-4 ${moodInfo.stripeClass} cursor-pointer hover:shadow-md transition-shadow`;
        card.innerHTML = renderDiaryCardInner(d);
        card.addEventListener('click', (e) => {
            // 如果点击的是编辑/删除按钮，不触发详情弹窗
            if (e.target.closest('.diary-action-edit') || e.target.closest('.diary-action-delete')) return;
            if (typeof openDetailModal === 'function') openDetailModal(d.id);
        });
        // 编辑按钮
        const editBtn = card.querySelector('.diary-action-edit');
        if (editBtn) editBtn.addEventListener('click', () => {
            if (typeof openDetailModal === 'function') openDetailModal(d.id, true);
        });
        // 删除按钮
        const deleteBtn = card.querySelector('.diary-action-delete');
        if (deleteBtn) deleteBtn.addEventListener('click', () => {
            if (typeof deleteDiaryDirect === 'function') deleteDiaryDirect(d.id);
        });
    }

    return card;
}

/**
 * 渲染心情统计条
 */
function renderMoodStats(diaries) {
    const bar = document.getElementById('moodStatsBar');
    const content = document.getElementById('moodStatsContent');
    if (!diaries || diaries.length === 0) {
        bar.classList.add('hidden');
        return;
    }
    const dist = {};
    diaries.forEach(d => { const m = d.mood; dist[m] = (dist[m] || 0) + 1; });
    const total = diaries.length;
    let html = '';
    for (const [mood, count] of Object.entries(dist)) {
        const pct = Math.round((count / total) * 100);
        const info = MOOD_MAP[mood] || MOOD_MAP['😊'];
        html += `<span class="text-xs shrink-0">${mood}</span>`;
        html += `<div class="flex-1 h-1.5 rounded-full bg-gray-100 min-w-[20px]"><div class="h-1.5 rounded-full" style="width:${pct}%;background:${info.border}"></div></div>`;
        html += `<span class="text-[10px] text-gray-400 shrink-0">${pct}%</span>`;
    }
    content.innerHTML = html;
    bar.classList.remove('hidden');
}

// 暴露工厂函数供其他模块使用
window.createPublicDiaryCard = createPublicDiaryCard;

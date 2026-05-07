/**
 * Treehole View - 树洞 + 投递 + 详情弹窗
 */
(function() {
    'use strict';

    // 注入抱抱动画样式
    (function() {
        if (document.getElementById('hug-animate-style')) return;
        const style = document.createElement('style');
        style.id = 'hug-animate-style';
        style.textContent = '@keyframes hug-pop{0%{transform:scale(1)}50%{transform:scale(1.4)}100%{transform:scale(1)}} .hug-animate{animation:hug-pop 0.5s ease-out}';
        document.head.appendChild(style);
    })();

    // ===== DOM 元素引用 =====
    const treeholeCard = document.getElementById('treeholeCard');
    const treeholeEmpty = document.getElementById('treeholeEmpty');
    const treeholeMood = document.getElementById('treeholeMood');
    const treeholeContent = document.getElementById('treeholeContent');
    const btnHug = document.getElementById('btnHug');
    const btnTreeholeReply = document.getElementById('btnTreeholeReply');
    const btnTreeholeReport = document.getElementById('btnTreeholeReport');
    const btnTreeholeSend = document.getElementById('btnTreeholeSend');
    const btnRefresh = document.getElementById('btnRefresh');
    const treeholeComposeOverlay = document.getElementById('treeholeComposeOverlay');
    const treeholeComposeContent = document.getElementById('treeholeComposeContent');
    const treeholeMoodBtns = document.querySelectorAll('.treehole-mood-btn');
    const btnSubmitTreehole = document.getElementById('btnSubmitTreehole');
    const btnTreeholePickImage = document.getElementById('btnTreeholePickImage');
    const treeholeImageFileInput = document.getElementById('treeholeImageFileInput');
    const treeholeImagePreviewArea = document.getElementById('treeholeImagePreviewArea');
    const treeholeImageThumbnails = document.getElementById('treeholeImageThumbnails');
    const treeholeImageUploadStatus = document.getElementById('treeholeImageUploadStatus');
    const btnCloseTreeholeCompose = document.getElementById('btnCloseTreeholeCompose');
    const treeholeDetailOverlay = document.getElementById('treeholeDetailOverlay');
    const treeholeDetailContent = document.getElementById('treeholeDetailContent');
    const btnCloseTreeholeDetail = document.getElementById('btnCloseTreeholeDetail');
    const treeholeReplyInput = document.getElementById('treeholeReplyInput');
    const btnTreeholeDetailReport = document.getElementById('btnTreeholeDetailReport');
    const btnThCancelReply = document.getElementById('btnThCancelReply');
    const btnThDetailReplySend = document.getElementById('btnThDetailReplySend');
    const thReplyIndicator = document.getElementById('thReplyIndicator');
    const thDetailReplyInput = document.getElementById('thDetailReplyInput');
    const btnThDetailImage = document.getElementById('btnThDetailImage');
    const thDetailImageInput = document.getElementById('thDetailImageInput');
    const thDetailThumbnails = document.getElementById('thDetailThumbnails');

    let treeholeImageUrls = [];
    let currentTreeholeDiaryId = null;
    let currentTreeholeHugged = false;
    let thDetailCurrentId = null;
    let currentTreeholeDetailData = null;
    let thReplyToReplyId = null;
    let thReplyToIdentityId = null;
    let thReplyToAnonName = '';
    let thDetailCommentImageUrls = [];

    // client_id 生成（点亮去重）
    let echoClientId = localStorage.getItem('echo_client_id');
    if (!echoClientId) {
        echoClientId = 'echo_browser_' + Date.now() + '_' + Math.random().toString(36).slice(2);
        localStorage.setItem('echo_client_id', echoClientId);
    }

    // ===== 树洞投递模态框 =====

    window.openTreeholeCompose = function() {
        treeholeComposeContent.value = '';
        treeholeMoodBtns.forEach(b => b.classList.remove('active'));
        treeholeMoodBtns[0].classList.add('active');
        btnSubmitTreehole.disabled = false;
        btnSubmitTreehole.innerHTML = '<i data-lucide="send" class="w-5 h-5"></i> 匿名投递';
        treeholeComposeOverlay.classList.remove('opacity-0', 'pointer-events-none');
        treeholeComposeOverlay.classList.add('opacity-100', 'pointer-events-auto');
        treeholeComposeContent.focus();
        lucide.createIcons();
    };

    window.closeTreeholeCompose = function() {
        treeholeComposeOverlay.classList.add('opacity-0', 'pointer-events-none');
        treeholeComposeOverlay.classList.remove('opacity-100', 'pointer-events-auto');
        treeholeImageUrls = [];
        treeholeImagePreviewArea.classList.add('hidden');
        treeholeImageUploadStatus.classList.add('hidden');
    };

    window.renderTreeholeThumbnails = function() {
        treeholeImageThumbnails.innerHTML = treeholeImageUrls.map((url, i) => `
            <div class="relative inline-block">
                <img src="${url}" class="h-20 rounded-xl object-cover shadow-sm border border-gray-100" alt="">
                <button class="treehole-img-remove-btn absolute -top-1.5 -right-1.5 w-5 h-5 rounded-full bg-gray-700/70 text-white text-[10px] flex items-center justify-center hover:bg-gray-800/80 active:scale-95 transition-all" data-index="${i}">
                    <i data-lucide="x" class="w-3 h-3"></i>
                </button>
            </div>
        `).join('');
        if (treeholeImageUrls.length > 0) {
            treeholeImagePreviewArea.classList.remove('hidden');
            btnTreeholePickImage.innerHTML = '<i data-lucide="image" class="w-4 h-4"></i> 继续添加';
        } else {
            treeholeImagePreviewArea.classList.add('hidden');
            btnTreeholePickImage.innerHTML = '<i data-lucide="image" class="w-4 h-4"></i> 添加图片';
        }
        treeholeImageThumbnails.querySelectorAll('.treehole-img-remove-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const idx = parseInt(btn.dataset.index);
                treeholeImageUrls.splice(idx, 1);
                renderTreeholeThumbnails();
            });
        });
    };

    // ===== 树洞 =====

    window.loadTreehole = async function() {
        try {
            const data = await EchoAPI.fetchTreeholeRandom();
            if (data === null) {
                currentTreeholeDiaryId = null;
                treeholeCard.classList.add('hidden');
                treeholeEmpty.classList.remove('hidden');
            } else {
                currentTreeholeDiaryId = data.id;
                currentTreeholeHugged = !!data.is_hugged;
                treeholeCard.classList.remove('hidden');
                treeholeEmpty.classList.add('hidden');
                treeholeCard.classList.remove('drift-enter');
                void treeholeCard.offsetWidth;
                treeholeCard.classList.add('drift-enter');
                treeholeMood.textContent = data.mood || '🥰';
                treeholeContent.textContent = data.content || '';
                // 卡片缩略图
                const imgEl = document.getElementById('treeholeCardImage');
                const urls = data.image_urls || [];
                if (urls.length > 0) {
                    imgEl.src = urls[0];
                    imgEl.dataset.gallery = btoa(encodeURIComponent(JSON.stringify(urls)));
                    imgEl.dataset.idx = '0';
                    imgEl.classList.remove('hidden');
                    imgEl.classList.add('cursor-pointer', 'hover:opacity-90', 'transition-opacity');
                } else {
                    imgEl.classList.add('hidden');
                    imgEl.src = '';
                }
                hugCountEl.textContent = data.hug_count || 0;
            }
        } catch (e) {
            console.error('加载树洞失败:', e);
        }
        lucide.createIcons();
        // 等 Lucide 生成 SVG 后再更新抱抱样式
        const svgIcon = document.getElementById('hugIcon');
        updateHugButtonUI(btnHug, svgIcon, currentTreeholeHugged);
    };

    function updateHugButtonUI(btn, icon, hugged) {
        if (btn) {
            if (hugged) {
                btn.classList.add('text-pink-400');
                btn.classList.remove('text-gray-400');
            } else {
                btn.classList.remove('text-pink-400');
                btn.classList.add('text-gray-400');
            }
        }
        // 直接操作 SVG fill 属性，不依赖 Lucide class
        if (icon) {
            if (hugged) {
                icon.setAttribute('fill', '#f472b6');
                icon.setAttribute('stroke', '#f472b6');
            } else {
                icon.setAttribute('fill', 'none');
                icon.setAttribute('stroke', 'currentColor');
            }
        }
    }

    window.toggleTreeholeHug = async function(diaryId, btnEl, iconEl, countEl) {
        btnEl.disabled = true;
        try {
            let result;
            if (currentTreeholeHugged) {
                // 乐观更新：先改 UI，再发请求
                updateHugButtonUI(btnEl, iconEl, false);
                currentTreeholeHugged = false;
                result = await EchoAPI.unhugDiary(diaryId);
            } else {
                // 乐观更新：先改 UI，再发请求
                updateHugButtonUI(btnEl, iconEl, true);
                currentTreeholeHugged = true;
                result = await EchoAPI.hugDiary(diaryId);
                if (!result.already_hugged) {
                    // 动画只在首次抱抱时播放
                    if (iconEl) {
                        iconEl.classList.remove('hug-animate');
                        iconEl.style.color = '#EC4899';
                        void iconEl.offsetWidth;
                        iconEl.classList.add('hug-animate');
                        setTimeout(() => { iconEl.style.color = ''; }, 600);
                    }
                }
            }
            if (countEl) countEl.textContent = result.hug_count || 0;
            // 同步更新另一个计数器
            hugCountEl.textContent = result.hug_count || 0;
            const thHugCount = document.getElementById('thDetailHugCount');
            if (thHugCount && thHugCount !== countEl) thHugCount.textContent = result.hug_count || 0;
        } catch (e) {
            console.error('抱抱操作失败:', e);
            // 失败时回滚状态
            if (!currentTreeholeHugged) {
                currentTreeholeHugged = true;
                updateHugButtonUI(btnEl, iconEl, true);
            } else {
                currentTreeholeHugged = false;
                updateHugButtonUI(btnEl, iconEl, false);
            }
        } finally {
            btnEl.disabled = false;
        }
    };

    // ===== 树洞详情弹窗 =====

    window.openTreeholeDetail = function(diaryId) {
        thDetailCurrentId = diaryId;
        treeholeDetailContent.innerHTML = '<div class="flex items-center justify-center py-20"><span class="loader w-8 h-8 border-2 border-purple-400 border-t-transparent rounded-full inline-block"></span></div>';
        thDetailReplyInput.value = '';
        clearThDetailCommentImages();
        exitThReplyMode();
        treeholeDetailOverlay.classList.remove('opacity-0', 'pointer-events-none');
        treeholeDetailOverlay.classList.add('opacity-100', 'pointer-events-auto');
        document.body.style.overflow = 'hidden';
        loadTreeholeDetail(diaryId);
    };

    window.closeTreeholeDetail = function() {
        treeholeDetailOverlay.classList.add('opacity-0', 'pointer-events-none');
        treeholeDetailOverlay.classList.remove('opacity-100', 'pointer-events-auto');
        document.body.style.overflow = '';
        thDetailCurrentId = null;
        exitThReplyMode();
    };

    window.loadTreeholeDetail = async function(diaryId) {
        try {
            const d = await EchoAPI.fetchTreeholeDetail(diaryId);
            if (!d) {
                treeholeDetailContent.innerHTML = '<p class="text-center text-gray-400 py-20">树洞日记不存在</p>';
                return;
            }
            currentTreeholeDetailData = d;
            renderTreeholeDetail(d);
        } catch (e) {
            console.error('加载树洞详情失败:', e);
            treeholeDetailContent.innerHTML = '<p class="text-center text-gray-400 py-20">加载失败</p>';
        }
    };

    // 生成单个回复的 HTML（用于单独渲染）
    function buildReplyItemHtml(r, isChild = false) {
        const liked = !!r.liked;
        const anonName = escapeHtml(r.anon_name || '匿名小伙伴');
        const anonAvatar = escapeHtml(r.anon_avatar || '👻');
        const identityId = r.identity_id || 0;
        const replyToName = escapeHtml(r.reply_to_anon_name || '');
        const imgs = r.image_urls || [];
        const imageHtml = imgs.length ? `<div class="flex flex-wrap gap-1 mt-2">${imgs.map(u => `<img src="${escapeHtml(u)}" class="w-16 h-16 rounded-xl object-contain shadow-sm bg-gray-50 cursor-pointer gallery-img" data-gallery="${btoa(encodeURIComponent(JSON.stringify(imgs)))}" data-idx="${imgs.indexOf(u)}" alt="">`).join('')}</div>` : '';
        return `
            <div class="th-reply-item ${isChild ? 'ml-8 pl-3 border-l-2 border-purple-100' : ''}" id="reply-${r.id}" data-reply-id="${r.id}" data-identity-id="${identityId}" data-anon-name="${escapeHtml(anonName)}">
                <div class="flex items-start gap-2.5">
                    <span class="w-8 h-8 rounded-full bg-gradient-to-br from-purple-100 to-indigo-100 flex items-center justify-center text-sm shrink-0 shadow-sm select-none">${anonAvatar}</span>
                    <div class="bg-gray-50 rounded-2xl rounded-tl-sm px-4 py-3 flex-1">
                        <div class="flex items-center gap-1.5 mb-1">
                            <span class="text-[11px] font-medium text-gray-500">${anonName}</span>
                            ${r.is_author ? '<span class="text-[9px] px-1.5 py-px rounded-full bg-amber-100 text-amber-600 font-medium ml-0.5">作者</span>' : ''}
                            ${replyToName ? `<span class="text-[10px] text-purple-400">回复 ${replyToName}</span>` : ''}
                            <span class="text-[10px] text-gray-300">· ${formatDate(r.created_at)}</span>
                        </div>
                        <p class="text-[13px] text-gray-600 leading-relaxed">${escapeHtml(r.content)}</p>
                        ${imageHtml}
                        <div class="flex items-center justify-end mt-1.5 gap-2">
                            <button class="th-reply-like-btn inline-flex items-center gap-0.5 text-[10px] ${liked ? 'text-pink-400' : 'text-gray-300'} hover:text-pink-400 transition-colors" data-reply-id="${r.id}">
                                <i data-lucide="heart" class="w-3 h-3 ${liked ? 'fill-pink-400' : ''}"></i>
                                <span class="th-reply-like-count">${r.like_count || 0}</span>
                            </button>
                            <button class="th-reply-reply-btn text-[10px] text-gray-300 hover:text-purple-400 transition-colors" data-reply-id="${r.id}" data-identity-id="${identityId}" data-anon-name="${escapeHtml(anonName)}">
                                <i data-lucide="message-circle" class="w-3 h-3"></i>
                            </button>
                            <button class="th-reply-report-btn inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-gray-50 text-gray-400 text-[10px] hover:bg-red-50 hover:text-red-400 active:scale-95 transition-all" data-reply-id="${r.id}">
                                <i data-lucide="flag" class="w-3 h-3"></i>
                            </button>
                        </div>
                    </div>
                </div>
            </div>`;
    }

    window.renderTreeholeDetail = function(d) {
        const moodInfo = MOOD_MAP[d.mood] || MOOD_MAP['😊'];
        const tags = d.tags ? d.tags.split(',').filter(Boolean) : [];
        const tagHtml = tags.map((t, ti) =>
            `<span class="sticker-${ti % 5} text-xs font-medium px-2.5 py-1 rounded-xl shadow-sm">#${t.trim()}</span>`
        ).join(' ');
        const replies = d.replies || [];
        let totalReplyCount = 0;

        function renderReplyItem(r, isChild = false) {
            totalReplyCount++;
            let html = buildReplyItemHtml(r, isChild);
            // 子回复（二级）
            if (r.replies && r.replies.length > 0) {
                html += '<div class="mt-2">';
                r.replies.forEach(cr => { html += renderReplyItem(cr, true); });
                html += '</div>';
            }
            return html;
        }

        let replyHtml = '';
        replies.forEach(r => { replyHtml += renderReplyItem(r, false); });

        treeholeDetailContent.innerHTML = `
            <!-- 顶部：匿名头像 + 心情 -->
            <div class="flex items-center justify-between mb-4">
                <div class="flex items-center gap-2.5">
                    <span class="w-10 h-10 rounded-full bg-gradient-to-br from-purple-100 to-indigo-100 flex items-center justify-center text-xl shadow-sm select-none">👻</span>
                    <span class="text-sm text-gray-400 tracking-wide">匿名小伙伴</span>
                </div>
                <div class="flex items-center gap-2">
                    <span class="text-3xl select-none">${d.mood || '🥰'}</span>
                    <span class="text-[11px] text-white px-2 py-0.5 rounded-full" style="background:${moodInfo.border}">${moodInfo.label}</span>
                </div>
            </div>
            <!-- 正文 -->
            ${d.image_urls && d.image_urls.length && window.renderImageGallery ? window.renderImageGallery(d.image_urls, { maxHeight: 'h-32', objectFit: 'contain' }) : ''}
            <p class="text-[15px] text-gray-700 leading-relaxed mb-4 whitespace-pre-wrap">${escapeHtml(d.content || '')}</p>
            ${tagHtml ? `<div class="flex flex-wrap gap-2 mb-4">${tagHtml}</div>` : ''}
            <time class="text-xs text-gray-400 block mb-4">${formatDate(d.created_at)}</time>
            <!-- 操作栏 -->
            <div class="flex items-center gap-4 mb-6 pt-3 border-t border-gray-50">
                <button id="thDetailHugBtn" class="inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-pink-50 text-pink-400 text-sm font-medium hover:bg-pink-100 active:scale-95 transition-all select-none">
                    <i data-lucide="heart" class="w-4 h-4"></i>
                    <span id="thDetailHugCount">${d.hug_count || 0}</span>
                </button>
                <span class="inline-flex items-center gap-1 text-sm text-gray-400">
                    <i data-lucide="message-circle" class="w-4 h-4"></i> ${totalReplyCount} 条回应
                </span>
                <button id="thDetailReportBtn" class="ml-auto inline-flex items-center gap-1 px-3 py-1.5 rounded-full bg-gray-50 text-gray-400 text-xs hover:bg-red-50 hover:text-red-400 active:scale-95 transition-all select-none">
                    <i data-lucide="flag" class="w-3.5 h-3.5"></i> 举报
                </button>
            </div>
            <!-- 回复列表 -->
            ${replyHtml ? `<div class="space-y-3 mb-4">${replyHtml}</div>` : '<p class="text-center text-gray-300 text-sm py-4">还没有回应，来写第一条吧</p>'}
        `;

        // 抱抱按钮（toggle）
        const hugBtn = document.getElementById('thDetailHugBtn');
        const thHugCount = document.getElementById('thDetailHugCount');
        if (hugBtn) hugBtn.addEventListener('click', () => {
            toggleTreeholeHug(d.id, hugBtn, hugBtn.querySelector('i'), thHugCount);
        });
        const reportBtn = document.getElementById('thDetailReportBtn');
        if (reportBtn) {
            reportBtn.addEventListener('click', () => {
                openReportModal('treehole', d.id, `举报树洞 #${d.id}`);
            });
        }


        lucide.createIcons();
    };

    // 退出树洞回复模式
    window.exitThReplyMode = function() {
        thReplyToReplyId = null;
        thReplyToIdentityId = null;
        thReplyToAnonName = '';
        thReplyIndicator.classList.add('hidden');
        thDetailReplyInput.placeholder = '给陌生人一句温暖的回应…';
        clearThDetailCommentImages();
    };

    // ===== Event listeners =====

    // 树洞投递模态框
    btnTreeholeSend.addEventListener('click', openTreeholeCompose);
    btnCloseTreeholeCompose.addEventListener('click', closeTreeholeCompose);
    treeholeComposeOverlay.addEventListener('click', (e) => {
        if (e.target === treeholeComposeOverlay) closeTreeholeCompose();
    });

    treeholeMoodBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            treeholeMoodBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            treeholeMood.textContent = btn.dataset.mood;
        });
    });

    // 树洞添加图片
    btnTreeholePickImage.addEventListener('click', () => treeholeImageFileInput.click());

    treeholeImageFileInput.addEventListener('change', async () => {
        const file = treeholeImageFileInput.files[0];
        if (!file) return;
        treeholeImageUploadStatus.textContent = '压缩上传中...';
        treeholeImageUploadStatus.classList.remove('hidden');
        btnTreeholePickImage.disabled = true;
        try {
            const blob = await compressImage(file);
            const data = await EchoAPI.uploadImage(blob);
            treeholeImageUrls.push(data.url);
            renderTreeholeThumbnails();
            treeholeImageUploadStatus.textContent = '已上传';
            treeholeImageUploadStatus.classList.remove('text-gray-300');
            treeholeImageUploadStatus.classList.add('text-emerald-500');
        } catch (e) {
            console.error('树洞图片上传失败:', e);
            treeholeImageUploadStatus.textContent = '上传失败';
            treeholeImageUploadStatus.classList.add('text-red-400');
        } finally {
            btnTreeholePickImage.disabled = false;
            treeholeImageFileInput.value = '';
        }
    });

    btnSubmitTreehole.addEventListener('click', async () => {
        const content = treeholeComposeContent.value.trim();
        if (!content) { alert('先写点什么吧～'); return; }
        const mood = document.querySelector('.treehole-mood-btn.active')?.dataset.mood || '😊';

        btnSubmitTreehole.disabled = true;
        btnSubmitTreehole.innerHTML = '<span class="loader w-5 h-5 border-2 border-white border-t-transparent rounded-full inline-block"></span> 投递中...';
        try {
            await EchoAPI.createTreehole({ mood, content, tags: '', image_urls: treeholeImageUrls });
            treeholeImageUrls = [];
            closeTreeholeCompose();
            showToast('🫧 漂流瓶已投递，它将漂流到另一个陌生人手中');
            await loadTreehole();
        } catch (e) {
            console.error('投递树洞失败:', e);
            alert('投递失败，请稍后再试～');
        } finally {
            btnSubmitTreehole.disabled = false;
            btnSubmitTreehole.innerHTML = '<i data-lucide="send" class="w-5 h-5"></i> 匿名投递';
            lucide.createIcons();
        }
    });

    // 树洞主区域
    btnRefresh.addEventListener('click', loadTreehole);

    btnHug.addEventListener('click', () => {
        if (!currentTreeholeDiaryId) return;
        const svgIcon = btnHug.querySelector('svg');
        toggleTreeholeHug(currentTreeholeDiaryId, btnHug, svgIcon, hugCountEl);
    });

    // 树洞回复
    btnTreeholeReply.addEventListener('click', async () => {
        const content = treeholeReplyInput.value.trim();
        if (!content && !thDetailCommentImageUrls) return;
        if (!currentTreeholeDiaryId) return;
        btnTreeholeReply.disabled = true;
        try {
            await EchoAPI.replyTreehole(currentTreeholeDiaryId, content, null, null, echoClientId);
            treeholeReplyInput.value = '';
            showToast('回复已发送，匿名小伙伴会收到你的温暖 💌');
            openTreeholeDetail(currentTreeholeDiaryId);
        } catch (e) {
            console.error('树洞回复失败:', e);
            showToast('回复失败，请稍后再试');
        } finally {
            btnTreeholeReply.disabled = false;
        }
    });

    treeholeReplyInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') btnTreeholeReply.click();
    });

    // 点击树洞卡片正文区域打开详情
    treeholeContent.addEventListener('click', () => {
        if (currentTreeholeDiaryId) openTreeholeDetail(currentTreeholeDiaryId);
    });
    treeholeContent.style.cursor = 'pointer';

    // 树洞详情弹窗
    btnThCancelReply.addEventListener('click', exitThReplyMode);

    btnCloseTreeholeDetail.addEventListener('click', closeTreeholeDetail);
    treeholeDetailOverlay.addEventListener('click', (e) => {
        if (e.target === treeholeDetailOverlay) closeTreeholeDetail();
    });

    // 树洞详情中回复按钮和点赞按钮：事件委托
    treeholeDetailContent.addEventListener('click', (e) => {
        const replyBtn = e.target.closest('.th-reply-reply-btn');
        if (replyBtn) {
            e.stopPropagation();
            const replyId = parseInt(replyBtn.dataset.replyId);
            const identityId = parseInt(replyBtn.dataset.identityId);
            const anonName = replyBtn.dataset.anonName || '';
            if (replyId) {
                thReplyToReplyId = replyId;
                thReplyToIdentityId = identityId || null;
                thReplyToAnonName = anonName;
                thReplyTargetName.textContent = anonName;
                thReplyIndicator.classList.remove('hidden');
                thDetailReplyInput.placeholder = `回复 ${anonName}…`;
                thDetailReplyInput.focus();
            }
            return;
        }
        // 回复举报（事件委托）
        const reportBtn = e.target.closest('.th-reply-report-btn');
        if (reportBtn) {
            e.stopPropagation();
            const replyId = parseInt(reportBtn.dataset.replyId);
            if (replyId) openReportModal('treehole_reply', replyId, `举报回复 #${replyId}`);
            return;
        }
        // 回复点赞（事件委托）
        const likeBtn = e.target.closest('.th-reply-like-btn');
        if (likeBtn) {
            e.stopPropagation();
            const replyId = parseInt(likeBtn.dataset.replyId);
            if (!currentTreeholeDetailData || !replyId) return;
            const replyEl = document.getElementById('reply-' + replyId);
            if (!replyEl) return;
            const findReply = (arr, id) => {
                for (let r of arr) {
                    if (r.id === id) return r;
                    if (r.replies) { const f = findReply(r.replies, id); if (f) return f; }
                }
                return null;
            };
            const reply = findReply(currentTreeholeDetailData.replies || [], replyId);
            if (!reply) return;
            // 乐观更新
            reply.liked = !reply.liked;
            reply.like_count = (reply.like_count || 0) + (reply.liked ? 1 : -1);
            if (reply.like_count < 0) reply.like_count = 0;
            // 立即更新 DOM（单个回复）- 用 replaceWith 替换整个元素
            const newEl = document.createElement('div');
            newEl.innerHTML = buildReplyItemHtml(reply, reply.parent_reply_id > 0);
            replyEl.replaceWith(newEl.firstElementChild);
            lucide.createIcons();
            // 异步调用 API
            (async () => {
                try {
                    if (reply.liked) {
                        await EchoAPI.likeTreeholeReply(replyId);
                    } else {
                        await EchoAPI.unlikeTreeholeReply(replyId);
                    }
                } catch (err) {
                    console.error('回复点赞失败:', err);
                    // 回滚
                    reply.liked = !reply.liked;
                    reply.like_count = (reply.like_count || 0) + (reply.liked ? 1 : -1);
                    if (reply.like_count < 0) reply.like_count = 0;
                    const rollbackEl = document.getElementById('reply-' + replyId);
                    if (rollbackEl) {
                        const rbNew = document.createElement('div');
                        rbNew.innerHTML = buildReplyItemHtml(reply, reply.parent_reply_id > 0);
                        rollbackEl.replaceWith(rbNew.firstElementChild);
                    }
                    lucide.createIcons();
                }
            })();
        }
    });

    // 详情中发送回复
    btnThDetailReplySend.addEventListener('click', async () => {
        const content = thDetailReplyInput.value.trim();
        if ((!content && !thDetailCommentImageUrls) || !thDetailCurrentId) return;
        btnThDetailReplySend.disabled = true;
        try {
            await EchoAPI.replyTreehole(thDetailCurrentId, content, thReplyToReplyId, thReplyToIdentityId, echoClientId, thDetailCommentImageUrls);
            thDetailReplyInput.value = '';
            clearThDetailCommentImages();
            exitThReplyMode();
            showToast('回应已发送 💌');
            await loadTreeholeDetail(thDetailCurrentId);
        } catch (e) {
            console.error('树洞回复失败:', e);
            showToast('回复失败，请稍后再试');
        } finally {
            btnThDetailReplySend.disabled = false;
        }
    });

    thDetailReplyInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') btnThDetailReplySend.click();
    });

    function renderThDetailThumbnails() {
        if (!thDetailThumbnails) return;
        if (thDetailCommentImageUrls.length === 0) {
            thDetailThumbnails.classList.add('hidden');
            thDetailThumbnails.innerHTML = '';
            return;
        }
        thDetailThumbnails.classList.remove('hidden');
        thDetailThumbnails.innerHTML = thDetailCommentImageUrls.map((url, i) => `
            <div class="relative">
                <img src="${escapeHtml(url)}" class="w-16 h-16 rounded-xl object-cover shadow-sm border border-gray-100">
                <button class="th-img-remove absolute -top-1 -right-1 w-5 h-5 rounded-full bg-gray-700/80 text-white text-[10px] flex items-center justify-center hover:bg-gray-800" data-index="${i}">
                    <i data-lucide="x" class="w-2.5 h-2.5"></i>
                </button>
            </div>
        `).join('');
        if (typeof lucide !== 'undefined' && lucide.createIcons) lucide.createIcons();
    }

    function clearThDetailCommentImages() {
        thDetailCommentImageUrls = [];
        renderThDetailThumbnails();
    }

    btnThDetailImage.addEventListener('click', () => thDetailImageInput.click());
    thDetailImageInput.addEventListener('change', async () => {
        const files = Array.from(thDetailImageInput.files);
        if (!files.length) return;
        btnThDetailImage.disabled = true;
        btnThDetailImage.classList.add('opacity-50');
        try {
            for (const file of files) {
                const blob = await compressImage(file);
                const data = await EchoAPI.uploadImage(blob);
                thDetailCommentImageUrls.push(data.url);
            }
            renderThDetailThumbnails();
        } catch (e) {
            console.error('图片上传失败:', e);
            showToast('图片上传失败');
        } finally {
            btnThDetailImage.disabled = false;
            btnThDetailImage.classList.remove('opacity-50');
            thDetailImageInput.value = '';
        }
    });
    if (thDetailThumbnails) {
        thDetailThumbnails.addEventListener('click', (e) => {
            const btn = e.target.closest('.th-img-remove');
            if (btn) {
                thDetailCommentImageUrls.splice(parseInt(btn.dataset.index), 1);
                renderThDetailThumbnails();
            }
        });
    }

    // 漂流瓶卡片举报按钮
    if (btnTreeholeReport) {
        btnTreeholeReport.addEventListener('click', () => {
            if (currentTreeholeDiaryId) openReportModal('treehole', currentTreeholeDiaryId, `举报树洞 #${currentTreeholeDiaryId}`);
        });
    }

    // 详情中举报按钮
    btnTreeholeDetailReport.addEventListener('click', () => {
        if (thDetailCurrentId) openReportModal('treehole', thDetailCurrentId, `举报树洞 #${thDetailCurrentId}`);
    });

})();
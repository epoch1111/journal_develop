/**
 * Diary Detail View - 日记详情 / 编辑弹窗
 * 包含详情渲染、编辑模式、图片管理
 */
(function() {
    'use strict';

    // === DOM 引用 ===
    const detailOverlay    = document.getElementById('detailOverlay');
    const detailTitle     = document.getElementById('detailTitle');
    const detailContent   = document.getElementById('detailContent');
    const detailEditBar   = document.getElementById('detailEditBar');
    const btnCloseDetail  = document.getElementById('btnCloseDetail');
    const btnEditDiary    = document.getElementById('btnEditDiary');
    const btnDeleteDiary  = document.getElementById('btnDeleteDiary');
    const btnSaveEdit     = document.getElementById('btnSaveEdit');
    const btnCancelEdit   = document.getElementById('btnCancelEdit');

    // === 状态（全局保留在 window，供外部访问） ===
    window.currentDetailId = null;
    window.currentDetailData = null;
    let isEditing = false;
    let editImageUrls = [];

    // === 图片画廊渲染 ===
    function renderImageGallery(imageUrls, opts) {
        opts = opts || {};
        const urls = (imageUrls && imageUrls.length) ? imageUrls : [];
        if (!urls.length) return '';
        const maxH = opts.maxHeight || 'h-32';
        const objectFit = opts.objectFit || 'cover'; // cover=填满裁剪，contain=等比缩放
        const cls = opts.className || 'rounded-2xl shadow-sm border border-gray-50';
        const cols = opts.gridCols || Math.min(urls.length, 3);
        // 将 urls JSON 编码后存 data 属性，JS 通过事件委托读取
        const encoded = btoa(encodeURIComponent(JSON.stringify(urls)));
        if (urls.length === 1) {
            return `<img src="${escapeHtml(urls[0])}" data-gallery="${encoded}" data-idx="0" class="w-full ${maxH} object-${objectFit} ${cls} mb-4 cursor-pointer hover:opacity-90 transition-opacity gallery-img" alt="">`;
        }
        const gridColClass = cols === 2 ? 'grid-cols-2' : 'grid-cols-3';
        return `
            <div class="grid ${gridColClass} gap-2 mb-4">
                ${urls.map((url, i) => {
                    const span = (cols === 3 && i === 0) ? 'col-span-2 row-span-2' : '';
                    return `<img src="${escapeHtml(url)}" data-gallery="${encoded}" data-idx="${i}" class="w-full ${maxH} object-${objectFit} ${cls} ${span} cursor-pointer hover:opacity-90 transition-opacity gallery-img" alt="">`;
                }).join('')}
            </div>`;
    }

    // === 图片查看器 ===
    let _imgViewerUrls = [];
    let _imgViewerIndex = 0;

    window.openImageViewer = function(urls, startIndex) {
        _imgViewerUrls = urls;
        _imgViewerIndex = startIndex;
        const overlay = document.getElementById('imgViewerOverlay');
        const img = document.getElementById('imgViewerImg');
        img.src = urls[startIndex];
        overlay.classList.remove('opacity-0', 'pointer-events-none');
        overlay.classList.add('opacity-100');
        document.body.style.overflow = 'hidden';
        if (typeof lucide !== 'undefined' && lucide.createIcons) lucide.createIcons();
    };

    window.closeImageViewer = function() {
        const overlay = document.getElementById('imgViewerOverlay');
        overlay.classList.add('opacity-0', 'pointer-events-none');
        overlay.classList.remove('opacity-100');
        document.body.style.overflow = '';
    };

    window.switchImageViewer = function(dir) {
        _imgViewerIndex = (_imgViewerIndex + dir + _imgViewerUrls.length) % _imgViewerUrls.length;
        document.getElementById('imgViewerImg').src = _imgViewerUrls[_imgViewerIndex];
    };

    // 图片查看器事件绑定
    document.getElementById('imgViewerOverlay')?.addEventListener('click', (e) => {
        if (e.target.id === 'imgViewerOverlay' || e.target.id === 'btnCloseImgViewer') closeImageViewer();
    });
    document.getElementById('btnImgPrev')?.addEventListener('click', () => switchImageViewer(-1));
    document.getElementById('btnImgNext')?.addEventListener('click', () => switchImageViewer(1));

    // 事件委托：所有 gallery 图片点击打开查看器
    document.addEventListener('click', (e) => {
        const img = e.target.closest('.gallery-img');
        if (img) {
            const encoded = img.dataset.gallery;
            const idx = parseInt(img.dataset.idx || '0');
            try {
                const urls = JSON.parse(decodeURIComponent(atob(encoded)));
                openImageViewer(urls, idx);
            } catch (err) {
                console.error('图片查看器打开失败:', err);
            }
        }
    });

    // === 日记详情弹窗 ===
    window.openDetailModal = function(diaryId, startInEdit) {
        window.currentDetailId = diaryId;
        isEditing = false;
        detailContent.innerHTML = '<div class="flex items-center justify-center py-20"><span class="loader w-8 h-8 border-2 border-emerald-400 border-t-transparent rounded-full inline-block"></span></div>';
        detailEditBar.classList.add('hidden');
        detailOverlay.classList.remove('opacity-0', 'pointer-events-none');
        detailOverlay.classList.add('opacity-100', 'pointer-events-auto');
        document.body.style.overflow = 'hidden';
        loadDetail(diaryId, startInEdit);
        lucide.createIcons();
    };

    window.loadDetail = async function(diaryId, startInEdit) {
        try {
            const d = await EchoAPI.fetchDiaryById(diaryId);
            window.currentDetailData = d;
            renderDetailView(d);
            if (startInEdit && !d.locked) {
                setTimeout(() => window.enterEditMode(), 100);
            }
        } catch (e) {
            console.error('加载详情失败:', e);
            detailContent.innerHTML = '<p class="text-center text-gray-400 py-20">加载失败，请稍后再试</p>';
        }
        lucide.createIcons();
    };

    window.renderDetailView = function(d) {
        detailTitle.textContent = d.locked ? '时光胶囊 🔒' : '日记详情';
        btnEditDiary.classList.toggle('hidden', !!d.locked);
        btnDeleteDiary.classList.remove('hidden');
        detailEditBar.classList.add('hidden');
        isEditing = false;

        const tags = d.tags ? d.tags.split(',').filter(Boolean) : [];
        const tagHtml = tags.map((t, ti) =>
            `<span class="sticker-${ti % 5} text-xs font-medium px-2.5 py-1 rounded-xl shadow-sm select-none">#${t.trim()}</span>`
        ).join('');
        const moodInfo = MOOD_MAP[d.mood] || MOOD_MAP['😊'];

        const capsLocked = !!d.locked;
        const capsUnlocked = !capsLocked && !!(d.unlock_date);

        let statusBadge = '';
        if (capsLocked) {
            statusBadge = `<div class="flex items-center gap-2 bg-indigo-50 rounded-2xl px-4 py-3 mb-4">
                <i data-lucide="lock" class="w-5 h-5 text-indigo-400"></i>
                <span class="text-sm text-indigo-500 font-medium">距离拆封还有 ${d.days_left} 天</span>
            </div>`;
        } else if (capsUnlocked) {
            statusBadge = `<div class="flex items-center gap-2 bg-yellow-50 rounded-2xl px-4 py-3 mb-4">
                <span class="text-sm text-yellow-600 font-medium">🕰️ 时光胶囊已解锁</span>
            </div>`;
        }

        const contentDisplay = capsLocked
            ? '<p class="text-gray-300 italic text-center py-8">🔒 这颗时光胶囊还没有到开启时间</p>'
            : `<p class="text-[16px] text-gray-700 leading-relaxed whitespace-pre-wrap">${escapeHtml(d.content || '')}</p>`;

        const detailImageUrls = (d.image_urls && d.image_urls.length) ? d.image_urls : (d.image_url ? [d.image_url] : []);
        const imageHtml = (!capsLocked) ? renderImageGallery(detailImageUrls, { maxHeight: 'h-32', objectFit: 'contain' }) : '';

        detailContent.innerHTML = `
            ${statusBadge}
            ${imageHtml}
            <div class="flex items-center gap-3 mb-4">
                <span class="text-4xl select-none">${d.mood || '📝'}</span>
                <div>
                    <span class="text-sm font-medium text-white px-2.5 py-1 rounded-full" style="background:${moodInfo.border}">${moodInfo.label}</span>
                </div>
                <time class="text-xs text-gray-400 ml-auto">${formatDate(d.created_at)}</time>
            </div>
            ${contentDisplay}
            ${!capsLocked && d.ai_message ? `
            <div class="flex items-start gap-2.5 mt-5">
                <div class="w-8 h-8 rounded-full bg-gradient-to-br from-amber-100 to-amber-200 flex items-center justify-center text-lg shrink-0 shadow-sm select-none">🐰</div>
                <div class="relative bubble-left bg-[#F2F7F5] border border-emerald-100 rounded-2xl rounded-tl-sm px-4 py-3 shadow-sm flex-1">
                    <p class="text-[13px] text-gray-600 leading-relaxed">${escapeHtml(d.ai_message || '')}</p>
                    ${d.ai_summary ? `<p class="text-[11px] text-gray-400 mt-1.5 italic">📌 ${escapeHtml(d.ai_summary)}</p>` : ''}
                </div>
            </div>` : ''}
            ${!capsLocked && tags.length ? `<div class="flex flex-wrap gap-2 mt-4">${tagHtml}</div>` : ''}
        `;
        lucide.createIcons();
    };

    // === 编辑模式 ===
    window.enterEditMode = function() {
        if (!window.currentDetailData || window.currentDetailData.locked) return;
        isEditing = true;
        const d = window.currentDetailData;
        detailTitle.textContent = '编辑日记';
        btnEditDiary.classList.add('hidden');
        btnDeleteDiary.classList.add('hidden');
        detailEditBar.classList.remove('hidden');

        const tagsStr = d.tags || '';

        detailContent.innerHTML = `
            <div class="mb-4">
                <p class="text-xs text-gray-400 mb-2">心情</p>
                <div class="flex justify-center gap-5" id="editMoodSelector">
                    <button class="edit-mood-btn text-3xl select-none ${d.mood === '😊' ? 'active' : ''}" data-mood="😊" style="${d.mood !== '😊' ? 'opacity:0.45;filter:grayscale(0.3)' : ''}">😊</button>
                    <button class="edit-mood-btn text-3xl select-none ${d.mood === '😫' ? 'active' : ''}" data-mood="😫" style="${d.mood !== '😫' ? 'opacity:0.45;filter:grayscale(0.3)' : ''}">😫</button>
                    <button class="edit-mood-btn text-3xl select-none ${d.mood === '😢' ? 'active' : ''}" data-mood="😢" style="${d.mood !== '😢' ? 'opacity:0.45;filter:grayscale(0.3)' : ''}">😢</button>
                    <button class="edit-mood-btn text-3xl select-none ${d.mood === '😡' ? 'active' : ''}" data-mood="😡" style="${d.mood !== '😡' ? 'opacity:0.45;filter:grayscale(0.3)' : ''}">😡</button>
                    <button class="edit-mood-btn text-3xl select-none ${d.mood === '🥰' ? 'active' : ''}" data-mood="🥰" style="${d.mood !== '🥰' ? 'opacity:0.45;filter:grayscale(0.3)' : ''}">🥰</button>
                    <button class="edit-mood-btn text-3xl select-none ${d.mood === '😐' ? 'active' : ''}" data-mood="😐" style="${d.mood !== '😐' ? 'opacity:0.45;filter:grayscale(0.3)' : ''}">😐</button>
                </div>
            </div>
            <div class="mb-4">
                <p class="text-xs text-gray-400 mb-2">内容</p>
                <textarea id="editContent" class="w-full h-40 resize-none text-[16px] text-gray-700 leading-relaxed p-4 rounded-2xl bg-gray-50 border-0 focus:ring-2 focus:ring-emerald-200 focus:outline-none">${escapeHtml(d.content || '')}</textarea>
            </div>
            <div class="mb-4">
                <p class="text-xs text-gray-400 mb-2">标签（逗号分隔）</p>
                <input id="editTags" type="text" value="${escapeHtml(tagsStr)}" class="w-full p-3 rounded-xl bg-gray-50 text-gray-700 text-sm border-0 focus:ring-2 focus:ring-emerald-200 focus:outline-none" placeholder="开心,日常,正能量">
            </div>
            <div class="mb-4">
                <p class="text-xs text-gray-400 mb-2">图片</p>
                <div id="editImageArea">
                    <div id="editImageThumbnails" class="flex flex-wrap gap-2 mb-2"></div>
                    <button id="btnEditPickImage" class="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-gray-50 text-gray-400 text-xs hover:bg-gray-100 hover:text-gray-500 active:scale-95 transition-all select-none">
                        <i data-lucide="image" class="w-4 h-4"></i> 添加图片
                    </button>
                    <span id="editImageUploadStatus" class="text-[10px] text-gray-300 ml-2 hidden"></span>
                </div>
            </div>
            <div class="flex items-center justify-between mb-4">
                <span class="text-xs text-gray-400">公开到发现广场</span>
                <button id="editPublicToggle" class="relative w-10 h-5 rounded-full transition-colors duration-200 focus:outline-none active:scale-95 ${d.is_public ? 'bg-pink-400' : 'bg-gray-300'}">
                    <span id="editPublicDot" class="absolute top-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform duration-200 ${d.is_public ? 'left-5' : 'left-0.5'}"></span>
                </button>
            </div>
        `;

        // 编辑心情选择
        document.querySelectorAll('.edit-mood-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.edit-mood-btn').forEach(b => {
                    b.classList.remove('active');
                    b.style.opacity = '0.45';
                    b.style.filter = 'grayscale(0.3)';
                });
                btn.classList.add('active');
                btn.style.opacity = '';
                btn.style.filter = '';
            });
        });

        // 公开开关
        let editIsPublic = !!d.is_public;
        document.getElementById('editPublicToggle').addEventListener('click', () => {
            editIsPublic = !editIsPublic;
            const tog = document.getElementById('editPublicToggle');
            const dot = document.getElementById('editPublicDot');
            if (editIsPublic) {
                tog.className = 'relative w-10 h-5 rounded-full bg-pink-400 transition-colors duration-200 focus:outline-none active:scale-95';
                dot.className = 'absolute top-0.5 left-5 w-4 h-4 rounded-full bg-white shadow transition-transform duration-200';
            } else {
                tog.className = 'relative w-10 h-5 rounded-full bg-gray-300 transition-colors duration-200 focus:outline-none active:scale-95';
                dot.className = 'absolute top-0.5 left-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform duration-200';
            }
        });

        // 图片管理 - 多图
        editImageUrls = (d.image_urls && d.image_urls.length) ? [...d.image_urls] : (d.image_url ? [d.image_url] : []);

        function renderEditThumbnails() {
            const thumbContainer = document.getElementById('editImageThumbnails');
            if (!thumbContainer) return;
            thumbContainer.innerHTML = editImageUrls.map((url, i) => `
                <div class="relative inline-block">
                    <img src="${url}" class="h-20 rounded-xl object-cover shadow-sm border border-gray-100" alt="">
                    <button class="edit-img-remove-btn absolute -top-1.5 -right-1.5 w-5 h-5 rounded-full bg-gray-700/70 text-white text-[10px] flex items-center justify-center hover:bg-gray-800/80 active:scale-95 transition-all" data-index="${i}">
                        <i data-lucide="x" class="w-3 h-3"></i>
                    </button>
                </div>
            `).join('');
            const btnEditPick = document.getElementById('btnEditPickImage');
            if (btnEditPick) {
                btnEditPick.innerHTML = editImageUrls.length > 0
                    ? '<i data-lucide="image" class="w-4 h-4"></i> 继续添加'
                    : '<i data-lucide="image" class="w-4 h-4"></i> 添加图片';
            }
            thumbContainer.querySelectorAll('.edit-img-remove-btn').forEach(btn => {
                btn.addEventListener('click', () => {
                    const idx = parseInt(btn.dataset.index);
                    editImageUrls.splice(idx, 1);
                    renderEditThumbnails();
                    lucide.createIcons();
                });
            });
            lucide.createIcons();
        }
        renderEditThumbnails();

        // 文件输入重置 + 事件绑定
        const oldInput = document.getElementById('editImageFileInput');
        const newInput = oldInput.cloneNode(true);
        oldInput.parentNode.replaceChild(newInput, oldInput);

        const btnEditPick = document.getElementById('btnEditPickImage');
        const editUploadStatus = document.getElementById('editImageUploadStatus');

        if (btnEditPick) btnEditPick.addEventListener('click', () => newInput.click());

        newInput.addEventListener('change', async () => {
            const file = newInput.files[0];
            if (!file) return;
            editUploadStatus.textContent = '压缩上传中...';
            editUploadStatus.classList.remove('hidden');
            btnEditPick.disabled = true;
            try {
                const blob = await compressImage(file);
                const data = await EchoAPI.uploadImage(blob);
                editImageUrls.push(data.url);
                renderEditThumbnails();
                editUploadStatus.textContent = '已上传';
            } catch (e) {
                console.error('图片上传失败:', e);
                editUploadStatus.textContent = '上传失败';
            } finally {
                btnEditPick.disabled = false;
                setTimeout(() => editUploadStatus.classList.add('hidden'), 2000);
                newInput.value = '';
            }
        });

        lucide.createIcons();
    };

    // === 编辑事件 ===
    btnSaveEdit.addEventListener('click', async () => {
        const mood = document.querySelector('.edit-mood-btn.active')?.dataset.mood || '😊';
        const content = document.getElementById('editContent').value.trim();
        const tags = document.getElementById('editTags').value.trim();
        const isPublic = document.getElementById('editPublicToggle').classList.contains('bg-pink-400');
        const imageUrls = [...editImageUrls];

        if (!content) { alert('内容不能为空～'); return; }

        btnSaveEdit.disabled = true;
        btnSaveEdit.innerHTML = '<span class="loader w-5 h-5 border-2 border-white border-t-transparent rounded-full inline-block"></span> 保存中...';
        try {
            const updatePayload = { mood, content, tags, is_public: isPublic, image_url: imageUrls[0] || '', image_urls: imageUrls };
            await EchoAPI.updateDiary(window.currentDetailId, updatePayload);
            window.currentDetailData.mood = mood;
            window.currentDetailData.content = content;
            window.currentDetailData.tags = tags;
            window.currentDetailData.is_public = isPublic ? 1 : 0;
            window.currentDetailData.image_url = imageUrls[0] || '';
            window.currentDetailData.image_urls = imageUrls;
            window.renderDetailView(window.currentDetailData);
            if (typeof loadDiaries === 'function') await loadDiaries();
        } catch (e) {
            console.error('编辑失败:', e);
            alert('保存失败，请稍后再试～');
        } finally {
            btnSaveEdit.disabled = false;
            btnSaveEdit.innerHTML = '<i data-lucide="check" class="w-5 h-5"></i> 保存修改';
            lucide.createIcons();
        }
    });

    btnCancelEdit.addEventListener('click', () => {
        window.renderDetailView(window.currentDetailData);
    });

    btnEditDiary.addEventListener('click', () => window.enterEditMode());

    btnDeleteDiary.addEventListener('click', async () => {
        if (!confirm('确定要删除这篇日记吗？此操作不可恢复。')) return;
        try {
            await EchoAPI.deleteDiary(window.currentDetailId);
            window.closeDetailModal();
            if (typeof loadDiaries === 'function') await loadDiaries();
        } catch (e) {
            console.error('删除失败:', e);
            alert('删除失败，请稍后再试～');
        }
    });

    window.closeDetailModal = function() {
        detailOverlay.classList.add('opacity-0', 'pointer-events-none');
        detailOverlay.classList.remove('opacity-100', 'pointer-events-auto');
        document.body.style.overflow = '';
        window.currentDetailId = null;
        window.currentDetailData = null;
    };

    btnCloseDetail.addEventListener('click', window.closeDetailModal);
    detailOverlay.addEventListener('click', (e) => {
        if (e.target === detailOverlay) window.closeDetailModal();
    });

    // 暴露图片画廊供其他模块使用
    window.renderImageGallery = renderImageGallery;
})();

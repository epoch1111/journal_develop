/**
 * Compose View - 写日记 / 公开投递弹窗
 * 包含模态框打开/关闭/重置、AI 分析、图片上传、保存日记
 */
(function() {
    'use strict';

    // === DOM 引用 ===
    const overlay           = document.getElementById('modalOverlay');
    const textarea          = document.getElementById('diaryContent');
    const moodBtns          = document.querySelectorAll('.mood-btn');
    const btnAi             = document.getElementById('btnAiAnalyze');
    const btnAiToggle       = document.getElementById('btnAiToggle');
    const aiToggleDot       = document.getElementById('aiToggleDot');
    const aiResultArea      = document.getElementById('aiResultArea');
    const btnSave           = document.getElementById('btnSaveDraft');
    const btnOpen           = document.getElementById('btnOpenModal');
    const btnClose          = document.getElementById('btnCloseModal');
    const writingPrompt     = document.getElementById('writingPrompt');
    const imagePreviewArea  = document.getElementById('imagePreviewArea');
    const imageThumbnails   = document.getElementById('imageThumbnails');
    const imageUploadStatus = document.getElementById('imageUploadStatus');
    const btnPickImage      = document.getElementById('btnPickImage');
    const imageFileInput    = document.getElementById('imageFileInput');
    const planeOverlay      = document.getElementById('planeOverlay');
    const planeIcon         = document.getElementById('planeIcon');
    const planeToast        = document.getElementById('planeToast');
    const writeTagBtns      = document.querySelectorAll('.write-tag-btn');

    // === 状态 ===
    let aiEnabled = false;
    let aiResult = null;
    let currentImageUrls = [];
    let selectedWriteTags = new Set();

    // === 图片选择与上传（多图） ===
    function renderWriteThumbnails() {
        imageThumbnails.innerHTML = currentImageUrls.map((url, i) => `
            <div class="relative inline-block">
                <img src="${url}" class="h-20 rounded-xl object-cover shadow-sm border border-gray-100" alt="">
                <button class="img-remove-btn absolute -top-1.5 -right-1.5 w-5 h-5 rounded-full bg-gray-700/70 text-white text-[10px] flex items-center justify-center hover:bg-gray-800/80 active:scale-95 transition-all" data-index="${i}">
                    <i data-lucide="x" class="w-3 h-3"></i>
                </button>
            </div>
        `).join('');
        imageThumbnails.querySelectorAll('.img-remove-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                currentImageUrls.splice(parseInt(btn.dataset.index), 1);
                renderWriteThumbnails();
                lucide.createIcons();
            });
        });
        imagePreviewArea.classList.toggle('hidden', !currentImageUrls.length);
        lucide.createIcons();
    }

    btnPickImage.addEventListener('click', () => imageFileInput.click());

    imageFileInput.addEventListener('change', async () => {
        const file = imageFileInput.files[0];
        if (!file) return;
        imageUploadStatus.textContent = '压缩上传中...';
        imageUploadStatus.classList.remove('hidden');
        btnPickImage.disabled = true;
        try {
            const blob = await compressImage(file);
            const data = await EchoAPI.uploadImage(blob);
            currentImageUrls.push(data.url);
            renderWriteThumbnails();
            imageUploadStatus.textContent = '已上传';
        } catch (e) {
            console.error('图片上传失败:', e);
            imageUploadStatus.textContent = '上传失败';
        } finally {
            btnPickImage.disabled = false;
            setTimeout(() => imageUploadStatus.classList.add('hidden'), 2000);
            imageFileInput.value = '';
        }
    });

    // === 模态框 ===
    function openModal() {
        overlay.classList.remove('opacity-0', 'pointer-events-none');
        overlay.classList.add('opacity-100', 'pointer-events-auto');
        document.body.style.overflow = 'hidden';
    }

    function closeModal() {
        overlay.classList.add('opacity-0', 'pointer-events-none');
        overlay.classList.remove('opacity-100', 'pointer-events-auto');
        document.body.style.overflow = '';
    }

    function resetModal() {
        window.composeMode = 'diary';
        writingPrompt.textContent = '💡 ' + (typeof pickPrompt === 'function' ? pickPrompt() : '记录今天的心情吧');
        textarea.value = '';
        aiResult = null;
        aiResultArea.classList.add('hidden');
        moodBtns.forEach(b => b.classList.remove('active'));
        moodBtns[0].classList.add('active');
        btnAi.querySelector('.ai-icon').innerHTML = '<i data-lucide="sparkles" class="w-5 h-5"></i>';
        lucide.createIcons();
        btnAi.querySelector('.ai-label').textContent = 'AI 帮你总结';
        btnAi.disabled = false;
        aiEnabled = false;
        updateAiToggleUI();
        currentImageUrls = [];
        imageThumbnails.innerHTML = '';
        imagePreviewArea.classList.add('hidden');
        selectedWriteTags = new Set();
        writeTagBtns.forEach(btn => {
            btn.className = 'write-tag-btn px-3 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-400 shrink-0 active:scale-95 transition-all';
        });
        imageUploadStatus.textContent = '';
        imageUploadStatus.className = 'text-[10px] text-gray-300 hidden';
        btnPickImage.innerHTML = '<i data-lucide="image" class="w-4 h-4"></i> 添加图片';
        btnPickImage.disabled = false;
    }

    function updateAiToggleUI() {
        if (aiEnabled) {
            btnAiToggle.className = 'relative w-10 h-5 rounded-full bg-emerald-400 transition-colors duration-200 focus:outline-none active:scale-95';
            aiToggleDot.className = 'absolute top-0.5 left-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform duration-200 translate-x-5';
            btnAi.classList.remove('hidden');
            btnSave.classList.add('hidden');
        } else {
            btnAiToggle.className = 'relative w-10 h-5 rounded-full bg-gray-300 transition-colors duration-200 focus:outline-none active:scale-95';
            aiToggleDot.className = 'absolute top-0.5 left-0.5 w-4 h-4 rounded-full bg-white shadow transition-transform duration-200 translate-x-0';
            btnAi.classList.add('hidden');
            btnSave.classList.remove('hidden');
        }
    }

    btnOpen.addEventListener('click', () => { resetModal(); openModal(); });
    btnClose.addEventListener('click', closeModal);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) closeModal(); });

    // === 心情选择 ===
    moodBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            moodBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
        });
    });

    // === 话题标签选择 ===
    writeTagBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            const tag = btn.dataset.tag;
            if (selectedWriteTags.has(tag)) {
                selectedWriteTags.delete(tag);
                btn.className = 'write-tag-btn px-3 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-400 shrink-0 active:scale-95 transition-all';
            } else {
                selectedWriteTags.add(tag);
                btn.className = 'write-tag-btn px-3 py-1 rounded-full text-xs font-medium bg-emerald-100 text-emerald-600 shrink-0 active:scale-95 transition-all';
            }
        });
    });

    // === AI 开关 ===
    btnAiToggle.addEventListener('click', () => {
        aiEnabled = !aiEnabled;
        updateAiToggleUI();
    });

    // === AI 分析 ===
    btnAi.addEventListener('click', async () => {
        const content = textarea.value.trim();
        if (!content) { alert('先写点什么吧～'); return; }

        const mood = document.querySelector('.mood-btn.active')?.dataset.mood || '😊';

        btnAi.disabled = true;
        btnAi.querySelector('.ai-label').textContent = '思考中...';
        btnAi.querySelector('.ai-icon').innerHTML = '<i data-lucide="loader-circle" class="w-5 h-5 loader"></i>';
        lucide.createIcons();

        try {
            aiResult = await EchoAPI.analyzeDiary(content, 'default');

            document.getElementById('aiMessageText').textContent = aiResult.message || '';
            document.getElementById('aiSummaryText').textContent = aiResult.summary ? '📌 ' + aiResult.summary : '';
            const tagsContainer = document.getElementById('aiTagsContainer');
            tagsContainer.innerHTML = '';
            (aiResult.tags || []).forEach((tag, ti) => {
                const span = document.createElement('span');
                span.className = `sticker-${ti % 5} text-xs font-medium px-2.5 py-1 rounded-xl shadow-sm select-none`;
                span.textContent = '#' + tag.trim();
                tagsContainer.appendChild(span);
            });
            aiResultArea.classList.remove('hidden');
            btnSave.classList.remove('hidden');
            btnAi.querySelector('.ai-label').textContent = '重新分析';
        } catch (e) {
            console.error('AI 分析失败:', e);
            alert('AI 分析失败，请稍后再试～');
        } finally {
            btnAi.disabled = false;
            btnAi.querySelector('.ai-icon').innerHTML = '<i data-lucide="sparkles" class="w-5 h-5"></i>';
            lucide.createIcons();
        }
    });

    // === 保存日记 ===
    btnSave.addEventListener('click', async () => {
        const mood = document.querySelector('.mood-btn.active')?.dataset.mood || '😊';
        const content = textarea.value.trim();
        if (!content) { alert('先写点什么吧～'); return; }

        if (aiEnabled && !aiResult) {
            alert('请先点击"AI 帮你总结"获得分析结果～');
            return;
        }

        const tagsStr = aiResult
            ? [...new Set([...(aiResult.tags || []), ...selectedWriteTags])].join(',')
            : [...selectedWriteTags].join(',');
        const summary = aiResult ? (aiResult.summary || '') : '';
        const message = aiResult ? (aiResult.message || '') : '';
        const isPublic = window.composeMode === 'public';
        btnSave.disabled = true;
        btnSave.innerHTML = '<span class="loader w-5 h-5 border-2 border-white border-t-transparent rounded-full inline-block"></span> 保存中...';
        try {
            await EchoAPI.saveDiary({ mood, content, ai_summary: summary, ai_message: message, tags: tagsStr, is_public: isPublic, image_url: currentImageUrls[0] || '', image_urls: currentImageUrls });
            if (isPublic) {
                planeIcon.style.animation = 'none';
                void planeIcon.offsetWidth;
                planeIcon.style.animation = 'planeTakeoff 1.5s ease-out forwards';
                planeToast.textContent = '📮 已发布到发现广场，同频的人会看到它';
                planeOverlay.classList.remove('opacity-0', 'pointer-events-none');
                planeOverlay.classList.add('opacity-100');
                btnSave.disabled = false;
                btnSave.innerHTML = '<i data-lucide="check" class="w-5 h-5"></i> 保存日记';
                lucide.createIcons();
                await new Promise(r => setTimeout(r, 1600));
                planeOverlay.classList.add('opacity-0', 'pointer-events-none');
                planeOverlay.classList.remove('opacity-100');
            }
            closeModal();
            if (typeof loadDiaries === 'function') await loadDiaries();
            if (isPublic && typeof loadDiscover === 'function') await loadDiscover();
        } catch (e) {
            console.error('保存失败:', e);
            alert('保存失败，请稍后再试～');
        } finally {
            btnSave.disabled = false;
            btnSave.innerHTML = '<i data-lucide="check" class="w-5 h-5"></i> 保存日记';
            lucide.createIcons();
            window.composeMode = 'diary';
        }
    });

    // === 暴露到 window ===
    window.openModal = openModal;
    window.closeModal = closeModal;
    window.resetModal = resetModal;
    window.updateAiToggleUI = updateAiToggleUI;
})();

/**
 * Timeline View - 日记时间线
 * 只负责日记列表加载/搜索、胶囊列表、心情统计
 */
(function() {
    'use strict';

    // ===== DOM 引用（仅 timeline/capsule 相关） =====
    const diaryList = document.getElementById('diaryList');
    const capsuleList = document.getElementById('capsuleList');
    const diarySearch = document.getElementById('diarySearch');
    const diarySearchClear = document.getElementById('diarySearchClear');

    // ===== 状态 =====
    let diaryKeyword = '';

    // ===== 日记列表 =====
    window.loadDiaries = async function() {
        try {
            const kw = diaryKeyword || undefined;
            const date = kw ? undefined : getTodayStr();
            const data = await EchoAPI.fetchDiaries(date, kw);
            window.renderDiaries(data);
        } catch (e) {
            console.error('加载日记失败:', e);
            diaryList.innerHTML = '<p class="text-center text-gray-400 py-20">加载失败，请稍后再试</p>';
        }
    };

    window.renderDiaries = function(diaries) {
        diaryList.innerHTML = '';
        if (!diaries || diaries.length === 0) {
            diaryList.innerHTML = '<p class="text-center text-gray-400 py-20">还没有日记，写下第一篇吧 💭</p>';
            return;
        }
        diaries.forEach((d, i) => {
            diaryList.appendChild(createDiaryCard(d, { index: i }));
        });
        lucide.createIcons();
    };

    // ===== 日记搜索 =====
    let diarySearchTimer;
    diarySearch.addEventListener('input', () => {
        clearTimeout(diarySearchTimer);
        if (diarySearch.value.trim()) {
            diarySearchClear.style.display = 'flex';
        } else {
            diarySearchClear.style.display = 'none';
        }
        diarySearchTimer = setTimeout(() => {
            diaryKeyword = diarySearch.value.trim();
            window.loadDiaries();
        }, 350);
    });
    diarySearch.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            clearTimeout(diarySearchTimer);
            diaryKeyword = diarySearch.value.trim();
            window.loadDiaries();
        }
    });
    diarySearchClear.addEventListener('click', () => {
        diarySearch.value = '';
        diarySearchClear.style.display = 'none';
        diaryKeyword = '';
        window.loadDiaries();
        diarySearch.focus();
    });

    // ===== 时光胶囊列表 =====
    window.loadCapsules = async function() {
        try {
            const all = await EchoAPI.fetchDiaries();
            const capsules = (all || []).filter(d => d.unlock_date && d.unlock_date !== '');
            window.renderCapsules(capsules);
        } catch (e) {
            console.error('加载胶囊失败:', e);
            capsuleList.innerHTML = '<p class="text-center text-gray-400 py-20">加载失败，请稍后再试</p>';
        }
    };

    window.renderCapsules = function(capsules) {
        capsuleList.innerHTML = '';
        if (!capsules || capsules.length === 0) {
            capsuleList.innerHTML = `
                <div class="flex flex-col items-center justify-center py-20">
                    <i data-lucide="mailbox" class="w-16 h-16 text-indigo-100 mb-4" style="stroke-width:1.5"></i>
                    <p class="text-gray-400 text-sm mb-2">还没有时光胶囊</p>
                    <p class="text-gray-300 text-xs">点击上方按钮，写下第一封寄往未来的信吧</p>
                </div>`;
            lucide.createIcons();
            return;
        }
        capsules.forEach((d, i) => {
            capsuleList.appendChild(createDiaryCard(d, { index: i, animationDelay: 0.06 }));
        });
        lucide.createIcons();
    };

    // ===== 心情统计条 =====
    window.renderMoodBars = function(distribution, containerId) {
        if (containerId === undefined) containerId = 'moodBars';
        const container = document.getElementById(containerId);
        if (!distribution || !distribution.length) {
            container.innerHTML = '<p class="text-sm text-gray-400 text-center py-6">还没有数据，先写一篇日记吧</p>';
            return;
        }
        container.innerHTML = distribution.map(d => `
            <div class="flex items-center gap-3">
                <span class="text-xl w-8 text-center select-none shrink-0">${d.mood}</span>
                <div class="flex-1 h-7 rounded-full bg-gray-100 overflow-hidden">
                    <div class="h-full rounded-full flex items-end justify-end pr-2 transition-all duration-700 ease-out"
                         style="width:${d.percentage}%; background:${d.border}; opacity:0.75">
                        <span class="text-[10px] text-white font-medium drop-shadow">${d.percentage}%</span>
                    </div>
                </div>
                <span class="text-xs text-gray-400 w-8 text-right shrink-0">${d.count}次</span>
            </div>
        `).join('');
    };

})();

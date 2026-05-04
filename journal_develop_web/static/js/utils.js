/**
 * Echo 日记 - 工具函数库
 * 所有纯函数集中在此，无 DOM 副作用（shakeCard 除外，它是 UI 工具）
 */

function formatDate(dateStr) {
    if (!dateStr) return '';
    const d = new Date(dateStr.replace(' ', 'T'));
    if (isNaN(d.getTime())) {
        const [datePart, timePart] = dateStr.split(' ');
        const [, month, day] = datePart.split('-');
        const [hour, minute] = (timePart || '').split(':');
        return `${parseInt(month)}月${parseInt(day)}日 ${hour}:${minute}`;
    }
    return `${d.getMonth() + 1}月${d.getDate()}日 ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

function compressImage(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = (e) => {
            const img = new Image();
            img.onload = () => {
                const canvas = document.createElement('canvas');
                const maxW = 1200;
                let w = img.width, h = img.height;
                if (w > maxW) { h = Math.round(h * maxW / w); w = maxW; }
                canvas.width = w;
                canvas.height = h;
                const ctx = canvas.getContext('2d');
                ctx.drawImage(img, 0, 0, w, h);
                canvas.toBlob((blob) => {
                    if (blob) resolve(blob);
                    else reject(new Error('toBlob failed'));
                }, 'image/jpeg', 0.8);
            };
            img.onerror = reject;
            img.src = e.target.result;
        };
        reader.onerror = reject;
        reader.readAsDataURL(file);
    });
}

function calculateDaysLeft(unlockDateStr) {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const unlock = new Date(unlockDateStr + 'T00:00:00');
    return Math.ceil((unlock.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
}

function shakeCard(el) {
    el.classList.remove('shake');
    void el.offsetWidth;
    el.classList.add('shake');
    const toast = document.createElement('div');
    toast.className = 'fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 z-[70] bg-gray-800/90 text-white text-sm px-5 py-2.5 rounded-2xl shadow-xl pointer-events-none';
    toast.textContent = '🔒 嘘，还没到拆封时间呢~';
    document.body.appendChild(toast);
    setTimeout(() => toast.remove(), 1500);
}

function getTodayStr() {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/**
 * 让元素支持鼠标拖动横向滚动
 * - mousedown 记录起点，mousemove 改变 scrollLeft，mouseup 停止
 * - 拖动距离 < 5px 视为点击，不干扰子元素的 click 事件
 * - 同时添加 wheel 事件：鼠标滚轮在元素上时横向滚动
 */
function enableHorizontalDragScroll(el) {
    let isDown = false;
    let startX = 0;
    let scrollStart = 0;
    let moved = false;

    el.addEventListener('mousedown', (e) => {
        // 不拦截表单元素自身的交互（按钮点击等）
        if (e.target.closest('button, input, textarea, select')) return;
        isDown = true;
        moved = false;
        startX = e.pageX;
        scrollStart = el.scrollLeft;
        el.style.cursor = 'grabbing';
        e.preventDefault(); // 阻止浏览器默认行为（文本选中、原生拖拽）
    });

    // mousemove 绑定在 document，保证拖动不因鼠标离开元素而中断
    document.addEventListener('mousemove', (e) => {
        if (!isDown) return;
        const dx = e.pageX - startX;
        if (Math.abs(dx) > 4) moved = true;
        el.scrollLeft = scrollStart - dx;
    });

    const stop = () => {
        if (!isDown) return;
        isDown = false;
        moved = false;
        el.style.cursor = '';
    };
    document.addEventListener('mouseup', stop);
    el.addEventListener('mouseleave', stop);

    // 拖动后的 click 不触发子元素事件
    el.addEventListener('click', (e) => {
        if (moved) {
            e.stopPropagation();
            e.preventDefault();
            moved = false;
        }
    }, true);

    // 鼠标滚轮横向滚动
    el.addEventListener('wheel', (e) => {
        if (Math.abs(e.deltaX) > Math.abs(e.deltaY)) return; // 触控板自然横向手势优先
        e.preventDefault();
        el.scrollLeft += e.deltaY;
    }, { passive: false });
}

/**
 * Echo 日记 - 调试工具
 * 仅在开发环境使用，生产环境应移除
 */
window.Debug = {
    enabled: true,  // 生产环境设为 false

    log(...args) {
        if (this.enabled) console.log('[Debug]', ...args);
    },

    error(...args) {
        if (this.enabled) console.error('[Error]', ...args);
    },

    warn(...args) {
        if (this.enabled) console.warn('[Warn]', ...args);
    },

    // WebSocket 日志
    ws(...args) {
        if (this.enabled) console.log('[WS]', ...args);
    },

    // 临时调试：追踪函数执行
    trace(fn, label = 'fn') {
        return async (...args) => {
            this.log(`${label} 开始`);
            try {
                const result = await fn(...args);
                this.log(`${label} 完成`, result);
                return result;
            } catch (e) {
                this.error(`${label} 失败`, e);
                throw e;
            }
        };
    },

    // 日历调试
    calendar(...args) {
        if (this.enabled) console.log('[日历]', ...args);
    },
};
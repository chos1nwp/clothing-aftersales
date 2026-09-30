/**
 * 统一 fetch 封装：解析 {code,message,data}，非 2xx 抛出带 status 的错误。
 */
async function api(path, options = {}) {
  const init = {
    method: options.method || 'GET',
    headers: {},
    body: undefined
  };
  if (options.json !== false && options.body !== undefined && !(options.body instanceof FormData)) {
    init.headers['Content-Type'] = 'application/json';
    init.body = JSON.stringify(options.body);
  } else if (options.body instanceof FormData) {
    init.body = options.body;
  }

  const response = await fetch(path, init);
  let payload = {};
  try {
    payload = await response.json();
  } catch (e) {
    throw Object.assign(new Error('服务未返回有效响应'), { status: response.status });
  }
  if (!response.ok) {
    throw Object.assign(new Error(payload.message || '请求失败'), { status: response.status });
  }
  return payload.data;
}

const ROLE_HOME = {
  CONSUMER: 'consumer-orders.html',
  CS: 'cs-workbench.html',
  WAREHOUSE: 'warehouse-workbench.html'
};

const NAV_BY_ROLE = {
  CONSUMER: [
    ['consumer-orders.html', '我的订单'],
    ['consumer-list.html', '我的售后单']
  ],
  CS: [
    ['cs-workbench.html', '客服工作台']
  ],
  WAREHOUSE: [
    ['warehouse-workbench.html', '仓库工作台']
  ]
};

let cachedUser = null;

async function requireUser() {
  if (cachedUser) return cachedUser;
  try {
    cachedUser = await api('/api/auth/me');
  } catch (error) {
    if (error.status === 401) {
      location.href = 'index.html';
      throw error;
    }
    throw error;
  }
  return cachedUser;
}

function renderNav(user) {
  const nav = document.getElementById('nav');
  if (!nav) return;
  const links = (NAV_BY_ROLE[user.role] || [])
    .map(([href, label]) => {
      const active = location.pathname.endsWith(href) ? ' active' : '';
      return `<a class="nav-link${active}" href="${href}">${label}</a>`;
    })
    .join('');
  nav.innerHTML = `
    <div class="nav-links">${links}</div>
    <div class="nav-user">
      <span class="role-tag">${escapeHtml(user.roleLabel)}</span>
      <span class="muted">${escapeHtml(user.displayName)}</span>
      <button class="btn tiny" id="logout-btn">退出</button>
    </div>`;
  document.getElementById('logout-btn').addEventListener('click', async () => {
    await api('/api/auth/logout', { method: 'POST' });
    location.href = 'index.html';
  });
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  })[c]);
}

function showToast(message, type = 'success') {
  const box = document.getElementById('toast');
  if (!box) {
    alert(message);
    return;
  }
  box.textContent = message;
  box.className = `toast ${type}`;
  box.hidden = false;
  clearTimeout(box._timer);
  box._timer = setTimeout(() => { box.hidden = true; }, 3500);
}

/** 表格区域通用渲染：加载中 / 空数据 / 错误 */
function renderState(container, state, options = {}) {
  if (state === 'loading') {
    container.innerHTML = `<div class="state">${options.loadingText || '加载中…'}</div>`;
  } else if (state === 'empty') {
    container.innerHTML = `<div class="state">${options.emptyText || '暂无数据'}</div>`;
  } else if (state === 'error') {
    container.innerHTML = `<div class="state error-text">${escapeHtml(options.message || '加载失败')}</div>`;
  }
}

const STATUS_LABEL = {
  PENDING_REVIEW: '待审核',
  NEED_SUPPLEMENT: '待补充',
  WAIT_RETURN: '待退回',
  WAIT_RECEIPT: '待收货',
  WAIT_FINAL_REVIEW: '待确认',
  COMPLETED: '已完成',
  REJECTED: '已拒绝',
  CANCELLED: '已取消'
};

const ACTION_LABEL = {
  APPLY: '提交申请',
  SUPPLEMENT_REQUEST: '要求补充材料',
  RESUBMIT: '补充后重新提交',
  APPROVE_RETURN: '同意退回',
  REJECT: '拒绝申请',
  MARK_SHIPPED: '消费者已寄回',
  CANCEL: '撤销申请',
  RECEIVE: '登记收货',
  INSPECT_PASS: '验货合格',
  INSPECT_ABNORMAL: '验货异常',
  FINAL_EXCHANGE: '确认换货补发',
  FINAL_REFUND: '确认退款',
  FINAL_REJECT: '最终拒绝'
};

const TYPE_LABEL = { RETURN: '退货', EXCHANGE: '换货' };
const REASON_LABEL = {
  SIZE: '尺码不合适', DAMAGED: '商品破损', WRONG_ITEM: '商家错发',
  QUALITY: '质量问题', OTHER: '其他原因'
};

function statusBadge(status) {
  return `<span class="badge status-${status}">${STATUS_LABEL[status] || status}</span>`;
}

function formatTime(value) {
  return value ? String(value).replace('T', ' ').slice(0, 19) : '—';
}

function queryParam(name) {
  return new URLSearchParams(location.search).get(name);
}

/** 写操作失败时按状态区分提示：409 是并发冲突，需要用户刷新后重看 */
function failWithToast(error) {
  const type = error.status === 409 ? 'conflict' : 'error';
  showToast(error.message, type);
  return type;
}

function renderTimeline(items, withVisibility) {
  if (!items || !items.length) return '<div class="state">暂无操作记录</div>';
  return `<ul class="timeline">${items.map(t => `
    <li>
      <div class="tl-head">${ACTION_LABEL[t.action] || t.action} ${statusBadge(t.toStatus)}</div>
      <div class="tl-meta">
        ${formatTime(t.createdAt)} · ${escapeHtml(t.operatorName || '')}（${t.operatorRole}）
        ${withVisibility ? ` · 对消费者可见=${t.visibleToConsumer ? '是' : '否（内部）'}` : ''}
      </div>
      <div>${escapeHtml(t.note || '')}</div>
    </li>`).join('')}</ul>`;
}

async function bootstrap() {
  const user = await requireUser();
  renderNav(user);
  return user;
}

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
  WAIT_FINAL_REVIEW: '待客服确认',
  COMPLETED: '已完成',
  REJECTED: '已拒绝',
  CANCELLED: '已取消'
};

const TYPE_LABEL = { RETURN: '退货', EXCHANGE: '换货' };
const REASON_LABEL = {
  SIZE: '尺码不合适', DAMAGED: '商品破损', WRONG_ITEM: '商家错发',
  QUALITY: '质量问题', OTHER: '其他原因'
};

function statusBadge(status) {
  return `<span class="badge status-${status}">${STATUS_LABEL[status] || status}</span>`;
}

async function bootstrap() {
  const user = await requireUser();
  renderNav(user);
  return user;
}

let store = {
  events: [],
  todos: [],
  stickyNotes: [],
  settings: {
    isMiniBoardPinnedOnTop: true,
    stickyWindowOpacity: 0.95
  }
};

let currentTab = 'today';
let isPinned = true;
let editingItem = null; // { type: 'event'|'todo', id: string }

const STICKY_COLORS = ['yellow', 'pink', 'blue', 'green', 'purple'];

function renderMiniView() {
  if (currentTab === 'memo') {
    document.getElementById('miniNormalContainer').style.display = 'none';
    document.getElementById('miniMemoContainer').style.display = 'flex';
    renderStickyNotes();
  } else {
    document.getElementById('miniNormalContainer').style.display = 'flex';
    document.getElementById('miniMemoContainer').style.display = 'none';
    renderMiniCards();
  }
}

function renderMiniCards() {
  const container = document.getElementById('miniCardsList');
  container.innerHTML = '';

  const today = new Date();

  // Filter events
  const tabEvents = store.events.filter(e => {
    if (currentTab === 'today') {
      const eventStart = new Date(e.startDate);
      return (
        eventStart.getFullYear() === today.getFullYear() &&
        eventStart.getMonth() === today.getMonth() &&
        eventStart.getDate() === today.getDate()
      );
    }
    return true;
  });

  const tabTodos = store.todos.filter(t => {
    if (currentTab === 'today') return t.scope === 'today';
    if (currentTab === 'week') return t.scope === 'week';
    if (currentTab === 'month') return t.scope === 'month';
    return true;
  });

  let idx = 1;

  tabEvents.forEach(event => {
    const card = document.createElement('div');
    card.className = `capsule-card ${event.isCompleted ? 'completed' : ''}`;

    const folderTagHtml = event.linkedFolderPath ? `
      <div class="mini-postit-tag">
        <span class="folder-icon">${ICONS.folder}</span>
        <span>${event.linkedFolderPath.split(/[\\/]/).pop()}</span>
        ${ICONS.link}
      </div>
    ` : '';

    card.innerHTML = `
      <button class="capsule-check-btn">${event.isCompleted ? ICONS.check : idx}</button>
      <div class="capsule-content">
        <div class="capsule-title-row">
          <span class="capsule-title">${event.title}</span>
          ${folderTagHtml}
        </div>
        <div class="capsule-sub-row">
          <span style="display: inline-flex; align-items: center; gap: 4px;">
            ${event.periodType === 'timed' ? ICONS.clock + ' ' + (event.startTime || '10:00') : ICONS.calendar + ' ' + event.periodType}
          </span>
          <span style="color: var(--primary-color); font-size: 10px; margin-left: auto;">수정</span>
        </div>
      </div>
    `;

    card.querySelector('.capsule-check-btn').addEventListener('click', (e) => {
      e.stopPropagation();
      event.isCompleted = !event.isCompleted;
      window.api.saveData(store);
      renderMiniCards();
    });

    const folderTag = card.querySelector('.mini-postit-tag');
    if (folderTag) {
      folderTag.addEventListener('click', (e) => {
        e.stopPropagation();
        window.api.openFolder(event.linkedFolderPath);
      });
    }

    // Clicking card opens the edit modal!
    card.addEventListener('click', () => {
      openEditModal('event', event.id);
    });

    container.appendChild(card);
    idx++;
  });

  tabTodos.forEach(todo => {
    const card = document.createElement('div');
    card.className = `capsule-card ${todo.isCompleted ? 'completed' : ''}`;

    const folderTagHtml = todo.linkedFolderPath ? `
      <div class="mini-postit-tag">
        <span class="folder-icon">${ICONS.folder}</span>
        <span>${todo.linkedFolderPath.split(/[\\/]/).pop()}</span>
        ${ICONS.link}
      </div>
    ` : '';

    card.innerHTML = `
      <button class="capsule-check-btn">${todo.isCompleted ? ICONS.check : idx}</button>
      <div class="capsule-content">
        <div class="capsule-title-row">
          <span class="capsule-title">${todo.title}</span>
          ${folderTagHtml}
        </div>
        <div class="capsule-sub-row">
          <span>할 일 · ${todo.scope === 'today' ? '오늘' : (todo.scope === 'week' ? '이번 주' : '이번 달')}</span>
          <span style="color: var(--primary-color); font-size: 10px; margin-left: auto;">수정</span>
        </div>
      </div>
    `;

    card.querySelector('.capsule-check-btn').addEventListener('click', (e) => {
      e.stopPropagation();
      todo.isCompleted = !todo.isCompleted;
      window.api.saveData(store);
      renderMiniCards();
    });

    const folderTag = card.querySelector('.mini-postit-tag');
    if (folderTag) {
      folderTag.addEventListener('click', (e) => {
        e.stopPropagation();
        window.api.openFolder(todo.linkedFolderPath);
      });
    }

    // Clicking card opens the edit modal!
    card.addEventListener('click', () => {
      openEditModal('todo', todo.id);
    });

    container.appendChild(card);
    idx++;
  });
}

function renderStickyNotes() {
  const container = document.getElementById('miniMemoList');
  container.innerHTML = '';

  if (!store.stickyNotes) store.stickyNotes = [];

  store.stickyNotes.forEach(note => {
    const noteEl = document.createElement('div');
    noteEl.className = `sticky-note-card sticky-note-${note.color || 'yellow'}`;

    noteEl.innerHTML = `
      <div class="sticky-note-header">
        <div class="sticky-color-dot" style="background: currentColor;"></div>
        <input type="text" class="sticky-note-title" placeholder="제목 (선택)" value="${note.title || ''}">
        <button class="btn-delete-note" style="border: none; background: none; cursor: pointer; font-size: 14px; opacity: 0.6;">&times;</button>
      </div>
      <textarea class="sticky-note-body" placeholder="메모 내용 입력...">${note.content || ''}</textarea>
    `;

    const titleInput = noteEl.querySelector('.sticky-note-title');
    const bodyInput = noteEl.querySelector('.sticky-note-body');
    const colorDot = noteEl.querySelector('.sticky-color-dot');
    const deleteBtn = noteEl.querySelector('.btn-delete-note');

    titleInput.addEventListener('input', (e) => {
      note.title = e.target.value;
      window.api.saveData(store);
    });

    bodyInput.addEventListener('input', (e) => {
      note.content = e.target.value;
      window.api.saveData(store);
    });

    colorDot.addEventListener('click', () => {
      const curIdx = STICKY_COLORS.indexOf(note.color || 'yellow');
      note.color = STICKY_COLORS[(curIdx + 1) % STICKY_COLORS.length];
      window.api.saveData(store);
      renderStickyNotes();
    });

    deleteBtn.addEventListener('click', () => {
      store.stickyNotes = store.stickyNotes.filter(n => n.id !== note.id);
      window.api.saveData(store);
      renderStickyNotes();
    });

    container.appendChild(noteEl);
  });
}

// Edit Modal in Mini Board
function openEditModal(type, id) {
  editingItem = { type, id };
  const modal = document.getElementById('miniEditModal');

  if (type === 'event') {
    const event = store.events.find(e => e.id === id);
    if (!event) return;
    document.getElementById('miniEditModalTitle').textContent = '일정 수정';
    document.getElementById('miniEditTitleInput').value = event.title;
    document.getElementById('miniEditScopeGroup').style.display = 'none';
    document.getElementById('miniEditFolderInput').value = event.linkedFolderPath || '';
    document.getElementById('miniEditNotesInput').value = event.notes || '';
  } else {
    const todo = store.todos.find(t => t.id === id);
    if (!todo) return;
    document.getElementById('miniEditModalTitle').textContent = '할 일 수정';
    document.getElementById('miniEditTitleInput').value = todo.title;
    document.getElementById('miniEditScopeGroup').style.display = 'block';
    document.getElementById('miniEditScopeSelect').value = todo.scope || 'today';
    document.getElementById('miniEditFolderInput').value = todo.linkedFolderPath || '';
    document.getElementById('miniEditNotesInput').value = todo.notes || '';
  }

  modal.style.display = 'flex';
}

document.getElementById('btnCloseMiniEditModal').addEventListener('click', () => {
  document.getElementById('miniEditModal').style.display = 'none';
});

document.getElementById('btnChooseMiniFolder').addEventListener('click', async () => {
  const folder = await window.api.chooseFolder();
  if (folder) {
    document.getElementById('miniEditFolderInput').value = folder;
  }
});

document.getElementById('btnClearMiniFolder').addEventListener('click', () => {
  document.getElementById('miniEditFolderInput').value = '';
});

document.getElementById('btnSaveMiniItem').addEventListener('click', () => {
  if (!editingItem) return;
  const title = document.getElementById('miniEditTitleInput').value.trim();
  if (!title) return;
  const folderPath = document.getElementById('miniEditFolderInput').value.trim() || null;
  const notes = document.getElementById('miniEditNotesInput').value;

  if (editingItem.type === 'event') {
    const event = store.events.find(e => e.id === editingItem.id);
    if (event) {
      event.title = title;
      event.linkedFolderPath = folderPath;
      event.notes = notes;
    }
  } else {
    const todo = store.todos.find(t => t.id === editingItem.id);
    if (todo) {
      todo.title = title;
      todo.scope = document.getElementById('miniEditScopeSelect').value;
      todo.linkedFolderPath = folderPath;
      todo.notes = notes;
    }
  }

  document.getElementById('miniEditModal').style.display = 'none';
  window.api.saveData(store);
  renderMiniCards();
});

document.getElementById('btnDeleteMiniItem').addEventListener('click', () => {
  if (!editingItem) return;
  if (editingItem.type === 'event') {
    store.events = store.events.filter(e => e.id !== editingItem.id);
  } else {
    store.todos = store.todos.filter(t => t.id !== editingItem.id);
  }
  document.getElementById('miniEditModal').style.display = 'none';
  window.api.saveData(store);
  renderMiniCards();
});

document.getElementById('btnAddNewMemo').addEventListener('click', () => {
  if (!store.stickyNotes) store.stickyNotes = [];
  const color = STICKY_COLORS[store.stickyNotes.length % STICKY_COLORS.length];
  store.stickyNotes.unshift({
    id: 'memo_' + Date.now(),
    title: '',
    content: '',
    color
  });
  window.api.saveData(store);
  renderStickyNotes();
});

document.getElementById('btnReturnToMain').addEventListener('click', () => {
  window.api.switchToMain();
});

const pinBtn = document.getElementById('btnPinToggle');
pinBtn.addEventListener('click', () => {
  isPinned = !isPinned;
  window.api.setMiniAlwaysOnTop(isPinned);
  if (isPinned) {
    pinBtn.classList.add('pinned');
    pinBtn.innerHTML = `${ICONS.pin} 항상 위`;
  } else {
    pinBtn.classList.remove('pinned');
    pinBtn.innerHTML = `${ICONS.pin} 고정 해제`;
  }
});

const opacitySlider = document.getElementById('miniOpacitySlider');
const opacityLabel = document.getElementById('miniOpacityLabel');
opacitySlider.addEventListener('input', (e) => {
  const val = parseInt(e.target.value, 10);
  opacityLabel.textContent = `${val}%`;
  window.api.setMiniOpacity(val / 100);
});

document.querySelectorAll('.tabs-segmented .tab-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.tabs-segmented .tab-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    currentTab = btn.getAttribute('data-tab');
    renderMiniView();
  });
});

document.getElementById('miniQuickAddInput').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') {
    const val = e.target.value.trim();
    if (!val) return;
    store.todos.push({
      id: 'todo_' + Date.now(),
      title: val,
      scope: currentTab === 'month' ? 'month' : (currentTab === 'week' ? 'week' : 'today'),
      isCompleted: false
    });
    e.target.value = '';
    window.api.saveData(store);
    renderMiniCards();
  }
});

window.addEventListener('DOMContentLoaded', async () => {
  store = await window.api.getData();
  window.api.onDataUpdated((newData) => {
    store = newData;
    renderMiniView();
  });
  renderMiniView();
});

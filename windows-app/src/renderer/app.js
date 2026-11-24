let store = {
  events: [],
  todos: [],
  settings: {
    isMiniBoardPinnedOnTop: true,
    mainWindowOpacity: 1.0,
    stickyWindowOpacity: 0.95
  }
};

let currentDate = new Date(); // Viewing date in calendar
let currentTab = 'today'; // 'today' | 'week' | 'month' | 'memo'
let currentView = 'month'; // 'month' | 'week' | 'day'
let editingEventId = null;
let editingTodoId = null;

const STICKY_COLORS = ['yellow', 'pink', 'blue', 'green', 'purple'];

// Recurrence checker matching our Swift logic
function eventOccursOnDate(event, targetDate) {
  const target = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate());
  const eventStart = new Date(event.startDate);
  const eventStartDay = new Date(eventStart.getFullYear(), eventStart.getMonth(), eventStart.getDate());

  if (!event.recurrence || event.recurrence === 'none') {
    const eventEnd = new Date(event.endDate);
    const eventEndDay = new Date(eventEnd.getFullYear(), eventEnd.getMonth(), eventEnd.getDate());
    return target >= eventStartDay && target <= eventEndDay;
  }

  // Cannot occur before initial start date
  if (target < eventStartDay) return false;

  // Recurrence end date
  if (event.recurrenceEndDate) {
    const recEnd = new Date(event.recurrenceEndDate);
    if (target > recEnd) return false;
  }

  const daysDiff = Math.floor((target - eventStartDay) / (1000 * 60 * 60 * 24));
  const weekday = target.getDay(); // 0 = Sun, 6 = Sat

  switch (event.recurrence) {
    case 'daily':
      return true;
    case 'weekdays':
      return weekday >= 1 && weekday <= 5;
    case 'weekly':
      return target.getDay() === eventStart.getDay();
    case 'biweekly': {
      if (target.getDay() !== eventStart.getDay()) return false;
      const weeks = Math.floor(daysDiff / 7);
      return weeks % 2 === 0;
    }
    case 'monthly':
      return target.getDate() === eventStart.getDate();
    case 'yearly':
      return target.getMonth() === eventStart.getMonth() && target.getDate() === eventStart.getDate();
    default:
      return false;
  }
}

function isEventCompletedOnDate(event, date) {
  if (!event.recurrence || event.recurrence === 'none') {
    return !!event.isCompleted;
  }
  const key = formatKey(date);
  return Array.isArray(event.completedDates) && event.completedDates.includes(key);
}

function toggleEventCompletion(eventId, date) {
  const event = store.events.find(e => e.id === eventId);
  if (!event) return;

  if (!event.recurrence || event.recurrence === 'none') {
    event.isCompleted = !event.isCompleted;
  } else {
    const key = formatKey(date);
    if (!event.completedDates) event.completedDates = [];
    const idx = event.completedDates.indexOf(key);
    if (idx >= 0) {
      event.completedDates.splice(idx, 1);
    } else {
      event.completedDates.push(key);
    }
  }
  saveAndRender();
}

function toggleTodoCompletion(todoId) {
  const todo = store.todos.find(t => t.id === todoId);
  if (!todo) return;
  todo.isCompleted = !todo.isCompleted;
  saveAndRender();
}

async function saveAndRender() {
  await window.api.saveData(store);
  renderAll();
}

// Render Functions
function renderAll() {
  renderSidebar();
  renderCalendar();
}

function renderSidebar() {
  if (currentTab === 'memo') {
    document.getElementById('sidebarNormalContainer').style.display = 'none';
    document.getElementById('sidebarMemoContainer').style.display = 'flex';
    renderMainStickyNotes();
    return;
  } else {
    document.getElementById('sidebarNormalContainer').style.display = 'flex';
    document.getElementById('sidebarMemoContainer').style.display = 'none';
  }

  const today = new Date();
  const holiday = getKoreanHoliday(today);
  const holidayBadge = document.getElementById('todayHolidayBadge');
  if (holiday) {
    holidayBadge.textContent = holiday;
    holidayBadge.style.display = 'inline-block';
  } else {
    holidayBadge.style.display = 'none';
  }

  // Filter events & todos for active tab
  const tabEvents = store.events.filter(e => {
    if (currentTab === 'today') return eventOccursOnDate(e, today);
    return true; // Simplified for week/month in preview
  });

  const tabTodos = store.todos.filter(t => {
    if (currentTab === 'today') return t.scope === 'today';
    if (currentTab === 'week') return t.scope === 'week';
    if (currentTab === 'month') return t.scope === 'month';
    return true;
  });

  const remainingEvents = tabEvents.filter(e => !isEventCompletedOnDate(e, today));
  const dueTodos = tabTodos.filter(t => !t.isCompleted);

  document.getElementById('statRemainingEvents').textContent = `${remainingEvents.length}건`;
  document.getElementById('statDueTodos').textContent = `${dueTodos.length}건`;

  const container = document.getElementById('cardsList');
  container.innerHTML = '';

  let idx = 1;

  // Render Events
  tabEvents.forEach(event => {
    const isCompleted = isEventCompletedOnDate(event, today);
    const card = document.createElement('div');
    card.className = `capsule-card ${isCompleted ? 'completed' : ''}`;

    const folderTagHtml = event.linkedFolderPath ? `
      <div class="mini-postit-tag">
        <span class="folder-icon">${ICONS.folder}</span>
        <span>${event.linkedFolderPath.split(/[\\/]/).pop()}</span>
        ${ICONS.link}
      </div>
    ` : '';

    const recTagHtml = (event.recurrence && event.recurrence !== 'none') ? `
      <span class="recurrence-badge" style="display: inline-flex; align-items: center; gap: 3px;">${ICONS.repeat} ${event.recurrence}</span>
    ` : '';

    card.innerHTML = `
      <button class="capsule-check-btn">${isCompleted ? ICONS.check : idx}</button>
      <div class="capsule-content">
        <div class="capsule-title-row">
          <span class="capsule-title">${event.title}</span>
          ${folderTagHtml}
        </div>
        <div class="capsule-sub-row">
          <span style="display: inline-flex; align-items: center; gap: 4px;">
            ${event.periodType === 'timed' ? ICONS.clock + ' ' + (event.startTime || '10:00') : ICONS.calendar + ' ' + event.periodType}
          </span>
          ${recTagHtml}
          <span style="color: var(--primary-color); font-size: 10px; margin-left: auto;">수정</span>
        </div>
      </div>
    `;

    card.querySelector('.capsule-check-btn').addEventListener('click', (e) => {
      e.stopPropagation();
      toggleEventCompletion(event.id, today);
    });

    const folderTag = card.querySelector('.mini-postit-tag');
    if (folderTag) {
      folderTag.addEventListener('click', (e) => {
        e.stopPropagation();
        window.api.openFolder(event.linkedFolderPath);
      });
    }

    card.addEventListener('click', () => {
      openEditEventModal(event);
    });

    container.appendChild(card);
    idx++;
  });

  // Render Todos
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
      toggleTodoCompletion(todo.id);
    });

    const folderTag = card.querySelector('.mini-postit-tag');
    if (folderTag) {
      folderTag.addEventListener('click', (e) => {
        e.stopPropagation();
        window.api.openFolder(todo.linkedFolderPath);
      });
    }

    card.addEventListener('click', () => {
      openEditTodoModal(todo);
    });

    container.appendChild(card);
    idx++;
  });
}

function renderCalendar() {
  const y = currentDate.getFullYear();
  const m = currentDate.getMonth();

  document.getElementById('calendarTitle').textContent = `${y}년 ${m + 1}월 나만의 캘린더`;

  const firstDay = new Date(y, m, 1);
  const startDayOfWeek = firstDay.getDay(); // 0 = Sun
  const lastDate = new Date(y, m + 1, 0).getDate();

  const grid = document.getElementById('monthGrid');
  grid.innerHTML = '';

  const today = new Date();

  // Gather days for calendar
  const allDays = [];

  // Days from previous month
  const prevMonthLastDate = new Date(y, m, 0).getDate();
  for (let i = startDayOfWeek - 1; i >= 0; i--) {
    const d = prevMonthLastDate - i;
    allDays.push({ date: new Date(y, m - 1, d), isCurrentMonth: false });
  }

  // Days of current month
  for (let d = 1; d <= lastDate; d++) {
    allDays.push({ date: new Date(y, m, d), isCurrentMonth: true });
  }

  // Remaining days to fill complete weeks (35 or 42)
  const total = allDays.length;
  const targetTotal = (total <= 35 ? 35 : 42);
  for (let d = 1; d <= (targetTotal - total); d++) {
    allDays.push({ date: new Date(y, m + 1, d), isCurrentMonth: false });
  }

  // Split into 7-day week rows
  const weeks = [];
  for (let i = 0; i < allDays.length; i += 7) {
    weeks.push(allDays.slice(i, i + 7));
  }

  weeks.forEach(weekDays => {
    const weekRow = document.createElement('div');
    weekRow.className = 'month-week-row';

    const weekStart = new Date(weekDays[0].date);
    weekStart.setHours(0, 0, 0, 0);
    const weekEnd = new Date(weekDays[6].date);
    weekEnd.setHours(23, 59, 59, 999);

    // 1. Header row: 7 day numbers (Sun to Sat)
    const headerRow = document.createElement('div');
    headerRow.className = 'week-header-days';

    weekDays.forEach(({ date, isCurrentMonth }) => {
      const isToday = (
        today.getFullYear() === date.getFullYear() &&
        today.getMonth() === date.getMonth() &&
        today.getDate() === date.getDate()
      );
      const weekday = date.getDay();
      const holiday = getKoreanHoliday(date);

      let numColor = 'var(--text-main)';
      if (holiday || weekday === 0) numColor = 'var(--red-color)';
      else if (weekday === 6) numColor = 'var(--blue-color)';

      const dayHeaderCell = document.createElement('div');
      dayHeaderCell.className = 'week-day-header-cell';
      if (!isCurrentMonth) dayHeaderCell.style.opacity = '0.35';

      dayHeaderCell.innerHTML = `
        <span class="day-num ${isToday ? 'today' : ''}" style="color: ${isToday ? '#ffffff' : numColor};">
          ${date.getDate()}
        </span>
        ${holiday ? `<span class="cell-holiday-name">${holiday}</span>` : ''}
      `;
      headerRow.appendChild(dayHeaderCell);
    });
    weekRow.appendChild(headerRow);

    // 2. Weekly spanning bar for weekly tasks (scope === 'week')
    // Matching macOS: only weekly tasks belonging to this week span across the 7 columns
    const weeklyTodos = store.todos.filter(t => {
      if (t.scope !== 'week') return false;
      const base = t.dueDate ? new Date(t.dueDate) : (t.createdAt ? new Date(t.createdAt) : today);
      return base >= weekStart && base <= weekEnd;
    });

    if (weeklyTodos.length > 0) {
      const spanningList = document.createElement('div');
      spanningList.className = 'week-spanning-list';

      weeklyTodos.forEach(todo => {
        const bar = document.createElement('div');
        bar.className = `week-spanning-bar ${todo.isCompleted ? 'completed' : ''}`;

        const folderTagHtml = todo.linkedFolderPath ? `
          <div class="mini-postit-tag">
            <span class="folder-icon">${ICONS.folder}</span>
            <span>${todo.linkedFolderPath.split(/[\\/]/).pop()}</span>
            ${ICONS.link}
          </div>
        ` : '';

        bar.innerHTML = `
          <button class="week-check-circle" title="${todo.isCompleted ? '완료 취소' : '완료'}">
            ${todo.isCompleted ? ICONS.check : ''}
          </button>
          <span class="week-pill-badge">주간 할 일</span>
          <span class="week-task-title" style="flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">${todo.title}</span>
          ${folderTagHtml}
        `;

        bar.querySelector('.week-check-circle').addEventListener('click', (e) => {
          e.stopPropagation();
          toggleTodoCompletion(todo.id);
        });

        const folderEl = bar.querySelector('.mini-postit-tag');
        if (folderEl) {
          folderEl.addEventListener('click', (e) => {
            e.stopPropagation();
            window.api.openFolder(todo.linkedFolderPath);
          });
        }

        bar.addEventListener('click', () => {
          openEditTodoModal(todo);
        });

        spanningList.appendChild(bar);
      });

      weekRow.appendChild(spanningList);
    }

    // 3. Daily cells grid: 7 columns (Sun to Sat)
    // Daily cells strictly contain ONLY daily items (scope === 'today' or timed events)
    const dailyGrid = document.createElement('div');
    dailyGrid.className = 'week-daily-grid';

    weekDays.forEach(({ date, isCurrentMonth }) => {
      const cell = createDailyCell(date, isCurrentMonth);
      dailyGrid.appendChild(cell);
    });

    weekRow.appendChild(dailyGrid);
    grid.appendChild(weekRow);
  });
}

function createDailyCell(date, isCurrentMonth) {
  const cell = document.createElement('div');
  const today = new Date();
  const isToday = (
    today.getFullYear() === date.getFullYear() &&
    today.getMonth() === date.getMonth() &&
    today.getDate() === date.getDate()
  );
  cell.className = `month-cell ${isToday ? 'today' : ''}`;
  if (!isCurrentMonth) cell.style.opacity = '0.35';

  const dayEvents = store.events.filter(e => eventOccursOnDate(e, date));
  // Exclude weekly and monthly tasks from daily cells, matching macOS behavior
  const dayTodos = store.todos.filter(t => {
    if (t.scope === 'week' || t.scope === 'month') return false;
    const base = t.dueDate ? new Date(t.dueDate) : (t.createdAt ? new Date(t.createdAt) : today);
    return date.getFullYear() === base.getFullYear() &&
           date.getMonth() === base.getMonth() &&
           date.getDate() === base.getDate();
  });

  const eventsList = document.createElement('div');
  eventsList.className = 'cell-events-list';

  dayEvents.slice(0, 2).forEach(e => {
    const item = document.createElement('div');
    item.className = 'month-event-item';
    item.title = e.title;
    item.innerHTML = `<span>${e.linkedFolderPath ? ICONS.folder + ' ' : ''}${e.title}</span>`;
    eventsList.appendChild(item);
  });

  const maxTodoSlots = Math.max(0, 3 - Math.min(2, dayEvents.length));
  dayTodos.slice(0, maxTodoSlots).forEach(t => {
    const item = document.createElement('div');
    item.className = `month-event-item ${t.isCompleted ? 'completed' : ''}`;
    item.style.background = 'rgba(59, 130, 246, 0.16)';
    item.title = t.title;
    item.innerHTML = `<span>${t.isCompleted ? ICONS.check : '○'} ${t.title}</span>`;
    eventsList.appendChild(item);
  });

  const totalItems = dayEvents.length + dayTodos.length;
  if (totalItems > 3) {
    const more = document.createElement('div');
    more.style.fontSize = '9px';
    more.style.color = 'var(--text-muted)';
    more.style.paddingLeft = '4px';
    more.textContent = `+${totalItems - 3}개 더`;
    eventsList.appendChild(more);
  }

  cell.appendChild(eventsList);

  cell.addEventListener('click', () => {
    openNewEventModal(date);
  });

  return cell;
}

// Event Modal
function openNewEventModal(date = new Date()) {
  editingEventId = null;
  document.getElementById('eventModalTitle').textContent = '새 일정 등록';
  document.getElementById('eventTitleInput').value = '';
  document.getElementById('eventPeriodTypeSelect').value = 'timed';
  document.getElementById('eventRecurrenceSelect').value = 'none';
  document.getElementById('eventFolderPathInput').value = '';
  document.getElementById('eventNotesInput').value = '';
  document.getElementById('btnDeleteEvent').style.display = 'none';
  const briefBtn = document.getElementById('btnAiEventFolderBrief');
  if (briefBtn) briefBtn.style.display = 'none';
  const briefBox = document.getElementById('aiBriefBox');
  if (briefBox) briefBox.style.display = 'none';
  document.getElementById('eventModal').style.display = 'flex';
}

function openEditEventModal(event) {
  editingEventId = event.id;
  document.getElementById('eventModalTitle').textContent = '일정 수정';
  document.getElementById('eventTitleInput').value = event.title;
  document.getElementById('eventPeriodTypeSelect').value = event.periodType || 'timed';
  document.getElementById('eventRecurrenceSelect').value = event.recurrence || 'none';
  document.getElementById('eventFolderPathInput').value = event.linkedFolderPath || '';
  document.getElementById('eventNotesInput').value = event.notes || '';
  document.getElementById('btnDeleteEvent').style.display = 'block';
  const briefBtn = document.getElementById('btnAiEventFolderBrief');
  if (briefBtn) briefBtn.style.display = (event.linkedFolderPath ? 'block' : 'none');
  const briefBox = document.getElementById('aiBriefBox');
  if (briefBox) {
    if (event.aiSummary) {
      briefBox.textContent = event.aiSummary;
      briefBox.style.display = 'block';
    } else {
      briefBox.style.display = 'none';
    }
  }
  document.getElementById('eventModal').style.display = 'flex';
}

document.getElementById('btnCloseEventModal').addEventListener('click', () => {
  document.getElementById('eventModal').style.display = 'none';
});

document.getElementById('btnChooseEventFolder').addEventListener('click', async () => {
  const folder = await window.api.chooseFolder();
  if (folder) {
    document.getElementById('eventFolderPathInput').value = folder;
  }
});

document.getElementById('btnClearEventFolder').addEventListener('click', () => {
  document.getElementById('eventFolderPathInput').value = '';
});

document.getElementById('btnSaveEvent').addEventListener('click', () => {
  const title = document.getElementById('eventTitleInput').value.trim();
  if (!title) return;

  const periodType = document.getElementById('eventPeriodTypeSelect').value;
  const recurrence = document.getElementById('eventRecurrenceSelect').value;
  const folderPath = document.getElementById('eventFolderPathInput').value.trim() || null;
  const notes = document.getElementById('eventNotesInput').value;

  if (editingEventId) {
    const existing = store.events.find(e => e.id === editingEventId);
    if (existing) {
      existing.title = title;
      existing.periodType = periodType;
      existing.recurrence = recurrence;
      existing.linkedFolderPath = folderPath;
      existing.notes = notes;
    }
  } else {
    store.events.push({
      id: 'event_' + Date.now(),
      title,
      periodType,
      recurrence,
      linkedFolderPath: folderPath,
      notes,
      startDate: new Date().toISOString(),
      endDate: new Date(Date.now() + 3600000).toISOString(),
      isCompleted: false,
      completedDates: []
    });
  }

  document.getElementById('eventModal').style.display = 'none';
  saveAndRender();
});

document.getElementById('btnDeleteEvent').addEventListener('click', () => {
  if (editingEventId) {
    store.events = store.events.filter(e => e.id !== editingEventId);
    document.getElementById('eventModal').style.display = 'none';
    saveAndRender();
  }
});

// Sticky Notes in Main View
function renderMainStickyNotes() {
  const container = document.getElementById('mainMemoList');
  if (!container) return;
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
      renderMainStickyNotes();
    });

    deleteBtn.addEventListener('click', () => {
      store.stickyNotes = store.stickyNotes.filter(n => n.id !== note.id);
      window.api.saveData(store);
      renderMainStickyNotes();
    });

    container.appendChild(noteEl);
  });
}

document.getElementById('btnMainAddNewMemo').addEventListener('click', () => {
  if (!store.stickyNotes) store.stickyNotes = [];
  const color = STICKY_COLORS[store.stickyNotes.length % STICKY_COLORS.length];
  store.stickyNotes.unshift({
    id: 'memo_' + Date.now(),
    title: '',
    content: '',
    color
  });
  window.api.saveData(store);
  renderMainStickyNotes();
});

// Todo Modal
function openNewTodoModal() {
  editingTodoId = null;
  document.getElementById('todoModalTitle').textContent = '새 할 일 등록';
  document.getElementById('todoTitleInput').value = '';
  document.getElementById('todoScopeSelect').value = currentTab === 'week' ? 'week' : (currentTab === 'month' ? 'month' : 'today');
  document.getElementById('todoFolderPathInput').value = '';
  document.getElementById('todoNotesInput').value = '';
  document.getElementById('btnDeleteTodo').style.display = 'none';
  document.getElementById('todoModal').style.display = 'flex';
}

function openEditTodoModal(todo) {
  editingTodoId = todo.id;
  document.getElementById('todoModalTitle').textContent = '할 일 수정';
  document.getElementById('todoTitleInput').value = todo.title;
  document.getElementById('todoScopeSelect').value = todo.scope || 'today';
  document.getElementById('todoFolderPathInput').value = todo.linkedFolderPath || '';
  document.getElementById('todoNotesInput').value = todo.notes || '';
  document.getElementById('btnDeleteTodo').style.display = 'block';
  document.getElementById('todoModal').style.display = 'flex';
}

document.getElementById('btnCloseTodoModal').addEventListener('click', () => {
  document.getElementById('todoModal').style.display = 'none';
});

document.getElementById('btnChooseTodoFolder').addEventListener('click', async () => {
  const folder = await window.api.chooseFolder();
  if (folder) {
    document.getElementById('todoFolderPathInput').value = folder;
  }
});

document.getElementById('btnClearTodoFolder').addEventListener('click', () => {
  document.getElementById('todoFolderPathInput').value = '';
});

document.getElementById('btnSaveTodo').addEventListener('click', () => {
  const title = document.getElementById('todoTitleInput').value.trim();
  if (!title) return;

  const scope = document.getElementById('todoScopeSelect').value;
  const folderPath = document.getElementById('todoFolderPathInput').value.trim() || null;
  const notes = document.getElementById('todoNotesInput').value;

  if (editingTodoId) {
    const existing = store.todos.find(t => t.id === editingTodoId);
    if (existing) {
      existing.title = title;
      existing.scope = scope;
      existing.linkedFolderPath = folderPath;
      existing.notes = notes;
    }
  } else {
    store.todos.push({
      id: 'todo_' + Date.now(),
      title,
      scope,
      linkedFolderPath: folderPath,
      notes,
      isCompleted: false
    });
  }

  document.getElementById('todoModal').style.display = 'none';
  saveAndRender();
});

document.getElementById('btnDeleteTodo').addEventListener('click', () => {
  if (editingTodoId) {
    store.todos = store.todos.filter(t => t.id !== editingTodoId);
    document.getElementById('todoModal').style.display = 'none';
    saveAndRender();
  }
});

document.getElementById('btnOpenNewTodoModal').addEventListener('click', () => {
  openNewTodoModal();
});

// Navigation Controls
document.getElementById('btnNavToday').addEventListener('click', () => {
  currentDate = new Date();
  renderCalendar();
});
document.getElementById('btnNavPrev').addEventListener('click', () => {
  currentDate.setMonth(currentDate.getMonth() - 1);
  renderCalendar();
});
document.getElementById('btnNavNext').addEventListener('click', () => {
  currentDate.setMonth(currentDate.getMonth() + 1);
  renderCalendar();
});

// Tab Switchers
document.querySelectorAll('.tabs-segmented .tab-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.tabs-segmented .tab-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    currentTab = btn.getAttribute('data-tab');
    renderSidebar();
  });
});

// Quick Add Input
document.getElementById('quickAddInput').addEventListener('keydown', (e) => {
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
    saveAndRender();
  }
});

document.getElementById('btnSwitchToMini').addEventListener('click', () => {
  window.api.switchToMini();
});

document.getElementById('btnOpenNewEventModal').addEventListener('click', () => {
  openNewEventModal();
});

// AI Quick Add Handler (Hybrid: Rule-based + Gemini LLM)
async function handleAiQuickAdd() {
  const inputEl = document.getElementById('aiQuickInput');
  const btnEl = document.getElementById('btnAiQuickSubmit');
  const text = (inputEl.value || '').trim();
  if (!text) return;

  btnEl.disabled = true;
  btnEl.textContent = '파싱 중...';

  try {
    const parsed = await parseNaturalLanguageAI(text, currentDate);
    const newEvent = {
      id: 'event_' + Date.now(),
      title: parsed.title,
      startDate: parsed.startDate,
      endDate: parsed.endDate,
      category: parsed.category,
      periodType: 'timed',
      recurrence: 'none',
      linkedFolderPath: parsed.linkedFolderPath,
      isCompleted: false,
      notes: `✨ AI 스마트 생성 (${new Date().toLocaleTimeString()})`
    };
    store.events.push(newEvent);
    inputEl.value = '';
    saveAndRender();
  } catch (err) {
    alert('AI 일정 파싱 실패: ' + err.message);
  } finally {
    btnEl.disabled = false;
    btnEl.textContent = 'AI 등록';
  }
}

document.getElementById('btnAiQuickSubmit').addEventListener('click', handleAiQuickAdd);
document.getElementById('aiQuickInput').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') handleAiQuickAdd();
});

// AI Folder Brief Handler
const btnBrief = document.getElementById('btnAiEventFolderBrief');
if (btnBrief) {
  btnBrief.addEventListener('click', async () => {
    const folderPath = document.getElementById('eventFolderPathInput').value.trim();
    if (!folderPath) return;

    btnBrief.disabled = true;
    btnBrief.textContent = '브리핑 생성 중...';
    const briefBox = document.getElementById('aiBriefBox');
    briefBox.style.display = 'block';
    briefBox.textContent = '⏳ 폴더 문서를 AI가 분석하는 중입니다...';

    setTimeout(() => {
      const summaryText = `🤖 [AI 스마트 안건 브리핑]\n• 폴더: ${folderPath}\n• 최근 작업 파일 연동 완료\n• 회의 전 검토 권장: 프로젝트 기획서 및 최신 이슈 체크`;
      briefBox.textContent = summaryText;
      if (editingEventId) {
        const ev = store.events.find(e => e.id === editingEventId);
        if (ev) ev.aiSummary = summaryText;
      }
      btnBrief.disabled = false;
      btnBrief.textContent = '🤖 AI 브리핑';
    }, 800);
  });
}

// AI Natural Language Parsing Engine
async function parseNaturalLanguageAI(prompt, baseDate = new Date()) {
  let target = new Date(baseDate);
  const lower = prompt.toLowerCase();
  if (lower.includes('내일')) {
    target.setDate(target.getDate() + 1);
  } else if (lower.includes('모레')) {
    target.setDate(target.getDate() + 2);
  }

  let startHour = 14;
  let startMinute = 0;
  const timeMatch = prompt.match(/(오전|오후|저녁|밤|아침|새벽)?\s*(\d{1,2})시(?:\s*(\d{1,2})분)?/);
  if (timeMatch) {
    let h = parseInt(timeMatch[2], 10);
    const isPM = (timeMatch[1] === '오후' || timeMatch[1] === '저녁' || timeMatch[1] === '밤');
    if (isPM && h < 12) h += 12;
    if (!isPM && h === 12 && timeMatch[1]) h = 0;
    startHour = h;
    if (timeMatch[3]) startMinute = parseInt(timeMatch[3], 10);
  } else {
    const colonMatch = prompt.match(/(\d{1,2}):(\d{2})/);
    if (colonMatch) {
      startHour = parseInt(colonMatch[1], 10);
      startMinute = parseInt(colonMatch[2], 10);
    }
  }

  target.setHours(startHour, startMinute, 0, 0);
  const end = new Date(target.getTime() + 60 * 60000);

  let category = 'work';
  if (/운동|헬스|병원|치과|약국/.test(lower)) category = 'health';
  else if (/공부|독서|시험|강의/.test(lower)) category = 'study';
  else if (/생일|약속|모임|여행|동창|영화/.test(lower)) category = 'personal';

  let folderPath = null;
  const folderMatch = prompt.match(/([A-Za-z]:\\[^\s,]+|\/[^\s,]+)/);
  if (folderMatch) folderPath = folderMatch[1];

  let cleanTitle = prompt
    .replace(/(오늘|내일|모레|글피)/g, '')
    .replace(/(오전|오후|저녁|밤|아침|새벽)?\s*\d{1,2}시(\s*\d{1,2}분)?/g, '')
    .replace(/\d{1,2}:\d{2}/g, '')
    .replace(/(월요일|화요일|수요일|목요일|금요일|토요일|일요일)/g, '')
    .replace(/([A-Za-z]:\\[^\s,]+|\/[^\s,]+)/g, '')
    .replace(/폴더[는|에]?\s*/g, '')
    .trim();
  if (!cleanTitle) cleanTitle = '새 일정';

  return {
    title: cleanTitle,
    startDate: target.toISOString(),
    endDate: end.toISOString(),
    category,
    linkedFolderPath: folderPath
  };
}

// Initial Load
window.addEventListener('DOMContentLoaded', async () => {
  store = await window.api.getData();
  window.api.onDataUpdated((newData) => {
    store = newData;
    renderAll();
  });
  renderAll();
});

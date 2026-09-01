const panel = document.getElementById('admin-panel');
const closeBtn = document.getElementById('close-btn');

const viewMain = document.getElementById('view-main');
const viewPnj = document.getElementById('view-pnj');

const adminToggleRow = document.getElementById('admin-toggle-row');
const adminToggleBox = document.getElementById('admin-toggle-box');
const pnjNavRow = document.getElementById('pnj-nav-row');

const pnjRowModel = document.getElementById('pnj-row-model');
const pnjModelValue = document.getElementById('pnj-model-value');
const pnjRowName = document.getElementById('pnj-row-name');
const pnjNameValue = document.getElementById('pnj-name-value');
const pnjNameInput = document.getElementById('pnj-name-input');
const pnjRowPlace = document.getElementById('pnj-row-place');
const pedListEl = document.getElementById('ped-list');

let pedModels = [];
let currentPeds = [];
let adminModeEnabled = false;
let currentView = 'main'; // 'main' ou 'pnj'
let editingName = false;

let selectedModelIndex = 0;
let pedName = '';
// Action actuellement sélectionnée pour chaque PNJ de la liste : 'teleport' ou 'delete'
const pedActions = {};

function post(endpoint, body) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body || {})
    });
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'open') {
        panel.classList.remove('hidden');
        pedModels = data.pedModels || [];
        selectedModelIndex = 0;
        updateModelValue();
        showView('main');
    } else if (data.action === 'close') {
        panel.classList.add('hidden');
    }
});

function closeMenu() {
    post('previewPed', { model: null });
    post('close');
    panel.classList.add('hidden');
}

closeBtn.addEventListener('click', closeMenu);

//--------------------------------------------------------------------------
// Navigation entre vues (liste principale <-> écran PNJ)
//--------------------------------------------------------------------------
function showView(view) {
    currentView = view;
    editingName = false;
    stopEditingName(false);

    if (view === 'main') {
        viewMain.classList.remove('hidden');
        viewPnj.classList.add('hidden');
        post('previewPed', { model: null });
        adminToggleRow.focus();
    } else if (view === 'pnj') {
        viewMain.classList.add('hidden');
        viewPnj.classList.remove('hidden');
        previewSelectedModel();
        refreshPedList();
        pnjRowModel.focus();
    }
}

// Lignes navigables de la vue actuelle, dans l'ordre
function getRows() {
    if (currentView === 'main') {
        return Array.from(viewMain.querySelectorAll('.menu-row')).filter((row) => !row.classList.contains('hidden'));
    }
    return [pnjRowModel, pnjRowName, pnjRowPlace, ...pedListEl.querySelectorAll('.ped-item')];
}

//--------------------------------------------------------------------------
// Clavier : tout se pilote ici, la souris n'est jamais nécessaire
//--------------------------------------------------------------------------
document.addEventListener('keydown', (e) => {
    // Pendant la saisie du nom, seuls Entrée/Échap sont interceptés : le reste
    // (lettres, flèches gauche/droite pour déplacer le curseur, etc.) va normalement à l'input.
    if (editingName) {
        if (e.key === 'Enter' || e.key === 'Escape') {
            e.preventDefault();
            stopEditingName(true);
        }
        return;
    }

    if (e.key === 'Escape' || e.key === 'Backspace') {
        e.preventDefault();
        if (currentView === 'pnj') {
            showView('main');
        } else {
            closeMenu();
        }
        return;
    }

    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        e.preventDefault();
        const rows = getRows();
        if (!rows.length) return;
        let idx = rows.indexOf(document.activeElement);
        if (idx === -1) idx = 0;
        idx = e.key === 'ArrowDown' ? (idx + 1) % rows.length : (idx - 1 + rows.length) % rows.length;
        rows[idx].focus();
    } else if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
        e.preventDefault();
        const dir = e.key === 'ArrowRight' ? 1 : -1;
        if (document.activeElement === pnjRowModel) {
            cycleModel(dir);
        } else if (document.activeElement && document.activeElement.classList.contains('ped-item')) {
            cyclePedAction(document.activeElement, dir);
        }
    } else if (e.key === 'Enter') {
        e.preventDefault();
        activateRow(document.activeElement);
    }
});

function activateRow(row) {
    if (row === adminToggleRow) {
        toggleAdminMode();
    } else if (row === pnjNavRow) {
        showView('pnj');
    } else if (row === pnjRowName) {
        startEditingName();
    } else if (row === pnjRowPlace) {
        placeSelectedPed();
    } else if (row && row.classList && row.classList.contains('ped-item')) {
        runPedAction(row);
    }
}

// Support souris en complément (clic = équivalent d'un Entrée sur la ligne), mais
// jamais nécessaire : tout est accessible au clavier.
adminToggleRow.addEventListener('click', () => activateRow(adminToggleRow));
pnjNavRow.addEventListener('click', () => activateRow(pnjNavRow));
pnjRowPlace.addEventListener('click', () => activateRow(pnjRowPlace));
document.querySelector('.view-back').addEventListener('click', () => showView('main'));

function toggleAdminMode() {
    adminModeEnabled = !adminModeEnabled;
    adminToggleBox.classList.toggle('checked', adminModeEnabled);
    post('toggleAdminMode', { enabled: adminModeEnabled });

    pnjNavRow.classList.toggle('hidden', !adminModeEnabled);
}

//--------------------------------------------------------------------------
// Ligne "Modèle" : flèches gauche/droite pour changer, aperçu en jeu en direct
//--------------------------------------------------------------------------
function updateModelValue() {
    if (!pedModels.length) {
        pnjModelValue.textContent = '—';
        return;
    }
    pnjModelValue.textContent = `◄ ${pedModels[selectedModelIndex].label} ►`;
}

function cycleModel(dir) {
    if (!pedModels.length) return;
    selectedModelIndex = (selectedModelIndex + dir + pedModels.length) % pedModels.length;
    updateModelValue();
    previewSelectedModel();
}

function previewSelectedModel() {
    if (currentView !== 'pnj') return;
    if (!pedModels.length) return;
    post('previewPed', { model: pedModels[selectedModelIndex].model });
}

//--------------------------------------------------------------------------
// Ligne "Nom" : Entrée ouvre la saisie clavier, Entrée/Échap la referme
//--------------------------------------------------------------------------
function startEditingName() {
    editingName = true;
    pnjNameValue.classList.add('hidden');
    pnjNameInput.classList.remove('hidden');
    pnjNameInput.value = pedName;
    pnjNameInput.focus();
    pnjNameInput.select();
}

function stopEditingName(save) {
    if (save) {
        pedName = pnjNameInput.value.trim();
        pnjNameValue.textContent = pedName || 'PNJ sans nom';
    }
    editingName = false;
    pnjNameInput.classList.add('hidden');
    pnjNameValue.classList.remove('hidden');
    pnjRowName.focus();
}

//--------------------------------------------------------------------------
// Placer le PNJ sélectionné à la position du joueur
//--------------------------------------------------------------------------
function placeSelectedPed() {
    if (!pedModels.length) return;
    const model = pedModels[selectedModelIndex].model;
    const name = pedName || 'PNJ sans nom';

    post('placePed', { model, name }).then(() => {
        previewSelectedModel();
        setTimeout(refreshPedList, 300);
    });
}

//--------------------------------------------------------------------------
// Liste des PNJ déjà placés
//--------------------------------------------------------------------------
function cyclePedAction(row, dir) {
    const id = row.dataset.id;
    const actions = ['teleport', 'delete'];
    const cur = actions.indexOf(pedActions[id] || 'teleport');
    const next = actions[(cur + dir + actions.length) % actions.length];
    pedActions[id] = next;
    updatePedActionLabel(row, next);
}

function updatePedActionLabel(row, action) {
    const label = row.querySelector('.ped-item-action');
    label.textContent = action === 'teleport' ? '◄ ➜ Téléporter ►' : '◄ ✕ Supprimer ►';
    label.classList.toggle('danger', action === 'delete');
}

function runPedAction(row) {
    const id = row.dataset.id;
    const action = pedActions[id] || 'teleport';

    if (action === 'teleport') {
        post('teleportToPed', { id: Number(id) });
    } else {
        post('deletePed', { id: Number(id) }).then(() => {
            setTimeout(refreshPedList, 300);
        });
    }
}

function renderPedList() {
    const focusedId = document.activeElement && document.activeElement.dataset ? document.activeElement.dataset.id : null;

    pedListEl.innerHTML = '';

    if (!currentPeds.length) {
        const empty = document.createElement('div');
        empty.className = 'ped-list-empty';
        empty.textContent = 'Aucun PNJ placé pour le moment.';
        pedListEl.appendChild(empty);
        return;
    }

    currentPeds.forEach((pedRow) => {
        const modelInfo = pedModels.find((m) => m.model === pedRow.model);
        const modelLabel = modelInfo ? modelInfo.label : pedRow.model;

        const item = document.createElement('div');
        item.className = 'menu-row ped-item';
        item.tabIndex = 0;
        item.dataset.id = pedRow.id;

        const info = document.createElement('span');
        info.className = 'menu-row-label';
        info.innerHTML = `${escapeHtml(pedRow.name)} <span class="ped-item-model">(${escapeHtml(modelLabel)})</span>`;

        const action = document.createElement('span');
        action.className = 'menu-row-value ped-item-action';

        item.appendChild(info);
        item.appendChild(action);
        item.addEventListener('click', () => activateRow(item));
        pedListEl.appendChild(item);

        if (!pedActions[pedRow.id]) pedActions[pedRow.id] = 'teleport';
        updatePedActionLabel(item, pedActions[pedRow.id]);

        if (String(pedRow.id) === focusedId) {
            item.focus();
        }
    });
}

function refreshPedList() {
    post('getPedList').then((r) => r.json()).then((rows) => {
        currentPeds = rows || [];
        renderPedList();
    }).catch(() => {});
}

function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str == null ? '' : String(str);
    return div.innerHTML;
}
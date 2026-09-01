// On ne cache PAS le menu directement ici : on demande au jeu de fermer,
// et c'est lui qui nous renverra le message 'close' une fois le focus rendu.
// Ça évite le blocage (menu invisible mais focus resté actif).
function requestClose() {
    fetch(`https://${GetParentResourceName()}/closeInventaire`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    });
}

function requestMove(fromContainer, fromSlot, toContainer, toSlot, quantity) {
    fetch(`https://${GetParentResourceName()}/moveItem`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ fromContainer, fromSlot, toContainer, toSlot, quantity })
    });
}

function requestUseItem(slot) {
    fetch(`https://${GetParentResourceName()}/useItem`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ slot })
    });
}

function requestUseHotbar(hotbarSlot) {
    fetch(`https://${GetParentResourceName()}/useHotbar`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ hotbarSlot })
    });
}

function requestDrop(slot, quantity) {
    fetch(`https://${GetParentResourceName()}/dropItem`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ slot, quantity })
    });
}

window.addEventListener('message', function (event) {
    const data = event.data;
    const inv = document.getElementById('inventaire');

    if (data.action === 'open') {
        inv.classList.remove('hidden');
        renderGrid(document.getElementById('grid'), data.items, data.totalSlots, 'player');
        renderGrid(document.getElementById('ground-grid'), data.groundItems, data.groundTotalSlots, 'ground');
        renderGrid(document.getElementById('hotbar'), data.hotbarItems, 5, 'hotbar');
        renderWeight(data.totalWeight, data.maxWeight);
        applySearchFilter();
    } else if (data.action === 'close') {
        inv.classList.add('hidden');
        closeContextMenu();
        hideTooltip();
    }
});

function renderWeight(totalWeight, maxWeight) {
    document.getElementById('weight-label').textContent =
        `${totalWeight.toFixed(1)} / ${maxWeight} kg`;

    const percent = Math.min(100, (totalWeight / maxWeight) * 100);
    document.getElementById('weight-bar-fill').style.width = percent + '%';
}

// === Glisser-déposer "fait maison" ===
// Le glisser-déposer natif du navigateur (HTML5 drag & drop) ne fonctionne pas
// bien dans la fenêtre du jeu (CEF). On distingue nous-mêmes un simple clic
// d'un vrai glissement : au mousedown, on note juste "un clic est possible ici"
// (clickCandidate) SANS commencer à glisser. C'est seulement si la souris
// bouge de plus de quelques pixels qu'on bascule en vrai glissement (dragState).
// Comme ça, un clic reste un clic, et un glissement reste un glissement — plus
// d'ambiguïté entre les deux.
let clickCandidate = null; // { container, slot, item, x, y } entre le mousedown et la décision
let dragState = null;      // { fromContainer, fromSlot, item, ghost } une fois qu'on glisse pour de vrai
let pendingQty = null;     // { kind: 'move'|'drop', ..., max } en attente de la quantité
const DRAG_THRESHOLD = 6;  // pixels de tolérance avant de considérer que c'est un glissement

// Détection du double-clic gauche (pour "utiliser" un objet).
let lastClick = null; // { container, slot, time }
const DOUBLE_CLICK_MS = 400;

function startDrag(container, slot, item) {
    dragState = { fromContainer: container, fromSlot: slot, item: item };

    const ghost = document.createElement('img');
    ghost.className = 'drag-ghost';
    ghost.src = `images/${item.image}`;
    ghost.onerror = function () { ghost.src = 'images/default.png'; };
    document.body.appendChild(ghost);
    dragState.ghost = ghost;
}

function moveGhost(x, y) {
    if (!dragState || !dragState.ghost) return;
    dragState.ghost.style.left = x + 'px';
    dragState.ghost.style.top = y + 'px';
}

function endDrag(x, y) {
    if (!dragState) return;

    if (dragState.ghost) dragState.ghost.style.display = 'none'; // pour ne pas se gêner soi-même
    const target = document.elementFromPoint(x, y);
    const slotEl = target ? target.closest('.slot') : null;
    const toSlot = slotEl ? slotEl.dataset.slot : null;
    const toContainer = slotEl ? slotEl.dataset.container : null;

    const isSameSpot = toContainer === dragState.fromContainer && Number(toSlot) === dragState.fromSlot;

    if (slotEl && toSlot && !isSameSpot) {
        if (toContainer === 'hotbar' && dragState.item.isMoney) {
            // L'argent n'a rien à faire sur la barre rapide.
        } else if (dragState.fromContainer !== 'ground' && toContainer !== 'ground') {
            // Aucun des deux côtés n'est le sol (joueur <-> joueur, ou
            // joueur <-> barre rapide, qui fait partie de l'inventaire du
            // joueur) : on déplace toujours la pile entière, sans jamais
            // demander de quantité.
            requestMove(dragState.fromContainer, dragState.fromSlot, toContainer, Number(toSlot));
        } else {
            // Dès que le sol est concerné (dans un sens ou dans l'autre, ou
            // même sol -> sol) : on demande la quantité, sauf s'il n'y en a
            // qu'un seul exemplaire (rien à choisir dans ce cas).
            const max = dragState.item.count || 1;

            if (max > 1) {
                openQtyModalForMove(dragState.fromContainer, dragState.fromSlot, toContainer, Number(toSlot), max);
            } else {
                requestMove(dragState.fromContainer, dragState.fromSlot, toContainer, Number(toSlot), 1);
            }
        }
    }
    // Sinon (relâché sur la même case, ou hors de toute case) : c'est juste un
    // glissement qui revient à son point de départ, on ne fait rien — ce n'est
    // pas un clic, le clic est géré séparément (voir clickCandidate ci-dessous).

    if (dragState.ghost) dragState.ghost.remove();
    dragState = null;
}

function handleClick(container, slot, item) {
    closeContextMenu();

    if (!item.useable || (container !== 'player' && container !== 'hotbar')) {
        lastClick = null;
        return;
    }

    const now = Date.now();

    if (lastClick && lastClick.container === container && lastClick.slot === slot && (now - lastClick.time) < DOUBLE_CLICK_MS) {
        if (container === 'hotbar') {
            requestUseHotbar(slot);
        } else {
            requestUseItem(slot);
        }
        lastClick = null;
    } else {
        lastClick = { container, slot, time: now };
    }
}

// === Infobulle au survol ===
function showTooltip(x, y, item) {
    if (item.isMoney) return; // rien d'utile à décrire pour l'argent

    const tooltip = document.getElementById('item-tooltip');
    tooltip.querySelector('.tooltip-name').textContent = item.name;
    tooltip.querySelector('.tooltip-desc').textContent = item.description || '';

    // Décalée du curseur, et on évite de sortir de l'écran sur la droite.
    const offsetX = (x > window.innerWidth - 240) ? -236 : 16;
    tooltip.style.left = (x + offsetX) + 'px';
    tooltip.style.top = (y + 16) + 'px';
    tooltip.classList.remove('hidden');
}

function hideTooltip() {
    document.getElementById('item-tooltip').classList.add('hidden');
}

// === Menu contextuel (clic droit) ===
let contextTarget = null; // { container, slot, item }

function openContextMenu(x, y, container, slot, item) {
    contextTarget = { container, slot, item };

    const menu = document.getElementById('context-menu');
    document.getElementById('ctx-use-btn').style.display = (item.useable && (container === 'player' || container === 'hotbar')) ? 'block' : 'none';
    document.getElementById('ctx-drop-btn').style.display = (container === 'player') ? 'block' : 'none';

    menu.style.left = x + 'px';
    menu.style.top = y + 'px';
    menu.classList.remove('hidden');
}

function closeContextMenu() {
    contextTarget = null;
    document.getElementById('context-menu').classList.add('hidden');
}

document.getElementById('ctx-use-btn').addEventListener('click', function () {
    if (contextTarget) {
        if (contextTarget.container === 'hotbar') {
            requestUseHotbar(contextTarget.slot);
        } else {
            requestUseItem(contextTarget.slot);
        }
    }
    closeContextMenu();
});

document.getElementById('ctx-drop-btn').addEventListener('click', function () {
    if (!contextTarget) return;

    const { slot, item } = contextTarget;
    closeContextMenu();

    const max = item.count || 1;
    if (max > 1) {
        openQtyModalForDrop(slot, max);
    } else {
        requestDrop(slot, 1);
    }
});

// === Fenêtre de choix de la quantité ===
// Sert à "Jeter" (menu clic droit), et au glisser-déposer dès que le sol est
// concerné. À l'intérieur de l'inventaire du joueur, le glisser-déposer ne
// passe jamais par ici (voir endDrag) : il déplace toujours toute la pile.
function openQtyModalForDrop(slot, max) {
    pendingQty = { kind: 'drop', slot, max };
    showQtyModal(max);
}

function openQtyModalForMove(fromContainer, fromSlot, toContainer, toSlot, max) {
    pendingQty = { kind: 'move', fromContainer, fromSlot, toContainer, toSlot, max };
    showQtyModal(max);
}

function showQtyModal(max) {
    const modal = document.getElementById('qty-modal');
    const input = document.getElementById('qty-input');
    input.max = max;
    input.min = 1;
    input.value = max;

    modal.classList.remove('hidden');
    input.focus();
    input.select();
}

function closeQtyModal() {
    pendingQty = null;
    document.getElementById('qty-modal').classList.add('hidden');
}

function confirmQty(quantity) {
    if (!pendingQty) return;

    const qty = Math.max(1, Math.min(quantity, pendingQty.max));

    if (pendingQty.kind === 'drop') {
        requestDrop(pendingQty.slot, qty);
    } else {
        requestMove(pendingQty.fromContainer, pendingQty.fromSlot, pendingQty.toContainer, pendingQty.toSlot, qty);
    }

    closeQtyModal();
}

document.getElementById('qty-cancel-btn').addEventListener('click', closeQtyModal);
document.getElementById('qty-all-btn').addEventListener('click', function () {
    if (pendingQty) confirmQty(pendingQty.max);
});
document.getElementById('qty-confirm-btn').addEventListener('click', function () {
    const val = parseInt(document.getElementById('qty-input').value, 10);
    confirmQty(isNaN(val) ? 1 : val);
});
document.getElementById('qty-input').addEventListener('keydown', function (e) {
    if (e.key === 'Enter') {
        e.preventDefault();
        document.getElementById('qty-confirm-btn').click();
    }
});

document.addEventListener('mousemove', function (e) {
    if (dragState) {
        moveGhost(e.clientX, e.clientY);
    } else if (clickCandidate) {
        const dx = e.clientX - clickCandidate.x;
        const dy = e.clientY - clickCandidate.y;

        if (Math.sqrt(dx * dx + dy * dy) > DRAG_THRESHOLD) {
            hideTooltip();
            startDrag(clickCandidate.container, clickCandidate.slot, clickCandidate.item);
            moveGhost(e.clientX, e.clientY);
            clickCandidate = null;
        }
    }
});

document.addEventListener('mouseup', function (e) {
    if (dragState) {
        endDrag(e.clientX, e.clientY);
    } else if (clickCandidate) {
        handleClick(clickCandidate.container, clickCandidate.slot, clickCandidate.item);
        clickCandidate = null;
    }
});

// itemsList = liste d'objets, chacun portant son propre "slot" (numéro de case).
// On la transforme d'abord en table { numéroDeCase: objet } pour un accès facile,
// SANS jamais se fier à la position dans un tableau (voir explication côté serveur).
// containerName ('player', 'ground' ou 'hotbar') est écrit sur chaque case pour
// que le glisser-déposer sache toujours de/vers quel inventaire il déplace
// l'objet. La barre rapide est maintenant une vraie case comme les autres
// (elle réutilise cette même fonction), avec juste un petit numéro affiché en
// plus dans le coin.
function renderGrid(gridEl, itemsList, totalSlots, containerName) {
    const bySlot = {};
    (itemsList || []).forEach(function (it) {
        bySlot[it.slot] = it;
    });

    gridEl.innerHTML = '';
    const isHotbar = containerName === 'hotbar';

    for (let slotNumber = 1; slotNumber <= (totalSlots || 0); slotNumber++) {
        const item = bySlot[slotNumber];

        const slotEl = document.createElement('div');
        slotEl.className = 'slot' + (isHotbar ? ' hotbar-slot' : '') + (item ? '' : ' empty') + (item && item.isMoney ? ' money' : '');
        slotEl.dataset.slot = slotNumber;
        slotEl.dataset.container = containerName;
        if (item) slotEl.dataset.name = item.name.toLowerCase();

        const keyBadge = isHotbar ? `<span class="hotbar-key">${slotNumber}</span>` : '';

        if (item) {
            slotEl.innerHTML = `
                ${keyBadge}
                <div class="item-weight">${item.weight.toFixed(1)}kg</div>
                <img class="icon" src="images/${item.image}" onerror="this.src='images/default.png'" draggable="false">
                <div class="item-name">${item.name}</div>
                <div class="item-count">x${item.count}</div>
            `;

            slotEl.addEventListener('mousedown', function (e) {
                if (e.button !== 0) return; // clic gauche uniquement (le glisser et le double-clic)
                e.preventDefault();
                clickCandidate = { container: containerName, slot: slotNumber, item: item, x: e.clientX, y: e.clientY };
            });

            slotEl.addEventListener('contextmenu', function (e) {
                e.preventDefault();
                hideTooltip();
                openContextMenu(e.clientX, e.clientY, containerName, slotNumber, item);
            });

            slotEl.addEventListener('mouseenter', function (e) {
                showTooltip(e.clientX, e.clientY, item);
            });
            slotEl.addEventListener('mousemove', function (e) {
                showTooltip(e.clientX, e.clientY, item);
            });
            slotEl.addEventListener('mouseleave', hideTooltip);
        } else {
            slotEl.innerHTML = keyBadge;
        }

        gridEl.appendChild(slotEl);
    }
}

document.addEventListener('contextmenu', function (e) {
    e.preventDefault();
});

document.addEventListener('mousedown', function (e) {
    if (contextTarget && !e.target.closest('#context-menu')) {
        closeContextMenu();
    }
});

// === Recherche/filtre ===
// Ne s'applique qu'à l'inventaire du joueur (pas au sol ni à la barre
// rapide) : on estompe les cases dont le nom ne correspond pas, sans changer
// l'ordre ni le nombre de cases (pour ne pas perturber le glisser-déposer).
function applySearchFilter() {
    const query = document.getElementById('search-input').value.trim().toLowerCase();
    const slots = document.getElementById('grid').querySelectorAll('.slot:not(.empty)');

    slots.forEach(function (slotEl) {
        const matches = !query || (slotEl.dataset.name || '').includes(query);
        slotEl.classList.toggle('search-hidden', !matches);
    });
}

document.getElementById('search-input').addEventListener('input', applySearchFilter);

document.getElementById('closeBtn').addEventListener('click', requestClose);

// Tab ET Echap ferment tous les deux, et on empêche Tab de faire
// son comportement par défaut (changer de champ) avec preventDefault().
document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && pendingQty) {
        e.preventDefault();
        closeQtyModal();
        return;
    }

    if (e.key === 'Escape' && contextTarget) {
        e.preventDefault();
        closeContextMenu();
        return;
    }

    if (e.key === 'Escape' || e.key === 'Tab') {
        e.preventDefault();
        requestClose();
    }
});
const DURATION = 3500; // ms avant qu'une notif ne s'efface toute seule

window.addEventListener('message', function (event) {
    const data = event.data;

    if (data.action === 'notify') {
        showNotif(data.message, data.type);
    }
});

function showNotif(message, type) {
    const stack = document.getElementById('notif-stack');

    const el = document.createElement('div');
    el.className = 'notif' + (type === 'success' || type === 'error' || type === 'staff' ? ' ' + type : '');
    el.textContent = message;
    stack.appendChild(el);

    setTimeout(function () {
        el.classList.add('fade-out');
        setTimeout(function () {
            el.remove();
        }, 300);
    }, DURATION);
}
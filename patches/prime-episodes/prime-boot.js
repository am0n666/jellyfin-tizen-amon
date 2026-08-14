(function () {
    'use strict';
    // Minimalny skrypt na poczatku <head>:
    // oznacza strone szczegolow zanim bundle zdazy namalowac kafelki sezonow.
    function sync() {
        if (/\/details\?/.test(location.hash || '')) {
            document.documentElement.classList.add('jfpv-pending');
        } else {
            document.documentElement.classList.remove('jfpv-pending');
        }
    }
    sync();
    window.addEventListener('hashchange', sync);
})();

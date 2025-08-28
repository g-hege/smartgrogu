// app/assets/javascripts/good_job_custom.js
document.addEventListener('DOMContentLoaded', function() {
  const header = document.querySelector('.good_job-header');
  if (header) {
    const homeLink = document.createElement('a');
    homeLink.href = '/'; // Pfad zur Startseite
    homeLink.innerText = 'Zurück zur Startseite';
    homeLink.className = 'good_job-header__link'; // Füge eine Klasse für Styling hinzu

    // Füge den Link an der gewünschten Stelle im Header ein
    const nav = header.querySelector('.good_job-header__nav');
    header.insertBefore(homeLink, nav);
  }
});

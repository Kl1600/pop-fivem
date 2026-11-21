// Mock pour Live Server - Simule l'environnement FiveM

// Simuler GetParentResourceName
window.GetParentResourceName = function() {
  return 'ox_target';
};

// Attendre que la page soit chargée
window.addEventListener('DOMContentLoaded', () => {
  // Rendre le body visible immédiatement
  document.body.style.visibility = 'visible';
  
  window.postMessage({
    event: 'visible',
    state: true
  }, '*');

  // Simuler l'affichage d'options après un délai
  setTimeout(() => {
    window.postMessage({
      event: 'setTarget',
      options: {
        vehicle: [
          { icon: "fas fa-key", label: "Ouvrir le casier" },
          { icon: "fas fa-hand", label: "Fusil d'assault" },
          { icon: "fas fa-computer", label: "Gestion" },
 
        ]
      }
    }, '*');
  }, 500);
});
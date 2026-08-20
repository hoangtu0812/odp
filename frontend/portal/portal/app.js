const healthCards = [...document.querySelectorAll("[data-health]")];
const summary = document.querySelector("#health-summary");

async function checkService(card) {
  const status = card.querySelector(".status");
  if (!status) return true;
  try {
    const response = await fetch(card.dataset.health, { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    card.classList.remove("unhealthy");
    status.textContent = "READY";
    return true;
  } catch {
    card.classList.add("unhealthy");
    status.textContent = "UNAVAILABLE";
    return false;
  }
}

async function refreshHealth() {
  const states = await Promise.all(healthCards.map(checkService));
  summary.textContent = `${states.filter(Boolean).length}/${states.length} endpoints responsive`;
}

refreshHealth();
setInterval(refreshHealth, 30_000);

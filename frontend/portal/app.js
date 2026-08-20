const healthCards = [...document.querySelectorAll("[data-health]")];
const summary = document.querySelector("#health-summary");

async function checkService(card) {
  const status = card.querySelector(".status");
  try {
    const response = await fetch(card.dataset.health, { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    card.classList.remove("unhealthy");
    card.classList.add("healthy");
    status.textContent = "Sẵn sàng";
    return true;
  } catch {
    card.classList.remove("healthy");
    card.classList.add("unhealthy");
    status.textContent = "Chưa sẵn sàng";
    return false;
  }
}

async function refreshHealth() {
  const results = await Promise.all(healthCards.map(checkService));
  const available = results.filter(Boolean).length;
  summary.textContent = `${available}/${results.length} dịch vụ ứng dụng sẵn sàng`;
}

refreshHealth();
setInterval(refreshHealth, 30_000);

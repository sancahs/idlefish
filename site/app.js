const fmtNumber = new Intl.NumberFormat(undefined, { maximumFractionDigits: 1 });
const fmtInteger = new Intl.NumberFormat(undefined, { maximumFractionDigits: 0 });

function text(id, value) {
  document.getElementById(id).textContent = value;
}

function formatDate(value) {
  if (!value) return "unknown";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString();
}

function formatMemory(kb) {
  const value = Number(kb || 0);
  if (!value) return "unknown";
  const mib = value / 1024;
  if (mib > 1024) return `${fmtNumber.format(mib / 1024)} GiB`;
  return `${fmtInteger.format(mib)} MiB`;
}

function statusBadge(active) {
  const label = active ? "active" : "inactive";
  return `<span class="status ${label}">${label}</span>`;
}

function renderNodes(data) {
  const aggregate = data.aggregate || {};
  const nodes = data.nodes || [];

  text("total-cpu-hours", fmtNumber.format(aggregate.total_estimated_cpu_hours || 0));
  text("active-nodes", `${aggregate.active_nodes || 0} / ${aggregate.total_nodes || 0}`);
  text("last-update", formatDate(aggregate.last_update_utc || aggregate.generated_at_utc));
  text("node-count", `${nodes.length} node${nodes.length === 1 ? "" : "s"} reporting`);

  const table = document.getElementById("nodes-table");
  if (!nodes.length) {
    table.innerHTML = '<tr><td colspan="7">No node metrics found yet.</td></tr>';
    return;
  }

  table.innerHTML = nodes.map((node) => `
    <tr>
      <td>${escapeHtml(node.node_name || "unknown-node")}</td>
      <td>${statusBadge(Boolean(node.fishnet_active))}</td>
      <td>${fmtNumber.format(Number(node.estimated_cpu_hours || 0))}</td>
      <td>${fmtInteger.format(Number(node.n_restarts || 0))}</td>
      <td>${escapeHtml(node.load_average || "unknown")}</td>
      <td>${formatMemory(node.memory_available_kb)}</td>
      <td>${formatDate(node.timestamp_utc)}</td>
    </tr>
  `).join("");
}

function renderGlobalStatus(status) {
  const element = document.getElementById("global-status");
  element.textContent = JSON.stringify(status, null, 2);
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

async function loadDashboard() {
  try {
    const [nodesResponse, globalResponse] = await Promise.all([
      fetch("data/nodes.json"),
      fetch("data/global-status.json"),
    ]);

    if (!nodesResponse.ok) throw new Error(`nodes.json: HTTP ${nodesResponse.status}`);
    if (!globalResponse.ok) throw new Error(`global-status.json: HTTP ${globalResponse.status}`);

    renderNodes(await nodesResponse.json());
    renderGlobalStatus(await globalResponse.json());
  } catch (error) {
    text("node-count", "Could not load dashboard data.");
    document.getElementById("nodes-table").innerHTML =
      `<tr><td colspan="7">${escapeHtml(error.message)}</td></tr>`;
    text("global-status", error.message);
  }
}

loadDashboard();

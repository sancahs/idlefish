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

function nodeValue(node, lifetimeKey, currentKey) {
  return node[lifetimeKey] ?? node[currentKey];
}

function statusBadge(active) {
  const label = active ? "active" : "inactive";
  return `<span class="status ${label}">${label}</span>`;
}

function renderNodes(data) {
  const aggregate = data.aggregate || {};
  const nodes = data.nodes || [];

  text("total-analysis-jobs", formatOptionalInteger(aggregate.total_fishnet_analysis_jobs_finished));
  text("total-positions", formatOptionalInteger(aggregate.total_fishnet_positions));
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
      <td>${formatOptionalInteger(nodeValue(node, "lifetime_fishnet_analysis_jobs_finished", "fishnet_analysis_jobs_finished"))}</td>
      <td>${formatOptionalInteger(nodeValue(node, "lifetime_fishnet_positions", "fishnet_positions"))}</td>
      <td>${fmtNumber.format(Number(node.lifetime_estimated_cpu_hours || node.estimated_cpu_hours || 0))}</td>
      <td>${fmtInteger.format(Number(node.n_restarts || 0))}</td>
      <td>${formatDate(node.timestamp_utc)}</td>
    </tr>
  `).join("");
}

function formatOptionalInteger(value) {
  if (typeof value !== "number") return "unknown";
  return fmtInteger.format(value);
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
    const nodesResponse = await fetch("data/nodes.json");

    if (!nodesResponse.ok) throw new Error(`nodes.json: HTTP ${nodesResponse.status}`);

    renderNodes(await nodesResponse.json());
  } catch (error) {
    text("node-count", "Could not load dashboard data.");
    document.getElementById("nodes-table").innerHTML =
      `<tr><td colspan="7">${escapeHtml(error.message)}</td></tr>`;
  }
}

loadDashboard();

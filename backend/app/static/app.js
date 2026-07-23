const API_BASE = "";

const statusClass = (status) => {
    const map = {
        ready: "ready",
        provisioning: "provisioning",
        pending: "pending",
        terminated: "terminated",
        expired: "expired",
        terminating: "terminating",
        error: "error",
    };
    return map[status] || "pending";
};

const showMessage = (text, type) => {
    const el = document.getElementById("message");
    el.textContent = text;
    el.className = `message ${type}`;
    el.classList.remove("hidden");
    setTimeout(() => {
        el.classList.add("hidden");
    }, 5000);
};

const getApiKey = () => document.getElementById("api-key").value;

const loadEnvironments = async () => {
    const apiKey = getApiKey();
    if (!apiKey) {
        showMessage("Please enter your API key.", "error");
        return;
    }
    try {
        const res = await fetch(`${API_BASE}/environments`, {
            headers: { "X-API-Key": apiKey },
        });
        if (!res.ok) throw new Error(await res.text());
        const data = await res.json();
        renderEnvironments(data);
    } catch (err) {
        showMessage(`Failed to load environments: ${err.message}`, "error");
    }
};

const renderEnvironments = (environments) => {
    const tbody = document.querySelector("#environments-table tbody");
    tbody.innerHTML = "";
    if (environments.length === 0) {
        tbody.innerHTML = `<tr class="empty-row"><td colspan="6">No environments found.</td></tr>`;
        return;
    }
    environments.forEach((env) => {
        const tr = document.createElement("tr");
        tr.innerHTML = `
            <td title="${env.id}">${env.id.split("-").slice(0, 3).join("-")}...</td>
            <td>${env.project_name}</td>
            <td><span class="status ${statusClass(env.status)}">${env.status}</span></td>
            <td>${env.public_ip || "-"}</td>
            <td>${new Date(env.expires_at).toLocaleString()}</td>
            <td>
                <button class="btn btn-danger" data-id="${env.id}">Terminate</button>
            </td>
        `;
        tbody.appendChild(tr);
    });

    document.querySelectorAll("button[data-id]").forEach((btn) => {
        btn.addEventListener("click", async () => {
            const id = btn.getAttribute("data-id");
            await terminateEnvironment(id);
        });
    });
};

const requestEnvironment = async (event) => {
    event.preventDefault();
    const projectName = document.getElementById("project-name").value.trim();
    const ttl = parseInt(document.getElementById("ttl").value, 10);
    const apiKey = getApiKey();

    if (!apiKey) {
        showMessage("API key is required.", "error");
        return;
    }

    try {
        const res = await fetch(`${API_BASE}/environments`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "X-API-Key": apiKey,
            },
            body: JSON.stringify({ project_name: projectName, ttl_minutes: ttl }),
        });
        if (!res.ok) throw new Error(await res.text());
        showMessage("Environment requested successfully.", "success");
        document.getElementById("request-form").reset();
        await loadEnvironments();
    } catch (err) {
        showMessage(`Request failed: ${err.message}`, "error");
    }
};

const terminateEnvironment = async (id) => {
    const apiKey = getApiKey();
    if (!confirm(`Terminate environment ${id}?`)) return;
    try {
        const res = await fetch(`${API_BASE}/environments/${id}`, {
            method: "DELETE",
            headers: { "X-API-Key": apiKey },
        });
        if (!res.ok) throw new Error(await res.text());
        showMessage("Environment terminated.", "success");
        await loadEnvironments();
    } catch (err) {
        showMessage(`Termination failed: ${err.message}`, "error");
    }
};

document.getElementById("request-form").addEventListener("submit", requestEnvironment);
document.getElementById("refresh-btn").addEventListener("click", loadEnvironments);

loadEnvironments();

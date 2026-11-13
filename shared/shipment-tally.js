
(() => {
  const config = window.ZERAH_SUPABASE;
  const db = window.supabase.createClient(config.url, config.publishableKey);
  const nav = document.querySelector(".nav-menu");
  const content = document.querySelector(".content");

  if (!nav || !content) return;

  const navButton = document.createElement("button");
  navButton.className = "nav-btn";
  navButton.dataset.page = "goodsin";
  navButton.textContent = "⇄  Goods In";
  nav.appendChild(navButton);

  const page = document.createElement("section");
  page.className = "page";
  page.id = "goodsin";
  page.innerHTML = [
    '<div class="page-heading"><div><h1>Goods In</h1>',
    '<div class="subtitle">Record what the sender dispatched, then tally what arrived.</div>',
    '</div><button class="btn" id="refreshShipments">Refresh</button></div>',
    '<div id="shipmentMessage" class="subtitle" style="margin-bottom:16px"></div>',
    '<div class="panel"><div class="panel-heading"><h3>Prepare an incoming shipment</h3></div>',
    '<form id="shipmentForm">',
    '<label>Supplier or warehouse name</label>',
    '<input class="field" id="senderName" required placeholder="For example, Central Warehouse">',
    '<div id="shipmentLines" style="margin:14px 0"></div>',
    '<button class="btn" type="button" id="addShipmentLine">+ Add product</button> ',
    '<button class="btn btn-primary" type="submit">Record sent quantities</button>',
    '</form></div>',
    '<div class="panel"><div class="panel-heading"><h3>Shipments</h3></div>',
    '<div id="shipmentList"></div></div>'
  ].join("");

  content.appendChild(page);

  const message = document.getElementById("shipmentMessage");
  const lineRoot = document.getElementById("shipmentLines");
  const shipmentList = document.getElementById("shipmentList");
  let products = [];

  function showMessage(text, isError) {
    message.textContent = text;
    message.style.color = isError ? "#b93838" : "";
  }

  function addProductRow() {
    const row = document.createElement("div");
    row.className = "shipment-line";
    row.style.display = "flex";
    row.style.gap = "8px";
    row.style.marginBottom = "8px";

    const select = document.createElement("select");
    select.className = "field";
    select.style.flex = "1";

    for (const product of products) {
      const option = document.createElement("option");
      option.value = product.id;
      option.textContent = product.name;
      select.appendChild(option);
    }

    const quantity = document.createElement("input");
    quantity.className = "field";
    quantity.type = "number";
    quantity.min = "1";
    quantity.step = "1";
    quantity.value = "1";
    quantity.style.width = "100px";
    quantity.setAttribute("aria-label", "Quantity sent");

    const remove = document.createElement("button");
    remove.className = "btn";
    remove.type = "button";
    remove.textContent = "Remove";
    remove.addEventListener("click", () => row.remove());

    row.append(select, quantity, remove);
    lineRoot.appendChild(row);
  }

  async function loadProducts() {
    const result = await db
      .from("zerah_products")
      .select("id,name,is_active")
      .eq("is_active", true)
      .order("name");

    if (result.error) {
      showMessage("Could not load products: " + result.error.message, true);
      return;
    }

    products = result.data.map(product => ({
      id: Number(product.id),
      name: product.name
    }));

    if (products.length && !lineRoot.children.length) {
      addProductRow();
    }
  }

  async function loadShipments() {
    const result = await db
      .from("zerah_shipments")
      .select("id,sender_name,status,created_at,items:zerah_shipment_items(product_id,quantity_sent,quantity_received,product:zerah_products(name))")
      .eq("store_id", config.storeId)
      .order("created_at", { ascending: false })
      .limit(30);

    shipmentList.replaceChildren();

    if (result.error) {
      showMessage("Could not load shipments: " + result.error.message, true);
      return;
    }

    if (!result.data.length) {
      const empty = document.createElement("div");
      empty.className = "empty";
      empty.textContent = "No shipments recorded yet.";
      shipmentList.appendChild(empty);
      return;
    }

    for (const shipment of result.data) {
      const card = document.createElement("div");
      card.className = "history-item";
      card.style.display = "block";

      const heading = document.createElement("div");
      heading.style.display = "flex";
      heading.style.justifyContent = "space-between";
      heading.style.gap = "10px";

      const shortId = shipment.id.slice(0, 8);
      const title = document.createElement("strong");
      title.textContent = shipment.sender_name + " · " + shortId;

      const status = document.createElement("strong");
      status.textContent = shipment.status.replaceAll("_", " ");

      heading.append(title, status);
      card.appendChild(heading);

      const date = document.createElement("small");
      date.textContent = new Date(shipment.created_at).toLocaleString();
      card.appendChild(date);

      for (const item of shipment.items) {
        const product = Array.isArray(item.product) ? item.product[0] : item.product;
        const name = product ? product.name : "Product";
        const line = document.createElement("div");
        const missing = Number(item.quantity_sent) - Number(item.quantity_received);
        line.textContent =
          name + " — sent " + item.quantity_sent +
          ", received " + item.quantity_received +
          (shipment.status === "received" || shipment.status === "short_received"
            ? ", missing " + missing
            : "");
        card.appendChild(line);
      }

      if (shipment.status === "prepared") {
        const dispatchButton = document.createElement("button");
        dispatchButton.className = "btn btn-primary";
        dispatchButton.type = "button";
        dispatchButton.textContent = "Mark as dispatched";
        dispatchButton.dataset.dispatchId = shipment.id;
        card.appendChild(dispatchButton);
      }

      if (shipment.status === "dispatched" ||
          shipment.status === "partially_received") {
        const form = document.createElement("form");
        form.style.marginTop = "14px";

        const instructions = document.createElement("p");
        instructions.className = "subtitle";
        instructions.textContent =
          "Count each item that arrived. Enter 0 for anything missing.";
        form.appendChild(instructions);

        for (const item of shipment.items) {
          const product = Array.isArray(item.product) ? item.product[0] : item.product;
          const name = product ? product.name : "Product";
          const remaining =
            Number(item.quantity_sent) - Number(item.quantity_received);

          const label = document.createElement("label");
          label.style.display = "block";
          label.style.margin = "10px 0 4px";
          label.textContent =
            name + " (remaining expected: " + remaining + ")";

          const input = document.createElement("input");
          input.className = "field received-quantity";
          input.type = "number";
          input.min = "0";
          input.max = String(remaining);
          input.step = "1";
          input.value = "0";
          input.dataset.productId = String(item.product_id);

          form.append(label, input);
        }

        const receiveButton = document.createElement("button");
        receiveButton.className = "btn btn-primary";
        receiveButton.type = "submit";
        receiveButton.textContent = "Save final receipt tally";
        form.appendChild(receiveButton);

        form.addEventListener("submit", async event => {
          event.preventDefault();
          receiveButton.disabled = true;

          const receivedItems = [...form.querySelectorAll(".received-quantity")]
            .map(input => ({
              product_id: Number(input.dataset.productId),
              quantity_received: Number(input.value)
            }));

          const response = await db.rpc("zerah_receive_shipment", {
            p_shipment_id: shipment.id,
            p_items: receivedItems,
            p_final: true
          });

          receiveButton.disabled = false;

          if (response.error) {
            showMessage("Could not save tally: " + response.error.message, true);
            return;
          }

          showMessage(
            response.data === "short_received"
              ? "Receipt saved. StockFlow recorded a shortage."
              : "Receipt saved. Received quantities were added to stock."
          );
          await loadShipments();
        });

        card.appendChild(form);
      }

      shipmentList.appendChild(card);
    }
  }

  document.getElementById("addShipmentLine").addEventListener("click", () => {
    if (products.length) addProductRow();
  });

  document.getElementById("shipmentForm").addEventListener("submit", async event => {
    event.preventDefault();

    const rows = [...lineRoot.querySelectorAll(".shipment-line")];
    const items = rows.map(row => ({
      product_id: Number(row.querySelector("select").value),
      quantity_sent: Number(row.querySelector('input[type="number"]').value)
    }));

    if (!items.length || items.some(item =>
      !Number.isInteger(item.quantity_sent) || item.quantity_sent < 1
    )) {
      showMessage("Add at least one product with a sent quantity above zero.", true);
      return;
    }

    const submitButton = event.submitter;
    submitButton.disabled = true;

    const created = await db.rpc("zerah_create_shipment", {
      p_store_id: config.storeId,
      p_sender_name: document.getElementById("senderName").value.trim(),
      p_items: items
    });

    if (created.error) {
      submitButton.disabled = false;
      showMessage("Could not create shipment: " + created.error.message, true);
      return;
    }

    const dispatched = await db.rpc("zerah_dispatch_shipment", {
      p_shipment_id: created.data
    });

    submitButton.disabled = false;

    if (dispatched.error) {
      showMessage(
        "Shipment saved as prepared. Dispatch it from the list below: " +
          dispatched.error.message,
        true
      );
    } else {
      showMessage("Shipment recorded and marked as dispatched.");
    }

    document.getElementById("shipmentForm").reset();
    lineRoot.replaceChildren();
    addProductRow();
    await loadShipments();
  });

  shipmentList.addEventListener("click", async event => {
    const button = event.target.closest("[data-dispatch-id]");
    if (!button) return;

    button.disabled = true;

    const result = await db.rpc("zerah_dispatch_shipment", {
      p_shipment_id: button.dataset.dispatchId
    });

    if (result.error) {
      button.disabled = false;
      showMessage("Could not dispatch shipment: " + result.error.message, true);
      return;
    }

    showMessage("Shipment marked as dispatched.");
    await loadShipments();
  });

  navButton.addEventListener("click", () => {
    document.querySelectorAll(".page").forEach(section => {
      section.classList.toggle("active", section.id === "goodsin");
    });

    document.querySelectorAll(".nav-btn").forEach(button => {
      button.classList.toggle("active", button === navButton);
    });

    document.getElementById("topTitle").textContent = "Goods In";
    loadProducts();
    loadShipments();
  });

  document.getElementById("refreshShipments").addEventListener("click", () => {
    loadProducts();
    loadShipments();
  });

  db.auth.getSession().then(result => {
    if (result.data.session) {
      loadProducts();
      loadShipments();
    }
  });

  db.auth.onAuthStateChange((_event, session) => {
    if (session) {
      loadProducts();
      loadShipments();
    }
  });
})();
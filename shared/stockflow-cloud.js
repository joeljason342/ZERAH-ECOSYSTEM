
(() => {
  const config = window.ZERAH_SUPABASE;
  const db = window.supabase.createClient(config.url, config.publishableKey);
  const historyPage = document.getElementById("history");

  if (!historyPage) return;

  const panel = document.createElement("section");
  panel.className = "panel";

  const heading = document.createElement("div");
  heading.className = "panel-heading";

  const title = document.createElement("h3");
  title.textContent = "ZERAH Store orders";

  const refreshButton = document.createElement("button");
  refreshButton.className = "btn";
  refreshButton.textContent = "Refresh";

  heading.append(title, refreshButton);

  const statusBox = document.createElement("p");
  statusBox.className = "subtitle";
  statusBox.textContent = "Sign in to view orders waiting for cashier confirmation.";

  const orderList = document.createElement("div");

  panel.append(heading, statusBox, orderList);
  historyPage.appendChild(panel);

  let refreshTimer = null;
  let started = false;
  let currentUserId = null;
let currentRole = null;

  function setStatus(message, isError) {
    statusBox.textContent = message;
    statusBox.style.color = isError ? "#b93838" : "";
  }

  function formatMoney(value) {
    return new Intl.NumberFormat("en-IN", {
      style: "currency",
      currency: "INR"
    }).format(Number(value) || 0);
  }

  function clearOrders() {
    while (orderList.firstChild) {
      orderList.removeChild(orderList.firstChild);
    }
  }

  function addText(parent, tagName, text, className) {
    const element = document.createElement(tagName);
    element.textContent = text;
    if (className) element.className = className;
    parent.appendChild(element);
    return element;
  }

  async function loadPendingOrders() {
    const result = await db
      .from("zerah_orders")
            .select("id,created_at,total_amount,claimed_by,items:zerah_order_items(quantity,unit_price,product:zerah_products(name))")
      .eq("store_id", config.storeId)
      .eq("status", "pending")
      .order("created_at", { ascending: true });

    if (result.error) {
      setStatus("Order loading error: " + result.error.message, true);
      return;
    }

    clearOrders();

    if (!result.data.length) {
      addText(orderList, "div", "No Store orders are waiting.", "empty");
      setStatus("Orders appear here after customers send them from ZERAH Store.");
      return;
    }

    setStatus(result.data.length + " order(s) waiting for cashier confirmation.");

    for (const order of result.data) {
      const card = document.createElement("div");
      card.className = "history-item";

      const topRow = document.createElement("div");
      topRow.style.display = "flex";
      topRow.style.justifyContent = "space-between";
      topRow.style.gap = "12px";

      addText(topRow, "strong", "Order " + order.id.slice(0, 8));
      addText(topRow, "strong", formatMoney(order.total_amount));
      card.appendChild(topRow);

      addText(card, "small", new Date(order.created_at).toLocaleString());

      for (const item of order.items) {
        const product = Array.isArray(item.product) ? item.product[0] : item.product;
        const name = product ? product.name : "Product";
        addText(
          card,
          "div",
          name + " × " + item.quantity + " — " +
            formatMoney(Number(item.unit_price) * Number(item.quantity))
        );
      }

            const actionButton = document.createElement("button");
      actionButton.className = "btn btn-primary";
      actionButton.dataset.orderId = order.id;

      if (!order.claimed_by) {
        actionButton.textContent = "Accept order";
        actionButton.dataset.action = "claim";
      } else if (order.claimed_by === currentUserId) {
        actionButton.textContent = "Confirm payment & deduct stock";
        actionButton.dataset.action = "confirm";
      } else if (currentRole === "owner" || currentRole === "manager") {
        actionButton.textContent = "Manager: confirm payment & deduct stock";
        actionButton.dataset.action = "confirm";
      } else {
        actionButton.textContent = "Accepted by another cashier";
        actionButton.disabled = true;
      }

      card.appendChild(actionButton);

      orderList.appendChild(card);
    }
  }

  async function syncInventoryToDashboard() {
    const results = await Promise.all([
      db.from("zerah_products")
        .select("id,name,category,purchase_cost,selling_price,minimum_stock,is_active")
        .eq("is_active", true)
        .order("id"),
      db.from("zerah_inventory")
        .select("product_id,quantity_on_hand")
        .eq("store_id", config.storeId)
    ]);

    const productsResult = results[0];
    const stockResult = results[1];

    if (productsResult.error || stockResult.error) {
      setStatus("Could not refresh inventory from the shared database.", true);
      return;
    }

    const stockById = new Map();
    for (const row of stockResult.data) {
      stockById.set(Number(row.product_id), row.quantity_on_hand);
    }

    state.products = productsResult.data.map(product => ({
      id: Number(product.id),
      name: product.name,
      category: product.category,
      cost: product.purchase_cost === null ? NaN : Number(product.purchase_cost),
      price: Number(product.selling_price),
      stock: stockById.get(Number(product.id)) || 0,
      min: Number(product.minimum_stock)
    }));

    saveState();
    renderAll();
    renderBilling();
  }

  async function syncConfirmedSales() {
    const result = await db
      .from("zerah_orders")
      .select("id,created_at,total_amount,items:zerah_order_items(product_id,quantity,unit_price,unit_cost,product:zerah_products(name))")
      .eq("store_id", config.storeId)
      .eq("status", "confirmed")
      .order("created_at", { ascending: false });

    if (result.error) return;

    let changed = false;

    for (const order of result.data) {
      const alreadyAdded = state.sales.some(sale => sale.orderId === order.id);
      if (alreadyAdded) continue;

      const items = order.items.map(item => {
        const product = Array.isArray(item.product) ? item.product[0] : item.product;

        return {
          productId: Number(item.product_id),
          name: product ? product.name : "Product",
          price: Number(item.unit_price),
          unitCost: item.unit_cost === null ? null : Number(item.unit_cost),
          quantity: Number(item.quantity),
          lineTotal: Number(item.unit_price) * Number(item.quantity)
        };
      });

      const costsKnown = items.every(item => Number.isFinite(item.unitCost));
      const grossProfit = costsKnown
        ? items.reduce((sum, item) =>
            sum + (item.price - item.unitCost) * item.quantity, 0)
        : null;

      state.sales.unshift({
        id: Date.now() + Math.floor(Math.random() * 1000),
        orderId: order.id,
        customer: "ZERAH Store order",
        items: items,
        total: Number(order.total_amount),
        grossProfit: grossProfit,
        time: order.created_at
      });

      for (const item of items) {
        state.movements.unshift({
          id: "store-" + order.id + "-" + item.productId,
          productId: item.productId,
          productName: item.name,
          change: -item.quantity,
          reason: "ZERAH Store order " + order.id.slice(0, 8),
          time: order.created_at
        });
      }

      changed = true;
    }

    if (changed) {
      saveState();
      renderAll();
    }
  }

  async function refreshDashboard() {
    await loadPendingOrders();
    await syncInventoryToDashboard();
    await syncConfirmedSales();
  }

    async function start(session) {
    if (started) return;
    started = true;
    currentUserId = session.user.id;

    const membership = await db
      .from("zerah_store_memberships")
      .select("role")
      .eq("store_id", config.storeId)
      .eq("user_id", currentUserId)
      .maybeSingle();

    currentRole = membership.data ? membership.data.role : null;

    await refreshDashboard();
    refreshTimer = setInterval(loadPendingOrders, 15000);
  }

  function stop() {
    started = false;
        currentUserId = null;
    currentRole = null;
    if (refreshTimer) clearInterval(refreshTimer);
    refreshTimer = null;
    clearOrders();
    setStatus("Sign in to view orders waiting for cashier confirmation.");
  }

    orderList.addEventListener("click", async event => {
    const button = event.target.closest("[data-order-id]");
    if (!button) return;

    const action = button.dataset.action;
    const originalText = button.textContent;
    button.disabled = true;
    button.textContent = action === "claim" ? "Accepting…" : "Confirming…";

    if (action === "confirm") {
      const paid = window.confirm(
        "Have you collected payment from the customer at the counter?"
      );

      if (!paid) {
        button.disabled = false;
        button.textContent = originalText;
        return;
      }
    }

    const result = await db.rpc(
      action === "claim"
        ? "zerah_claim_store_order"
        : "zerah_confirm_store_order",
      { p_order_id: button.dataset.orderId }
    );

    if (result.error) {
      setStatus(result.error.message, true);
      await loadPendingOrders();
      return;
    }

    setStatus(
      action === "claim"
        ? "Order accepted by you."
        : "Order confirmed. Stock and sales are updating."
    );

    await refreshDashboard();
  });


  refreshButton.addEventListener("click", refreshDashboard);

  db.auth.onAuthStateChange((_event, session) => {
    if (session) start(session);    else stop();
  });

    db.auth.getSession().then(result => {
    if (result.data.session) start(result.data.session);
  });
})();
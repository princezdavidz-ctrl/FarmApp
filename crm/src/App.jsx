import { useEffect, useMemo, useRef, useState } from "react";
import { api, clearSession, FARM_KEY, ROLE_KEY, saveProfile, saveSession, TOKEN_KEY } from "./api";
import "./customer-workspace.css";
import "./farm-context.css";
import "./registered-buyers.css";
import { AdminNavbar } from "./components/AdminNavbar";
import { CustomerSidebar } from "./components/CustomerSidebar";
import { HomeDashboard } from "./components/HomeDashboard";
import { DirectoryView } from "./components/DirectoryView";
import { RegisteredBuyers } from "./components/RegisteredBuyers";
import { OrdersView } from "./components/OrdersView";
import { PipelineBoard } from "./components/PipelineBoard";
import { FinanceSidebar } from "./components/FinanceSidebar";
import { FinanceWorkspace } from "./components/FinanceWorkspace";
import { FarmFinanceLedger } from "./components/FarmFinanceLedger";
import { Login } from "./components/Login";
import { SplashScreen } from "./components/SplashScreen";
import { CustomerForm } from "./components/CustomerForm";
import { FarmOwnerProspects } from "./components/FarmOwnerProspects";
import { TaskPanel } from "./components/TaskPanel";
import { TasksWorkspace } from "./components/TasksWorkspace";
import { FarmOperationsTasks } from "./components/FarmOperationsTasks";
import { StaffSidebar } from "./components/StaffSidebar";
import { StaffWorkspace } from "./components/StaffWorkspace";
import { CommunicationSidebar } from "./components/CommunicationSidebar";
import { CommunicationWorkspace } from "./components/CommunicationWorkspace";
import { SettingsSidebar } from "./components/SettingsSidebar";
import { SettingsWorkspace } from "./components/SettingsWorkspace";
import { FarmOperationsWorkspace } from "./components/FarmOperationsWorkspace";
import { FarmHerdWorkspace } from "./components/FarmHerdWorkspace";
import { FarmOperationsSidebar } from "./components/FarmOperationsSidebar";
import { CrmFarmOperations } from "./components/CrmFarmOperations";
import { MarketSidebar } from "./components/MarketSidebar";
import { MarketListings } from "./components/MarketListings";
const emptyCustomer = {
  farm_id: "",
  assigned_user_id: "",
  name: "",
  email: "",
  phone: "",
  company: "",
  address: "",
  type: "lead",
  status: "new",
  notes: "",
};
const statuses = ["all", "new", "contacted", "qualified", "won", "lost"];
const interactionTypes = ["message", "call", "email", "visit", "meeting", "note"];
const segmentDefinitions = [
  { id: "hot", label: "Hot leads", description: "Fresh opportunities ready for follow-up", predicate: (customer) => ["new", "contacted"].includes(customer.status) },
  { id: "priority", label: "Priority buyers", description: "Qualified prospects with strong conversion potential", predicate: (customer) => customer.type === "buyer" || customer.status === "qualified" },
  { id: "retained", label: "Retained accounts", description: "Won opportunities and active accounts", predicate: (customer) => customer.status === "won" },
  { id: "at-risk", label: "At risk", description: "Leads that need attention before they go cold", predicate: (customer) => customer.status === "lost" || customer.status === "contacted" },
];
function App() {
  const [customers, setCustomers] = useState([]);
  const [selectedId, setSelectedId] = useState(null);
  const [interactions, setInteractions] = useState([]);
  const [timeline, setTimeline] = useState([]);
  const [tasks, setTasks] = useState([]);
  const [globalTasks, setGlobalTasks] = useState([]);
  const [farmTasks, setFarmTasks] = useState([]);
  const [farmTasksLoading, setFarmTasksLoading] = useState(false);
  const [farmTasksError, setFarmTasksError] = useState("");
  const farmTasksRequest = useRef(0);
  const [globalTasksLoading, setGlobalTasksLoading] = useState(false);
  const [globalTasksError, setGlobalTasksError] = useState("");
  const [taskFilters, setTaskFilters] = useState({ search: "", status: "all", priority: "all", assigned_to: "all", overdue: false });
  const [taskForm, setTaskForm] = useState({ title: "", notes: "", due_at: "", priority: "normal", assigned_to: "" });
  const [filters, setFilters] = useState({ search: "", status: "all", type: "all", assigned_to: "all", sort_by: "latest", sort_direction: "desc", page: 1 });
  const [customerMeta, setCustomerMeta] = useState({ current_page: 1, last_page: 1, per_page: 25, total: 0 });
  const [customerViewMode, setCustomerViewMode] = useState(() => localStorage.getItem("farmapp_crm_customer_view") || "table");
  const [customerListMaximized, setCustomerListMaximized] = useState(false);
  const [form, setForm] = useState(emptyCustomer);
  const [interaction, setInteraction] = useState({ type: "message", notes: "" });
  const [editing, setEditing] = useState(false);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [notice, setNotice] = useState(null);
  const [farmId, setFarmId] = useState("");
  const [availableFarms, setAvailableFarms] = useState([]);
  const [staff, setStaff] = useState([]);
  const [staffCategories, setStaffCategories] = useState([]);
  const [staffGroups, setStaffGroups] = useState({ directory: true, policies: true });
  const buildDefaultPolicyPages = (audience) => {
    if (audience === "finance") {
      return ["Home", "Finance", "Tasks", "Staff → Finance", "Settings"];
    }
    if (audience === "customer_support") {
      return ["Home", "Customers", "Communication", "Tasks", "Staff → Customer service", "Settings"];
    }
    return ["Home", "Customers", "Tasks", "Staff", "Finance", "Communication", "Settings"];
  };
  const [policies, setPolicies] = useState([]);
  const [editingPolicyId, setEditingPolicyId] = useState(null);
  const [policiesLoading, setPoliciesLoading] = useState(false);
  const [importingCustomers, setImportingCustomers] = useState(false);
  const [policyForm, setPolicyForm] = useState({
    title: "",
    audience: "all",
    category: "All staff",
    status: "active",
    effectiveDate: "",
    summary: "",
    details: "",
    notes: "",
    visiblePages: buildDefaultPolicyPages("all"),
  });
  const [staffLogs, setStaffLogs] = useState([]);
  const [crmMessages, setCrmMessages] = useState([]);
  const [supportConversations, setSupportConversations] = useState([]);
  const [activeSupportConversation, setActiveSupportConversation] = useState(null);
  const [supportOnlineAgents, setSupportOnlineAgents] = useState([]);
  const [supportAvailable, setSupportAvailable] = useState(false);
  const [supportPresenceSaving, setSupportPresenceSaving] = useState(false);
  const [broadcastHistory, setBroadcastHistory] = useState([]);
  const [profile, setProfile] = useState(null);
  const [profileAvatar, setProfileAvatar] = useState("");
  const [profileForm, setProfileForm] = useState({ name: "" });
  const [passwordForm, setPasswordForm] = useState({ current_password: "", new_password: "", new_password_confirmation: "" });
  const [settingsFarm, setSettingsFarm] = useState(null);
  const [farmName, setFarmName] = useState("");
  const [farmMembers, setFarmMembers] = useState([]);
  const [globalFarms, setGlobalFarms] = useState([]);
  const [memberPermissions, setMemberPermissions] = useState({});
  const [farmNotifications, setFarmNotifications] = useState([]);
  const [auth, setAuth] = useState(() => ({
    email: "",
    password: "",
    token: localStorage.getItem(TOKEN_KEY) || sessionStorage.getItem(TOKEN_KEY) || "",
    role: localStorage.getItem(ROLE_KEY) || sessionStorage.getItem(ROLE_KEY) || "",
    rememberMe: false,
    challengeId: "",
    destination: "",
    otp: "",
  }));
  const crmRole = auth.role || "customer_support";
  const isAdmin = crmRole === "admin";
  const canWriteCustomers = isAdmin || crmRole === "finance";
  const currentFarmMember = farmMembers.find((member) => String(member.id) === String(profile?.id));
  const canManageFarmTasks = isAdmin || crmRole === "finance" || profile?.role === "farmOwner" || (profile?.role === "farmManager" && (currentFarmMember?.permissions == null || currentFarmMember.permissions.includes("manageTasks")));
  const canReply = isAdmin || crmRole === "customer_support";
  const canNotify = isAdmin || crmRole === "customer_support";
  const canReadCommunication = isAdmin || crmRole === "finance" || crmRole === "customer_support";
  const canViewOperations = isAdmin || crmRole === "finance" || ["farmOwner", "farmManager", "farmWorker"].includes(profile?.role);
  const defaultOperationPermissions = profile?.role === "farmManager"
    ? ["manageHerd", "manageHealth", "manageBreeding", "manageFeed", "manageInventory", "viewReports"]
    : profile?.role === "farmWorker"
      ? ["manageHerd", "manageFeed"]
      : profile?.role === "veterinarian"
        ? ["manageHealth"]
      : [];
  const farmOperationPermissions = profile?.role === "farmOwner"
    ? ["manageHerd", "manageHealth", "manageBreeding", "manageFeed", "manageInventory", "manageGrowth"]
    : currentFarmMember?.permissions ?? defaultOperationPermissions;
  const isGlobalAdmin = Boolean(profile?.is_global_crm_admin);
  const [notification, setNotification] = useState({
    message: "",
    title: "",
    recipient_id: "",
    farm_id: "",
    audience_scope: "farm",
  });
  const [importText, setImportText] = useState("");
  const [activeSection, setActiveSection] = useState("home");
  const [activeView, setActiveView] = useState("customers");
  const [operationsRefreshKey, setOperationsRefreshKey] = useState(0);
  const [marketRefreshKey, setMarketRefreshKey] = useState(0);
  const [operationsOrdersExpanded, setOperationsOrdersExpanded] = useState(true);
  const [buyersRefreshKey, setBuyersRefreshKey] = useState(0);
  const [customerGroups, setCustomerGroups] = useState({ myCustomers: true, orders: false });
  const [calculator, setCalculator] = useState({
    customers: "",
    amount: "",
  });
  const [report, setReport] = useState(null);
  const [farmFinanceLedger, setFarmFinanceLedger] = useState(null);
  const [farmFinanceLoading, setFarmFinanceLoading] = useState(false);
  const [plans, setPlans] = useState([]);
  const [dashboard, setDashboard] = useState(null);
  const [dashboardLoading, setDashboardLoading] = useState(false);
  const [dashboardError, setDashboardError] = useState("");
  const [directory, setDirectory] = useState(null);
  const [directoryLoading, setDirectoryLoading] = useState(false);
  const [directoryError, setDirectoryError] = useState("");
  const [orders, setOrders] = useState({ data: [], meta: null });
  const [ordersLoading, setOrdersLoading] = useState(false);
  const [ordersError, setOrdersError] = useState("");
  const [showSplash, setShowSplash] = useState(true);
  const [planForm, setPlanForm] = useState({
    code: "",
    name: "",
    description: "",
    amount: "",
    currency: "KES",
    pig_limit: "",
    active: true,
  });
  const [memberForm, setMemberForm] = useState({
    name: "",
    email: "",
    password: "",
    crm_role: "finance",
  });
  const selectSection = (section) => {
    setActiveSection(section);
    if (section === "operations") setActiveView("operations-farms");
    if (section === "market") setActiveView("market-posted-pigs");
    if (section === "customers") setActiveView("customers");
    if (section === "tasks") setActiveView("tasks");
    if (section === "staff") setActiveView("staff-list");
    if (section === "finance") setActiveView("finance-reporting");
    if (section === "communication") setActiveView("communication-inbox");
    if (section === "settings") setActiveView("settings-profile");
  };
  const selected = useMemo(
    () => customers.find((customer) => customer.id === selectedId) || null,
    [customers, selectedId],
  );
  const counts = useMemo(
    () =>
      statuses
        .slice(1)
        .reduce(
          (result, status) => ({
            ...result,
            [status]: customers.filter((customer) => customer.status === status)
              .length,
          }),
          {},
        ),
    [customers],
  );
  const leadNextAction = useMemo(() => {
    if (!selected) return "";
    switch (selected.status) {
      case "new":
        return "Call the lead, confirm needs, and record the first touch.";
      case "contacted":
        return "Send the proposal or quote and confirm the buying timeline.";
      case "qualified":
        return "Arrange the delivery plan, subscription details, or follow-up meeting.";
      case "won":
        return "Activate the account and capture the success handoff.";
      case "lost":
        return "Document the reason and keep the opportunity for future re-engagement.";
      default:
        return "Log the next move and keep the relationship moving.";
    }
  }, [selected]);
  const lastInteraction = useMemo(() => interactions[0] || null, [interactions]);
  const segmentSummary = useMemo(
    () =>
      segmentDefinitions.reduce((result, segment) => {
        result[segment.id] = customers.filter(segment.predicate);
        return result;
      }, {}),
    [customers],
  );
  const projectedRevenue = useMemo(() => {
    const customerCount = Number(calculator.customers) || 0;
    const monthlyAmount = Number(calculator.amount) || 0;
    return customerCount * monthlyAmount;
  }, [calculator]);
  const showNotice = (message, tone = "info") => {
    setNotice({ message, tone });
    window.setTimeout(() => setNotice(null), 3500);
  };
  const resetFarmWorkspace = () => {
    farmTasksRequest.current += 1;
    setCustomers([]);
    setSelectedId(null);
    setInteractions([]);
    setTimeline([]);
    setTasks([]);
    setGlobalTasks([]);
    setFarmTasks([]);
    setFarmTasksLoading(false);
    setFarmTasksError("");
    setDashboard(null);
    setDirectory(null);
    setOrders({ data: [], meta: null });
    setStaff([]);
    setStaffCategories([]);
    setPolicies([]);
    setStaffLogs([]);
    setCrmMessages([]);
    setSupportConversations([]);
    setActiveSupportConversation(null);
    setSupportOnlineAgents([]);
    setSupportAvailable(false);
    setBroadcastHistory([]);
    setFarmMembers([]);
    setFarmNotifications([]);
    setMemberPermissions({});
    setReport(null);
    setFarmFinanceLedger(null);
    setGlobalFarms([]);
  };
  const resetUserWorkspace = () => {
    resetFarmWorkspace();
    setProfile(null);
    setProfileForm({ name: "" });
    setSettingsFarm(null);
    setFarmName("");
    setFarmId("");
    setAvailableFarms([]);
    setForm(emptyCustomer);
    setProfileAvatar("");
  };
  const logout = async () => {
    try {
      if (auth.token && farmId && canReply && !isGlobalAdmin) {
        await api.post("/crm/support-presence", { farm_id: Number(farmId), online: false });
      }
      if (auth.token) await api.post("/auth/logout");
    } catch {
      // The local session must still end when the server is unavailable.
    } finally {
      clearSession();
      localStorage.removeItem(FARM_KEY);
      resetUserWorkspace();
      setAuth({ email: "", password: "", token: "", role: "", rememberMe: false, challengeId: "", destination: "", otp: "" });
    }
  };

  const changeFarm = (nextFarmId) => {
    const nextFarm = availableFarms.find((farm) => String(farm.id) === String(nextFarmId));
    if (!nextFarm || String(nextFarm.id) === String(farmId)) return;
    const normalizedFarmId = String(nextFarm.id);
    localStorage.setItem(FARM_KEY, normalizedFarmId);
    setFarmId(normalizedFarmId);
    setSettingsFarm(nextFarm);
    setFarmName(nextFarm.name || "");
    setForm((current) => ({ ...current, farm_id: normalizedFarmId }));
    resetFarmWorkspace();
    setFilters((current) => ({ ...current, page: 1 }));
  };
  const updateProfileAvatar = (file) => {
    if (!file) return;
    const formData = new FormData();
    formData.append("avatar", file);
    api.post("/auth/profile/avatar", formData)
      .then((response) => {
        const updatedUser = response.data?.user;
        setProfile((current) => ({ ...current, ...updatedUser }));
        setProfileAvatar(updatedUser?.avatar_url || "");
        showNotice("Profile picture saved to your account.", "success");
      })
      .catch((error) => showNotice(error.response?.data?.message || "Could not save your profile picture.", "error"));
  };
  useEffect(() => {
    if (!auth.token) return undefined;
    let timer;
    const resetIdleTimer = () => {
      window.clearTimeout(timer);
      timer = window.setTimeout(logout, 30 * 60 * 1000);
    };
    const activityEvents = ["click", "keydown", "mousemove", "scroll", "touchstart"];
    activityEvents.forEach((event) => window.addEventListener(event, resetIdleTimer));
    resetIdleTimer();
    return () => {
      window.clearTimeout(timer);
      activityEvents.forEach((event) => window.removeEventListener(event, resetIdleTimer));
    };
  }, [auth.token]);

  useEffect(() => {
    if (!auth.token) return undefined;
    let active = true;
    api.get("/auth/me")
      .then((response) => {
        if (!active) return;
        const session = saveProfile(response);
        setProfile(session.user);
        setProfileForm({ name: session.user.name || "" });
        setProfileAvatar(session.user.avatar_url || "");
        const role = session.user.crm_role || (session.user.role === "farmOwner" ? "admin" : "customer_support");
        setAvailableFarms(session.farms);
        const savedFarmId = localStorage.getItem(FARM_KEY);
        const nextFarm = session.farms.find((farm) => String(farm.id) === savedFarmId) || session.farms[0] || null;
        const nextFarmId = nextFarm?.id ? String(nextFarm.id) : "";
        setFarmId(nextFarmId);
        if (nextFarmId) localStorage.setItem(FARM_KEY, nextFarmId);
        setSettingsFarm(nextFarm);
        setFarmName(nextFarm?.name || "");
        setForm((current) => ({ ...current, farm_id: nextFarmId }));
        setAuth((current) => ({ ...current, role }));
      })
      .catch(() => logout());
    return () => { active = false; };
  }, [auth.token]);

  useEffect(() => {
    const expire = () => {
      localStorage.removeItem(FARM_KEY);
      resetUserWorkspace();
      setAuth((current) => ({ ...current, token: "", role: "" }));
    };
    window.addEventListener("farmapp-auth-expired", expire);
    return () => window.removeEventListener("farmapp-auth-expired", expire);
  }, []);

  useEffect(() => {
    const timer = window.setTimeout(() => setShowSplash(false), 1800);
    return () => window.clearTimeout(timer);
  }, []);

  const parseCsvLine = (line) => {
    const cells = [];
    let current = "";
    let inQuotes = false;
    for (let i = 0; i < line.length; i += 1) {
      const char = line[i];
      if (char === '"') {
        if (inQuotes && line[i + 1] === '"') {
          current += '"';
          i += 1;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (char === "," && !inQuotes) {
        cells.push(current.trim());
        current = "";
        continue;
      }
      current += char;
    }
    cells.push(current.trim());
    return cells;
  };
  const importCustomersFromCsv = async (event) => {
    event.preventDefault();
    if (importingCustomers) return;
    if (!importText.trim()) {
      return showNotice("Paste or upload customer rows before importing.", "error");
    }
    if (!farmId) {
      return showNotice("Your account is not linked to a farm.", "error");
    }
    const sourceLines = importText.split(/\r?\n/).filter((line) => line.trim());
    const rows = sourceLines.map(parseCsvLine);
    if (rows.length < 2) {
      return showNotice("Add at least a header row and one customer row.", "error");
    }
    const headers = rows[0].map((header) => header.toLowerCase().trim());
    const imported = [];
    const failedLines = [];
    setImportingCustomers(true);
    for (const [index, row] of rows.slice(1).entries()) {
      const record = Object.fromEntries(headers.map((header, index) => [header, row[index] || ""]));
      const payload = {
        farm_id: Number(farmId),
        name: record.name || record.company || record.customer || "Imported customer",
        email: record.email || record.contact_email || "",
        phone: record.phone || record.mobile || record.contact_phone || "",
        company: record.company || record.business || "",
        address: record.address || record.location || "",
        type: ["buyer", "supplier"].includes((record.type || "").toLowerCase()) ? record.type.toLowerCase() : "lead",
        status: ["new", "contacted", "qualified", "won", "lost"].includes((record.status || "").toLowerCase()) ? record.status.toLowerCase() : "new",
        notes: record.notes || `Imported from CSV on ${new Date().toLocaleDateString()}`,
      };
      try {
        const response = await api.post("/crm/customers", payload);
        imported.push(response.data.data);
      } catch (error) {
        failedLines.push(sourceLines[index + 1]);
      }
    }
    setImportingCustomers(false);
    if (imported.length) {
      setCustomers((current) => [...imported, ...current]);
      setSelectedId(imported[0]?.id || null);
    }
    if (failedLines.length) {
      setImportText([sourceLines[0], ...failedLines].join("\n"));
      showNotice(`${imported.length} imported; ${failedLines.length} failed. Failed rows remain in the box so you can correct and retry them.`, imported.length ? "warning" : "error");
      return;
    }
    setImportText("");
    showNotice(`Imported ${imported.length} customer records.`, "success");
  };
  const loadCustomers = async () => {
    try {
      setLoading(true);
      const params = {
        ...(farmId ? { farm_id: farmId } : {}),
        ...(filters.search ? { search: filters.search } : {}),
        ...(filters.status !== "all" ? { status: filters.status } : {}),
        ...(filters.type !== "all" ? { type: filters.type } : {}),
        ...(filters.assigned_to !== "all" ? { assigned_to: filters.assigned_to } : {}),
        sort_by: filters.sort_by,
        sort_direction: filters.sort_direction,
        page: filters.page,
        per_page: 25,
        _refresh: Date.now(),
      };
      const response = await api.get("/crm/customers", { params });
      const data = response.data?.data || [];
      setCustomers(data);
      setCustomerMeta(response.data?.meta || { current_page: 1, last_page: 1, per_page: 25, total: data.length });
      setSelectedId((current) =>
        data.some((customer) => customer.id === current)
          ? current
          : data[0]?.id || null,
      );
    } catch (error) {
      showNotice(
        error.response?.data?.message ||
          "Unable to load customers. Check your connection.",
        "error",
      );
    } finally {
      setLoading(false);
    }
  };
  useEffect(() => {
    if (!auth.token) return undefined;
    const timer = window.setTimeout(() => loadCustomers(), 300);
    return () => window.clearTimeout(timer);
  }, [auth.token, farmId, filters.search, filters.status, filters.type, filters.assigned_to, filters.sort_by, filters.sort_direction, filters.page]);
  useEffect(() => {
    if (!auth.token || !isAdmin && crmRole !== "finance") return undefined;
    loadReport();
    return undefined;
  }, [auth.token, farmId, isAdmin, crmRole]);
  useEffect(() => {
    if (!auth.token || !isAdmin && crmRole !== "finance") return undefined;
    loadPlans();
    return undefined;
  }, [auth.token, isAdmin, crmRole]);
  useEffect(() => {
    if (!selected) {
      setInteractions([]);
      return;
    }
    Promise.all([
      api.get(`/crm/customers/${selected.id}/interactions`),
      api.get(`/crm/customers/${selected.id}/tasks`),
      api.get(`/crm/customers/${selected.id}/timeline`),
    ])
      .then(([interactionResponse, taskResponse, timelineResponse]) => {
        setInteractions(interactionResponse.data?.data || []);
        setTasks(taskResponse.data?.data || []);
        setTimeline(timelineResponse.data?.data || []);
      })
      .catch(() => showNotice("Unable to load customer workflow history.", "error"));
  }, [selectedId]);

  const establishSession = (response, identifier, rememberMe) => {
    const session = saveSession(response, rememberMe);
    resetUserWorkspace();
    const token = response.data.access_token;
    const farms = session.farms;
    setAvailableFarms(farms);
    const savedFarmId = localStorage.getItem(FARM_KEY);
    const selectedFarm = farms.find((farm) => String(farm.id) === savedFarmId) || farms[0] || null;
    const selectedFarmId = selectedFarm?.id ? String(selectedFarm.id) : "";
    if (selectedFarmId) localStorage.setItem(FARM_KEY, selectedFarmId);
    const user = session.user;
    setProfile(user);
    setProfileForm({ name: user.name || "" });
    const role = user.crm_role || (user.role === "farmOwner" ? "admin" : "customer_support");
    setFarmId(selectedFarmId);
    setSettingsFarm(selectedFarm);
    setFarmName(selectedFarm?.name || "");
    setForm((current) => ({ ...current, farm_id: selectedFarmId }));
    setAuth((current) => ({ ...current, password: "", token, role, challengeId: "", destination: "", otp: "" }));
    showNotice(`Welcome back. ${role.replace("_", " ")} workspace loaded.`, "success");
  };
  const login = async (event) => {
    event.preventDefault();
    try {
      const response = await api.post("/auth/login", {
        identifier: auth.email,
        password: auth.password,
        remember_me: auth.rememberMe,
      });
      if (response.data?.otp_required) {
        setAuth((current) => ({
          ...current,
          challengeId: response.data.challenge_id,
          destination: response.data.destination || "your registered email",
          otp: "",
        }));
        showNotice("A six-digit sign-in code was sent to your email.", "success");
        return;
      }
      establishSession(response, auth.email, auth.rememberMe);
    } catch (error) {
      showNotice(
        error.response?.data?.message ||
          "Authentication failed. Check your credentials.",
        "error",
      );
    }
  };
  const verifyLoginOtp = async (code) => {
    if (!auth.challengeId || !/^\d{6}$/.test(code || "")) {
      showNotice("Enter the six-digit code sent to your email.", "error");
      return;
    }
    try {
      const response = await api.post("/auth/verify-otp", {
        challenge_id: auth.challengeId,
        code,
      });
      establishSession(response, auth.email, auth.rememberMe);
    } catch (error) {
      showNotice(
        error.response?.data?.errors?.code?.[0] ||
          error.response?.data?.message ||
          "That code is invalid or expired. Request a new sign-in code.",
        "error",
      );
    }
  };
  const resendLoginOtp = async () => {
    if (!auth.challengeId) {
      showNotice("Sign in again to request a new verification code.", "error");
      return;
    }
    try {
      const response = await api.post("/auth/resend-otp", {
        challenge_id: auth.challengeId,
      });
      setAuth((current) => ({
        ...current,
        challengeId: response.data.challenge_id,
        destination: response.data.destination || current.destination,
        otp: "",
      }));
      showNotice("A new six-digit sign-in code was sent to your email.", "success");
    } catch (error) {
      showNotice(
        error.response?.data?.errors?.challenge_id?.[0] ||
          error.response?.data?.message ||
          "Could not resend the code. Sign in again and try once more.",
        "error",
      );
    }
  };
  const requestPasswordReset = async (email) => {
    try {
      await api.post("/auth/forgot-password", { email });
      showNotice("If that email is registered, a reset link has been sent.", "success");
    } catch (error) {
      const message = error.response?.data?.message || "Could not send the reset link. Please try again.";
      showNotice(message, "error");
    }
  };
  const updateForm = (key, value) =>
    setForm((current) => ({ ...current, [key]: value }));
  const saveCustomer = async (event) => {
    if (!canWriteCustomers)
      return showNotice(
        "Your CRM role cannot change customer records.",
        "error",
      );
    event.preventDefault();
    if (!form.name.trim())
      return showNotice("A customer name is required.", "error");
    if (!editing && !farmId)
      return showNotice("Your account is not linked to a farm.", "error");
    try {
      setSaving(true);
      const payload = {
        ...form,
        farm_id: Number(editing ? form.farm_id : farmId),
      };
      const response = editing
        ? await api.put(`/crm/customers/${selected.id}`, payload)
        : await api.post("/crm/customers", payload);
      const saved = response.data.data;
      setCustomers((current) =>
        editing
          ? current.map((item) => (item.id === saved.id ? saved : item))
          : [saved, ...current],
      );
      setSelectedId(saved.id);
      setForm({ ...emptyCustomer, farm_id: farmId });
      setEditing(false);
      showNotice(editing ? "Customer updated." : "Customer added.", "success");
    } catch (error) {
      showNotice(
        error.response?.data?.message || "Could not save this customer.",
        "error",
      );
    } finally {
      setSaving(false);
    }
  };
  const startEditing = () => {
    setForm({ ...emptyCustomer, ...selected });
    setEditing(true);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };
  const deleteCustomer = async () => {
    if (!isAdmin)
      return showNotice("Only admins can delete customers.", "error");
    if (
      !selected ||
      !window.confirm(
        `Delete ${selected.name}? This also removes interaction history.`,
      )
    )
      return;
    try {
      await api.delete(`/crm/customers/${selected.id}`);
      setCustomers((current) =>
        current.filter((item) => item.id !== selected.id),
      );
      setSelectedId(null);
      showNotice("Customer deleted.", "success");
    } catch (error) {
      showNotice(
        error.response?.data?.message || "Could not delete this customer.",
        "error",
      );
    }
  };
  const addInteraction = async (event) => {
    event.preventDefault();
    if (!canReply)
      return showNotice(
        "Only customer support can reply to customers.",
        "error",
      );
    if (!selected) return;
    try {
      const response = await api.post(
        `/crm/customers/${selected.id}/interactions`,
        { ...interaction, occurred_at: new Date().toISOString() },
      );
      setInteractions((current) => [response.data.data, ...current]);
      await loadCustomerWorkflow(selected.id);
      setInteraction({ type: "message", notes: "" });
      showNotice("Reply logged.", "success");
    } catch (error) {
      showNotice(
        error.response?.data?.message || "Could not log reply.",
        "error",
      );
    }
  };
  const loadCustomerWorkflow = async (customerId) => {
    const [interactionResponse, taskResponse, timelineResponse] = await Promise.all([
      api.get(`/crm/customers/${customerId}/interactions`),
      api.get(`/crm/customers/${customerId}/tasks`),
      api.get(`/crm/customers/${customerId}/timeline`),
    ]);
    setInteractions(interactionResponse.data?.data || []);
    setTasks(taskResponse.data?.data || []);
    setTimeline(timelineResponse.data?.data || []);
  };
  const saveTask = async (event) => {
    event.preventDefault();
    if (!selected || !taskForm.title.trim()) return;
    try {
      const response = await api.post(`/crm/customers/${selected.id}/tasks`, {
        ...taskForm,
        assigned_to: taskForm.assigned_to || null,
        due_at: taskForm.due_at ? new Date(taskForm.due_at).toISOString() : null,
      });
      setTasks((current) => [response.data.data, ...current]);
      setTaskForm({ title: "", notes: "", due_at: "", priority: "normal", assigned_to: "" });
      await loadCustomerWorkflow(selected.id);
      showNotice("Follow-up task created.", "success");
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not create the task.", "error");
    }
  };
  const updateTaskStatus = async (task, status) => {
    try {
      await api.patch(`/crm/customers/${selected.id}/tasks/${task.id}`, { status });
      await loadCustomerWorkflow(selected.id);
      showNotice(status === "completed" ? "Task completed." : "Task reopened.", "success");
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not update the task.", "error");
    }
  };
  const addQuickAutomation = async (template) => {
    if (!selected) {
      return showNotice("Select a customer before using a communication shortcut.", "error");
    }
    try {
      const response = await api.post(
        `/crm/customers/${selected.id}/interactions`,
        {
          type: template.type,
          notes: template.copy,
          occurred_at: new Date().toISOString(),
        },
      );
      setInteractions((current) => [response.data.data, ...current]);
      showNotice(`${template.label} saved to ${selected.name}.`, "success");
    } catch (error) {
      showNotice(
        error.response?.data?.message || "Could not save the automation action.",
        "error",
      );
    }
  };
  const updateCustomerStatus = async (customerOrStatus, requestedStatus) => {
    const customer = typeof customerOrStatus === "object" ? customerOrStatus : selected;
    const nextStatus = requestedStatus || customerOrStatus;
    if (!customer || nextStatus === customer.status) return;
    try {
      const response = await api.put(`/crm/customers/${customer.id}`, {
        ...customer,
        status: nextStatus,
        farm_id: Number(customer.farm_id || farmId || 0),
      });
      const updated = response.data.data;
      setCustomers((current) =>
        current.map((customer) => (customer.id === updated.id ? updated : customer)),
      );
      setSelectedId(updated.id);
      await loadCustomerWorkflow(updated.id);
      showNotice(`Customer moved to ${nextStatus}.`, "success");
    } catch (error) {
      showNotice(
        error.response?.data?.message || "Could not update the lead status.",
        "error",
      );
    }
  };
  const loadStaff = async () => {
    if (!auth.token || !farmId) return;
    try {
      const response = await api.get("/crm/members", {
        params: { farm_id: farmId },
      });
      setStaff(response.data?.data || []);
    } catch (error) {
      showNotice(
        error.response?.data?.message || "Unable to load CRM accounts.",
        "error",
      );
    }
  };
  const loadPolicies = async () => {
    if (!auth.token || !farmId) return;
    try {
      setPoliciesLoading(true);
      const response = await api.get("/crm/policies", { params: { farm_id: farmId } });
      setPolicies(response.data?.data || []);
    } catch (error) {
      showNotice(error.response?.data?.message || "Unable to load staff policies.", "error");
    } finally {
      setPoliciesLoading(false);
    }
  };
  const loadStaffLogs = async () => {
    if (!auth.token || !farmId || !isAdmin) return;
    try {
      const response = await api.get("/crm/audit-logs", { params: { farm_id: farmId, per_page: 100 } });
      setStaffLogs(response.data?.data || []);
    } catch (error) {
      showNotice(error.response?.data?.message || "Unable to load staff audit history.", "error");
    }
  };
  const loadStaffCategories = async () => {
    if (!auth.token || !farmId) return;
    try {
      const response = await api.get("/crm/staff-categories", { params: { farm_id: farmId, _refresh: Date.now() } });
      setStaffCategories(response.data?.data || []);
    } catch (error) {
      showNotice(error.response?.data?.message || "Unable to load staff categories.", "error");
    }
  };
  const addStaffCategory = async (event, category) => {
    event.preventDefault();
    try {
      const response = await api.post("/crm/staff-categories", { farm_id: Number(farmId), ...category });
      setStaffCategories((current) => [...current, response.data.data].sort((left, right) => left.name.localeCompare(right.name)));
      if (isAdmin) await loadStaffLogs();
      showNotice("Staff category created.", "success");
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not create staff category.", "error");
    }
  };
  const deleteStaffCategory = async (category) => {
    if (!window.confirm(`Delete the ${category.name} category?`)) return;
    try {
      await api.delete(`/crm/staff-categories/${category.id}`);
      setStaffCategories((current) => current.filter((item) => item.id !== category.id));
      if (isAdmin) await loadStaffLogs();
      showNotice("Staff category deleted.", "success");
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not delete staff category.", "error");
    }
  };
  const loadGlobalTasks = async () => {
    if (!auth.token || !farmId) return;
    try {
      setGlobalTasksLoading(true);
      setGlobalTasksError("");
      const params = {
        farm_id: farmId,
        ...(taskFilters.search ? { search: taskFilters.search } : {}),
        ...(taskFilters.status !== "all" ? { status: taskFilters.status } : {}),
        ...(taskFilters.priority !== "all" ? { priority: taskFilters.priority } : {}),
        ...(taskFilters.assigned_to !== "all" ? { assigned_to: taskFilters.assigned_to } : {}),
        ...(taskFilters.overdue ? { overdue: 1 } : {}),
        _refresh: Date.now(),
      };
      const response = await api.get("/crm/tasks", { params });
      setGlobalTasks(response.data?.data || []);
    } catch (error) {
      setGlobalTasksError(error.response?.data?.message || "Unable to load follow-up tasks.");
    } finally {
      setGlobalTasksLoading(false);
    }
  };
  const loadFarmTasks = async () => {
    if (!auth.token || !farmId) return;
    const requestId = ++farmTasksRequest.current;
    try {
      setFarmTasksLoading(true);
      setFarmTasksError("");
      const response = await api.get(`/farms/${farmId}/tasks`, { params: { _refresh: Date.now() } });
      if (requestId !== farmTasksRequest.current) return;
      setFarmTasks(response.data?.data || []);
    } catch (error) {
      if (requestId !== farmTasksRequest.current) return;
      setFarmTasksError(error.response?.data?.message || "Unable to load farm operations tasks.");
    } finally {
      if (requestId === farmTasksRequest.current) setFarmTasksLoading(false);
    }
  };
  const saveFarmTask = async (_event, draft) => {
    try {
      await api.post(`/farms/${farmId}/tasks`, {
        ...draft,
        assigned_to: draft.assigned_to ? Number(draft.assigned_to) : null,
        due_at: draft.due_at ? new Date(draft.due_at).toISOString() : null,
      });
      await loadFarmTasks();
      showNotice("Farm task created.", "success");
      return true;
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not create the farm task.", "error");
      return false;
    }
  };
  const updateFarmTaskStatus = async (task, status) => {
    try {
      await api.patch(`/farms/${farmId}/tasks/${task.id}`, { status });
      await loadFarmTasks();
      showNotice(status === "completed" ? "Farm task completed." : "Farm task reopened.", "success");
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not update the farm task.", "error");
    }
  };
  const deleteFarmTask = async (task) => {
    if (!window.confirm(`Delete “${task.title}”?`)) return;
    try {
      await api.delete(`/farms/${farmId}/tasks/${task.id}`);
      await loadFarmTasks();
      showNotice("Farm task deleted.", "success");
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not delete the farm task.", "error");
    }
  };
  const updateGlobalTaskStatus = async (task, status) => {
    try {
      await api.patch(`/crm/customers/${task.customer_id}/tasks/${task.id}`, { status });
      await loadGlobalTasks();
      showNotice(status === "completed" ? "Task completed." : "Task reopened.", "success");
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not update the task.", "error");
    }
  };
  const loadCrmMessages = async () => {
    const messageFarmId = farmId || (isGlobalAdmin ? notification.farm_id || globalFarms[0]?.id : "");
    if (!auth.token || !messageFarmId || !canReadCommunication) return;
    try {
      const [legacyResponse, conversationResponse, broadcastResponse] = await Promise.all([
        api.get("/crm/notifications", { params: { farm_id: messageFarmId } }),
        canReply && !isGlobalAdmin
          ? api.get("/crm/support-conversations", { params: { farm_id: messageFarmId, status: "all" } })
          : Promise.resolve({ data: { data: [] } }),
        canNotify
          ? api.get("/crm/broadcasts", { params: { farm_id: messageFarmId } })
          : Promise.resolve({ data: { data: [] } }),
      ]);
      const presenceResponse = canReply && !isGlobalAdmin
        ? await api.get("/crm/support-presence", { params: { farm_id: messageFarmId } })
        : { data: { data: { online_agents: [], current_user_online: false } } };
      setCrmMessages(legacyResponse.data?.data || []);
      setSupportConversations(conversationResponse.data?.data || []);
      setBroadcastHistory(broadcastResponse.data?.data || []);
      setSupportOnlineAgents(presenceResponse.data?.data?.online_agents || []);
      setSupportAvailable(Boolean(presenceResponse.data?.data?.current_user_online));
    } catch (error) {
      showNotice(error.response?.data?.message || "Unable to load CRM messages.", "error");
    }
  };
  const updateSupportAvailability = async (online) => {
    if (!farmId || supportPresenceSaving) return;
    setSupportPresenceSaving(true);
    try {
      await api.post("/crm/support-presence", {
        farm_id: Number(farmId),
        online,
      });
      setSupportAvailable(online);
      await loadCrmMessages();
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not update live chat availability.", "error");
    } finally {
      setSupportPresenceSaving(false);
    }
  };
  const loadGlobalFarms = async () => {
    if (!auth.token || !isGlobalAdmin) return;
    try {
      const response = await api.get("/crm/admin/farms");
      const farms = response.data?.data || [];
      setGlobalFarms(farms);
      setNotification((current) => ({ ...current, farm_id: current.farm_id || String(farms[0]?.id || "") }));
    } catch (error) {
      showNotice(error.response?.data?.message || "Unable to load farms for central CRM administration.", "error");
    }
  };
  const openSupportConversation = async (conversation) => {
    try {
      await api.patch(`/crm/support-conversations/${conversation.id}/read`);
      const response = await api.get(`/crm/support-conversations/${conversation.id}`);
      setActiveSupportConversation(response.data?.data || null);
      await loadCrmMessages();
    } catch (error) {
      showNotice(error.response?.data?.message || "Unable to open this support conversation.", "error");
    }
  };
  const sendSupportReply = async (message) => {
    if (!activeSupportConversation) return;
    try {
      await api.post(`/crm/support-conversations/${activeSupportConversation.id}/messages`, { message });
      const response = await api.get(`/crm/support-conversations/${activeSupportConversation.id}`);
      setActiveSupportConversation(response.data?.data || null);
      await loadCrmMessages();
      showNotice("Reply sent to the farm user.", "success");
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not send your reply.", "error");
    }
  };
  const updateSupportConversation = async (changes) => {
    if (!activeSupportConversation) return;
    try {
      await api.patch(`/crm/support-conversations/${activeSupportConversation.id}`, changes);
      const response = await api.get(`/crm/support-conversations/${activeSupportConversation.id}`);
      setActiveSupportConversation(response.data?.data || null);
      await loadCrmMessages();
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not update the conversation.", "error");
    }
  };
  const loadSettingsData = async () => {
    if (!auth.token || !farmId) return;
    try {
      const [memberResponse, notificationResponse] = await Promise.all([
        api.get(`/farms/${farmId}/members`),
        api.get(`/farms/${farmId}/notifications`),
      ]);
      const members = memberResponse.data?.data || [];
      setFarmMembers(members);
      setMemberPermissions(Object.fromEntries(members.map((member) => [member.id, member.permissions || []])));
      setFarmNotifications(notificationResponse.data?.data || []);
    } catch (error) {
      showNotice(error.response?.data?.message || "Unable to load workspace settings.", "error");
    }
  };
  const saveProfileSettings = async (event) => {
    event.preventDefault();
    try {
      const response = await api.patch("/auth/profile", profileForm);
      setProfile(response.data?.user || null);
      setProfileForm({ name: response.data?.user?.name || profileForm.name });
      showNotice("Profile updated.", "success");
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not update your profile.", "error");
    }
  };
  const changePassword = async (event) => {
    event.preventDefault();
    if (passwordForm.new_password !== passwordForm.new_password_confirmation) return showNotice("New passwords do not match.", "error");
    try {
      await api.post("/auth/change-password", passwordForm);
      setPasswordForm({ current_password: "", new_password: "", new_password_confirmation: "" });
      showNotice("Password changed successfully.", "success");
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not change your password.", "error");
    }
  };
  const saveFarmSettings = async (event) => {
    event.preventDefault();
    if (!settingsFarm || !farmName.trim()) return;
    try {
      const response = await api.patch(`/farms/${settingsFarm.id}`, { name: farmName.trim() });
      const updated = response.data?.data || { ...settingsFarm, name: farmName.trim() };
      setSettingsFarm(updated);
      setFarmName(updated.name);
      showNotice("Farm workspace updated.", "success");
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not update the farm workspace.", "error");
    }
  };
  const saveMemberPermissions = async (member) => {
    try {
      const response = await api.patch(`/farms/${farmId}/members/${member.id}`, { permissions: memberPermissions[member.id] || [] });
      setFarmMembers((current) => current.map((item) => item.id === member.id ? response.data?.data || item : item));
      showNotice(`${member.name}'s permissions updated.`, "success");
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not update member permissions.", "error");
    }
  };
  const loadFarmNotifications = async () => {
    if (!farmId) return;
    try {
      const response = await api.get(`/farms/${farmId}/notifications`);
      setFarmNotifications(response.data?.data || []);
    } catch (error) {
      showNotice(error.response?.data?.message || "Unable to load notifications.", "error");
    }
  };
  const markFarmNotificationRead = async (notification) => {
    try {
      await api.patch(`/farms/${farmId}/notifications/${notification.id}/read`);
      setFarmNotifications((current) => current.map((item) => item.id === notification.id ? { ...item, read_at: new Date().toISOString() } : item));
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not mark notification as read.", "error");
    }
  };
  const loadDashboard = async () => {
    if (!auth.token || !farmId) return;
    try {
      setDashboardLoading(true);
      setDashboardError("");
      const response = await api.get("/crm/dashboard/overview", { params: { farm_id: farmId, _refresh: Date.now() } });
      setDashboard(response.data?.data || null);
    } catch (error) {
      const message = error.response?.data?.message || "Unable to load the CRM dashboard.";
      setDashboardError(message);
    } finally {
      setDashboardLoading(false);
    }
  };
  const loadReport = async () => {
    if (!auth.token || !farmId || !isAdmin && crmRole !== "finance") return;
    try {
      const response = await api.get("/crm/reports/overview", {
        params: { farm_id: farmId, _refresh: Date.now() },
      });
      setReport(response.data?.data || null);
    } catch (error) {
      showNotice(error.response?.data?.message || "Unable to load revenue reporting.", "error");
    }
  };
  const loadFarmFinanceLedger = async () => {
    if (!auth.token || !farmId || !isAdmin && crmRole !== "finance") return;
    try {
      setFarmFinanceLoading(true);
      const response = await api.get(`/farms/${farmId}/finance`, { params: { _refresh: Date.now() } });
      setFarmFinanceLedger(response.data || null);
      return true;
    } catch (error) {
      showNotice(error.response?.data?.message || "Unable to load farm income and expenses.", "error");
      return false;
    } finally {
      setFarmFinanceLoading(false);
    }
  };
  const createFarmFinanceTransaction = async (transaction) => {
    const response = await api.post(`/farms/${farmId}/finance`, transaction);
    const refreshed = await loadFarmFinanceLedger();
    showNotice(refreshed ? "Farm transaction recorded." : "Transaction saved, but the ledger could not be refreshed.", refreshed ? "success" : "error");
    return response.data?.data;
  };
  const loadPlans = async () => {
    if (!auth.token || !isAdmin && crmRole !== "finance") return;
    try {
      const response = await api.get("/subscription-plans", { params: { _refresh: Date.now() } });
      setPlans(response.data?.data || []);
    } catch (error) {
      showNotice(error.response?.data?.message || "Unable to load subscription plans.", "error");
    }
  };
  const loadDirectory = async () => {
    if (!auth.token) return;
    try {
      setDirectoryLoading(true);
      setDirectoryError("");
      const response = await api.get("/crm/directories/overview");
      setDirectory(response.data?.data || null);
    } catch (error) {
      setDirectoryError(error.response?.data?.message || "Unable to load customer directories.");
    } finally {
      setDirectoryLoading(false);
    }
  };
  const loadOrders = async (status) => {
    if (!auth.token) return;
    try {
      setOrdersLoading(true);
      setOrdersError("");
      const response = await api.get("/crm/orders", { params: { status, per_page: 25 } });
      setOrders({ data: response.data?.data || [], meta: response.data?.meta || null });
    } catch (error) {
      setOrdersError(error.response?.data?.message || "Unable to load customer orders.");
    } finally {
      setOrdersLoading(false);
    }
  };
  const refreshCurrentView = () => {
    if (activeSection === "home") return loadDashboard();
    if (activeSection === "operations") return setOperationsRefreshKey((key) => key + 1);
    if (activeSection === "market") return setMarketRefreshKey((key) => key + 1);
    if (activeSection === "customers") {
      if (activeView === "registered-buyers") return setBuyersRefreshKey((key) => key + 1);
      if (activeView.startsWith("orders-")) return loadOrders(activeView.replace("orders-", ""));
      if (["farm-owners", "farm-managers", "farm-workers", "relationships"].includes(activeView)) return loadDirectory();
      return loadCustomers();
    }
    if (activeSection === "tasks") return Promise.all([loadGlobalTasks(), loadFarmTasks()]);
    if (activeSection === "staff") return Promise.all([loadStaff(), loadStaffCategories(), loadPolicies(), loadStaffLogs()]);
    if (activeSection === "communication") return loadCrmMessages();
    if (activeSection === "settings") return activeView === "settings-notifications" ? loadFarmNotifications() : loadSettingsData();
    if (activeSection === "finance") return Promise.all([loadReport(), loadPlans(), loadFarmFinanceLedger()]);
    return undefined;
  };
  const updateStaff = async (member, data) => {
    try {
      const response = await api.patch(`/crm/members/${member.id}`, data);
      setStaff((current) =>
        current.map((item) =>
          item.id === member.id ? response.data.data : item,
        ),
      );
      if (isAdmin) await loadStaffLogs();
      showNotice("CRM account updated.", "success");
    } catch (error) {
      showNotice(
        error.response?.data?.message || "Could not update CRM account.",
        "error",
      );
    }
  };
  const deleteStaff = async (member) => {
    if (!window.confirm(`Delete ${member.name}'s CRM account?`)) return;
    try {
      await api.delete(`/crm/members/${member.id}`);
      setStaff((current) => current.filter((item) => item.id !== member.id));
      if (isAdmin) await loadStaffLogs();
      showNotice("CRM account deleted.", "success");
    } catch (error) {
      showNotice(
        error.response?.data?.message || "Could not delete CRM account.",
        "error",
      );
    }
  };
  const addStaff = async (event) => {
    event.preventDefault();
    try {
      const response = await api.post("/crm/members", {
        ...memberForm,
        farm_id: Number(farmId),
      });
      setStaff((current) => [...current, response.data.data]);
      if (isAdmin) await loadStaffLogs();
      setMemberForm({ name: "", email: "", password: "", crm_role: "finance" });
      showNotice("CRM account added.", "success");
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not add CRM account.", "error");
    }
  };
  const policyPayload = (policy) => ({
    farm_id: Number(farmId),
    title: policy.title.trim(),
    category: policy.category || "All staff",
    audience: policy.audience,
    status: policy.status || "active",
    effective_date: policy.effectiveDate,
    summary: policy.summary.trim(),
    details: (policy.details || "").trim(),
    notes: (policy.notes || "").trim(),
    visible_pages: policy.visiblePages?.length ? policy.visiblePages : buildDefaultPolicyPages(policy.audience),
  });
  const createPolicy = async (event) => {
    event.preventDefault();
    if (!isAdmin) return showNotice("Only CRM admins can manage staff policies.", "error");
    if (!farmId) return showNotice("Your account is not linked to a farm.", "error");
    const payload = policyPayload(policyForm);
    try {
      if (editingPolicyId) {
        const response = await api.put(`/crm/policies/${editingPolicyId}`, payload);
        setPolicies((current) => current.map((item) => item.id === response.data.data.id ? response.data.data : item));
        if (isAdmin) await loadStaffLogs();
        showNotice("Staff policy updated.", "success");
      } else {
        const response = await api.post("/crm/policies", payload);
        setPolicies((current) => [response.data.data, ...current]);
        if (isAdmin) await loadStaffLogs();
        showNotice("Staff policy published.", "success");
      }
      setEditingPolicyId(null);
      setActiveView("policy-existing");
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not save staff policy.", "error");
      return;
    }
    setPolicyForm({
      title: "",
      audience: "all",
      category: "All staff",
      status: "active",
      effectiveDate: "",
      summary: "",
      details: "",
      notes: "",
      visiblePages: buildDefaultPolicyPages("all"),
    });
  };
  const archivePolicy = async (policy) => {
    if (!isAdmin) return showNotice("Only CRM admins can manage staff policies.", "error");
    try {
      const response = await api.put(`/crm/policies/${policy.id}`, { ...policyPayload(policy), status: "archived" });
      setPolicies((current) => current.map((item) => item.id === policy.id ? response.data.data : item));
      if (isAdmin) await loadStaffLogs();
      showNotice(`${policy.title} archived.`, "success");
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not archive this policy.", "error");
    }
  };
  const editPolicy = (policy) => {
    if (!isAdmin) return showNotice("Only CRM admins can edit staff policies.", "error");
    setEditingPolicyId(policy.id);
    setPolicyForm({
      title: policy.title,
      audience: policy.audience,
      category: policy.category || "All staff",
      status: policy.status || "active",
      effectiveDate: policy.effectiveDate,
      summary: policy.summary,
      details: policy.details || policy.summary,
      notes: policy.notes || "",
      visiblePages: policy.visiblePages || buildDefaultPolicyPages(policy.audience),
    });
    setActiveView("policy-new");
    showNotice(`Editing ${policy.title}.`, "info");
  };
  const cancelPolicyEdit = () => {
    setEditingPolicyId(null);
    setPolicyForm({ title: "", audience: "all", category: "All staff", status: "active", effectiveDate: "", summary: "", details: "", notes: "", visiblePages: buildDefaultPolicyPages("all") });
    setActiveView("policy-existing");
  };
  const sendNotification = async (event) => {
    event.preventDefault();
    if (!canNotify || !notification.message.trim()) return;
    const targetFarmId = notification.farm_id || farmId;
    const targetMembers = isGlobalAdmin
      ? globalFarms.find((farm) => String(farm.id) === String(targetFarmId))?.members || []
      : farmMembers;
    if (!targetFarmId) return showNotice("Select a farm before sending.", "error");
    const allRegisteredRecipients = [...new Map(globalFarms.flatMap((farm) =>
      (farm.members || [])
        .filter((member) => member.role === "farmOwner" || (["farmManager", "farmWorker"].includes(member.role) && !member.crm_role))
        .map((member) => [String(member.id), member]),
    ))].map(([, member]) => member);
    const broadcastRecipients = (notification.audience_scope === "all_registered" && isGlobalAdmin
      ? allRegisteredRecipients
      : targetMembers).filter((member) =>
      String(member.id) !== String(profile?.id) && (member.role === "farmOwner" || (["farmManager", "farmWorker"].includes(member.role) && !member.crm_role)),
    );
    const recipient = targetMembers.find((member) => String(member.id) === String(notification.recipient_id));
    const audienceText = recipient
      ? `${recipient.name} only`
      : notification.audience_scope === "all_registered" && isGlobalAdmin
        ? `${broadcastRecipients.length} registered app users across all farms`
        : `${broadcastRecipients.length} farm members`;
    if (!window.confirm(`Send this notification to ${audienceText}?`)) return;
    try {
      await api.post("/crm/notifications", {
        farm_id: Number(targetFarmId),
        kind: "broadcast",
        message: notification.message.trim(),
        ...(notification.title.trim() ? { title: notification.title.trim() } : {}),
        ...(notification.recipient_id
          ? { recipient_id: Number(notification.recipient_id) }
          : {}),
        ...(notification.audience_scope === "all_registered" && isGlobalAdmin
          ? { audience_scope: "all_registered" }
          : {}),
      });
      setNotification((current) => ({ message: "", title: "", recipient_id: "", farm_id: current.farm_id, audience_scope: "farm" }));
      await loadCrmMessages();
      showNotice("Notification sent.", "success");
    } catch (error) {
      showNotice(
        error.response?.data?.message || "Could not send notification.",
        "error",
      );
    }
  };
  const useNotificationTemplate = (template) => {
    setNotification((current) => ({
      ...current,
      title: template.title,
      message: template.message,
      recipient_id: "",
      farm_id: current.farm_id || String(globalFarms[0]?.id || farmId || ""),
      audience_scope: "farm",
    }));
    setActiveSection("communication");
    setActiveView("communication-broadcast");
  };
  const savePlan = async (event) => {
    event.preventDefault();
    try {
      const response = await api.post("/subscription-plans", {
        ...planForm,
        amount: Number(planForm.amount),
        pig_limit: planForm.pig_limit ? Number(planForm.pig_limit) : null,
      });
      setPlans((current) => [...current, response.data.data]);
      setPlanForm({ code: "", name: "", description: "", amount: "", currency: "USD", pig_limit: "", active: true });
      showNotice("Subscription plan created.", "success");
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not create subscription plan.", "error");
    }
  };
  const togglePlan = async (plan) => {
    try {
      const response = await api.patch(`/subscription-plans/${plan.id}`, { active: !plan.active });
      setPlans((current) => current.map((item) => item.id === plan.id ? response.data.data : item));
      showNotice(plan.active ? "Plan retired." : "Plan activated.", "success");
    } catch (error) {
      showNotice(error.response?.data?.message || "Could not update subscription plan.", "error");
    }
  };
  useEffect(() => {
    if (auth.token) {
      loadGlobalFarms();
      loadStaff();
      loadStaffCategories();
      loadPolicies();
      loadStaffLogs();
      loadDashboard();
      loadDirectory();
      loadSettingsData();
      loadReport();
      loadFarmFinanceLedger();
      loadGlobalTasks();
      loadFarmTasks();
    }
  }, [auth.token, farmId, canReadCommunication, isGlobalAdmin]);

  useEffect(() => {
    if (!auth.token || !canReadCommunication) return;
    loadCrmMessages();
  }, [auth.token, farmId, canReadCommunication, isGlobalAdmin, globalFarms.length, notification.farm_id]);

  useEffect(() => {
    if (!auth.token || !canReadCommunication || activeSection !== "communication" || activeView !== "communication-inbox") return undefined;
    const timer = window.setInterval(loadCrmMessages, 15 * 1000);
    return () => window.clearInterval(timer);
  }, [auth.token, canReadCommunication, activeSection, activeView, farmId, isGlobalAdmin, globalFarms.length, notification.farm_id]);

  useEffect(() => {
    if (!auth.token || !farmId || !canReply || isGlobalAdmin || !supportAvailable) return undefined;
    let active = true;
    const heartbeat = async () => {
      try {
        await api.post("/crm/support-presence", {
          farm_id: Number(farmId),
          online: true,
        });
      } catch (error) {
        if (!active) return;
        setSupportAvailable(false);
        showNotice(error.response?.data?.message || "Your live-chat availability could not be renewed.", "error");
      }
    };
    const timer = window.setInterval(heartbeat, 40 * 1000);
    return () => {
      active = false;
      window.clearInterval(timer);
      api.post("/crm/support-presence", {
        farm_id: Number(farmId),
        online: false,
      }).catch((error) => console.error("Could not mark CRM support presence offline.", error));
    };
  }, [auth.token, farmId, canReply, isGlobalAdmin, supportAvailable]);

  useEffect(() => {
    if (activeSection !== "tasks") return undefined;
    const timer = window.setTimeout(() => {
      loadGlobalTasks();
      loadFarmTasks();
    }, 250);
    return () => window.clearTimeout(timer);
  }, [activeSection, farmId, taskFilters.search, taskFilters.status, taskFilters.priority, taskFilters.assigned_to, taskFilters.overdue]);

  useEffect(() => {
    if (!auth.token || !farmId) return undefined;
    const refreshData = () => {
      loadCustomers();
      loadDashboard();
      loadStaff();
      loadStaffCategories();
      loadPolicies();
      loadStaffLogs();
      loadGlobalTasks();
      loadFarmTasks();
      loadCrmMessages();
      loadDirectory();
      loadSettingsData();
      loadReport();
      loadFarmFinanceLedger();
      loadPlans();
      if (activeView.startsWith("orders-")) {
        loadOrders(activeView.replace("orders-", ""));
      }
    };
    const interval = window.setInterval(refreshData, 5 * 60 * 1000);
    const refreshOnFocus = () => {
      if (document.visibilityState === "visible") refreshData();
    };
    document.addEventListener("visibilitychange", refreshOnFocus);
    window.addEventListener("focus", refreshData);
    return () => {
      window.clearInterval(interval);
      document.removeEventListener("visibilitychange", refreshOnFocus);
      window.removeEventListener("focus", refreshData);
    };
  }, [auth.token, farmId, activeView, canReadCommunication]);

  useEffect(() => {
    if (!auth.token || !activeView.startsWith("orders-")) return;
    loadOrders(activeView.replace("orders-", ""));
  }, [auth.token, activeView]);

  if (showSplash) {
    return <SplashScreen />;
  }

  if (!auth.token)
    return (
      <Login auth={auth} setAuth={setAuth} onSubmit={login} onVerifyOtp={verifyLoginOtp} onResendOtp={resendLoginOtp} onForgotPassword={requestPasswordReset} notice={notice} />
    );
  return (
    <div className={`app-shell ${activeSection === "home" ? "home-shell" : ""}`}>
      {activeSection !== "home" && <aside className="sidebar">
        <div className="brand-block">
          <span className="crm-mark" aria-hidden="true">CRM</span>
          <div>
            <strong>CRM</strong>
            <span>Customer desk</span>
          </div>
        </div>
        {activeSection === "customers" && (
          <CustomerSidebar
            activeView={activeView}
            setActiveView={setActiveView}
            customerGroups={customerGroups}
            setCustomerGroups={setCustomerGroups}
            isGlobalAdmin={isGlobalAdmin}
          />
        )}
        {activeSection === "staff" && <StaffSidebar activeView={activeView} setActiveView={setActiveView} groups={staffGroups} setGroups={setStaffGroups} categories={staffCategories} isAdmin={isAdmin} />}
        {activeSection === "finance" && <FinanceSidebar activeView={activeView} setActiveView={setActiveView} />}
        {activeSection === "communication" && <CommunicationSidebar activeView={activeView} setActiveView={setActiveView} />}
        {activeSection === "settings" && <SettingsSidebar activeView={activeView} setActiveView={setActiveView} isAdmin={isAdmin} />}
        {activeSection === "operations" && <FarmOperationsSidebar activeView={activeView} setActiveView={setActiveView} ordersExpanded={operationsOrdersExpanded} setOrdersExpanded={setOperationsOrdersExpanded} />}
        {activeSection === "market" && <MarketSidebar activeView={activeView} setActiveView={setActiveView} />}
        <div className="sidebar-footer">
          {profileAvatar ? <img className="profile-avatar-image" src={profileAvatar} alt={`${profile?.name || "User"} profile`} /> : <span className="profile-avatar-fallback">{(profile?.name || auth.email || "U").slice(0, 1).toUpperCase()}</span>}
          <div>
            <strong>{profile?.name || auth.email || "CRM user"}</strong>
            <small>{settingsFarm?.name || "Farm operations"}</small>
          </div>
        </div>
      </aside>}
      <main className="main-panel">
        <AdminNavbar activeSection={activeSection} selectSection={selectSection} />
        <header className="topbar">
          <div>
            <div className="eyebrow">{isAdmin ? "Admin workspace" : `${crmRole.replace("_", " ")} workspace`}</div>
            <h1>
              {activeSection === "home"
                ? "Home"
                : activeSection === "operations"
                  ? activeView === "operations-farms"
                    ? "Farms"
                    : activeView === "operations-feed-orders"
                      ? "Feed orders"
                      : activeView === "operations-medicine-orders"
                        ? "Medicine orders"
                        : activeView === "operations-emergencies"
                          ? "Emergencies"
                          : activeView === "operations-records"
                            ? "Farm records"
                            : activeView === "operations-herd"
                              ? "Farm herd"
                            : "Farm operations"
                : activeSection === "market"
                  ? activeView === "market-sold-pigs"
                    ? "Sold Pigs"
                    : "Posted Pigs"
                : activeSection === "staff"
                  ? activeView === "staff-finance"
                    ? "Finance staff"
                    : activeView === "staff-support"
                      ? "Customer service staff"
                      : activeView === "policy-new"
                        ? "New staff policy"
                        : activeView === "policy-existing"
                          ? "Existing staff policies"
                          : activeView === "staff-logs"
                            ? "Staff logs"
                            : "Staff"
                  : activeSection === "tasks"
                    ? "Tasks and follow-ups"
                  : activeSection === "settings"
                    ? activeView === "settings-security"
                      ? "Password and security"
                      : activeView === "settings-farm"
                        ? "Farm workspace"
                        : activeView === "settings-name-approvals"
                          ? "Farm name approvals"
                        : activeView === "settings-members"
                          ? "Members and permissions"
                          : activeView === "settings-notifications"
                            ? "Notifications"
                            : "My profile"
                    : activeSection === "finance"
                      ? activeView === "finance-ledger"
                        ? "Farm income & expenses"
                        : activeView === "finance-subscriptions"
                          ? "Farm subscriptions"
                          : activeView === "finance-payments"
                            ? "Payment activity"
                            : activeView === "finance-plans"
                              ? "Subscription plans"
                              : activeView === "finance-reporting"
                                ? "Revenue reporting"
                                : "Finance overview"
                : activeSection === "communication"
                  ? activeView === "communication-broadcast"
                    ? "Broadcast"
                    : activeView === "communication-activity"
                      ? "Customer activity"
                      : activeView === "communication-templates"
                        ? "Communication templates"
                        : "Communication inbox"
                  : activeView === "farm-owner-prospects"
                    ? "Farm-owner prospects"
                    : activeView === "registered-buyers"
                      ? "Registered buyers"
                    : "Customers"}
            </h1>
          </div>
          <div className="top-actions">
            {activeSection === "operations" && activeView === "operations-records" && availableFarms.length > 1 && (
              <label className="farm-context-picker">
                <span>Farm</span>
                <select
                  aria-label="Current farm"
                  value={farmId}
                  onChange={(event) => changeFarm(event.target.value)}
                >
                  {availableFarms.map((farm) => (
                    <option key={farm.id} value={String(farm.id)}>{farm.name}</option>
                  ))}
                </select>
              </label>
            )}
            {activeSection === "communication" && activeView === "communication-inbox" && canReply && !isGlobalAdmin && (
              <div className="support-presence-control">
                <span aria-live="polite">
                  {supportAvailable ? `Online · ${supportOnlineAgents.length} agent${supportOnlineAgents.length === 1 ? "" : "s"}` : "Offline"}
                </span>
                <button
                  className={supportAvailable ? "ghost-button" : "primary-button"}
                  type="button"
                  disabled={supportPresenceSaving || !farmId}
                  onClick={() => updateSupportAvailability(!supportAvailable)}
                >
                  {supportPresenceSaving ? "Updating…" : supportAvailable ? "Go offline" : "Go online"}
                </button>
              </div>
            )}
            {activeSection !== "home" && <button className="ghost-button" type="button" onClick={refreshCurrentView}>
              ↻ Refresh {activeSection}
            </button>}
            {activeSection === "customers" && activeView === "customers" && canWriteCustomers && <button
              className="primary-button"
              onClick={() => {
                setEditing(false);
                setForm(emptyCustomer);
                window.scrollTo({ top: 0, behavior: "smooth" });
              }}
            >
              ＋ Add customer
            </button>}
          </div>
        </header>
        {notice && (
          <div className={`notice ${notice.tone}`}>{notice.message}</div>
        )}
        {activeSection === "home" && <HomeDashboard dashboard={dashboard} loading={dashboardLoading} error={dashboardError} onRefresh={loadDashboard} onOpen={selectSection} onOpenStatus={(status) => { setFilters((current) => ({ ...current, search: "", status, page: 1 })); selectSection("customers"); }} directory={directory} directoryLoading={directoryLoading} directoryError={directoryError} onDirectoryRefresh={loadDirectory} onOpenDirectory={(view) => { setActiveSection("customers"); setActiveView(view); }} />}
        {activeSection === "operations" && activeView === "operations-records" && <FarmOperationsWorkspace key={farmId} farmId={farmId} canView={canViewOperations} managePermissions={farmOperationPermissions} refreshKey={operationsRefreshKey} />}
        {activeSection === "operations" && activeView === "operations-herd" && <FarmHerdWorkspace canView={canViewOperations} />}
        {activeSection === "operations" && !["operations-records", "operations-herd"].includes(activeView) && <CrmFarmOperations key={farmId} view={activeView} farms={availableFarms} isGlobalAdmin={isGlobalAdmin} refreshKey={operationsRefreshKey} onRefresh={() => setOperationsRefreshKey((key) => key + 1)} />}
        {activeSection === "market" && <MarketListings key={activeView} view={activeView} refreshKey={marketRefreshKey} onRefresh={() => setMarketRefreshKey((key) => key + 1)} />}
        {activeSection === "tasks" && <div className="tasks-workspace"><FarmOperationsTasks key={farmId} tasks={farmTasks} members={farmMembers} loading={farmTasksLoading} error={farmTasksError} canManage={canManageFarmTasks} currentUserId={profile?.id} onRefresh={loadFarmTasks} onCreate={saveFarmTask} onToggle={updateFarmTaskStatus} onDelete={deleteFarmTask} /><TasksWorkspace tasks={globalTasks} staff={staff} loading={globalTasksLoading} error={globalTasksError} filters={taskFilters} setFilters={setTaskFilters} onRefresh={loadGlobalTasks} onToggle={updateGlobalTaskStatus} /></div>}
        {activeSection === "customers" && ["farm-owners", "farm-managers", "farm-workers", "relationships"].includes(activeView) && <DirectoryView view={activeView} directory={directory} loading={directoryLoading} error={directoryError} onRefresh={loadDirectory} />}
        {activeSection === "customers" && activeView === "registered-buyers" && <RegisteredBuyers refreshKey={buyersRefreshKey} />}
        {activeSection === "customers" && activeView === "farm-owner-prospects" && isGlobalAdmin && <FarmOwnerProspects />}
        {activeSection === "customers" && activeView.startsWith("orders-") && <OrdersView status={activeView.replace("orders-", "")} orders={orders} loading={ordersLoading} error={ordersError} onRefresh={() => loadOrders(activeView.replace("orders-", ""))} />}
        {activeSection === "communication" && <CommunicationWorkspace view={activeView} conversations={supportConversations} selectedConversation={activeSupportConversation} onSelectConversation={openSupportConversation} onReply={sendSupportReply} onUpdateConversation={updateSupportConversation} farmMembers={farmMembers} globalFarms={globalFarms} isGlobalAdmin={isGlobalAdmin} farmId={farmId} currentUserId={profile?.id} history={broadcastHistory} notification={notification} setNotification={setNotification} onSubmit={sendNotification} onUseTemplate={useNotificationTemplate} selected={selected} interactions={interactions} canNotify={canNotify} canReply={canReply} canRead={canReadCommunication} onlineAgents={supportOnlineAgents} />}
        {activeSection === "staff" && <StaffWorkspace view={activeView} members={staff} dashboard={dashboard} categories={staffCategories} policies={policies} policiesLoading={policiesLoading} policyForm={policyForm} setPolicyForm={setPolicyForm} onCreatePolicy={createPolicy} onArchivePolicy={archivePolicy} onEditPolicy={editPolicy} onCancelPolicyEdit={cancelPolicyEdit} editingPolicy={Boolean(editingPolicyId)} logs={staffLogs} onUpdate={updateStaff} onDelete={deleteStaff} isAdmin={isAdmin} memberForm={memberForm} setMemberForm={setMemberForm} onAdd={addStaff} onAddCategory={addStaffCategory} onDeleteCategory={deleteStaffCategory} />}
        {activeSection === "settings" && <SettingsWorkspace view={activeView} user={profile} profileForm={profileForm} setProfileForm={setProfileForm} onSaveProfile={saveProfileSettings} onAvatarChange={updateProfileAvatar} profileAvatar={profileAvatar} onLogout={logout} passwordForm={passwordForm} setPasswordForm={setPasswordForm} onChangePassword={changePassword} farm={settingsFarm} farmName={farmName} setFarmName={setFarmName} onSaveFarm={saveFarmSettings} canEditFarm={Boolean(settingsFarm)} members={farmMembers} canManageMembers={isAdmin || profile?.role === "farmOwner"} memberPermissions={memberPermissions} setMemberPermissions={setMemberPermissions} onSaveMember={saveMemberPermissions} notifications={farmNotifications} onRefreshNotifications={loadFarmNotifications} onReadNotification={markFarmNotificationRead} />}
        {activeSection === "finance" && activeView === "finance-ledger" && (
          <FarmFinanceLedger
            ledger={farmFinanceLedger}
            loading={farmFinanceLoading}
            onRefresh={loadFarmFinanceLedger}
            onCreate={createFarmFinanceTransaction}
          />
        )}
        {activeSection === "finance" && activeView !== "finance-ledger" && (
          <FinanceWorkspace
            view={activeView}
            customers={customers}
            counts={counts}
            report={report}
            calculator={calculator}
            setCalculator={setCalculator}
            projectedRevenue={projectedRevenue}
            plans={plans}
            planForm={planForm}
            setPlanForm={setPlanForm}
            savePlan={savePlan}
            togglePlan={togglePlan}
            canManagePlans={isAdmin || crmRole === "finance"}
            statuses={statuses}
          />
        )}
        {activeSection === "customers" && activeView === "pipeline" && (
          <PipelineBoard customers={customers} onSelect={setSelectedId} onMove={updateCustomerStatus} statuses={statuses} />
        )}
        {activeSection === "customers" && activeView === "segments" && (
          <section className="panel-card crm-tools">
            <div className="panel-heading">
              <div>
                <div className="eyebrow">Classification</div>
                <h2>Customer segments</h2>
              </div>
              <span>{customers.length} records</span>
            </div>
            <div className="segment-grid">
              {segmentDefinitions.map((segment) => (
                <button
                  key={segment.id}
                  type="button"
                  className="segment-card"
                  onClick={() => {
                    setFilters((current) => ({ ...current, search: "", status: "all", page: 1 }));
                    setActiveView("customers");
                    setSelectedId(segmentSummary[segment.id][0]?.id || null);
                  }}
                >
                  <div className="segment-header">
                    <strong>{segment.label}</strong>
                    <span>{segmentSummary[segment.id].length}</span>
                  </div>
                  <p>{segment.description}</p>
                </button>
              ))}
            </div>
          </section>
        )}
        {activeSection === "customers" && activeView === "import" && (
          <section className="panel-card crm-tools">
            <div className="panel-heading">
              <div>
                <div className="eyebrow">Bulk import</div>
                <h2>Import customers from CSV</h2>
              </div>
              <span>Use headers: name, email, phone, company, address, type, status</span>
            </div>
            <form className="import-form" onSubmit={importCustomersFromCsv}>
              <textarea
                value={importText}
                onChange={(event) => setImportText(event.target.value)}
                placeholder="name,email,phone,company,address,type,status\nAmara Foods,amara@farm.com,+254700000001,Amara Foods,Nakuru,buyer,qualified"
                rows="10"
              />
              <div className="form-actions">
                <button className="ghost-button" type="button" onClick={() => setImportText("")}>Clear</button>
                <button className="primary-button" type="submit" disabled={importingCustomers}>{importingCustomers ? "Importing…" : "Import records"}</button>
              </div>
            </form>
          </section>
        )}
        {activeSection === "customers" && activeView === "customers" && <section className="stats-row">
          <div>
            <span>Total relationships</span>
            <strong>{customers.length}</strong>
          </div>
          <div>
            <span>Qualified leads</span>
            <strong>{counts.qualified || 0}</strong>
          </div>
          <div>
            <span>Won this cycle</span>
            <strong>{counts.won || 0}</strong>
          </div>
          <div className="accent-stat">
            <span>Conversion focus</span>
            <strong>
              {customers.length
                ? `${Math.round(((counts.won || 0) / customers.length) * 100)}%`
                : "0%"}
            </strong>
          </div>
        </section>}
        {activeSection === "customers" && activeView === "customers" && <section className={`workspace-grid ${customerListMaximized ? "customer-list-maximized" : ""}`}>
          <div className="list-panel panel-card customer-list-panel">
            <div className="panel-heading">
              <div>
                <h2>Customer list</h2>
                <span>{customerMeta.total} records in view</span>
              </div>
              <div className="customer-list-actions"><div className="customer-view-toggle" role="group" aria-label="Customer list view"><button className={customerViewMode === "table" ? "selected" : ""} type="button" onClick={() => { setCustomerViewMode("table"); localStorage.setItem("farmapp_crm_customer_view", "table"); }}>Table</button><button className={customerViewMode === "cards" ? "selected" : ""} type="button" onClick={() => { setCustomerViewMode("cards"); localStorage.setItem("farmapp_crm_customer_view", "cards"); }}>Cards</button></div><button className="filter-button" type="button" onClick={() => setCustomerListMaximized((current) => !current)}>{customerListMaximized ? "↙ Restore" : "↗ Maximize"}</button><button className="filter-button" type="button" onClick={() => setFilters((current) => ({ ...current, search: "", status: "all", type: "all", assigned_to: "all", page: 1 }))}>Clear filters</button></div>
            </div>
            <label className="search-field" htmlFor="customer-search">
              <span>⌕</span>
              <input
                id="customer-search"
                aria-label="Search customers"
                value={filters.search}
                onChange={(event) =>
                  setFilters((current) => ({
                    ...current,
                    search: event.target.value,
                  }))
                }
                placeholder="Search name, company, or email"
              />
            </label>
            <div className="filter-tabs">
              {statuses.map((status) => (
                <button
                  key={status}
                  className={filters.status === status ? "selected" : ""}
                  onClick={() =>
                    setFilters((current) => ({ ...current, status }))
                  }
                >
                  {status === "all" ? "All" : status}
                </button>
              ))}
            </div>
            <div className="customer-filter-bar">
              <select aria-label="Filter by customer type" value={filters.type} onChange={(event) => setFilters((current) => ({ ...current, type: event.target.value, page: 1 }))}><option value="all">All types</option><option value="lead">Leads</option><option value="buyer">Buyers</option><option value="supplier">Suppliers</option></select>
              <select aria-label="Filter by assigned staff" value={filters.assigned_to} onChange={(event) => setFilters((current) => ({ ...current, assigned_to: event.target.value, page: 1 }))}><option value="all">All staff</option>{staff.map((member) => <option key={member.id} value={member.id}>{member.name}</option>)}</select>
              <select aria-label="Sort customers" value={`${filters.sort_by}:${filters.sort_direction}`} onChange={(event) => { const [sort_by, sort_direction] = event.target.value.split(":"); setFilters((current) => ({ ...current, sort_by, sort_direction, page: 1 })); }}><option value="latest:desc">Recently added</option><option value="name:asc">Name A-Z</option><option value="name:desc">Name Z-A</option><option value="status:asc">Status</option><option value="updated_at:desc">Recently updated</option></select>
            </div>
            <div className={`customer-list ${customerViewMode === "cards" ? "cards-view" : "table-view"}`}>
              {loading ? (
                <div className="state-message">Loading customers…</div>
              ) : customers.length === 0 ? (
                <div className="state-message">
                  No customers match these filters.
                </div>
              ) : (
                customers.map((customer) => (
                  <button
                    key={customer.id}
                    className={`customer-row ${selectedId === customer.id ? "selected" : ""}`}
                    onClick={() => setSelectedId(customer.id)}
                  >
                    <span className="customer-avatar">
                      {customer.name.slice(0, 1).toUpperCase()}
                    </span>
                    <span className="customer-row-copy">
                      <strong>{customer.name}</strong>
                      <small>
                        {customer.farm_name || customer.company ||
                          customer.email ||
                          "No company details"}
                      </small>
                    </span>
                    <span className="customer-row-meta">
                      <small>{customer.email || "No email"}</small>
                      <small>{customer.phone || "No phone"}</small>
                      <small>{customer.type || "contact"}</small>
                      <small>{customer.assignee?.name || "Unassigned"}</small>
                      <small>{customer.open_tasks_count || 0} open tasks</small>
                    </span>
                    <span className={`status-label ${customer.status}`}>
                      {customer.status}
                    </span>
                    <span className="row-arrow">›</span>
                  </button>
                ))
              )}
            </div>
            {customerMeta.last_page > 1 && <div className="customer-pagination"><button className="filter-button" type="button" disabled={customerMeta.current_page <= 1} onClick={() => setFilters((current) => ({ ...current, page: current.page - 1 }))}>Previous</button><span>Page {customerMeta.current_page} of {customerMeta.last_page}</span><button className="filter-button" type="button" disabled={customerMeta.current_page >= customerMeta.last_page} onClick={() => setFilters((current) => ({ ...current, page: current.page + 1 }))}>Next</button></div>}
          </div>
          <div className="detail-column">
            {editing ? (
              <CustomerForm
                form={form}
                updateForm={updateForm}
                staff={staff}
                statuses={statuses}
                onSubmit={saveCustomer}
                onCancel={() => setEditing(false)}
                saving={saving}
              />
            ) : selected ? (
              <>
                <section className="detail-card panel-card">
                  <div className="detail-header">
                    <div className="profile-heading">
                      <span className="profile-avatar">
                        {selected.name.slice(0, 1).toUpperCase()}
                      </span>
                      <div>
                        <div className="eyebrow">
                          {selected.type} relationship
                        </div>
                        <h2>{selected.name}</h2>
                        <span>{selected.company || "Independent contact"}</span>
                      </div>
                    </div>
                    <div className="detail-actions">
                      {canWriteCustomers && <button className="ghost-button" onClick={startEditing}>Edit</button>}
                      {isAdmin && <button className="danger-button" onClick={deleteCustomer}>Delete</button>}
                    </div>
                  </div>
                  <div className="company-overview-grid">
                    <div className="company-overview-item">
                      <span>Business profile</span>
                      <strong>{selected.company || "Independent contact"}</strong>
                    </div>
                    <div className="company-overview-item">
                      <span>Type</span>
                      <strong>{selected.type}</strong>
                    </div>
                    <div className="company-overview-item">
                      <span>Last touch</span>
                      <strong>{lastInteraction ? new Date(lastInteraction.occurred_at).toLocaleDateString() : "No activity yet"}</strong>
                    </div>
                    <div className="company-overview-item">
                      <span>Next action</span>
                      <strong>{leadNextAction}</strong>
                    </div>
                  </div>
                  <div className="company-overview-grid">
                    <div className="company-overview-item">
                      <span>Business profile</span>
                      <strong>{selected.company || "Independent contact"}</strong>
                    </div>
                    <div className="company-overview-item">
                      <span>Type</span>
                      <strong>{selected.type}</strong>
                    </div>
                    <div className="company-overview-item">
                      <span>Last touch</span>
                      <strong>{lastInteraction ? new Date(lastInteraction.occurred_at).toLocaleDateString() : "No activity yet"}</strong>
                    </div>
                    <div className="company-overview-item">
                      <span>Next action</span>
                      <strong>{leadNextAction}</strong>
                    </div>
                  </div>
                  <div className="contact-grid">
                    <ContactItem label="Email" value={selected.email} />
                    <ContactItem label="Phone" value={selected.phone} />
                    <ContactItem label="Address" value={selected.address} />
                    <ContactItem
                      label="Status"
                      value={selected.status}
                      accent
                    />
                  </div>
                  <div className="lead-journey">
                    <div>
                      <span>Lead lifecycle</span>
                      <strong>{selected.status}</strong>
                    </div>
                    <div className="status-action-row">
                      {statuses.slice(1).map((status) => (
                        <button
                          key={status}
                          type="button"
                          className={selected.status === status ? "status-pill active" : "status-pill"}
                          onClick={() => updateCustomerStatus(status)}
                          disabled={selected.status === status}
                        >
                          {status}
                        </button>
                      ))}
                    </div>
                  </div>
                  <div className="next-step-card">
                    <span>Suggested next step</span>
                    <p>{leadNextAction}</p>
                  </div>
                  {selected.notes && (
                    <div className="notes">
                      <span>Notes</span>
                      <p>{selected.notes}</p>
                    </div>
                  )}
                </section>
                <TaskPanel
                  tasks={tasks}
                  taskForm={taskForm}
                  setTaskForm={setTaskForm}
                  staff={staff}
                  onSubmit={saveTask}
                  onToggle={updateTaskStatus}
                />
                <section className="activity-card panel-card">
                  <div className="panel-heading">
                    <div>
                      <h2>Activity timeline</h2>
                      <span>Keep every conversation in context</span>
                    </div>
                    <span className="activity-count">
                      {timeline.length} events
                    </span>
                  </div>
                  {canReply && <form
                    className="interaction-composer"
                    onSubmit={addInteraction}
                  >
                    <select
                      value={interaction.type}
                      onChange={(event) =>
                        setInteraction((current) => ({
                          ...current,
                          type: event.target.value,
                        }))
                      }
                    >
                      {interactionTypes.map((type) => (
                        <option key={type} value={type}>
                          {type[0].toUpperCase() + type.slice(1)}
                        </option>
                      ))}
                    </select>
                    <input
                      value={interaction.notes}
                      onChange={(event) =>
                        setInteraction((current) => ({
                          ...current,
                          notes: event.target.value,
                        }))
                      }
                      placeholder={canReply ? "Write a reply to this customer…" : "Customer activity is read-only"}
                      disabled={!canReply}
                    />
                    <button className="primary-button" type="submit">
                      {canReply ? "Send reply" : "Read only"}
                    </button>
                  </form>}
                  <div className="timeline">
                    {timeline.length === 0 ? (
                      <div className="state-message">
                        No activity recorded yet.
                      </div>
                    ) : (
                      timeline.map((item) => (
                        <div className="timeline-item" key={item.id}>
                          <span className="timeline-icon">
                            {item.subtype === "call"
                              ? "⌕"
                              : item.subtype === "email"
                                ? "@"
                                : "✦"}
                          </span>
                          <div>
                            <strong>
                              {(item.subtype || item.type).replaceAll("_", " ").replace(/\b\w/g, (letter) => letter.toUpperCase())}
                            </strong>
                            <span>{item.notes || item.data?.title || item.data?.to || "No notes added"}</span>
                          </div>
                          <time>
                            {new Date(item.occurred_at).toLocaleDateString()}
                          </time>
                        </div>
                      ))
                    )}
                  </div>
                </section>
              </>
            ) : (
              <div className="empty-detail panel-card">
                <span>◈</span>
                <h2>Choose a relationship</h2>
                <p>
                  Select a customer from the list to see their details and
                  activity.
                </p>
              </div>
            )}
          </div>
        </section>}
      </main>
    </div>
  );
}

function ContactItem({ label, value, accent }) {
  return (
    <div className="contact-item">
      <span>{label}</span>
      <strong className={accent ? `status-label ${value}` : ""}>
        {value || "Not provided"}
      </strong>
    </div>
  );
}
export default App;

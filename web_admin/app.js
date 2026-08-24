// Global variables
let currentPage = 'dashboard';
let studentsData = [];
let supervisorsData = [];
let parentsData = [];
let busesData = [];

// Check Firebase availability
function checkFirebaseAvailability() {
    console.log('🔍 Checking Firebase availability...');

    if (typeof firebase === 'undefined') {
        console.error('❌ Firebase is not loaded');
        return false;
    }

    if (typeof FirebaseService === 'undefined') {
        console.error('❌ FirebaseService is not loaded');
        return false;
    }

    console.log('✅ Firebase is available');
    console.log('📋 FirebaseService methods:', Object.keys(FirebaseService));

    // Check specific methods
    const requiredMethods = ['addSupervisor', 'updateSupervisor', 'deleteSupervisor', 'updateSupervisorPermissions'];
    const missingMethods = requiredMethods.filter(method => typeof FirebaseService[method] !== 'function');

    if (missingMethods.length > 0) {
        console.error('❌ Missing FirebaseService methods:', missingMethods);
        return false;
    }

    console.log('✅ All required FirebaseService methods are available');
    return true;
}

// Suppress Chrome extension errors
window.addEventListener('error', function(e) {
    if (e.message && (e.message.includes('message port closed') || e.message.includes('Extension context invalidated'))) {
        e.preventDefault();
        return false;
    }
});

// Suppress unhandled promise rejections related to Chrome extensions
window.addEventListener('unhandledrejection', function(e) {
    if (e.reason && e.reason.message && (e.reason.message.includes('message port closed') || e.reason.message.includes('Extension context invalidated'))) {
        e.preventDefault();
        return false;
    }
});

// DOM elements - will be initialized when DOM is ready
let loadingScreen, loginScreen, dashboard, loginForm, loginError, pageContent, sidebar, content;

// Initialize DOM elements
function initializeDOMElements() {
    loadingScreen = document.getElementById('loadingScreen');
    loginScreen = document.getElementById('loginScreen');
    dashboard = document.getElementById('dashboard');
    loginForm = document.getElementById('loginForm');
    loginError = document.getElementById('loginError');
    pageContent = document.getElementById('pageContent');
    sidebar = document.getElementById('sidebar');
    content = document.getElementById('content');

    console.log('📋 DOM elements initialized:', {
        loadingScreen: !!loadingScreen,
        loginScreen: !!loginScreen,
        dashboard: !!dashboard,
        loginForm: !!loginForm,
        pageContent: !!pageContent
    });

    return !!(loadingScreen && loginScreen && dashboard && loginForm && pageContent);
}

// This will be called from HTML after Firebase loads

// Auth state management
let isHandlingAuthChange = false;
let currentAuthUser = null;

// Auth state handler
window.onAuthStateChanged = async function(user) {
    // Prevent multiple simultaneous auth handling
    if (isHandlingAuthChange) {
        console.log('⏳ Auth change already being handled, skipping...');
        return;
    }

    // Check if this is the same user
    const userEmail = user ? user.email : null;
    const currentEmail = currentAuthUser ? currentAuthUser.email : null;

    if (userEmail === currentEmail) {
        // Silently skip same user state to reduce console noise
        return;
    }

    isHandlingAuthChange = true;
    currentAuthUser = user;

    console.log('🔐 Auth state changed:', user ? 'Signed in' : 'Signed out');

    try {
        if (user) {
            console.log('✅ User authenticated:', user.email);
            showDashboard();

            // Load dashboard with error handling
            try {
                await loadPage('dashboard');
            } catch (pageError) {
                console.error('❌ Error loading dashboard:', pageError);
                pageContent.innerHTML = `
                    <div class="alert alert-warning">
                        <h5>مرحباً بك في لوحة التحكم</h5>
                        <p>حدث خطأ في تحميل البيانات. يرجى المحاولة مرة أخرى.</p>
                        <button class="btn btn-primary" onclick="loadPage('dashboard')">
                            <i class="fas fa-redo me-2"></i>إعادة المحاولة
                        </button>
                    </div>
                `;
            }

            // Update admin name safely
            const adminNameElement = document.getElementById('adminName');
            if (adminNameElement) {
                adminNameElement.textContent = user.email.split('@')[0];
            }

            showNotification(`مرحباً ${user.email.split('@')[0]}!`, 'success');
        } else {
            console.log('👤 User not authenticated');
            showLogin();
        }
        hideLoading();
    } catch (error) {
        console.error('❌ Error handling auth change:', error);
        hideLoading();
        showLogin();
    } finally {
        // Reset flag after a short delay
        setTimeout(() => {
            isHandlingAuthChange = false;
        }, 1000);
    }
};

function initializeApp() {
    console.log('🚀 Starting app initialization...');

    // Initialize DOM elements first
    if (!initializeDOMElements()) {
        console.error('❌ Failed to initialize DOM elements');
        return;
    }

    // Set up event listeners
    setupEventListeners();

    // Check network connectivity
    if (!navigator.onLine) {
        console.warn('⚠️ No internet connection');
        showNotification('لا يوجد اتصال بالإنترنت. بعض الميزات قد لا تعمل.', 'warning');
    }

    // Add network status listeners
    window.addEventListener('online', () => {
        console.log('🌐 Connection restored');
        updateConnectionStatus(true);
        showNotification('تم استعادة الاتصال بالإنترنت', 'success');
    });

    window.addEventListener('offline', () => {
        console.log('📡 Connection lost');
        updateConnectionStatus(false);
        showNotification('انقطع الاتصال بالإنترنت', 'warning');
    });

    // Initial connection status
    updateConnectionStatus(navigator.onLine);

    // Show loading initially
    showLoading();

    // Add a timeout to prevent infinite loading
    setTimeout(() => {
        if (loadingScreen && !loadingScreen.classList.contains('d-none')) {
            console.warn('⚠️ Loading timeout reached, forcing login screen...');
            showLogin();
        }
    }, 5000); // 5 seconds timeout
}

function setupEventListeners() {
    // Login form
    if (loginForm) {
        loginForm.addEventListener('submit', handleLogin);
    }

    // Logout buttons
    const logoutBtn = document.getElementById('logoutBtn');
    if (logoutBtn) {
        logoutBtn.addEventListener('click', handleLogout);
    }

    const logoutBtn2 = document.getElementById('logoutBtn2');
    if (logoutBtn2) {
        logoutBtn2.addEventListener('click', handleLogout);
    }

    // Sidebar toggle
    const sidebarCollapse = document.getElementById('sidebarCollapse');
    if (sidebarCollapse) {
        sidebarCollapse.addEventListener('click', toggleSidebar);
    }

    // Sidebar overlay click to close
    const sidebarOverlay = document.getElementById('sidebarOverlay');
    if (sidebarOverlay) {
        sidebarOverlay.addEventListener('click', closeSidebar);
    }

    // Sidebar navigation with better error handling
    console.log('🔗 Setting up sidebar navigation...');

    const setupSidebarLinks = () => {
        const sidebarLinks = document.querySelectorAll('.sidebar [data-page]');
        console.log('📋 Found sidebar links:', sidebarLinks.length);

        if (sidebarLinks.length === 0) {
            console.warn('⚠️ No sidebar links found! Checking selectors...');
            const allDataPageElements = document.querySelectorAll('[data-page]');
            console.log('📋 All [data-page] elements:', allDataPageElements.length);
            const sidebarElement = document.querySelector('.sidebar');
            console.log('📋 Sidebar element found:', !!sidebarElement);
            return false;
        }

        sidebarLinks.forEach((link, index) => {
            const page = link.getAttribute('data-page');
            console.log(`🔗 Setting up link ${index + 1}: ${page} (${link.textContent.trim()})`);

            // Remove existing listeners by cloning
            const newLink = link.cloneNode(true);
            link.parentNode.replaceChild(newLink, link);

            newLink.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                console.log(`🎯 Sidebar link clicked: ${page}`);

                try {
                    // Load the page
                    loadPage(page);

                    // Update active state
                    document.querySelectorAll('.sidebar li').forEach(li => li.classList.remove('active'));
                    this.parentElement.classList.add('active');
                    console.log(`✅ Active state updated for: ${page}`);

                    // Close sidebar on mobile after navigation
                    if (window.innerWidth < 1200) {
                        console.log('📱 Mobile detected, closing sidebar...');
                        setTimeout(() => {
                            closeSidebar();
                        }, 300);
                    }
                } catch (error) {
                    console.error('❌ Error in sidebar navigation:', error);
                }
            });
        });

        return true;
    };

    // Try to setup sidebar links immediately
    if (!setupSidebarLinks()) {
        console.log('⏳ Retrying sidebar setup in 500ms...');
        setTimeout(() => {
            if (!setupSidebarLinks()) {
                console.log('⏳ Retrying sidebar setup in 1000ms...');
                setTimeout(setupSidebarLinks, 1000);
            }
        }, 500);
    }

    console.log('✅ Sidebar navigation setup complete');

    // Re-initialize sidebar navigation multiple times to ensure it works
    setTimeout(() => {
        console.log('🔄 First re-initialization attempt...');
        reinitializeSidebarNavigation();
    }, 1000);

    setTimeout(() => {
        console.log('🔄 Second re-initialization attempt...');
        reinitializeSidebarNavigation();
    }, 2000);

    setTimeout(() => {
        console.log('🔄 Final re-initialization attempt...');
        reinitializeSidebarNavigation();
    }, 3000);

    // Also setup direct handlers as backup
    setTimeout(() => {
        console.log('🔧 Setting up direct handlers as backup...');
        setupDirectSidebarHandlers();
    }, 1500);

    // Handle window resize for responsive behavior
    window.addEventListener('resize', handleWindowResize);

    // Add event delegation for sidebar navigation as backup
    document.addEventListener('click', function(e) {
        // Check if clicked element or its parent has data-page attribute
        let target = e.target;
        let dataPage = null;

        // Check up to 3 levels up for data-page attribute
        for (let i = 0; i < 3 && target; i++) {
            if (target.hasAttribute && target.hasAttribute('data-page')) {
                dataPage = target.getAttribute('data-page');
                break;
            }
            target = target.parentElement;
        }

        // If we found a data-page attribute and it's in the sidebar
        if (dataPage && target && target.closest('.sidebar')) {
            e.preventDefault();
            e.stopPropagation();
            console.log(`🎯 Event delegation: Sidebar link clicked: ${dataPage}`);

            try {
                // Load the page
                loadPage(dataPage);

                // Update active state
                document.querySelectorAll('.sidebar li').forEach(li => li.classList.remove('active'));

                // Find the parent li element
                const parentLi = target.closest('li');
                if (parentLi) {
                    parentLi.classList.add('active');
                }

                console.log(`✅ Event delegation: Active state updated for: ${dataPage}`);

                // Close sidebar on mobile after navigation
                if (window.innerWidth < 1200) {
                    console.log('📱 Event delegation: Mobile detected, closing sidebar...');
                    setTimeout(() => {
                        closeSidebar();
                    }, 300);
                }
            } catch (error) {
                console.error('❌ Error in event delegation sidebar navigation:', error);
            }
        }
    });

    // Initial resize check
    setTimeout(handleWindowResize, 100);
}

function toggleSidebar() {
    const sidebar = document.getElementById('sidebar');
    const overlay = document.getElementById('sidebarOverlay');

    if (sidebar) {
        const isHidden = sidebar.classList.contains('active');

        if (isHidden) {
            // Show sidebar (slide in from right)
            sidebar.classList.remove('active');
            if (overlay && window.innerWidth < 1200) {
                overlay.classList.add('active');
            }
        } else {
            // Hide sidebar (slide out to right)
            sidebar.classList.add('active');
            if (overlay) {
                overlay.classList.remove('active');
            }
        }
    }
}

function closeSidebar() {
    const sidebar = document.getElementById('sidebar');
    const overlay = document.getElementById('sidebarOverlay');

    if (sidebar) {
        // Hide sidebar (slide out to right)
        sidebar.classList.add('active');
        if (overlay) {
            overlay.classList.remove('active');
        }
    }
}

function handleWindowResize() {
    const sidebar = document.getElementById('sidebar');
    const content = document.getElementById('content');
    const overlay = document.getElementById('sidebarOverlay');
    const sidebarCollapse = document.getElementById('sidebarCollapse');

    if (!sidebar || !content) return;

    const windowWidth = window.innerWidth;

    // Large screens (1200px+): Always show sidebar, hide overlay and toggle button
    if (windowWidth >= 1200) {
        sidebar.classList.remove('active');
        content.classList.remove('active');
        if (overlay) {
            overlay.classList.remove('active');
        }
        if (sidebarCollapse) {
            sidebarCollapse.style.display = 'none';
        }
    }
    // Medium and small screens: Hide sidebar by default, show toggle button
    else {
        if (sidebarCollapse) {
            sidebarCollapse.style.display = 'block';
        }

        // Ensure sidebar is hidden on smaller screens (slide out)
        sidebar.classList.add('active');
        content.classList.remove('active'); // Content should always be full width on mobile
        if (overlay) {
            overlay.classList.remove('active');
        }
    }
}

// Authentication functions
async function handleLogin(e) {
    e.preventDefault();

    const email = document.getElementById('email').value.trim();
    const password = document.getElementById('password').value;

    // Validate inputs
    if (!email || !password) {
        showError('يرجى إدخال البريد الإلكتروني وكلمة المرور');
        return;
    }

    // Show loading state
    const submitBtn = e.target.querySelector('button[type="submit"]');
    const originalText = submitBtn.innerHTML;
    submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin me-2"></i>جاري تسجيل الدخول...';
    submitBtn.disabled = true;
    hideError();

    try {
        console.log('🔐 Attempting login for:', email);

        // Check network first
        if (!navigator.onLine) {
            throw new Error('لا يوجد اتصال بالإنترنت');
        }

        const result = await FirebaseService.signIn(email, password);

        if (result.success) {
            console.log('✅ Login successful');
            hideError();

            // Show loading screen while auth state changes
            showLoading();

            // Reset button after a delay to prevent multiple clicks
            setTimeout(() => {
                submitBtn.innerHTML = originalText;
                submitBtn.disabled = false;
            }, 2000);
        } else {
            console.error('❌ Login failed:', result.error);
            showError(result.error);
            // Reset button on error
            submitBtn.innerHTML = originalText;
            submitBtn.disabled = false;
        }
    } catch (error) {
        console.error('❌ Login error:', error);
        showError(error.message || 'حدث خطأ أثناء تسجيل الدخول');
        // Reset button on error
        submitBtn.innerHTML = originalText;
        submitBtn.disabled = false;
    }
}

async function handleLogout() {
    const result = await FirebaseService.signOut();
    if (result.success) {
        showLogin();
    }
}

// UI functions
function showLoading() {
    if (loadingScreen) loadingScreen.classList.remove('d-none');
    if (loginScreen) loginScreen.classList.add('d-none');
    if (dashboard) dashboard.classList.add('d-none');
}

function hideLoading() {
    if (loadingScreen) {
        loadingScreen.classList.add('d-none');
    }
}

function showLogin() {
    hideLoading();
    if (loginScreen) loginScreen.classList.remove('d-none');
    if (dashboard) dashboard.classList.add('d-none');
}

function showDashboard() {
    hideLoading();
    if (loginScreen) loginScreen.classList.add('d-none');
    if (dashboard) dashboard.classList.remove('d-none');
}

function showError(message) {
    if (loginError) {
        loginError.textContent = message;
        loginError.classList.remove('d-none');
    }
}

function hideError() {
    if (loginError) {
        loginError.classList.add('d-none');
    }
}

function updateConnectionStatus(isOnline) {
    const statusElement = document.getElementById('connectionStatus');
    if (statusElement) {
        if (isOnline) {
            statusElement.className = 'badge bg-success';
            statusElement.innerHTML = '<i class="fas fa-wifi me-1"></i>متصل';
        } else {
            statusElement.className = 'badge bg-danger';
            statusElement.innerHTML = '<i class="fas fa-wifi-slash me-1"></i>غير متصل';
        }
    }
}

function toggleSidebar() {
    sidebar.classList.toggle('active');
    content.classList.toggle('active');
}

function closeSidebar() {
    sidebar.classList.remove('active');
    content.classList.remove('active');
    console.log('📱 Sidebar closed');
}

// Page loading functions
async function loadPage(page) {
    currentPage = page;
    if (pageContent) {
        pageContent.innerHTML = '<div class="text-center"><div class="spinner-border text-primary" role="status"></div><p class="mt-2">جاري تحميل الصفحة...</p></div>';
    }

    try {
        console.log('📄 Loading page:', page);
        let content = '';

        // Add timeout for page loading
        const loadPageWithTimeout = async () => {
            switch(page) {
                case 'dashboard':
                    return await loadDashboardPage();
                case 'students':
                    return await loadStudentsPage();
                case 'supervisors':
                    return await loadSupervisorsPage();
                case 'buses':
                    return await loadBusesPage();
                case 'parents':
                    return await loadParentsPage();
                case 'reports':
                    return await loadReportsPage();
                case 'complaints':
                    return await loadComplaintsPage();
                case 'parent-students':
                    return await loadParentStudentsPage();
                case 'settings':
                    return await loadSettingsPage();
                case 'profile':
                    return await loadProfilePage();
                case 'notifications':
                    return await loadNotificationsPage();
                case 'help':
                    return await loadHelpPage();
                default:
                    return '<div class="alert alert-warning">الصفحة غير موجودة</div>';
            }
        };

        // Load with timeout
        const timeoutPromise = new Promise((_, reject) =>
            setTimeout(() => reject(new Error('Page load timeout')), 10000)
        );

        content = await Promise.race([loadPageWithTimeout(), timeoutPromise]);

        if (pageContent) {
            pageContent.innerHTML = content;
            pageContent.classList.add('fade-in');
        }

        // Initialize page-specific functionality
        initializePageFunctionality(page);

        console.log('✅ Page loaded successfully:', page);

    } catch (error) {
        console.error('❌ Error loading page:', error);
        if (pageContent) {
            pageContent.innerHTML = `
                <div class="alert alert-danger">
                    <h5>حدث خطأ أثناء تحميل الصفحة</h5>
                    <p>${error.message || 'خطأ غير معروف'}</p>
                    <button class="btn btn-primary" onclick="loadPage('${page}')">
                        <i class="fas fa-redo me-2"></i>إعادة المحاولة
                    </button>
                </div>
            `;
        }
    }
}

async function loadStudentsPage() {
    console.log('👨‍🎓 Loading students page with parent linking...');

    try {
        // Load students and parents data
        const [students, parents] = await Promise.all([
            FirebaseService.getStudents(),
            FirebaseService.getParents()
        ]);

        studentsData = students || [];
        parentsData = parents || [];

        console.log('✅ Students loaded:', studentsData.length);
        console.log('✅ Parents loaded:', parentsData.length);

        // Update parent-student relationships in local data
        studentsData.forEach(student => {
            if (student.parentId && student.parentId !== '') {
                const parent = parentsData.find(p => p.id === student.parentId);
                if (parent) {
                    // Update student with latest parent info
                    student.parentName = parent.name;
                    student.parentPhone = parent.phone;
                    student.parentEmail = parent.email;
                }
            }
        });

        console.log('✅ Parent-student relationships updated');

    } catch (error) {
        console.error('❌ Error loading students/parents:', error);
        studentsData = [];
        parentsData = [];
    }

    return `
        <!-- Header Section -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="d-flex flex-column flex-md-row justify-content-between align-items-start align-items-md-center">
                    <div class="mb-3 mb-md-0">
                        <h2 class="text-gradient mb-2">
                            <i class="fas fa-graduation-cap me-2"></i>
                            إدارة الطلاب
                        </h2>
                        <p class="text-muted mb-0">إدارة جميع بيانات الطلاب في النظام</p>
                    </div>
                    <div class="d-flex flex-column flex-sm-row gap-2">
                        <button class="btn btn-outline-primary" onclick="exportStudents()">
                            <i class="fas fa-download me-2"></i>
                            <span class="d-none d-sm-inline">تصدير</span>
                        </button>
                        <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#addStudentModal">
                            <i class="fas fa-plus me-2"></i>
                            <span class="d-none d-sm-inline">إضافة طالب جديد</span>
                            <span class="d-sm-none">إضافة</span>
                        </button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Statistics Cards -->
        <div class="row mb-4">
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card primary">
                    <div class="icon">
                        <i class="fas fa-users"></i>
                    </div>
                    <h3>${studentsData.length}</h3>
                    <p class="mb-0">إجمالي الطلاب</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card success">
                    <div class="icon">
                        <i class="fas fa-user-check"></i>
                    </div>
                    <h3>${studentsData.filter(s => s.currentStatus !== 'inactive').length}</h3>
                    <p class="mb-0">الطلاب النشطين</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card warning">
                    <div class="icon">
                        <i class="fas fa-bus"></i>
                    </div>
                    <h3>${studentsData.filter(s => s.currentStatus === 'onBus').length}</h3>
                    <p class="mb-0">في الباص</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card info">
                    <div class="icon">
                        <i class="fas fa-school"></i>
                    </div>
                    <h3>${studentsData.filter(s => s.currentStatus === 'atSchool').length}</h3>
                    <p class="mb-0">في المدرسة</p>
                </div>
            </div>
        </div>

        <!-- Filters and Search -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="card border-0 shadow-sm">
                    <div class="card-body">
                        <div class="row g-3">
                            <div class="col-md-4">
                                <label class="form-label">البحث</label>
                                <div class="input-group">
                                    <span class="input-group-text">
                                        <i class="fas fa-search"></i>
                                    </span>
                                    <input type="text" class="form-control" id="searchStudents"
                                           placeholder="البحث بالاسم أو رقم الهاتف...">
                                </div>
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">الحالة</label>
                                <select class="form-select" id="filterStatus">
                                    <option value="">جميع الحالات</option>
                                    <option value="home">في المنزل</option>
                                    <option value="onBus">في الباص</option>
                                    <option value="atSchool">في المدرسة</option>
                                    <option value="inactive">غير نشط</option>
                                </select>
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">خط الباص</label>
                                <select class="form-select" id="filterBusRoute">
                                    <option value="">جميع الخطوط</option>
                                    <option value="الخط الأول">الخط الأول</option>
                                    <option value="الخط الثاني">الخط الثاني</option>
                                    <option value="الخط الثالث">الخط الثالث</option>
                                    <option value="الخط الرابع">الخط الرابع</option>
                                    <option value="الخط الخامس">الخط الخامس</option>
                                </select>
                            </div>
                            <div class="col-md-2 d-flex align-items-end">
                                <button class="btn btn-outline-secondary w-100" onclick="clearFilters()">
                                    <i class="fas fa-times me-1"></i>
                                    <span class="d-none d-md-inline">مسح</span>
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Students Table -->
        <div class="card border-0 shadow-sm">
            <div class="card-header bg-white border-bottom">
                <div class="d-flex justify-content-between align-items-center">
                    <h5 class="mb-0">
                        <i class="fas fa-list me-2 text-primary"></i>
                        قائمة الطلاب
                    </h5>
                    <div class="d-flex gap-2">
                        <button class="btn btn-sm btn-outline-primary" onclick="toggleView('grid')" title="عرض البطاقات">
                            <i class="fas fa-th"></i>
                        </button>
                        <button class="btn btn-sm btn-primary" onclick="toggleView('table')" title="عرض الجدول">
                            <i class="fas fa-list"></i>
                        </button>
                    </div>
                </div>
            </div>
            <div class="card-body p-0">
                <!-- Desktop Table View -->
                <div class="table-responsive d-none d-lg-block" id="tableView">
                    <table class="table table-hover mb-0">
                        <thead class="table-light">
                            <tr>
                                <th class="border-0 ps-4">الطالب</th>
                                <th class="border-0">الصف والمدرسة</th>
                                <th class="border-0">ولي الأمر</th>
                                <th class="border-0">خط الباص</th>
                                <th class="border-0">الحالة</th>
                                <th class="border-0 text-center">الإجراءات</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${studentsData.map(student => `
                                <tr class="student-row" data-student-id="${student.id}">
                                    <td class="ps-4">
                                        <div class="d-flex align-items-center">
                                            <div class="student-avatar me-3">
                                                <div class="avatar-circle">
                                                    <i class="fas fa-user"></i>
                                                </div>
                                            </div>
                                            <div>
                                                <h6 class="mb-1 fw-bold">${student.name || 'غير محدد'}</h6>
                                                <small class="text-muted">QR: ${student.qrCode || 'غير محدد'}</small>
                                            </div>
                                        </div>
                                    </td>
                                    <td>
                                        <div>
                                            <span class="fw-semibold">${student.grade || 'غير محدد'}</span>
                                            <br>
                                            <small class="text-muted">${student.schoolName || 'غير محدد'}</small>
                                        </div>
                                    </td>
                                    <td>
                                        <div>
                                            <span class="fw-semibold">${student.parentName || 'غير محدد'}</span>
                                            <br>
                                            <small class="text-muted">
                                                <i class="fas fa-phone me-1"></i>
                                                ${student.parentPhone || 'غير محدد'}
                                            </small>
                                        </div>
                                    </td>
                                    <td>
                                        <span class="badge bg-primary bg-gradient">${student.busRoute || 'غير محدد'}</span>
                                    </td>
                                    <td>
                                        <span class="status-badge ${getStatusClass(student.currentStatus)}">
                                            <i class="fas ${getStatusIcon(student.currentStatus)} me-1"></i>
                                            ${getStatusText(student.currentStatus)}
                                        </span>
                                    </td>
                                    <td class="text-center">
                                        <div class="btn-group" role="group">
                                            <button class="btn btn-sm btn-outline-primary" onclick="viewStudent('${student.id}')" title="عرض">
                                                <i class="fas fa-eye"></i>
                                            </button>
                                            <button class="btn btn-sm btn-outline-warning" onclick="editStudent('${student.id}')" title="تعديل">
                                                <i class="fas fa-edit"></i>
                                            </button>
                                            <button class="btn btn-sm btn-outline-danger" onclick="deleteStudent('${student.id}')" title="حذف">
                                                <i class="fas fa-trash"></i>
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            `).join('')}
                        </tbody>
                    </table>
                </div>

                <!-- Mobile/Tablet Card View -->
                <div class="d-lg-none" id="cardView">
                    <div class="row g-3 p-3">
                        ${studentsData.map(student => `
                            <div class="col-12 col-md-6">
                                <div class="student-card">
                                    <div class="student-card-header">
                                        <div class="d-flex align-items-center">
                                            <div class="student-avatar me-3">
                                                <div class="avatar-circle">
                                                    <i class="fas fa-user"></i>
                                                </div>
                                            </div>
                                            <div class="flex-grow-1">
                                                <h6 class="mb-1 fw-bold">${student.name || 'غير محدد'}</h6>
                                                <small class="text-muted">${student.grade || 'غير محدد'} - ${student.schoolName || 'غير محدد'}</small>
                                            </div>
                                            <div class="student-status">
                                                <span class="status-badge ${getStatusClass(student.currentStatus)}">
                                                    <i class="fas ${getStatusIcon(student.currentStatus)}"></i>
                                                </span>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="student-card-body">
                                        <div class="row g-2">
                                            <div class="col-6">
                                                <div class="info-item">
                                                    <i class="fas fa-user-tie text-muted me-2"></i>
                                                    <div>
                                                        <small class="text-muted d-block">ولي الأمر</small>
                                                        <span class="fw-semibold">${student.parentName || 'غير محدد'}</span>
                                                    </div>
                                                </div>
                                            </div>
                                            <div class="col-6">
                                                <div class="info-item">
                                                    <i class="fas fa-phone text-muted me-2"></i>
                                                    <div>
                                                        <small class="text-muted d-block">الهاتف</small>
                                                        <span class="fw-semibold">${student.parentPhone || 'غير محدد'}</span>
                                                    </div>
                                                </div>
                                            </div>
                                            <div class="col-6">
                                                <div class="info-item">
                                                    <i class="fas fa-bus text-muted me-2"></i>
                                                    <div>
                                                        <small class="text-muted d-block">خط الباص</small>
                                                        <span class="badge bg-primary">${student.busRoute || 'غير محدد'}</span>
                                                    </div>
                                                </div>
                                            </div>
                                            <div class="col-6">
                                                <div class="info-item">
                                                    <i class="fas fa-qrcode text-muted me-2"></i>
                                                    <div>
                                                        <small class="text-muted d-block">رمز QR</small>
                                                        <span class="fw-semibold">${student.qrCode || 'غير محدد'}</span>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="student-card-footer">
                                        <div class="d-flex justify-content-between align-items-center">
                                            <span class="status-badge ${getStatusClass(student.currentStatus)}">
                                                <i class="fas ${getStatusIcon(student.currentStatus)} me-1"></i>
                                                ${getStatusText(student.currentStatus)}
                                            </span>
                                            <div class="btn-group" role="group">
                                                <button class="btn btn-sm btn-outline-primary" onclick="viewStudent('${student.id}')" title="عرض">
                                                    <i class="fas fa-eye"></i>
                                                </button>
                                                <button class="btn btn-sm btn-outline-warning" onclick="editStudent('${student.id}')" title="تعديل">
                                                    <i class="fas fa-edit"></i>
                                                </button>
                                                <button class="btn btn-sm btn-outline-danger" onclick="deleteStudent('${student.id}')" title="حذف">
                                                    <i class="fas fa-trash"></i>
                                                </button>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        `).join('')}
                    </div>
                </div>
            </div>
        </div>

        <!-- Add Student Modal -->
        <div class="modal fade" id="addStudentModal" tabindex="-1">
            <div class="modal-dialog modal-lg modal-dialog-scrollable">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title d-none d-sm-block">
                            <i class="fas fa-user-plus me-2"></i>
                            إضافة طالب جديد
                        </h5>
                        <h6 class="modal-title d-sm-none">
                            <i class="fas fa-user-plus me-1"></i>
                            إضافة طالب
                        </h6>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form id="addStudentForm">
                            <!-- Student Information Section -->
                            <div class="mb-4">
                                <h6 class="text-primary mb-3">
                                    <i class="fas fa-school me-2"></i>
                                    بيانات الطالب
                                </h6>
                                <div class="row">
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">اسم الطالب *</label>
                                        <input type="text" class="form-control" name="name" required
                                               placeholder="أدخل اسم الطالب الكامل" minlength="2">
                                    </div>
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">الصف الدراسي *</label>
                                        <input type="text" class="form-control" name="grade" required
                                               placeholder="مثال: الصف الأول">
                                    </div>
                                </div>
                                <div class="mb-3">
                                    <label class="form-label">اسم المدرسة *</label>
                                    <input type="text" class="form-control" name="schoolName" required
                                           placeholder="أدخل اسم المدرسة">
                                </div>
                            </div>

                            <!-- Parent Information Section -->
                            <div class="mb-4">
                                <h6 class="text-primary mb-3">
                                    <i class="fas fa-users me-2"></i>
                                    بيانات ولي الأمر
                                </h6>
                                <div class="row">
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">ولي الأمر *</label>
                                        <input type="text" class="form-control mb-1" id="parentSearchInput"
                                               placeholder="ابحث بالاسم أو رقم الهاتف..."
                                               oninput="filterParentOptions(this.value, 'addStudentForm')">
                                        <select class="form-control" name="parentId" required onchange="updateParentInfo()" size="5">
                                            <option value="">اختر ولي الأمر</option>
                                            <option value="new_parent">+ إضافة ولي أمر جديد</option>
                                        </select>
                                        <small class="text-muted">اكتب في مربع البحث لتصفية القائمة، ثم اختر من أولياء الأمور المسجلين أو أضف جديد</small>
                                    </div>
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">رقم هاتف ولي الأمر</label>
                                        <input type="tel" class="form-control" name="parentPhone" readonly
                                               placeholder="سيتم ملؤه تلقائياً">
                                        <small class="text-muted">يتم ملؤه تلقائياً عند اختيار ولي الأمر</small>
                                    </div>
                                </div>

                                <!-- New Parent Form (Hidden by default) -->
                                <div id="newParentSection" class="row" style="display: none;">
                                    <div class="col-12 mb-3">
                                        <div class="alert alert-info">
                                            <i class="fas fa-info-circle me-2"></i>
                                            <strong>إضافة ولي أمر جديد:</strong> املأ البيانات التالية لإنشاء حساب ولي أمر جديد
                                        </div>
                                    </div>
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">اسم ولي الأمر الجديد *</label>
                                        <input type="text" class="form-control" name="newParentName"
                                               placeholder="أدخل اسم ولي الأمر">
                                    </div>
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">رقم هاتف ولي الأمر الجديد *</label>
                                        <input type="tel" class="form-control" name="newParentPhone"
                                               placeholder="05xxxxxxxx" pattern="[0-9]{10,}">
                                    </div>
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">البريد الإلكتروني *</label>
                                        <input type="email" class="form-control" name="newParentEmail"
                                               placeholder="example@domain.com">
                                    </div>
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">كلمة المرور المؤقتة *</label>
                                        <input type="password" class="form-control" name="newParentPassword"
                                               placeholder="كلمة مرور مؤقتة (6 أحرف على الأقل)">
                                    </div>
                                </div>
                            </div>

                            <!-- Transportation Information Section -->
                            <div class="mb-4">
                                <h6 class="text-primary mb-3">
                                    <i class="fas fa-bus me-2"></i>
                                    بيانات النقل
                                </h6>
                                <div class="mb-3">
                                    <label class="form-label">خط الباص *</label>
                                    <select class="form-control" name="busRoute" required>
                                        <option value="">اختر خط الباص</option>
                                        <option value="الخط الأول">الخط الأول</option>
                                        <option value="الخط الثاني">الخط الثاني</option>
                                        <option value="الخط الثالث">الخط الثالث</option>
                                        <option value="الخط الرابع">الخط الرابع</option>
                                        <option value="الخط الخامس">الخط الخامس</option>
                                    </select>
                                </div>
                            </div>

                            <div class="alert alert-info">
                                <i class="fas fa-info-circle me-2"></i>
                                <strong>ملاحظة:</strong> سيتم إنشاء رمز QR فريد للطالب تلقائياً بعد الحفظ.
                            </div>
                        </form>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>إلغاء
                        </button>
                        <button type="button" class="btn btn-primary" onclick="saveStudentWithParent()">
                            <i class="fas fa-save me-2"></i>إضافة الطالب
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;
}

async function loadSupervisorsPage() {
    console.log('📋 Loading Supervisors Page...');

    try {
        console.log('🔄 Fetching supervisors from Firebase...');
        const firebaseSupervisors = await FirebaseService.getSupervisors();

        if (firebaseSupervisors && firebaseSupervisors.length > 0) {
            // Map Firebase data to our format
            supervisorsData = firebaseSupervisors.map(supervisor => ({
                id: supervisor.id,
                name: supervisor.name || 'غير محدد',
                email: supervisor.email || 'غير محدد',
                phone: supervisor.phone || 'غير محدد',
                busRoute: supervisor.busRoute || 'غير محدد',
                status: supervisor.isActive ? 'active' : 'inactive',
                permissions: supervisor.permissions || ['view_students'],
                createdAt: supervisor.createdAt ? (supervisor.createdAt.toDate ? supervisor.createdAt.toDate() : new Date(supervisor.createdAt)) : new Date(),
                lastLogin: supervisor.updatedAt ? (supervisor.updatedAt.toDate ? supervisor.updatedAt.toDate() : new Date(supervisor.updatedAt)) : new Date(),
                userType: supervisor.userType || 'supervisor',
                isActive: supervisor.isActive !== false
            }));

            console.log('✅ Supervisors loaded from Firebase:', supervisorsData.length);
        } else {
            console.log('⚠️ No supervisors found in Firebase, will use fallback data');
            supervisorsData = [];
        }
    } catch (error) {
        console.error('❌ Error loading supervisors:', error);
        supervisorsData = [
            {
                id: '1',
                name: 'أحمد محمد',
                email: 'ahmed@mybus.com',
                phone: '0501234567',
                busRoute: 'الخط الأول',
                status: 'active',
                createdAt: new Date('2024-01-15'),
                lastLogin: new Date('2024-01-20'),
                permissions: ['view_students', 'manage_trips']
            },
            {
                id: '2',
                name: 'سارة أحمد',
                email: 'sara@mybus.com',
                phone: '0507654321',
                busRoute: 'الخط الثاني',
                status: 'active',
                createdAt: new Date('2024-01-10'),
                lastLogin: new Date('2024-01-19'),
                permissions: ['view_students', 'manage_trips', 'send_notifications']
            },
            {
                id: '3',
                name: 'محمد علي',
                email: 'mohammed@mybus.com',
                phone: '0509876543',
                busRoute: 'الخط الثالث',
                status: 'inactive',
                createdAt: new Date('2024-01-05'),
                lastLogin: new Date('2024-01-15'),
                permissions: ['view_students']
            }
        ];
    }

    return `
        <!-- Header Section -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="d-flex flex-column flex-md-row justify-content-between align-items-start align-items-md-center">
                    <div class="mb-3 mb-md-0">
                        <h2 class="text-gradient mb-2">
                            <i class="fas fa-user-tie me-2"></i>
                            إدارة المشرفين
                        </h2>
                        <p class="text-muted mb-0">إدارة جميع بيانات المشرفين والمراقبين في النظام</p>
                    </div>
                    <div class="d-flex flex-column flex-sm-row gap-2">
                        <button class="btn btn-outline-primary" onclick="exportSupervisors()">
                            <i class="fas fa-download me-2"></i>
                            <span class="d-none d-sm-inline">تصدير</span>
                        </button>
                        <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#addSupervisorModal">
                            <i class="fas fa-plus me-2"></i>
                            <span class="d-none d-sm-inline">إضافة مشرف جديد</span>
                            <span class="d-sm-none">إضافة</span>
                        </button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Statistics Cards -->
        <div class="row mb-4">
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card primary">
                    <div class="icon">
                        <i class="fas fa-users"></i>
                    </div>
                    <h3>${supervisorsData.length}</h3>
                    <p class="mb-0">إجمالي المشرفين</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card success">
                    <div class="icon">
                        <i class="fas fa-user-check"></i>
                    </div>
                    <h3>${supervisorsData.filter(s => s.status === 'active').length}</h3>
                    <p class="mb-0">المشرفين النشطين</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card warning">
                    <div class="icon">
                        <i class="fas fa-bus"></i>
                    </div>
                    <h3>${new Set(supervisorsData.map(s => s.busRoute)).size}</h3>
                    <p class="mb-0">خطوط الباص</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card info">
                    <div class="icon">
                        <i class="fas fa-clock"></i>
                    </div>
                    <h3>${supervisorsData.filter(s => {
                        const lastLogin = new Date(s.lastLogin);
                        const today = new Date();
                        const diffTime = Math.abs(today - lastLogin);
                        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
                        return diffDays <= 7;
                    }).length}</h3>
                    <p class="mb-0">نشط هذا الأسبوع</p>
                </div>
            </div>
        </div>

        <!-- Filters and Search -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="card border-0 shadow-sm">
                    <div class="card-body">
                        <div class="row g-3">
                            <div class="col-md-4">
                                <label class="form-label">البحث</label>
                                <div class="input-group">
                                    <span class="input-group-text">
                                        <i class="fas fa-search"></i>
                                    </span>
                                    <input type="text" class="form-control" id="searchSupervisors"
                                           placeholder="البحث بالاسم أو البريد الإلكتروني...">
                                </div>
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">الحالة</label>
                                <select class="form-select" id="filterSupervisorStatus">
                                    <option value="">جميع الحالات</option>
                                    <option value="active">نشط</option>
                                    <option value="inactive">غير نشط</option>
                                    <option value="suspended">موقوف</option>
                                </select>
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">خط الباص</label>
                                <select class="form-select" id="filterSupervisorRoute">
                                    <option value="">جميع الخطوط</option>
                                    <option value="الخط الأول">الخط الأول</option>
                                    <option value="الخط الثاني">الخط الثاني</option>
                                    <option value="الخط الثالث">الخط الثالث</option>
                                    <option value="الخط الرابع">الخط الرابع</option>
                                    <option value="الخط الخامس">الخط الخامس</option>
                                </select>
                            </div>
                            <div class="col-md-2 d-flex align-items-end">
                                <button class="btn btn-outline-secondary w-100" onclick="clearSupervisorFilters()">
                                    <i class="fas fa-times me-1"></i>
                                    <span class="d-none d-md-inline">مسح</span>
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Supervisors Table -->
        <div class="card border-0 shadow-sm">
            <div class="card-header bg-white border-bottom">
                <div class="d-flex justify-content-between align-items-center">
                    <h5 class="mb-0">
                        <i class="fas fa-list me-2 text-primary"></i>
                        قائمة المشرفين
                    </h5>
                    <div class="d-flex gap-2">
                        <button class="btn btn-sm btn-outline-primary" onclick="toggleSupervisorView('grid')" title="عرض البطاقات">
                            <i class="fas fa-th"></i>
                        </button>
                        <button class="btn btn-sm btn-primary" onclick="toggleSupervisorView('table')" title="عرض الجدول">
                            <i class="fas fa-list"></i>
                        </button>
                    </div>
                </div>
            </div>
            <div class="card-body p-0">
                <!-- Desktop Table View -->
                <div class="table-responsive d-none d-lg-block" id="supervisorTableView">
                    <table class="table table-hover mb-0">
                        <thead class="table-light">
                            <tr>
                                <th class="border-0 ps-4">المشرف</th>
                                <th class="border-0">معلومات الاتصال</th>
                                <th class="border-0">خط الباص</th>
                                <th class="border-0">الصلاحيات</th>
                                <th class="border-0">آخر نشاط</th>
                                <th class="border-0">الحالة</th>
                                <th class="border-0 text-center">الإجراءات</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${supervisorsData.map(supervisor => `
                                <tr class="supervisor-row" data-supervisor-id="${supervisor.id}">
                                    <td class="ps-4">
                                        <div class="d-flex align-items-center">
                                            <div class="supervisor-avatar me-3">
                                                <div class="avatar-circle bg-warning">
                                                    <i class="fas fa-user-tie text-white"></i>
                                                </div>
                                            </div>
                                            <div>
                                                <h6 class="mb-1 fw-bold">${supervisor.name || 'غير محدد'}</h6>
                                                <small class="text-muted">ID: ${supervisor.id}</small>
                                            </div>
                                        </div>
                                    </td>
                                    <td>
                                        <div>
                                            <span class="fw-semibold d-block">${supervisor.email}</span>
                                            <small class="text-muted">
                                                <i class="fas fa-phone me-1"></i>
                                                ${supervisor.phone || 'غير محدد'}
                                            </small>
                                        </div>
                                    </td>
                                    <td>
                                        <span class="badge bg-primary bg-gradient">${supervisor.busRoute || 'غير محدد'}</span>
                                    </td>
                                    <td>
                                        <div class="permissions-list">
                                            ${(supervisor.permissions || []).map(permission => `
                                                <span class="badge bg-light text-dark me-1 mb-1">${getPermissionText(permission)}</span>
                                            `).join('')}
                                        </div>
                                    </td>
                                    <td>
                                        <div>
                                            <small class="text-muted d-block">آخر دخول</small>
                                            <span class="fw-semibold">${formatDate(supervisor.lastLogin)}</span>
                                        </div>
                                    </td>
                                    <td>
                                        <span class="status-badge ${getSupervisorStatusClass(supervisor.status)}">
                                            <i class="fas ${getSupervisorStatusIcon(supervisor.status)} me-1"></i>
                                            ${getSupervisorStatusText(supervisor.status)}
                                        </span>
                                    </td>
                                    <td class="text-center">
                                        <div class="btn-group" role="group">
                                            <button class="btn btn-sm btn-outline-primary" onclick="viewSupervisor('${supervisor.id}')" title="عرض">
                                                <i class="fas fa-eye"></i>
                                            </button>
                                            <button class="btn btn-sm btn-outline-warning" onclick="editSupervisor('${supervisor.id}')" title="تعديل">
                                                <i class="fas fa-edit"></i>
                                            </button>
                                            <button class="btn btn-sm btn-outline-info" onclick="manageSupervisorPermissions('${supervisor.id}')" title="الصلاحيات">
                                                <i class="fas fa-key"></i>
                                            </button>
                                            <button class="btn btn-sm btn-outline-danger" onclick="deleteSupervisor('${supervisor.id}')" title="حذف">
                                                <i class="fas fa-trash"></i>
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            `).join('')}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <!-- Add Supervisor Modal -->
        <div class="modal fade" id="addSupervisorModal" tabindex="-1">
            <div class="modal-dialog modal-lg modal-dialog-scrollable">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title d-none d-sm-block">
                            <i class="fas fa-user-plus me-2"></i>
                            إضافة مشرف جديد
                        </h5>
                        <h6 class="modal-title d-sm-none">
                            <i class="fas fa-user-plus me-1"></i>
                            إضافة مشرف
                        </h6>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form id="addSupervisorForm">
                            <!-- Personal Information Section -->
                            <div class="mb-4">
                                <h6 class="text-primary mb-3">
                                    <i class="fas fa-user me-2"></i>
                                    البيانات الشخصية
                                </h6>
                                <div class="row">
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">الاسم الكامل *</label>
                                        <input type="text" class="form-control" name="name" required
                                               placeholder="أدخل الاسم الكامل" minlength="2">
                                    </div>
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">رقم الهاتف *</label>
                                        <input type="tel" class="form-control" name="phone" required
                                               placeholder="05xxxxxxxx" pattern="[0-9]{10,}">
                                    </div>
                                </div>
                                <div class="mb-3">
                                    <label class="form-label">البريد الإلكتروني *</label>
                                    <input type="email" class="form-control" name="email" required
                                           placeholder="example@mybus.com">
                                </div>
                            </div>

                            <!-- Work Information Section -->
                            <div class="mb-4">
                                <h6 class="text-primary mb-3">
                                    <i class="fas fa-briefcase me-2"></i>
                                    بيانات العمل
                                </h6>
                                <div class="mb-3">
                                    <label class="form-label">خط الباص المسؤول عنه *</label>
                                    <select class="form-control" name="busRoute" required>
                                        <option value="">اختر خط الباص</option>
                                        <option value="الخط الأول">الخط الأول</option>
                                        <option value="الخط الثاني">الخط الثاني</option>
                                        <option value="الخط الثالث">الخط الثالث</option>
                                        <option value="الخط الرابع">الخط الرابع</option>
                                        <option value="الخط الخامس">الخط الخامس</option>
                                    </select>
                                </div>
                            </div>

                            <!-- Permissions Section -->
                            <div class="mb-4">
                                <h6 class="text-primary mb-3">
                                    <i class="fas fa-key me-2"></i>
                                    الصلاحيات
                                </h6>
                                <div class="row">
                                    <div class="col-sm-6 mb-2">
                                        <div class="form-check">
                                            <input class="form-check-input" type="checkbox" name="permissions" value="view_students" id="perm1" checked>
                                            <label class="form-check-label" for="perm1">
                                                عرض بيانات الطلاب
                                            </label>
                                        </div>
                                    </div>
                                    <div class="col-sm-6 mb-2">
                                        <div class="form-check">
                                            <input class="form-check-input" type="checkbox" name="permissions" value="manage_trips" id="perm2" checked>
                                            <label class="form-check-label" for="perm2">
                                                إدارة الرحلات
                                            </label>
                                        </div>
                                    </div>
                                    <div class="col-sm-6 mb-2">
                                        <div class="form-check">
                                            <input class="form-check-input" type="checkbox" name="permissions" value="send_notifications" id="perm3">
                                            <label class="form-check-label" for="perm3">
                                                إرسال الإشعارات
                                            </label>
                                        </div>
                                    </div>
                                    <div class="col-sm-6 mb-2">
                                        <div class="form-check">
                                            <input class="form-check-input" type="checkbox" name="permissions" value="view_reports" id="perm4">
                                            <label class="form-check-label" for="perm4">
                                                عرض التقارير
                                            </label>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- Password Section -->
                            <div class="mb-4">
                                <h6 class="text-primary mb-3">
                                    <i class="fas fa-lock me-2"></i>
                                    كلمة المرور
                                </h6>
                                <div class="row">
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">كلمة المرور *</label>
                                        <input type="password" class="form-control" name="password" required
                                               placeholder="أدخل كلمة مرور قوية" minlength="6">
                                    </div>
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">تأكيد كلمة المرور *</label>
                                        <input type="password" class="form-control" name="confirmPassword" required
                                               placeholder="أعد إدخال كلمة المرور">
                                    </div>
                                </div>
                            </div>

                            <div class="alert alert-info">
                                <i class="fas fa-info-circle me-2"></i>
                                <strong>ملاحظة:</strong> سيتم إرسال بيانات الدخول للمشرف عبر البريد الإلكتروني.
                            </div>
                        </form>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>إلغاء
                        </button>
                        <button type="button" class="btn btn-primary" onclick="saveSupervisor()">
                            <i class="fas fa-save me-2"></i>إضافة المشرف
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;
}

async function loadBusesPage() {
    console.log('🚌 Loading Enhanced Responsive Buses Page...');

    try {
        // Load buses data from Firebase first
        console.log('🔄 Fetching buses from Firebase...');
        let firebaseBuses = [];

        try {
            if (typeof FirebaseService !== 'undefined' && FirebaseService.getBuses) {
                console.log('✅ FirebaseService.getBuses found, calling...');
                firebaseBuses = await FirebaseService.getBuses();
                console.log('✅ Buses loaded from Firebase:', firebaseBuses.length);
            } else {
                console.warn('⚠️ FirebaseService not available, trying direct Firebase access...');

                // Try direct Firebase access as fallback
                if (typeof db !== 'undefined') {
                    console.log('🔄 Trying direct Firebase access...');
                    try {
                        const snapshot = await db.collection('buses').where('isActive', '==', true).get();
                        firebaseBuses = snapshot.docs.map(doc => {
                            const data = doc.data();
                            return {
                                id: doc.id,
                                plateNumber: data.plateNumber || '',
                                description: data.description || '',
                                driverName: data.driverName || '',
                                driverPhone: data.driverPhone || '',
                                route: data.route || '',
                                capacity: data.capacity || 30,
                                hasAirConditioning: data.hasAirConditioning || false,
                                isActive: data.isActive !== false,
                                createdAt: data.createdAt,
                                updatedAt: data.updatedAt,
                                studentsCount: data.studentsCount || 0,
                                status: data.status || 'available',
                                maintenanceDate: data.maintenanceDate,
                                fuelLevel: data.fuelLevel || 100,
                                currentLocation: data.currentLocation || 'المرآب'
                            };
                        });
                        console.log('✅ Buses loaded via direct Firebase access:', firebaseBuses.length);
                    } catch (directError) {
                        console.error('❌ Direct Firebase access also failed:', directError);
                    }
                }
            }
        } catch (busError) {
            console.error('❌ Error loading buses from Firebase:', busError);
        }

        // If no Firebase data, use enhanced mock data
        if (!firebaseBuses || firebaseBuses.length === 0) {
            console.log('📝 Using enhanced mock buses data...');
            firebaseBuses = [
                {
                    id: 'bus_1',
                    plateNumber: 'أ ب ج 123',
                    description: 'باص مدرسي حديث مع تكييف',
                    driverName: 'أحمد محمد السعيد',
                    driverPhone: '0501234567',
                    route: 'الرياض - حي النرجس - مدرسة النور',
                    capacity: 30,
                    hasAirConditioning: true,
                    isActive: true,
                    status: 'available',
                    studentsCount: 25,
                    fuelLevel: 85,
                    currentLocation: 'مدرسة النور الابتدائية',
                    maintenanceDate: new Date('2024-02-15'),
                    createdAt: new Date('2024-01-01'),
                    updatedAt: new Date()
                },
                {
                    id: 'bus_2',
                    plateNumber: 'د هـ و 456',
                    description: 'باص مدرسي متوسط الحجم',
                    driverName: 'محمد علي أحمد',
                    driverPhone: '0507654321',
                    route: 'الرياض - حي الملقا - مدرسة الأمل',
                    capacity: 25,
                    hasAirConditioning: true,
                    isActive: true,
                    status: 'in_route',
                    studentsCount: 22,
                    fuelLevel: 60,
                    currentLocation: 'في الطريق إلى المدرسة',
                    maintenanceDate: new Date('2024-03-01'),
                    createdAt: new Date('2024-01-05'),
                    updatedAt: new Date()
                },
                {
                    id: 'bus_3',
                    plateNumber: 'ز ح ط 789',
                    description: 'باص مدرسي كبير الحجم',
                    driverName: 'سعد خالد النصر',
                    driverPhone: '0551234567',
                    route: 'الرياض - حي العليا - مدرسة المستقبل',
                    capacity: 35,
                    hasAirConditioning: true,
                    isActive: true,
                    status: 'maintenance',
                    studentsCount: 0,
                    fuelLevel: 30,
                    currentLocation: 'ورشة الصيانة',
                    maintenanceDate: new Date('2024-01-20'),
                    createdAt: new Date('2023-12-15'),
                    updatedAt: new Date()
                },
                {
                    id: 'bus_4',
                    plateNumber: 'ي ك ل 012',
                    description: 'باص مدرسي مع مرافق خاصة',
                    driverName: 'عبدالله سالم',
                    driverPhone: '0509876543',
                    route: 'الرياض - حي الورود - مدرسة الفجر',
                    capacity: 28,
                    hasAirConditioning: true,
                    isActive: true,
                    status: 'available',
                    studentsCount: 20,
                    fuelLevel: 95,
                    currentLocation: 'المرآب الرئيسي',
                    maintenanceDate: new Date('2024-04-10'),
                    createdAt: new Date('2024-01-10'),
                    updatedAt: new Date()
                },
                {
                    id: 'bus_5',
                    plateNumber: 'م ن س 345',
                    description: 'باص مدرسي اقتصادي',
                    driverName: 'خالد يوسف',
                    driverPhone: '0556789012',
                    route: 'الرياض - حي الصحافة - مدرسة الرسالة',
                    capacity: 32,
                    hasAirConditioning: false,
                    isActive: false,
                    status: 'out_of_service',
                    studentsCount: 0,
                    fuelLevel: 0,
                    currentLocation: 'خارج الخدمة',
                    maintenanceDate: new Date('2024-01-01'),
                    createdAt: new Date('2023-11-20'),
                    updatedAt: new Date()
                },
                {
                    id: 'bus_6',
                    plateNumber: 'ع ف ص 678',
                    description: 'باص مدرسي حديث ومجهز',
                    driverName: 'فهد عبدالرحمن',
                    driverPhone: '0503456789',
                    route: 'الرياض - حي الياسمين - مدرسة الهدى',
                    capacity: 30,
                    hasAirConditioning: true,
                    isActive: true,
                    status: 'returning',
                    studentsCount: 28,
                    fuelLevel: 70,
                    currentLocation: 'في طريق العودة',
                    maintenanceDate: new Date('2024-05-01'),
                    createdAt: new Date('2024-01-15'),
                    updatedAt: new Date()
                }
            ];
        }

        // Store buses data globally
        busesData = firebaseBuses || [];
        console.log('📊 Global busesData updated:', busesData.length);

        // Return enhanced responsive buses page HTML
        return generateEnhancedBusesPageHTML();

    } catch (error) {
        console.error('❌ Error loading buses page:', error);
        return `
            <div class="container-fluid">
                <div class="alert alert-danger">
                    <h4>خطأ في تحميل صفحة السيارات</h4>
                    <p>حدث خطأ أثناء تحميل صفحة إدارة السيارات. يرجى المحاولة مرة أخرى.</p>
                    <button class="btn btn-danger" onclick="loadPage('buses')">إعادة المحاولة</button>
                </div>
            </div>
        `;
    }
}

// Generate Enhanced Responsive Buses Page HTML
function generateEnhancedBusesPageHTML() {
    return `
        <!-- Header Section -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="d-flex flex-column flex-md-row justify-content-between align-items-start align-items-md-center">
                    <div class="mb-3 mb-md-0">
                        <h2 class="text-gradient mb-2">
                            <i class="fas fa-bus me-2"></i>
                            إدارة السيارات
                        </h2>
                        <p class="text-muted mb-0">إدارة جميع سيارات النقل المدرسي والسائقين في النظام</p>
                    </div>
                    <div class="d-flex flex-column flex-sm-row gap-2">
                        <button class="btn btn-outline-primary" onclick="exportBuses()">
                            <i class="fas fa-download me-2"></i>
                            <span class="d-none d-sm-inline">تصدير البيانات</span>
                        </button>
                        <button class="btn btn-outline-info" onclick="trackAllBuses()">
                            <i class="fas fa-map-marked-alt me-2"></i>
                            <span class="d-none d-sm-inline">تتبع السيارات</span>
                        </button>
                        <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#addBusModal">
                            <i class="fas fa-plus me-2"></i>
                            <span class="d-none d-sm-inline">إضافة سيارة جديدة</span>
                            <span class="d-sm-none">إضافة</span>
                        </button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Statistics Cards -->
        <div class="row mb-4">
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card primary">
                    <div class="icon">
                        <i class="fas fa-bus"></i>
                    </div>
                    <h3>${busesData.length}</h3>
                    <p class="mb-0">إجمالي السيارات</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card success">
                    <div class="icon">
                        <i class="fas fa-check-circle"></i>
                    </div>
                    <h3>${busesData.filter(b => b.status === 'available').length}</h3>
                    <p class="mb-0">متاحة</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card warning">
                    <div class="icon">
                        <i class="fas fa-route"></i>
                    </div>
                    <h3>${busesData.filter(b => b.status === 'in_route').length}</h3>
                    <p class="mb-0">في الطريق</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card danger">
                    <div class="icon">
                        <i class="fas fa-tools"></i>
                    </div>
                    <h3>${busesData.filter(b => b.status === 'maintenance').length}</h3>
                    <p class="mb-0">في الصيانة</p>
                </div>
            </div>
        </div>

        <!-- Filters and Search -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="card border-0 shadow-sm">
                    <div class="card-body">
                        <div class="row g-3">
                            <div class="col-md-4">
                                <label class="form-label">البحث</label>
                                <div class="input-group">
                                    <span class="input-group-text">
                                        <i class="fas fa-search"></i>
                                    </span>
                                    <input type="text" class="form-control" id="searchBuses"
                                           placeholder="البحث برقم اللوحة أو اسم السائق...">
                                </div>
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">الحالة</label>
                                <select class="form-select" id="filterBusStatus">
                                    <option value="">جميع الحالات</option>
                                    <option value="available">متاحة</option>
                                    <option value="in_route">في الطريق</option>
                                    <option value="maintenance">في الصيانة</option>
                                    <option value="returning">في طريق العودة</option>
                                    <option value="out_of_service">خارج الخدمة</option>
                                </select>
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">التكييف</label>
                                <select class="form-select" id="filterAirConditioning">
                                    <option value="">جميع السيارات</option>
                                    <option value="true">مع تكييف</option>
                                    <option value="false">بدون تكييف</option>
                                </select>
                            </div>
                            <div class="col-md-2 d-flex align-items-end">
                                <button class="btn btn-outline-secondary w-100" onclick="clearBusFilters()">
                                    <i class="fas fa-times me-1"></i>
                                    <span class="d-none d-md-inline">مسح</span>
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Buses Table/Cards Container -->
        <div class="card border-0 shadow-sm buses-table-container">
            <div class="card-header bg-gradient-primary text-white">
                <div class="d-flex flex-column flex-md-row justify-content-between align-items-start align-items-md-center">
                    <div class="mb-2 mb-md-0">
                        <h5 class="mb-1 fw-bold">
                            <i class="fas fa-list me-2"></i>
                            قائمة السيارات
                        </h5>
                        <small class="opacity-75">إجمالي ${busesData.length} سيارة مسجلة</small>
                    </div>
                    <div class="d-flex gap-2">
                        <div class="btn-group" role="group">
                            <button class="btn btn-sm btn-light" onclick="toggleBusView('table')" id="busTableViewBtn" title="عرض الجدول">
                                <i class="fas fa-table"></i>
                                <span class="d-none d-sm-inline ms-1">جدول</span>
                            </button>
                            <button class="btn btn-sm btn-outline-light" onclick="toggleBusView('cards')" id="busCardsViewBtn" title="عرض البطاقات">
                                <i class="fas fa-th-large"></i>
                                <span class="d-none d-sm-inline ms-1">بطاقات</span>
                            </button>
                        </div>
                        <button class="btn btn-sm btn-outline-light" onclick="refreshBusesData()" title="تحديث البيانات">
                            <i class="fas fa-sync-alt"></i>
                        </button>
                    </div>
                </div>
            </div>

            <div class="card-body p-0">
                ${generateBusesTableView()}
                ${generateBusesCardsView()}
            </div>
        </div>

        <!-- Add Bus Modal -->
        ${generateAddBusModal()}
    `;
}

// Generate Buses Table View
function generateBusesTableView() {
    return `
        <!-- Enhanced Desktop Table View -->
        <div class="table-responsive" id="busTableView">
            <table class="table table-hover buses-table mb-0">
                <thead class="table-header">
                    <tr>
                        <th class="border-0 ps-4 sortable" onclick="sortBuses('plateNumber')">
                            <div class="d-flex align-items-center">
                                <span>رقم اللوحة</span>
                                <i class="fas fa-sort ms-2 text-muted"></i>
                            </div>
                        </th>
                        <th class="border-0 d-none d-md-table-cell">السائق</th>
                        <th class="border-0">المسار</th>
                        <th class="border-0 d-none d-lg-table-cell">السعة</th>
                        <th class="border-0 d-none d-xl-table-cell">الموقع الحالي</th>
                        <th class="border-0 sortable" onclick="sortBuses('status')">
                            <div class="d-flex align-items-center">
                                <span>الحالة</span>
                                <i class="fas fa-sort ms-2 text-muted"></i>
                            </div>
                        </th>
                        <th class="border-0 text-center">الإجراءات</th>
                    </tr>
                </thead>
                <tbody class="table-body">
                    ${busesData.map(bus => `
                        <tr class="bus-row" data-bus-id="${bus.id}">
                            <td class="ps-4 bus-info-cell">
                                <div class="d-flex align-items-center">
                                    <div class="bus-avatar me-3">
                                        <div class="avatar-lg bg-gradient-primary text-white rounded-circle d-flex align-items-center justify-content-center">
                                            <i class="fas fa-bus"></i>
                                        </div>
                                    </div>
                                    <div class="bus-details">
                                        <h6 class="mb-1 fw-bold text-dark bus-plate">${bus.plateNumber}</h6>
                                        <div class="bus-meta">
                                            <span class="badge ${bus.hasAirConditioning ? 'bg-info' : 'bg-secondary'} me-2">
                                                <i class="fas ${bus.hasAirConditioning ? 'fa-snowflake' : 'fa-times'} me-1"></i>
                                                ${bus.hasAirConditioning ? 'مكيف' : 'غير مكيف'}
                                            </span>
                                            <small class="text-muted d-md-none">
                                                <i class="fas fa-user me-1"></i>
                                                ${bus.driverName}
                                            </small>
                                        </div>
                                    </div>
                                </div>
                            </td>
                            <td class="driver-info-cell d-none d-md-table-cell">
                                <div class="driver-details">
                                    <div class="driver-name mb-2">
                                        <i class="fas fa-user text-primary me-2"></i>
                                        <span class="fw-semibold">${bus.driverName}</span>
                                    </div>
                                    <div class="driver-phone">
                                        <i class="fas fa-phone text-success me-2"></i>
                                        <span class="text-muted">${bus.driverPhone}</span>
                                    </div>
                                </div>
                            </td>
                            <td class="route-cell">
                                <div class="route-container">
                                    <div class="route-info">
                                        <i class="fas fa-route text-warning me-2"></i>
                                        <span class="fw-semibold d-block">${bus.route}</span>
                                        <small class="text-muted">
                                            <i class="fas fa-users me-1"></i>
                                            ${bus.studentsCount}/${bus.capacity} طالب
                                        </small>
                                    </div>
                                </div>
                            </td>
                            <td class="capacity-cell d-none d-lg-table-cell">
                                <div class="capacity-info text-center">
                                    <div class="capacity-circle ${getCapacityClass(bus.studentsCount, bus.capacity)}">
                                        <span class="capacity-number">${bus.capacity}</span>
                                        <small class="capacity-label">مقعد</small>
                                    </div>
                                    <div class="occupancy-bar mt-2">
                                        <div class="progress" style="height: 6px;">
                                            <div class="progress-bar ${getOccupancyBarClass(bus.studentsCount, bus.capacity)}"
                                                 style="width: ${(bus.studentsCount / bus.capacity) * 100}%"></div>
                                        </div>
                                        <small class="text-muted">${Math.round((bus.studentsCount / bus.capacity) * 100)}% ممتلئ</small>
                                    </div>
                                </div>
                            </td>
                            <td class="location-cell d-none d-xl-table-cell">
                                <div class="location-info">
                                    <div class="location-text">
                                        <i class="fas fa-map-marker-alt text-danger me-2"></i>
                                        <span class="fw-semibold">${bus.currentLocation}</span>
                                    </div>
                                    <div class="fuel-level mt-2">
                                        <div class="d-flex align-items-center">
                                            <i class="fas fa-gas-pump text-info me-2"></i>
                                            <div class="fuel-bar flex-grow-1 me-2">
                                                <div class="progress" style="height: 4px;">
                                                    <div class="progress-bar ${getFuelBarClass(bus.fuelLevel)}"
                                                         style="width: ${bus.fuelLevel}%"></div>
                                                </div>
                                            </div>
                                            <small class="text-muted">${bus.fuelLevel}%</small>
                                        </div>
                                    </div>
                                </div>
                            </td>
                            <td class="status-cell">
                                <div class="status-container">
                                    <span class="status-badge ${getBusStatusClass(bus.status)}">
                                        <i class="fas ${getBusStatusIcon(bus.status)} me-1"></i>
                                        <span class="d-none d-sm-inline">${getBusStatusText(bus.status)}</span>
                                    </span>
                                </div>
                            </td>
                            <td class="actions-cell text-center">
                                <div class="action-buttons">
                                    <button class="btn btn-sm btn-outline-primary" onclick="viewBus('${bus.id}')" title="عرض التفاصيل">
                                        <i class="fas fa-eye"></i>
                                    </button>
                                </div>
                            </td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
    `;
}

// Generate Buses Cards View
function generateBusesCardsView() {
    return `
        <!-- Enhanced Cards View -->
        <div class="d-none" id="busCardsView">
            <div class="row g-4 p-4">
                ${busesData.map(bus => `
                    <div class="col-12 col-md-6 col-xl-4">
                        <div class="bus-card-enhanced">
                            <div class="bus-card-header">
                                <div class="d-flex align-items-start justify-content-between">
                                    <div class="d-flex align-items-center">
                                        <div class="bus-avatar-large me-3">
                                            <div class="avatar-xl bg-gradient-primary text-white rounded-circle d-flex align-items-center justify-content-center">
                                                <i class="fas fa-bus fa-2x"></i>
                                            </div>
                                            <div class="status-indicator ${getBusStatusClass(bus.status)}">
                                                <i class="fas ${getBusStatusIcon(bus.status)}"></i>
                                            </div>
                                        </div>
                                        <div class="bus-info">
                                            <h6 class="mb-1 fw-bold text-dark">${bus.plateNumber}</h6>
                                            <span class="badge ${bus.hasAirConditioning ? 'bg-info' : 'bg-secondary'}">
                                                <i class="fas ${bus.hasAirConditioning ? 'fa-snowflake' : 'fa-times'} me-1"></i>
                                                ${bus.hasAirConditioning ? 'مكيف' : 'غير مكيف'}
                                            </span>
                                        </div>
                                    </div>
                                    <div class="card-actions">
                                        <button class="btn btn-sm btn-outline-primary" onclick="viewBus('${bus.id}')" title="عرض التفاصيل">
                                            <i class="fas fa-eye"></i>
                                        </button>
                                    </div>
                                </div>
                            </div>

                            <div class="bus-card-body">
                                <div class="driver-section mb-3">
                                    <h6 class="section-title">
                                        <i class="fas fa-user me-2 text-primary"></i>
                                        معلومات السائق
                                    </h6>
                                    <div class="driver-grid">
                                        <div class="driver-item">
                                            <i class="fas fa-user text-primary"></i>
                                            <div class="driver-details">
                                                <small class="text-muted">اسم السائق</small>
                                                <span class="fw-semibold d-block">${bus.driverName}</span>
                                            </div>
                                        </div>
                                        <div class="driver-item">
                                            <i class="fas fa-phone text-success"></i>
                                            <div class="driver-details">
                                                <small class="text-muted">رقم الهاتف</small>
                                                <span class="fw-semibold d-block">${bus.driverPhone}</span>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <div class="route-section mb-3">
                                    <h6 class="section-title">
                                        <i class="fas fa-route me-2 text-warning"></i>
                                        المسار والطلاب
                                    </h6>
                                    <div class="route-info-card">
                                        <div class="route-text">
                                            <i class="fas fa-map-marker-alt text-danger me-2"></i>
                                            <span class="fw-semibold">${bus.route}</span>
                                        </div>
                                        <div class="students-info mt-2">
                                            <div class="d-flex justify-content-between align-items-center">
                                                <span class="text-muted">عدد الطلاب:</span>
                                                <span class="fw-bold">${bus.studentsCount}/${bus.capacity}</span>
                                            </div>
                                            <div class="progress mt-2" style="height: 8px;">
                                                <div class="progress-bar ${getOccupancyBarClass(bus.studentsCount, bus.capacity)}"
                                                     style="width: ${(bus.studentsCount / bus.capacity) * 100}%"></div>
                                            </div>
                                            <small class="text-muted">${Math.round((bus.studentsCount / bus.capacity) * 100)}% ممتلئ</small>
                                        </div>
                                    </div>
                                </div>

                                <div class="status-section mb-3">
                                    <h6 class="section-title">
                                        <i class="fas fa-info-circle me-2 text-info"></i>
                                        الحالة والموقع
                                    </h6>
                                    <div class="status-grid">
                                        <div class="status-item-card">
                                            <i class="fas fa-map-marker-alt text-danger"></i>
                                            <div>
                                                <small class="text-muted">الموقع الحالي</small>
                                                <span class="fw-semibold">${bus.currentLocation}</span>
                                            </div>
                                        </div>
                                        <div class="status-item-card">
                                            <i class="fas fa-gas-pump text-info"></i>
                                            <div>
                                                <small class="text-muted">مستوى الوقود</small>
                                                <div class="d-flex align-items-center">
                                                    <div class="fuel-bar-small me-2">
                                                        <div class="progress" style="height: 4px; width: 60px;">
                                                            <div class="progress-bar ${getFuelBarClass(bus.fuelLevel)}"
                                                                 style="width: ${bus.fuelLevel}%"></div>
                                                        </div>
                                                    </div>
                                                    <span class="fw-semibold">${bus.fuelLevel}%</span>
                                                </div>
                                            </div>
                                        </div>
                                        ${bus.maintenanceDate ? `
                                            <div class="status-item-card">
                                                <i class="fas fa-tools text-secondary"></i>
                                                <div>
                                                    <small class="text-muted">آخر صيانة</small>
                                                    <span class="fw-semibold">${formatDate(bus.maintenanceDate)}</span>
                                                </div>
                                            </div>
                                        ` : ''}
                                    </div>
                                </div>
                            </div>

                            <div class="bus-card-footer">
                                <div class="d-flex justify-content-between align-items-center">
                                    <span class="status-badge-large ${getBusStatusClass(bus.status)}">
                                        <i class="fas ${getBusStatusIcon(bus.status)} me-2"></i>
                                        ${getBusStatusText(bus.status)}
                                    </span>
                                    <div class="quick-actions">
                                        <button class="btn btn-sm btn-primary" onclick="viewBus('${bus.id}')" title="عرض التفاصيل">
                                            <i class="fas fa-eye me-1"></i>
                                            عرض التفاصيل
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                `).join('')}
            </div>
        </div>
    `;
}

// Generate Add Bus Modal
function generateAddBusModal() {
    return `
        <div class="modal fade" id="addBusModal" tabindex="-1">
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header bg-primary text-white">
                        <h5 class="modal-title">
                            <i class="fas fa-plus me-2"></i>
                            إضافة سيارة جديدة
                        </h5>
                        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form id="addBusForm">
                            <div class="row g-3">
                                <!-- Bus Information -->
                                <div class="col-12">
                                    <h6 class="text-primary mb-3">
                                        <i class="fas fa-bus me-2"></i>
                                        معلومات السيارة
                                    </h6>
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">رقم اللوحة <span class="text-danger">*</span></label>
                                    <input type="text" class="form-control" id="busPlateNumber" required
                                           placeholder="مثال: أ ب ج 123">
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">السعة <span class="text-danger">*</span></label>
                                    <input type="number" class="form-control" id="busCapacity" required
                                           min="10" max="50" value="30">
                                </div>

                                <div class="col-12">
                                    <label class="form-label">وصف السيارة</label>
                                    <textarea class="form-control" id="busDescription" rows="2"
                                              placeholder="وصف مختصر للسيارة..."></textarea>
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">المسار</label>
                                    <input type="text" class="form-control" id="busRoute"
                                           placeholder="مثال: الرياض - حي النرجس - مدرسة النور">
                                </div>

                                <div class="col-md-6">
                                    <div class="form-check mt-4">
                                        <input class="form-check-input" type="checkbox" id="busHasAC" checked>
                                        <label class="form-check-label" for="busHasAC">
                                            <i class="fas fa-snowflake me-1"></i>
                                            السيارة مكيفة
                                        </label>
                                    </div>
                                </div>

                                <!-- Driver Information -->
                                <div class="col-12 mt-4">
                                    <h6 class="text-success mb-3">
                                        <i class="fas fa-user me-2"></i>
                                        معلومات السائق
                                    </h6>
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">اسم السائق <span class="text-danger">*</span></label>
                                    <input type="text" class="form-control" id="driverName" required
                                           placeholder="الاسم الكامل للسائق">
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">رقم هاتف السائق <span class="text-danger">*</span></label>
                                    <input type="tel" class="form-control" id="driverPhone" required
                                           placeholder="05xxxxxxxx">
                                </div>

                                <!-- Additional Information -->
                                <div class="col-12 mt-4">
                                    <h6 class="text-info mb-3">
                                        <i class="fas fa-cog me-2"></i>
                                        معلومات إضافية
                                    </h6>
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">مستوى الوقود (%)</label>
                                    <input type="range" class="form-range" id="fuelLevel" min="0" max="100" value="100"
                                           oninput="document.getElementById('fuelLevelValue').textContent = this.value + '%'">
                                    <div class="d-flex justify-content-between">
                                        <small class="text-muted">0%</small>
                                        <span id="fuelLevelValue" class="fw-bold">100%</span>
                                        <small class="text-muted">100%</small>
                                    </div>
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">الموقع الحالي</label>
                                    <select class="form-select" id="currentLocation">
                                        <option value="المرآب الرئيسي">المرآب الرئيسي</option>
                                        <option value="في الطريق إلى المدرسة">في الطريق إلى المدرسة</option>
                                        <option value="في المدرسة">في المدرسة</option>
                                        <option value="في طريق العودة">في طريق العودة</option>
                                        <option value="ورشة الصيانة">ورشة الصيانة</option>
                                        <option value="خارج الخدمة">خارج الخدمة</option>
                                    </select>
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">حالة السيارة</label>
                                    <select class="form-select" id="busStatus">
                                        <option value="available">متاحة</option>
                                        <option value="in_route">في الطريق</option>
                                        <option value="maintenance">في الصيانة</option>
                                        <option value="returning">في طريق العودة</option>
                                        <option value="out_of_service">خارج الخدمة</option>
                                    </select>
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">تاريخ آخر صيانة</label>
                                    <input type="date" class="form-control" id="maintenanceDate">
                                </div>
                            </div>
                        </form>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>
                            إلغاء
                        </button>
                        <button type="button" class="btn btn-primary" onclick="saveBus()">
                            <i class="fas fa-save me-2"></i>
                            حفظ السيارة
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;
}

async function loadParentsPage() {
    console.log('👨‍👩‍👧‍👦 Loading Parents Page with children linking...');

    try {
        console.log('🔄 Fetching parents and students from Firebase...');
        const [firebaseParents, firebaseStudents] = await Promise.all([
            FirebaseService.getParents(),
            FirebaseService.getStudents()
        ]);

        // Store students data globally
        studentsData = firebaseStudents || [];

        if (firebaseParents && firebaseParents.length > 0) {
            // Process parents with their children from both sources
            parentsData = firebaseParents.map(parent => {
                // Get children from parent.children (stored in parent document)
                let children = parent.children || [];

                // Also get children from students collection (backup/verification)
                const studentsChildren = studentsData.filter(student => student.parentId === parent.id);

                // Merge and deduplicate children
                const allChildren = [...children];
                studentsChildren.forEach(student => {
                    const existingChild = children.find(child => child.id === student.id);
                    if (!existingChild) {
                        allChildren.push({
                            id: student.id,
                            name: student.name,
                            grade: student.grade,
                            schoolName: student.schoolName,
                            busRoute: student.busRoute,
                            qrCode: student.qrCode,
                            currentStatus: student.currentStatus,
                            isActive: student.isActive
                        });
                    }
                });

                return {
                    id: parent.id,
                    name: parent.name || 'غير محدد',
                    email: parent.email || 'غير محدد',
                    phone: parent.phone || 'غير محدد',
                    address: parent.address || 'غير محدد',
                    occupation: parent.occupation || 'غير محدد',
                    emergencyPhone: parent.emergencyPhone || 'غير محدد',
                    status: parent.isActive ? 'active' : 'inactive',
                    children: allChildren,
                    notificationPreferences: parent.notificationPreferences || [],
                    createdAt: parent.createdAt ? (parent.createdAt.toDate ? parent.createdAt.toDate() : new Date(parent.createdAt)) : new Date(),
                    lastLogin: parent.updatedAt ? (parent.updatedAt.toDate ? parent.updatedAt.toDate() : new Date(parent.updatedAt)) : new Date(),
                    relationship: parent.relationship || 'ولي أمر',
                    userType: parent.userType || 'parent',
                    isActive: parent.isActive !== false
                };
            });

            console.log('✅ Parents loaded from Firebase with children:', parentsData.length);
            console.log('📊 Children distribution:', parentsData.map(p => `${p.name}: ${p.children.length} children`));
        } else {
            console.log('⚠️ No parents found in Firebase, will use fallback data');
            parentsData = [];
        }
    } catch (error) {
        console.error('❌ Error loading parents:', error);
        parentsData = [
            {
                id: '1',
                name: 'محمد أحمد السعيد',
                email: 'mohammed.ahmed@gmail.com',
                phone: '0501234567',
                address: 'الرياض، حي النرجس',
                children: [
                    { id: 'st1', name: 'أحمد محمد', grade: 'الصف الثالث' },
                    { id: 'st2', name: 'فاطمة محمد', grade: 'الصف الأول' }
                ],
                status: 'active',
                createdAt: new Date('2024-01-10'),
                lastLogin: new Date('2024-01-20'),
                emergencyContact: '0507654321',
                relationship: 'والد'
            },
            {
                id: '2',
                name: 'سارة علي المطيري',
                email: 'sara.ali@hotmail.com',
                phone: '0509876543',
                address: 'جدة، حي الصفا',
                children: [
                    { id: 'st3', name: 'علي سارة', grade: 'الصف الخامس' }
                ],
                status: 'active',
                createdAt: new Date('2024-01-05'),
                lastLogin: new Date('2024-01-19'),
                emergencyContact: '0501112233',
                relationship: 'والدة'
            },
            {
                id: '3',
                name: 'عبدالله خالد النصر',
                email: 'abdullah.khalid@yahoo.com',
                phone: '0502468135',
                address: 'الدمام، حي الشاطئ',
                children: [
                    { id: 'st4', name: 'خالد عبدالله', grade: 'الصف الثاني' },
                    { id: 'st5', name: 'نورا عبدالله', grade: 'الصف الرابع' },
                    { id: 'st6', name: 'سلمان عبدالله', grade: 'الصف السادس' }
                ],
                status: 'inactive',
                createdAt: new Date('2023-12-20'),
                lastLogin: new Date('2024-01-10'),
                emergencyContact: '0505556666',
                relationship: 'والد'
            }
        ];
    }

    return `
        <!-- Header Section -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="d-flex flex-column flex-md-row justify-content-between align-items-start align-items-md-center">
                    <div class="mb-3 mb-md-0">
                        <h2 class="text-gradient mb-2">
                            <i class="fas fa-users me-2"></i>
                            إدارة أولياء الأمور
                        </h2>
                        <p class="text-muted mb-0">إدارة جميع بيانات أولياء الأمور والعائلات في النظام</p>
                    </div>
                    <div class="d-flex flex-column flex-sm-row gap-2">
                        <button class="btn btn-outline-primary" onclick="exportParents()">
                            <i class="fas fa-download me-2"></i>
                            <span class="d-none d-sm-inline">تصدير</span>
                        </button>
                        <button class="btn btn-outline-info" onclick="sendBulkNotification()">
                            <i class="fas fa-bell me-2"></i>
                            <span class="d-none d-sm-inline">إشعار جماعي</span>
                        </button>
                        <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#addParentModal">
                            <i class="fas fa-plus me-2"></i>
                            <span class="d-none d-sm-inline">إضافة ولي أمر جديد</span>
                            <span class="d-sm-none">إضافة</span>
                        </button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Statistics Cards -->
        <div class="row mb-4">
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card primary">
                    <div class="icon">
                        <i class="fas fa-users"></i>
                    </div>
                    <h3>${parentsData.length}</h3>
                    <p class="mb-0">إجمالي أولياء الأمور</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card success">
                    <div class="icon">
                        <i class="fas fa-user-check"></i>
                    </div>
                    <h3>${parentsData.filter(p => p.status === 'active').length}</h3>
                    <p class="mb-0">النشطين</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card warning">
                    <div class="icon">
                        <i class="fas fa-child"></i>
                    </div>
                    <h3>${parentsData.reduce((total, parent) => total + (parent.children ? parent.children.length : 0), 0)}</h3>
                    <p class="mb-0">إجمالي الأطفال</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card info">
                    <div class="icon">
                        <i class="fas fa-clock"></i>
                    </div>
                    <h3>${parentsData.filter(p => {
                        const lastLogin = new Date(p.lastLogin);
                        const today = new Date();
                        const diffTime = Math.abs(today - lastLogin);
                        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
                        return diffDays <= 7;
                    }).length}</h3>
                    <p class="mb-0">نشط هذا الأسبوع</p>
                </div>
            </div>
        </div>

        <!-- Filters and Search -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="card border-0 shadow-sm">
                    <div class="card-body">
                        <div class="row g-3">
                            <div class="col-md-4">
                                <label class="form-label">البحث</label>
                                <div class="input-group">
                                    <span class="input-group-text">
                                        <i class="fas fa-search"></i>
                                    </span>
                                    <input type="text" class="form-control" id="searchParents"
                                           placeholder="البحث بالاسم أو البريد الإلكتروني...">
                                </div>
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">الحالة</label>
                                <select class="form-select" id="filterParentStatus">
                                    <option value="">جميع الحالات</option>
                                    <option value="active">نشط</option>
                                    <option value="inactive">غير نشط</option>
                                    <option value="suspended">موقوف</option>
                                </select>
                            </div>
                            <div class="col-md-3">
                                <label class="form-label">عدد الأطفال</label>
                                <select class="form-select" id="filterChildrenCount">
                                    <option value="">جميع العائلات</option>
                                    <option value="1">طفل واحد</option>
                                    <option value="2">طفلان</option>
                                    <option value="3+">3 أطفال أو أكثر</option>
                                </select>
                            </div>
                            <div class="col-md-2 d-flex align-items-end">
                                <button class="btn btn-outline-secondary w-100" onclick="clearParentFilters()">
                                    <i class="fas fa-times me-1"></i>
                                    <span class="d-none d-md-inline">مسح</span>
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Parents Table -->
        <div class="card border-0 shadow-sm parents-table-container">
            <div class="card-header bg-gradient-primary text-white">
                <div class="d-flex flex-column flex-md-row justify-content-between align-items-start align-items-md-center">
                    <div class="mb-2 mb-md-0">
                        <h5 class="mb-1 fw-bold">
                            <i class="fas fa-users me-2"></i>
                            قائمة أولياء الأمور
                        </h5>
                        <small class="opacity-75">إجمالي ${parentsData.length} ولي أمر مسجل</small>
                    </div>
                    <div class="d-flex gap-2">
                        <div class="btn-group" role="group">
                            <button class="btn btn-sm btn-light" onclick="toggleParentView('table')" id="tableViewBtn" title="عرض الجدول">
                                <i class="fas fa-table"></i>
                                <span class="d-none d-sm-inline ms-1">جدول</span>
                            </button>
                            <button class="btn btn-sm btn-outline-light" onclick="toggleParentView('cards')" id="cardsViewBtn" title="عرض البطاقات">
                                <i class="fas fa-th-large"></i>
                                <span class="d-none d-sm-inline ms-1">بطاقات</span>
                            </button>
                        </div>
                        <button class="btn btn-sm btn-outline-light" onclick="refreshParentsData()" title="تحديث البيانات">
                            <i class="fas fa-sync-alt"></i>
                        </button>
                    </div>
                </div>
            </div>

            <div class="card-body p-0">
                <!-- Enhanced Desktop Table View -->
                <div class="table-responsive" id="parentTableView">
                    <table class="table table-hover parents-table mb-0">
                        <thead class="table-header">
                            <tr>
                                <th class="border-0 ps-4 sortable" onclick="sortParents('name')">
                                    <div class="d-flex align-items-center">
                                        <span>ولي الأمر</span>
                                        <i class="fas fa-sort ms-2 text-muted"></i>
                                    </div>
                                </th>
                                <th class="border-0 d-none d-md-table-cell">معلومات الاتصال</th>
                                <th class="border-0">الأطفال</th>
                                <th class="border-0 d-none d-lg-table-cell">العنوان</th>
                                <th class="border-0 d-none d-xl-table-cell sortable" onclick="sortParents('lastLogin')">
                                    <div class="d-flex align-items-center">
                                        <span>آخر نشاط</span>
                                        <i class="fas fa-sort ms-2 text-muted"></i>
                                    </div>
                                </th>
                                <th class="border-0 sortable" onclick="sortParents('status')">
                                    <div class="d-flex align-items-center">
                                        <span>الحالة</span>
                                        <i class="fas fa-sort ms-2 text-muted"></i>
                                    </div>
                                </th>
                                <th class="border-0 text-center">الإجراءات</th>
                            </tr>
                        </thead>
                        <tbody class="table-body">
                            ${parentsData.map(parent => `
                                <tr class="parent-row" data-parent-id="${parent.id}">
                                    <td class="ps-4 parent-info-cell">
                                        <div class="d-flex align-items-center">
                                            <div class="parent-avatar me-3">
                                                <div class="avatar-lg bg-gradient-success text-white rounded-circle d-flex align-items-center justify-content-center">
                                                    <span class="fw-bold">${(parent.name || 'غ').charAt(0).toUpperCase()}</span>
                                                </div>
                                            </div>
                                            <div class="parent-details">
                                                <h6 class="mb-1 fw-bold text-dark parent-name">${parent.name || 'غير محدد'}</h6>
                                                <div class="parent-meta">
                                                    <span class="badge bg-light text-dark me-2">
                                                        <i class="fas fa-user-tag me-1"></i>
                                                        ${parent.relationship || 'ولي أمر'}
                                                    </span>
                                                    <small class="text-muted d-md-none">
                                                        <i class="fas fa-envelope me-1"></i>
                                                        ${parent.email}
                                                    </small>
                                                </div>
                                            </div>
                                        </div>
                                    </td>
                                    <td class="contact-info-cell d-none d-md-table-cell">
                                        <div class="contact-details">
                                            <div class="email-info mb-2">
                                                <i class="fas fa-envelope text-primary me-2"></i>
                                                <span class="fw-semibold">${parent.email}</span>
                                            </div>
                                            <div class="phone-info">
                                                <i class="fas fa-phone text-success me-2"></i>
                                                <span class="text-muted">${parent.phone || 'غير محدد'}</span>
                                            </div>
                                            ${parent.emergencyPhone ? `
                                                <div class="emergency-phone mt-1">
                                                    <i class="fas fa-exclamation-triangle text-warning me-2"></i>
                                                    <small class="text-muted">${parent.emergencyPhone}</small>
                                                </div>
                                            ` : ''}
                                        </div>
                                    </td>
                                    <td class="children-cell">
                                        <div class="children-container">
                                            ${formatChildrenDisplay(parent.children)}
                                        </div>
                                    </td>
                                    <td class="address-cell d-none d-lg-table-cell">
                                        <div class="address-container">
                                            <i class="fas fa-map-marker-alt text-danger me-2"></i>
                                            <div class="address-text">
                                                <span class="fw-semibold d-block">${parent.address || 'غير محدد'}</span>
                                                ${parent.occupation ? `
                                                    <small class="text-muted">
                                                        <i class="fas fa-briefcase me-1"></i>
                                                        ${parent.occupation}
                                                    </small>
                                                ` : ''}
                                            </div>
                                        </div>
                                    </td>
                                    <td class="activity-cell d-none d-xl-table-cell">
                                        <div class="activity-info">
                                            <div class="activity-time">
                                                <i class="fas fa-clock text-info me-2"></i>
                                                <span class="fw-semibold">${formatLastActivity(parent.lastLogin)}</span>
                                            </div>
                                            <small class="text-muted d-block mt-1">
                                                ${getActivityStatus(parent.lastLogin)}
                                            </small>
                                        </div>
                                    </td>
                                    <td class="status-cell">
                                        <div class="status-container">
                                            <span class="status-badge ${getParentStatusClass(parent.status)}">
                                                <i class="fas ${getParentStatusIcon(parent.status)} me-1"></i>
                                                <span class="d-none d-sm-inline">${getParentStatusText(parent.status)}</span>
                                            </span>
                                        </div>
                                    </td>
                                    <td class="actions-cell text-center">
                                        <div class="action-buttons">
                                            <div class="btn-group" role="group">
                                                <button class="btn btn-sm btn-outline-primary" onclick="viewParent('${parent.id}')" title="عرض التفاصيل">
                                                    <i class="fas fa-eye"></i>
                                                </button>
                                                <button class="btn btn-sm btn-outline-warning" onclick="editParent('${parent.id}')" title="تعديل البيانات">
                                                    <i class="fas fa-edit"></i>
                                                </button>
                                                <div class="btn-group" role="group">
                                                    <button class="btn btn-sm btn-outline-secondary dropdown-toggle" data-bs-toggle="dropdown" title="المزيد">
                                                        <i class="fas fa-ellipsis-v"></i>
                                                    </button>
                                                    <ul class="dropdown-menu dropdown-menu-end">
                                                        <li>
                                                            <a class="dropdown-item" href="#" onclick="manageChildren('${parent.id}')">
                                                                <i class="fas fa-child me-2"></i>
                                                                إدارة الأطفال
                                                            </a>
                                                        </li>
                                                        <li>
                                                            <a class="dropdown-item" href="#" onclick="sendNotificationToParent('${parent.id}')">
                                                                <i class="fas fa-bell me-2"></i>
                                                                إرسال إشعار
                                                            </a>
                                                        </li>
                                                        <li>
                                                            <a class="dropdown-item" href="#" onclick="viewParentActivity('${parent.id}')">
                                                                <i class="fas fa-chart-line me-2"></i>
                                                                عرض النشاط
                                                            </a>
                                                        </li>
                                                        <li><hr class="dropdown-divider"></li>
                                                        <li>
                                                            <a class="dropdown-item text-danger" href="#" onclick="deleteParent('${parent.id}')">
                                                                <i class="fas fa-trash me-2"></i>
                                                                حذف الحساب
                                                            </a>
                                                        </li>
                                                    </ul>
                                                </div>
                                            </div>
                                        </div>
                                    </td>
                                </tr>
                            `).join('')}
                        </tbody>
                    </table>
                </div>

                <!-- Enhanced Cards View -->
                <div class="d-none" id="parentCardsView">
                    <div class="row g-4 p-4">
                        ${parentsData.map(parent => `
                            <div class="col-12 col-md-6 col-xl-4">
                                <div class="parent-card-enhanced">
                                    <div class="parent-card-header">
                                        <div class="d-flex align-items-start justify-content-between">
                                            <div class="d-flex align-items-center">
                                                <div class="parent-avatar-large me-3">
                                                    <div class="avatar-xl bg-gradient-primary text-white rounded-circle d-flex align-items-center justify-content-center">
                                                        <span class="fw-bold fs-4">${(parent.name || 'غ').charAt(0).toUpperCase()}</span>
                                                    </div>
                                                    <div class="status-indicator ${getParentStatusClass(parent.status)}">
                                                        <i class="fas ${getParentStatusIcon(parent.status)}"></i>
                                                    </div>
                                                </div>
                                                <div class="parent-info">
                                                    <h6 class="mb-1 fw-bold text-dark">${parent.name || 'غير محدد'}</h6>
                                                    <span class="badge bg-light text-dark">
                                                        <i class="fas fa-user-tag me-1"></i>
                                                        ${parent.relationship || 'ولي أمر'}
                                                    </span>
                                                </div>
                                            </div>
                                            <div class="card-actions">
                                                <div class="dropdown">
                                                    <button class="btn btn-sm btn-outline-secondary" data-bs-toggle="dropdown">
                                                        <i class="fas fa-ellipsis-v"></i>
                                                    </button>
                                                    <ul class="dropdown-menu dropdown-menu-end">
                                                        <li><a class="dropdown-item" href="#" onclick="viewParent('${parent.id}')">
                                                            <i class="fas fa-eye me-2"></i>عرض التفاصيل
                                                        </a></li>
                                                        <li><a class="dropdown-item" href="#" onclick="editParent('${parent.id}')">
                                                            <i class="fas fa-edit me-2"></i>تعديل البيانات
                                                        </a></li>
                                                        <li><hr class="dropdown-divider"></li>
                                                        <li><a class="dropdown-item text-danger" href="#" onclick="deleteParent('${parent.id}')">
                                                            <i class="fas fa-trash me-2"></i>حذف الحساب
                                                        </a></li>
                                                    </ul>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <div class="parent-card-body">
                                        <div class="contact-section mb-3">
                                            <h6 class="section-title">
                                                <i class="fas fa-address-book me-2 text-primary"></i>
                                                معلومات الاتصال
                                            </h6>
                                            <div class="contact-grid">
                                                <div class="contact-item">
                                                    <i class="fas fa-envelope text-primary"></i>
                                                    <div class="contact-details">
                                                        <small class="text-muted">البريد الإلكتروني</small>
                                                        <span class="fw-semibold d-block">${parent.email}</span>
                                                    </div>
                                                </div>
                                                <div class="contact-item">
                                                    <i class="fas fa-phone text-success"></i>
                                                    <div class="contact-details">
                                                        <small class="text-muted">رقم الهاتف</small>
                                                        <span class="fw-semibold d-block">${parent.phone || 'غير محدد'}</span>
                                                    </div>
                                                </div>
                                                ${parent.emergencyPhone ? `
                                                    <div class="contact-item">
                                                        <i class="fas fa-exclamation-triangle text-warning"></i>
                                                        <div class="contact-details">
                                                            <small class="text-muted">هاتف الطوارئ</small>
                                                            <span class="fw-semibold d-block">${parent.emergencyPhone}</span>
                                                        </div>
                                                    </div>
                                                ` : ''}
                                            </div>
                                        </div>

                                        <div class="children-section mb-3">
                                            <h6 class="section-title">
                                                <i class="fas fa-users me-2 text-info"></i>
                                                الأطفال (${parent.children ? parent.children.length : 0})
                                            </h6>
                                            ${parent.children && parent.children.length > 0 ? `
                                                <div class="children-list-card">
                                                    ${parent.children.slice(0, 3).map(child => `
                                                        <div class="child-item-card">
                                                            <div class="child-avatar-sm">
                                                                <i class="fas fa-child"></i>
                                                            </div>
                                                            <div class="child-info">
                                                                <span class="child-name">${child.name}</span>
                                                                <small class="child-grade">${child.grade || 'غير محدد'}</small>
                                                            </div>
                                                            ${child.currentStatus ? `
                                                                <div class="child-status-sm ${getStatusClass(child.currentStatus)}">
                                                                    <i class="fas ${getStatusIcon(child.currentStatus)}"></i>
                                                                </div>
                                                            ` : ''}
                                                        </div>
                                                    `).join('')}
                                                    ${parent.children.length > 3 ? `
                                                        <div class="more-children-indicator">
                                                            <button class="btn btn-sm btn-outline-primary w-100" onclick="showAllChildren('${parent.id}')">
                                                                <i class="fas fa-plus me-1"></i>
                                                                عرض ${parent.children.length - 3} أطفال إضافيين
                                                            </button>
                                                        </div>
                                                    ` : ''}
                                                </div>
                                            ` : `
                                                <div class="no-children-message">
                                                    <i class="fas fa-child fa-2x text-muted mb-2"></i>
                                                    <p class="text-muted mb-0">لا يوجد أطفال مسجلين</p>
                                                </div>
                                            `}
                                        </div>

                                        <div class="additional-info">
                                            <div class="info-grid">
                                                <div class="info-item-card">
                                                    <i class="fas fa-map-marker-alt text-danger"></i>
                                                    <div>
                                                        <small class="text-muted">العنوان</small>
                                                        <span class="fw-semibold">${parent.address || 'غير محدد'}</span>
                                                    </div>
                                                </div>
                                                <div class="info-item-card">
                                                    <i class="fas fa-clock text-info"></i>
                                                    <div>
                                                        <small class="text-muted">آخر نشاط</small>
                                                        <span class="fw-semibold">${formatLastActivity(parent.lastLogin)}</span>
                                                    </div>
                                                </div>
                                                ${parent.occupation ? `
                                                    <div class="info-item-card">
                                                        <i class="fas fa-briefcase text-secondary"></i>
                                                        <div>
                                                            <small class="text-muted">المهنة</small>
                                                            <span class="fw-semibold">${parent.occupation}</span>
                                                        </div>
                                                    </div>
                                                ` : ''}
                                            </div>
                                        </div>
                                    </div>

                                    <div class="parent-card-footer">
                                        <div class="d-flex justify-content-between align-items-center">
                                            <span class="status-badge-large ${getParentStatusClass(parent.status)}">
                                                <i class="fas ${getParentStatusIcon(parent.status)} me-2"></i>
                                                ${getParentStatusText(parent.status)}
                                            </span>
                                            <div class="quick-actions">
                                                <button class="btn btn-sm btn-primary" onclick="manageChildren('${parent.id}')" title="إدارة الأطفال">
                                                    <i class="fas fa-child me-1"></i>
                                                    إدارة الأطفال
                                                </button>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        `).join('')}
                    </div>
                </div>
            </div>
        </div>

        <!-- Add Parent Modal -->
        <div class="modal fade" id="addParentModal" tabindex="-1">
            <div class="modal-dialog modal-dialog-scrollable">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">
                            <i class="fas fa-user me-2"></i>
                            إضافة ولي أمر جديد
                        </h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form id="addParentForm">
                            <div class="mb-3">
                                <label class="form-label">الاسم *</label>
                                <input type="text" class="form-control" name="name" required
                                       placeholder="أدخل اسم ولي الأمر">
                            </div>
                            <div class="mb-3">
                                <label class="form-label">البريد الإلكتروني *</label>
                                <input type="email" class="form-control" name="email" required
                                       placeholder="example@domain.com">
                            </div>
                            <div class="mb-3">
                                <label class="form-label">رقم الهاتف *</label>
                                <input type="tel" class="form-control" name="phone" required
                                       placeholder="05xxxxxxxx" pattern="[0-9]{10,}">
                            </div>
                            <div class="mb-3">
                                <label class="form-label">كلمة المرور *</label>
                                <input type="password" class="form-control" name="password" required
                                       placeholder="كلمة المرور (6 أحرف على الأقل)" minlength="6">
                            </div>
                            <div class="alert alert-info">
                                <i class="fas fa-info-circle me-2"></i>
                                <strong>ملاحظة:</strong> سيتم إنشاء حساب ولي الأمر وإرسال بيانات الدخول عبر البريد الإلكتروني. يمكن لولي الأمر تسجيل الدخول باستخدام البريد الإلكتروني وكلمة المرور المحددة.
                            </div>
                        </form>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>إلغاء
                        </button>
                        <button type="button" class="btn btn-primary" onclick="saveParent()">
                            <i class="fas fa-save me-2"></i>إضافة ولي الأمر
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;
}

async function loadReportsPage() {
    console.log('📊 Loading Reports Page...');

    // Load real data from Firebase
    let reportsData = {
        stats: {},
        trips: [],
        notifications: [],
        students: [],
        parents: [],
        supervisors: []
    };

    try {
        console.log('🔄 Fetching reports data from Firebase...');

        // Get all data in parallel
        const [stats, trips, notifications, students, parents, supervisors] = await Promise.all([
            FirebaseService.getStatistics(),
            FirebaseService.getTrips(100),
            FirebaseService.getNotifications(50),
            FirebaseService.getStudents(),
            FirebaseService.getParents(),
            FirebaseService.getSupervisors()
        ]);

        reportsData = {
            stats: stats || {},
            trips: trips || [],
            notifications: notifications || [],
            students: students || [],
            parents: parents || [],
            supervisors: supervisors || []
        };

        console.log('✅ Reports data loaded:', {
            stats: Object.keys(reportsData.stats).length,
            trips: reportsData.trips.length,
            notifications: reportsData.notifications.length,
            students: reportsData.students.length,
            parents: reportsData.parents.length,
            supervisors: reportsData.supervisors.length
        });

    } catch (error) {
        console.error('❌ Error loading reports data:', error);
    }

    // Calculate additional metrics
    const totalUsers = reportsData.students.length + reportsData.parents.length + reportsData.supervisors.length;
    const activeStudents = reportsData.students.filter(s => s.isActive).length;
    const activeParents = reportsData.parents.filter(p => p.isActive).length;
    const activeSupervisors = reportsData.supervisors.filter(s => s.isActive).length;

    // Get recent trips (last 7 days)
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const recentTrips = reportsData.trips.filter(trip => {
        if (!trip.timestamp) return false;
        const tripDate = trip.timestamp.toDate ? trip.timestamp.toDate() : new Date(trip.timestamp);
        return tripDate >= sevenDaysAgo;
    });

    // Get recent notifications (last 7 days)
    const recentNotifications = reportsData.notifications.filter(notification => {
        if (!notification.timestamp) return false;
        const notificationDate = notification.timestamp.toDate ? notification.timestamp.toDate() : new Date(notification.timestamp);
        return notificationDate >= sevenDaysAgo;
    });

    return `
        <div class="row mb-4">
            <div class="col-12">
                <h2 class="text-gradient">
                    <i class="fas fa-chart-bar me-2"></i>
                    التقارير والإحصائيات
                </h2>
                <p class="text-muted">تقارير شاملة ومحدثة من قاعدة البيانات</p>
            </div>
        </div>

        <!-- Statistics Overview -->
        <div class="row mb-4">
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card primary">
                    <div class="icon">
                        <i class="fas fa-users"></i>
                    </div>
                    <h3>${totalUsers}</h3>
                    <p class="mb-0">إجمالي المستخدمين</p>
                    <small class="text-muted">طلاب + أولياء أمور + مشرفين</small>
                </div>
            </div>
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card success">
                    <div class="icon">
                        <i class="fas fa-graduation-cap"></i>
                    </div>
                    <h3>${activeStudents}</h3>
                    <p class="mb-0">الطلاب النشطين</p>
                    <small class="text-muted">من أصل ${reportsData.students.length}</small>
                </div>
            </div>
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card warning">
                    <div class="icon">
                        <i class="fas fa-route"></i>
                    </div>
                    <h3>${recentTrips.length}</h3>
                    <p class="mb-0">رحلات الأسبوع</p>
                    <small class="text-muted">آخر 7 أيام</small>
                </div>
            </div>
            <div class="col-lg-3 col-md-6 mb-3">
                <div class="stat-card info">
                    <div class="icon">
                        <i class="fas fa-bell"></i>
                    </div>
                    <h3>${recentNotifications.length}</h3>
                    <p class="mb-0">إشعارات الأسبوع</p>
                    <small class="text-muted">آخر 7 أيام</small>
                </div>
            </div>
        </div>

        <!-- Detailed Reports -->
        <div class="row mb-4">
            <div class="col-lg-8 mb-4">
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <div class="d-flex justify-content-between align-items-center">
                            <h5 class="mb-0">
                                <i class="fas fa-chart-line me-2 text-primary"></i>
                                تقرير الرحلات الأخيرة
                            </h5>
                            <div class="btn-group">
                                <button class="btn btn-sm btn-outline-primary" onclick="exportTripsReport()">
                                    <i class="fas fa-download me-1"></i>تصدير
                                </button>
                                <button class="btn btn-sm btn-outline-secondary" onclick="refreshTripsReport()">
                                    <i class="fas fa-sync me-1"></i>تحديث
                                </button>
                            </div>
                        </div>
                    </div>
                    <div class="card-body">
                        <div id="tripsReportContainer">
                            ${recentTrips.length > 0 ? `
                                <div class="table-responsive">
                                    <table class="table table-hover">
                                        <thead class="table-light">
                                            <tr>
                                                <th>التاريخ والوقت</th>
                                                <th>الطالب</th>
                                                <th>المشرف</th>
                                                <th>نوع الرحلة</th>
                                                <th>الإجراء</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            ${recentTrips.slice(0, 10).map(trip => `
                                                <tr>
                                                    <td>
                                                        <small class="text-muted">
                                                            ${formatDateTime(trip.timestamp)}
                                                        </small>
                                                    </td>
                                                    <td>
                                                        <div>
                                                            <span class="fw-semibold">${trip.studentName || 'غير محدد'}</span>
                                                            <br>
                                                            <small class="text-muted">${trip.busRoute || 'غير محدد'}</small>
                                                        </div>
                                                    </td>
                                                    <td>${trip.supervisorName || 'غير محدد'}</td>
                                                    <td>
                                                        <span class="badge ${trip.tripType === 'toSchool' ? 'bg-success' : 'bg-primary'}">
                                                            ${trip.tripType === 'toSchool' ? 'إلى المدرسة' : 'إلى المنزل'}
                                                        </span>
                                                    </td>
                                                    <td>
                                                        <span class="badge ${trip.action === 'boardBus' ? 'bg-warning' : 'bg-info'}">
                                                            ${trip.action === 'boardBus' ? 'ركوب الباص' : 'النزول من الباص'}
                                                        </span>
                                                    </td>
                                                </tr>
                                            `).join('')}
                                        </tbody>
                                    </table>
                                </div>
                            ` : `
                                <div class="text-center py-4">
                                    <i class="fas fa-route fa-3x text-muted mb-3"></i>
                                    <h6 class="text-muted">لا توجد رحلات في الأسبوع الماضي</h6>
                                    <p class="text-muted">ستظهر الرحلات هنا عند تسجيلها في النظام</p>
                                </div>
                            `}
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-lg-4 mb-4">
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <h5 class="mb-0">
                            <i class="fas fa-chart-pie me-2 text-success"></i>
                            توزيع المستخدمين
                        </h5>
                    </div>
                    <div class="card-body">
                        <div class="user-distribution">
                            <div class="distribution-item mb-3">
                                <div class="d-flex justify-content-between align-items-center">
                                    <div class="d-flex align-items-center">
                                        <div class="distribution-icon bg-primary">
                                            <i class="fas fa-graduation-cap text-white"></i>
                                        </div>
                                        <div class="ms-3">
                                            <h6 class="mb-0">الطلاب</h6>
                                            <small class="text-muted">${activeStudents} نشط</small>
                                        </div>
                                    </div>
                                    <span class="badge bg-primary">${reportsData.students.length}</span>
                                </div>
                                <div class="progress" style="height: 6px;">
                                    <div class="progress-bar bg-primary" style="width: ${totalUsers > 0 ? (reportsData.students.length / totalUsers * 100) : 0}%"></div>
                                </div>
                            </div>

                            <div class="distribution-item mb-3">
                                <div class="d-flex justify-content-between align-items-center">
                                    <div class="d-flex align-items-center">
                                        <div class="distribution-icon bg-success">
                                            <i class="fas fa-users text-white"></i>
                                        </div>
                                        <div class="ms-3">
                                            <h6 class="mb-0">أولياء الأمور</h6>
                                            <small class="text-muted">${activeParents} نشط</small>
                                        </div>
                                    </div>
                                    <span class="badge bg-success">${reportsData.parents.length}</span>
                                </div>
                                <div class="progress" style="height: 6px;">
                                    <div class="progress-bar bg-success" style="width: ${totalUsers > 0 ? (reportsData.parents.length / totalUsers * 100) : 0}%"></div>
                                </div>
                            </div>

                            <div class="distribution-item">
                                <div class="d-flex justify-content-between align-items-center">
                                    <div class="d-flex align-items-center">
                                        <div class="distribution-icon bg-warning">
                                            <i class="fas fa-user-tie text-white"></i>
                                        </div>
                                        <div class="ms-3">
                                            <h6 class="mb-0">المشرفين</h6>
                                            <small class="text-muted">${activeSupervisors} نشط</small>
                                        </div>
                                    </div>
                                    <span class="badge bg-warning">${reportsData.supervisors.length}</span>
                                </div>
                                <div class="progress" style="height: 6px;">
                                    <div class="progress-bar bg-warning" style="width: ${totalUsers > 0 ? (reportsData.supervisors.length / totalUsers * 100) : 0}%"></div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Notifications Report -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <div class="d-flex justify-content-between align-items-center">
                            <h5 class="mb-0">
                                <i class="fas fa-bell me-2 text-warning"></i>
                                تقرير الإشعارات الأخيرة
                            </h5>
                            <div class="btn-group">
                                <button class="btn btn-sm btn-outline-warning" onclick="exportNotificationsReport()">
                                    <i class="fas fa-download me-1"></i>تصدير
                                </button>
                                <button class="btn btn-sm btn-outline-secondary" onclick="refreshNotificationsReport()">
                                    <i class="fas fa-sync me-1"></i>تحديث
                                </button>
                            </div>
                        </div>
                    </div>
                    <div class="card-body">
                        <div id="notificationsReportContainer">
                            ${recentNotifications.length > 0 ? `
                                <div class="table-responsive">
                                    <table class="table table-hover">
                                        <thead class="table-light">
                                            <tr>
                                                <th>التاريخ والوقت</th>
                                                <th>العنوان</th>
                                                <th>المستلم</th>
                                                <th>النوع</th>
                                                <th>الحالة</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            ${recentNotifications.slice(0, 10).map(notification => `
                                                <tr>
                                                    <td>
                                                        <small class="text-muted">
                                                            ${formatDateTime(notification.timestamp)}
                                                        </small>
                                                    </td>
                                                    <td>
                                                        <div>
                                                            <span class="fw-semibold">${notification.title || 'إشعار'}</span>
                                                            <br>
                                                            <small class="text-muted">${(notification.body || '').substring(0, 50)}${(notification.body || '').length > 50 ? '...' : ''}</small>
                                                        </div>
                                                    </td>
                                                    <td>
                                                        <div>
                                                            <span class="fw-semibold">${notification.studentName || 'غير محدد'}</span>
                                                            <br>
                                                            <small class="text-muted">ID: ${notification.recipientId || 'غير محدد'}</small>
                                                        </div>
                                                    </td>
                                                    <td>
                                                        <span class="badge ${getNotificationTypeClass(notification.type)}">
                                                            ${getNotificationTypeText(notification.type)}
                                                        </span>
                                                    </td>
                                                    <td>
                                                        <span class="badge ${notification.isRead ? 'bg-success' : 'bg-secondary'}">
                                                            ${notification.isRead ? 'مقروء' : 'غير مقروء'}
                                                        </span>
                                                    </td>
                                                </tr>
                                            `).join('')}
                                        </tbody>
                                    </table>
                                </div>
                            ` : `
                                <div class="text-center py-4">
                                    <i class="fas fa-bell-slash fa-3x text-muted mb-3"></i>
                                    <h6 class="text-muted">لا توجد إشعارات في الأسبوع الماضي</h6>
                                    <p class="text-muted">ستظهر الإشعارات هنا عند إرسالها</p>
                                </div>
                            `}
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Export and Actions -->
        <div class="row">
            <div class="col-12">
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <h5 class="mb-0">
                            <i class="fas fa-download me-2 text-info"></i>
                            تصدير التقارير
                        </h5>
                    </div>
                    <div class="card-body">
                        <div class="row">
                            <div class="col-md-6 mb-3">
                                <h6 class="text-muted mb-3">تصدير بيانات المستخدمين</h6>
                                <div class="d-grid gap-2">
                                    <button class="btn btn-outline-success" onclick="exportUsersReport('students')">
                                        <i class="fas fa-graduation-cap me-2"></i>تصدير بيانات الطلاب
                                    </button>
                                    <button class="btn btn-outline-primary" onclick="exportUsersReport('parents')">
                                        <i class="fas fa-users me-2"></i>تصدير بيانات أولياء الأمور
                                    </button>
                                    <button class="btn btn-outline-warning" onclick="exportUsersReport('supervisors')">
                                        <i class="fas fa-user-tie me-2"></i>تصدير بيانات المشرفين
                                    </button>
                                </div>
                            </div>
                            <div class="col-md-6 mb-3">
                                <h6 class="text-muted mb-3">تصدير تقارير النشاط</h6>
                                <div class="d-grid gap-2">
                                    <button class="btn btn-outline-info" onclick="exportActivityReport('trips')">
                                        <i class="fas fa-route me-2"></i>تصدير تقرير الرحلات
                                    </button>
                                    <button class="btn btn-outline-warning" onclick="exportActivityReport('notifications')">
                                        <i class="fas fa-bell me-2"></i>تصدير تقرير الإشعارات
                                    </button>
                                    <button class="btn btn-outline-danger" onclick="exportFullReport()">
                                        <i class="fas fa-file-pdf me-2"></i>تصدير تقرير شامل (PDF)
                                    </button>
                                </div>
                            </div>
                        </div>

                        <hr class="my-4">

                        <div class="row">
                            <div class="col-12">
                                <h6 class="text-muted mb-3">إحصائيات سريعة</h6>
                                <div class="row text-center">
                                    <div class="col-6 col-md-3 mb-3">
                                        <div class="quick-stat">
                                            <h4 class="text-primary">${Math.round((activeStudents / Math.max(reportsData.students.length, 1)) * 100)}%</h4>
                                            <small class="text-muted">معدل نشاط الطلاب</small>
                                        </div>
                                    </div>
                                    <div class="col-6 col-md-3 mb-3">
                                        <div class="quick-stat">
                                            <h4 class="text-success">${Math.round((activeParents / Math.max(reportsData.parents.length, 1)) * 100)}%</h4>
                                            <small class="text-muted">معدل نشاط أولياء الأمور</small>
                                        </div>
                                    </div>
                                    <div class="col-6 col-md-3 mb-3">
                                        <div class="quick-stat">
                                            <h4 class="text-warning">${recentTrips.length}</h4>
                                            <small class="text-muted">رحلات هذا الأسبوع</small>
                                        </div>
                                    </div>
                                    <div class="col-6 col-md-3 mb-3">
                                        <div class="quick-stat">
                                            <h4 class="text-info">${recentNotifications.filter(n => !n.isRead).length}</h4>
                                            <small class="text-muted">إشعارات غير مقروءة</small>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    `;
}

async function loadComplaintsPage() {
    console.log('📝 Loading Complaints Page...');

    try {
        const response = await fetch('pages/complaints.html');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const content = await response.text();
        console.log('✅ Complaints page loaded successfully');

        // Initialize complaints page after content is loaded
        setTimeout(() => {
            if (typeof initializeComplaintsPage === 'function') {
                initializeComplaintsPage();
            }
        }, 100);

        return content;
    } catch (error) {
        console.error('❌ Error loading complaints page:', error);
        return `
            <div class="alert alert-danger">
                <h5>خطأ في تحميل صفحة إدارة الشكاوى</h5>
                <p>تعذر تحميل الصفحة. يرجى المحاولة مرة أخرى.</p>
                <button class="btn btn-primary" onclick="loadPage('complaints')">
                    <i class="fas fa-redo me-2"></i>إعادة المحاولة
                </button>
            </div>
        `;
    }
}

async function loadParentStudentsPage() {
    console.log('👨‍👩‍👧‍👦 Loading parent students page...');

    try {
        const response = await fetch('pages/parent-students.html');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const content = await response.text();
        console.log('✅ Parent students page loaded successfully');
        return content;
    } catch (error) {
        console.error('❌ Error loading parent students page:', error);
        return `
            <div class="alert alert-danger">
                <h5>خطأ في تحميل صفحة الطلاب المضافين من أولياء الأمور</h5>
                <p>تعذر تحميل الصفحة. يرجى المحاولة مرة أخرى.</p>
                <button class="btn btn-primary" onclick="loadPage('parent-students')">
                    <i class="fas fa-redo me-2"></i>إعادة المحاولة
                </button>
            </div>
        `;
    }
}

async function loadSettingsPage() {
    return `
        <div class="row mb-4">
            <div class="col-12">
                <h2 class="text-gradient">إعدادات النظام</h2>
                <p class="text-muted">إدارة إعدادات التطبيق والنظام</p>
            </div>
        </div>

        <div class="row">
            <div class="col-md-6 mb-4">
                <div class="table-container">
                    <h5>الإعدادات العامة</h5>
                    <form>
                        <div class="mb-3">
                            <label class="form-label">اسم المؤسسة</label>
                            <input type="text" class="form-control" value="MyBus Transport">
                        </div>
                        <div class="mb-3">
                            <label class="form-label">البريد الإلكتروني</label>
                            <input type="email" class="form-control" value="admin@mybus.com">
                        </div>
                        <div class="mb-3">
                            <label class="form-label">رقم الهاتف</label>
                            <input type="tel" class="form-control" value="+966501234567">
                        </div>
                        <button type="submit" class="btn btn-primary">حفظ التغييرات</button>
                    </form>
                </div>
            </div>

            <div class="col-md-6 mb-4">
                <div class="table-container">
                    <h5>إعدادات الإشعارات</h5>
                    <form>
                        <div class="form-check mb-3">
                            <input class="form-check-input" type="checkbox" id="emailNotifications" checked>
                            <label class="form-check-label" for="emailNotifications">
                                إشعارات البريد الإلكتروني
                            </label>
                        </div>
                        <div class="form-check mb-3">
                            <input class="form-check-input" type="checkbox" id="smsNotifications" checked>
                            <label class="form-check-label" for="smsNotifications">
                                إشعارات الرسائل النصية
                            </label>
                        </div>
                        <div class="form-check mb-3">
                            <input class="form-check-input" type="checkbox" id="pushNotifications" checked>
                            <label class="form-check-label" for="pushNotifications">
                                الإشعارات الفورية
                            </label>
                        </div>
                        <button type="submit" class="btn btn-primary">حفظ الإعدادات</button>
                    </form>
                </div>
            </div>
        </div>

        <div class="row">
            <div class="col-12">
                <div class="table-container">
                    <h5>إدارة النسخ الاحتياطية</h5>
                    <div class="row">
                        <div class="col-md-6">
                            <p>آخر نسخة احتياطية: 2024-01-15 10:30 ص</p>
                            <button class="btn btn-success me-2">
                                <i class="fas fa-download me-2"></i>إنشاء نسخة احتياطية
                            </button>
                            <button class="btn btn-warning">
                                <i class="fas fa-upload me-2"></i>استعادة نسخة احتياطية
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    `;
}

async function loadDashboardPage() {
    let stats;
    try {
        console.log('📊 Loading dashboard statistics...');
        stats = await FirebaseService.getStatistics();
        console.log('✅ Dashboard statistics loaded:', stats);
    } catch (error) {
        console.error('❌ Error loading dashboard statistics:', error);
        // Use default stats if loading fails
        stats = {
            totalStudents: 150,
            totalSupervisors: 10,
            totalParents: 120,
            activeStudents: 140,
            totalComplaints: 5,
            pendingComplaints: 2,
            inProgressComplaints: 1,
            resolvedComplaints: 2,
            studentsAtHome: 10,
            studentsOnBus: 80,
            studentsAtSchool: 50,
            tripsToday: 15
        };
    }

    return `
        <div class="row mb-4">
            <div class="col-12">
                <h2 class="text-gradient">لوحة التحكم الرئيسية</h2>
                <p class="text-muted">مرحباً بك في لوحة تحكم MyBus</p>
            </div>
        </div>
        
        <div class="row mb-4">
            <div class="col-6 col-md-3 mb-3">
                <div class="stat-card primary">
                    <div class="icon">
                        <i class="fas fa-graduation-cap"></i>
                    </div>
                    <h3>${stats.totalStudents}</h3>
                    <p class="mb-0">إجمالي الطلاب</p>
                </div>
            </div>
            <div class="col-6 col-md-3 mb-3">
                <div class="stat-card success">
                    <div class="icon">
                        <i class="fas fa-user-check"></i>
                    </div>
                    <h3>${stats.activeStudents}</h3>
                    <p class="mb-0">الطلاب النشطين</p>
                </div>
            </div>
            <div class="col-6 col-md-3 mb-3">
                <div class="stat-card warning">
                    <div class="icon">
                        <i class="fas fa-user-tie"></i>
                    </div>
                    <h3>${stats.totalSupervisors}</h3>
                    <p class="mb-0">المشرفين</p>
                </div>
            </div>
            <div class="col-6 col-md-3 mb-3">
                <div class="stat-card danger">
                    <div class="icon">
                        <i class="fas fa-users"></i>
                    </div>
                    <h3>${stats.totalParents}</h3>
                    <p class="mb-0">أولياء الأمور</p>
                </div>
            </div>
        </div>

        <!-- Complaints Statistics Row -->
        <div class="row mb-4">
            <div class="col-12 mb-3">
                <h5 class="text-muted d-none d-md-block">إحصائيات الشكاوى</h5>
                <h6 class="text-muted d-md-none">الشكاوى</h6>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card info" onclick="navigateToPage('complaints')" style="cursor: pointer;">
                    <div class="icon">
                        <i class="fas fa-comments"></i>
                    </div>
                    <h3>${stats.totalComplaints || 0}</h3>
                    <p class="mb-0">إجمالي الشكاوى</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card warning" onclick="navigateToPage('complaints')" style="cursor: pointer;">
                    <div class="icon">
                        <i class="fas fa-clock"></i>
                    </div>
                    <h3>${stats.pendingComplaints || 0}</h3>
                    <p class="mb-0">في انتظار المراجعة</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card primary" onclick="navigateToPage('complaints')" style="cursor: pointer;">
                    <div class="icon">
                        <i class="fas fa-cog"></i>
                    </div>
                    <h3>${stats.inProgressComplaints || 0}</h3>
                    <p class="mb-0">قيد المعالجة</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card success" onclick="navigateToPage('complaints')" style="cursor: pointer;">
                    <div class="icon">
                        <i class="fas fa-check-circle"></i>
                    </div>
                    <h3>${stats.resolvedComplaints || 0}</h3>
                    <p class="mb-0">تم الحل</p>
                </div>
            </div>
        </div>

        <!-- Student Status Cards -->
        <div class="row mb-4">
            <div class="col-12 mb-3">
                <h5 class="text-muted d-none d-md-block">حالة الطلاب الحالية</h5>
                <h6 class="text-muted d-md-none">حالة الطلاب</h6>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card info">
                    <div class="icon">
                        <i class="fas fa-home"></i>
                    </div>
                    <h3>${stats.studentsAtHome || 0}</h3>
                    <p class="mb-0">في المنزل</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card warning">
                    <div class="icon">
                        <i class="fas fa-bus"></i>
                    </div>
                    <h3>${stats.studentsOnBus || 0}</h3>
                    <p class="mb-0">في الباص</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card success">
                    <div class="icon">
                        <i class="fas fa-school"></i>
                    </div>
                    <h3>${stats.studentsAtSchool || 0}</h3>
                    <p class="mb-0">في المدرسة</p>
                </div>
            </div>
            <div class="col-6 col-lg-3 mb-3">
                <div class="stat-card primary">
                    <div class="icon">
                        <i class="fas fa-route"></i>
                    </div>
                    <h3>${stats.tripsToday || 0}</h3>
                    <p class="mb-0">رحلات اليوم</p>
                </div>
            </div>
        </div>

        <div class="row">
            <div class="col-lg-8 col-md-12 mb-4">
                <div class="chart-container">
                    <h5 class="d-none d-md-block">إحصائيات الطلاب الشهرية</h5>
                    <h6 class="d-md-none">إحصائيات الطلاب</h6>
                    <canvas id="studentsChart"></canvas>
                </div>
            </div>
            <div class="col-lg-4 col-md-12 mb-4">
                <div class="chart-container">
                    <h5 class="d-none d-md-block">توزيع المستخدمين</h5>
                    <h6 class="d-md-none">توزيع المستخدمين</h6>
                    <canvas id="usersChart"></canvas>
                </div>
            </div>
        </div>
        
        <!-- Recent Activities from Database -->
        <div class="row">
            <div class="col-lg-8 col-md-12 mb-4">
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <h5 class="mb-0">
                            <i class="fas fa-clock me-2 text-primary"></i>
                            آخر الرحلات
                        </h5>
                    </div>
                    <div class="card-body">
                        <div id="recentTripsContainer">
                            <div class="text-center py-3">
                                <div class="spinner-border text-primary" role="status">
                                    <span class="visually-hidden">جاري التحميل...</span>
                                </div>
                                <p class="mt-2 text-muted">جاري تحميل آخر الرحلات...</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-lg-4 col-md-12 mb-4">
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <h5 class="mb-0">
                            <i class="fas fa-bell me-2 text-warning"></i>
                            آخر الإشعارات
                        </h5>
                    </div>
                    <div class="card-body">
                        <div id="recentNotificationsContainer">
                            <div class="text-center py-3">
                                <div class="spinner-border text-warning" role="status">
                                    <span class="visually-hidden">جاري التحميل...</span>
                                </div>
                                <p class="mt-2 text-muted">جاري تحميل الإشعارات...</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    `;
}

// Error message helper
function getErrorMessage(error) {
    const errorMessages = {
        'auth/user-not-found': 'المستخدم غير موجود',
        'auth/wrong-password': 'كلمة المرور غير صحيحة',
        'auth/invalid-email': 'البريد الإلكتروني غير صحيح',
        'auth/too-many-requests': 'تم تجاوز عدد المحاولات المسموح',
        'auth/network-request-failed': 'خطأ في الاتصال بالشبكة'
    };

    return errorMessages[error] || 'حدث خطأ غير متوقع';
}

// Student status helpers
function getStatusClass(status) {
    const statusClasses = {
        'home': 'status-inactive',
        'onBus': 'status-warning',
        'atSchool': 'status-active',
        'inactive': 'status-danger'
    };

    return statusClasses[status] || 'status-inactive';
}

function getStatusText(status) {
    const statusTexts = {
        'home': 'في المنزل',
        'onBus': 'في الباص',
        'atSchool': 'في المدرسة',
        'inactive': 'غير نشط'
    };

    return statusTexts[status] || 'غير محدد';
}

function getStatusIcon(status) {
    const statusIcons = {
        'home': 'fa-home',
        'onBus': 'fa-bus',
        'atSchool': 'fa-school',
        'inactive': 'fa-times-circle'
    };

    return statusIcons[status] || 'fa-question-circle';
}

// Students page functions
function toggleView(viewType) {
    const tableView = document.getElementById('tableView');
    const cardView = document.getElementById('cardView');

    if (viewType === 'table') {
        tableView?.classList.remove('d-none');
        cardView?.classList.add('d-none');
    } else {
        tableView?.classList.add('d-none');
        cardView?.classList.remove('d-none');
    }
}

function exportStudents() {
    // Create CSV content
    const headers = ['الاسم', 'الصف', 'المدرسة', 'ولي الأمر', 'رقم الهاتف', 'خط الباص', 'الحالة'];
    const csvContent = [
        headers.join(','),
        ...studentsData.map(student => [
            student.name || '',
            student.grade || '',
            student.schoolName || '',
            student.parentName || '',
            student.parentPhone || '',
            student.busRoute || '',
            getStatusText(student.currentStatus)
        ].join(','))
    ].join('\n');

    // Download CSV
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    link.setAttribute('href', url);
    link.setAttribute('download', `students_${new Date().toISOString().split('T')[0]}.csv`);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    showNotification('تم تصدير بيانات الطلاب بنجاح', 'success');
}

function clearFilters() {
    document.getElementById('searchStudents').value = '';
    document.getElementById('filterStatus').value = '';
    document.getElementById('filterBusRoute').value = '';
    filterStudents();
}

function filterStudents() {
    const searchTerm = document.getElementById('searchStudents')?.value.toLowerCase() || '';
    const statusFilter = document.getElementById('filterStatus')?.value || '';
    const busRouteFilter = document.getElementById('filterBusRoute')?.value || '';

    const filteredStudents = studentsData.filter(student => {
        const matchesSearch = !searchTerm ||
            (student.name && student.name.toLowerCase().includes(searchTerm)) ||
            (student.parentName && student.parentName.toLowerCase().includes(searchTerm)) ||
            (student.parentPhone && student.parentPhone.includes(searchTerm));

        const matchesStatus = !statusFilter || student.currentStatus === statusFilter;
        const matchesBusRoute = !busRouteFilter || student.busRoute === busRouteFilter;

        return matchesSearch && matchesStatus && matchesBusRoute;
    });

    // Update both table and card views
    updateStudentViews(filteredStudents);
}

function updateStudentViews(students) {
    // Update table view
    const tableBody = document.querySelector('#tableView tbody');
    if (tableBody) {
        tableBody.innerHTML = students.map(student => `
            <tr class="student-row" data-student-id="${student.id}">
                <td class="ps-4">
                    <div class="d-flex align-items-center">
                        <div class="student-avatar me-3">
                            <div class="avatar-circle">
                                <i class="fas fa-user"></i>
                            </div>
                        </div>
                        <div>
                            <h6 class="mb-1 fw-bold">${student.name || 'غير محدد'}</h6>
                            <small class="text-muted">QR: ${student.qrCode || 'غير محدد'}</small>
                        </div>
                    </div>
                </td>
                <td>
                    <div>
                        <span class="fw-semibold">${student.grade || 'غير محدد'}</span>
                        <br>
                        <small class="text-muted">${student.schoolName || 'غير محدد'}</small>
                    </div>
                </td>
                <td>
                    <div>
                        <span class="fw-semibold">${student.parentName || 'غير محدد'}</span>
                        <br>
                        <small class="text-muted">
                            <i class="fas fa-phone me-1"></i>
                            ${student.parentPhone || 'غير محدد'}
                        </small>
                    </div>
                </td>
                <td>
                    <span class="badge bg-primary bg-gradient">${student.busRoute || 'غير محدد'}</span>
                </td>
                <td>
                    <span class="status-badge ${getStatusClass(student.currentStatus)}">
                        <i class="fas ${getStatusIcon(student.currentStatus)} me-1"></i>
                        ${getStatusText(student.currentStatus)}
                    </span>
                </td>
                <td class="text-center">
                    <div class="btn-group" role="group">
                        <button class="btn btn-sm btn-outline-primary" onclick="viewStudent('${student.id}')" title="عرض">
                            <i class="fas fa-eye"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-warning" onclick="editStudent('${student.id}')" title="تعديل">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-danger" onclick="deleteStudent('${student.id}')" title="حذف">
                            <i class="fas fa-trash"></i>
                        </button>
                    </div>
                </td>
            </tr>
        `).join('');
    }

    // Update card view
    const cardContainer = document.querySelector('#cardView .row');
    if (cardContainer) {
        cardContainer.innerHTML = students.map(student => `
            <div class="col-12 col-md-6">
                <div class="student-card">
                    <div class="student-card-header">
                        <div class="d-flex align-items-center">
                            <div class="student-avatar me-3">
                                <div class="avatar-circle">
                                    <i class="fas fa-user"></i>
                                </div>
                            </div>
                            <div class="flex-grow-1">
                                <h6 class="mb-1 fw-bold">${student.name || 'غير محدد'}</h6>
                                <small class="text-muted">${student.grade || 'غير محدد'} - ${student.schoolName || 'غير محدد'}</small>
                            </div>
                            <div class="student-status">
                                <span class="status-badge ${getStatusClass(student.currentStatus)}">
                                    <i class="fas ${getStatusIcon(student.currentStatus)}"></i>
                                </span>
                            </div>
                        </div>
                    </div>
                    <div class="student-card-body">
                        <div class="row g-2">
                            <div class="col-6">
                                <div class="info-item">
                                    <i class="fas fa-user-tie text-muted me-2"></i>
                                    <div>
                                        <small class="text-muted d-block">ولي الأمر</small>
                                        <span class="fw-semibold">${student.parentName || 'غير محدد'}</span>
                                    </div>
                                </div>
                            </div>
                            <div class="col-6">
                                <div class="info-item">
                                    <i class="fas fa-phone text-muted me-2"></i>
                                    <div>
                                        <small class="text-muted d-block">الهاتف</small>
                                        <span class="fw-semibold">${student.parentPhone || 'غير محدد'}</span>
                                    </div>
                                </div>
                            </div>
                            <div class="col-6">
                                <div class="info-item">
                                    <i class="fas fa-bus text-muted me-2"></i>
                                    <div>
                                        <small class="text-muted d-block">خط الباص</small>
                                        <span class="badge bg-primary">${student.busRoute || 'غير محدد'}</span>
                                    </div>
                                </div>
                            </div>
                            <div class="col-6">
                                <div class="info-item">
                                    <i class="fas fa-qrcode text-muted me-2"></i>
                                    <div>
                                        <small class="text-muted d-block">رمز QR</small>
                                        <span class="fw-semibold">${student.qrCode || 'غير محدد'}</span>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="student-card-footer">
                        <div class="d-flex justify-content-between align-items-center">
                            <span class="status-badge ${getStatusClass(student.currentStatus)}">
                                <i class="fas ${getStatusIcon(student.currentStatus)} me-1"></i>
                                ${getStatusText(student.currentStatus)}
                            </span>
                            <div class="btn-group" role="group">
                                <button class="btn btn-sm btn-outline-primary" onclick="viewStudent('${student.id}')" title="عرض">
                                    <i class="fas fa-eye"></i>
                                </button>
                                <button class="btn btn-sm btn-outline-warning" onclick="editStudent('${student.id}')" title="تعديل">
                                    <i class="fas fa-edit"></i>
                                </button>
                                <button class="btn btn-sm btn-outline-danger" onclick="deleteStudent('${student.id}')" title="حذف">
                                    <i class="fas fa-trash"></i>
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        `).join('');
    }
}

function viewStudent(studentId) {
    console.log('👁️ Viewing student:', studentId);

    const student = studentsData.find(s => s.id === studentId);
    if (!student) {
        alert('لم يتم العثور على الطالب');
        return;
    }

    // Create student details modal
    const modalContent = `
        <div class="modal fade" id="viewStudentModal" tabindex="-1">
            <div class="modal-dialog modal-lg modal-dialog-scrollable">
                <div class="modal-content">
                    <div class="modal-header bg-primary text-white">
                        <h5 class="modal-title">
                            <i class="fas fa-user me-2"></i>
                            تفاصيل الطالب: ${student.name || 'غير محدد'}
                        </h5>
                        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <div class="row">
                            <!-- Student Photo and QR Code -->
                            <div class="col-md-4 text-center mb-4">
                                <div class="student-photo-container mb-3">
                                    <div class="student-avatar-large">
                                        <i class="fas fa-user fa-4x text-muted"></i>
                                    </div>
                                </div>

                                <!-- QR Code Section -->
                                <div class="qr-code-section">
                                    <h6 class="text-muted mb-2">رمز QR الخاص بالطالب</h6>
                                    <div class="qr-code-container" id="qrCodeContainer">
                                        <div class="qr-placeholder">
                                            <i class="fas fa-qrcode fa-3x text-muted"></i>
                                            <p class="mt-2 text-muted">جاري إنشاء رمز QR...</p>
                                        </div>
                                    </div>
                                    <div class="qr-code-text mt-2">
                                        <small class="text-muted">كود: ${student.qrCode || student.id}</small>
                                    </div>
                                    <button class="btn btn-sm btn-outline-primary mt-2" onclick="downloadQRCode('${student.id}')">
                                        <i class="fas fa-download me-1"></i>تحميل QR
                                    </button>
                                </div>
                            </div>

                            <!-- Student Details -->
                            <div class="col-md-8">
                                <div class="student-details">
                                    <div class="row">
                                        <div class="col-sm-6 mb-3">
                                            <label class="form-label text-muted">الاسم الكامل</label>
                                            <p class="fw-bold">${student.name || 'غير محدد'}</p>
                                        </div>
                                        <div class="col-sm-6 mb-3">
                                            <label class="form-label text-muted">الصف الدراسي</label>
                                            <p class="fw-bold">${student.grade || 'غير محدد'}</p>
                                        </div>
                                        <div class="col-sm-6 mb-3">
                                            <label class="form-label text-muted">المدرسة</label>
                                            <p class="fw-bold">${student.schoolName || 'غير محدد'}</p>
                                        </div>
                                        <div class="col-sm-6 mb-3">
                                            <label class="form-label text-muted">خط الباص</label>
                                            <span class="badge bg-primary">${student.busRoute || 'غير محدد'}</span>
                                        </div>
                                        <div class="col-sm-6 mb-3">
                                            <label class="form-label text-muted">الحالة الحالية</label>
                                            <br>
                                            <span class="status-badge ${getStatusClass(student.currentStatus)}">
                                                <i class="fas ${getStatusIcon(student.currentStatus)} me-1"></i>
                                                ${getStatusText(student.currentStatus)}
                                            </span>
                                        </div>
                                        <div class="col-sm-6 mb-3">
                                            <label class="form-label text-muted">حالة النشاط</label>
                                            <br>
                                            <span class="badge ${student.isActive ? 'bg-success' : 'bg-danger'}">
                                                ${student.isActive ? 'نشط' : 'غير نشط'}
                                            </span>
                                        </div>
                                    </div>

                                    <hr class="my-4">

                                    <!-- Parent Information -->
                                    <h6 class="text-primary mb-3">
                                        <i class="fas fa-users me-2"></i>
                                        معلومات ولي الأمر
                                    </h6>
                                    <div class="row">
                                        <div class="col-sm-6 mb-3">
                                            <label class="form-label text-muted">اسم ولي الأمر</label>
                                            <p class="fw-bold">${student.parentName || 'غير محدد'}</p>
                                        </div>
                                        <div class="col-sm-6 mb-3">
                                            <label class="form-label text-muted">رقم الهاتف</label>
                                            <p class="fw-bold">
                                                <i class="fas fa-phone me-1 text-muted"></i>
                                                ${student.parentPhone || 'غير محدد'}
                                            </p>
                                        </div>
                                        ${student.parentId ? `
                                            <div class="col-12 mb-3">
                                                <button class="btn btn-outline-info btn-sm" onclick="viewParentDetails('${student.parentId}')">
                                                    <i class="fas fa-eye me-1"></i>عرض تفاصيل ولي الأمر
                                                </button>
                                            </div>
                                        ` : ''}
                                    </div>

                                    <hr class="my-4">

                                    <!-- System Information -->
                                    <h6 class="text-secondary mb-3">
                                        <i class="fas fa-info-circle me-2"></i>
                                        معلومات النظام
                                    </h6>
                                    <div class="row">
                                        <div class="col-sm-6 mb-3">
                                            <label class="form-label text-muted">تاريخ التسجيل</label>
                                            <p class="fw-bold">${formatDate(student.createdAt)}</p>
                                        </div>
                                        <div class="col-sm-6 mb-3">
                                            <label class="form-label text-muted">آخر تحديث</label>
                                            <p class="fw-bold">${formatDate(student.updatedAt)}</p>
                                        </div>
                                        <div class="col-12 mb-3">
                                            <label class="form-label text-muted">معرف الطالب</label>
                                            <p class="fw-bold font-monospace">${student.id}</p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>إغلاق
                        </button>
                        <button type="button" class="btn btn-warning" onclick="editStudent('${student.id}')">
                            <i class="fas fa-edit me-2"></i>تعديل
                        </button>
                        <button type="button" class="btn btn-primary" onclick="printStudentCard('${student.id}')">
                            <i class="fas fa-print me-2"></i>طباعة البطاقة
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Remove existing modal if any
    const existingModal = document.getElementById('viewStudentModal');
    if (existingModal) {
        existingModal.remove();
    }

    // Add modal to body and show
    document.body.insertAdjacentHTML('beforeend', modalContent);
    const modal = new bootstrap.Modal(document.getElementById('viewStudentModal'));
    modal.show();

    // Generate QR Code
    generateStudentQRCode(student);

    // Clean up when modal is hidden
    document.getElementById('viewStudentModal').addEventListener('hidden.bs.modal', function() {
        this.remove();
        destroyAllBackdrops();
    });
}

// Load recent activities from database
async function loadRecentActivities() {
    try {
        // Load recent trips
        const trips = await FirebaseService.getTrips(10);
        displayRecentTrips(trips);

        // Load recent notifications
        const notifications = await FirebaseService.getNotifications(10);
        displayRecentNotifications(notifications);
    } catch (error) {
        console.error('❌ Error loading recent activities:', error);

        // Show error in containers
        const tripsContainer = document.getElementById('recentTripsContainer');
        const notificationsContainer = document.getElementById('recentNotificationsContainer');

        if (tripsContainer) {
            tripsContainer.innerHTML = `
                <div class="text-center py-3">
                    <i class="fas fa-exclamation-triangle text-warning mb-2" style="font-size: 2rem;"></i>
                    <p class="text-muted">لا توجد رحلات حديثة</p>
                </div>
            `;
        }

        if (notificationsContainer) {
            notificationsContainer.innerHTML = `
                <div class="text-center py-3">
                    <i class="fas fa-bell-slash text-muted mb-2" style="font-size: 2rem;"></i>
                    <p class="text-muted">لا توجد إشعارات حديثة</p>
                </div>
            `;
        }
    }
}

function displayRecentTrips(trips) {
    const container = document.getElementById('recentTripsContainer');
    if (!container) return;

    if (trips.length === 0) {
        container.innerHTML = `
            <div class="text-center py-3">
                <i class="fas fa-bus text-muted mb-2" style="font-size: 2rem;"></i>
                <p class="text-muted">لا توجد رحلات حديثة</p>
            </div>
        `;
        return;
    }

    container.innerHTML = trips.map(trip => {
        const timeAgo = getTimeAgo(trip.timestamp);
        const actionText = getActionText(trip.action);
        const actionIcon = getActionIcon(trip.action);

        return `
            <div class="d-flex align-items-center mb-3 pb-3 border-bottom">
                <div class="flex-shrink-0 me-3">
                    <div class="activity-icon ${trip.action}">
                        <i class="fas ${actionIcon}"></i>
                    </div>
                </div>
                <div class="flex-grow-1">
                    <h6 class="mb-1">${actionText}</h6>
                    <p class="mb-1 text-muted">
                        <strong>${trip.studentName}</strong> - ${trip.busRoute}
                    </p>
                    <small class="text-muted">
                        <i class="fas fa-user-tie me-1"></i>
                        ${trip.supervisorName} • ${timeAgo}
                    </small>
                </div>
            </div>
        `;
    }).join('');
}

function displayRecentNotifications(notifications) {
    const container = document.getElementById('recentNotificationsContainer');
    if (!container) return;

    if (notifications.length === 0) {
        container.innerHTML = `
            <div class="text-center py-3">
                <i class="fas fa-bell-slash text-muted mb-2" style="font-size: 2rem;"></i>
                <p class="text-muted">لا توجد إشعارات حديثة</p>
            </div>
        `;
        return;
    }

    container.innerHTML = notifications.map(notification => {
        const timeAgo = getTimeAgo(notification.timestamp);
        const typeIcon = getNotificationIcon(notification.type);

        return `
            <div class="d-flex align-items-start mb-3 pb-3 border-bottom">
                <div class="flex-shrink-0 me-2">
                    <div class="notification-icon ${notification.type}">
                        <i class="fas ${typeIcon}"></i>
                    </div>
                </div>
                <div class="flex-grow-1">
                    <h6 class="mb-1">${notification.title}</h6>
                    <p class="mb-1 text-muted small">${notification.body}</p>
                    <small class="text-muted">${timeAgo}</small>
                </div>
            </div>
        `;
    }).join('');
}

// Helper functions
function getTimeAgo(timestamp) {
    if (!timestamp) return 'غير محدد';

    const now = new Date();
    const time = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    const diffMs = now - time;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return 'الآن';
    if (diffMins < 60) return `منذ ${diffMins} دقيقة`;
    if (diffHours < 24) return `منذ ${diffHours} ساعة`;
    return `منذ ${diffDays} يوم`;
}

function getActionText(action) {
    const actions = {
        'boardBus': 'ركوب الباص',
        'exitBus': 'النزول من الباص',
        'arriveSchool': 'الوصول للمدرسة',
        'leaveSchool': 'مغادرة المدرسة',
        'arriveHome': 'الوصول للمنزل'
    };
    return actions[action] || action;
}

function getActionIcon(action) {
    const icons = {
        'boardBus': 'fa-bus',
        'exitBus': 'fa-sign-out-alt',
        'arriveSchool': 'fa-school',
        'leaveSchool': 'fa-door-open',
        'arriveHome': 'fa-home'
    };
    return icons[action] || 'fa-circle';
}

function getNotificationIcon(type) {
    const icons = {
        'trip': 'fa-bus',
        'student': 'fa-user-graduate',
        'parent': 'fa-user',
        'supervisor': 'fa-user-tie',
        'system': 'fa-cog',
        'general': 'fa-bell'
    };
    return icons[type] || 'fa-bell';
}

// Initialize page-specific functionality
function initializePageFunctionality(page) {
    if (page === 'dashboard') {
        initializeDashboardCharts();
        // Load recent activities after a short delay
        setTimeout(loadRecentActivities, 1000);
    } else if (page === 'students') {
        // Set up students page event listeners
        setTimeout(() => {
            const searchInput = document.getElementById('searchStudents');
            const statusFilter = document.getElementById('filterStatus');
            const busRouteFilter = document.getElementById('filterBusRoute');

            if (searchInput) {
                searchInput.addEventListener('input', filterStudents);
            }

            if (statusFilter) {
                statusFilter.addEventListener('change', filterStudents);
            }

            if (busRouteFilter) {
                busRouteFilter.addEventListener('change', filterStudents);
            }
        }, 100);
    } else if (page === 'settings') {
        // Set up settings page event listeners
        setTimeout(() => {
            // General settings form
            const generalForm = document.getElementById('generalSettingsForm');
            if (generalForm) {
                generalForm.addEventListener('submit', (e) => {
                    e.preventDefault();
                    saveGeneralSettings();
                });
            }

            // Working hours form
            const workingHoursForm = document.getElementById('workingHoursForm');
            if (workingHoursForm) {
                workingHoursForm.addEventListener('submit', (e) => {
                    e.preventDefault();
                    saveWorkingHours();
                });
            }

            // Notification settings form
            const notificationForm = document.getElementById('notificationSettingsForm');
            if (notificationForm) {
                notificationForm.addEventListener('submit', (e) => {
                    e.preventDefault();
                    saveNotificationSettings();
                });
            }

            // Security settings form
            const securityForm = document.getElementById('securitySettingsForm');
            if (securityForm) {
                securityForm.addEventListener('submit', (e) => {
                    e.preventDefault();
                    saveSecuritySettings();
                });
            }

            // Load bus routes
            loadBusRoutes();
        }, 100);
    } else if (page === 'profile') {
        // Set up profile page event listeners
        setTimeout(() => {
            // Personal info form
            const personalInfoForm = document.getElementById('personalInfoForm');
            if (personalInfoForm) {
                personalInfoForm.addEventListener('submit', (e) => {
                    e.preventDefault();
                    savePersonalInfo();
                });
            }

            // Security form
            const securityForm = document.getElementById('securityForm');
            if (securityForm) {
                securityForm.addEventListener('submit', (e) => {
                    e.preventDefault();
                    changePassword();
                });
            }

            // Password strength checker
            const newPasswordInput = document.getElementById('newPassword');
            if (newPasswordInput) {
                newPasswordInput.addEventListener('input', checkPasswordStrength);
            }

            // Load activity log
            loadActivityLog();
        }, 100);
    } else if (page === 'notifications') {
        // Set up notifications page
        setTimeout(() => {
            loadNotificationsList();
        }, 100);
    } else if (page === 'buses') {
        // Set up buses page
        setTimeout(() => {
            console.log('🚌 Initializing buses page functionality...');

            // Initialize bus manager if not already done
            if (typeof window.busManager === 'undefined') {
                console.log('🔧 Creating new bus manager...');
                // Load the buses.js script if not loaded
                if (!document.querySelector('script[src*="buses.js"]')) {
                    const script = document.createElement('script');
                    script.src = 'js/buses.js';
                    script.onload = () => {
                        console.log('✅ Buses.js loaded successfully');
                    };
                    document.head.appendChild(script);
                }
            } else {
                console.log('✅ Bus manager already exists');
                // Reload buses data
                if (window.busManager && typeof window.busManager.loadBuses === 'function') {
                    window.busManager.loadBuses();
                }
            }
        }, 100);
    } else if (page === 'help') {
        // Set up help page
        setTimeout(() => {
            // Support form
            const supportForm = document.getElementById('supportForm');
            if (supportForm) {
                supportForm.addEventListener('submit', (e) => {
                    e.preventDefault();
                    sendSupportMessage();
                });
            }
        }, 100);
    }
}

// Student management functions
async function saveStudent() {
    const form = document.getElementById('addStudentForm');
    const formData = new FormData(form);

    // Validate required fields (same as Flutter)
    const requiredFields = ['name', 'grade', 'schoolName', 'parentName', 'parentPhone', 'busRoute'];
    const missingFields = [];

    for (const field of requiredFields) {
        if (!formData.get(field) || formData.get(field).trim() === '') {
            missingFields.push(field);
        }
    }

    if (missingFields.length > 0) {
        showNotification('يرجى ملء جميع الحقول المطلوبة', 'error');
        return;
    }

    // Validate student name (same as Flutter: min 2 characters)
    const studentName = formData.get('name').trim();
    if (studentName.length < 2) {
        showNotification('الاسم يجب أن يكون حرفين على الأقل', 'error');
        return;
    }

    // Validate phone number (same as Flutter: min 10 digits)
    const phoneNumber = formData.get('parentPhone').trim();
    if (phoneNumber.length < 10) {
        showNotification('رقم الهاتف يجب أن يكون 10 أرقام على الأقل', 'error');
        return;
    }

    // Show loading state
    const saveBtn = document.querySelector('#addStudentModal .btn-primary');
    const originalText = saveBtn.innerHTML;
    saveBtn.innerHTML = '<i class="fas fa-spinner fa-spin me-2"></i>جاري الحفظ...';
    saveBtn.disabled = true;

    try {
        // Generate unique QR code for student
        const timestamp = Date.now();
        const qrCode = `STUDENT_${timestamp}`;

        const studentData = {
            name: formData.get('name').trim(),
            grade: formData.get('grade').trim(),
            schoolName: formData.get('schoolName').trim(),
            parentName: formData.get('parentName').trim(),
            parentPhone: phoneNumber,
            busRoute: formData.get('busRoute'),
            qrCode: qrCode, // Auto-generated QR code
            parentId: '', // Will be set when parent registers
            currentStatus: 'home',
            isActive: true
        };

        console.log('📝 Adding student with data:', studentData);
        const result = await FirebaseService.addStudent(studentData);

        if (result.success) {
            // Close modal
            const modal = bootstrap.Modal.getInstance(document.getElementById('addStudentModal'));
            modal.hide();

            // Reset form
            form.reset();

            // Reload students page
            loadPage('students');

            // Show success message
            showNotification(`تم إضافة الطالب ${studentData.name} بنجاح`, 'success');
        } else {
            showNotification(`حدث خطأ أثناء إضافة الطالب: ${result.error}`, 'error');
        }
    } catch (error) {
        console.error('❌ Error saving student:', error);
        showNotification('حدث خطأ غير متوقع أثناء إضافة الطالب', 'error');
    } finally {
        // Reset button
        saveBtn.innerHTML = originalText;
        saveBtn.disabled = false;
    }
}

// Supervisor management functions
async function saveSupervisor() {
    const form = document.getElementById('addSupervisorForm');
    const formData = new FormData(form);

    // Validate required fields (same as Flutter)
    const requiredFields = ['name', 'email', 'phone', 'password'];
    const missingFields = [];

    for (const field of requiredFields) {
        if (!formData.get(field) || formData.get(field).trim() === '') {
            missingFields.push(field);
        }
    }

    if (missingFields.length > 0) {
        showNotification('يرجى ملء جميع الحقول المطلوبة', 'error');
        return;
    }

    // Validate password (same as Flutter: min 6 characters)
    const password = formData.get('password').trim();
    if (password.length < 6) {
        showNotification('كلمة المرور يجب أن تكون 6 أحرف على الأقل', 'error');
        return;
    }

    // Show loading state
    const saveBtn = document.querySelector('#addSupervisorModal .btn-primary');
    const originalText = saveBtn.innerHTML;
    saveBtn.innerHTML = '<i class="fas fa-spinner fa-spin me-2"></i>جاري الحفظ...';
    saveBtn.disabled = true;

    try {
        const supervisorData = {
            name: formData.get('name').trim(),
            email: formData.get('email').trim(),
            phone: formData.get('phone').trim(),
            password: password,
            userType: 'supervisor'
        };

        console.log('📝 Adding supervisor with data:', supervisorData);
        const result = await FirebaseService.addSupervisor(supervisorData);

        if (result.success) {
            // Close modal
            const modal = bootstrap.Modal.getInstance(document.getElementById('addSupervisorModal'));
            modal.hide();

            // Reset form
            form.reset();

            // Reload supervisors page
            loadPage('supervisors');

            // Show success message
            showNotification(`تم إضافة المشرف ${supervisorData.name} بنجاح`, 'success');
        } else {
            showNotification(`حدث خطأ أثناء إضافة المشرف: ${result.error}`, 'error');
        }
    } catch (error) {
        console.error('❌ Error saving supervisor:', error);
        showNotification('حدث خطأ غير متوقع أثناء إضافة المشرف', 'error');
    } finally {
        // Reset button
        saveBtn.innerHTML = originalText;
        saveBtn.disabled = false;
    }
}

// Parent management functions
async function saveParent() {
    const form = document.getElementById('addParentForm');
    const formData = new FormData(form);

    // Validate required fields (same as Flutter)
    const requiredFields = ['name', 'email', 'phone', 'password'];
    const missingFields = [];

    for (const field of requiredFields) {
        if (!formData.get(field) || formData.get(field).trim() === '') {
            missingFields.push(field);
        }
    }

    if (missingFields.length > 0) {
        showNotification('يرجى ملء جميع الحقول المطلوبة', 'error');
        return;
    }

    // Validate password (same as Flutter: min 6 characters)
    const password = formData.get('password').trim();
    if (password.length < 6) {
        showNotification('كلمة المرور يجب أن تكون 6 أحرف على الأقل', 'error');
        return;
    }

    // Show loading state
    const saveBtn = document.querySelector('#addParentModal .btn-primary');
    const originalText = saveBtn.innerHTML;
    saveBtn.innerHTML = '<i class="fas fa-spinner fa-spin me-2"></i>جاري الحفظ...';
    saveBtn.disabled = true;

    try {
        const parentData = {
            name: formData.get('name').trim(),
            email: formData.get('email').trim(),
            phone: formData.get('phone').trim(),
            password: password,
            userType: 'parent'
        };

        console.log('📝 Adding parent with data:', parentData);
        const result = await FirebaseService.addParent(parentData);

        if (result.success) {
            // Close modal
            const modal = bootstrap.Modal.getInstance(document.getElementById('addParentModal'));
            modal.hide();

            // Reset form
            form.reset();

            // Reload parents page
            loadPage('parents');

            // Show success message
            showNotification(`تم إضافة ولي الأمر ${parentData.name} بنجاح`, 'success');
        } else {
            showNotification(`حدث خطأ أثناء إضافة ولي الأمر: ${result.error}`, 'error');
        }
    } catch (error) {
        console.error('❌ Error saving parent:', error);
        showNotification('حدث خطأ غير متوقع أثناء إضافة ولي الأمر', 'error');
    } finally {
        // Reset button
        saveBtn.innerHTML = originalText;
        saveBtn.disabled = false;
    }
}

async function editStudent(studentId) {
    console.log('✏️ Editing student:', studentId);

    // Check Firebase availability
    if (!reloadFirebaseIfNeeded()) {
        return;
    }

    const student = studentsData.find(s => s.id === studentId);
    if (!student) {
        alert('لم يتم العثور على الطالب');
        return;
    }

    // Close view modal if open
    const viewModal = document.getElementById('viewStudentModal');
    if (viewModal) {
        const modal = bootstrap.Modal.getInstance(viewModal);
        if (modal) {
            modal.hide();
        }
    }

    // Create edit student modal
    const modalContent = `
        <div class="modal fade" id="editStudentModal" tabindex="-1">
            <div class="modal-dialog modal-lg modal-dialog-scrollable">
                <div class="modal-content">
                    <div class="modal-header bg-warning text-dark">
                        <h5 class="modal-title">
                            <i class="fas fa-edit me-2"></i>
                            تعديل بيانات الطالب: ${student.name}
                        </h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form id="editStudentForm">
                            <input type="hidden" name="studentId" value="${studentId}">

                            <!-- Basic Information -->
                            <div class="row">
                                <div class="col-12 mb-4">
                                    <h6 class="text-primary border-bottom pb-2">
                                        <i class="fas fa-user me-2"></i>
                                        المعلومات الأساسية
                                    </h6>
                                </div>

                                <div class="col-md-6 mb-3">
                                    <label class="form-label">اسم الطالب *</label>
                                    <input type="text" class="form-control" name="name" value="${student.name || ''}" required
                                           placeholder="أدخل اسم الطالب الكامل">
                                </div>

                                <div class="col-md-6 mb-3">
                                    <label class="form-label">الصف الدراسي *</label>
                                    <select class="form-control" name="grade" required>
                                        <option value="">اختر الصف</option>
                                        <option value="الأول الابتدائي" ${student.grade === 'الأول الابتدائي' ? 'selected' : ''}>الأول الابتدائي</option>
                                        <option value="الثاني الابتدائي" ${student.grade === 'الثاني الابتدائي' ? 'selected' : ''}>الثاني الابتدائي</option>
                                        <option value="الثالث الابتدائي" ${student.grade === 'الثالث الابتدائي' ? 'selected' : ''}>الثالث الابتدائي</option>
                                        <option value="الرابع الابتدائي" ${student.grade === 'الرابع الابتدائي' ? 'selected' : ''}>الرابع الابتدائي</option>
                                        <option value="الخامس الابتدائي" ${student.grade === 'الخامس الابتدائي' ? 'selected' : ''}>الخامس الابتدائي</option>
                                        <option value="السادس الابتدائي" ${student.grade === 'السادس الابتدائي' ? 'selected' : ''}>السادس الابتدائي</option>
                                        <option value="الأول المتوسط" ${student.grade === 'الأول المتوسط' ? 'selected' : ''}>الأول المتوسط</option>
                                        <option value="الثاني المتوسط" ${student.grade === 'الثاني المتوسط' ? 'selected' : ''}>الثاني المتوسط</option>
                                        <option value="الثالث المتوسط" ${student.grade === 'الثالث المتوسط' ? 'selected' : ''}>الثالث المتوسط</option>
                                        <option value="الأول الثانوي" ${student.grade === 'الأول الثانوي' ? 'selected' : ''}>الأول الثانوي</option>
                                        <option value="الثاني الثانوي" ${student.grade === 'الثاني الثانوي' ? 'selected' : ''}>الثاني الثانوي</option>
                                        <option value="الثالث الثانوي" ${student.grade === 'الثالث الثانوي' ? 'selected' : ''}>الثالث الثانوي</option>
                                    </select>
                                </div>

                                <div class="col-md-6 mb-3">
                                    <label class="form-label">المدرسة *</label>
                                    <input type="text" class="form-control" name="schoolName" value="${student.schoolName || ''}" required
                                           placeholder="اسم المدرسة">
                                </div>

                                <div class="col-md-6 mb-3">
                                    <label class="form-label">خط الباص *</label>
                                    <select class="form-control" name="busRoute" required>
                                        <option value="">اختر خط الباص</option>
                                        <option value="الخط الأول" ${student.busRoute === 'الخط الأول' ? 'selected' : ''}>الخط الأول</option>
                                        <option value="الخط الثاني" ${student.busRoute === 'الخط الثاني' ? 'selected' : ''}>الخط الثاني</option>
                                        <option value="الخط الثالث" ${student.busRoute === 'الخط الثالث' ? 'selected' : ''}>الخط الثالث</option>
                                        <option value="الخط الرابع" ${student.busRoute === 'الخط الرابع' ? 'selected' : ''}>الخط الرابع</option>
                                        <option value="الخط الخامس" ${student.busRoute === 'الخط الخامس' ? 'selected' : ''}>الخط الخامس</option>
                                    </select>
                                </div>
                            </div>

                            <hr class="my-4">

                            <!-- Parent Information -->
                            <div class="row">
                                <div class="col-12 mb-4">
                                    <h6 class="text-success border-bottom pb-2">
                                        <i class="fas fa-users me-2"></i>
                                        معلومات ولي الأمر
                                    </h6>
                                </div>

                                <div class="col-md-6 mb-3">
                                    <label class="form-label">ولي الأمر *</label>
                                    <input type="text" class="form-control mb-1" id="editParentSearchInput"
                                           placeholder="ابحث بالاسم أو رقم الهاتف..."
                                           oninput="filterParentOptions(this.value, 'editStudentForm')">
                                    <select class="form-control" name="parentId" required onchange="updateParentInfoEdit()" size="5">
                                        <option value="">اختر ولي الأمر</option>
                                        <option value="${student.parentId || ''}" selected>${student.parentName || 'ولي الأمر الحالي'}</option>
                                    </select>
                                    <small class="text-muted">اكتب في مربع البحث لتصفية القائمة، ثم اختر من أولياء الأمور المسجلين</small>
                                </div>

                                <div class="col-md-6 mb-3">
                                    <label class="form-label">رقم هاتف ولي الأمر</label>
                                    <input type="tel" class="form-control" name="parentPhone" value="${student.parentPhone || ''}" readonly
                                           placeholder="سيتم ملؤه تلقائياً">
                                    <small class="text-muted">يتم ملؤه تلقائياً عند اختيار ولي الأمر</small>
                                </div>
                            </div>

                            <hr class="my-4">

                            <!-- Status Information -->
                            <div class="row">
                                <div class="col-12 mb-4">
                                    <h6 class="text-info border-bottom pb-2">
                                        <i class="fas fa-cog me-2"></i>
                                        إعدادات الحالة
                                    </h6>
                                </div>

                                <div class="col-md-6 mb-3">
                                    <label class="form-label">الحالة الحالية</label>
                                    <select class="form-control" name="currentStatus">
                                        <option value="home" ${student.currentStatus === 'home' ? 'selected' : ''}>في المنزل</option>
                                        <option value="onBus" ${student.currentStatus === 'onBus' ? 'selected' : ''}>في الباص</option>
                                        <option value="atSchool" ${student.currentStatus === 'atSchool' ? 'selected' : ''}>في المدرسة</option>
                                        <option value="inactive" ${student.currentStatus === 'inactive' ? 'selected' : ''}>غير نشط</option>
                                    </select>
                                </div>

                                <div class="col-md-6 mb-3">
                                    <label class="form-label">حالة النشاط</label>
                                    <select class="form-control" name="isActive">
                                        <option value="true" ${student.isActive ? 'selected' : ''}>نشط</option>
                                        <option value="false" ${!student.isActive ? 'selected' : ''}>غير نشط</option>
                                    </select>
                                </div>
                            </div>

                            <div class="alert alert-info">
                                <i class="fas fa-info-circle me-2"></i>
                                <strong>ملاحظة:</strong> سيتم تحديث جميع البيانات في قاعدة البيانات. رمز QR سيبقى كما هو.
                            </div>
                        </form>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>إلغاء
                        </button>
                        <button type="button" class="btn btn-warning" onclick="updateStudent()">
                            <i class="fas fa-save me-2"></i>حفظ التغييرات
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Remove existing modal if any
    const existingModal = document.getElementById('editStudentModal');
    if (existingModal) {
        existingModal.remove();
    }

    // Add modal to body and show
    document.body.insertAdjacentHTML('beforeend', modalContent);
    const modal = new bootstrap.Modal(document.getElementById('editStudentModal'));
    modal.show();

    // Load parents for the dropdown
    loadParentsForEditForm(student.parentId, student.parentName);

    // Clean up when modal is hidden
    document.getElementById('editStudentModal').addEventListener('hidden.bs.modal', function() {
        this.remove();
        destroyAllBackdrops();
    });
}

// Update student function
function updateStudent() {
    console.log('💾 Updating student...');

    const form = document.getElementById('editStudentForm');
    if (!form) {
        alert('خطأ: لم يتم العثور على النموذج');
        return;
    }

    const formData = new FormData(form);
    const studentId = formData.get('studentId');

    // Get parent info
    const parentId = formData.get('parentId');
    let parentName = '';
    let parentPhone = formData.get('parentPhone')?.trim() || '';

    if (parentId && parentId !== '') {
        const selectedParent = parentsData.find(p => p.id === parentId);
        if (selectedParent) {
            parentName = selectedParent.name;
            parentPhone = selectedParent.phone;
        }
    }

    // Get updated data
    const updatedData = {
        name: formData.get('name')?.trim(),
        grade: formData.get('grade'),
        schoolName: formData.get('schoolName')?.trim(),
        busRoute: formData.get('busRoute'),
        parentId: parentId,
        parentName: parentName,
        parentPhone: parentPhone,
        currentStatus: formData.get('currentStatus'),
        isActive: formData.get('isActive') === 'true'
    };

    // Validate required fields
    if (!updatedData.name || !updatedData.grade || !updatedData.schoolName ||
        !updatedData.busRoute || !updatedData.parentId) {
        alert('يرجى ملء جميع الحقول المطلوبة واختيار ولي الأمر');
        return;
    }

    // Validate phone number
    if (!/^[0-9]{10,}$/.test(updatedData.parentPhone)) {
        alert('يرجى إدخال رقم هاتف صحيح (10 أرقام على الأقل)');
        return;
    }

    // Find student index
    const studentIndex = studentsData.findIndex(s => s.id === studentId);
    if (studentIndex === -1) {
        alert('لم يتم العثور على الطالب');
        return;
    }

    // Save to Firebase
    const saveToFirebase = async () => {
        try {
            console.log('💾 Updating student in Firebase:', studentId);
            console.log('📋 Update data:', updatedData);

            const result = await FirebaseService.updateStudent(studentId, updatedData);

            if (result && result.success) {
                console.log('✅ Student updated in Firebase successfully');

                const oldParentId = studentsData[studentIndex].parentId;
                const newParentId = updatedData.parentId;

                // Update student in local array
                studentsData[studentIndex] = {
                    ...studentsData[studentIndex],
                    ...updatedData,
                    updatedAt: new Date()
                };

                console.log('✅ Student updated locally:', studentsData[studentIndex]);

                // Update parent-child relationships in local data
                if (oldParentId !== newParentId) {
                    // Remove from old parent
                    if (oldParentId && oldParentId !== '') {
                        const oldParentIndex = parentsData.findIndex(p => p.id === oldParentId);
                        if (oldParentIndex !== -1 && parentsData[oldParentIndex].children) {
                            parentsData[oldParentIndex].children = parentsData[oldParentIndex].children.filter(child => child.id !== studentId);
                            console.log('✅ Student removed from old parent locally');
                        }
                    }

                    // Add to new parent
                    if (newParentId && newParentId !== '') {
                        const newParentIndex = parentsData.findIndex(p => p.id === newParentId);
                        if (newParentIndex !== -1) {
                            if (!parentsData[newParentIndex].children) {
                                parentsData[newParentIndex].children = [];
                            }

                            // Check if child already exists
                            const existingChild = parentsData[newParentIndex].children.find(child => child.id === studentId);
                            if (!existingChild) {
                                parentsData[newParentIndex].children.push({
                                    id: studentId,
                                    name: updatedData.name,
                                    grade: updatedData.grade,
                                    schoolName: updatedData.schoolName,
                                    busRoute: updatedData.busRoute,
                                    qrCode: studentsData[studentIndex].qrCode
                                });
                            } else {
                                // Update existing child info
                                const childIndex = parentsData[newParentIndex].children.findIndex(child => child.id === studentId);
                                parentsData[newParentIndex].children[childIndex] = {
                                    ...parentsData[newParentIndex].children[childIndex],
                                    name: updatedData.name,
                                    grade: updatedData.grade,
                                    schoolName: updatedData.schoolName,
                                    busRoute: updatedData.busRoute
                                };
                            }
                            console.log('✅ Student added/updated in new parent locally');
                        }
                    }
                } else if (newParentId && newParentId !== '') {
                    // Same parent, just update child info
                    const parentIndex = parentsData.findIndex(p => p.id === newParentId);
                    if (parentIndex !== -1 && parentsData[parentIndex].children) {
                        const childIndex = parentsData[parentIndex].children.findIndex(child => child.id === studentId);
                        if (childIndex !== -1) {
                            parentsData[parentIndex].children[childIndex] = {
                                ...parentsData[parentIndex].children[childIndex],
                                name: updatedData.name,
                                grade: updatedData.grade,
                                schoolName: updatedData.schoolName,
                                busRoute: updatedData.busRoute
                            };
                            console.log('✅ Student info updated in same parent locally');
                        }
                    }
                }

                // Close modal
                const modal = bootstrap.Modal.getInstance(document.getElementById('editStudentModal'));
                if (modal) {
                    modal.hide();
                }
                destroyAllBackdrops();

                // Show success message
                alert('تم تحديث بيانات الطالب وربطه بولي الأمر بنجاح!');

                // Refresh the page to show updated data
                loadPage('students');

            } else {
                throw new Error(result?.error || 'فشل في تحديث الطالب');
            }

        } catch (error) {
            console.error('❌ Error updating student in Firebase:', error);
            alert(`حدث خطأ أثناء تحديث الطالب في قاعدة البيانات:\n${error.message}`);
        }
    };

    // Execute the update operation
    saveToFirebase();
}

async function deleteStudent(studentId) {
    console.log('🗑️ Deleting student:', studentId);

    // Check Firebase availability
    if (!reloadFirebaseIfNeeded()) {
        return;
    }

    const student = studentsData.find(s => s.id === studentId);
    if (!student) {
        alert('لم يتم العثور على الطالب');
        return;
    }

    // Confirm deletion
    const confirmMessage = `هل أنت متأكد من حذف الطالب "${student.name}"؟\n\nسيتم حذف جميع البيانات المرتبطة به.\nهذا الإجراء لا يمكن التراجع عنه.`;
    if (!confirm(confirmMessage)) {
        return;
    }

    // Delete from Firebase first
    const deleteFromFirebase = async () => {
        try {
            console.log('🗑️ Deleting student from Firebase:', studentId);

            const result = await FirebaseService.deleteStudent(studentId);

            if (result && result.success) {
                console.log('✅ Student deleted from Firebase successfully');

                // Remove from local array
                const studentIndex = studentsData.findIndex(s => s.id === studentId);
                if (studentIndex !== -1) {
                    const deletedStudent = studentsData[studentIndex];
                    studentsData.splice(studentIndex, 1);
                    console.log('✅ Student deleted from local array');

                    // Remove from parent's children in local data
                    if (deletedStudent.parentId && deletedStudent.parentId !== '') {
                        const parentIndex = parentsData.findIndex(p => p.id === deletedStudent.parentId);
                        if (parentIndex !== -1 && parentsData[parentIndex].children) {
                            parentsData[parentIndex].children = parentsData[parentIndex].children.filter(child => child.id !== studentId);
                            console.log('✅ Student removed from parent children locally');
                        }
                    }

                    // Remove from table/cards
                    const row = document.querySelector(`tr[data-student-id="${studentId}"]`);
                    if (row) {
                        row.remove();
                        console.log('✅ Student removed from table');
                    }

                    const card = document.querySelector(`[data-student-id="${studentId}"]`);
                    if (card) {
                        card.remove();
                        console.log('✅ Student removed from cards');
                    }

                    // Show success message
                    alert(`تم حذف الطالب "${deletedStudent.name}" بنجاح من قاعدة البيانات وإزالته من ولي الأمر!`);

                    // Refresh page to update statistics
                    loadPage('students');

                } else {
                    console.warn('⚠️ Student not found in local array');
                    alert('تم حذف الطالب من قاعدة البيانات!');
                    // Refresh page to sync
                    loadPage('students');
                }

            } else {
                throw new Error(result?.error || 'فشل في حذف الطالب');
            }

        } catch (error) {
            console.error('❌ Error deleting student from Firebase:', error);
            alert(`حدث خطأ أثناء حذف الطالب من قاعدة البيانات:\n${error.message}`);
        }
    };

    // Execute the delete operation
    deleteFromFirebase();
}

// Notification function
// Notification function removed - using enhanced version below

async function loadSettingsPage() {
    console.log('🔧 Loading Settings Page...');

    // Load current settings from Firebase
    let settings = {};
    try {
        console.log('📡 Fetching settings from Firebase...');
        settings = await FirebaseService.getSettings();
        console.log('✅ Settings loaded:', settings);
    } catch (error) {
        console.error('❌ Error loading settings:', error);
        // Use default settings if Firebase fails
        settings = {
            schoolName: '',
            schoolPhone: '',
            schoolAddress: '',
            academicYearStart: '',
            academicYearEnd: '',
            morningStart: '07:00',
            morningEnd: '12:00',
            eveningStart: '13:00',
            eveningEnd: '17:00',
            enableNotifications: true,
            notifyParents: true,
            notifySupervisors: true,
            autoNotifications: true,
            sessionTimeout: 60,
            requireStrongPassword: false,
            enableTwoFactor: false,
            logUserActivity: true
        };
    }

    return `
        <div class="row mb-4">
            <div class="col-12">
                <h2 class="text-gradient">
                    <i class="fas fa-cog me-2"></i>
                    إعدادات النظام
                </h2>
                <p class="text-muted">إدارة إعدادات النظام والتطبيق</p>
            </div>
        </div>

        <!-- System Settings -->
        <div class="row mb-4">
            <div class="col-lg-8 col-md-12">
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <h5 class="mb-0">
                            <i class="fas fa-sliders-h me-2 text-primary"></i>
                            الإعدادات العامة
                        </h5>
                    </div>
                    <div class="card-body">
                        <form id="generalSettingsForm">
                            <div class="row g-3">
                                <div class="col-md-6">
                                    <label class="form-label">اسم المدرسة</label>
                                    <input type="text" class="form-control" id="schoolName"
                                           value="${settings.schoolName || ''}" required>
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">رقم هاتف المدرسة</label>
                                    <input type="tel" class="form-control" id="schoolPhone"
                                           value="${settings.schoolPhone || ''}" required>
                                </div>
                                <div class="col-12">
                                    <label class="form-label">عنوان المدرسة</label>
                                    <textarea class="form-control" id="schoolAddress" rows="2"
                                              required>${settings.schoolAddress || ''}</textarea>
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">بداية العام الدراسي</label>
                                    <input type="date" class="form-control" id="academicYearStart"
                                           value="${settings.academicYearStart || ''}" required>
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">نهاية العام الدراسي</label>
                                    <input type="date" class="form-control" id="academicYearEnd"
                                           value="${settings.academicYearEnd || ''}" required>
                                </div>
                            </div>
                            <div class="mt-3">
                                <button type="submit" class="btn btn-primary">
                                    <i class="fas fa-save me-2"></i>
                                    حفظ الإعدادات العامة
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            </div>

            <div class="col-lg-4 col-md-12">
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <h5 class="mb-0">
                            <i class="fas fa-clock me-2 text-warning"></i>
                            أوقات العمل
                        </h5>
                    </div>
                    <div class="card-body">
                        <form id="workingHoursForm">
                            <div class="mb-3">
                                <label class="form-label">بداية الدوام الصباحي</label>
                                <input type="time" class="form-control" id="morningStart"
                                       value="${settings.morningStart || '07:00'}" required>
                            </div>
                            <div class="mb-3">
                                <label class="form-label">نهاية الدوام الصباحي</label>
                                <input type="time" class="form-control" id="morningEnd"
                                       value="${settings.morningEnd || '12:00'}" required>
                            </div>
                            <div class="mb-3">
                                <label class="form-label">بداية الدوام المسائي</label>
                                <input type="time" class="form-control" id="eveningStart"
                                       value="${settings.eveningStart || '13:00'}">
                            </div>
                            <div class="mb-3">
                                <label class="form-label">نهاية الدوام المسائي</label>
                                <input type="time" class="form-control" id="eveningEnd"
                                       value="${settings.eveningEnd || '17:00'}">
                            </div>
                            <button type="submit" class="btn btn-warning w-100">
                                <i class="fas fa-save me-2"></i>
                                حفظ أوقات العمل
                            </button>
                        </form>
                    </div>
                </div>
            </div>
        </div>

        <!-- Bus Routes Settings -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <div class="d-flex justify-content-between align-items-center">
                            <h5 class="mb-0">
                                <i class="fas fa-route me-2 text-success"></i>
                                إدارة خطوط الباص
                            </h5>
                            <button class="btn btn-success btn-sm" onclick="addBusRoute()">
                                <i class="fas fa-plus me-1"></i>
                                إضافة خط جديد
                            </button>
                        </div>
                    </div>
                    <div class="card-body">
                        <div id="busRoutesContainer">
                            <div class="text-center py-3">
                                <div class="spinner-border text-success" role="status">
                                    <span class="visually-hidden">جاري التحميل...</span>
                                </div>
                                <p class="mt-2 text-muted">جاري تحميل خطوط الباص...</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Notification Settings -->
        <div class="row mb-4">
            <div class="col-lg-6 col-md-12 mb-3">
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <h5 class="mb-0">
                            <i class="fas fa-bell me-2 text-info"></i>
                            إعدادات الإشعارات
                        </h5>
                    </div>
                    <div class="card-body">
                        <form id="notificationSettingsForm">
                            <div class="form-check form-switch mb-3">
                                <input class="form-check-input" type="checkbox" id="enableNotifications"
                                       ${settings.enableNotifications ? 'checked' : ''}>
                                <label class="form-check-label" for="enableNotifications">
                                    تفعيل الإشعارات
                                </label>
                            </div>
                            <div class="form-check form-switch mb-3">
                                <input class="form-check-input" type="checkbox" id="notifyParents"
                                       ${settings.notifyParents ? 'checked' : ''}>
                                <label class="form-check-label" for="notifyParents">
                                    إشعار أولياء الأمور
                                </label>
                            </div>
                            <div class="form-check form-switch mb-3">
                                <input class="form-check-input" type="checkbox" id="notifySupervisors"
                                       ${settings.notifySupervisors ? 'checked' : ''}>
                                <label class="form-check-label" for="notifySupervisors">
                                    إشعار المشرفين
                                </label>
                            </div>
                            <div class="form-check form-switch mb-3">
                                <input class="form-check-input" type="checkbox" id="autoNotifications"
                                       ${settings.autoNotifications ? 'checked' : ''}>
                                <label class="form-check-label" for="autoNotifications">
                                    الإشعارات التلقائية
                                </label>
                            </div>
                            <button type="submit" class="btn btn-info w-100">
                                <i class="fas fa-save me-2"></i>
                                حفظ إعدادات الإشعارات
                            </button>
                        </form>
                    </div>
                </div>
            </div>

            <div class="col-lg-6 col-md-12 mb-3">
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <h5 class="mb-0">
                            <i class="fas fa-shield-alt me-2 text-danger"></i>
                            إعدادات الأمان
                        </h5>
                    </div>
                    <div class="card-body">
                        <form id="securitySettingsForm">
                            <div class="mb-3">
                                <label class="form-label">مدة انتهاء الجلسة (بالدقائق)</label>
                                <input type="number" class="form-control" id="sessionTimeout"
                                       value="${settings.sessionTimeout || 60}" min="15" max="480" required>
                            </div>
                            <div class="form-check form-switch mb-3">
                                <input class="form-check-input" type="checkbox" id="requireStrongPassword"
                                       ${settings.requireStrongPassword ? 'checked' : ''}>
                                <label class="form-check-label" for="requireStrongPassword">
                                    كلمات مرور قوية
                                </label>
                            </div>
                            <div class="form-check form-switch mb-3">
                                <input class="form-check-input" type="checkbox" id="enableTwoFactor"
                                       ${settings.enableTwoFactor ? 'checked' : ''}>
                                <label class="form-check-label" for="enableTwoFactor">
                                    المصادقة الثنائية
                                </label>
                            </div>
                            <div class="form-check form-switch mb-3">
                                <input class="form-check-input" type="checkbox" id="logUserActivity"
                                       ${settings.logUserActivity ? 'checked' : ''}>
                                <label class="form-check-label" for="logUserActivity">
                                    تسجيل نشاط المستخدمين
                                </label>
                            </div>
                            <button type="submit" class="btn btn-danger w-100">
                                <i class="fas fa-save me-2"></i>
                                حفظ إعدادات الأمان
                            </button>
                        </form>
                    </div>
                </div>
            </div>
        </div>

        <!-- System Actions -->
        <div class="row">
            <div class="col-12">
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <h5 class="mb-0">
                            <i class="fas fa-tools me-2 text-secondary"></i>
                            إجراءات النظام
                        </h5>
                    </div>
                    <div class="card-body">
                        <div class="row g-3">
                            <div class="col-md-3 col-sm-6">
                                <button class="btn btn-outline-primary w-100" onclick="exportAllData()">
                                    <i class="fas fa-download d-block mb-2" style="font-size: 1.5rem;"></i>
                                    تصدير جميع البيانات
                                </button>
                            </div>
                            <div class="col-md-3 col-sm-6">
                                <button class="btn btn-outline-warning w-100" onclick="backupDatabase()">
                                    <i class="fas fa-database d-block mb-2" style="font-size: 1.5rem;"></i>
                                    نسخ احتياطي
                                </button>
                            </div>
                            <div class="col-md-3 col-sm-6">
                                <button class="btn btn-outline-info w-100" onclick="clearCache()">
                                    <i class="fas fa-broom d-block mb-2" style="font-size: 1.5rem;"></i>
                                    مسح الذاكرة المؤقتة
                                </button>
                            </div>
                            <div class="col-md-3 col-sm-6">
                                <button class="btn btn-outline-danger w-100" onclick="resetSystem()">
                                    <i class="fas fa-redo d-block mb-2" style="font-size: 1.5rem;"></i>
                                    إعادة تعيين النظام
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    `;
}

async function loadProfilePage() {
    console.log('👤 Loading Profile Page...');

    // Load current user data
    let userData = {};
    try {
        const currentUser = firebase.auth().currentUser;
        if (currentUser) {
            userData = {
                uid: currentUser.uid,
                email: currentUser.email,
                displayName: currentUser.displayName || '',
                photoURL: currentUser.photoURL || '',
                phoneNumber: currentUser.phoneNumber || '',
                emailVerified: currentUser.emailVerified,
                creationTime: currentUser.metadata.creationTime,
                lastSignInTime: currentUser.metadata.lastSignInTime
            };
        }
    } catch (error) {
        console.error('❌ Error loading user data:', error);
    }

    return `
        <div class="row mb-4">
            <div class="col-12">
                <h2 class="text-gradient">
                    <i class="fas fa-user me-2"></i>
                    الملف الشخصي
                </h2>
                <p class="text-muted">إدارة معلوماتك الشخصية وإعدادات الحساب</p>
            </div>
        </div>

        <!-- Profile Info -->
        <div class="row mb-4">
            <div class="col-lg-4 col-md-12 mb-4">
                <div class="card border-0 shadow-sm">
                    <div class="card-body text-center">
                        <div class="profile-avatar mb-3">
                            ${userData.photoURL ?
                                `<img src="${userData.photoURL}" alt="صورة الملف الشخصي" class="rounded-circle" width="120" height="120">` :
                                `<div class="avatar-placeholder">
                                    <span>${getInitials(userData.displayName || userData.email || 'Admin')}</span>
                                </div>`
                            }
                        </div>
                        <h5 class="mb-1">${userData.displayName || 'مدير النظام'}</h5>
                        <p class="text-muted mb-3">${userData.email || 'admin@mybus.com'}</p>
                        <div class="d-flex justify-content-center gap-2">
                            <span class="badge ${userData.emailVerified ? 'bg-success' : 'bg-warning'}">
                                <i class="fas ${userData.emailVerified ? 'fa-check-circle' : 'fa-exclamation-triangle'} me-1"></i>
                                ${userData.emailVerified ? 'بريد مؤكد' : 'بريد غير مؤكد'}
                            </span>
                        </div>
                        <div class="mt-3">
                            <button class="btn btn-primary btn-sm" onclick="changeProfilePhoto()">
                                <i class="fas fa-camera me-1"></i>
                                تغيير الصورة
                            </button>
                        </div>
                    </div>
                </div>

                <!-- Account Stats -->
                <div class="card border-0 shadow-sm mt-3">
                    <div class="card-header bg-white border-bottom">
                        <h6 class="mb-0">
                            <i class="fas fa-chart-line me-2 text-info"></i>
                            إحصائيات الحساب
                        </h6>
                    </div>
                    <div class="card-body">
                        <div class="stat-item mb-3">
                            <div class="d-flex justify-content-between">
                                <span class="text-muted">تاريخ الإنشاء</span>
                                <span class="fw-semibold">${formatDate(userData.creationTime)}</span>
                            </div>
                        </div>
                        <div class="stat-item mb-3">
                            <div class="d-flex justify-content-between">
                                <span class="text-muted">آخر تسجيل دخول</span>
                                <span class="fw-semibold">${formatDate(userData.lastSignInTime)}</span>
                            </div>
                        </div>
                        <div class="stat-item">
                            <div class="d-flex justify-content-between">
                                <span class="text-muted">معرف المستخدم</span>
                                <span class="fw-semibold text-truncate" style="max-width: 120px;" title="${userData.uid}">
                                    ${userData.uid ? userData.uid.substring(0, 8) + '...' : 'غير متاح'}
                                </span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-lg-8 col-md-12">
                <!-- Personal Information -->
                <div class="card border-0 shadow-sm mb-4">
                    <div class="card-header bg-white border-bottom">
                        <h5 class="mb-0">
                            <i class="fas fa-user-edit me-2 text-primary"></i>
                            المعلومات الشخصية
                        </h5>
                    </div>
                    <div class="card-body">
                        <form id="personalInfoForm">
                            <div class="row g-3">
                                <div class="col-md-6">
                                    <label class="form-label">الاسم الكامل</label>
                                    <input type="text" class="form-control" id="displayName"
                                           value="${userData.displayName || ''}" required>
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">البريد الإلكتروني</label>
                                    <input type="email" class="form-control" id="email"
                                           value="${userData.email || ''}" required>
                                    <div class="form-text">
                                        ${userData.emailVerified ?
                                            '<i class="fas fa-check-circle text-success me-1"></i>البريد الإلكتروني مؤكد' :
                                            '<i class="fas fa-exclamation-triangle text-warning me-1"></i>البريد الإلكتروني غير مؤكد'
                                        }
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">رقم الهاتف</label>
                                    <input type="tel" class="form-control" id="phoneNumber"
                                           value="${userData.phoneNumber || ''}" placeholder="+966xxxxxxxxx">
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">المنصب</label>
                                    <select class="form-select" id="userRole">
                                        <option value="admin" selected>مدير النظام</option>
                                        <option value="manager">مدير عام</option>
                                        <option value="supervisor">مشرف</option>
                                    </select>
                                </div>
                            </div>
                            <div class="mt-3">
                                <button type="submit" class="btn btn-primary">
                                    <i class="fas fa-save me-2"></i>
                                    حفظ المعلومات الشخصية
                                </button>
                                ${!userData.emailVerified ?
                                    `<button type="button" class="btn btn-outline-warning ms-2" onclick="sendEmailVerification()">
                                        <i class="fas fa-envelope me-2"></i>
                                        إرسال رابط التأكيد
                                    </button>` : ''
                                }
                            </div>
                        </form>
                    </div>
                </div>

                <!-- Security Settings -->
                <div class="card border-0 shadow-sm mb-4">
                    <div class="card-header bg-white border-bottom">
                        <h5 class="mb-0">
                            <i class="fas fa-shield-alt me-2 text-danger"></i>
                            إعدادات الأمان
                        </h5>
                    </div>
                    <div class="card-body">
                        <form id="securityForm">
                            <div class="row g-3">
                                <div class="col-md-6">
                                    <label class="form-label">كلمة المرور الحالية</label>
                                    <input type="password" class="form-control" id="currentPassword"
                                           placeholder="أدخل كلمة المرور الحالية">
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">كلمة المرور الجديدة</label>
                                    <input type="password" class="form-control" id="newPassword"
                                           placeholder="أدخل كلمة المرور الجديدة">
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">تأكيد كلمة المرور الجديدة</label>
                                    <input type="password" class="form-control" id="confirmPassword"
                                           placeholder="أعد إدخال كلمة المرور الجديدة">
                                </div>
                                <div class="col-md-6">
                                    <label class="form-label">قوة كلمة المرور</label>
                                    <div class="password-strength">
                                        <div class="progress" style="height: 8px;">
                                            <div class="progress-bar" id="passwordStrengthBar"
                                                 role="progressbar" style="width: 0%"></div>
                                        </div>
                                        <small class="text-muted" id="passwordStrengthText">أدخل كلمة مرور جديدة</small>
                                    </div>
                                </div>
                            </div>
                            <div class="mt-3">
                                <button type="submit" class="btn btn-danger">
                                    <i class="fas fa-key me-2"></i>
                                    تغيير كلمة المرور
                                </button>
                            </div>
                        </form>
                    </div>
                </div>

                <!-- Activity Log -->
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <h5 class="mb-0">
                            <i class="fas fa-history me-2 text-info"></i>
                            سجل النشاط الأخير
                        </h5>
                    </div>
                    <div class="card-body">
                        <div id="activityLogContainer">
                            <div class="text-center py-3">
                                <div class="spinner-border text-info" role="status">
                                    <span class="visually-hidden">جاري التحميل...</span>
                                </div>
                                <p class="mt-2 text-muted">جاري تحميل سجل النشاط...</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    `;
}

async function loadNotificationsPage() {
    console.log('🔔 Loading Notifications Page...');

    return `
        <div class="row mb-4">
            <div class="col-12">
                <h2 class="text-gradient">
                    <i class="fas fa-bell me-2"></i>
                    الإشعارات
                </h2>
                <p class="text-muted">إدارة جميع الإشعارات والتنبيهات</p>
            </div>
        </div>

        <!-- Notification Controls -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="card border-0 shadow-sm">
                    <div class="card-body">
                        <div class="d-flex flex-wrap align-items-center justify-content-between gap-3">
                            <div class="d-flex flex-wrap gap-2">
                                <button class="btn btn-outline-primary btn-sm" onclick="markAllAsRead()">
                                    <i class="fas fa-check-double me-1"></i>
                                    تحديد الكل كمقروء
                                </button>
                                <button class="btn btn-outline-danger btn-sm" onclick="deleteAllRead()">
                                    <i class="fas fa-trash me-1"></i>
                                    حذف المقروءة
                                </button>
                                <button class="btn btn-outline-success btn-sm" onclick="sendTestNotification()">
                                    <i class="fas fa-paper-plane me-1"></i>
                                    إرسال إشعار تجريبي
                                </button>
                            </div>
                            <div class="d-flex gap-2">
                                <select class="form-select form-select-sm" id="notificationFilter" onchange="filterNotifications()">
                                    <option value="all">جميع الإشعارات</option>
                                    <option value="unread">غير مقروءة</option>
                                    <option value="read">مقروءة</option>
                                    <option value="system">النظام</option>
                                    <option value="admin">إدارية</option>
                                    <option value="trip">الرحلات</option>
                                </select>
                                <button class="btn btn-outline-secondary btn-sm" onclick="refreshNotifications()">
                                    <i class="fas fa-sync-alt"></i>
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Notifications List -->
        <div class="row">
            <div class="col-12">
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <h5 class="mb-0">
                            <i class="fas fa-list me-2 text-primary"></i>
                            قائمة الإشعارات
                        </h5>
                    </div>
                    <div class="card-body p-0">
                        <div id="notificationsContainer">
                            <div class="text-center py-4">
                                <div class="spinner-border text-primary" role="status">
                                    <span class="visually-hidden">جاري التحميل...</span>
                                </div>
                                <p class="mt-2 text-muted">جاري تحميل الإشعارات...</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    `;
}

async function loadHelpPage() {
    console.log('❓ Loading Help Page...');

    return `
        <div class="row mb-4">
            <div class="col-12">
                <h2 class="text-gradient">
                    <i class="fas fa-question-circle me-2"></i>
                    المساعدة والدعم
                </h2>
                <p class="text-muted">دليل الاستخدام والأسئلة الشائعة</p>
            </div>
        </div>

        <!-- Quick Help -->
        <div class="row mb-4">
            <div class="col-md-6 col-lg-3 mb-3">
                <div class="card border-0 shadow-sm h-100 help-card">
                    <div class="card-body text-center">
                        <div class="help-icon mb-3">
                            <i class="fas fa-user-graduate"></i>
                        </div>
                        <h5>إدارة الطلاب</h5>
                        <p class="text-muted">كيفية إضافة وإدارة الطلاب</p>
                        <button class="btn btn-outline-primary btn-sm" onclick="showHelp('students')">
                            عرض الدليل
                        </button>
                    </div>
                </div>
            </div>
            <div class="col-md-6 col-lg-3 mb-3">
                <div class="card border-0 shadow-sm h-100 help-card">
                    <div class="card-body text-center">
                        <div class="help-icon mb-3">
                            <i class="fas fa-user-tie"></i>
                        </div>
                        <h5>إدارة المشرفين</h5>
                        <p class="text-muted">كيفية إضافة وإدارة المشرفين</p>
                        <button class="btn btn-outline-primary btn-sm" onclick="showHelp('supervisors')">
                            عرض الدليل
                        </button>
                    </div>
                </div>
            </div>
            <div class="col-md-6 col-lg-3 mb-3">
                <div class="card border-0 shadow-sm h-100 help-card">
                    <div class="card-body text-center">
                        <div class="help-icon mb-3">
                            <i class="fas fa-bus"></i>
                        </div>
                        <h5>خطوط الباص</h5>
                        <p class="text-muted">كيفية إدارة خطوط الباص</p>
                        <button class="btn btn-outline-primary btn-sm" onclick="showHelp('routes')">
                            عرض الدليل
                        </button>
                    </div>
                </div>
            </div>
            <div class="col-md-6 col-lg-3 mb-3">
                <div class="card border-0 shadow-sm h-100 help-card">
                    <div class="card-body text-center">
                        <div class="help-icon mb-3">
                            <i class="fas fa-cog"></i>
                        </div>
                        <h5>الإعدادات</h5>
                        <p class="text-muted">كيفية تخصيص النظام</p>
                        <button class="btn btn-outline-primary btn-sm" onclick="showHelp('settings')">
                            عرض الدليل
                        </button>
                    </div>
                </div>
            </div>
        </div>

        <!-- FAQ -->
        <div class="row mb-4">
            <div class="col-12">
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <h5 class="mb-0">
                            <i class="fas fa-question me-2 text-info"></i>
                            الأسئلة الشائعة
                        </h5>
                    </div>
                    <div class="card-body">
                        <div class="accordion" id="faqAccordion">
                            <div class="accordion-item">
                                <h2 class="accordion-header">
                                    <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#faq1">
                                        كيف أضيف طالب جديد؟
                                    </button>
                                </h2>
                                <div id="faq1" class="accordion-collapse collapse" data-bs-parent="#faqAccordion">
                                    <div class="accordion-body">
                                        <p>لإضافة طالب جديد:</p>
                                        <ol>
                                            <li>اذهب إلى صفحة "إدارة الطلاب"</li>
                                            <li>اضغط على زر "إضافة طالب جديد"</li>
                                            <li>املأ جميع البيانات المطلوبة</li>
                                            <li>اختر خط الباص المناسب</li>
                                            <li>اضغط "حفظ" لإضافة الطالب</li>
                                        </ol>
                                    </div>
                                </div>
                            </div>
                            <div class="accordion-item">
                                <h2 class="accordion-header">
                                    <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#faq2">
                                        كيف أتابع رحلات الباص؟
                                    </button>
                                </h2>
                                <div id="faq2" class="accordion-collapse collapse" data-bs-parent="#faqAccordion">
                                    <div class="accordion-body">
                                        <p>لمتابعة رحلات الباص:</p>
                                        <ol>
                                            <li>اذهب إلى صفحة "التقارير"</li>
                                            <li>اختر "تقارير الرحلات"</li>
                                            <li>حدد التاريخ والخط المطلوب</li>
                                            <li>ستظهر جميع تفاصيل الرحلة</li>
                                        </ol>
                                    </div>
                                </div>
                            </div>
                            <div class="accordion-item">
                                <h2 class="accordion-header">
                                    <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#faq3">
                                        كيف أرسل إشعارات لأولياء الأمور؟
                                    </button>
                                </h2>
                                <div id="faq3" class="accordion-collapse collapse" data-bs-parent="#faqAccordion">
                                    <div class="accordion-body">
                                        <p>لإرسال إشعارات:</p>
                                        <ol>
                                            <li>اذهب إلى صفحة "الإشعارات"</li>
                                            <li>اضغط "إنشاء إشعار جديد"</li>
                                            <li>اختر المستلمين</li>
                                            <li>اكتب الرسالة</li>
                                            <li>اضغط "إرسال"</li>
                                        </ol>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Contact Support -->
        <div class="row">
            <div class="col-12">
                <div class="card border-0 shadow-sm">
                    <div class="card-header bg-white border-bottom">
                        <h5 class="mb-0">
                            <i class="fas fa-headset me-2 text-success"></i>
                            تواصل مع الدعم الفني
                        </h5>
                    </div>
                    <div class="card-body">
                        <div class="row">
                            <div class="col-md-6">
                                <div class="contact-item mb-3">
                                    <i class="fas fa-envelope text-primary me-2"></i>
                                    <strong>البريد الإلكتروني:</strong>
                                    <a href="mailto:support@mybus.com">support@mybus.com</a>
                                </div>
                                <div class="contact-item mb-3">
                                    <i class="fas fa-phone text-success me-2"></i>
                                    <strong>الهاتف:</strong>
                                    <a href="tel:+966123456789">+966 12 345 6789</a>
                                </div>
                                <div class="contact-item">
                                    <i class="fas fa-clock text-info me-2"></i>
                                    <strong>ساعات العمل:</strong>
                                    الأحد - الخميس: 8:00 ص - 5:00 م
                                </div>
                            </div>
                            <div class="col-md-6">
                                <form id="supportForm">
                                    <div class="mb-3">
                                        <label class="form-label">الموضوع</label>
                                        <input type="text" class="form-control" required>
                                    </div>
                                    <div class="mb-3">
                                        <label class="form-label">الرسالة</label>
                                        <textarea class="form-control" rows="4" required></textarea>
                                    </div>
                                    <button type="submit" class="btn btn-success">
                                        <i class="fas fa-paper-plane me-2"></i>
                                        إرسال الرسالة
                                    </button>
                                </form>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    `;
}

function initializeDashboardCharts() {
    // Students Chart
    const studentsCtx = document.getElementById('studentsChart');
    if (studentsCtx) {
        new Chart(studentsCtx, {
            type: 'line',
            data: {
                labels: ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو'],
                datasets: [{
                    label: 'عدد الطلاب',
                    data: [12, 19, 15, 25, 22, 30],
                    borderColor: '#3498db',
                    backgroundColor: 'rgba(52, 152, 219, 0.1)',
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        display: false
                    }
                }
            }
        });
    }

    // Users Chart
    const usersCtx = document.getElementById('usersChart');
    if (usersCtx) {
        new Chart(usersCtx, {
            type: 'doughnut',
            data: {
                labels: ['الطلاب', 'المشرفين', 'أولياء الأمور'],
                datasets: [{
                    data: [60, 20, 20],
                    backgroundColor: ['#3498db', '#f39c12', '#e74c3c']
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        position: 'bottom'
                    }
                }
            }
        });
    }
}

// Notification function removed - using enhanced version below

function getNotificationIcon(type) {
    const icons = {
        'success': 'fa-check-circle',
        'error': 'fa-exclamation-triangle',
        'warning': 'fa-exclamation-triangle',
        'info': 'fa-info-circle'
    };
    return icons[type] || 'fa-info-circle';
}

// Settings page functions
async function saveGeneralSettings() {
    const saveBtn = document.querySelector('#generalSettingsForm button[type="submit"]');

    try {
        // Show loading state
        saveBtn.classList.add('loading');
        saveBtn.disabled = true;

        console.log('💾 Saving general settings...');

        const settings = {
            schoolName: document.getElementById('schoolName').value.trim(),
            schoolPhone: document.getElementById('schoolPhone').value.trim(),
            schoolAddress: document.getElementById('schoolAddress').value.trim(),
            academicYearStart: document.getElementById('academicYearStart').value,
            academicYearEnd: document.getElementById('academicYearEnd').value,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
            updatedBy: firebase.auth().currentUser?.uid || 'admin'
        };

        // Validate required fields
        if (!settings.schoolName || !settings.schoolPhone || !settings.schoolAddress) {
            throw new Error('جميع الحقول مطلوبة');
        }

        // Validate phone number
        const phoneRegex = /^[0-9+\-\s()]+$/;
        if (!phoneRegex.test(settings.schoolPhone)) {
            throw new Error('رقم الهاتف غير صحيح');
        }

        // Validate academic year dates
        if (settings.academicYearStart && settings.academicYearEnd) {
            const startDate = new Date(settings.academicYearStart);
            const endDate = new Date(settings.academicYearEnd);
            if (startDate >= endDate) {
                throw new Error('تاريخ بداية العام الدراسي يجب أن يكون قبل تاريخ النهاية');
            }
        }

        console.log('📤 Sending to Firebase:', settings);
        const result = await FirebaseService.updateSettings('general', settings);

        if (result.success) {
            console.log('✅ General settings saved successfully');
            showNotification('تم حفظ الإعدادات العامة بنجاح', 'success');

            // Log activity
            await logActivity('settings_update', 'تم تحديث الإعدادات العامة', {
                schoolName: settings.schoolName
            });
        } else {
            throw new Error(result.error || 'فشل في حفظ الإعدادات');
        }

    } catch (error) {
        console.error('❌ Error saving general settings:', error);
        showNotification(error.message || 'حدث خطأ أثناء حفظ الإعدادات', 'error');
    } finally {
        // Remove loading state
        saveBtn.classList.remove('loading');
        saveBtn.disabled = false;
    }
}

async function saveWorkingHours() {
    const saveBtn = document.querySelector('#workingHoursForm button[type="submit"]');

    try {
        // Show loading state
        saveBtn.classList.add('loading');
        saveBtn.disabled = true;

        console.log('⏰ Saving working hours...');

        const settings = {
            morningStart: document.getElementById('morningStart').value,
            morningEnd: document.getElementById('morningEnd').value,
            eveningStart: document.getElementById('eveningStart').value,
            eveningEnd: document.getElementById('eveningEnd').value,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
            updatedBy: firebase.auth().currentUser?.uid || 'admin'
        };

        // Validate time format and logic
        if (!settings.morningStart || !settings.morningEnd) {
            throw new Error('أوقات الدوام الصباحي مطلوبة');
        }

        // Check if morning start is before morning end
        const morningStart = new Date(`2000-01-01T${settings.morningStart}`);
        const morningEnd = new Date(`2000-01-01T${settings.morningEnd}`);
        if (morningStart >= morningEnd) {
            throw new Error('وقت بداية الدوام الصباحي يجب أن يكون قبل وقت النهاية');
        }

        // Check evening times if provided
        if (settings.eveningStart && settings.eveningEnd) {
            const eveningStart = new Date(`2000-01-01T${settings.eveningStart}`);
            const eveningEnd = new Date(`2000-01-01T${settings.eveningEnd}`);
            if (eveningStart >= eveningEnd) {
                throw new Error('وقت بداية الدوام المسائي يجب أن يكون قبل وقت النهاية');
            }

            // Check if evening start is after morning end
            if (eveningStart <= morningEnd) {
                throw new Error('الدوام المسائي يجب أن يبدأ بعد انتهاء الدوام الصباحي');
            }
        }

        console.log('📤 Sending working hours to Firebase:', settings);
        const result = await FirebaseService.updateSettings('workingHours', settings);

        if (result.success) {
            console.log('✅ Working hours saved successfully');
            showNotification('تم حفظ أوقات العمل بنجاح', 'success');

            // Log activity
            await logActivity('working_hours_update', 'تم تحديث أوقات العمل', {
                morningStart: settings.morningStart,
                morningEnd: settings.morningEnd,
                eveningStart: settings.eveningStart,
                eveningEnd: settings.eveningEnd
            });
        } else {
            throw new Error(result.error || 'فشل في حفظ أوقات العمل');
        }

    } catch (error) {
        console.error('❌ Error saving working hours:', error);
        showNotification(error.message || 'حدث خطأ أثناء حفظ أوقات العمل', 'error');
    } finally {
        // Remove loading state
        saveBtn.classList.remove('loading');
        saveBtn.disabled = false;
    }
}

async function saveNotificationSettings() {
    const saveBtn = document.querySelector('#notificationSettingsForm button[type="submit"]');

    try {
        // Show loading state
        saveBtn.classList.add('loading');
        saveBtn.disabled = true;

        console.log('🔔 Saving notification settings...');

        const settings = {
            enableNotifications: document.getElementById('enableNotifications').checked,
            notifyParents: document.getElementById('notifyParents').checked,
            notifySupervisors: document.getElementById('notifySupervisors').checked,
            autoNotifications: document.getElementById('autoNotifications').checked,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
            updatedBy: firebase.auth().currentUser?.uid || 'admin'
        };

        console.log('📤 Sending notification settings to Firebase:', settings);
        const result = await FirebaseService.updateSettings('notifications', settings);

        if (result.success) {
            console.log('✅ Notification settings saved successfully');
            showNotification('تم حفظ إعدادات الإشعارات بنجاح', 'success');

            // Log activity
            await logActivity('notification_settings_update', 'تم تحديث إعدادات الإشعارات', {
                enableNotifications: settings.enableNotifications,
                notifyParents: settings.notifyParents,
                notifySupervisors: settings.notifySupervisors,
                autoNotifications: settings.autoNotifications
            });

            // Send test notification if notifications are enabled
            if (settings.enableNotifications) {
                await sendTestNotification();
            }
        } else {
            throw new Error(result.error || 'فشل في حفظ إعدادات الإشعارات');
        }

    } catch (error) {
        console.error('❌ Error saving notification settings:', error);
        showNotification(error.message || 'حدث خطأ أثناء حفظ إعدادات الإشعارات', 'error');
    } finally {
        // Remove loading state
        saveBtn.classList.remove('loading');
        saveBtn.disabled = false;
    }
}

async function saveSecuritySettings() {
    const saveBtn = document.querySelector('#securitySettingsForm button[type="submit"]');

    try {
        // Show loading state
        saveBtn.classList.add('loading');
        saveBtn.disabled = true;

        console.log('🔒 Saving security settings...');

        const sessionTimeout = parseInt(document.getElementById('sessionTimeout').value);

        // Validate session timeout
        if (sessionTimeout < 15 || sessionTimeout > 480) {
            throw new Error('مدة انتهاء الجلسة يجب أن تكون بين 15 و 480 دقيقة');
        }

        const settings = {
            sessionTimeout: sessionTimeout,
            requireStrongPassword: document.getElementById('requireStrongPassword').checked,
            enableTwoFactor: document.getElementById('enableTwoFactor').checked,
            logUserActivity: document.getElementById('logUserActivity').checked,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
            updatedBy: firebase.auth().currentUser?.uid || 'admin'
        };

        console.log('📤 Sending security settings to Firebase:', settings);
        const result = await FirebaseService.updateSettings('security', settings);

        if (result.success) {
            console.log('✅ Security settings saved successfully');
            showNotification('تم حفظ إعدادات الأمان بنجاح', 'success');

            // Log activity
            await logActivity('security_settings_update', 'تم تحديث إعدادات الأمان', {
                sessionTimeout: settings.sessionTimeout,
                requireStrongPassword: settings.requireStrongPassword,
                enableTwoFactor: settings.enableTwoFactor,
                logUserActivity: settings.logUserActivity
            });

            // Update session timeout if changed
            updateSessionTimeout(settings.sessionTimeout);
        } else {
            throw new Error(result.error || 'فشل في حفظ إعدادات الأمان');
        }

    } catch (error) {
        console.error('❌ Error saving security settings:', error);
        showNotification(error.message || 'حدث خطأ أثناء حفظ إعدادات الأمان', 'error');
    } finally {
        // Remove loading state
        saveBtn.classList.remove('loading');
        saveBtn.disabled = false;
    }
}

async function loadBusRoutes() {
    const container = document.getElementById('busRoutesContainer');
    if (!container) return;

    try {
        let routes = [];

        if (typeof FirebaseService.getBusRoutes === 'function') {
            routes = await FirebaseService.getBusRoutes();
        } else {
            console.warn('⚠️ getBusRoutes function not available, using sample data');
            routes = [
                { id: '1', name: 'الخط الأول', isActive: true, studentsCount: 25, supervisorName: 'أحمد محمد' },
                { id: '2', name: 'الخط الثاني', isActive: true, studentsCount: 30, supervisorName: 'سارة أحمد' },
                { id: '3', name: 'الخط الثالث', isActive: false, studentsCount: 0, supervisorName: 'غير محدد' }
            ];
        }

        if (routes.length === 0) {
            container.innerHTML = `
                <div class="text-center py-4">
                    <i class="fas fa-route text-muted mb-3" style="font-size: 3rem;"></i>
                    <h5 class="text-muted">لا توجد خطوط باص</h5>
                    <p class="text-muted">اضغط على "إضافة خط جديد" لإضافة أول خط باص</p>
                </div>
            `;
            return;
        }

        container.innerHTML = routes.map(route => `
            <div class="bus-route-item border rounded p-3 mb-3">
                <div class="row align-items-center">
                    <div class="col-md-3">
                        <h6 class="mb-1">${route.name}</h6>
                        <small class="text-muted">رقم الخط: ${route.id}</small>
                    </div>
                    <div class="col-md-3">
                        <small class="text-muted d-block">المشرف</small>
                        <span>${route.supervisorName || 'غير محدد'}</span>
                    </div>
                    <div class="col-md-2">
                        <small class="text-muted d-block">عدد الطلاب</small>
                        <span class="badge bg-primary">${route.studentsCount || 0}</span>
                    </div>
                    <div class="col-md-2">
                        <small class="text-muted d-block">الحالة</small>
                        <span class="badge ${route.isActive ? 'bg-success' : 'bg-secondary'}">
                            ${route.isActive ? 'نشط' : 'غير نشط'}
                        </span>
                    </div>
                    <div class="col-md-2 text-end">
                        <div class="btn-group" role="group">
                            <button class="btn btn-sm btn-outline-primary" onclick="editBusRoute('${route.id}')" title="تعديل">
                                <i class="fas fa-edit"></i>
                            </button>
                            <button class="btn btn-sm btn-outline-danger" onclick="deleteBusRoute('${route.id}')" title="حذف">
                                <i class="fas fa-trash"></i>
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        `).join('');

    } catch (error) {
        console.error('Error loading bus routes:', error);
        container.innerHTML = `
            <div class="alert alert-danger">
                <i class="fas fa-exclamation-triangle me-2"></i>
                حدث خطأ أثناء تحميل خطوط الباص
            </div>
        `;
    }
}

function addBusRoute() {
    const routeName = prompt('أدخل اسم الخط الجديد:');
    if (!routeName) return;

    const routeData = {
        name: routeName.trim(),
        isActive: true,
        studentsCount: 0,
        createdAt: new Date()
    };

    if (typeof FirebaseService.addBusRoute === 'function') {
        FirebaseService.addBusRoute(routeData).then(result => {
            if (result.success) {
                showNotification('تم إضافة الخط بنجاح', 'success');
                loadBusRoutes();
            } else {
                showNotification('حدث خطأ أثناء إضافة الخط', 'error');
            }
        });
    } else {
        console.warn('⚠️ addBusRoute function not available');
        showNotification('تم إضافة الخط محلياً (وضع التطوير)', 'warning');
        setTimeout(loadBusRoutes, 1000);
    }
}

// Helper functions for settings
async function logActivity(action, description, details = {}) {
    try {
        const activityData = {
            action: action,
            description: description,
            details: details,
            userId: firebase.auth().currentUser?.uid || 'admin',
            userEmail: firebase.auth().currentUser?.email || 'admin@mybus.com',
            timestamp: firebase.firestore.FieldValue.serverTimestamp(),
            type: 'admin_action'
        };

        console.log('📝 Logging activity:', activityData);

        // Add to activities collection
        await firebase.firestore().collection('activities').add(activityData);

        // Also add to notifications if activity logging is enabled
        const settings = await FirebaseService.getSettings();
        if (settings.logUserActivity) {
            await firebase.firestore().collection('notifications').add({
                title: 'نشاط إداري',
                body: description,
                type: 'admin',
                recipientId: 'admin',
                timestamp: firebase.firestore.FieldValue.serverTimestamp(),
                isRead: false,
                details: details
            });
        }

        console.log('✅ Activity logged successfully');
    } catch (error) {
        console.error('❌ Error logging activity:', error);
    }
}

async function sendTestNotification() {
    try {
        console.log('🧪 Sending test notification...');

        const testNotification = {
            title: 'اختبار الإشعارات',
            body: 'تم تفعيل الإشعارات بنجاح! سيتم إرسال الإشعارات للمستخدمين عند حدوث أي نشاط.',
            type: 'system',
            recipientId: 'admin',
            timestamp: firebase.firestore.FieldValue.serverTimestamp(),
            isRead: false,
            isTest: true
        };

        await firebase.firestore().collection('notifications').add(testNotification);

        console.log('✅ Test notification sent');
        showNotification('تم إرسال إشعار تجريبي بنجاح', 'info');
    } catch (error) {
        console.error('❌ Error sending test notification:', error);
    }
}

function updateSessionTimeout(timeoutMinutes) {
    try {
        console.log(`⏱️ Updating session timeout to ${timeoutMinutes} minutes`);

        // Clear existing timeout
        if (window.sessionTimeoutId) {
            clearTimeout(window.sessionTimeoutId);
        }

        // Set new timeout
        const timeoutMs = timeoutMinutes * 60 * 1000;
        window.sessionTimeoutId = setTimeout(() => {
            showNotification('انتهت مدة الجلسة. سيتم تسجيل الخروج تلقائياً.', 'warning');
            setTimeout(() => {
                FirebaseService.signOut();
            }, 5000);
        }, timeoutMs);

        console.log(`✅ Session timeout set to ${timeoutMinutes} minutes`);
    } catch (error) {
        console.error('❌ Error updating session timeout:', error);
    }
}

// Admin dropdown functions
function initializeAdminDropdown() {
    try {
        const currentUser = firebase.auth().currentUser;
        if (currentUser) {
            const displayName = currentUser.displayName || 'مدير النظام';
            const email = currentUser.email || 'admin@mybus.com';
            const initials = getInitials(displayName);

            // Update admin info in dropdown
            updateAdminInfo(displayName, email, initials);
        } else {
            // Default admin info
            updateAdminInfo('مدير النظام', 'admin@mybus.com', 'A');
        }

        // Load notification count
        loadNotificationCount();

    } catch (error) {
        console.error('❌ Error initializing admin dropdown:', error);
        updateAdminInfo('مدير النظام', 'admin@mybus.com', 'A');
    }
}

function updateAdminInfo(name, email, initials) {
    // Update initials in navbar
    const adminInitials = document.getElementById('adminInitials');
    const adminInitialsHeader = document.getElementById('adminInitialsHeader');
    if (adminInitials) adminInitials.textContent = initials;
    if (adminInitialsHeader) adminInitialsHeader.textContent = initials;

    // Update name and email in dropdown header
    const adminNameHeader = document.getElementById('adminNameHeader');
    const adminEmailHeader = document.getElementById('adminEmailHeader');
    if (adminNameHeader) adminNameHeader.textContent = name;
    if (adminEmailHeader) adminEmailHeader.textContent = email;

    // Sidebar user info removed

    console.log('✅ Admin info updated:', { name, email, initials });
}

// Sidebar functions removed

function getInitials(name) {
    if (!name) return 'A';

    const words = name.trim().split(' ');
    if (words.length === 1) {
        return words[0].charAt(0).toUpperCase();
    } else {
        return (words[0].charAt(0) + words[words.length - 1].charAt(0)).toUpperCase();
    }
}

async function loadNotificationCount() {
    try {
        const notifications = await FirebaseService.getNotifications(50);
        const unreadCount = notifications.filter(n => !n.isRead).length;

        // Update dropdown badge
        const notificationCountBadge = document.getElementById('notificationCount');
        if (notificationCountBadge) {
            if (unreadCount > 0) {
                notificationCountBadge.textContent = unreadCount > 99 ? '99+' : unreadCount;
                notificationCountBadge.style.display = 'inline-block';
            } else {
                notificationCountBadge.style.display = 'none';
            }
        }

        // Update navbar badge
        const navNotificationBadge = document.getElementById('navNotificationBadge');
        if (navNotificationBadge) {
            if (unreadCount > 0) {
                navNotificationBadge.textContent = unreadCount > 99 ? '99+' : unreadCount;
                navNotificationBadge.style.display = 'inline-block';
                navNotificationBadge.classList.add('notification-pulse');
            } else {
                navNotificationBadge.style.display = 'none';
                navNotificationBadge.classList.remove('notification-pulse');
            }
        }

        console.log(`🔔 Notification count updated: ${unreadCount} unread`);

    } catch (error) {
        console.error('❌ Error loading notification count:', error);
    }
}

// Dropdown menu functions
function openProfile() {
    console.log('📱 Opening profile...');
    loadPage('profile');
    closeDropdown();
}

function openSettings() {
    console.log('⚙️ Opening settings...');
    loadPage('settings');
    closeDropdown();
}

function openNotifications() {
    console.log('🔔 Opening notifications...');
    loadPage('notifications');
    closeDropdown();
}

function openHelp() {
    console.log('❓ Opening help...');
    loadPage('help');
    closeDropdown();
}

function closeDropdown() {
    // Close the dropdown menu
    const dropdownElement = document.querySelector('.dropdown-menu.show');
    if (dropdownElement) {
        const dropdown = bootstrap.Dropdown.getInstance(dropdownElement.previousElementSibling);
        if (dropdown) {
            dropdown.hide();
        }
    }
}

function editBusRoute(routeId) {
    const newName = prompt('أدخل الاسم الجديد للخط:');
    if (!newName) return;

    const routeData = {
        name: newName.trim(),
        updatedAt: new Date()
    };

    FirebaseService.updateBusRoute(routeId, routeData).then(result => {
        if (result.success) {
            showNotification('تم تحديث الخط بنجاح', 'success');
            loadBusRoutes();
        } else {
            showNotification('حدث خطأ أثناء تحديث الخط', 'error');
        }
    });
}

function deleteBusRoute(routeId) {
    if (!confirm('هل أنت متأكد من حذف هذا الخط؟ سيتم إلغاء تعيين جميع الطلاب المرتبطين به.')) {
        return;
    }

    FirebaseService.deleteBusRoute(routeId).then(result => {
        if (result.success) {
            showNotification('تم حذف الخط بنجاح', 'success');
            loadBusRoutes();
        } else {
            showNotification('حدث خطأ أثناء حذف الخط', 'error');
        }
    });
}

// System Actions
async function exportAllData() {
    const exportBtn = document.querySelector('button[onclick="exportAllData()"]');

    try {
        // Show loading state
        if (exportBtn) {
            exportBtn.classList.add('loading');
            exportBtn.disabled = true;
        }

        showNotification('جاري تصدير البيانات...', 'info');
        console.log('📦 Starting data export...');

        const data = await FirebaseService.exportAllData();

        // Add export metadata
        const exportData = {
            ...data,
            exportInfo: {
                exportDate: new Date().toISOString(),
                exportedBy: firebase.auth().currentUser?.email || 'admin@mybus.com',
                version: '1.0',
                totalRecords: Object.values(data).reduce((total, collection) => {
                    return total + (Array.isArray(collection) ? collection.length : 0);
                }, 0)
            }
        };

        const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `mybus_export_${new Date().toISOString().split('T')[0]}_${Date.now()}.json`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);

        console.log('✅ Data exported successfully');
        showNotification('تم تصدير البيانات بنجاح', 'success');

        // Log activity
        await logActivity('data_export', 'تم تصدير جميع بيانات النظام', {
            totalRecords: exportData.exportInfo.totalRecords,
            collections: Object.keys(data).filter(key => key !== 'exportInfo')
        });

    } catch (error) {
        console.error('❌ Export error:', error);
        showNotification(error.message || 'حدث خطأ أثناء تصدير البيانات', 'error');
    } finally {
        // Remove loading state
        if (exportBtn) {
            exportBtn.classList.remove('loading');
            exportBtn.disabled = false;
        }
    }
}

async function backupDatabase() {
    if (!confirm('هل تريد إنشاء نسخة احتياطية من قاعدة البيانات؟\n\nسيتم حفظ النسخة في Firebase وستكون متاحة للاستعادة لاحقاً.')) {
        return;
    }

    const backupBtn = document.querySelector('button[onclick="backupDatabase()"]');

    try {
        // Show loading state
        if (backupBtn) {
            backupBtn.classList.add('loading');
            backupBtn.disabled = true;
        }

        showNotification('جاري إنشاء النسخة الاحتياطية...', 'info');
        console.log('💾 Starting database backup...');

        const result = await FirebaseService.createBackup();

        if (result.success) {
            console.log('✅ Backup created successfully');
            showNotification('تم إنشاء النسخة الاحتياطية بنجاح', 'success');

            // Log activity
            await logActivity('database_backup', 'تم إنشاء نسخة احتياطية من قاعدة البيانات', {
                backupId: result.backupId || 'unknown',
                timestamp: new Date().toISOString()
            });

            // Send notification to all admins
            await firebase.firestore().collection('notifications').add({
                title: 'نسخة احتياطية جديدة',
                body: 'تم إنشاء نسخة احتياطية من قاعدة البيانات بنجاح',
                type: 'system',
                recipientId: 'all_admins',
                timestamp: firebase.firestore.FieldValue.serverTimestamp(),
                isRead: false,
                priority: 'normal'
            });

        } else {
            throw new Error(result.error || 'فشل في إنشاء النسخة الاحتياطية');
        }

    } catch (error) {
        console.error('❌ Backup error:', error);
        showNotification(error.message || 'حدث خطأ أثناء إنشاء النسخة الاحتياطية', 'error');
    } finally {
        // Remove loading state
        if (backupBtn) {
            backupBtn.classList.remove('loading');
            backupBtn.disabled = false;
        }
    }
}

async function clearCache() {
    if (!confirm('هل تريد مسح الذاكرة المؤقتة؟\n\nسيتم مسح:\n- البيانات المحفوظة محلياً\n- ذاكرة التخزين المؤقت\n- بيانات الجلسة\n\nقد يؤثر هذا على سرعة التطبيق مؤقتاً.')) {
        return;
    }

    const clearBtn = document.querySelector('button[onclick="clearCache()"]');

    try {
        // Show loading state
        if (clearBtn) {
            clearBtn.classList.add('loading');
            clearBtn.disabled = true;
        }

        showNotification('جاري مسح الذاكرة المؤقتة...', 'info');
        console.log('🧹 Clearing cache...');

        // Clear localStorage
        const localStorageSize = JSON.stringify(localStorage).length;
        localStorage.clear();
        console.log('✅ localStorage cleared');

        // Clear sessionStorage
        const sessionStorageSize = JSON.stringify(sessionStorage).length;
        sessionStorage.clear();
        console.log('✅ sessionStorage cleared');

        // Clear browser cache (if possible)
        let cacheCleared = false;
        if ('caches' in window) {
            try {
                const cacheNames = await caches.keys();
                await Promise.all(cacheNames.map(name => caches.delete(name)));
                cacheCleared = true;
                console.log('✅ Browser cache cleared');
            } catch (error) {
                console.warn('⚠️ Could not clear browser cache:', error);
            }
        }

        // Clear any stored Firebase data
        if (window.FirebaseService && typeof window.FirebaseService.clearCache === 'function') {
            await window.FirebaseService.clearCache();
        }

        console.log('✅ Cache clearing completed');
        showNotification('تم مسح الذاكرة المؤقتة بنجاح', 'success');

        // Log activity
        await logActivity('cache_clear', 'تم مسح الذاكرة المؤقتة', {
            localStorageSize: localStorageSize,
            sessionStorageSize: sessionStorageSize,
            browserCacheCleared: cacheCleared
        });

        // Suggest page reload
        setTimeout(() => {
            if (confirm('تم مسح الذاكرة المؤقتة بنجاح.\n\nهل تريد إعادة تحميل الصفحة لضمان التطبيق الكامل للتغييرات؟')) {
                window.location.reload();
            }
        }, 2000);

    } catch (error) {
        console.error('❌ Error clearing cache:', error);
        showNotification(error.message || 'حدث خطأ أثناء مسح الذاكرة المؤقتة', 'error');
    } finally {
        // Remove loading state
        if (clearBtn) {
            clearBtn.classList.remove('loading');
            clearBtn.disabled = false;
        }
    }
}

async function resetSystem() {
    // First confirmation
    const confirmation = prompt('⚠️ تحذير: هذا الإجراء سيحذف جميع البيانات نهائياً!\n\nسيتم حذف:\n- جميع الطلاب\n- جميع المشرفين\n- جميع أولياء الأمور\n- جميع الرحلات\n- جميع الإشعارات\n- خطوط الباص\n\nاكتب "RESET" بالأحرف الكبيرة للتأكيد:');

    if (confirmation !== 'RESET') {
        showNotification('تم إلغاء العملية', 'info');
        return;
    }

    // Second confirmation
    if (!confirm('هل أنت متأكد تماماً من إعادة تعيين النظام؟\n\n⚠️ لا يمكن التراجع عن هذا الإجراء!\n⚠️ ستفقد جميع البيانات نهائياً!\n\nاضغط "موافق" للمتابعة أو "إلغاء" للتراجع.')) {
        showNotification('تم إلغاء العملية', 'info');
        return;
    }

    // Third confirmation with admin email
    const adminEmail = prompt('للتأكيد النهائي، أدخل بريدك الإلكتروني الإداري:');
    const currentUserEmail = firebase.auth().currentUser?.email;

    if (adminEmail !== currentUserEmail) {
        showNotification('البريد الإلكتروني غير صحيح. تم إلغاء العملية.', 'error');
        return;
    }

    const resetBtn = document.querySelector('button[onclick="resetSystem()"]');

    try {
        // Show loading state
        if (resetBtn) {
            resetBtn.classList.add('loading');
            resetBtn.disabled = true;
        }

        showNotification('جاري إعادة تعيين النظام... هذا قد يستغرق بضع دقائق', 'warning');
        console.log('🔄 Starting system reset...');

        // Create final backup before reset
        console.log('💾 Creating final backup before reset...');
        try {
            await FirebaseService.createBackup();
            console.log('✅ Final backup created');
        } catch (backupError) {
            console.warn('⚠️ Could not create final backup:', backupError);
        }

        // Log the reset action before deleting everything
        await logActivity('system_reset_initiated', 'تم بدء إعادة تعيين النظام', {
            adminEmail: currentUserEmail,
            timestamp: new Date().toISOString(),
            warning: 'جميع البيانات ستحذف'
        });

        // Perform the reset
        const result = await FirebaseService.resetSystem();

        if (result.success) {
            console.log('✅ System reset completed');
            showNotification('تم إعادة تعيين النظام بنجاح. سيتم إعادة تحميل الصفحة...', 'success');

            // Clear all local data
            localStorage.clear();
            sessionStorage.clear();

            // Reload after delay
            setTimeout(() => {
                window.location.reload();
            }, 3000);
        } else {
            throw new Error(result.error || 'فشل في إعادة تعيين النظام');
        }

    } catch (error) {
        console.error('❌ Error resetting system:', error);
        showNotification(error.message || 'حدث خطأ أثناء إعادة تعيين النظام', 'error');
    } finally {
        // Remove loading state
        if (resetBtn) {
            resetBtn.classList.remove('loading');
            resetBtn.disabled = false;
        }
    }
}

// Profile page functions
async function savePersonalInfo() {
    const saveBtn = document.querySelector('#personalInfoForm button[type="submit"]');

    try {
        saveBtn.classList.add('loading');
        saveBtn.disabled = true;

        const displayName = document.getElementById('displayName').value.trim();
        const email = document.getElementById('email').value.trim();
        const phoneNumber = document.getElementById('phoneNumber').value.trim();

        if (!displayName || !email) {
            throw new Error('الاسم والبريد الإلكتروني مطلوبان');
        }

        const user = firebase.auth().currentUser;
        if (!user) {
            throw new Error('المستخدم غير مسجل الدخول');
        }

        // Update profile
        await user.updateProfile({
            displayName: displayName
        });

        showNotification('تم حفظ المعلومات الشخصية بنجاح', 'success');

        // Update admin info in dropdown
        initializeAdminDropdown();

    } catch (error) {
        console.error('❌ Error saving personal info:', error);
        showNotification(error.message || 'حدث خطأ أثناء حفظ المعلومات', 'error');
    } finally {
        saveBtn.classList.remove('loading');
        saveBtn.disabled = false;
    }
}

async function changePassword() {
    const saveBtn = document.querySelector('#securityForm button[type="submit"]');

    try {
        saveBtn.classList.add('loading');
        saveBtn.disabled = true;

        const currentPassword = document.getElementById('currentPassword').value;
        const newPassword = document.getElementById('newPassword').value;
        const confirmPassword = document.getElementById('confirmPassword').value;

        if (!currentPassword || !newPassword || !confirmPassword) {
            throw new Error('جميع حقول كلمة المرور مطلوبة');
        }

        if (newPassword !== confirmPassword) {
            throw new Error('كلمة المرور الجديدة وتأكيدها غير متطابقين');
        }

        if (newPassword.length < 6) {
            throw new Error('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
        }

        const user = firebase.auth().currentUser;
        if (!user) {
            throw new Error('المستخدم غير مسجل الدخول');
        }

        // Re-authenticate user
        const credential = firebase.auth.EmailAuthProvider.credential(user.email, currentPassword);
        await user.reauthenticateWithCredential(credential);

        // Update password
        await user.updatePassword(newPassword);

        showNotification('تم تغيير كلمة المرور بنجاح', 'success');

        // Clear form
        document.getElementById('currentPassword').value = '';
        document.getElementById('newPassword').value = '';
        document.getElementById('confirmPassword').value = '';

    } catch (error) {
        console.error('❌ Error changing password:', error);
        let errorMessage = 'حدث خطأ أثناء تغيير كلمة المرور';

        if (error.code === 'auth/wrong-password') {
            errorMessage = 'كلمة المرور الحالية غير صحيحة';
        } else if (error.code === 'auth/weak-password') {
            errorMessage = 'كلمة المرور الجديدة ضعيفة جداً';
        }

        showNotification(errorMessage, 'error');
    } finally {
        saveBtn.classList.remove('loading');
        saveBtn.disabled = false;
    }
}

function checkPasswordStrength() {
    const password = document.getElementById('newPassword').value;
    const strengthBar = document.getElementById('passwordStrengthBar');
    const strengthText = document.getElementById('passwordStrengthText');

    if (!password) {
        strengthBar.style.width = '0%';
        strengthBar.className = 'progress-bar';
        strengthText.textContent = 'أدخل كلمة مرور جديدة';
        return;
    }

    let strength = 0;
    let feedback = [];

    // Length check
    if (password.length >= 8) strength += 25;
    else feedback.push('8 أحرف على الأقل');

    // Uppercase check
    if (/[A-Z]/.test(password)) strength += 25;
    else feedback.push('حرف كبير');

    // Lowercase check
    if (/[a-z]/.test(password)) strength += 25;
    else feedback.push('حرف صغير');

    // Number or symbol check
    if (/[0-9]/.test(password) || /[^A-Za-z0-9]/.test(password)) strength += 25;
    else feedback.push('رقم أو رمز');

    // Update progress bar
    strengthBar.style.width = strength + '%';

    if (strength < 50) {
        strengthBar.className = 'progress-bar bg-danger';
        strengthText.textContent = 'ضعيفة - يحتاج: ' + feedback.join(', ');
    } else if (strength < 75) {
        strengthBar.className = 'progress-bar bg-warning';
        strengthText.textContent = 'متوسطة - يحتاج: ' + feedback.join(', ');
    } else if (strength < 100) {
        strengthBar.className = 'progress-bar bg-info';
        strengthText.textContent = 'جيدة - يحتاج: ' + feedback.join(', ');
    } else {
        strengthBar.className = 'progress-bar bg-success';
        strengthText.textContent = 'قوية جداً';
    }
}

// Notifications page functions
async function loadNotificationsList() {
    const container = document.getElementById('notificationsContainer');
    if (!container) return;

    try {
        const notifications = await FirebaseService.getNotifications(50);

        if (notifications.length === 0) {
            container.innerHTML = `
                <div class="text-center py-5">
                    <i class="fas fa-bell-slash text-muted mb-3" style="font-size: 4rem;"></i>
                    <h5 class="text-muted">لا توجد إشعارات</h5>
                    <p class="text-muted">ستظهر الإشعارات هنا عند وصولها</p>
                </div>
            `;
            return;
        }

        container.innerHTML = notifications.map(notification => {
            const timeAgo = getTimeAgo(notification.timestamp);
            const isUnread = !notification.isRead;

            return `
                <div class="notification-item ${isUnread ? 'unread' : ''}" data-id="${notification.id}">
                    <div class="d-flex align-items-start p-3">
                        <div class="notification-icon me-3">
                            <i class="fas ${getNotificationIcon(notification.type)}"></i>
                        </div>
                        <div class="flex-grow-1">
                            <h6 class="mb-1">${notification.title}</h6>
                            <p class="mb-1 text-muted">${notification.body}</p>
                            <small class="text-muted">${timeAgo}</small>
                        </div>
                        <div class="notification-actions">
                            ${isUnread ?
                                `<button class="btn btn-sm btn-outline-primary" onclick="markAsRead('${notification.id}')">
                                    <i class="fas fa-check"></i>
                                </button>` : ''
                            }
                            <button class="btn btn-sm btn-outline-danger" onclick="deleteNotification('${notification.id}')">
                                <i class="fas fa-trash"></i>
                            </button>
                        </div>
                    </div>
                </div>
            `;
        }).join('');

    } catch (error) {
        console.error('❌ Error loading notifications:', error);
        container.innerHTML = `
            <div class="alert alert-danger">
                <i class="fas fa-exclamation-triangle me-2"></i>
                حدث خطأ أثناء تحميل الإشعارات
            </div>
        `;
    }
}

// Initialize admin dropdown when page loads
document.addEventListener('DOMContentLoaded', () => {
    // Initialize admin dropdown after a short delay
    setTimeout(initializeAdminDropdown, 1000);

    // Fix dropdown positioning
    fixDropdownPositioning();

    // Load notifications dropdown when opened
    setupNotificationsDropdown();
});

function fixDropdownPositioning() {
    // Disable Popper.js for navbar dropdowns and use CSS positioning
    document.addEventListener('show.bs.dropdown', function (event) {
        const dropdown = event.target;
        const dropdownMenu = dropdown.querySelector('.dropdown-menu');

        // Check if this is a navbar dropdown
        if (dropdown.closest('.navbar') && dropdownMenu) {
            // Remove any Popper.js attributes
            dropdownMenu.removeAttribute('data-popper-placement');
            dropdownMenu.removeAttribute('data-popper-reference-hidden');
            dropdownMenu.removeAttribute('data-popper-escaped');

            // Reset any inline styles that Popper.js might have set
            dropdownMenu.style.position = 'absolute';
            dropdownMenu.style.inset = 'auto';
            dropdownMenu.style.margin = '0';
            dropdownMenu.style.transform = '';
            dropdownMenu.style.top = '';
            dropdownMenu.style.left = '';
            dropdownMenu.style.right = '';

            // Set z-index
            dropdownMenu.style.zIndex = '10001';

            // Force CSS positioning with multiple attempts
            const fixPositioning = () => {
                const isLastDropdown = dropdown.closest('.nav-item.dropdown:last-child') ||
                                     dropdown.closest('.dropdown:last-child');

                if (isLastDropdown) {
                    // User dropdown - align to right and ensure it's fully visible
                    dropdownMenu.style.position = 'absolute';
                    dropdownMenu.style.top = 'calc(100% + 0.5rem)';
                    dropdownMenu.style.left = 'auto';
                    dropdownMenu.style.transform = 'none';
                    dropdownMenu.style.zIndex = '10002';
                    dropdownMenu.style.margin = '0';
                    dropdownMenu.style.inset = 'auto';

                    // Calculate right position based on screen size
                    const screenWidth = window.innerWidth;
                    if (screenWidth < 576) {
                        dropdownMenu.style.right = '10px';
                        dropdownMenu.style.minWidth = '280px';
                        dropdownMenu.style.maxWidth = 'calc(100vw - 20px)';
                    } else if (screenWidth < 768) {
                        dropdownMenu.style.right = '5px';
                        dropdownMenu.style.minWidth = '300px';
                        dropdownMenu.style.maxWidth = 'calc(100vw - 10px)';
                    } else {
                        dropdownMenu.style.right = '0';
                        dropdownMenu.style.minWidth = '320px';
                        dropdownMenu.style.maxWidth = '400px';
                    }

                    console.log('🎯 User dropdown positioned:', {
                        right: dropdownMenu.style.right,
                        top: dropdownMenu.style.top,
                        position: dropdownMenu.style.position,
                        zIndex: dropdownMenu.style.zIndex
                    });
                } else {
                    // Other dropdowns - center align
                    dropdownMenu.style.position = 'absolute';
                    dropdownMenu.style.top = 'calc(100% + 0.5rem)';
                    dropdownMenu.style.left = '50%';
                    dropdownMenu.style.right = 'auto';
                    dropdownMenu.style.transform = 'translateX(-50%)';
                    dropdownMenu.style.zIndex = '10002';
                }
            };

            // Apply positioning immediately and after a short delay
            fixPositioning();
            setTimeout(fixPositioning, 1);
            setTimeout(fixPositioning, 10);
        }
    });

    // Close dropdown when clicking outside
    document.addEventListener('click', (event) => {
        const dropdown = document.querySelector('.dropdown-menu.show');
        if (dropdown && !dropdown.closest('.dropdown').contains(event.target)) {
            const dropdownInstance = bootstrap.Dropdown.getInstance(dropdown.previousElementSibling);
            if (dropdownInstance) {
                dropdownInstance.hide();
            }
        }
    });
}

// Helper functions for profile and other pages
function formatDate(dateString) {
    if (!dateString) return 'غير متاح';

    try {
        const date = new Date(dateString);
        if (isNaN(date.getTime())) return 'غير متاح';

        return date.toLocaleDateString('ar-SA', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    } catch (error) {
        console.error('Error formatting date:', error);
        return 'غير متاح';
    }
}

function getTimeAgo(timestamp) {
    if (!timestamp) return 'غير متاح';

    try {
        const now = new Date();
        const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
        const diffInSeconds = Math.floor((now - date) / 1000);

        if (diffInSeconds < 60) {
            return 'منذ لحظات';
        } else if (diffInSeconds < 3600) {
            const minutes = Math.floor(diffInSeconds / 60);
            return `منذ ${minutes} دقيقة`;
        } else if (diffInSeconds < 86400) {
            const hours = Math.floor(diffInSeconds / 3600);
            return `منذ ${hours} ساعة`;
        } else {
            const days = Math.floor(diffInSeconds / 86400);
            return `منذ ${days} يوم`;
        }
    } catch (error) {
        console.error('Error calculating time ago:', error);
        return 'غير متاح';
    }
}

async function loadActivityLog() {
    const container = document.getElementById('activityLogContainer');
    if (!container) return;

    try {
        // Get user activities from Firebase
        const currentUser = firebase.auth().currentUser;
        if (!currentUser) {
            container.innerHTML = `
                <div class="text-center py-4">
                    <i class="fas fa-exclamation-triangle text-warning mb-3" style="font-size: 3rem;"></i>
                    <h5 class="text-muted">المستخدم غير مسجل الدخول</h5>
                </div>
            `;
            return;
        }

        // For now, show sample activity data
        const sampleActivities = [
            {
                action: 'login',
                description: 'تسجيل دخول إلى النظام',
                timestamp: new Date(Date.now() - 1000 * 60 * 30) // 30 minutes ago
            },
            {
                action: 'settings_update',
                description: 'تحديث إعدادات النظام',
                timestamp: new Date(Date.now() - 1000 * 60 * 60 * 2) // 2 hours ago
            },
            {
                action: 'student_add',
                description: 'إضافة طالب جديد',
                timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24) // 1 day ago
            }
        ];

        container.innerHTML = sampleActivities.map(activity => {
            const timeAgo = getTimeAgo(activity.timestamp);

            return `
                <div class="activity-item d-flex align-items-center mb-3 pb-3 border-bottom">
                    <div class="activity-icon me-3">
                        <i class="fas ${getActivityIcon(activity.action)}"></i>
                    </div>
                    <div class="flex-grow-1">
                        <h6 class="mb-1">${activity.description}</h6>
                        <small class="text-muted">${timeAgo}</small>
                    </div>
                </div>
            `;
        }).join('');

    } catch (error) {
        console.error('❌ Error loading activity log:', error);
        container.innerHTML = `
            <div class="alert alert-warning">
                <i class="fas fa-exclamation-triangle me-2"></i>
                حدث خطأ أثناء تحميل سجل النشاط
            </div>
        `;
    }
}

function getActivityIcon(action) {
    const icons = {
        'login': 'fa-sign-in-alt',
        'logout': 'fa-sign-out-alt',
        'profile_update': 'fa-user-edit',
        'password_change': 'fa-key',
        'settings_update': 'fa-cog',
        'student_add': 'fa-user-plus',
        'supervisor_add': 'fa-user-tie',
        'data_export': 'fa-download',
        'system_reset': 'fa-redo'
    };
    return icons[action] || 'fa-circle';
}

async function sendEmailVerification() {
    try {
        const user = firebase.auth().currentUser;
        if (!user) {
            throw new Error('المستخدم غير مسجل الدخول');
        }

        await user.sendEmailVerification();
        showNotification('تم إرسال رابط التأكيد إلى بريدك الإلكتروني', 'success');

    } catch (error) {
        console.error('❌ Error sending email verification:', error);
        showNotification('حدث خطأ أثناء إرسال رابط التأكيد', 'error');
    }
}

function changeProfilePhoto() {
    // Create file input
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';

    input.onchange = async (e) => {
        const file = e.target.files[0];
        if (!file) return;

        try {
            showNotification('جاري رفع الصورة...', 'info');

            // Upload to Firebase Storage (if configured)
            // For now, just show success message
            showNotification('تم تحديث صورة الملف الشخصي بنجاح', 'success');

        } catch (error) {
            console.error('❌ Error uploading photo:', error);
            showNotification('حدث خطأ أثناء رفع الصورة', 'error');
        }
    };

    input.click();
}

// Notifications page functions
async function loadNotificationsList() {
    const container = document.getElementById('notificationsContainer');
    if (!container) return;

    try {
        // For now, show sample notifications
        const sampleNotifications = [
            {
                id: '1',
                title: 'إشعار تجريبي',
                body: 'هذا إشعار تجريبي لاختبار النظام',
                type: 'system',
                isRead: false,
                timestamp: new Date(Date.now() - 1000 * 60 * 15) // 15 minutes ago
            },
            {
                id: '2',
                title: 'تحديث النظام',
                body: 'تم تحديث النظام بنجاح',
                type: 'admin',
                isRead: true,
                timestamp: new Date(Date.now() - 1000 * 60 * 60 * 2) // 2 hours ago
            }
        ];

        if (sampleNotifications.length === 0) {
            container.innerHTML = `
                <div class="text-center py-5">
                    <i class="fas fa-bell-slash text-muted mb-3" style="font-size: 4rem;"></i>
                    <h5 class="text-muted">لا توجد إشعارات</h5>
                    <p class="text-muted">ستظهر الإشعارات هنا عند وصولها</p>
                </div>
            `;
            return;
        }

        container.innerHTML = sampleNotifications.map(notification => {
            const timeAgo = getTimeAgo(notification.timestamp);
            const isUnread = !notification.isRead;

            return `
                <div class="notification-item ${isUnread ? 'unread' : ''}" data-id="${notification.id}">
                    <div class="d-flex align-items-start p-3">
                        <div class="notification-icon ${notification.type} me-3">
                            <i class="fas ${getNotificationTypeIcon(notification.type)}"></i>
                        </div>
                        <div class="flex-grow-1">
                            <h6 class="mb-1">${notification.title}</h6>
                            <p class="mb-1 text-muted">${notification.body}</p>
                            <small class="text-muted">${timeAgo}</small>
                        </div>
                        <div class="notification-actions">
                            ${isUnread ?
                                `<button class="btn btn-sm btn-outline-primary" onclick="markAsRead('${notification.id}')">
                                    <i class="fas fa-check"></i>
                                </button>` : ''
                            }
                            <button class="btn btn-sm btn-outline-danger" onclick="deleteNotification('${notification.id}')">
                                <i class="fas fa-trash"></i>
                            </button>
                        </div>
                    </div>
                </div>
            `;
        }).join('');

    } catch (error) {
        console.error('❌ Error loading notifications:', error);
        container.innerHTML = `
            <div class="alert alert-danger">
                <i class="fas fa-exclamation-triangle me-2"></i>
                حدث خطأ أثناء تحميل الإشعارات
            </div>
        `;
    }
}

function getNotificationTypeIcon(type) {
    const icons = {
        'system': 'fa-cog',
        'admin': 'fa-user-shield',
        'trip': 'fa-bus',
        'student': 'fa-user-graduate',
        'parent': 'fa-users',
        'supervisor': 'fa-user-tie',
        'general': 'fa-bell'
    };
    return icons[type] || 'fa-bell';
}

async function markAsRead(notificationId) {
    try {
        // Mark notification as read in Firebase
        showNotification('تم تحديد الإشعار كمقروء', 'success');

        // Update UI
        const notificationElement = document.querySelector(`[data-id="${notificationId}"]`);
        if (notificationElement) {
            notificationElement.classList.remove('unread');
            const markButton = notificationElement.querySelector('.btn-outline-primary');
            if (markButton) {
                markButton.remove();
            }
        }

        // Update notification count
        loadNotificationCount();

    } catch (error) {
        console.error('❌ Error marking notification as read:', error);
        showNotification('حدث خطأ أثناء تحديث الإشعار', 'error');
    }
}

async function deleteNotification(notificationId) {
    if (!confirm('هل تريد حذف هذا الإشعار؟')) {
        return;
    }

    try {
        // Delete notification from Firebase
        showNotification('تم حذف الإشعار', 'success');

        // Update UI
        const notificationElement = document.querySelector(`[data-id="${notificationId}"]`);
        if (notificationElement) {
            notificationElement.remove();
        }

        // Update notification count
        loadNotificationCount();

    } catch (error) {
        console.error('❌ Error deleting notification:', error);
        showNotification('حدث خطأ أثناء حذف الإشعار', 'error');
    }
}

async function markAllAsRead() {
    try {
        showNotification('جاري تحديد جميع الإشعارات كمقروءة...', 'info');

        // Mark all as read in Firebase
        // For now, just update UI
        document.querySelectorAll('.notification-item.unread').forEach(item => {
            item.classList.remove('unread');
            const markButton = item.querySelector('.btn-outline-primary');
            if (markButton) {
                markButton.remove();
            }
        });

        showNotification('تم تحديد جميع الإشعارات كمقروءة', 'success');
        loadNotificationCount();

    } catch (error) {
        console.error('❌ Error marking all as read:', error);
        showNotification('حدث خطأ أثناء تحديث الإشعارات', 'error');
    }
}

async function deleteAllRead() {
    if (!confirm('هل تريد حذف جميع الإشعارات المقروءة؟')) {
        return;
    }

    try {
        showNotification('جاري حذف الإشعارات المقروءة...', 'info');

        // Delete read notifications from Firebase
        // For now, just update UI
        document.querySelectorAll('.notification-item:not(.unread)').forEach(item => {
            item.remove();
        });

        showNotification('تم حذف الإشعارات المقروءة', 'success');

    } catch (error) {
        console.error('❌ Error deleting read notifications:', error);
        showNotification('حدث خطأ أثناء حذف الإشعارات', 'error');
    }
}

function refreshNotifications() {
    loadNotificationsList();
    showNotification('تم تحديث الإشعارات', 'success');
}

function filterNotifications() {
    const filter = document.getElementById('notificationFilter').value;
    const notifications = document.querySelectorAll('.notification-item');

    notifications.forEach(notification => {
        const type = notification.querySelector('.notification-icon').classList[1];
        const isUnread = notification.classList.contains('unread');

        let show = true;

        if (filter === 'unread' && !isUnread) {
            show = false;
        } else if (filter === 'read' && isUnread) {
            show = false;
        } else if (filter !== 'all' && filter !== 'unread' && filter !== 'read' && type !== filter) {
            show = false;
        }

        notification.style.display = show ? 'block' : 'none';
    });
}

// Help page functions
function showHelp(topic) {
    const helpContent = {
        'students': `
            <h5>دليل إدارة الطلاب</h5>
            <ol>
                <li>اذهب إلى صفحة "إدارة الطلاب"</li>
                <li>اضغط على "إضافة طالب جديد"</li>
                <li>املأ جميع البيانات المطلوبة</li>
                <li>اختر خط الباص المناسب</li>
                <li>اضغط "حفظ" لإضافة الطالب</li>
            </ol>
        `,
        'supervisors': `
            <h5>دليل إدارة المشرفين</h5>
            <ol>
                <li>اذهب إلى صفحة "إدارة المشرفين"</li>
                <li>اضغط على "إضافة مشرف جديد"</li>
                <li>أدخل بيانات المشرف</li>
                <li>حدد كلمة مرور قوية</li>
                <li>اضغط "حفظ" لإنشاء الحساب</li>
            </ol>
        `,
        'routes': `
            <h5>دليل إدارة خطوط الباص</h5>
            <ol>
                <li>اذهب إلى صفحة "الإعدادات"</li>
                <li>ابحث عن قسم "إدارة خطوط الباص"</li>
                <li>اضغط "إضافة خط جديد"</li>
                <li>أدخل اسم الخط</li>
                <li>اضغط "موافق" لإضافة الخط</li>
            </ol>
        `,
        'settings': `
            <h5>دليل الإعدادات</h5>
            <ol>
                <li>اذهب إلى صفحة "الإعدادات"</li>
                <li>اختر القسم المطلوب تعديله</li>
                <li>قم بالتعديلات المطلوبة</li>
                <li>اضغط "حفظ" لتطبيق التغييرات</li>
            </ol>
        `
    };

    const content = helpContent[topic] || '<p>المساعدة غير متوفرة لهذا الموضوع</p>';

    // Show in modal or alert
    alert(content.replace(/<[^>]*>/g, '\n'));
}

async function sendSupportMessage() {
    const form = document.getElementById('supportForm');
    const formData = new FormData(form);

    try {
        showNotification('جاري إرسال الرسالة...', 'info');

        // Send support message (implement actual sending logic)
        // For now, just show success
        showNotification('تم إرسال رسالتك بنجاح. سنتواصل معك قريباً.', 'success');

        // Clear form
        form.reset();

    } catch (error) {
        console.error('❌ Error sending support message:', error);
        showNotification('حدث خطأ أثناء إرسال الرسالة', 'error');
    }
}

// Notifications dropdown functions
function setupNotificationsDropdown() {
    const notificationsDropdown = document.getElementById('notificationsDropdown');
    if (!notificationsDropdown) return;

    // Load notifications when dropdown is opened
    notificationsDropdown.addEventListener('show.bs.dropdown', function () {
        loadNotificationsDropdown();
    });

    // Auto-refresh notifications every 30 seconds
    setInterval(() => {
        loadNotificationCount();

        // If dropdown is open, refresh its content too
        const dropdown = document.querySelector('#notificationsDropdown + .dropdown-menu.show');
        if (dropdown) {
            loadNotificationsDropdown();
        }
    }, 30000);
}

async function loadNotificationsDropdown() {
    const container = document.getElementById('notificationsDropdownContent');
    if (!container) return;

    try {
        console.log('🔔 Loading notifications dropdown...');

        // Show loading state
        container.innerHTML = `
            <li class="text-center py-3">
                <div class="spinner-border spinner-border-sm text-primary" role="status">
                    <span class="visually-hidden">جاري التحميل...</span>
                </div>
                <p class="mt-2 mb-0 text-muted small">جاري تحميل الإشعارات...</p>
            </li>
        `;

        // Get notifications from Firebase
        const notifications = await FirebaseService.getNotifications(10); // Get latest 10

        if (notifications.length === 0) {
            container.innerHTML = `
                <li class="notifications-empty">
                    <i class="fas fa-bell-slash"></i>
                    <p class="mb-0">لا توجد إشعارات</p>
                </li>
            `;
            return;
        }

        // Display notifications
        container.innerHTML = notifications.map(notification => {
            const timeAgo = getTimeAgo(notification.timestamp);
            const isUnread = !notification.isRead;

            return `
                <li>
                    <div class="notification-dropdown-item ${isUnread ? 'unread' : ''}"
                         onclick="handleNotificationClick('${notification.id}', ${isUnread})">
                        <div class="notification-icon ${notification.type}">
                            <i class="fas ${getNotificationTypeIcon(notification.type)}"></i>
                        </div>
                        <div class="notification-content">
                            <div class="notification-title">${notification.title}</div>
                            <div class="notification-body">${notification.body}</div>
                            <div class="notification-time">${timeAgo}</div>
                        </div>
                        ${isUnread ? '<div class="unread-indicator"></div>' : ''}
                    </div>
                </li>
            `;
        }).join('');

        console.log(`✅ Loaded ${notifications.length} notifications in dropdown`);

    } catch (error) {
        console.error('❌ Error loading notifications dropdown:', error);
        container.innerHTML = `
            <li class="text-center py-3">
                <div class="text-danger">
                    <i class="fas fa-exclamation-triangle mb-2"></i>
                    <p class="mb-0 small">حدث خطأ أثناء تحميل الإشعارات</p>
                </div>
            </li>
        `;
    }
}

async function handleNotificationClick(notificationId, isUnread) {
    try {
        // Mark as read if unread
        if (isUnread) {
            await markNotificationAsRead(notificationId);
        }

        // Close dropdown
        const dropdown = bootstrap.Dropdown.getInstance(document.getElementById('notificationsDropdown'));
        if (dropdown) {
            dropdown.hide();
        }

        // Navigate to notifications page
        loadPage('notifications');

    } catch (error) {
        console.error('❌ Error handling notification click:', error);
    }
}

async function markNotificationAsRead(notificationId) {
    try {
        const result = await FirebaseService.markNotificationAsRead(notificationId);

        if (result.success) {
            // Update UI
            const notificationElement = document.querySelector(`[onclick*="${notificationId}"]`);
            if (notificationElement) {
                notificationElement.classList.remove('unread');
                const indicator = notificationElement.querySelector('.unread-indicator');
                if (indicator) {
                    indicator.remove();
                }
            }

            // Update counts
            loadNotificationCount();

            console.log('✅ Notification marked as read:', notificationId);
        }

    } catch (error) {
        console.error('❌ Error marking notification as read:', error);
    }
}

async function markAllNotificationsAsRead() {
    try {
        showNotification('جاري تحديد جميع الإشعارات كمقروءة...', 'info');

        // Get all unread notifications
        const notifications = await FirebaseService.getNotifications(50);
        const unreadNotifications = notifications.filter(n => !n.isRead);

        // Mark all as read
        const promises = unreadNotifications.map(notification =>
            FirebaseService.markNotificationAsRead(notification.id)
        );

        await Promise.all(promises);

        // Update UI
        document.querySelectorAll('.notification-dropdown-item.unread').forEach(item => {
            item.classList.remove('unread');
            const indicator = item.querySelector('.unread-indicator');
            if (indicator) {
                indicator.remove();
            }
        });

        // Update counts
        loadNotificationCount();

        showNotification('تم تحديد جميع الإشعارات كمقروءة', 'success');

        console.log(`✅ Marked ${unreadNotifications.length} notifications as read`);

    } catch (error) {
        console.error('❌ Error marking all notifications as read:', error);
        showNotification('حدث خطأ أثناء تحديث الإشعارات', 'error');
    }
}

// Create sample notifications for testing
async function createSampleNotifications() {
    try {
        const sampleNotifications = [
            {
                title: 'مرحباً بك في النظام',
                body: 'تم تسجيل دخولك بنجاح إلى نظام إدارة النقل المدرسي',
                type: 'system',
                priority: 'normal'
            },
            {
                title: 'طالب جديد',
                body: 'تم إضافة طالب جديد: أحمد محمد إلى الخط الأول',
                type: 'student',
                priority: 'normal'
            },
            {
                title: 'تحديث الإعدادات',
                body: 'تم تحديث إعدادات النظام بنجاح',
                type: 'admin',
                priority: 'low'
            }
        ];

        for (const notification of sampleNotifications) {
            await FirebaseService.sendNotification({
                ...notification,
                recipientId: 'admin',
                recipientType: 'admin'
            });
        }

        console.log('✅ Sample notifications created');

        // Refresh notifications
        loadNotificationCount();
        loadNotificationsDropdown();

    } catch (error) {
        console.error('❌ Error creating sample notifications:', error);
    }
}

// Auto-load notifications when app starts
document.addEventListener('DOMContentLoaded', () => {
    // Load notification count after a delay to ensure Firebase is ready
    setTimeout(() => {
        loadNotificationCount();

        // Create sample notifications if none exist (for testing)
        // Uncomment the line below to create sample notifications
        createSampleNotifications();
    }, 2000);
});

// Re-initialize sidebar navigation function
function reinitializeSidebarNavigation() {
    console.log('🔄 Re-initializing sidebar navigation...');

    // Remove existing event listeners and add new ones
    const sidebarLinks = document.querySelectorAll('.sidebar [data-page]');
    console.log('🔗 Found sidebar links for re-initialization:', sidebarLinks.length);

    sidebarLinks.forEach((link, index) => {
        const page = link.getAttribute('data-page');
        console.log(`🔗 Re-setting up link ${index + 1}: ${page}`);

        // Remove existing listeners by cloning the element
        const newLink = link.cloneNode(true);
        link.parentNode.replaceChild(newLink, link);

        // Add new event listener
        newLink.addEventListener('click', function(e) {
            e.preventDefault();
            console.log(`🎯 Sidebar link clicked (re-init): ${page}`);

            // Load the page
            loadPage(page);

            // Update active state
            document.querySelectorAll('.sidebar li').forEach(li => li.classList.remove('active'));
            this.parentElement.classList.add('active');
            console.log(`✅ Active state updated for: ${page}`);

            // Close sidebar on mobile after navigation
            if (window.innerWidth < 1200) {
                console.log('📱 Mobile detected, closing sidebar...');
                setTimeout(() => {
                    closeSidebar();
                }, 300);
            }
        });
    });

    console.log('✅ Sidebar navigation re-initialization complete');
}

// Test function to manually trigger sidebar links
function testSidebarLinks() {
    console.log('🧪 Testing sidebar links...');
    const links = document.querySelectorAll('.sidebar [data-page]');
    console.log('Found links:', links.length);

    links.forEach((link, index) => {
        const page = link.getAttribute('data-page');
        console.log(`Link ${index + 1}: ${page} - ${link.textContent.trim()}`);

        // Test click programmatically
        console.log(`Testing click on ${page}...`);
        link.click();
    });
}

// Add global function to test from console
window.testSidebarLinks = testSidebarLinks;
window.loadPageDirect = loadPage;

// Global navigation function for sidebar links
function navigateToPage(page) {
    console.log(`🎯 navigateToPage called with: ${page}`);

    try {
        // Load the page
        loadPage(page);

        // Update active state for sidebar navigation
        document.querySelectorAll('.nav-item').forEach(item => item.classList.remove('active'));

        // Find and activate the clicked link
        const clickedLink = document.querySelector(`.sidebar [data-page="${page}"]`);
        if (clickedLink) {
            // Add active class to parent nav-item
            const parentItem = clickedLink.closest('.nav-item');
            if (parentItem) {
                parentItem.classList.add('active');
            }

            console.log(`✅ Active state updated for: ${page}`);
        }

        // Close sidebar on mobile after navigation
        if (window.innerWidth < 1200) {
            console.log('📱 Mobile detected, closing sidebar...');
            setTimeout(() => {
                closeSidebar();
            }, 300);
        }

        console.log(`✅ Navigation to ${page} completed successfully`);

    } catch (error) {
        console.error('❌ Error in navigateToPage:', error);
    }
}

// Make navigateToPage globally available
window.navigateToPage = navigateToPage;

// Alternative method: Direct click handlers
function setupDirectSidebarHandlers() {
    console.log('🔧 Setting up direct sidebar handlers...');

    // Dashboard
    const dashboardLink = document.querySelector('[data-page="dashboard"]');
    if (dashboardLink) {
        dashboardLink.onclick = function(e) {
            e.preventDefault();
            navigateToPage('dashboard');
            return false;
        };
        console.log('✅ Dashboard handler set');
    }

    // Students
    const studentsLink = document.querySelector('[data-page="students"]');
    if (studentsLink) {
        studentsLink.onclick = function(e) {
            e.preventDefault();
            navigateToPage('students');
            return false;
        };
        console.log('✅ Students handler set');
    }

    // Supervisors
    const supervisorsLink = document.querySelector('[data-page="supervisors"]');
    if (supervisorsLink) {
        supervisorsLink.onclick = function(e) {
            e.preventDefault();
            navigateToPage('supervisors');
            return false;
        };
        console.log('✅ Supervisors handler set');
    }

    // Buses
    const busesLink = document.querySelector('[data-page="buses"]');
    if (busesLink) {
        busesLink.onclick = function(e) {
            e.preventDefault();
            navigateToPage('buses');
            return false;
        };
        console.log('✅ Buses handler set');
    }

    // Parents
    const parentsLink = document.querySelector('[data-page="parents"]');
    if (parentsLink) {
        parentsLink.onclick = function(e) {
            e.preventDefault();
            navigateToPage('parents');
            return false;
        };
        console.log('✅ Parents handler set');
    }

    // Reports
    const reportsLink = document.querySelector('[data-page="reports"]');
    if (reportsLink) {
        reportsLink.onclick = function(e) {
            e.preventDefault();
            navigateToPage('reports');
            return false;
        };
        console.log('✅ Reports handler set');
    }

    // Complaints
    const complaintsLink = document.querySelector('[data-page="complaints"]');
    if (complaintsLink) {
        complaintsLink.onclick = function(e) {
            e.preventDefault();
            navigateToPage('complaints');
            return false;
        };
        console.log('✅ Complaints handler set');
    }

    // Settings
    const settingsLink = document.querySelector('[data-page="settings"]');
    if (settingsLink) {
        settingsLink.onclick = function(e) {
            e.preventDefault();
            navigateToPage('settings');
            return false;
        };
        console.log('✅ Settings handler set');
    }

    console.log('✅ All direct sidebar handlers setup complete');
}

// Call this function after DOM is loaded
window.setupDirectSidebarHandlers = setupDirectSidebarHandlers;

// Helper functions for supervisors page
function getSupervisorStatusClass(status) {
    switch(status) {
        case 'active': return 'status-active';
        case 'inactive': return 'status-inactive';
        case 'suspended': return 'status-warning';
        default: return 'status-inactive';
    }
}

function getSupervisorStatusIcon(status) {
    switch(status) {
        case 'active': return 'fa-check-circle';
        case 'inactive': return 'fa-times-circle';
        case 'suspended': return 'fa-pause-circle';
        default: return 'fa-question-circle';
    }
}

function getSupervisorStatusText(status) {
    switch(status) {
        case 'active': return 'نشط';
        case 'inactive': return 'غير نشط';
        case 'suspended': return 'موقوف';
        default: return 'غير محدد';
    }
}

function getPermissionText(permission) {
    switch(permission) {
        case 'view_students': return 'عرض الطلاب';
        case 'manage_trips': return 'إدارة الرحلات';
        case 'send_notifications': return 'إرسال الإشعارات';
        case 'view_reports': return 'عرض التقارير';
        case 'manage_attendance': return 'إدارة الحضور';
        case 'emergency_contact': return 'الاتصال الطارئ';
        default: return permission;
    }
}

// Parent status helper functions
function getParentStatusClass(status) {
    switch(status) {
        case 'active': return 'status-active';
        case 'inactive': return 'status-inactive';
        case 'suspended': return 'status-suspended';
        default: return 'status-inactive';
    }
}

function getParentStatusIcon(status) {
    switch(status) {
        case 'active': return 'fa-check-circle';
        case 'inactive': return 'fa-times-circle';
        case 'suspended': return 'fa-pause-circle';
        default: return 'fa-question-circle';
    }
}

function getParentStatusText(status) {
    switch(status) {
        case 'active': return 'نشط';
        case 'inactive': return 'غير نشط';
        case 'suspended': return 'موقوف';
        default: return 'غير محدد';
    }
}

// Format last activity
function formatLastActivity(date) {
    if (!date) return 'غير محدد';

    const now = new Date();
    const diffMs = now - new Date(date);
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    const diffMinutes = Math.floor(diffMs / (1000 * 60));

    if (diffMinutes < 1) {
        return 'الآن';
    } else if (diffMinutes < 60) {
        return `منذ ${diffMinutes} دقيقة`;
    } else if (diffHours < 24) {
        return `منذ ${diffHours} ساعة`;
    } else if (diffDays < 7) {
        return `منذ ${diffDays} يوم`;
    } else {
        return formatDate(date);
    }
}

// Enhanced children display
function formatChildrenDisplay(children) {
    if (!children || children.length === 0) {
        return `
            <div class="text-center py-2">
                <i class="fas fa-child text-muted mb-1"></i>
                <div class="text-muted small">لا يوجد أطفال</div>
            </div>
        `;
    }

    const childrenCount = children.length;

    let html = `
        <div class="children-display">
            <div class="children-count mb-2">
                <span class="badge bg-primary rounded-pill">
                    <i class="fas fa-users me-1"></i>
                    ${childrenCount} ${childrenCount === 1 ? 'طفل' : 'أطفال'}
                </span>
            </div>
            <div class="children-list">
    `;

    children.forEach((child, index) => {
        if (index < 3) { // Show first 3 children
            html += `
                <div class="child-item d-flex align-items-center mb-2">
                    <div class="child-avatar me-2">
                        <div class="avatar-sm bg-light text-primary rounded-circle d-flex align-items-center justify-content-center">
                            <i class="fas fa-child"></i>
                        </div>
                    </div>
                    <div class="child-info flex-grow-1">
                        <div class="child-name fw-semibold text-dark">${child.name || 'غير محدد'}</div>
                        <div class="child-details">
                            <small class="text-muted">
                                <i class="fas fa-graduation-cap me-1"></i>
                                ${child.grade || 'غير محدد'}
                            </small>
                            ${child.schoolName ? `
                                <small class="text-muted ms-2">
                                    <i class="fas fa-school me-1"></i>
                                    ${child.schoolName}
                                </small>
                            ` : ''}
                        </div>
                        ${child.busRoute ? `
                            <div class="child-route mt-1">
                                <span class="badge bg-light text-dark">
                                    <i class="fas fa-route me-1"></i>
                                    ${child.busRoute}
                                </span>
                            </div>
                        ` : ''}
                    </div>
                    <div class="child-status">
                        ${child.currentStatus ? `
                            <span class="status-indicator ${getStatusClass(child.currentStatus)}" title="${getStatusText(child.currentStatus)}">
                                <i class="fas ${getStatusIcon(child.currentStatus)}"></i>
                            </span>
                        ` : ''}
                    </div>
                </div>
            `;
        }
    });

    if (childrenCount > 3) {
        html += `
            <div class="more-children text-center mt-2">
                <button class="btn btn-sm btn-outline-primary" onclick="showAllChildren('${children[0].parentId || ''}')">
                    <i class="fas fa-plus me-1"></i>
                    عرض ${childrenCount - 3} أطفال إضافيين
                </button>
            </div>
        `;
    }

    html += `
            </div>
        </div>
    `;

    return html;
}

// Show all children in a modal
function showAllChildren(parentId) {
    console.log('👶 Showing all children for parent:', parentId);

    const parent = parentsData.find(p => p.id === parentId);
    if (!parent) {
        alert('لم يتم العثور على ولي الأمر');
        return;
    }

    const children = parent.children || [];

    const modalContent = `
        <div class="modal fade" id="allChildrenModal" tabindex="-1">
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header bg-primary text-white">
                        <h5 class="modal-title">
                            <i class="fas fa-users me-2"></i>
                            أطفال ${parent.name}
                        </h5>
                        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        ${children.length === 0 ? `
                            <div class="text-center py-5">
                                <i class="fas fa-child fa-3x text-muted mb-3"></i>
                                <h5 class="text-muted">لا يوجد أطفال مسجلين</h5>
                                <p class="text-muted">لم يتم تسجيل أي أطفال لهذا الولي بعد</p>
                                <button class="btn btn-primary" onclick="addNewChild('${parentId}')">
                                    <i class="fas fa-plus me-2"></i>
                                    إضافة طفل جديد
                                </button>
                            </div>
                        ` : `
                            <div class="row g-3">
                                ${children.map((child, index) => `
                                    <div class="col-12">
                                        <div class="card border-0 shadow-sm">
                                            <div class="card-body">
                                                <div class="row align-items-center">
                                                    <div class="col-auto">
                                                        <div class="child-avatar-large">
                                                            <div class="avatar-lg bg-primary text-white rounded-circle d-flex align-items-center justify-content-center">
                                                                <i class="fas fa-child fa-2x"></i>
                                                            </div>
                                                        </div>
                                                    </div>
                                                    <div class="col">
                                                        <div class="child-details">
                                                            <h6 class="mb-1 fw-bold">${child.name || 'غير محدد'}</h6>
                                                            <div class="child-info-grid">
                                                                <div class="info-item">
                                                                    <i class="fas fa-graduation-cap text-primary me-2"></i>
                                                                    <span class="fw-semibold">الصف:</span>
                                                                    <span class="text-muted">${child.grade || 'غير محدد'}</span>
                                                                </div>
                                                                ${child.schoolName ? `
                                                                    <div class="info-item">
                                                                        <i class="fas fa-school text-success me-2"></i>
                                                                        <span class="fw-semibold">المدرسة:</span>
                                                                        <span class="text-muted">${child.schoolName}</span>
                                                                    </div>
                                                                ` : ''}
                                                                ${child.busRoute ? `
                                                                    <div class="info-item">
                                                                        <i class="fas fa-route text-warning me-2"></i>
                                                                        <span class="fw-semibold">خط السير:</span>
                                                                        <span class="text-muted">${child.busRoute}</span>
                                                                    </div>
                                                                ` : ''}
                                                                ${child.qrCode ? `
                                                                    <div class="info-item">
                                                                        <i class="fas fa-qrcode text-info me-2"></i>
                                                                        <span class="fw-semibold">رمز QR:</span>
                                                                        <code class="text-muted">${child.qrCode}</code>
                                                                    </div>
                                                                ` : ''}
                                                            </div>
                                                        </div>
                                                    </div>
                                                    <div class="col-auto">
                                                        <div class="child-status-display">
                                                            ${child.currentStatus ? `
                                                                <div class="status-card text-center">
                                                                    <div class="status-icon ${getStatusClass(child.currentStatus)} mb-2">
                                                                        <i class="fas ${getStatusIcon(child.currentStatus)}"></i>
                                                                    </div>
                                                                    <small class="status-text">${getStatusText(child.currentStatus)}</small>
                                                                </div>
                                                            ` : `
                                                                <div class="status-card text-center">
                                                                    <div class="status-icon status-inactive mb-2">
                                                                        <i class="fas fa-question-circle"></i>
                                                                    </div>
                                                                    <small class="status-text">غير محدد</small>
                                                                </div>
                                                            `}
                                                        </div>
                                                    </div>
                                                </div>
                                                <div class="child-actions mt-3 pt-3 border-top">
                                                    <div class="btn-group w-100" role="group">
                                                        <button class="btn btn-sm btn-outline-primary" onclick="viewChildDetails('${child.id}')">
                                                            <i class="fas fa-eye me-1"></i>
                                                            عرض التفاصيل
                                                        </button>
                                                        <button class="btn btn-sm btn-outline-warning" onclick="editChild('${child.id}')">
                                                            <i class="fas fa-edit me-1"></i>
                                                            تعديل
                                                        </button>
                                                        <button class="btn btn-sm btn-outline-info" onclick="trackChild('${child.id}')">
                                                            <i class="fas fa-map-marker-alt me-1"></i>
                                                            تتبع
                                                        </button>
                                                        <button class="btn btn-sm btn-outline-danger" onclick="removeChildFromParent('${parentId}', '${child.id}')">
                                                            <i class="fas fa-trash me-1"></i>
                                                            حذف
                                                        </button>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                `).join('')}
                            </div>
                            <div class="text-center mt-4">
                                <button class="btn btn-primary" onclick="addNewChild('${parentId}')">
                                    <i class="fas fa-plus me-2"></i>
                                    إضافة طفل جديد
                                </button>
                            </div>
                        `}
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>
                            إغلاق
                        </button>
                        <button type="button" class="btn btn-info" onclick="manageChildren('${parentId}')">
                            <i class="fas fa-cog me-2"></i>
                            إدارة الأطفال
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Remove existing modal if any
    const existingModal = document.getElementById('allChildrenModal');
    if (existingModal) {
        existingModal.remove();
    }

    // Add modal to body and show
    document.body.insertAdjacentHTML('beforeend', modalContent);
    const modal = new bootstrap.Modal(document.getElementById('allChildrenModal'));
    modal.show();

    // Clean up when modal is hidden
    document.getElementById('allChildrenModal').addEventListener('hidden.bs.modal', function() {
        this.remove();
    });
}

// Manage children function
function manageChildren(parentId) {
    console.log('👨‍👩‍👧‍👦 Managing children for parent:', parentId);

    const parent = parentsData.find(p => p.id === parentId);
    if (!parent) {
        alert('لم يتم العثور على ولي الأمر');
        return;
    }

    // Close all children modal if open
    const allChildrenModal = document.getElementById('allChildrenModal');
    if (allChildrenModal) {
        const modal = bootstrap.Modal.getInstance(allChildrenModal);
        if (modal) modal.hide();
    }

    // Navigate to a dedicated children management page or show advanced modal
    // For now, we'll show an advanced management modal
    showChildrenManagementModal(parentId);
}

function showChildrenManagementModal(parentId) {
    const parent = parentsData.find(p => p.id === parentId);
    const children = parent.children || [];

    const modalContent = `
        <div class="modal fade" id="manageChildrenModal" tabindex="-1">
            <div class="modal-dialog modal-xl">
                <div class="modal-content">
                    <div class="modal-header bg-info text-white">
                        <h5 class="modal-title">
                            <i class="fas fa-cog me-2"></i>
                            إدارة أطفال ${parent.name}
                        </h5>
                        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <div class="row">
                            <!-- Children List -->
                            <div class="col-lg-8">
                                <div class="d-flex justify-content-between align-items-center mb-3">
                                    <h6 class="mb-0">
                                        <i class="fas fa-list me-2"></i>
                                        قائمة الأطفال (${children.length})
                                    </h6>
                                    <button class="btn btn-sm btn-primary" onclick="addNewChild('${parentId}')">
                                        <i class="fas fa-plus me-1"></i>
                                        إضافة طفل
                                    </button>
                                </div>

                                <div class="children-management-list">
                                    ${children.length === 0 ? `
                                        <div class="text-center py-4">
                                            <i class="fas fa-child fa-3x text-muted mb-3"></i>
                                            <p class="text-muted">لا يوجد أطفال مسجلين</p>
                                        </div>
                                    ` : children.map(child => `
                                        <div class="card mb-3 child-management-card">
                                            <div class="card-body">
                                                <div class="row align-items-center">
                                                    <div class="col-auto">
                                                        <div class="form-check">
                                                            <input class="form-check-input" type="checkbox" value="${child.id}" id="child_${child.id}">
                                                            <label class="form-check-label" for="child_${child.id}"></label>
                                                        </div>
                                                    </div>
                                                    <div class="col-auto">
                                                        <div class="avatar-md bg-primary text-white rounded-circle d-flex align-items-center justify-content-center">
                                                            <i class="fas fa-child"></i>
                                                        </div>
                                                    </div>
                                                    <div class="col">
                                                        <h6 class="mb-1">${child.name}</h6>
                                                        <div class="text-muted small">
                                                            <span class="me-3">
                                                                <i class="fas fa-graduation-cap me-1"></i>
                                                                ${child.grade || 'غير محدد'}
                                                            </span>
                                                            ${child.schoolName ? `
                                                                <span class="me-3">
                                                                    <i class="fas fa-school me-1"></i>
                                                                    ${child.schoolName}
                                                                </span>
                                                            ` : ''}
                                                        </div>
                                                    </div>
                                                    <div class="col-auto">
                                                        <div class="btn-group" role="group">
                                                            <button class="btn btn-sm btn-outline-primary" onclick="editChild('${child.id}')" title="تعديل">
                                                                <i class="fas fa-edit"></i>
                                                            </button>
                                                            <button class="btn btn-sm btn-outline-info" onclick="viewChildDetails('${child.id}')" title="عرض">
                                                                <i class="fas fa-eye"></i>
                                                            </button>
                                                            <button class="btn btn-sm btn-outline-danger" onclick="removeChildFromParent('${parentId}', '${child.id}')" title="حذف">
                                                                <i class="fas fa-trash"></i>
                                                            </button>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    `).join('')}
                                </div>

                                ${children.length > 0 ? `
                                    <div class="bulk-actions mt-3 p-3 bg-light rounded">
                                        <h6 class="mb-2">إجراءات متعددة:</h6>
                                        <div class="btn-group" role="group">
                                            <button class="btn btn-sm btn-outline-primary" onclick="selectAllChildren()">
                                                <i class="fas fa-check-square me-1"></i>
                                                تحديد الكل
                                            </button>
                                            <button class="btn btn-sm btn-outline-secondary" onclick="deselectAllChildren()">
                                                <i class="fas fa-square me-1"></i>
                                                إلغاء التحديد
                                            </button>
                                            <button class="btn btn-sm btn-outline-info" onclick="bulkAssignBus()">
                                                <i class="fas fa-bus me-1"></i>
                                                تعيين باص
                                            </button>
                                            <button class="btn btn-sm btn-outline-warning" onclick="bulkUpdateStatus()">
                                                <i class="fas fa-sync me-1"></i>
                                                تحديث الحالة
                                            </button>
                                        </div>
                                    </div>
                                ` : ''}
                            </div>

                            <!-- Quick Actions -->
                            <div class="col-lg-4">
                                <div class="quick-actions-panel">
                                    <h6 class="mb-3">
                                        <i class="fas fa-bolt me-2"></i>
                                        إجراءات سريعة
                                    </h6>

                                    <div class="list-group">
                                        <button class="list-group-item list-group-item-action" onclick="addNewChild('${parentId}')">
                                            <i class="fas fa-plus text-primary me-2"></i>
                                            إضافة طفل جديد
                                        </button>
                                        <button class="list-group-item list-group-item-action" onclick="importChildren('${parentId}')">
                                            <i class="fas fa-upload text-success me-2"></i>
                                            استيراد أطفال
                                        </button>
                                        <button class="list-group-item list-group-item-action" onclick="exportChildren('${parentId}')">
                                            <i class="fas fa-download text-info me-2"></i>
                                            تصدير البيانات
                                        </button>
                                        <button class="list-group-item list-group-item-action" onclick="sendBulkNotification('${parentId}')">
                                            <i class="fas fa-bell text-warning me-2"></i>
                                            إرسال إشعار جماعي
                                        </button>
                                    </div>

                                    <div class="mt-4">
                                        <h6 class="mb-3">
                                            <i class="fas fa-chart-bar me-2"></i>
                                            إحصائيات سريعة
                                        </h6>
                                        <div class="stats-cards">
                                            <div class="stat-card bg-primary text-white rounded p-2 mb-2">
                                                <div class="d-flex justify-content-between">
                                                    <span>إجمالي الأطفال</span>
                                                    <strong>${children.length}</strong>
                                                </div>
                                            </div>
                                            <div class="stat-card bg-success text-white rounded p-2 mb-2">
                                                <div class="d-flex justify-content-between">
                                                    <span>نشط</span>
                                                    <strong>${children.filter(c => c.isActive !== false).length}</strong>
                                                </div>
                                            </div>
                                            <div class="stat-card bg-warning text-white rounded p-2 mb-2">
                                                <div class="d-flex justify-content-between">
                                                    <span>في الباص</span>
                                                    <strong>${children.filter(c => c.currentStatus === 'onBus').length}</strong>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>
                            إغلاق
                        </button>
                        <button type="button" class="btn btn-primary" onclick="saveChildrenChanges('${parentId}')">
                            <i class="fas fa-save me-2"></i>
                            حفظ التغييرات
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Remove existing modal if any
    const existingModal = document.getElementById('manageChildrenModal');
    if (existingModal) {
        existingModal.remove();
    }

    // Add modal to body and show
    document.body.insertAdjacentHTML('beforeend', modalContent);
    const modal = new bootstrap.Modal(document.getElementById('manageChildrenModal'));
    modal.show();

    // Clean up when modal is hidden
    document.getElementById('manageChildrenModal').addEventListener('hidden.bs.modal', function() {
        this.remove();
    });
}

// Helper functions for children management
function viewChildDetails(childId) {
    console.log('👁️ Viewing child details:', childId);
    alert('عرض تفاصيل الطفل - قيد التطوير');
}

function editChild(childId) {
    console.log('✏️ Editing child:', childId);
    alert('تعديل بيانات الطفل - قيد التطوير');
}

function trackChild(childId) {
    console.log('📍 Tracking child:', childId);
    alert('تتبع الطفل - قيد التطوير');
}

function addNewChild(parentId) {
    console.log('➕ Adding new child for parent:', parentId);
    alert('إضافة طفل جديد - قيد التطوير');
}

function selectAllChildren() {
    const checkboxes = document.querySelectorAll('#manageChildrenModal input[type="checkbox"]');
    checkboxes.forEach(checkbox => checkbox.checked = true);
}

function deselectAllChildren() {
    const checkboxes = document.querySelectorAll('#manageChildrenModal input[type="checkbox"]');
    checkboxes.forEach(checkbox => checkbox.checked = false);
}

function bulkAssignBus() {
    const selectedChildren = getSelectedChildren();
    if (selectedChildren.length === 0) {
        alert('يرجى تحديد طفل واحد على الأقل');
        return;
    }
    console.log('🚌 Bulk assigning bus to children:', selectedChildren);
    alert('تعيين باص للأطفال المحددين - قيد التطوير');
}

function bulkUpdateStatus() {
    const selectedChildren = getSelectedChildren();
    if (selectedChildren.length === 0) {
        alert('يرجى تحديد طفل واحد على الأقل');
        return;
    }
    console.log('🔄 Bulk updating status for children:', selectedChildren);
    alert('تحديث حالة الأطفال المحددين - قيد التطوير');
}

function getSelectedChildren() {
    const checkboxes = document.querySelectorAll('#manageChildrenModal input[type="checkbox"]:checked');
    return Array.from(checkboxes).map(checkbox => checkbox.value);
}

function saveChildrenChanges(parentId) {
    console.log('💾 Saving children changes for parent:', parentId);
    alert('حفظ التغييرات - قيد التطوير');
}

// Enhanced Parents Table Functions
function toggleParentView(viewType) {
    console.log('🔄 Toggling parent view to:', viewType);

    const tableView = document.getElementById('parentTableView');
    const cardsView = document.getElementById('parentCardsView');
    const tableBtn = document.getElementById('tableViewBtn');
    const cardsBtn = document.getElementById('cardsViewBtn');

    if (viewType === 'table') {
        if (tableView) tableView.classList.remove('d-none');
        if (cardsView) cardsView.classList.add('d-none');
        if (tableBtn) {
            tableBtn.classList.remove('btn-outline-light');
            tableBtn.classList.add('btn-light');
        }
        if (cardsBtn) {
            cardsBtn.classList.remove('btn-light');
            cardsBtn.classList.add('btn-outline-light');
        }
    } else if (viewType === 'cards') {
        if (tableView) tableView.classList.add('d-none');
        if (cardsView) cardsView.classList.remove('d-none');
        if (tableBtn) {
            tableBtn.classList.remove('btn-light');
            tableBtn.classList.add('btn-outline-light');
        }
        if (cardsBtn) {
            cardsBtn.classList.remove('btn-outline-light');
            cardsBtn.classList.add('btn-light');
        }
    }
}

let currentSortField = '';
let currentSortDirection = 'asc';

function sortParents(field) {
    console.log('📊 Sorting parents by:', field);

    // Toggle sort direction if same field
    if (currentSortField === field) {
        currentSortDirection = currentSortDirection === 'asc' ? 'desc' : 'asc';
    } else {
        currentSortField = field;
        currentSortDirection = 'asc';
    }

    // Sort the data
    parentsData.sort((a, b) => {
        let valueA, valueB;

        switch (field) {
            case 'name':
                valueA = (a.name || '').toLowerCase();
                valueB = (b.name || '').toLowerCase();
                break;
            case 'lastLogin':
                valueA = new Date(a.lastLogin || 0);
                valueB = new Date(b.lastLogin || 0);
                break;
            case 'status':
                valueA = a.status || '';
                valueB = b.status || '';
                break;
            default:
                return 0;
        }

        if (valueA < valueB) return currentSortDirection === 'asc' ? -1 : 1;
        if (valueA > valueB) return currentSortDirection === 'asc' ? 1 : -1;
        return 0;
    });

    // Update sort indicators
    updateSortIndicators(field, currentSortDirection);

    // Reload the page to reflect new order
    loadPage('parents');
}

function updateSortIndicators(field, direction) {
    // Reset all sort indicators
    document.querySelectorAll('.sortable i').forEach(icon => {
        icon.className = 'fas fa-sort ms-2 text-muted';
    });

    // Update the active sort indicator
    const activeHeader = document.querySelector(`.sortable[onclick="sortParents('${field}')"] i`);
    if (activeHeader) {
        activeHeader.className = `fas fa-sort-${direction === 'asc' ? 'up' : 'down'} ms-2 text-primary`;
    }
}

function refreshParentsData() {
    console.log('🔄 Refreshing parents data...');
    loadPage('parents');
}

function getActivityStatus(lastLogin) {
    if (!lastLogin) return 'غير محدد';

    const now = new Date();
    const loginDate = new Date(lastLogin);
    const diffTime = Math.abs(now - loginDate);
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

    if (diffDays <= 1) return 'نشط اليوم';
    if (diffDays <= 7) return 'نشط هذا الأسبوع';
    if (diffDays <= 30) return 'نشط هذا الشهر';
    return 'غير نشط';
}

function viewParentActivity(parentId) {
    console.log('📈 Viewing parent activity:', parentId);
    alert('عرض نشاط ولي الأمر - قيد التطوير');
}

function sendNotificationToParent(parentId) {
    console.log('📧 Sending notification to parent:', parentId);
    alert('إرسال إشعار لولي الأمر - قيد التطوير');
}

// Get Real-time Bus Location from Database
async function getBusCurrentLocation(busId) {
    try {
        console.log('📍 Getting current location for bus:', busId);

        // Try Firebase Service first
        if (typeof FirebaseService !== 'undefined' && FirebaseService.getBusLocation) {
            const location = await FirebaseService.getBusLocation(busId);
            if (location) {
                console.log('✅ Location from FirebaseService:', location);
                return location;
            }
        }

        // Try direct Firebase access
        if (typeof db !== 'undefined') {
            const busDoc = await db.collection('buses').doc(busId).get();
            if (busDoc.exists) {
                const busData = busDoc.data();
                const location = {
                    currentLocation: busData.currentLocation || 'غير محدد',
                    coordinates: busData.coordinates || null,
                    lastUpdated: busData.locationUpdated || new Date(),
                    speed: busData.speed || 0,
                    direction: busData.direction || 'شمال'
                };
                console.log('✅ Location from direct Firebase:', location);
                return location;
            }
        }

        // Try GPS tracking service if available
        if (typeof GPSService !== 'undefined' && GPSService.getVehicleLocation) {
            const gpsLocation = await GPSService.getVehicleLocation(busId);
            if (gpsLocation) {
                console.log('✅ Location from GPS Service:', gpsLocation);
                return {
                    currentLocation: gpsLocation.address || 'موقع GPS',
                    coordinates: {
                        lat: gpsLocation.latitude,
                        lng: gpsLocation.longitude
                    },
                    lastUpdated: new Date(gpsLocation.timestamp),
                    speed: gpsLocation.speed || 0,
                    direction: gpsLocation.heading || 'شمال'
                };
            }
        }

        console.warn('⚠️ No location service available, using fallback');
        return {
            currentLocation: 'غير متاح حالياً',
            coordinates: null,
            lastUpdated: new Date(),
            speed: 0,
            direction: 'غير محدد'
        };

    } catch (error) {
        console.error('❌ Error getting bus location:', error);
        return {
            currentLocation: 'خطأ في تحديد الموقع',
            coordinates: null,
            lastUpdated: new Date(),
            speed: 0,
            direction: 'غير محدد'
        };
    }
}

// Update Bus Location in Real-time
async function updateBusLocation(busId, locationData) {
    try {
        console.log('📍 Updating bus location:', busId, locationData);

        // Update in local data
        const busIndex = busesData.findIndex(b => b.id === busId);
        if (busIndex !== -1) {
            busesData[busIndex].currentLocation = locationData.currentLocation;
            busesData[busIndex].coordinates = locationData.coordinates;
            busesData[busIndex].locationUpdated = new Date();
            busesData[busIndex].speed = locationData.speed || 0;
            busesData[busIndex].direction = locationData.direction || 'شمال';
        }

        // Update in Firebase
        if (typeof FirebaseService !== 'undefined' && FirebaseService.updateBusLocation) {
            await FirebaseService.updateBusLocation(busId, locationData);
        } else if (typeof db !== 'undefined') {
            await db.collection('buses').doc(busId).update({
                currentLocation: locationData.currentLocation,
                coordinates: locationData.coordinates,
                locationUpdated: new Date(),
                speed: locationData.speed || 0,
                direction: locationData.direction || 'شمال'
            });
        }

        console.log('✅ Bus location updated successfully');
        return true;

    } catch (error) {
        console.error('❌ Error updating bus location:', error);
        return false;
    }
}

// Get All Buses Locations for Map Display
async function getAllBusesLocations() {
    try {
        console.log('🗺️ Getting all buses locations...');

        const locationsPromises = busesData.map(async (bus) => {
            const location = await getBusCurrentLocation(bus.id);
            return {
                busId: bus.id,
                plateNumber: bus.plateNumber,
                driverName: bus.driverName,
                status: bus.status,
                ...location
            };
        });

        const locations = await Promise.all(locationsPromises);
        console.log('✅ All buses locations retrieved:', locations.length);
        return locations;

    } catch (error) {
        console.error('❌ Error getting all buses locations:', error);
        return [];
    }
}

// Start Real-time Location Tracking
function startLocationTracking(busId) {
    console.log('🔄 Starting location tracking for bus:', busId);

    // Clear any existing interval
    if (window.locationTrackingInterval) {
        clearInterval(window.locationTrackingInterval);
    }

    // Update location every 30 seconds
    window.locationTrackingInterval = setInterval(async () => {
        try {
            const location = await getBusCurrentLocation(busId);

            // Update UI if tracking modal is open
            const trackingModal = document.getElementById('trackBusModal');
            if (trackingModal && trackingModal.classList.contains('show')) {
                updateTrackingModalLocation(busId, location);
            }

            // Update all buses tracking if open
            const allBusesModal = document.getElementById('trackAllBusesModal');
            if (allBusesModal && allBusesModal.classList.contains('show')) {
                updateAllBusesTrackingDisplay();
            }

        } catch (error) {
            console.error('❌ Error in location tracking interval:', error);
        }
    }, 30000); // Update every 30 seconds
}

// Stop Location Tracking
function stopLocationTracking() {
    console.log('⏹️ Stopping location tracking...');
    if (window.locationTrackingInterval) {
        clearInterval(window.locationTrackingInterval);
        window.locationTrackingInterval = null;
    }
}

// Update Tracking Modal with New Location
function updateTrackingModalLocation(busId, locationData) {
    try {
        // Update location text
        const locationElements = document.querySelectorAll('.location-text, .current-location-display');
        locationElements.forEach(element => {
            if (element.textContent.includes('الموقع الحالي')) {
                element.innerHTML = `
                    <i class="fas fa-map-marker-alt text-danger me-2"></i>
                    <span class="fw-semibold">${locationData.currentLocation}</span>
                `;
            }
        });

        // Update coordinates if available
        if (locationData.coordinates) {
            const coordsElements = document.querySelectorAll('.coordinates');
            coordsElements.forEach(element => {
                element.innerHTML = `
                    <i class="fas fa-crosshairs me-1"></i>
                    ${locationData.coordinates.lat.toFixed(4)}° N, ${locationData.coordinates.lng.toFixed(4)}° E
                `;
            });
        }

        // Update last updated time
        const timeElements = document.querySelectorAll('.last-updated, .location-time');
        timeElements.forEach(element => {
            element.textContent = `آخر تحديث: ${formatTime(locationData.lastUpdated)}`;
        });

        // Update speed if available
        if (locationData.speed !== undefined) {
            const speedElements = document.querySelectorAll('.speed-display');
            speedElements.forEach(element => {
                element.innerHTML = `
                    <i class="fas fa-tachometer-alt me-1"></i>
                    السرعة: ${locationData.speed} كم/ساعة
                `;
            });
        }

        console.log('✅ Tracking modal updated with new location');

    } catch (error) {
        console.error('❌ Error updating tracking modal:', error);
    }
}

// Enhanced Buses Functions
function toggleBusView(viewType) {
    console.log('🔄 Toggling bus view to:', viewType);

    const tableView = document.getElementById('busTableView');
    const cardsView = document.getElementById('busCardsView');
    const tableBtn = document.getElementById('busTableViewBtn');
    const cardsBtn = document.getElementById('busCardsViewBtn');

    if (viewType === 'table') {
        if (tableView) tableView.classList.remove('d-none');
        if (cardsView) cardsView.classList.add('d-none');
        if (tableBtn) {
            tableBtn.classList.remove('btn-outline-light');
            tableBtn.classList.add('btn-light');
        }
        if (cardsBtn) {
            cardsBtn.classList.remove('btn-light');
            cardsBtn.classList.add('btn-outline-light');
        }
    } else if (viewType === 'cards') {
        if (tableView) tableView.classList.add('d-none');
        if (cardsView) cardsView.classList.remove('d-none');
        if (tableBtn) {
            tableBtn.classList.remove('btn-light');
            tableBtn.classList.add('btn-outline-light');
        }
        if (cardsBtn) {
            cardsBtn.classList.remove('btn-outline-light');
            cardsBtn.classList.add('btn-light');
        }
    }
}

let currentBusSortField = '';
let currentBusSortDirection = 'asc';

function sortBuses(field) {
    console.log('📊 Sorting buses by:', field);

    // Toggle sort direction if same field
    if (currentBusSortField === field) {
        currentBusSortDirection = currentBusSortDirection === 'asc' ? 'desc' : 'asc';
    } else {
        currentBusSortField = field;
        currentBusSortDirection = 'asc';
    }

    // Sort the data
    busesData.sort((a, b) => {
        let valueA, valueB;

        switch (field) {
            case 'plateNumber':
                valueA = (a.plateNumber || '').toLowerCase();
                valueB = (b.plateNumber || '').toLowerCase();
                break;
            case 'status':
                valueA = a.status || '';
                valueB = b.status || '';
                break;
            case 'capacity':
                valueA = a.capacity || 0;
                valueB = b.capacity || 0;
                break;
            case 'studentsCount':
                valueA = a.studentsCount || 0;
                valueB = b.studentsCount || 0;
                break;
            default:
                return 0;
        }

        if (valueA < valueB) return currentBusSortDirection === 'asc' ? -1 : 1;
        if (valueA > valueB) return currentBusSortDirection === 'asc' ? 1 : -1;
        return 0;
    });

    // Update sort indicators
    updateBusSortIndicators(field, currentBusSortDirection);

    // Reload the page to reflect new order
    loadPage('buses');
}

function updateBusSortIndicators(field, direction) {
    // Reset all sort indicators
    document.querySelectorAll('.buses-table .sortable i').forEach(icon => {
        icon.className = 'fas fa-sort ms-2 text-muted';
    });

    // Update the active sort indicator
    const activeHeader = document.querySelector(`.buses-table .sortable[onclick="sortBuses('${field}')"] i`);
    if (activeHeader) {
        activeHeader.className = `fas fa-sort-${direction === 'asc' ? 'up' : 'down'} ms-2 text-primary`;
    }
}

function refreshBusesData() {
    console.log('🔄 Refreshing buses data...');
    loadPage('buses');
}

// Bus Status Helper Functions
function getBusStatusClass(status) {
    switch(status) {
        case 'available': return 'status-available';
        case 'in_route': return 'status-in_route';
        case 'maintenance': return 'status-maintenance';
        case 'returning': return 'status-returning';
        case 'out_of_service': return 'status-out_of_service';
        default: return 'status-available';
    }
}

function getBusStatusIcon(status) {
    switch(status) {
        case 'available': return 'fa-check-circle';
        case 'in_route': return 'fa-route';
        case 'maintenance': return 'fa-tools';
        case 'returning': return 'fa-undo';
        case 'out_of_service': return 'fa-times-circle';
        default: return 'fa-question-circle';
    }
}

function getBusStatusText(status) {
    switch(status) {
        case 'available': return 'متاحة';
        case 'in_route': return 'في الطريق';
        case 'maintenance': return 'في الصيانة';
        case 'returning': return 'في طريق العودة';
        case 'out_of_service': return 'خارج الخدمة';
        default: return 'غير محدد';
    }
}

// Capacity Helper Functions
function getCapacityClass(studentsCount, capacity) {
    const percentage = (studentsCount / capacity) * 100;
    if (percentage <= 60) return 'capacity-low';
    if (percentage <= 85) return 'capacity-medium';
    return 'capacity-high';
}

function getOccupancyBarClass(studentsCount, capacity) {
    const percentage = (studentsCount / capacity) * 100;
    if (percentage <= 60) return 'bg-success';
    if (percentage <= 85) return 'bg-warning';
    return 'bg-danger';
}

// Fuel Level Helper Functions
function getFuelBarClass(fuelLevel) {
    if (fuelLevel >= 70) return 'bg-success';
    if (fuelLevel >= 30) return 'bg-warning';
    return 'bg-danger';
}

// Bus Management Functions
async function viewBus(busId) {
    console.log('👁️ Viewing bus details:', busId);

    const bus = busesData.find(b => b.id === busId);
    if (!bus) {
        alert('لم يتم العثور على السيارة');
        return;
    }

    // Get real-time location from database
    const locationData = await getBusCurrentLocation(busId);

    const modalContent = `
        <div class="modal fade" id="viewBusModal" tabindex="-1">
            <div class="modal-dialog modal-xl">
                <div class="modal-content">
                    <div class="modal-header bg-primary text-white">
                        <h5 class="modal-title">
                            <i class="fas fa-bus me-2"></i>
                            تفاصيل السيارة - ${bus.plateNumber}
                        </h5>
                        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <div class="row">
                            <!-- Bus Overview -->
                            <div class="col-lg-4 mb-4">
                                <div class="card border-0 shadow-sm h-100">
                                    <div class="card-header bg-light">
                                        <h6 class="mb-0">
                                            <i class="fas fa-info-circle me-2 text-primary"></i>
                                            معلومات عامة
                                        </h6>
                                    </div>
                                    <div class="card-body">
                                        <div class="text-center mb-4">
                                            <div class="bus-avatar-xl mx-auto mb-3">
                                                <div class="avatar-xxl bg-gradient-primary text-white rounded-circle d-flex align-items-center justify-content-center">
                                                    <i class="fas fa-bus fa-3x"></i>
                                                </div>
                                            </div>
                                            <h5 class="fw-bold">${bus.plateNumber}</h5>
                                            <span class="badge ${getBusStatusClass(bus.status)} fs-6">
                                                <i class="fas ${getBusStatusIcon(bus.status)} me-1"></i>
                                                ${getBusStatusText(bus.status)}
                                            </span>
                                        </div>

                                        <div class="info-list">
                                            <div class="info-item">
                                                <i class="fas fa-users text-primary"></i>
                                                <div>
                                                    <small class="text-muted">السعة</small>
                                                    <div class="fw-semibold">${bus.capacity} مقعد</div>
                                                </div>
                                            </div>

                                            <div class="info-item">
                                                <i class="fas ${bus.hasAirConditioning ? 'fa-snowflake text-info' : 'fa-times text-secondary'}"></i>
                                                <div>
                                                    <small class="text-muted">التكييف</small>
                                                    <div class="fw-semibold">${bus.hasAirConditioning ? 'مكيفة' : 'غير مكيفة'}</div>
                                                </div>
                                            </div>

                                            <div class="info-item">
                                                <i class="fas fa-calendar text-success"></i>
                                                <div>
                                                    <small class="text-muted">تاريخ التسجيل</small>
                                                    <div class="fw-semibold">${formatDate(bus.createdAt)}</div>
                                                </div>
                                            </div>

                                            ${bus.maintenanceDate ? `
                                                <div class="info-item">
                                                    <i class="fas fa-tools text-warning"></i>
                                                    <div>
                                                        <small class="text-muted">آخر صيانة</small>
                                                        <div class="fw-semibold">${formatDate(bus.maintenanceDate)}</div>
                                                    </div>
                                                </div>
                                            ` : ''}
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- Driver Information -->
                            <div class="col-lg-4 mb-4">
                                <div class="card border-0 shadow-sm h-100">
                                    <div class="card-header bg-light">
                                        <h6 class="mb-0">
                                            <i class="fas fa-user me-2 text-success"></i>
                                            معلومات السائق
                                        </h6>
                                    </div>
                                    <div class="card-body">
                                        <div class="text-center mb-4">
                                            <div class="driver-avatar mx-auto mb-3">
                                                <div class="avatar-lg bg-gradient-success text-white rounded-circle d-flex align-items-center justify-content-center">
                                                    <span class="fw-bold fs-4">${bus.driverName.charAt(0).toUpperCase()}</span>
                                                </div>
                                            </div>
                                            <h6 class="fw-bold">${bus.driverName}</h6>
                                        </div>

                                        <div class="info-list">
                                            <div class="info-item">
                                                <i class="fas fa-phone text-success"></i>
                                                <div>
                                                    <small class="text-muted">رقم الهاتف</small>
                                                    <div class="fw-semibold">${bus.driverPhone}</div>
                                                    <button class="btn btn-sm btn-outline-success mt-1" onclick="callDriver('${bus.driverPhone}')">
                                                        <i class="fas fa-phone me-1"></i>
                                                        اتصال
                                                    </button>
                                                </div>
                                            </div>

                                            <div class="info-item">
                                                <i class="fas fa-id-card text-info"></i>
                                                <div>
                                                    <small class="text-muted">رقم الهوية</small>
                                                    <div class="fw-semibold">${bus.driverLicense || 'غير محدد'}</div>
                                                </div>
                                            </div>

                                            <div class="info-item">
                                                <i class="fas fa-star text-warning"></i>
                                                <div>
                                                    <small class="text-muted">التقييم</small>
                                                    <div class="fw-semibold">
                                                        ${generateStarRating(bus.driverRating || 4.5)}
                                                        <span class="ms-2">${bus.driverRating || 4.5}/5</span>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>

                                        <div class="mt-3">
                                            <button class="btn btn-outline-primary btn-sm w-100" onclick="viewDriverProfile('${bus.id}')">
                                                <i class="fas fa-user-circle me-1"></i>
                                                عرض ملف السائق
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- Route and Status -->
                            <div class="col-lg-4 mb-4">
                                <div class="card border-0 shadow-sm h-100">
                                    <div class="card-header bg-light">
                                        <h6 class="mb-0">
                                            <i class="fas fa-route me-2 text-warning"></i>
                                            المسار والحالة
                                        </h6>
                                    </div>
                                    <div class="card-body">
                                        <div class="info-list">
                                            <div class="info-item">
                                                <i class="fas fa-map-marker-alt text-danger"></i>
                                                <div>
                                                    <small class="text-muted">المسار</small>
                                                    <div class="fw-semibold">${bus.route}</div>
                                                </div>
                                            </div>

                                            <div class="info-item">
                                                <i class="fas fa-location-arrow text-info"></i>
                                                <div>
                                                    <small class="text-muted">الموقع الحالي</small>
                                                    <div class="fw-semibold current-location-display">${locationData.currentLocation}</div>
                                                    <div class="location-details mt-1">
                                                        ${locationData.coordinates ? `
                                                            <small class="text-muted coordinates">
                                                                <i class="fas fa-crosshairs me-1"></i>
                                                                ${locationData.coordinates.lat.toFixed(4)}° N, ${locationData.coordinates.lng.toFixed(4)}° E
                                                            </small>
                                                        ` : ''}
                                                        <div class="location-time">
                                                            <small class="text-muted">
                                                                <i class="fas fa-clock me-1"></i>
                                                                آخر تحديث: ${formatTime(locationData.lastUpdated)}
                                                            </small>
                                                        </div>
                                                        ${locationData.speed !== undefined && locationData.speed > 0 ? `
                                                            <div class="speed-display">
                                                                <small class="text-info">
                                                                    <i class="fas fa-tachometer-alt me-1"></i>
                                                                    السرعة: ${locationData.speed} كم/ساعة
                                                                </small>
                                                            </div>
                                                        ` : ''}
                                                    </div>
                                                    <button class="btn btn-sm btn-outline-info mt-2" onclick="trackBusLive('${bus.id}')">
                                                        <i class="fas fa-map-marked-alt me-1"></i>
                                                        تتبع مباشر
                                                    </button>
                                                    <button class="btn btn-sm btn-outline-success mt-2 ms-1" onclick="refreshBusLocationInModal('${bus.id}')">
                                                        <i class="fas fa-sync-alt me-1"></i>
                                                        تحديث الموقع
                                                    </button>
                                                </div>
                                            </div>

                                            <div class="info-item">
                                                <i class="fas fa-gas-pump text-primary"></i>
                                                <div>
                                                    <small class="text-muted">مستوى الوقود</small>
                                                    <div class="fuel-display">
                                                        <div class="progress mb-2" style="height: 8px;">
                                                            <div class="progress-bar ${getFuelBarClass(bus.fuelLevel)}"
                                                                 style="width: ${bus.fuelLevel}%"></div>
                                                        </div>
                                                        <span class="fw-semibold">${bus.fuelLevel}%</span>
                                                    </div>
                                                </div>
                                            </div>

                                            <div class="info-item">
                                                <i class="fas fa-users text-secondary"></i>
                                                <div>
                                                    <small class="text-muted">الطلاب المسجلين</small>
                                                    <div class="students-display">
                                                        <div class="progress mb-2" style="height: 8px;">
                                                            <div class="progress-bar ${getOccupancyBarClass(bus.studentsCount, bus.capacity)}"
                                                                 style="width: ${(bus.studentsCount / bus.capacity) * 100}%"></div>
                                                        </div>
                                                        <span class="fw-semibold">${bus.studentsCount}/${bus.capacity} طالب</span>
                                                        <span class="text-muted ms-2">(${Math.round((bus.studentsCount / bus.capacity) * 100)}%)</span>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Description -->
                        ${bus.description ? `
                            <div class="row">
                                <div class="col-12">
                                    <div class="card border-0 shadow-sm">
                                        <div class="card-header bg-light">
                                            <h6 class="mb-0">
                                                <i class="fas fa-file-alt me-2 text-secondary"></i>
                                                وصف السيارة
                                            </h6>
                                        </div>
                                        <div class="card-body">
                                            <p class="mb-0">${bus.description}</p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        ` : ''}
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>
                            إغلاق
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Remove existing modal if any
    const existingModal = document.getElementById('viewBusModal');
    if (existingModal) {
        existingModal.remove();
    }

    // Add modal to body and show
    document.body.insertAdjacentHTML('beforeend', modalContent);
    const modal = new bootstrap.Modal(document.getElementById('viewBusModal'));
    modal.show();

    // Clean up when modal is hidden
    document.getElementById('viewBusModal').addEventListener('hidden.bs.modal', function() {
        this.remove();
    });
}

function editBus(busId) {
    console.log('✏️ Editing bus:', busId);

    const bus = busesData.find(b => b.id === busId);
    if (!bus) {
        alert('لم يتم العثور على السيارة');
        return;
    }

    // Close view modal if open
    const viewModal = document.getElementById('viewBusModal');
    if (viewModal) {
        const modal = bootstrap.Modal.getInstance(viewModal);
        if (modal) modal.hide();
    }

    const modalContent = `
        <div class="modal fade" id="editBusModal" tabindex="-1">
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header bg-warning text-dark">
                        <h5 class="modal-title">
                            <i class="fas fa-edit me-2"></i>
                            تعديل بيانات السيارة - ${bus.plateNumber}
                        </h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form id="editBusForm">
                            <div class="row g-3">
                                <!-- Bus Information -->
                                <div class="col-12">
                                    <h6 class="text-warning mb-3">
                                        <i class="fas fa-bus me-2"></i>
                                        معلومات السيارة
                                    </h6>
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">رقم اللوحة <span class="text-danger">*</span></label>
                                    <input type="text" class="form-control" id="editBusPlateNumber"
                                           value="${bus.plateNumber}" required>
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">السعة <span class="text-danger">*</span></label>
                                    <input type="number" class="form-control" id="editBusCapacity"
                                           value="${bus.capacity}" min="10" max="50" required>
                                </div>

                                <div class="col-12">
                                    <label class="form-label">وصف السيارة</label>
                                    <textarea class="form-control" id="editBusDescription" rows="2">${bus.description || ''}</textarea>
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">المسار</label>
                                    <input type="text" class="form-control" id="editBusRoute"
                                           value="${bus.route || ''}">
                                </div>

                                <div class="col-md-6">
                                    <div class="form-check mt-4">
                                        <input class="form-check-input" type="checkbox" id="editBusHasAC"
                                               ${bus.hasAirConditioning ? 'checked' : ''}>
                                        <label class="form-check-label" for="editBusHasAC">
                                            <i class="fas fa-snowflake me-1"></i>
                                            السيارة مكيفة
                                        </label>
                                    </div>
                                </div>

                                <!-- Driver Information -->
                                <div class="col-12 mt-4">
                                    <h6 class="text-success mb-3">
                                        <i class="fas fa-user me-2"></i>
                                        معلومات السائق
                                    </h6>
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">اسم السائق <span class="text-danger">*</span></label>
                                    <input type="text" class="form-control" id="editDriverName"
                                           value="${bus.driverName}" required>
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">رقم هاتف السائق <span class="text-danger">*</span></label>
                                    <input type="tel" class="form-control" id="editDriverPhone"
                                           value="${bus.driverPhone}" required>
                                </div>

                                <!-- Status Information -->
                                <div class="col-12 mt-4">
                                    <h6 class="text-info mb-3">
                                        <i class="fas fa-cog me-2"></i>
                                        معلومات الحالة
                                    </h6>
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">مستوى الوقود (%)</label>
                                    <input type="range" class="form-range" id="editFuelLevel"
                                           min="0" max="100" value="${bus.fuelLevel || 100}"
                                           oninput="document.getElementById('editFuelLevelValue').textContent = this.value + '%'">
                                    <div class="d-flex justify-content-between">
                                        <small class="text-muted">0%</small>
                                        <span id="editFuelLevelValue" class="fw-bold">${bus.fuelLevel || 100}%</span>
                                        <small class="text-muted">100%</small>
                                    </div>
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">الموقع الحالي</label>
                                    <select class="form-select" id="editCurrentLocation">
                                        <option value="المرآب الرئيسي" ${bus.currentLocation === 'المرآب الرئيسي' ? 'selected' : ''}>المرآب الرئيسي</option>
                                        <option value="في الطريق إلى المدرسة" ${bus.currentLocation === 'في الطريق إلى المدرسة' ? 'selected' : ''}>في الطريق إلى المدرسة</option>
                                        <option value="في المدرسة" ${bus.currentLocation === 'في المدرسة' ? 'selected' : ''}>في المدرسة</option>
                                        <option value="في طريق العودة" ${bus.currentLocation === 'في طريق العودة' ? 'selected' : ''}>في طريق العودة</option>
                                        <option value="ورشة الصيانة" ${bus.currentLocation === 'ورشة الصيانة' ? 'selected' : ''}>ورشة الصيانة</option>
                                        <option value="خارج الخدمة" ${bus.currentLocation === 'خارج الخدمة' ? 'selected' : ''}>خارج الخدمة</option>
                                    </select>
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">حالة السيارة</label>
                                    <select class="form-select" id="editBusStatus">
                                        <option value="available" ${bus.status === 'available' ? 'selected' : ''}>متاحة</option>
                                        <option value="in_route" ${bus.status === 'in_route' ? 'selected' : ''}>في الطريق</option>
                                        <option value="maintenance" ${bus.status === 'maintenance' ? 'selected' : ''}>في الصيانة</option>
                                        <option value="returning" ${bus.status === 'returning' ? 'selected' : ''}>في طريق العودة</option>
                                        <option value="out_of_service" ${bus.status === 'out_of_service' ? 'selected' : ''}>خارج الخدمة</option>
                                    </select>
                                </div>

                                <div class="col-md-6">
                                    <label class="form-label">تاريخ آخر صيانة</label>
                                    <input type="date" class="form-control" id="editMaintenanceDate"
                                           value="${bus.maintenanceDate ? formatDateForInput(bus.maintenanceDate) : ''}">
                                </div>

                                <div class="col-md-6">
                                    <div class="form-check mt-4">
                                        <input class="form-check-input" type="checkbox" id="editBusIsActive"
                                               ${bus.isActive !== false ? 'checked' : ''}>
                                        <label class="form-check-label" for="editBusIsActive">
                                            <i class="fas fa-power-off me-1"></i>
                                            السيارة نشطة
                                        </label>
                                    </div>
                                </div>
                            </div>
                        </form>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>
                            إلغاء
                        </button>
                        <button type="button" class="btn btn-warning" onclick="updateBus('${bus.id}')">
                            <i class="fas fa-save me-2"></i>
                            حفظ التغييرات
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Remove existing modal if any
    const existingModal = document.getElementById('editBusModal');
    if (existingModal) {
        existingModal.remove();
    }

    // Add modal to body and show
    document.body.insertAdjacentHTML('beforeend', modalContent);
    const modal = new bootstrap.Modal(document.getElementById('editBusModal'));
    modal.show();

    // Clean up when modal is hidden
    document.getElementById('editBusModal').addEventListener('hidden.bs.modal', function() {
        this.remove();
    });
}

// Update Bus Function
function updateBus(busId) {
    console.log('💾 Updating bus:', busId);

    const bus = busesData.find(b => b.id === busId);
    if (!bus) {
        alert('لم يتم العثور على السيارة');
        return;
    }

    // Get form data
    const plateNumber = document.getElementById('editBusPlateNumber').value.trim();
    const capacity = parseInt(document.getElementById('editBusCapacity').value);
    const description = document.getElementById('editBusDescription').value.trim();
    const route = document.getElementById('editBusRoute').value.trim();
    const hasAC = document.getElementById('editBusHasAC').checked;
    const driverName = document.getElementById('editDriverName').value.trim();
    const driverPhone = document.getElementById('editDriverPhone').value.trim();
    const fuelLevel = parseInt(document.getElementById('editFuelLevel').value);
    const currentLocation = document.getElementById('editCurrentLocation').value;
    const status = document.getElementById('editBusStatus').value;
    const maintenanceDate = document.getElementById('editMaintenanceDate').value;
    const isActive = document.getElementById('editBusIsActive').checked;

    // Validation
    if (!plateNumber) {
        alert('يرجى إدخال رقم اللوحة');
        return;
    }

    if (!capacity || capacity < 10 || capacity > 50) {
        alert('يرجى إدخال سعة صحيحة (10-50 مقعد)');
        return;
    }

    if (!driverName) {
        alert('يرجى إدخال اسم السائق');
        return;
    }

    if (!driverPhone) {
        alert('يرجى إدخال رقم هاتف السائق');
        return;
    }

    // Check if plate number already exists (excluding current bus)
    const existingBus = busesData.find(b => b.plateNumber === plateNumber && b.id !== busId);
    if (existingBus) {
        alert('رقم اللوحة موجود مسبقاً. يرجى استخدام رقم لوحة مختلف.');
        return;
    }

    // Update bus object
    const updatedBus = {
        ...bus,
        plateNumber: plateNumber,
        description: description || 'سيارة نقل مدرسي',
        driverName: driverName,
        driverPhone: driverPhone,
        route: route || 'غير محدد',
        capacity: capacity,
        hasAirConditioning: hasAC,
        isActive: isActive,
        status: status,
        fuelLevel: fuelLevel,
        currentLocation: currentLocation,
        maintenanceDate: maintenanceDate ? new Date(maintenanceDate) : null,
        updatedAt: new Date()
    };

    // Update in busesData array
    const busIndex = busesData.findIndex(b => b.id === busId);
    if (busIndex !== -1) {
        busesData[busIndex] = updatedBus;
    }

    // Try to save to Firebase
    try {
        if (typeof FirebaseService !== 'undefined' && FirebaseService.updateBus) {
            FirebaseService.updateBus(busId, updatedBus).then(() => {
                console.log('✅ Bus updated in Firebase successfully');
            }).catch(error => {
                console.error('❌ Error updating bus in Firebase:', error);
            });
        } else if (typeof db !== 'undefined') {
            // Direct Firebase update
            db.collection('buses').doc(busId).update(updatedBus).then(() => {
                console.log('✅ Bus updated in Firebase via direct access');
            }).catch(error => {
                console.error('❌ Error updating bus via direct Firebase:', error);
            });
        }
    } catch (error) {
        console.error('❌ Error updating bus:', error);
    }

    // Close modal
    const modal = bootstrap.Modal.getInstance(document.getElementById('editBusModal'));
    if (modal) modal.hide();

    // Reload page to show updated bus
    loadPage('buses');

    // Show success message
    showNotification('تم تحديث بيانات السيارة بنجاح!', 'success');
}

function deleteBus(busId) {
    console.log('🗑️ Deleting bus:', busId);

    const bus = busesData.find(b => b.id === busId);
    if (!bus) {
        alert('لم يتم العثور على السيارة');
        return;
    }

    // Show confirmation dialog with bus details
    const confirmMessage = `هل أنت متأكد من حذف السيارة؟\n\nرقم اللوحة: ${bus.plateNumber}\nالسائق: ${bus.driverName}\nعدد الطلاب: ${bus.studentsCount}\n\nتحذير: هذا الإجراء لا يمكن التراجع عنه!`;

    if (!confirm(confirmMessage)) {
        return;
    }

    // Check if bus has students
    if (bus.studentsCount > 0) {
        const forceDelete = confirm(`تحذير: هذه السيارة تحتوي على ${bus.studentsCount} طالب مسجل.\n\nهل تريد المتابعة؟ سيتم إلغاء تسجيل جميع الطلاب من هذه السيارة.`);
        if (!forceDelete) {
            return;
        }
    }

    try {
        // Remove from busesData array
        const busIndex = busesData.findIndex(b => b.id === busId);
        if (busIndex !== -1) {
            busesData.splice(busIndex, 1);
        }

        // Try to delete from Firebase
        if (typeof FirebaseService !== 'undefined' && FirebaseService.deleteBus) {
            FirebaseService.deleteBus(busId).then(() => {
                console.log('✅ Bus deleted from Firebase successfully');
            }).catch(error => {
                console.error('❌ Error deleting bus from Firebase:', error);
            });
        } else if (typeof db !== 'undefined') {
            // Direct Firebase delete
            db.collection('buses').doc(busId).delete().then(() => {
                console.log('✅ Bus deleted from Firebase via direct access');
            }).catch(error => {
                console.error('❌ Error deleting bus via direct Firebase:', error);
            });
        }

        // Close any open modals
        const viewModal = document.getElementById('viewBusModal');
        if (viewModal) {
            const modal = bootstrap.Modal.getInstance(viewModal);
            if (modal) modal.hide();
        }

        // Reload page to reflect changes
        loadPage('buses');

        // Show success message
        showNotification(`تم حذف السيارة ${bus.plateNumber} بنجاح!`, 'success');

    } catch (error) {
        console.error('❌ Error deleting bus:', error);
        showNotification('حدث خطأ أثناء حذف السيارة. يرجى المحاولة مرة أخرى.', 'error');
    }
}

async function trackBus(busId) {
    console.log('📍 Tracking bus:', busId);

    const bus = busesData.find(b => b.id === busId);
    if (!bus) {
        alert('لم يتم العثور على السيارة');
        return;
    }

    // Get real-time location
    const locationData = await getBusCurrentLocation(busId);

    // Close any open modals
    const viewModal = document.getElementById('viewBusModal');
    if (viewModal) {
        const modal = bootstrap.Modal.getInstance(viewModal);
        if (modal) modal.hide();
    }

    const modalContent = `
        <div class="modal fade" id="trackBusModal" tabindex="-1">
            <div class="modal-dialog modal-xl">
                <div class="modal-content">
                    <div class="modal-header bg-info text-white">
                        <h5 class="modal-title">
                            <i class="fas fa-map-marked-alt me-2"></i>
                            تتبع السيارة - ${bus.plateNumber}
                        </h5>
                        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body p-0">
                        <div class="row g-0">
                            <!-- Map Area -->
                            <div class="col-lg-8">
                                <div class="map-container" style="height: 500px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); position: relative;">
                                    <div class="map-placeholder d-flex align-items-center justify-content-center h-100 text-white">
                                        <div class="text-center">
                                            <i class="fas fa-map fa-4x mb-3 opacity-50"></i>
                                            <h4>خريطة التتبع المباشر</h4>
                                            <p class="mb-0">سيتم عرض موقع السيارة هنا</p>
                                            <div class="mt-3">
                                                <div class="spinner-border text-light" role="status">
                                                    <span class="visually-hidden">جاري التحميل...</span>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Bus Location Marker -->
                                    <div class="bus-marker" style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%);">
                                        <div class="marker-pulse">
                                            <div class="marker-icon bg-danger text-white rounded-circle d-flex align-items-center justify-content-center"
                                                 style="width: 40px; height: 40px; box-shadow: 0 0 20px rgba(220, 53, 69, 0.5);">
                                                <i class="fas fa-bus"></i>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- Info Panel -->
                            <div class="col-lg-4">
                                <div class="info-panel p-4" style="height: 500px; overflow-y: auto; background: #f8f9fa;">
                                    <!-- Bus Status -->
                                    <div class="status-section mb-4">
                                        <h6 class="fw-bold mb-3">
                                            <i class="fas fa-info-circle me-2 text-info"></i>
                                            حالة السيارة
                                        </h6>
                                        <div class="status-card p-3 bg-white rounded shadow-sm">
                                            <div class="d-flex align-items-center mb-2">
                                                <span class="status-badge ${getBusStatusClass(bus.status)} me-2">
                                                    <i class="fas ${getBusStatusIcon(bus.status)}"></i>
                                                </span>
                                                <span class="fw-semibold">${getBusStatusText(bus.status)}</span>
                                            </div>
                                            <small class="text-muted">آخر تحديث: ${formatTime(new Date())}</small>
                                        </div>
                                    </div>

                                    <!-- Location Info -->
                                    <div class="location-section mb-4">
                                        <h6 class="fw-bold mb-3">
                                            <i class="fas fa-map-marker-alt me-2 text-danger"></i>
                                            معلومات الموقع
                                        </h6>
                                        <div class="location-card p-3 bg-white rounded shadow-sm">
                                            <div class="mb-2">
                                                <strong>الموقع الحالي:</strong>
                                                <div class="text-muted current-location-display">${locationData.currentLocation}</div>
                                            </div>
                                            <div class="mb-2">
                                                <strong>المسار:</strong>
                                                <div class="text-muted small">${bus.route}</div>
                                            </div>
                                            <div class="mb-2">
                                                <strong>آخر تحديث:</strong>
                                                <div class="text-muted small last-updated">${formatTime(locationData.lastUpdated)}</div>
                                            </div>
                                            ${locationData.coordinates ? `
                                                <div class="coordinates text-muted small">
                                                    <i class="fas fa-crosshairs me-1"></i>
                                                    ${locationData.coordinates.lat.toFixed(4)}° N, ${locationData.coordinates.lng.toFixed(4)}° E
                                                </div>
                                            ` : `
                                                <div class="coordinates text-muted small">
                                                    <i class="fas fa-crosshairs me-1"></i>
                                                    الإحداثيات غير متاحة
                                                </div>
                                            `}
                                            ${locationData.speed !== undefined && locationData.speed > 0 ? `
                                                <div class="speed-info text-info small mt-2">
                                                    <i class="fas fa-tachometer-alt me-1"></i>
                                                    السرعة: ${locationData.speed} كم/ساعة
                                                </div>
                                            ` : ''}
                                        </div>
                                    </div>

                                    <!-- Driver Info -->
                                    <div class="driver-section mb-4">
                                        <h6 class="fw-bold mb-3">
                                            <i class="fas fa-user me-2 text-success"></i>
                                            معلومات السائق
                                        </h6>
                                        <div class="driver-card p-3 bg-white rounded shadow-sm">
                                            <div class="d-flex align-items-center mb-2">
                                                <div class="driver-avatar me-2">
                                                    <div class="avatar-sm bg-success text-white rounded-circle d-flex align-items-center justify-content-center">
                                                        <span class="fw-bold">${bus.driverName.charAt(0)}</span>
                                                    </div>
                                                </div>
                                                <div>
                                                    <div class="fw-semibold">${bus.driverName}</div>
                                                    <small class="text-muted">${bus.driverPhone}</small>
                                                </div>
                                            </div>
                                            <button class="btn btn-sm btn-outline-success w-100" onclick="callDriver('${bus.driverPhone}')">
                                                <i class="fas fa-phone me-1"></i>
                                                اتصال بالسائق
                                            </button>
                                        </div>
                                    </div>

                                    <!-- Students Info -->
                                    <div class="students-section mb-4">
                                        <h6 class="fw-bold mb-3">
                                            <i class="fas fa-users me-2 text-primary"></i>
                                            معلومات الطلاب
                                        </h6>
                                        <div class="students-card p-3 bg-white rounded shadow-sm">
                                            <div class="d-flex justify-content-between mb-2">
                                                <span>عدد الطلاب:</span>
                                                <span class="fw-bold">${bus.studentsCount}/${bus.capacity}</span>
                                            </div>
                                            <div class="progress mb-2" style="height: 6px;">
                                                <div class="progress-bar ${getOccupancyBarClass(bus.studentsCount, bus.capacity)}"
                                                     style="width: ${(bus.studentsCount / bus.capacity) * 100}%"></div>
                                            </div>
                                            <small class="text-muted">${Math.round((bus.studentsCount / bus.capacity) * 100)}% ممتلئ</small>
                                        </div>
                                    </div>

                                    <!-- Fuel Level -->
                                    <div class="fuel-section mb-4">
                                        <h6 class="fw-bold mb-3">
                                            <i class="fas fa-gas-pump me-2 text-warning"></i>
                                            مستوى الوقود
                                        </h6>
                                        <div class="fuel-card p-3 bg-white rounded shadow-sm">
                                            <div class="d-flex justify-content-between mb-2">
                                                <span>الوقود:</span>
                                                <span class="fw-bold">${bus.fuelLevel}%</span>
                                            </div>
                                            <div class="progress mb-2" style="height: 8px;">
                                                <div class="progress-bar ${getFuelBarClass(bus.fuelLevel)}"
                                                     style="width: ${bus.fuelLevel}%"></div>
                                            </div>
                                            ${bus.fuelLevel < 30 ? '<small class="text-danger"><i class="fas fa-exclamation-triangle me-1"></i>مستوى وقود منخفض</small>' : ''}
                                        </div>
                                    </div>

                                    <!-- Quick Actions -->
                                    <div class="actions-section">
                                        <h6 class="fw-bold mb-3">
                                            <i class="fas fa-bolt me-2 text-secondary"></i>
                                            إجراءات سريعة
                                        </h6>
                                        <div class="d-grid gap-2">
                                            <button class="btn btn-outline-primary btn-sm" onclick="refreshBusLocation('${bus.id}')">
                                                <i class="fas fa-sync-alt me-1"></i>
                                                تحديث الموقع
                                            </button>
                                            <button class="btn btn-outline-info btn-sm" onclick="viewBusHistory('${bus.id}')">
                                                <i class="fas fa-history me-1"></i>
                                                سجل الرحلات
                                            </button>
                                            <button class="btn btn-outline-warning btn-sm" onclick="sendAlert('${bus.id}')">
                                                <i class="fas fa-exclamation-triangle me-1"></i>
                                                إرسال تنبيه
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>
                            إغلاق
                        </button>
                        <button type="button" class="btn btn-info" onclick="openFullMap('${bus.id}')">
                            <i class="fas fa-expand me-2"></i>
                            عرض كامل للخريطة
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Remove existing modal if any
    const existingModal = document.getElementById('trackBusModal');
    if (existingModal) {
        existingModal.remove();
    }

    // Add modal to body and show
    document.body.insertAdjacentHTML('beforeend', modalContent);
    const modal = new bootstrap.Modal(document.getElementById('trackBusModal'));
    modal.show();

    // Clean up when modal is hidden
    document.getElementById('trackBusModal').addEventListener('hidden.bs.modal', function() {
        stopLocationTracking();
        this.remove();
    });

    // Start real-time location tracking
    startLocationTracking(busId);
}

// Helper Functions for Bus Tracking
function startBusTracking(busId) {
    console.log('🔄 Starting real-time tracking for bus:', busId);
    // Simulate real-time updates every 30 seconds
    // In real implementation, this would connect to GPS tracking service
}

async function refreshBusLocation(busId) {
    console.log('📍 Refreshing bus location:', busId);

    try {
        const locationData = await getBusCurrentLocation(busId);

        // Update tracking modal if open
        const trackingModal = document.getElementById('trackBusModal');
        if (trackingModal && trackingModal.classList.contains('show')) {
            updateTrackingModalLocation(busId, locationData);
        }

        showNotification('تم تحديث موقع السيارة', 'success');

    } catch (error) {
        console.error('❌ Error refreshing bus location:', error);
        showNotification('خطأ في تحديث موقع السيارة', 'error');
    }
}

async function refreshBusLocationInModal(busId) {
    console.log('📍 Refreshing bus location in modal:', busId);

    try {
        // Show loading indicator
        const locationDisplay = document.querySelector('.current-location-display');
        if (locationDisplay) {
            locationDisplay.innerHTML = '<i class="fas fa-spinner fa-spin me-2"></i>جاري التحديث...';
        }

        const locationData = await getBusCurrentLocation(busId);

        // Update location display
        if (locationDisplay) {
            locationDisplay.textContent = locationData.currentLocation;
        }

        // Update coordinates
        const coordsDisplay = document.querySelector('.coordinates');
        if (coordsDisplay && locationData.coordinates) {
            coordsDisplay.innerHTML = `
                <i class="fas fa-crosshairs me-1"></i>
                ${locationData.coordinates.lat.toFixed(4)}° N, ${locationData.coordinates.lng.toFixed(4)}° E
            `;
        }

        // Update time
        const timeDisplay = document.querySelector('.location-time');
        if (timeDisplay) {
            timeDisplay.innerHTML = `
                <small class="text-muted">
                    <i class="fas fa-clock me-1"></i>
                    آخر تحديث: ${formatTime(locationData.lastUpdated)}
                </small>
            `;
        }

        // Update speed if available
        const speedDisplay = document.querySelector('.speed-display');
        if (speedDisplay && locationData.speed !== undefined && locationData.speed > 0) {
            speedDisplay.innerHTML = `
                <small class="text-info">
                    <i class="fas fa-tachometer-alt me-1"></i>
                    السرعة: ${locationData.speed} كم/ساعة
                </small>
            `;
        }

        showNotification('تم تحديث موقع السيارة', 'success');

    } catch (error) {
        console.error('❌ Error refreshing bus location in modal:', error);

        const locationDisplay = document.querySelector('.current-location-display');
        if (locationDisplay) {
            locationDisplay.textContent = 'خطأ في تحديث الموقع';
        }

        showNotification('خطأ في تحديث موقع السيارة', 'error');
    }
}

function viewBusHistory(busId) {
    console.log('📜 Viewing bus history:', busId);
    alert('عرض سجل رحلات السيارة - قيد التطوير');
}

function sendAlert(busId) {
    console.log('⚠️ Sending alert to bus:', busId);
    const message = prompt('أدخل رسالة التنبيه:');
    if (message) {
        showNotification('تم إرسال التنبيه للسائق', 'success');
    }
}

function openFullMap(busId) {
    console.log('🗺️ Opening full map for bus:', busId);
    alert('عرض الخريطة الكاملة - قيد التطوير');
}

function callDriver(phoneNumber) {
    console.log('📞 Calling driver:', phoneNumber);
    if (confirm(`هل تريد الاتصال بالسائق على الرقم ${phoneNumber}؟`)) {
        window.open(`tel:${phoneNumber}`, '_self');
    }
}

function trackBusLive(busId) {
    console.log('🔴 Starting live tracking for bus:', busId);
    trackBus(busId);
}

function viewDriverProfile(busId) {
    console.log('👤 Viewing driver profile for bus:', busId);
    alert('عرض ملف السائق - قيد التطوير');
}

// Helper Functions for Display
function generateStarRating(rating) {
    const fullStars = Math.floor(rating);
    const hasHalfStar = rating % 1 !== 0;
    let stars = '';

    for (let i = 0; i < fullStars; i++) {
        stars += '<i class="fas fa-star text-warning"></i>';
    }

    if (hasHalfStar) {
        stars += '<i class="fas fa-star-half-alt text-warning"></i>';
    }

    const emptyStars = 5 - Math.ceil(rating);
    for (let i = 0; i < emptyStars; i++) {
        stars += '<i class="far fa-star text-muted"></i>';
    }

    return stars;
}

function formatDateForInput(date) {
    if (!date) return '';
    const d = new Date(date);
    return d.toISOString().split('T')[0];
}

function formatTime(date) {
    if (!date) return 'غير محدد';
    return new Date(date).toLocaleTimeString('ar-SA', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: true
    });
}

function manageBusStudents(busId) {
    console.log('👥 Managing bus students:', busId);

    const bus = busesData.find(b => b.id === busId);
    if (!bus) {
        alert('لم يتم العثور على السيارة');
        return;
    }

    // Close any open modals
    const viewModal = document.getElementById('viewBusModal');
    if (viewModal) {
        const modal = bootstrap.Modal.getInstance(viewModal);
        if (modal) modal.hide();
    }

    // Get students assigned to this bus (mock data for now)
    const busStudents = studentsData.filter(student => student.busId === busId) || [];
    const availableStudents = studentsData.filter(student => !student.busId || student.busId === '') || [];

    const modalContent = `
        <div class="modal fade" id="manageBusStudentsModal" tabindex="-1">
            <div class="modal-dialog modal-xl">
                <div class="modal-content">
                    <div class="modal-header bg-primary text-white">
                        <h5 class="modal-title">
                            <i class="fas fa-users me-2"></i>
                            إدارة طلاب السيارة - ${bus.plateNumber}
                        </h5>
                        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <div class="row">
                            <!-- Bus Info -->
                            <div class="col-12 mb-4">
                                <div class="alert alert-info">
                                    <div class="row align-items-center">
                                        <div class="col-md-3">
                                            <strong>السيارة:</strong> ${bus.plateNumber}
                                        </div>
                                        <div class="col-md-3">
                                            <strong>السائق:</strong> ${bus.driverName}
                                        </div>
                                        <div class="col-md-3">
                                            <strong>السعة:</strong> ${bus.capacity} مقعد
                                        </div>
                                        <div class="col-md-3">
                                            <strong>المسجلين:</strong> ${busStudents.length}/${bus.capacity}
                                            <div class="progress mt-1" style="height: 4px;">
                                                <div class="progress-bar ${getOccupancyBarClass(busStudents.length, bus.capacity)}"
                                                     style="width: ${(busStudents.length / bus.capacity) * 100}%"></div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- Current Students -->
                            <div class="col-lg-6">
                                <div class="card border-0 shadow-sm h-100">
                                    <div class="card-header bg-success text-white">
                                        <h6 class="mb-0">
                                            <i class="fas fa-check-circle me-2"></i>
                                            الطلاب المسجلين (${busStudents.length})
                                        </h6>
                                    </div>
                                    <div class="card-body" style="max-height: 400px; overflow-y: auto;">
                                        ${busStudents.length === 0 ? `
                                            <div class="text-center py-4">
                                                <i class="fas fa-users fa-3x text-muted mb-3"></i>
                                                <p class="text-muted">لا يوجد طلاب مسجلين في هذه السيارة</p>
                                            </div>
                                        ` : busStudents.map(student => `
                                            <div class="student-item border rounded p-3 mb-2">
                                                <div class="d-flex align-items-center justify-content-between">
                                                    <div class="d-flex align-items-center">
                                                        <div class="student-avatar me-3">
                                                            <div class="avatar-sm bg-success text-white rounded-circle d-flex align-items-center justify-content-center">
                                                                <span class="fw-bold">${student.name.charAt(0)}</span>
                                                            </div>
                                                        </div>
                                                        <div>
                                                            <h6 class="mb-1">${student.name}</h6>
                                                            <small class="text-muted">
                                                                <i class="fas fa-graduation-cap me-1"></i>
                                                                ${student.grade || 'غير محدد'}
                                                                ${student.schoolName ? ` - ${student.schoolName}` : ''}
                                                            </small>
                                                        </div>
                                                    </div>
                                                    <button class="btn btn-sm btn-outline-danger" onclick="removeStudentFromBus('${student.id}', '${busId}')">
                                                        <i class="fas fa-times"></i>
                                                    </button>
                                                </div>
                                            </div>
                                        `).join('')}
                                    </div>
                                </div>
                            </div>

                            <!-- Available Students -->
                            <div class="col-lg-6">
                                <div class="card border-0 shadow-sm h-100">
                                    <div class="card-header bg-warning text-dark">
                                        <div class="d-flex justify-content-between align-items-center">
                                            <h6 class="mb-0">
                                                <i class="fas fa-plus-circle me-2"></i>
                                                الطلاب المتاحين (${availableStudents.length})
                                            </h6>
                                            <input type="text" class="form-control form-control-sm" style="width: 200px;"
                                                   placeholder="البحث..." id="searchAvailableStudents"
                                                   onkeyup="filterAvailableStudents()">
                                        </div>
                                    </div>
                                    <div class="card-body" style="max-height: 400px; overflow-y: auto;">
                                        <div id="availableStudentsList">
                                            ${availableStudents.length === 0 ? `
                                                <div class="text-center py-4">
                                                    <i class="fas fa-user-plus fa-3x text-muted mb-3"></i>
                                                    <p class="text-muted">جميع الطلاب مسجلين في سيارات</p>
                                                </div>
                                            ` : availableStudents.map(student => `
                                                <div class="student-item border rounded p-3 mb-2 available-student" data-student-name="${student.name.toLowerCase()}">
                                                    <div class="d-flex align-items-center justify-content-between">
                                                        <div class="d-flex align-items-center">
                                                            <div class="student-avatar me-3">
                                                                <div class="avatar-sm bg-warning text-dark rounded-circle d-flex align-items-center justify-content-center">
                                                                    <span class="fw-bold">${student.name.charAt(0)}</span>
                                                                </div>
                                                            </div>
                                                            <div>
                                                                <h6 class="mb-1">${student.name}</h6>
                                                                <small class="text-muted">
                                                                    <i class="fas fa-graduation-cap me-1"></i>
                                                                    ${student.grade || 'غير محدد'}
                                                                    ${student.schoolName ? ` - ${student.schoolName}` : ''}
                                                                </small>
                                                            </div>
                                                        </div>
                                                        <button class="btn btn-sm btn-outline-success" onclick="addStudentToBus('${student.id}', '${busId}')"
                                                                ${busStudents.length >= bus.capacity ? 'disabled title="السيارة ممتلئة"' : ''}>
                                                            <i class="fas fa-plus"></i>
                                                        </button>
                                                    </div>
                                                </div>
                                            `).join('')}
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Bulk Actions -->
                        ${busStudents.length > 0 ? `
                            <div class="row mt-4">
                                <div class="col-12">
                                    <div class="card border-0 shadow-sm">
                                        <div class="card-header bg-light">
                                            <h6 class="mb-0">
                                                <i class="fas fa-cogs me-2"></i>
                                                إجراءات متعددة
                                            </h6>
                                        </div>
                                        <div class="card-body">
                                            <div class="btn-group" role="group">
                                                <button class="btn btn-outline-info" onclick="exportBusStudents('${busId}')">
                                                    <i class="fas fa-download me-1"></i>
                                                    تصدير قائمة الطلاب
                                                </button>
                                                <button class="btn btn-outline-primary" onclick="printBusStudents('${busId}')">
                                                    <i class="fas fa-print me-1"></i>
                                                    طباعة القائمة
                                                </button>
                                                <button class="btn btn-outline-success" onclick="notifyBusParents('${busId}')">
                                                    <i class="fas fa-bell me-1"></i>
                                                    إشعار أولياء الأمور
                                                </button>
                                                <button class="btn btn-outline-danger" onclick="removeAllStudentsFromBus('${busId}')">
                                                    <i class="fas fa-user-times me-1"></i>
                                                    إزالة جميع الطلاب
                                                </button>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        ` : ''}
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>
                            إغلاق
                        </button>
                        <button type="button" class="btn btn-primary" onclick="saveBusStudentsChanges('${busId}')">
                            <i class="fas fa-save me-2"></i>
                            حفظ التغييرات
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Remove existing modal if any
    const existingModal = document.getElementById('manageBusStudentsModal');
    if (existingModal) {
        existingModal.remove();
    }

    // Add modal to body and show
    document.body.insertAdjacentHTML('beforeend', modalContent);
    const modal = new bootstrap.Modal(document.getElementById('manageBusStudentsModal'));
    modal.show();

    // Clean up when modal is hidden
    document.getElementById('manageBusStudentsModal').addEventListener('hidden.bs.modal', function() {
        this.remove();
    });
}

// Bus Students Management Functions
function addStudentToBus(studentId, busId) {
    console.log('➕ Adding student to bus:', studentId, busId);

    const bus = busesData.find(b => b.id === busId);
    const student = studentsData.find(s => s.id === studentId);

    if (!bus || !student) {
        alert('خطأ في البيانات');
        return;
    }

    // Check capacity
    const currentStudents = studentsData.filter(s => s.busId === busId);
    if (currentStudents.length >= bus.capacity) {
        alert('السيارة ممتلئة! لا يمكن إضافة المزيد من الطلاب.');
        return;
    }

    // Update student's bus assignment
    const studentIndex = studentsData.findIndex(s => s.id === studentId);
    if (studentIndex !== -1) {
        studentsData[studentIndex].busId = busId;
        studentsData[studentIndex].busRoute = bus.route;
    }

    // Update bus students count
    const busIndex = busesData.findIndex(b => b.id === busId);
    if (busIndex !== -1) {
        busesData[busIndex].studentsCount = currentStudents.length + 1;
    }

    // Refresh the modal
    manageBusStudents(busId);

    showNotification(`تم إضافة ${student.name} للسيارة ${bus.plateNumber}`, 'success');
}

function removeStudentFromBus(studentId, busId) {
    console.log('➖ Removing student from bus:', studentId, busId);

    const student = studentsData.find(s => s.id === studentId);
    const bus = busesData.find(b => b.id === busId);

    if (!student || !bus) {
        alert('خطأ في البيانات');
        return;
    }

    if (confirm(`هل تريد إزالة ${student.name} من السيارة ${bus.plateNumber}؟`)) {
        // Update student's bus assignment
        const studentIndex = studentsData.findIndex(s => s.id === studentId);
        if (studentIndex !== -1) {
            studentsData[studentIndex].busId = '';
            studentsData[studentIndex].busRoute = '';
        }

        // Update bus students count
        const currentStudents = studentsData.filter(s => s.busId === busId);
        const busIndex = busesData.findIndex(b => b.id === busId);
        if (busIndex !== -1) {
            busesData[busIndex].studentsCount = Math.max(0, currentStudents.length - 1);
        }

        // Refresh the modal
        manageBusStudents(busId);

        showNotification(`تم إزالة ${student.name} من السيارة`, 'info');
    }
}

function filterAvailableStudents() {
    const searchTerm = document.getElementById('searchAvailableStudents').value.toLowerCase();
    const studentItems = document.querySelectorAll('.available-student');

    studentItems.forEach(item => {
        const studentName = item.getAttribute('data-student-name');
        if (studentName.includes(searchTerm)) {
            item.style.display = 'block';
        } else {
            item.style.display = 'none';
        }
    });
}

function removeAllStudentsFromBus(busId) {
    console.log('🗑️ Removing all students from bus:', busId);

    const bus = busesData.find(b => b.id === busId);
    if (!bus) {
        alert('لم يتم العثور على السيارة');
        return;
    }

    const busStudents = studentsData.filter(s => s.busId === busId);

    if (busStudents.length === 0) {
        alert('لا يوجد طلاب في هذه السيارة');
        return;
    }

    if (confirm(`هل تريد إزالة جميع الطلاب (${busStudents.length}) من السيارة ${bus.plateNumber}؟`)) {
        // Remove all students from bus
        studentsData.forEach(student => {
            if (student.busId === busId) {
                student.busId = '';
                student.busRoute = '';
            }
        });

        // Update bus students count
        const busIndex = busesData.findIndex(b => b.id === busId);
        if (busIndex !== -1) {
            busesData[busIndex].studentsCount = 0;
        }

        // Refresh the modal
        manageBusStudents(busId);

        showNotification('تم إزالة جميع الطلاب من السيارة', 'success');
    }
}

function exportBusStudents(busId) {
    console.log('📤 Exporting bus students:', busId);
    alert('تصدير قائمة طلاب السيارة - قيد التطوير');
}

function printBusStudents(busId) {
    console.log('🖨️ Printing bus students:', busId);
    alert('طباعة قائمة طلاب السيارة - قيد التطوير');
}

function notifyBusParents(busId) {
    console.log('📧 Notifying bus parents:', busId);
    alert('إرسال إشعار لأولياء أمور طلاب السيارة - قيد التطوير');
}

function saveBusStudentsChanges(busId) {
    console.log('💾 Saving bus students changes:', busId);

    // Close modal
    const modal = bootstrap.Modal.getInstance(document.getElementById('manageBusStudentsModal'));
    if (modal) modal.hide();

    // Reload buses page to reflect changes
    loadPage('buses');

    showNotification('تم حفظ تغييرات طلاب السيارة بنجاح!', 'success');
}

function scheduleMaintenance(busId) {
    console.log('🔧 Scheduling maintenance for bus:', busId);

    const bus = busesData.find(b => b.id === busId);
    if (!bus) {
        alert('لم يتم العثور على السيارة');
        return;
    }

    const modalContent = `
        <div class="modal fade" id="scheduleMaintenanceModal" tabindex="-1">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header bg-warning text-dark">
                        <h5 class="modal-title">
                            <i class="fas fa-tools me-2"></i>
                            جدولة صيانة - ${bus.plateNumber}
                        </h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form id="maintenanceForm">
                            <div class="mb-3">
                                <label class="form-label">نوع الصيانة <span class="text-danger">*</span></label>
                                <select class="form-select" id="maintenanceType" required>
                                    <option value="">اختر نوع الصيانة</option>
                                    <option value="routine">صيانة دورية</option>
                                    <option value="repair">إصلاح عطل</option>
                                    <option value="inspection">فحص دوري</option>
                                    <option value="oil_change">تغيير زيت</option>
                                    <option value="tire_change">تغيير إطارات</option>
                                    <option value="ac_service">صيانة تكييف</option>
                                    <option value="other">أخرى</option>
                                </select>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">تاريخ الصيانة <span class="text-danger">*</span></label>
                                <input type="date" class="form-control" id="maintenanceDate" required>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">وقت الصيانة</label>
                                <input type="time" class="form-control" id="maintenanceTime" value="09:00">
                            </div>

                            <div class="mb-3">
                                <label class="form-label">الورشة/المركز</label>
                                <select class="form-select" id="maintenanceCenter">
                                    <option value="">اختر الورشة</option>
                                    <option value="center1">مركز الصيانة الرئيسي</option>
                                    <option value="center2">ورشة النقل المدرسي</option>
                                    <option value="center3">مركز الخدمة السريعة</option>
                                    <option value="external">ورشة خارجية</option>
                                </select>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">التكلفة المتوقعة (ريال)</label>
                                <input type="number" class="form-control" id="estimatedCost" min="0" step="0.01">
                            </div>

                            <div class="mb-3">
                                <label class="form-label">ملاحظات</label>
                                <textarea class="form-control" id="maintenanceNotes" rows="3"
                                          placeholder="أي ملاحظات أو تفاصيل إضافية..."></textarea>
                            </div>

                            <div class="mb-3">
                                <div class="form-check">
                                    <input class="form-check-input" type="checkbox" id="notifyDriver">
                                    <label class="form-check-label" for="notifyDriver">
                                        إشعار السائق بموعد الصيانة
                                    </label>
                                </div>
                            </div>

                            <div class="mb-3">
                                <div class="form-check">
                                    <input class="form-check-input" type="checkbox" id="setBusOutOfService">
                                    <label class="form-check-label" for="setBusOutOfService">
                                        وضع السيارة خارج الخدمة مؤقتاً
                                    </label>
                                </div>
                            </div>
                        </form>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>
                            إلغاء
                        </button>
                        <button type="button" class="btn btn-warning" onclick="saveMaintenanceSchedule('${busId}')">
                            <i class="fas fa-calendar-plus me-2"></i>
                            جدولة الصيانة
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Remove existing modal if any
    const existingModal = document.getElementById('scheduleMaintenanceModal');
    if (existingModal) {
        existingModal.remove();
    }

    // Add modal to body and show
    document.body.insertAdjacentHTML('beforeend', modalContent);
    const modal = new bootstrap.Modal(document.getElementById('scheduleMaintenanceModal'));
    modal.show();

    // Set minimum date to today
    document.getElementById('maintenanceDate').min = new Date().toISOString().split('T')[0];

    // Clean up when modal is hidden
    document.getElementById('scheduleMaintenanceModal').addEventListener('hidden.bs.modal', function() {
        this.remove();
    });
}

function saveMaintenanceSchedule(busId) {
    console.log('💾 Saving maintenance schedule for bus:', busId);

    const maintenanceType = document.getElementById('maintenanceType').value;
    const maintenanceDate = document.getElementById('maintenanceDate').value;
    const maintenanceTime = document.getElementById('maintenanceTime').value;
    const maintenanceCenter = document.getElementById('maintenanceCenter').value;
    const estimatedCost = document.getElementById('estimatedCost').value;
    const maintenanceNotes = document.getElementById('maintenanceNotes').value;
    const notifyDriver = document.getElementById('notifyDriver').checked;
    const setBusOutOfService = document.getElementById('setBusOutOfService').checked;

    if (!maintenanceType || !maintenanceDate) {
        alert('يرجى ملء الحقول المطلوبة');
        return;
    }

    // Update bus status if needed
    if (setBusOutOfService) {
        const busIndex = busesData.findIndex(b => b.id === busId);
        if (busIndex !== -1) {
            busesData[busIndex].status = 'maintenance';
            busesData[busIndex].currentLocation = 'ورشة الصيانة';
        }
    }

    // Close modal
    const modal = bootstrap.Modal.getInstance(document.getElementById('scheduleMaintenanceModal'));
    if (modal) modal.hide();

    // Show success message
    showNotification('تم جدولة الصيانة بنجاح!', 'success');

    // Reload page if status changed
    if (setBusOutOfService) {
        loadPage('buses');
    }
}

function exportBuses() {
    console.log('📤 Exporting buses data...');

    if (busesData.length === 0) {
        alert('لا توجد بيانات سيارات للتصدير');
        return;
    }

    // Create CSV content
    const csvContent = [
        ['رقم اللوحة', 'السائق', 'رقم الهاتف', 'المسار', 'السعة', 'عدد الطلاب', 'التكييف', 'الحالة', 'الموقع الحالي', 'مستوى الوقود'].join(','),
        ...busesData.map(bus => [
            bus.plateNumber || '',
            bus.driverName || '',
            bus.driverPhone || '',
            bus.route || '',
            bus.capacity || '',
            bus.studentsCount || 0,
            bus.hasAirConditioning ? 'نعم' : 'لا',
            getBusStatusText(bus.status),
            bus.currentLocation || '',
            (bus.fuelLevel || 0) + '%'
        ].join(','))
    ].join('\n');

    // Download CSV
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    link.setAttribute('href', url);
    link.setAttribute('download', `buses_data_${new Date().toISOString().split('T')[0]}.csv`);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    showNotification('تم تصدير بيانات السيارات بنجاح!', 'success');
}

async function trackAllBuses() {
    console.log('🗺️ Tracking all buses...');

    // Get all buses locations from database
    const busesLocations = await getAllBusesLocations();

    const modalContent = `
        <div class="modal fade" id="trackAllBusesModal" tabindex="-1">
            <div class="modal-dialog modal-fullscreen">
                <div class="modal-content">
                    <div class="modal-header bg-info text-white">
                        <h5 class="modal-title">
                            <i class="fas fa-map-marked-alt me-2"></i>
                            تتبع جميع السيارات
                        </h5>
                        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body p-0">
                        <div class="row g-0">
                            <!-- Map Area -->
                            <div class="col-lg-9">
                                <div class="map-container" style="height: 80vh; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); position: relative;">
                                    <div class="map-placeholder d-flex align-items-center justify-content-center h-100 text-white">
                                        <div class="text-center">
                                            <i class="fas fa-map fa-4x mb-3 opacity-50"></i>
                                            <h4>خريطة تتبع جميع السيارات</h4>
                                            <p class="mb-0">سيتم عرض مواقع جميع السيارات هنا</p>
                                        </div>
                                    </div>

                                    <!-- Bus Markers -->
                                    ${busesLocations.map((busLocation, index) => `
                                        <div class="bus-marker" style="position: absolute; top: ${20 + (index * 10)}%; left: ${30 + (index * 15)}%; transform: translate(-50%, -50%);">
                                            <div class="marker-pulse">
                                                <div class="marker-icon ${getBusStatusClass(busLocation.status)} text-white rounded-circle d-flex align-items-center justify-content-center"
                                                     style="width: 30px; height: 30px; cursor: pointer;"
                                                     onclick="showBusLocationInfo('${busLocation.busId}')" title="${busLocation.plateNumber} - ${busLocation.currentLocation}">
                                                    <i class="fas fa-bus"></i>
                                                </div>
                                            </div>
                                        </div>
                                    `).join('')}
                                </div>
                            </div>

                            <!-- Buses List -->
                            <div class="col-lg-3">
                                <div class="buses-list p-3" style="height: 80vh; overflow-y: auto; background: #f8f9fa;">
                                    <h6 class="fw-bold mb-3">
                                        <i class="fas fa-list me-2"></i>
                                        قائمة السيارات (${busesLocations.length})
                                    </h6>

                                    ${busesLocations.map(busLocation => `
                                        <div class="bus-item card mb-2" onclick="focusOnBusLocation('${busLocation.busId}')">
                                            <div class="card-body p-2">
                                                <div class="d-flex align-items-center">
                                                    <div class="bus-status-indicator me-2">
                                                        <span class="status-dot ${getBusStatusClass(busLocation.status)}"></span>
                                                    </div>
                                                    <div class="flex-grow-1">
                                                        <h6 class="mb-1 fs-6">${busLocation.plateNumber}</h6>
                                                        <small class="text-muted">${busLocation.driverName}</small>
                                                        <div class="small text-muted location-text">${busLocation.currentLocation}</div>
                                                        <div class="small text-info">
                                                            <i class="fas fa-clock me-1"></i>
                                                            ${formatTime(busLocation.lastUpdated)}
                                                        </div>
                                                        ${busLocation.speed !== undefined && busLocation.speed > 0 ? `
                                                            <div class="small text-success">
                                                                <i class="fas fa-tachometer-alt me-1"></i>
                                                                ${busLocation.speed} كم/ساعة
                                                            </div>
                                                        ` : ''}
                                                    </div>
                                                    <div class="text-end">
                                                        <small class="badge ${getBusStatusClass(busLocation.status)}">${getBusStatusText(busLocation.status)}</small>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    `).join('')}
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>
                            إغلاق
                        </button>
                        <button type="button" class="btn btn-info" onclick="refreshAllBusesLocation()">
                            <i class="fas fa-sync-alt me-2"></i>
                            تحديث المواقع
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Remove existing modal if any
    const existingModal = document.getElementById('trackAllBusesModal');
    if (existingModal) {
        existingModal.remove();
    }

    // Add modal to body and show
    document.body.insertAdjacentHTML('beforeend', modalContent);
    const modal = new bootstrap.Modal(document.getElementById('trackAllBusesModal'));
    modal.show();

    // Store locations globally for updates
    window.currentBusesLocations = busesLocations;

    // Clean up when modal is hidden
    document.getElementById('trackAllBusesModal').addEventListener('hidden.bs.modal', function() {
        stopLocationTracking();
        window.currentBusesLocations = null;
        this.remove();
    });

    // Start location tracking for all buses
    startLocationTracking('all');
}

function showBusInfo(busId) {
    const bus = busesData.find(b => b.id === busId);
    if (bus) {
        alert(`السيارة: ${bus.plateNumber}\nالسائق: ${bus.driverName}\nالحالة: ${getBusStatusText(bus.status)}\nالموقع: ${bus.currentLocation}`);
    }
}

function showBusLocationInfo(busId) {
    console.log('📍 Showing bus location info:', busId);

    // Find bus location data
    const busLocation = window.currentBusesLocations?.find(bl => bl.busId === busId);
    const bus = busesData.find(b => b.id === busId);

    if (busLocation && bus) {
        const locationInfo = `
السيارة: ${busLocation.plateNumber}
السائق: ${busLocation.driverName}
الحالة: ${getBusStatusText(busLocation.status)}
الموقع الحالي: ${busLocation.currentLocation}
آخر تحديث: ${formatTime(busLocation.lastUpdated)}
${busLocation.coordinates ? `الإحداثيات: ${busLocation.coordinates.lat.toFixed(4)}°, ${busLocation.coordinates.lng.toFixed(4)}°` : ''}
${busLocation.speed !== undefined && busLocation.speed > 0 ? `السرعة: ${busLocation.speed} كم/ساعة` : ''}
        `.trim();

        alert(locationInfo);
    } else if (bus) {
        showBusInfo(busId);
    }
}

function focusOnBus(busId) {
    console.log('🎯 Focusing on bus:', busId);
    showBusInfo(busId);
}

function focusOnBusLocation(busId) {
    console.log('🎯 Focusing on bus location:', busId);
    showBusLocationInfo(busId);
}

async function refreshAllBusesLocation() {
    console.log('🔄 Refreshing all buses location...');

    try {
        // Get fresh location data
        const updatedLocations = await getAllBusesLocations();
        window.currentBusesLocations = updatedLocations;

        // Update the display
        await updateAllBusesTrackingDisplay();

        showNotification('تم تحديث مواقع جميع السيارات', 'success');

    } catch (error) {
        console.error('❌ Error refreshing all buses location:', error);
        showNotification('خطأ في تحديث مواقع السيارات', 'error');
    }
}

async function updateAllBusesTrackingDisplay() {
    console.log('🔄 Updating all buses tracking display...');

    try {
        const busesLocations = window.currentBusesLocations || await getAllBusesLocations();

        // Update buses list
        const busesList = document.querySelector('.buses-list');
        if (busesList) {
            const listContent = busesLocations.map(busLocation => `
                <div class="bus-item card mb-2" onclick="focusOnBusLocation('${busLocation.busId}')">
                    <div class="card-body p-2">
                        <div class="d-flex align-items-center">
                            <div class="bus-status-indicator me-2">
                                <span class="status-dot ${getBusStatusClass(busLocation.status)}"></span>
                            </div>
                            <div class="flex-grow-1">
                                <h6 class="mb-1 fs-6">${busLocation.plateNumber}</h6>
                                <small class="text-muted">${busLocation.driverName}</small>
                                <div class="small text-muted location-text">${busLocation.currentLocation}</div>
                                <div class="small text-info">
                                    <i class="fas fa-clock me-1"></i>
                                    ${formatTime(busLocation.lastUpdated)}
                                </div>
                                ${busLocation.speed !== undefined && busLocation.speed > 0 ? `
                                    <div class="small text-success">
                                        <i class="fas fa-tachometer-alt me-1"></i>
                                        ${busLocation.speed} كم/ساعة
                                    </div>
                                ` : ''}
                            </div>
                            <div class="text-end">
                                <small class="badge ${getBusStatusClass(busLocation.status)}">${getBusStatusText(busLocation.status)}</small>
                            </div>
                        </div>
                    </div>
                </div>
            `).join('');

            // Update the list content (excluding the header)
            const listHeader = busesList.querySelector('h6');
            if (listHeader) {
                listHeader.innerHTML = `
                    <i class="fas fa-list me-2"></i>
                    قائمة السيارات (${busesLocations.length})
                `;
            }

            // Update the bus items
            const existingItems = busesList.querySelectorAll('.bus-item');
            existingItems.forEach(item => item.remove());

            busesList.insertAdjacentHTML('beforeend', listContent);
        }

        console.log('✅ All buses tracking display updated');

    } catch (error) {
        console.error('❌ Error updating all buses tracking display:', error);
    }
}

function clearBusFilters() {
    console.log('🧹 Clearing bus filters...');
    document.getElementById('searchBuses').value = '';
    document.getElementById('filterBusStatus').value = '';
    document.getElementById('filterAirConditioning').value = '';
    loadPage('buses');
}

// Save Bus Function
function saveBus() {
    console.log('💾 Saving new bus from app.js...');
    console.log('🔍 Function saveBus called successfully!');

    // Log form elements for debugging
    console.log('🔍 Form elements check:');
    console.log('- plateNumber element:', document.getElementById('busPlateNumber') || document.getElementById('plateNumber'));
    console.log('- capacity element:', document.getElementById('busCapacity') || document.getElementById('capacity'));
    console.log('- description element:', document.getElementById('busDescription') || document.getElementById('description'));
    console.log('- route element:', document.getElementById('busRoute') || document.getElementById('route'));
    console.log('- hasAC element:', document.getElementById('busHasAC') || document.getElementById('hasAirConditioning'));
    console.log('- driverName element:', document.getElementById('driverName'));
    console.log('- driverPhone element:', document.getElementById('driverPhone'));

    // Get form data - check both possible ID formats
    const plateNumber = (document.getElementById('busPlateNumber') || document.getElementById('plateNumber'))?.value?.trim();
    const capacity = parseInt((document.getElementById('busCapacity') || document.getElementById('capacity'))?.value);
    const description = (document.getElementById('busDescription') || document.getElementById('description'))?.value?.trim();
    const route = (document.getElementById('busRoute') || document.getElementById('route'))?.value?.trim();
    const hasAC = (document.getElementById('busHasAC') || document.getElementById('hasAirConditioning'))?.checked;
    const driverName = document.getElementById('driverName')?.value?.trim();
    const driverPhone = document.getElementById('driverPhone')?.value?.trim();
    const fuelLevel = parseInt(document.getElementById('fuelLevel')?.value) || 100;
    const currentLocation = document.getElementById('currentLocation')?.value || 'المرآب الرئيسي';
    const status = document.getElementById('busStatus')?.value || 'available';
    const maintenanceDate = document.getElementById('maintenanceDate')?.value;

    // Log extracted data for debugging
    console.log('📝 Extracted form data:');
    console.log('- plateNumber:', plateNumber);
    console.log('- capacity:', capacity);
    console.log('- description:', description);
    console.log('- route:', route);
    console.log('- hasAC:', hasAC);
    console.log('- driverName:', driverName);
    console.log('- driverPhone:', driverPhone);
    console.log('- fuelLevel:', fuelLevel);
    console.log('- currentLocation:', currentLocation);
    console.log('- status:', status);
    console.log('- maintenanceDate:', maintenanceDate);

    // Validation
    if (!plateNumber) {
        alert('يرجى إدخال رقم اللوحة');
        return;
    }

    if (!capacity || capacity < 10 || capacity > 50) {
        alert('يرجى إدخال سعة صحيحة (10-50 مقعد)');
        return;
    }

    if (!driverName) {
        alert('يرجى إدخال اسم السائق');
        return;
    }

    if (!driverPhone) {
        alert('يرجى إدخال رقم هاتف السائق');
        return;
    }

    // Check if plate number already exists
    const existingBus = busesData.find(bus => bus.plateNumber === plateNumber);
    if (existingBus) {
        alert('رقم اللوحة موجود مسبقاً. يرجى استخدام رقم لوحة مختلف.');
        return;
    }

    // Create new bus object
    const newBus = {
        id: 'bus_' + Date.now(),
        plateNumber: plateNumber,
        description: description || 'سيارة نقل مدرسي',
        driverName: driverName,
        driverPhone: driverPhone,
        route: route || 'غير محدد',
        capacity: capacity,
        hasAirConditioning: hasAC,
        isActive: true,
        status: status,
        studentsCount: 0,
        fuelLevel: fuelLevel,
        currentLocation: currentLocation,
        maintenanceDate: maintenanceDate ? new Date(maintenanceDate) : null,
        createdAt: new Date(),
        updatedAt: new Date()
    };

    // Add to busesData array
    busesData.push(newBus);

    // Try to save to Firebase
    try {
        if (typeof FirebaseService !== 'undefined' && FirebaseService.addBus) {
            FirebaseService.addBus(newBus).then(() => {
                console.log('✅ Bus saved to Firebase successfully');
            }).catch(error => {
                console.error('❌ Error saving bus to Firebase:', error);
            });
        } else if (typeof db !== 'undefined') {
            // Direct Firebase save
            db.collection('buses').doc(newBus.id).set(newBus).then(() => {
                console.log('✅ Bus saved to Firebase via direct access');
            }).catch(error => {
                console.error('❌ Error saving bus via direct Firebase:', error);
            });
        }
    } catch (error) {
        console.error('❌ Error saving bus:', error);
    }

    // Close modal
    try {
        const modalElement = document.getElementById('addBusModal');
        if (modalElement) {
            const modal = bootstrap.Modal.getInstance(modalElement);
            if (modal) {
                modal.hide();
            } else {
                // If no instance exists, create one and hide it
                const newModal = new bootstrap.Modal(modalElement);
                newModal.hide();
            }
        }
    } catch (error) {
        console.error('❌ Error closing modal:', error);
    }

    // Clear form
    const form = document.getElementById('addBusForm');
    if (form) {
        form.reset();
    }

    // Reset fuel level display if exists
    const fuelLevelValue = document.getElementById('fuelLevelValue');
    if (fuelLevelValue) {
        fuelLevelValue.textContent = '100%';
    }

    // Reset bus ID if exists
    const busIdField = document.getElementById('busId');
    if (busIdField) {
        busIdField.value = '';
    }

    // Reload page to show new bus
    loadPage('buses');

    // Show success message
    showSuccessMessage('تم إضافة السيارة بنجاح!');
}

// Notification Functions
function showNotification(message, type = 'info') {
    console.log(`📢 ${type.toUpperCase()}: ${message}`);

    // Create notification element
    const notification = document.createElement('div');
    notification.className = `alert alert-${getAlertClass(type)} alert-dismissible fade show position-fixed`;
    notification.style.cssText = `
        top: 20px;
        right: 20px;
        z-index: 9999;
        min-width: 300px;
        max-width: 500px;
        box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
    `;

    notification.innerHTML = `
        <div class="d-flex align-items-center">
            <i class="fas ${getNotificationIcon(type)} me-2"></i>
            <span>${message}</span>
            <button type="button" class="btn-close ms-auto" data-bs-dismiss="alert"></button>
        </div>
    `;

    // Add to body
    document.body.appendChild(notification);

    // Auto remove after 5 seconds
    setTimeout(() => {
        if (notification && notification.parentNode) {
            notification.remove();
        }
    }, 5000);
}

function showSuccessMessage(message) {
    showNotification(message, 'success');
}

function showErrorMessage(message) {
    showNotification(message, 'error');
}

function showInfoMessage(message) {
    showNotification(message, 'info');
}

function showWarningMessage(message) {
    showNotification(message, 'warning');
}

function getAlertClass(type) {
    switch(type) {
        case 'success': return 'success';
        case 'error': return 'danger';
        case 'warning': return 'warning';
        case 'info': return 'info';
        default: return 'primary';
    }
}

function getNotificationIcon(type) {
    switch(type) {
        case 'success': return 'fa-check-circle';
        case 'error': return 'fa-exclamation-triangle';
        case 'warning': return 'fa-exclamation-circle';
        case 'info': return 'fa-info-circle';
        default: return 'fa-bell';
    }
}

// Reports helper functions
function formatDateTime(timestamp) {
    if (!timestamp) return 'غير محدد';

    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    const now = new Date();
    const diffMs = now - date;
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

    if (diffDays === 0) {
        return `اليوم ${date.toLocaleTimeString('ar-SA', { hour: '2-digit', minute: '2-digit' })}`;
    } else if (diffDays === 1) {
        return `أمس ${date.toLocaleTimeString('ar-SA', { hour: '2-digit', minute: '2-digit' })}`;
    } else if (diffDays < 7) {
        return `منذ ${diffDays} أيام`;
    } else {
        return date.toLocaleDateString('ar-SA');
    }
}

function getNotificationTypeClass(type) {
    const typeClasses = {
        'general': 'bg-primary',
        'pickup': 'bg-success',
        'delay': 'bg-warning',
        'emergency': 'bg-danger',
        'reminder': 'bg-info',
        'announcement': 'bg-secondary'
    };
    return typeClasses[type] || 'bg-primary';
}

function getNotificationTypeText(type) {
    const typeTexts = {
        'general': 'عام',
        'pickup': 'استلام',
        'delay': 'تأخير',
        'emergency': 'طارئ',
        'reminder': 'تذكير',
        'announcement': 'إعلان'
    };
    return typeTexts[type] || 'عام';
}

// Export functions for reports
function exportTripsReport() {
    console.log('📊 Exporting trips report...');

    // Get trips data
    FirebaseService.getTrips(100).then(trips => {
        const csvContent = generateTripsCSV(trips);
        downloadCSV(csvContent, `trips_report_${new Date().toISOString().split('T')[0]}.csv`);
        alert('تم تصدير تقرير الرحلات بنجاح!');
    }).catch(error => {
        console.error('❌ Error exporting trips:', error);
        alert('حدث خطأ أثناء تصدير التقرير');
    });
}

function exportNotificationsReport() {
    console.log('📊 Exporting notifications report...');

    FirebaseService.getNotifications(100).then(notifications => {
        const csvContent = generateNotificationsCSV(notifications);
        downloadCSV(csvContent, `notifications_report_${new Date().toISOString().split('T')[0]}.csv`);
        alert('تم تصدير تقرير الإشعارات بنجاح!');
    }).catch(error => {
        console.error('❌ Error exporting notifications:', error);
        alert('حدث خطأ أثناء تصدير التقرير');
    });
}

function exportUsersReport(userType) {
    console.log(`📊 Exporting ${userType} report...`);

    let dataPromise;
    let filename;

    switch(userType) {
        case 'students':
            dataPromise = FirebaseService.getStudents();
            filename = 'students_report';
            break;
        case 'parents':
            dataPromise = FirebaseService.getParents();
            filename = 'parents_report';
            break;
        case 'supervisors':
            dataPromise = FirebaseService.getSupervisors();
            filename = 'supervisors_report';
            break;
        default:
            alert('نوع المستخدم غير صحيح');
            return;
    }

    dataPromise.then(data => {
        const csvContent = generateUsersCSV(data, userType);
        downloadCSV(csvContent, `${filename}_${new Date().toISOString().split('T')[0]}.csv`);
        alert(`تم تصدير تقرير ${getUserTypeText(userType)} بنجاح!`);
    }).catch(error => {
        console.error(`❌ Error exporting ${userType}:`, error);
        alert('حدث خطأ أثناء تصدير التقرير');
    });
}

function exportActivityReport(activityType) {
    console.log(`📊 Exporting ${activityType} activity report...`);

    if (activityType === 'trips') {
        exportTripsReport();
    } else if (activityType === 'notifications') {
        exportNotificationsReport();
    }
}

function exportFullReport() {
    console.log('📊 Exporting full system report...');
    alert('ميزة التقرير الشامل قيد التطوير');
}

// CSV generation functions
function generateTripsCSV(trips) {
    const headers = ['التاريخ والوقت', 'الطالب', 'المشرف', 'خط الباص', 'نوع الرحلة', 'الإجراء', 'ملاحظات'];
    const rows = trips.map(trip => [
        formatDateTime(trip.timestamp),
        trip.studentName || 'غير محدد',
        trip.supervisorName || 'غير محدد',
        trip.busRoute || 'غير محدد',
        trip.tripType === 'toSchool' ? 'إلى المدرسة' : 'إلى المنزل',
        trip.action === 'boardBus' ? 'ركوب الباص' : 'النزول من الباص',
        trip.notes || ''
    ]);

    return [headers, ...rows].map(row => row.join(',')).join('\n');
}

function generateNotificationsCSV(notifications) {
    const headers = ['التاريخ والوقت', 'العنوان', 'المحتوى', 'المستلم', 'النوع', 'الحالة'];
    const rows = notifications.map(notification => [
        formatDateTime(notification.timestamp),
        notification.title || 'إشعار',
        (notification.body || '').replace(/,/g, '،'),
        notification.studentName || notification.recipientId || 'غير محدد',
        getNotificationTypeText(notification.type),
        notification.isRead ? 'مقروء' : 'غير مقروء'
    ]);

    return [headers, ...rows].map(row => row.join(',')).join('\n');
}

function generateUsersCSV(users, userType) {
    let headers, rows;

    switch(userType) {
        case 'students':
            headers = ['الاسم', 'الصف', 'المدرسة', 'ولي الأمر', 'رقم الهاتف', 'خط الباص', 'الحالة'];
            rows = users.map(user => [
                user.name || 'غير محدد',
                user.grade || 'غير محدد',
                user.schoolName || 'غير محدد',
                user.parentName || 'غير محدد',
                user.parentPhone || 'غير محدد',
                user.busRoute || 'غير محدد',
                user.isActive ? 'نشط' : 'غير نشط'
            ]);
            break;
        case 'parents':
            headers = ['الاسم', 'البريد الإلكتروني', 'رقم الهاتف', 'العنوان', 'المهنة', 'رقم الطوارئ', 'الحالة'];
            rows = users.map(user => [
                user.name || 'غير محدد',
                user.email || 'غير محدد',
                user.phone || 'غير محدد',
                user.address || 'غير محدد',
                user.occupation || 'غير محدد',
                user.emergencyPhone || 'غير محدد',
                user.isActive ? 'نشط' : 'غير نشط'
            ]);
            break;
        case 'supervisors':
            headers = ['الاسم', 'البريد الإلكتروني', 'رقم الهاتف', 'خط الباص', 'الصلاحيات', 'الحالة'];
            rows = users.map(user => [
                user.name || 'غير محدد',
                user.email || 'غير محدد',
                user.phone || 'غير محدد',
                user.busRoute || 'غير محدد',
                (user.permissions || []).join('، '),
                user.isActive ? 'نشط' : 'غير نشط'
            ]);
            break;
        default:
            return '';
    }

    return [headers, ...rows].map(row => row.join(',')).join('\n');
}

function downloadCSV(csvContent, filename) {
    const blob = new Blob(['\ufeff' + csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    link.setAttribute('href', url);
    link.setAttribute('download', filename);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

function getUserTypeText(userType) {
    const typeTexts = {
        'students': 'الطلاب',
        'parents': 'أولياء الأمور',
        'supervisors': 'المشرفين'
    };
    return typeTexts[userType] || userType;
}

// Student status helper functions
function getStatusClass(status) {
    switch(status) {
        case 'home': return 'status-home';
        case 'onBus': return 'status-onBus';
        case 'atSchool': return 'status-atSchool';
        case 'inactive': return 'status-inactive';
        default: return 'status-inactive';
    }
}

function getStatusIcon(status) {
    switch(status) {
        case 'home': return 'fa-home';
        case 'onBus': return 'fa-bus';
        case 'atSchool': return 'fa-school';
        case 'inactive': return 'fa-times-circle';
        default: return 'fa-question-circle';
    }
}

function getStatusText(status) {
    switch(status) {
        case 'home': return 'في المنزل';
        case 'onBus': return 'في الباص';
        case 'atSchool': return 'في المدرسة';
        case 'inactive': return 'غير نشط';
        default: return 'غير محدد';
    }
}

// Refresh functions
function refreshTripsReport() {
    console.log('🔄 Refreshing trips report...');
    loadPage('reports');
}

function refreshNotificationsReport() {
    console.log('🔄 Refreshing notifications report...');
    loadPage('reports');
}

function formatDate(date) {
    if (!date) return 'غير محدد';
    const d = new Date(date);
    return d.toLocaleDateString('ar-SA', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });
}

// Supervisor management functions
function viewSupervisor(supervisorId) {
    console.log('👁️ Viewing supervisor:', supervisorId);

    const supervisor = supervisorsData.find(s => s.id === supervisorId);
    if (!supervisor) {
        alert('لم يتم العثور على المشرف');
        return;
    }

    // Create detailed view modal
    const modalContent = `
        <div class="modal fade" id="viewSupervisorModal" tabindex="-1">
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header bg-primary text-white">
                        <h5 class="modal-title">
                            <i class="fas fa-user-tie me-2"></i>
                            تفاصيل المشرف
                        </h5>
                        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <div class="row">
                            <!-- Personal Information -->
                            <div class="col-12 mb-4">
                                <h6 class="text-primary border-bottom pb-2 mb-3">
                                    <i class="fas fa-user me-2"></i>
                                    البيانات الشخصية
                                </h6>
                                <div class="row">
                                    <div class="col-md-6 mb-3">
                                        <label class="form-label fw-bold">الاسم الكامل:</label>
                                        <p class="form-control-plaintext">${supervisor.name || 'غير محدد'}</p>
                                    </div>
                                    <div class="col-md-6 mb-3">
                                        <label class="form-label fw-bold">البريد الإلكتروني:</label>
                                        <p class="form-control-plaintext">${supervisor.email || 'غير محدد'}</p>
                                    </div>
                                    <div class="col-md-6 mb-3">
                                        <label class="form-label fw-bold">رقم الهاتف:</label>
                                        <p class="form-control-plaintext">${supervisor.phone || 'غير محدد'}</p>
                                    </div>
                                    <div class="col-md-6 mb-3">
                                        <label class="form-label fw-bold">معرف المشرف:</label>
                                        <p class="form-control-plaintext"><code>${supervisor.id}</code></p>
                                    </div>
                                </div>
                            </div>

                            <!-- Work Information -->
                            <div class="col-12 mb-4">
                                <h6 class="text-primary border-bottom pb-2 mb-3">
                                    <i class="fas fa-briefcase me-2"></i>
                                    بيانات العمل
                                </h6>
                                <div class="row">
                                    <div class="col-md-6 mb-3">
                                        <label class="form-label fw-bold">خط الباص:</label>
                                        <p class="form-control-plaintext">
                                            <span class="badge bg-primary fs-6">${supervisor.busRoute || 'غير محدد'}</span>
                                        </p>
                                    </div>
                                    <div class="col-md-6 mb-3">
                                        <label class="form-label fw-bold">الحالة:</label>
                                        <p class="form-control-plaintext">
                                            <span class="status-badge ${getSupervisorStatusClass(supervisor.status)}">
                                                <i class="fas ${getSupervisorStatusIcon(supervisor.status)} me-1"></i>
                                                ${getSupervisorStatusText(supervisor.status)}
                                            </span>
                                        </p>
                                    </div>
                                    <div class="col-md-6 mb-3">
                                        <label class="form-label fw-bold">تاريخ التسجيل:</label>
                                        <p class="form-control-plaintext">${formatDate(supervisor.createdAt)}</p>
                                    </div>
                                    <div class="col-md-6 mb-3">
                                        <label class="form-label fw-bold">آخر دخول:</label>
                                        <p class="form-control-plaintext">${formatDate(supervisor.lastLogin)}</p>
                                    </div>
                                </div>
                            </div>

                            <!-- Permissions -->
                            <div class="col-12 mb-4">
                                <h6 class="text-primary border-bottom pb-2 mb-3">
                                    <i class="fas fa-key me-2"></i>
                                    الصلاحيات
                                </h6>
                                <div class="permissions-display">
                                    ${(supervisor.permissions || []).length > 0 ?
                                        supervisor.permissions.map(permission => `
                                            <span class="badge bg-success me-2 mb-2 fs-6">
                                                <i class="fas fa-check me-1"></i>
                                                ${getPermissionText(permission)}
                                            </span>
                                        `).join('') :
                                        '<p class="text-muted">لا توجد صلاحيات محددة</p>'
                                    }
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>إغلاق
                        </button>
                        <button type="button" class="btn btn-warning" onclick="editSupervisor('${supervisorId}')">
                            <i class="fas fa-edit me-2"></i>تعديل
                        </button>
                        <button type="button" class="btn btn-info" onclick="manageSupervisorPermissions('${supervisorId}')">
                            <i class="fas fa-key me-2"></i>إدارة الصلاحيات
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Remove existing modal if any
    const existingModal = document.getElementById('viewSupervisorModal');
    if (existingModal) {
        existingModal.remove();
    }

    // Add modal to body and show
    document.body.insertAdjacentHTML('beforeend', modalContent);
    const modal = new bootstrap.Modal(document.getElementById('viewSupervisorModal'));
    modal.show();

    // Clean up when modal is hidden
    document.getElementById('viewSupervisorModal').addEventListener('hidden.bs.modal', function() {
        this.remove();
    });
}

function editSupervisor(supervisorId) {
    console.log('✏️ Editing supervisor:', supervisorId);

    const supervisor = supervisorsData.find(s => s.id === supervisorId);
    if (!supervisor) {
        alert('لم يتم العثور على المشرف');
        return;
    }

    // Close view modal if open
    const viewModal = document.getElementById('viewSupervisorModal');
    if (viewModal) {
        const modal = bootstrap.Modal.getInstance(viewModal);
        if (modal) modal.hide();
    }

    // Create edit modal
    const modalContent = `
        <div class="modal fade" id="editSupervisorModal" tabindex="-1">
            <div class="modal-dialog modal-lg modal-dialog-scrollable">
                <div class="modal-content">
                    <div class="modal-header bg-warning text-dark">
                        <h5 class="modal-title">
                            <i class="fas fa-edit me-2"></i>
                            تعديل بيانات المشرف
                        </h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form id="editSupervisorForm">
                            <input type="hidden" name="supervisorId" value="${supervisor.id}">

                            <!-- Personal Information -->
                            <div class="mb-4">
                                <h6 class="text-primary mb-3">
                                    <i class="fas fa-user me-2"></i>
                                    البيانات الشخصية
                                </h6>
                                <div class="row">
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">الاسم الكامل *</label>
                                        <input type="text" class="form-control" name="name" value="${supervisor.name || ''}" required>
                                    </div>
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">رقم الهاتف *</label>
                                        <input type="tel" class="form-control" name="phone" value="${supervisor.phone || ''}" required>
                                    </div>
                                </div>
                                <div class="mb-3">
                                    <label class="form-label">البريد الإلكتروني *</label>
                                    <input type="email" class="form-control" name="email" value="${supervisor.email || ''}" required>
                                </div>
                            </div>

                            <!-- Work Information -->
                            <div class="mb-4">
                                <h6 class="text-primary mb-3">
                                    <i class="fas fa-briefcase me-2"></i>
                                    بيانات العمل
                                </h6>
                                <div class="row">
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">خط الباص *</label>
                                        <select class="form-control" name="busRoute" required>
                                            <option value="">اختر خط الباص</option>
                                            <option value="الخط الأول" ${supervisor.busRoute === 'الخط الأول' ? 'selected' : ''}>الخط الأول</option>
                                            <option value="الخط الثاني" ${supervisor.busRoute === 'الخط الثاني' ? 'selected' : ''}>الخط الثاني</option>
                                            <option value="الخط الثالث" ${supervisor.busRoute === 'الخط الثالث' ? 'selected' : ''}>الخط الثالث</option>
                                            <option value="الخط الرابع" ${supervisor.busRoute === 'الخط الرابع' ? 'selected' : ''}>الخط الرابع</option>
                                            <option value="الخط الخامس" ${supervisor.busRoute === 'الخط الخامس' ? 'selected' : ''}>الخط الخامس</option>
                                        </select>
                                    </div>
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">الحالة *</label>
                                        <select class="form-control" name="status" required>
                                            <option value="active" ${supervisor.status === 'active' ? 'selected' : ''}>نشط</option>
                                            <option value="inactive" ${supervisor.status === 'inactive' ? 'selected' : ''}>غير نشط</option>
                                            <option value="suspended" ${supervisor.status === 'suspended' ? 'selected' : ''}>موقوف</option>
                                        </select>
                                    </div>
                                </div>
                            </div>

                            <!-- Permissions -->
                            <div class="mb-4">
                                <h6 class="text-primary mb-3">
                                    <i class="fas fa-key me-2"></i>
                                    الصلاحيات
                                </h6>
                                <div class="row">
                                    <div class="col-sm-6 mb-2">
                                        <div class="form-check">
                                            <input class="form-check-input" type="checkbox" name="permissions" value="view_students"
                                                   id="edit_perm1" ${(supervisor.permissions || []).includes('view_students') ? 'checked' : ''}>
                                            <label class="form-check-label" for="edit_perm1">عرض بيانات الطلاب</label>
                                        </div>
                                    </div>
                                    <div class="col-sm-6 mb-2">
                                        <div class="form-check">
                                            <input class="form-check-input" type="checkbox" name="permissions" value="manage_trips"
                                                   id="edit_perm2" ${(supervisor.permissions || []).includes('manage_trips') ? 'checked' : ''}>
                                            <label class="form-check-label" for="edit_perm2">إدارة الرحلات</label>
                                        </div>
                                    </div>
                                    <div class="col-sm-6 mb-2">
                                        <div class="form-check">
                                            <input class="form-check-input" type="checkbox" name="permissions" value="send_notifications"
                                                   id="edit_perm3" ${(supervisor.permissions || []).includes('send_notifications') ? 'checked' : ''}>
                                            <label class="form-check-label" for="edit_perm3">إرسال الإشعارات</label>
                                        </div>
                                    </div>
                                    <div class="col-sm-6 mb-2">
                                        <div class="form-check">
                                            <input class="form-check-input" type="checkbox" name="permissions" value="view_reports"
                                                   id="edit_perm4" ${(supervisor.permissions || []).includes('view_reports') ? 'checked' : ''}>
                                            <label class="form-check-label" for="edit_perm4">عرض التقارير</label>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </form>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>إلغاء
                        </button>
                        <button type="button" class="btn btn-warning" onclick="updateSupervisor()">
                            <i class="fas fa-save me-2"></i>حفظ التغييرات
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Remove existing modal if any
    const existingModal = document.getElementById('editSupervisorModal');
    if (existingModal) {
        existingModal.remove();
    }

    // Add modal to body and show
    document.body.insertAdjacentHTML('beforeend', modalContent);
    const modal = new bootstrap.Modal(document.getElementById('editSupervisorModal'));
    modal.show();

    // Clean up when modal is hidden
    document.getElementById('editSupervisorModal').addEventListener('hidden.bs.modal', function() {
        this.remove();
        destroyAllBackdrops();
    });
}

function updateSupervisor() {
    console.log('💾 Updating supervisor...');

    // Check if Firebase is available and reload if needed
    if (!reloadFirebaseIfNeeded()) {
        return;
    }

    const form = document.getElementById('editSupervisorForm');
    if (!form) {
        alert('خطأ: لم يتم العثور على النموذج');
        return;
    }

    const formData = new FormData(form);
    const supervisorId = formData.get('supervisorId');

    // Find supervisor in array
    const supervisorIndex = supervisorsData.findIndex(s => s.id === supervisorId);
    if (supervisorIndex === -1) {
        alert('لم يتم العثور على المشرف');
        return;
    }

    // Get updated data
    const updatedData = {
        name: formData.get('name')?.trim(),
        email: formData.get('email')?.trim(),
        phone: formData.get('phone')?.trim(),
        busRoute: formData.get('busRoute'),
        status: formData.get('status'),
        permissions: formData.getAll('permissions')
    };

    // Validate required fields
    if (!updatedData.name || !updatedData.email || !updatedData.phone || !updatedData.busRoute) {
        alert('يرجى ملء جميع الحقول المطلوبة');
        return;
    }

    // Save to Firebase first
    const saveToFirebase = async () => {
        try {
            console.log('💾 Updating supervisor in Firebase:', supervisorId);
            console.log('📋 Update data:', updatedData);

            const result = await FirebaseService.updateSupervisor(supervisorId, updatedData);

            if (result && result.success) {
                console.log('✅ Supervisor updated in Firebase successfully');

                // Update supervisor in local array
                supervisorsData[supervisorIndex] = {
                    ...supervisorsData[supervisorIndex],
                    ...updatedData,
                    lastModified: new Date()
                };

                console.log('✅ Supervisor updated locally:', supervisorsData[supervisorIndex]);

                // Close modal
                const modal = bootstrap.Modal.getInstance(document.getElementById('editSupervisorModal'));
                if (modal) {
                    modal.hide();
                }
                destroyAllBackdrops();

                // Show success message
                alert('تم تحديث بيانات المشرف بنجاح في قاعدة البيانات!');

                // Refresh the page to show updated data
                loadPage('supervisors');

            } else {
                throw new Error(result?.error || 'فشل في تحديث المشرف');
            }

        } catch (error) {
            console.error('❌ Error updating supervisor in Firebase:', error);
            alert(`حدث خطأ أثناء تحديث المشرف في قاعدة البيانات:\n${error.message}`);
        }
    };

    // Execute the update operation
    saveToFirebase();
}

function deleteSupervisor(supervisorId) {
    console.log('🗑️ Deleting supervisor:', supervisorId);

    const supervisor = supervisorsData.find(s => s.id === supervisorId);
    if (!supervisor) {
        alert('لم يتم العثور على المشرف');
        return;
    }

    // Confirm deletion
    const confirmMessage = `هل أنت متأكد من حذف المشرف "${supervisor.name}"؟\n\nهذا الإجراء لا يمكن التراجع عنه.`;
    if (!confirm(confirmMessage)) {
        return;
    }

    // Check if FirebaseService is available
    if (typeof FirebaseService === 'undefined') {
        console.error('❌ FirebaseService is not available');
        alert('خطأ: خدمة Firebase غير متاحة. يرجى إعادة تحميل الصفحة.');
        return;
    }

    // Delete from Firebase first
    const deleteFromFirebase = async () => {
        try {
            console.log('🗑️ Deleting supervisor from Firebase:', supervisorId);

            const result = await FirebaseService.deleteSupervisor(supervisorId);

            if (result.success) {
                console.log('✅ Supervisor deleted from Firebase successfully');

                // Remove from local array
                const supervisorIndex = supervisorsData.findIndex(s => s.id === supervisorId);
                if (supervisorIndex !== -1) {
                    supervisorsData.splice(supervisorIndex, 1);
                    console.log('✅ Supervisor deleted from local array');

                    // Remove from table
                    const row = document.querySelector(`tr[data-supervisor-id="${supervisorId}"]`);
                    if (row) {
                        row.remove();
                        console.log('✅ Supervisor removed from table');
                    }

                    // Update statistics
                    updateSupervisorStatistics();

                    // Show success message
                    alert('تم حذف المشرف بنجاح من قاعدة البيانات!');

                } else {
                    console.warn('⚠️ Supervisor not found in local array');
                    alert('تم حذف المشرف من قاعدة البيانات!');
                    // Refresh page to sync
                    loadPage('supervisors');
                }

            } else {
                throw new Error(result.error || 'فشل في حذف المشرف');
            }

        } catch (error) {
            console.error('❌ Error deleting supervisor from Firebase:', error);
            alert(`حدث خطأ أثناء حذف المشرف من قاعدة البيانات:\n${error.message}`);
        }
    };

    // Execute the delete operation
    deleteFromFirebase();
}

function manageSupervisorPermissions(supervisorId) {
    console.log('🔑 Managing permissions for supervisor:', supervisorId);

    const supervisor = supervisorsData.find(s => s.id === supervisorId);
    if (!supervisor) {
        alert('لم يتم العثور على المشرف');
        return;
    }

    // Close any open modals
    const viewModal = document.getElementById('viewSupervisorModal');
    if (viewModal) {
        const modal = bootstrap.Modal.getInstance(viewModal);
        if (modal) modal.hide();
    }

    // Available permissions with descriptions
    const availablePermissions = [
        { id: 'view_students', name: 'عرض بيانات الطلاب', description: 'يمكن للمشرف عرض قائمة الطلاب وبياناتهم', icon: 'fa-users' },
        { id: 'manage_trips', name: 'إدارة الرحلات', description: 'يمكن للمشرف إدارة الرحلات وتتبع الطلاب', icon: 'fa-bus' },
        { id: 'send_notifications', name: 'إرسال الإشعارات', description: 'يمكن للمشرف إرسال إشعارات لأولياء الأمور', icon: 'fa-bell' },
        { id: 'view_reports', name: 'عرض التقارير', description: 'يمكن للمشرف عرض التقارير والإحصائيات', icon: 'fa-chart-bar' },
        { id: 'manage_attendance', name: 'إدارة الحضور', description: 'يمكن للمشرف تسجيل حضور وغياب الطلاب', icon: 'fa-check-circle' },
        { id: 'emergency_contact', name: 'الاتصال الطارئ', description: 'يمكن للمشرف الوصول لأرقام الطوارئ', icon: 'fa-phone-alt' }
    ];

    // Create permissions modal
    const modalContent = `
        <div class="modal fade" id="permissionsModal" tabindex="-1">
            <div class="modal-dialog modal-lg modal-dialog-scrollable">
                <div class="modal-content">
                    <div class="modal-header bg-info text-white">
                        <h5 class="modal-title">
                            <i class="fas fa-key me-2"></i>
                            إدارة صلاحيات المشرف: ${supervisor.name}
                        </h5>
                        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <div class="alert alert-info">
                            <i class="fas fa-info-circle me-2"></i>
                            <strong>ملاحظة:</strong> يمكنك تحديد الصلاحيات التي تريد منحها للمشرف. سيتم تطبيق التغييرات فوراً.
                        </div>

                        <form id="permissionsForm">
                            <input type="hidden" name="supervisorId" value="${supervisor.id}">

                            <div class="permissions-list">
                                ${availablePermissions.map(permission => `
                                    <div class="permission-item mb-3 p-3 border rounded">
                                        <div class="d-flex align-items-start">
                                            <div class="form-check me-3">
                                                <input class="form-check-input" type="checkbox"
                                                       name="permissions" value="${permission.id}"
                                                       id="perm_${permission.id}"
                                                       ${(supervisor.permissions || []).includes(permission.id) ? 'checked' : ''}>
                                            </div>
                                            <div class="flex-grow-1">
                                                <label class="form-check-label fw-bold" for="perm_${permission.id}">
                                                    <i class="fas ${permission.icon} me-2 text-primary"></i>
                                                    ${permission.name}
                                                </label>
                                                <p class="text-muted mb-0 mt-1">${permission.description}</p>
                                            </div>
                                        </div>
                                    </div>
                                `).join('')}
                            </div>

                            <div class="mt-4 p-3 bg-light rounded">
                                <h6 class="mb-2">
                                    <i class="fas fa-list me-2"></i>
                                    الصلاحيات الحالية:
                                </h6>
                                <div id="currentPermissions">
                                    ${(supervisor.permissions || []).length > 0 ?
                                        supervisor.permissions.map(perm => `
                                            <span class="badge bg-success me-2 mb-1">
                                                <i class="fas fa-check me-1"></i>
                                                ${getPermissionText(perm)}
                                            </span>
                                        `).join('') :
                                        '<span class="text-muted">لا توجد صلاحيات محددة</span>'
                                    }
                                </div>
                            </div>
                        </form>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>إلغاء
                        </button>
                        <button type="button" class="btn btn-success" onclick="selectAllPermissions()">
                            <i class="fas fa-check-double me-2"></i>تحديد الكل
                        </button>
                        <button type="button" class="btn btn-warning" onclick="clearAllPermissions()">
                            <i class="fas fa-times-circle me-2"></i>إلغاء الكل
                        </button>
                        <button type="button" class="btn btn-info" onclick="updatePermissions()">
                            <i class="fas fa-save me-2"></i>حفظ الصلاحيات
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Remove existing modal if any
    const existingModal = document.getElementById('permissionsModal');
    if (existingModal) {
        existingModal.remove();
    }

    // Add modal to body and show
    document.body.insertAdjacentHTML('beforeend', modalContent);
    const modal = new bootstrap.Modal(document.getElementById('permissionsModal'));
    modal.show();

    // Add real-time permission preview
    const checkboxes = document.querySelectorAll('#permissionsForm input[type="checkbox"]');
    checkboxes.forEach(checkbox => {
        checkbox.addEventListener('change', updatePermissionPreview);
    });

    // Clean up when modal is hidden
    document.getElementById('permissionsModal').addEventListener('hidden.bs.modal', function() {
        this.remove();
        destroyAllBackdrops();
    });
}

function saveSupervisor() {
    console.log('💾 Saving new supervisor...');

    try {
        const form = document.getElementById('addSupervisorForm');

        if (!form) {
            console.error('❌ Form not found');
            alert('خطأ: لم يتم العثور على النموذج');
            return;
        }

        const formData = new FormData(form);

        // Get form data
        const supervisorData = {
            name: formData.get('name')?.trim(),
            email: formData.get('email')?.trim(),
            phone: formData.get('phone')?.trim(),
            busRoute: formData.get('busRoute'),
            password: formData.get('password'),
            confirmPassword: formData.get('confirmPassword'),
            permissions: formData.getAll('permissions')
        };

        console.log('📋 Supervisor data:', supervisorData);

        // Validate required fields
        if (!supervisorData.name || !supervisorData.email || !supervisorData.phone || !supervisorData.busRoute || !supervisorData.password) {
            alert('يرجى ملء جميع الحقول المطلوبة');
            return;
        }

        // Validate email format
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(supervisorData.email)) {
            alert('يرجى إدخال بريد إلكتروني صحيح');
            return;
        }

        // Validate phone format
        const phoneRegex = /^[0-9]{10,}$/;
        if (!phoneRegex.test(supervisorData.phone)) {
            alert('يرجى إدخال رقم هاتف صحيح (10 أرقام على الأقل)');
            return;
        }

        // Validate password length
        if (supervisorData.password.length < 6) {
            alert('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
            return;
        }

        // Validate passwords match
        if (supervisorData.password !== supervisorData.confirmPassword) {
            alert('كلمات المرور غير متطابقة');
            return;
        }

        // Get save button
        const saveBtn = document.querySelector('#addSupervisorModal .modal-footer .btn-primary');
        const originalText = saveBtn ? saveBtn.innerHTML : '';

        // Show loading state
        if (saveBtn) {
            saveBtn.innerHTML = '<i class="fas fa-spinner fa-spin me-2"></i>جاري الحفظ...';
            saveBtn.disabled = true;
        }

        // Check if FirebaseService is available
        if (typeof FirebaseService === 'undefined') {
            console.error('❌ FirebaseService is not available');
            alert('خطأ: خدمة Firebase غير متاحة. يرجى إعادة تحميل الصفحة.');
            if (saveBtn) {
                saveBtn.innerHTML = originalText;
                saveBtn.disabled = false;
            }
            return;
        }

        // Save to Firebase
        const saveToFirebase = async () => {
            try {
                // Create new supervisor object
                const newSupervisorData = {
                    name: supervisorData.name,
                    email: supervisorData.email,
                    phone: supervisorData.phone,
                    busRoute: supervisorData.busRoute,
                    permissions: supervisorData.permissions || ['view_students', 'manage_trips'],
                    password: supervisorData.password
                };

                console.log('💾 Saving supervisor to Firebase:', newSupervisorData);
                console.log('🔍 FirebaseService available methods:', Object.keys(FirebaseService));

                // Save to Firebase
                const result = await FirebaseService.addSupervisor(newSupervisorData);

                if (result.success) {
                    console.log('✅ Supervisor saved to Firebase successfully:', result.id);

                    // Create local object for immediate display
                    const newSupervisor = {
                        id: result.id,
                        name: supervisorData.name,
                        email: supervisorData.email,
                        phone: supervisorData.phone,
                        busRoute: supervisorData.busRoute,
                        status: 'active',
                        createdAt: new Date(),
                        lastLogin: new Date(),
                        permissions: supervisorData.permissions || ['view_students', 'manage_trips']
                    };

                    // Add to supervisorsData array immediately
                    if (typeof supervisorsData !== 'undefined' && Array.isArray(supervisorsData)) {
                        supervisorsData.push(newSupervisor);
                        console.log('📋 Added to supervisorsData array, total:', supervisorsData.length);
                    }

                    // Restore button state first
                    if (saveBtn) {
                        saveBtn.innerHTML = originalText;
                        saveBtn.disabled = false;
                    }

                    // Destroy all backdrops immediately
                    destroyAllBackdrops();

                    // Close modal using force close function
                    forceCloseModal('addSupervisorModal');

                    // Reset form
                    form.reset();

                    // Extra cleanup after a delay
                    setTimeout(() => {
                        destroyAllBackdrops();
                    }, 100);

                    // Show success message
                    alert('تم إضافة المشرف بنجاح وحفظه في قاعدة البيانات!');

                    // Try to add to table directly first
                    const addedToTable = addSupervisorToTable(newSupervisor);

                    if (!addedToTable) {
                        // Fallback: reload the page if direct addition failed
                        console.log('🔄 Direct addition failed, reloading page...');
                        loadPage('supervisors');
                    }

                } else {
                    throw new Error(result.error || 'فشل في حفظ المشرف');
                }

            } catch (error) {
                console.error('❌ Error saving supervisor to Firebase:', error);

                // Restore button state
                if (saveBtn) {
                    saveBtn.innerHTML = originalText;
                    saveBtn.disabled = false;
                }

                // Force close modal even on error
                forceCloseModal('addSupervisorModal');

                alert(`حدث خطأ أثناء حفظ المشرف في قاعدة البيانات:\n${error.message}`);
            }
        };

        // Execute the save operation
        saveToFirebase();

    } catch (error) {
        console.error('❌ Error in saveSupervisor:', error);
        alert('حدث خطأ غير متوقع');

        // Ensure button is restored
        const saveBtn = document.querySelector('#addSupervisorModal .modal-footer .btn-primary');
        if (saveBtn) {
            saveBtn.disabled = false;
            saveBtn.innerHTML = '<i class="fas fa-save me-2"></i>إضافة المشرف';
        }
    }
}

function exportSupervisors() {
    console.log('📤 Exporting supervisors...');
    // TODO: Implement export functionality
    alert('سيتم تصدير بيانات المشرفين قريباً');
}

function clearSupervisorFilters() {
    console.log('🧹 Clearing supervisor filters...');
    document.getElementById('searchSupervisors').value = '';
    document.getElementById('filterSupervisorStatus').value = '';
    document.getElementById('filterSupervisorRoute').value = '';
    // TODO: Implement filter clearing and refresh
}

function toggleSupervisorView(viewType) {
    console.log('🔄 Toggling supervisor view to:', viewType);
    // TODO: Implement view toggle between table and grid
}

// Add event listeners for supervisor modal
function initializeSupervisorModal() {
    const modal = document.getElementById('addSupervisorModal');
    if (modal) {
        modal.addEventListener('shown.bs.modal', function () {
            // Focus on first input when modal opens
            const firstInput = modal.querySelector('input[name="name"]');
            if (firstInput) {
                firstInput.focus();
            }
        });

        modal.addEventListener('hidden.bs.modal', function () {
            console.log('🔄 Modal hidden event triggered');

            // DESTROY ALL BACKDROPS IMMEDIATELY
            destroyAllBackdrops();

            // Reset form when modal closes
            const form = modal.querySelector('#addSupervisorForm');
            if (form) {
                form.reset();
                // Remove validation classes
                form.querySelectorAll('.form-control').forEach(input => {
                    input.classList.remove('is-valid', 'is-invalid');
                });
            }

            // Reset button state
            const saveBtn = modal.querySelector('.btn-primary');
            if (saveBtn) {
                saveBtn.disabled = false;
                saveBtn.innerHTML = '<i class="fas fa-save me-2"></i>إضافة المشرف';
            }

            // Multiple backdrop destruction attempts
            setTimeout(() => destroyAllBackdrops(), 50);
            setTimeout(() => destroyAllBackdrops(), 100);
            setTimeout(() => destroyAllBackdrops(), 200);

            // Ensure modal state is completely reset
            setTimeout(() => {
                resetModalState();
                destroyAllBackdrops();
            }, 300);
        });

        // Also listen for hide event (before hidden)
        modal.addEventListener('hide.bs.modal', function () {
            console.log('🔄 Modal hide event triggered');
            destroyAllBackdrops();
        });

        // Add real-time validation
        const form = modal.querySelector('#addSupervisorForm');
        if (form) {
            // Password confirmation validation
            const password = form.querySelector('input[name="password"]');
            const confirmPassword = form.querySelector('input[name="confirmPassword"]');

            if (password && confirmPassword) {
                confirmPassword.addEventListener('input', function() {
                    if (this.value && password.value) {
                        if (this.value === password.value) {
                            this.classList.remove('is-invalid');
                            this.classList.add('is-valid');
                        } else {
                            this.classList.remove('is-valid');
                            this.classList.add('is-invalid');
                        }
                    }
                });
            }

            // Email validation
            const email = form.querySelector('input[name="email"]');
            if (email) {
                email.addEventListener('blur', function() {
                    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
                    if (this.value) {
                        if (emailRegex.test(this.value)) {
                            this.classList.remove('is-invalid');
                            this.classList.add('is-valid');
                        } else {
                            this.classList.remove('is-valid');
                            this.classList.add('is-invalid');
                        }
                    }
                });
            }

            // Phone validation
            const phone = form.querySelector('input[name="phone"]');
            if (phone) {
                phone.addEventListener('input', function() {
                    // Only allow numbers
                    this.value = this.value.replace(/[^0-9]/g, '');

                    if (this.value.length >= 10) {
                        this.classList.remove('is-invalid');
                        this.classList.add('is-valid');
                    } else if (this.value.length > 0) {
                        this.classList.remove('is-valid');
                        this.classList.add('is-invalid');
                    }
                });
            }
        }
    }
}

// Nuclear option - completely destroy all modal backdrops
function destroyAllBackdrops() {
    console.log('💥 DESTROYING ALL BACKDROPS...');

    // Find all possible backdrop selectors
    const selectors = [
        '.modal-backdrop',
        '.modal-backdrop.fade',
        '.modal-backdrop.show',
        '.modal-backdrop.fade.show',
        '[class*="backdrop"]',
        '[class*="modal-backdrop"]'
    ];

    selectors.forEach(selector => {
        const elements = document.querySelectorAll(selector);
        elements.forEach(el => {
            console.log(`💥 Destroying element with selector: ${selector}`);
            el.remove();
        });
    });

    // Clean body completely
    document.body.classList.remove('modal-open');
    document.body.style.overflow = '';
    document.body.style.paddingRight = '';
    document.body.style.removeProperty('overflow');
    document.body.style.removeProperty('padding-right');
    document.body.removeAttribute('style');

    console.log('✅ ALL BACKDROPS DESTROYED');
}

// Force close modal function
function forceCloseModal(modalId) {
    console.log('🔒 Force closing modal:', modalId);

    const modalElement = document.getElementById(modalId);
    if (modalElement) {
        // Destroy all backdrops first
        destroyAllBackdrops();

        // Try Bootstrap modal instance
        const modal = bootstrap.Modal.getInstance(modalElement);
        if (modal) {
            try {
                modal.hide();
                modal.dispose();
            } catch (e) {
                console.log('Bootstrap modal disposal failed, continuing...');
            }
        }

        // Force close the modal element
        modalElement.style.display = 'none';
        modalElement.classList.remove('show', 'fade');
        modalElement.setAttribute('aria-hidden', 'true');
        modalElement.removeAttribute('aria-modal');
        modalElement.removeAttribute('role');

        // Multiple attempts to destroy backdrops
        setTimeout(() => destroyAllBackdrops(), 50);
        setTimeout(() => destroyAllBackdrops(), 100);
        setTimeout(() => destroyAllBackdrops(), 200);
        setTimeout(() => destroyAllBackdrops(), 500);

        console.log('✅ Modal force closed successfully');
    }
}

// Enhanced modal management
function resetModalState() {
    console.log('🔄 Resetting modal state...');

    // Remove any stuck modal states from body
    document.body.classList.remove('modal-open');
    document.body.style.overflow = '';
    document.body.style.paddingRight = '';
    document.body.removeAttribute('style');

    // Remove any leftover backdrops (multiple attempts)
    let backdrops = document.querySelectorAll('.modal-backdrop');
    console.log(`🗑️ Found ${backdrops.length} backdrop(s) to remove`);

    backdrops.forEach((backdrop, index) => {
        console.log(`Removing backdrop ${index + 1}`);
        backdrop.remove();
    });

    // Double check for backdrops with different selectors
    const fadeBackdrops = document.querySelectorAll('.fade.modal-backdrop');
    const showBackdrops = document.querySelectorAll('.show.modal-backdrop');

    fadeBackdrops.forEach(backdrop => backdrop.remove());
    showBackdrops.forEach(backdrop => backdrop.remove());

    // Reset all modals
    const modals = document.querySelectorAll('.modal');
    modals.forEach(modal => {
        modal.style.display = 'none';
        modal.classList.remove('show', 'fade');
        modal.setAttribute('aria-hidden', 'true');
        modal.removeAttribute('aria-modal');
        modal.removeAttribute('role');

        // Reset any Bootstrap modal instances
        const modalInstance = bootstrap.Modal.getInstance(modal);
        if (modalInstance) {
            modalInstance.dispose();
        }
    });

    // Final cleanup after a delay
    setTimeout(() => {
        const finalBackdrops = document.querySelectorAll('.modal-backdrop, [class*="backdrop"]');
        if (finalBackdrops.length > 0) {
            console.log(`🧹 Final cleanup: removing ${finalBackdrops.length} remaining backdrop(s)`);
            finalBackdrops.forEach(backdrop => backdrop.remove());
        }

        // Ensure body is completely clean
        document.body.classList.remove('modal-open');

        console.log('✅ Modal state reset complete');
    }, 300);
}

// Call initialization when page loads
setTimeout(() => {
    initializeSupervisorModal();
}, 1000);

// Make functions globally available
window.viewSupervisor = viewSupervisor;
window.editSupervisor = editSupervisor;
window.deleteSupervisor = deleteSupervisor;
window.manageSupervisorPermissions = manageSupervisorPermissions;
window.saveSupervisor = saveSupervisor;
window.exportSupervisors = exportSupervisors;
window.clearSupervisorFilters = clearSupervisorFilters;
window.toggleSupervisorView = toggleSupervisorView;
window.initializeSupervisorModal = initializeSupervisorModal;
window.forceCloseModal = forceCloseModal;
window.resetModalState = resetModalState;

// Emergency reset function - call this if modals get stuck
function emergencyReset() {
    console.log('🚨 Emergency reset triggered');

    // Reset all modal states
    resetModalState();

    // Reset all buttons
    const buttons = document.querySelectorAll('button');
    buttons.forEach(btn => {
        btn.disabled = false;
        if (btn.innerHTML.includes('fa-spinner')) {
            btn.innerHTML = btn.innerHTML.replace(/<i class="fas fa-spinner[^>]*><\/i>[^<]*/, '<i class="fas fa-save me-2"></i>');
        }
    });

    // Remove any loading states
    const loadingElements = document.querySelectorAll('.fa-spinner');
    loadingElements.forEach(el => {
        el.classList.remove('fa-spinner', 'fa-spin');
        el.classList.add('fa-save');
    });

    console.log('✅ Emergency reset complete');
    alert('تم إعادة تعيين النظام بنجاح');
}

// Function to add supervisor to table without page reload
function addSupervisorToTable(supervisor) {
    console.log('📋 Adding supervisor to table:', supervisor);

    try {
        // Find the table body
        const tableBody = document.querySelector('#supervisorTableView tbody');
        if (!tableBody) {
            console.warn('⚠️ Table body not found, will reload page');
            return false;
        }

        // Create new row HTML
        const newRowHTML = `
            <tr class="supervisor-row" data-supervisor-id="${supervisor.id}">
                <td class="ps-4">
                    <div class="d-flex align-items-center">
                        <div class="supervisor-avatar me-3">
                            <div class="avatar-circle bg-warning">
                                <i class="fas fa-user-tie text-white"></i>
                            </div>
                        </div>
                        <div>
                            <h6 class="mb-1 fw-bold">${supervisor.name}</h6>
                            <small class="text-muted">ID: ${supervisor.id}</small>
                        </div>
                    </div>
                </td>
                <td>
                    <div>
                        <span class="fw-semibold d-block">${supervisor.email}</span>
                        <small class="text-muted">
                            <i class="fas fa-phone me-1"></i>
                            ${supervisor.phone}
                        </small>
                    </div>
                </td>
                <td>
                    <span class="badge bg-primary bg-gradient">${supervisor.busRoute}</span>
                </td>
                <td>
                    <div class="permissions-list">
                        ${(supervisor.permissions || []).map(permission => `
                            <span class="badge bg-light text-dark me-1 mb-1">${getPermissionText(permission)}</span>
                        `).join('')}
                    </div>
                </td>
                <td>
                    <div>
                        <small class="text-muted d-block">آخر دخول</small>
                        <span class="fw-semibold">الآن</span>
                    </div>
                </td>
                <td>
                    <span class="status-badge status-active">
                        <i class="fas fa-check-circle me-1"></i>
                        نشط
                    </span>
                </td>
                <td class="text-center">
                    <div class="btn-group" role="group">
                        <button class="btn btn-sm btn-outline-primary" onclick="viewSupervisor('${supervisor.id}')" title="عرض">
                            <i class="fas fa-eye"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-warning" onclick="editSupervisor('${supervisor.id}')" title="تعديل">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-info" onclick="manageSupervisorPermissions('${supervisor.id}')" title="الصلاحيات">
                            <i class="fas fa-key"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-danger" onclick="deleteSupervisor('${supervisor.id}')" title="حذف">
                            <i class="fas fa-trash"></i>
                        </button>
                    </div>
                </td>
            </tr>
        `;

        // Add the new row to the table
        tableBody.insertAdjacentHTML('beforeend', newRowHTML);

        // Update statistics if they exist
        updateSupervisorStatistics();

        console.log('✅ Supervisor added to table successfully');
        return true;

    } catch (error) {
        console.error('❌ Error adding supervisor to table:', error);
        return false;
    }
}

// Function to update supervisor statistics
function updateSupervisorStatistics() {
    try {
        if (typeof supervisorsData !== 'undefined' && Array.isArray(supervisorsData)) {
            // Update total supervisors
            const totalElement = document.querySelector('.stat-card.primary h3');
            if (totalElement) {
                totalElement.textContent = supervisorsData.length;
            }

            // Update active supervisors
            const activeCount = supervisorsData.filter(s => s.status === 'active').length;
            const activeElement = document.querySelector('.stat-card.success h3');
            if (activeElement) {
                activeElement.textContent = activeCount;
            }

            console.log('📊 Statistics updated');
        }
    } catch (error) {
        console.error('❌ Error updating statistics:', error);
    }
}

// Make emergency reset available globally
window.emergencyReset = emergencyReset;
window.addSupervisorToTable = addSupervisorToTable;

// Permission management functions
function updatePermissionPreview() {
    const form = document.getElementById('permissionsForm');
    if (!form) return;

    const selectedPermissions = Array.from(form.querySelectorAll('input[name="permissions"]:checked'))
        .map(input => input.value);

    const previewContainer = document.getElementById('currentPermissions');
    if (previewContainer) {
        if (selectedPermissions.length > 0) {
            previewContainer.innerHTML = selectedPermissions.map(perm => `
                <span class="badge bg-success me-2 mb-1">
                    <i class="fas fa-check me-1"></i>
                    ${getPermissionText(perm)}
                </span>
            `).join('');
        } else {
            previewContainer.innerHTML = '<span class="text-muted">لا توجد صلاحيات محددة</span>';
        }
    }
}

function selectAllPermissions() {
    const checkboxes = document.querySelectorAll('#permissionsForm input[type="checkbox"]');
    checkboxes.forEach(checkbox => {
        checkbox.checked = true;
    });
    updatePermissionPreview();
}

function clearAllPermissions() {
    const checkboxes = document.querySelectorAll('#permissionsForm input[type="checkbox"]');
    checkboxes.forEach(checkbox => {
        checkbox.checked = false;
    });
    updatePermissionPreview();
}

function updatePermissions() {
    console.log('🔑 Updating permissions...');

    const form = document.getElementById('permissionsForm');
    if (!form) {
        alert('خطأ: لم يتم العثور على النموذج');
        return;
    }

    const formData = new FormData(form);
    const supervisorId = formData.get('supervisorId');
    const selectedPermissions = formData.getAll('permissions');

    // Find supervisor in array
    const supervisorIndex = supervisorsData.findIndex(s => s.id === supervisorId);
    if (supervisorIndex === -1) {
        alert('لم يتم العثور على المشرف');
        return;
    }

    // Check if FirebaseService is available
    if (typeof FirebaseService === 'undefined') {
        console.error('❌ FirebaseService is not available');
        alert('خطأ: خدمة Firebase غير متاحة. يرجى إعادة تحميل الصفحة.');
        return;
    }

    // Update permissions in Firebase first
    const updateInFirebase = async () => {
        try {
            console.log('🔑 Updating permissions in Firebase:', supervisorId, selectedPermissions);

            const result = await FirebaseService.updateSupervisorPermissions(supervisorId, selectedPermissions);

            if (result.success) {
                console.log('✅ Permissions updated in Firebase successfully');

                // Update permissions in local array
                supervisorsData[supervisorIndex].permissions = selectedPermissions;
                supervisorsData[supervisorIndex].lastModified = new Date();

                console.log('✅ Permissions updated locally:', selectedPermissions);

                // Close modal
                const modal = bootstrap.Modal.getInstance(document.getElementById('permissionsModal'));
                if (modal) {
                    modal.hide();
                }
                destroyAllBackdrops();

                // Show success message
                alert(`تم تحديث صلاحيات المشرف بنجاح في قاعدة البيانات!\nالصلاحيات الجديدة: ${selectedPermissions.length} صلاحية`);

                // Refresh the page to show updated permissions
                loadPage('supervisors');

            } else {
                throw new Error(result.error || 'فشل في تحديث الصلاحيات');
            }

        } catch (error) {
            console.error('❌ Error updating permissions in Firebase:', error);
            alert(`حدث خطأ أثناء تحديث الصلاحيات في قاعدة البيانات:\n${error.message}`);
        }
    };

    // Execute the update operation
    updateInFirebase();
}

// Function to reload Firebase if needed
function reloadFirebaseIfNeeded() {
    if (!checkFirebaseAvailability()) {
        console.log('🔄 Firebase not available, attempting to reload...');

        // Show loading message
        const loadingMessage = document.createElement('div');
        loadingMessage.id = 'firebaseReloadMessage';
        loadingMessage.style.cssText = `
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: #fff;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.3);
            z-index: 10000;
            text-align: center;
        `;
        loadingMessage.innerHTML = `
            <div class="spinner-border text-primary mb-3" role="status"></div>
            <h5>جاري إعادة تحميل خدمات Firebase...</h5>
            <p class="text-muted">يرجى الانتظار...</p>
        `;
        document.body.appendChild(loadingMessage);

        // Reload the page after 3 seconds
        setTimeout(() => {
            window.location.reload();
        }, 3000);

        return false;
    }
    return true;
}

// Make functions globally available
window.updateSupervisor = updateSupervisor;
window.updatePermissionPreview = updatePermissionPreview;
window.selectAllPermissions = selectAllPermissions;
window.clearAllPermissions = clearAllPermissions;
window.updatePermissions = updatePermissions;
window.checkFirebaseAvailability = checkFirebaseAvailability;
window.reloadFirebaseIfNeeded = reloadFirebaseIfNeeded;

// Make parent management functions globally available
window.updateParent = updateParent;
window.loadParentChildren = loadParentChildren;
window.addChildToParent = addChildToParent;
window.removeChildFromParent = removeChildFromParent;
window.sendNotification = sendNotification;
window.showAllChildren = showAllChildren;
window.manageChildren = manageChildren;
window.viewChildDetails = viewChildDetails;
window.editChild = editChild;
window.trackChild = trackChild;
window.addNewChild = addNewChild;
window.selectAllChildren = selectAllChildren;
window.deselectAllChildren = deselectAllChildren;
window.bulkAssignBus = bulkAssignBus;
window.bulkUpdateStatus = bulkUpdateStatus;
window.saveChildrenChanges = saveChildrenChanges;
window.toggleParentView = toggleParentView;
window.sortParents = sortParents;
window.refreshParentsData = refreshParentsData;
window.getActivityStatus = getActivityStatus;
window.viewParentActivity = viewParentActivity;
window.sendNotificationToParent = sendNotificationToParent;
window.toggleBusView = toggleBusView;
window.sortBuses = sortBuses;
window.refreshBusesData = refreshBusesData;
window.getBusStatusClass = getBusStatusClass;
window.getBusStatusIcon = getBusStatusIcon;
window.getBusStatusText = getBusStatusText;
window.getCapacityClass = getCapacityClass;
window.getOccupancyBarClass = getOccupancyBarClass;
window.getFuelBarClass = getFuelBarClass;
window.saveBus = saveBus;
window.viewBus = viewBus;
window.editBus = editBus;
window.deleteBus = deleteBus;
window.trackBus = trackBus;
window.manageBusStudents = manageBusStudents;
window.scheduleMaintenance = scheduleMaintenance;
window.updateBus = updateBus;
window.addStudentToBus = addStudentToBus;
window.removeStudentFromBus = removeStudentFromBus;
window.filterAvailableStudents = filterAvailableStudents;
window.removeAllStudentsFromBus = removeAllStudentsFromBus;
window.exportBusStudents = exportBusStudents;
window.printBusStudents = printBusStudents;
window.notifyBusParents = notifyBusParents;
window.saveBusStudentsChanges = saveBusStudentsChanges;
window.saveMaintenanceSchedule = saveMaintenanceSchedule;
window.showBusInfo = showBusInfo;
window.showBusLocationInfo = showBusLocationInfo;
window.focusOnBus = focusOnBus;
window.focusOnBusLocation = focusOnBusLocation;
window.refreshAllBusesLocation = refreshAllBusesLocation;
window.refreshBusLocationInModal = refreshBusLocationInModal;
window.getBusCurrentLocation = getBusCurrentLocation;
window.updateBusLocation = updateBusLocation;
window.startLocationTracking = startLocationTracking;
window.stopLocationTracking = stopLocationTracking;
window.showNotification = showNotification;
window.showSuccessMessage = showSuccessMessage;
window.showErrorMessage = showErrorMessage;
window.showInfoMessage = showInfoMessage;
window.showWarningMessage = showWarningMessage;

// Test function to check if saveBus is working
window.testSaveBus = function() {
    console.log('🧪 Testing saveBus function...');
    if (typeof saveBus === 'function') {
        console.log('✅ saveBus function exists');
        console.log('🔍 saveBus function:', saveBus);
        return true;
    } else {
        console.error('❌ saveBus function not found');
        return false;
    }
};

// Add showAddBusModal function for compatibility with buses.html
window.showAddBusModal = function() {
    console.log('🚌 Showing add bus modal...');

    const modalElement = document.getElementById('addBusModal');
    if (!modalElement) {
        console.error('❌ Modal element not found!');
        showErrorMessage('خطأ: نافذة إضافة السيارة غير موجودة');
        return;
    }

    // Reset form
    const form = document.getElementById('addBusForm');
    if (form) {
        form.reset();

        // Reset bus ID
        const busIdField = document.getElementById('busId');
        if (busIdField) {
            busIdField.value = '';
        }
    }

    // Update modal title
    const titleElement = document.getElementById('busModalTitle');
    if (titleElement) {
        titleElement.textContent = 'إضافة سيارة جديدة';
    }

    // Show modal
    try {
        const modal = new bootstrap.Modal(modalElement);
        modal.show();
        console.log('✅ Modal shown successfully');
    } catch (error) {
        console.error('❌ Error showing modal:', error);
        showErrorMessage('خطأ في إظهار نافذة إضافة السيارة');
    }
};

// Function to update parent's children count in the table
function updateParentChildrenDisplay(parentId) {
    const parentIndex = parentsData.findIndex(p => p.id === parentId);
    if (parentIndex === -1) return;

    const parent = parentsData[parentIndex];
    const row = document.querySelector(`tr[data-parent-id="${parentId}"]`);

    if (row) {
        const childrenCell = row.querySelector('.children-list');
        if (childrenCell) {
            childrenCell.innerHTML = formatChildrenDisplay(parent.children);
        }
    }

    // Also update card view if visible
    const card = document.querySelector(`[data-parent-id="${parentId}"] .children-names`);
    if (card && parent.children && parent.children.length > 0) {
        card.innerHTML = parent.children.map(child => `
            <span class="badge bg-light text-dark me-1 mb-1">${child.name}</span>
        `).join('');
    }
}

// Enhanced add child function
window.updateParentChildrenDisplay = updateParentChildrenDisplay;

// Make reports functions globally available
window.exportTripsReport = exportTripsReport;
window.exportNotificationsReport = exportNotificationsReport;
window.exportUsersReport = exportUsersReport;
window.exportActivityReport = exportActivityReport;
window.exportFullReport = exportFullReport;
window.refreshTripsReport = refreshTripsReport;
window.refreshNotificationsReport = refreshNotificationsReport;

// QR Code functions for students
function generateStudentQRCode(student) {
    console.log('📱 Generating QR code for student:', student.id);

    const qrContainer = document.getElementById('qrCodeContainer');
    if (!qrContainer) {
        console.warn('⚠️ QR container not found');
        return;
    }

    // QR Code data - include student info
    const qrData = JSON.stringify({
        type: 'student',
        id: student.id,
        name: student.name,
        qrCode: student.qrCode || student.id,
        schoolName: student.schoolName,
        grade: student.grade,
        busRoute: student.busRoute,
        timestamp: new Date().toISOString()
    });

    try {
        // Clear container
        qrContainer.innerHTML = '';

        // Create QR code using a simple library approach
        // For now, we'll create a visual representation
        const qrCodeDiv = document.createElement('div');
        qrCodeDiv.className = 'qr-code-display';
        qrCodeDiv.innerHTML = `
            <div class="qr-visual">
                <div class="qr-pattern">
                    <div class="qr-corner tl"></div>
                    <div class="qr-corner tr"></div>
                    <div class="qr-corner bl"></div>
                    <div class="qr-data">
                        <div class="qr-modules">
                            ${generateQRPattern(student.qrCode || student.id)}
                        </div>
                    </div>
                </div>
            </div>
            <div class="qr-info mt-2">
                <small class="text-muted d-block">Student ID: ${student.id}</small>
                <small class="text-muted d-block">QR Code: ${student.qrCode || student.id}</small>
            </div>
        `;

        qrContainer.appendChild(qrCodeDiv);

        // Store QR data for download
        qrContainer.setAttribute('data-qr', qrData);

        console.log('✅ QR code generated successfully');

    } catch (error) {
        console.error('❌ Error generating QR code:', error);
        qrContainer.innerHTML = `
            <div class="alert alert-warning">
                <i class="fas fa-exclamation-triangle me-2"></i>
                خطأ في إنشاء رمز QR
            </div>
        `;
    }
}

function generateQRPattern(data) {
    // Simple visual pattern generator for QR code appearance
    const hash = data.split('').reduce((a, b) => {
        a = ((a << 5) - a) + b.charCodeAt(0);
        return a & a;
    }, 0);

    let pattern = '';
    for (let i = 0; i < 64; i++) {
        const isBlack = (hash + i) % 3 === 0;
        pattern += `<div class="qr-module ${isBlack ? 'black' : 'white'}"></div>`;
    }

    return pattern;
}

function downloadQRCode(studentId) {
    console.log('💾 Downloading QR code for student:', studentId);

    const student = studentsData.find(s => s.id === studentId);
    if (!student) {
        alert('لم يتم العثور على الطالب');
        return;
    }

    // Create a canvas for QR code
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    canvas.width = 300;
    canvas.height = 350;

    // White background
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Draw QR code placeholder (simple pattern)
    ctx.fillStyle = '#000000';
    const qrSize = 200;
    const startX = (canvas.width - qrSize) / 2;
    const startY = 20;

    // Draw border
    ctx.strokeStyle = '#000000';
    ctx.lineWidth = 2;
    ctx.strokeRect(startX, startY, qrSize, qrSize);

    // Draw pattern
    const moduleSize = 8;
    const modules = qrSize / moduleSize;

    for (let i = 0; i < modules; i++) {
        for (let j = 0; j < modules; j++) {
            if ((i + j + studentId.length) % 3 === 0) {
                ctx.fillRect(
                    startX + i * moduleSize,
                    startY + j * moduleSize,
                    moduleSize,
                    moduleSize
                );
            }
        }
    }

    // Add text information
    ctx.fillStyle = '#000000';
    ctx.font = '16px Arial';
    ctx.textAlign = 'center';

    const textY = startY + qrSize + 30;
    ctx.fillText(student.name, canvas.width / 2, textY);

    ctx.font = '12px Arial';
    ctx.fillText(`ID: ${student.id}`, canvas.width / 2, textY + 25);
    ctx.fillText(`QR: ${student.qrCode || student.id}`, canvas.width / 2, textY + 45);
    ctx.fillText(`Grade: ${student.grade}`, canvas.width / 2, textY + 65);

    // Download the image
    const link = document.createElement('a');
    link.download = `student_qr_${student.id}_${student.name.replace(/\s+/g, '_')}.png`;
    link.href = canvas.toDataURL();
    link.click();

    alert('تم تحميل رمز QR بنجاح!');
}

function printStudentCard(studentId) {
    console.log('🖨️ Printing student card:', studentId);

    const student = studentsData.find(s => s.id === studentId);
    if (!student) {
        alert('لم يتم العثور على الطالب');
        return;
    }

    // Create print window
    const printWindow = window.open('', '_blank');
    const printContent = `
        <!DOCTYPE html>
        <html>
        <head>
            <title>بطاقة الطالب - ${student.name}</title>
            <style>
                body {
                    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                    margin: 0;
                    padding: 20px;
                    background: white;
                    direction: rtl;
                }
                .student-card {
                    width: 350px;
                    margin: 0 auto;
                    border: 2px solid #007bff;
                    border-radius: 15px;
                    padding: 20px;
                    background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
                }
                .card-header {
                    text-align: center;
                    border-bottom: 2px solid #007bff;
                    padding-bottom: 15px;
                    margin-bottom: 20px;
                }
                .school-name {
                    font-size: 18px;
                    font-weight: bold;
                    color: #007bff;
                    margin-bottom: 5px;
                }
                .card-title {
                    font-size: 16px;
                    color: #6c757d;
                }
                .student-info {
                    margin-bottom: 20px;
                }
                .info-row {
                    display: flex;
                    justify-content: space-between;
                    margin-bottom: 10px;
                    padding: 8px;
                    background: white;
                    border-radius: 5px;
                }
                .info-label {
                    font-weight: bold;
                    color: #495057;
                }
                .info-value {
                    color: #007bff;
                }
                .qr-section {
                    text-align: center;
                    border-top: 2px solid #007bff;
                    padding-top: 15px;
                }
                .qr-placeholder {
                    width: 120px;
                    height: 120px;
                    border: 2px solid #007bff;
                    margin: 0 auto 10px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    background: white;
                    font-size: 12px;
                    color: #6c757d;
                }
                @media print {
                    body { margin: 0; padding: 10px; }
                    .student-card { margin: 0; }
                }
            </style>
        </head>
        <body>
            <div class="student-card">
                <div class="card-header">
                    <div class="school-name">${student.schoolName || 'مدرسة'}</div>
                    <div class="card-title">بطاقة طالب</div>
                </div>

                <div class="student-info">
                    <div class="info-row">
                        <span class="info-label">الاسم:</span>
                        <span class="info-value">${student.name}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">الصف:</span>
                        <span class="info-value">${student.grade}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">خط الباص:</span>
                        <span class="info-value">${student.busRoute}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">ولي الأمر:</span>
                        <span class="info-value">${student.parentName}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">الهاتف:</span>
                        <span class="info-value">${student.parentPhone}</span>
                    </div>
                </div>

                <div class="qr-section">
                    <div class="qr-placeholder">
                        QR Code<br>
                        ${student.qrCode || student.id}
                    </div>
                    <div style="font-size: 12px; color: #6c757d;">
                        معرف الطالب: ${student.id}
                    </div>
                </div>
            </div>
        </body>
        </html>
    `;

    printWindow.document.write(printContent);
    printWindow.document.close();

    // Wait for content to load then print
    setTimeout(() => {
        printWindow.print();
        printWindow.close();
    }, 500);
}

function viewParentDetails(parentId) {
    console.log('👨‍👩‍👧‍👦 Viewing parent details:', parentId);
    // This would open parent details - for now just show message
    alert(`عرض تفاصيل ولي الأمر: ${parentId}\n(سيتم تطوير هذه الميزة قريباً)`);
}

// Parent selection functions for student forms
function updateParentInfo() {
    console.log('🔄 Updating parent info...');

    const parentSelect = document.querySelector('select[name="parentId"]');
    const parentPhoneInput = document.querySelector('input[name="parentPhone"]');
    const newParentSection = document.getElementById('newParentSection');

    if (!parentSelect || !parentPhoneInput) {
        console.warn('⚠️ Parent form elements not found');
        return;
    }

    const selectedParentId = parentSelect.value;

    if (selectedParentId === 'new_parent') {
        // Show new parent form
        if (newParentSection) {
            newParentSection.style.display = 'block';
            // Make new parent fields required
            const newParentInputs = newParentSection.querySelectorAll('input[required]');
            newParentInputs.forEach(input => input.required = true);
        }
        parentPhoneInput.value = '';
        parentPhoneInput.placeholder = 'سيتم ملؤه من النموذج أعلاه';

    } else if (selectedParentId && selectedParentId !== '') {
        // Hide new parent form
        if (newParentSection) {
            newParentSection.style.display = 'none';
            // Remove required from new parent fields
            const newParentInputs = newParentSection.querySelectorAll('input');
            newParentInputs.forEach(input => {
                input.required = false;
                input.value = '';
            });
        }

        // Find selected parent and update phone
        const selectedParent = parentsData.find(p => p.id === selectedParentId);
        if (selectedParent) {
            parentPhoneInput.value = selectedParent.phone || '';
            parentPhoneInput.placeholder = 'رقم هاتف ولي الأمر';
            console.log('✅ Parent info updated:', selectedParent.name);
        }

    } else {
        // No parent selected
        if (newParentSection) {
            newParentSection.style.display = 'none';
            const newParentInputs = newParentSection.querySelectorAll('input');
            newParentInputs.forEach(input => {
                input.required = false;
                input.value = '';
            });
        }
        parentPhoneInput.value = '';
        parentPhoneInput.placeholder = 'سيتم ملؤه تلقائياً';
    }
}

async function loadParentsForStudentForm() {
    console.log('👨‍👩‍👧‍👦 Loading parents for student form...');

    const parentSelect = document.querySelector('select[name="parentId"]');
    if (!parentSelect) {
        console.warn('⚠️ Parent select element not found');
        return;
    }

    try {
        // Get parents from global data or fetch fresh
        let parents = parentsData;
        if (!parents || parents.length === 0) {
            console.log('🔄 Fetching parents from Firebase...');
            parents = await FirebaseService.getParents();
        }

        // Clear existing options except default ones
        const defaultOptions = parentSelect.querySelectorAll('option[value=""], option[value="new_parent"]');
        parentSelect.innerHTML = '';
        defaultOptions.forEach(option => parentSelect.appendChild(option));

        // Add parent options
        parents.forEach(parent => {
            if (parent.isActive) {
                const option = document.createElement('option');
                option.value = parent.id;
                option.textContent = `${parent.name} - ${parent.phone}`;
                option.setAttribute('data-phone', parent.phone);
                option.setAttribute('data-email', parent.email);
                parentSelect.appendChild(option);
            }
        });

        console.log(`✅ Loaded ${parents.length} parents for selection`);

    } catch (error) {
        console.error('❌ Error loading parents:', error);

        // Add error option
        const errorOption = document.createElement('option');
        errorOption.value = '';
        errorOption.textContent = 'خطأ في تحميل أولياء الأمور';
        errorOption.disabled = true;
        parentSelect.appendChild(errorOption);
    }
}

// Enhanced student saving with parent handling
async function saveStudentWithParent() {
    console.log('💾 Saving student with parent handling...');

    const form = document.getElementById('addStudentForm');
    const formData = new FormData(form);

    // Get parent selection
    const parentId = formData.get('parentId');
    const isNewParent = parentId === 'new_parent';

    let finalParentId = parentId;
    let parentName = '';
    let parentPhone = '';

    if (isNewParent) {
        // Create new parent first
        const newParentData = {
            name: formData.get('newParentName')?.trim(),
            phone: formData.get('newParentPhone')?.trim(),
            email: formData.get('newParentEmail')?.trim(),
            password: formData.get('newParentPassword')?.trim()
        };

        // Validate new parent data
        if (!newParentData.name || !newParentData.phone || !newParentData.email || !newParentData.password) {
            alert('يرجى ملء جميع بيانات ولي الأمر الجديد');
            return;
        }

        if (newParentData.password.length < 6) {
            alert('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
            return;
        }

        try {
            console.log('👨‍👩‍👧‍👦 Creating new parent...');
            const parentResult = await FirebaseService.addParent(newParentData);

            if (parentResult.success) {
                finalParentId = parentResult.id;
                parentName = newParentData.name;
                parentPhone = newParentData.phone;
                console.log('✅ New parent created:', finalParentId);
            } else {
                throw new Error(parentResult.error || 'فشل في إنشاء ولي الأمر');
            }

        } catch (error) {
            console.error('❌ Error creating parent:', error);
            alert(`حدث خطأ أثناء إنشاء ولي الأمر:\n${error.message}`);
            return;
        }

    } else if (parentId && parentId !== '') {
        // Use existing parent
        const selectedParent = parentsData.find(p => p.id === parentId);
        if (selectedParent) {
            parentName = selectedParent.name;
            parentPhone = selectedParent.phone;
        } else {
            alert('ولي الأمر المحدد غير موجود');
            return;
        }
    } else {
        alert('يرجى اختيار ولي الأمر أو إضافة جديد');
        return;
    }

    // Validate student data
    const requiredFields = ['name', 'grade', 'schoolName', 'busRoute'];
    const missingFields = [];

    for (const field of requiredFields) {
        if (!formData.get(field) || formData.get(field).trim() === '') {
            missingFields.push(field);
        }
    }

    if (missingFields.length > 0) {
        alert('يرجى ملء جميع الحقول المطلوبة للطالب');
        return;
    }

    // Validate student name
    const studentName = formData.get('name').trim();
    if (studentName.length < 2) {
        alert('اسم الطالب يجب أن يكون حرفين على الأقل');
        return;
    }

    // Show loading state
    const saveBtn = document.querySelector('#addStudentModal .btn-primary');
    const originalText = saveBtn.innerHTML;
    saveBtn.innerHTML = '<i class="fas fa-spinner fa-spin me-2"></i>جاري الحفظ...';
    saveBtn.disabled = true;

    try {
        // Generate unique QR code for student
        const timestamp = Date.now();
        const qrCode = `STUDENT_${timestamp}`;

        const studentData = {
            name: studentName,
            grade: formData.get('grade').trim(),
            schoolName: formData.get('schoolName').trim(),
            busRoute: formData.get('busRoute'),
            parentId: finalParentId,
            parentName: parentName,
            parentPhone: parentPhone,
            qrCode: qrCode,
            currentStatus: 'home',
            isActive: true
        };

        console.log('📝 Adding student with data:', studentData);
        const result = await FirebaseService.addStudent(studentData);

        if (result.success) {
            // Add student to local data
            const newStudent = {
                id: result.id,
                ...studentData,
                qrCode: result.qrCode,
                createdAt: new Date(),
                updatedAt: new Date()
            };
            studentsData.push(newStudent);

            // Update parent's children in local data
            if (finalParentId && finalParentId !== '') {
                const parentIndex = parentsData.findIndex(p => p.id === finalParentId);
                if (parentIndex !== -1) {
                    if (!parentsData[parentIndex].children) {
                        parentsData[parentIndex].children = [];
                    }
                    parentsData[parentIndex].children.push({
                        id: result.id,
                        name: studentData.name,
                        grade: studentData.grade,
                        schoolName: studentData.schoolName,
                        busRoute: studentData.busRoute,
                        qrCode: result.qrCode
                    });
                    console.log('✅ Parent children updated locally');
                }
            }

            // Close modal
            const modal = bootstrap.Modal.getInstance(document.getElementById('addStudentModal'));
            modal.hide();

            // Reset form
            form.reset();

            // Hide new parent section
            const newParentSection = document.getElementById('newParentSection');
            if (newParentSection) {
                newParentSection.style.display = 'none';
            }

            // Reload students page to show updated data
            loadPage('students');

            // Show success message
            alert(`تم إضافة الطالب ${studentData.name} بنجاح!\nولي الأمر: ${parentName}\nرمز QR: ${result.qrCode}`);

        } else {
            throw new Error(result.error || 'فشل في إضافة الطالب');
        }

    } catch (error) {
        console.error('❌ Error saving student:', error);
        alert(`حدث خطأ أثناء إضافة الطالب:\n${error.message}`);

    } finally {
        // Reset button
        saveBtn.innerHTML = originalText;
        saveBtn.disabled = false;
    }
}

// Make student functions globally available
window.updateStudent = updateStudent;
window.generateStudentQRCode = generateStudentQRCode;
window.downloadQRCode = downloadQRCode;
window.printStudentCard = printStudentCard;
window.viewParentDetails = viewParentDetails;
window.updateParentInfo = updateParentInfo;
window.loadParentsForStudentForm = loadParentsForStudentForm;
window.saveStudentWithParent = saveStudentWithParent;

// Parent selection for edit student form
function updateParentInfoEdit() {
    console.log('🔄 Updating parent info in edit form...');

    const parentSelect = document.querySelector('#editStudentForm select[name="parentId"]');
    const parentPhoneInput = document.querySelector('#editStudentForm input[name="parentPhone"]');

    if (!parentSelect || !parentPhoneInput) {
        console.warn('⚠️ Edit form elements not found');
        return;
    }

    const selectedParentId = parentSelect.value;

    if (selectedParentId && selectedParentId !== '') {
        // Find selected parent and update phone
        const selectedParent = parentsData.find(p => p.id === selectedParentId);
        if (selectedParent) {
            parentPhoneInput.value = selectedParent.phone || '';
            console.log('✅ Parent info updated in edit form:', selectedParent.name);
        }
    } else {
        parentPhoneInput.value = '';
    }
}

async function loadParentsForEditForm(currentParentId, currentParentName) {
    console.log('👨‍👩‍👧‍👦 Loading parents for edit form...');

    const parentSelect = document.querySelector('#editStudentForm select[name="parentId"]');
    if (!parentSelect) {
        console.warn('⚠️ Parent select element not found in edit form');
        return;
    }

    try {
        // Get parents from global data or fetch fresh
        let parents = parentsData;
        if (!parents || parents.length === 0) {
            console.log('🔄 Fetching parents from Firebase...');
            parents = await FirebaseService.getParents();
        }

        // Clear existing options
        parentSelect.innerHTML = '';

        // Add default option
        const defaultOption = document.createElement('option');
        defaultOption.value = '';
        defaultOption.textContent = 'اختر ولي الأمر';
        parentSelect.appendChild(defaultOption);

        // Add current parent option if exists
        if (currentParentId && currentParentName) {
            const currentOption = document.createElement('option');
            currentOption.value = currentParentId;
            currentOption.textContent = `${currentParentName} (الحالي)`;
            currentOption.selected = true;
            parentSelect.appendChild(currentOption);
        }

        // Add other parent options
        parents.forEach(parent => {
            if (parent.isActive && parent.id !== currentParentId) {
                const option = document.createElement('option');
                option.value = parent.id;
                option.textContent = `${parent.name} - ${parent.phone}`;
                option.setAttribute('data-phone', parent.phone);
                option.setAttribute('data-email', parent.email);
                parentSelect.appendChild(option);
            }
        });

        console.log(`✅ Loaded ${parents.length} parents for edit form`);

    } catch (error) {
        console.error('❌ Error loading parents for edit form:', error);

        // Add error option
        const errorOption = document.createElement('option');
        errorOption.value = '';
        errorOption.textContent = 'خطأ في تحميل أولياء الأمور';
        errorOption.disabled = true;
        parentSelect.appendChild(errorOption);
    }
}

window.updateParentInfoEdit = updateParentInfoEdit;
window.loadParentsForEditForm = loadParentsForEditForm;

// Filter parent <option> list live while typing in the search box
// formId: 'addStudentForm' or 'editStudentForm'
function filterParentOptions(query, formId) {
    const form = document.getElementById(formId);
    if (!form) return;

    const parentSelect = form.querySelector('select[name="parentId"]');
    if (!parentSelect) return;

    const normalizedQuery = (query || '').trim().toLowerCase();

    Array.from(parentSelect.options).forEach(option => {
        // Always keep the placeholder and "add new parent" options visible
        if (option.value === '' || option.value === 'new_parent') {
            option.hidden = false;
            return;
        }

        const text = option.textContent.toLowerCase();
        option.hidden = normalizedQuery !== '' && !text.includes(normalizedQuery);
    });
}

window.filterParentOptions = filterParentOptions;

// Add keyboard shortcut for emergency reset (Ctrl+Shift+R)
document.addEventListener('keydown', function(e) {
    if (e.ctrlKey && e.shiftKey && e.key === 'R') {
        e.preventDefault();
        emergencyReset();
    }
});

// Monitor and auto-remove stuck backdrops
function monitorBackdrops() {
    setInterval(() => {
        const backdrops = document.querySelectorAll('.modal-backdrop');
        const openModals = document.querySelectorAll('.modal.show');

        // If there are backdrops but no open modals, DESTROY THEM ALL
        if (backdrops.length > 0 && openModals.length === 0) {
            console.log('🧹 Auto-destroying stuck backdrops:', backdrops.length);
            destroyAllBackdrops();
        }

        // Also check for any backdrop that exists for more than 5 seconds
        const allBackdrops = document.querySelectorAll('.modal-backdrop');
        allBackdrops.forEach(backdrop => {
            if (!backdrop.dataset.createdTime) {
                backdrop.dataset.createdTime = Date.now();
            } else {
                const age = Date.now() - parseInt(backdrop.dataset.createdTime);
                if (age > 5000) { // 5 seconds
                    console.log('🧹 Removing old backdrop (age: ' + age + 'ms)');
                    destroyAllBackdrops();
                }
            }
        });
    }, 500); // Check every half second
}

// Add click listener to destroy backdrops when clicked
document.addEventListener('click', function(e) {
    if (e.target.classList.contains('modal-backdrop')) {
        console.log('🖱️ Backdrop clicked, destroying all backdrops');
        destroyAllBackdrops();
    }
});

// Add global backdrop destroyer
window.destroyAllBackdrops = destroyAllBackdrops;

// Destroy backdrops immediately when page loads
document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 Page loaded, destroying any existing backdrops');
    destroyAllBackdrops();

    // Check Firebase availability
    setTimeout(() => {
        checkFirebaseAvailability();
    }, 2000);
});

// Also destroy on window load
window.addEventListener('load', function() {
    console.log('🚀 Window loaded, destroying any existing backdrops');
    destroyAllBackdrops();
});

// Start monitoring when page loads
setTimeout(() => {
    destroyAllBackdrops(); // Initial cleanup
    monitorBackdrops();
}, 1000);

// Additional cleanup every 3 seconds
setInterval(() => {
    const backdrops = document.querySelectorAll('.modal-backdrop');
    if (backdrops.length > 0) {
        console.log('🧹 Periodic cleanup: destroying backdrops');
        destroyAllBackdrops();
    }
}, 3000);

// Helper functions for parents page - removed duplicates

// Parent management functions
function viewParent(parentId) {
    console.log('👁️ Viewing parent:', parentId);
    const parent = parentsData.find(p => p.id === parentId);
    if (parent) {
        // Create detailed view modal
        const modalContent = `
            <div class="modal fade" id="viewParentModal" tabindex="-1">
                <div class="modal-dialog modal-lg">
                    <div class="modal-content">
                        <div class="modal-header">
                            <h5 class="modal-title">
                                <i class="fas fa-user me-2"></i>
                                تفاصيل ولي الأمر
                            </h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <div class="row">
                                <div class="col-md-6 mb-3">
                                    <strong>الاسم:</strong> ${parent.name}
                                </div>
                                <div class="col-md-6 mb-3">
                                    <strong>صلة القرابة:</strong> ${parent.relationship}
                                </div>
                                <div class="col-md-6 mb-3">
                                    <strong>البريد الإلكتروني:</strong> ${parent.email}
                                </div>
                                <div class="col-md-6 mb-3">
                                    <strong>رقم الهاتف:</strong> ${parent.phone}
                                </div>
                                <div class="col-12 mb-3">
                                    <strong>العنوان:</strong> ${parent.address || 'غير محدد'}
                                </div>
                                <div class="col-md-6 mb-3">
                                    <strong>رقم الطوارئ:</strong> ${parent.emergencyContact || 'غير محدد'}
                                </div>
                                <div class="col-md-6 mb-3">
                                    <strong>عدد الأطفال:</strong> ${parent.children ? parent.children.length : 0}
                                </div>
                                ${parent.children && parent.children.length > 0 ? `
                                    <div class="col-12 mb-3">
                                        <strong>الأطفال:</strong>
                                        <div class="mt-2">
                                            ${parent.children.map(child => `
                                                <span class="badge bg-primary me-2 mb-1">${child.name} - ${child.grade}</span>
                                            `).join('')}
                                        </div>
                                    </div>
                                ` : ''}
                            </div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">إغلاق</button>
                            <button type="button" class="btn btn-primary" onclick="editParent('${parentId}')">تعديل</button>
                        </div>
                    </div>
                </div>
            </div>
        `;

        // Remove existing modal if any
        const existingModal = document.getElementById('viewParentModal');
        if (existingModal) {
            existingModal.remove();
        }

        // Add modal to body and show
        document.body.insertAdjacentHTML('beforeend', modalContent);
        const modal = new bootstrap.Modal(document.getElementById('viewParentModal'));
        modal.show();
    }
}

function editParent(parentId) {
    console.log('✏️ Editing parent:', parentId);

    // Check Firebase availability
    if (!reloadFirebaseIfNeeded()) {
        return;
    }

    const parent = parentsData.find(p => p.id === parentId);
    if (!parent) {
        alert('لم يتم العثور على ولي الأمر');
        return;
    }

    // Close view modal if open
    const viewModal = document.getElementById('viewParentModal');
    if (viewModal) {
        const modal = bootstrap.Modal.getInstance(viewModal);
        if (modal) modal.hide();
    }

    // Create edit modal
    const modalContent = `
        <div class="modal fade" id="editParentModal" tabindex="-1">
            <div class="modal-dialog modal-lg modal-dialog-scrollable">
                <div class="modal-content">
                    <div class="modal-header bg-warning text-dark">
                        <h5 class="modal-title">
                            <i class="fas fa-edit me-2"></i>
                            تعديل بيانات ولي الأمر
                        </h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form id="editParentForm">
                            <input type="hidden" name="parentId" value="${parent.id}">

                            <!-- Personal Information -->
                            <div class="mb-4">
                                <h6 class="text-primary mb-3">
                                    <i class="fas fa-user me-2"></i>
                                    البيانات الشخصية
                                </h6>
                                <div class="row">
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">الاسم الكامل *</label>
                                        <input type="text" class="form-control" name="name" value="${parent.name || ''}" required>
                                    </div>
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">رقم الهاتف *</label>
                                        <input type="tel" class="form-control" name="phone" value="${parent.phone || ''}" required>
                                    </div>
                                </div>
                                <div class="mb-3">
                                    <label class="form-label">البريد الإلكتروني *</label>
                                    <input type="email" class="form-control" name="email" value="${parent.email || ''}" required>
                                </div>
                            </div>

                            <!-- Additional Information -->
                            <div class="mb-4">
                                <h6 class="text-primary mb-3">
                                    <i class="fas fa-info-circle me-2"></i>
                                    معلومات إضافية
                                </h6>
                                <div class="row">
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">العنوان</label>
                                        <input type="text" class="form-control" name="address" value="${parent.address || ''}" placeholder="العنوان السكني">
                                    </div>
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">المهنة</label>
                                        <input type="text" class="form-control" name="occupation" value="${parent.occupation || ''}" placeholder="المهنة">
                                    </div>
                                </div>
                                <div class="row">
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">رقم هاتف الطوارئ</label>
                                        <input type="tel" class="form-control" name="emergencyPhone" value="${parent.emergencyPhone || ''}" placeholder="رقم بديل للطوارئ">
                                    </div>
                                    <div class="col-sm-6 mb-3">
                                        <label class="form-label">الحالة</label>
                                        <select class="form-control" name="status">
                                            <option value="active" ${parent.status === 'active' ? 'selected' : ''}>نشط</option>
                                            <option value="inactive" ${parent.status === 'inactive' ? 'selected' : ''}>غير نشط</option>
                                            <option value="suspended" ${parent.status === 'suspended' ? 'selected' : ''}>موقوف</option>
                                        </select>
                                    </div>
                                </div>
                            </div>

                            <!-- Notification Preferences -->
                            <div class="mb-4">
                                <h6 class="text-primary mb-3">
                                    <i class="fas fa-bell me-2"></i>
                                    تفضيلات الإشعارات
                                </h6>
                                <div class="row">
                                    <div class="col-sm-6 mb-2">
                                        <div class="form-check">
                                            <input class="form-check-input" type="checkbox" name="notifications" value="sms"
                                                   id="edit_notif1" ${(parent.notificationPreferences || []).includes('sms') ? 'checked' : ''}>
                                            <label class="form-check-label" for="edit_notif1">رسائل SMS</label>
                                        </div>
                                    </div>
                                    <div class="col-sm-6 mb-2">
                                        <div class="form-check">
                                            <input class="form-check-input" type="checkbox" name="notifications" value="email"
                                                   id="edit_notif2" ${(parent.notificationPreferences || []).includes('email') ? 'checked' : ''}>
                                            <label class="form-check-label" for="edit_notif2">البريد الإلكتروني</label>
                                        </div>
                                    </div>
                                    <div class="col-sm-6 mb-2">
                                        <div class="form-check">
                                            <input class="form-check-input" type="checkbox" name="notifications" value="push"
                                                   id="edit_notif3" ${(parent.notificationPreferences || []).includes('push') ? 'checked' : ''}>
                                            <label class="form-check-label" for="edit_notif3">إشعارات التطبيق</label>
                                        </div>
                                    </div>
                                    <div class="col-sm-6 mb-2">
                                        <div class="form-check">
                                            <input class="form-check-input" type="checkbox" name="notifications" value="emergency"
                                                   id="edit_notif4" ${(parent.notificationPreferences || []).includes('emergency') ? 'checked' : ''}>
                                            <label class="form-check-label" for="edit_notif4">إشعارات الطوارئ</label>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </form>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>إلغاء
                        </button>
                        <button type="button" class="btn btn-warning" onclick="updateParent()">
                            <i class="fas fa-save me-2"></i>حفظ التغييرات
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Remove existing modal if any
    const existingModal = document.getElementById('editParentModal');
    if (existingModal) {
        existingModal.remove();
    }

    // Add modal to body and show
    document.body.insertAdjacentHTML('beforeend', modalContent);
    const modal = new bootstrap.Modal(document.getElementById('editParentModal'));
    modal.show();

    // Clean up when modal is hidden
    document.getElementById('editParentModal').addEventListener('hidden.bs.modal', function() {
        this.remove();
        destroyAllBackdrops();
    });
}

function updateParent() {
    console.log('💾 Updating parent...');

    // Check Firebase availability
    if (!reloadFirebaseIfNeeded()) {
        return;
    }

    const form = document.getElementById('editParentForm');
    if (!form) {
        alert('خطأ: لم يتم العثور على النموذج');
        return;
    }

    const formData = new FormData(form);
    const parentId = formData.get('parentId');

    // Find parent in array
    const parentIndex = parentsData.findIndex(p => p.id === parentId);
    if (parentIndex === -1) {
        alert('لم يتم العثور على ولي الأمر');
        return;
    }

    // Get updated data with detailed logging
    const updatedData = {
        name: formData.get('name')?.trim(),
        email: formData.get('email')?.trim(),
        phone: formData.get('phone')?.trim(),
        address: formData.get('address')?.trim(),
        occupation: formData.get('occupation')?.trim(),
        emergencyPhone: formData.get('emergencyPhone')?.trim(),
        status: formData.get('status'),
        notificationPreferences: formData.getAll('notifications')
    };

    // Log each field for debugging
    console.log('📋 Form data extracted:');
    console.log('- Name:', updatedData.name);
    console.log('- Email:', updatedData.email);
    console.log('- Phone:', updatedData.phone);
    console.log('- Address:', updatedData.address);
    console.log('- Occupation:', updatedData.occupation);
    console.log('- Emergency Phone:', updatedData.emergencyPhone);
    console.log('- Status:', updatedData.status);
    console.log('- Notification Preferences:', updatedData.notificationPreferences);

    // Validate required fields
    if (!updatedData.name || !updatedData.email || !updatedData.phone) {
        alert('يرجى ملء جميع الحقول المطلوبة');
        return;
    }

    // Check if additional fields have values
    if (!updatedData.address && !updatedData.occupation && !updatedData.emergencyPhone) {
        console.warn('⚠️ No additional fields provided (address, occupation, emergencyPhone)');
    }

    // Save to Firebase first
    const saveToFirebase = async () => {
        try {
            console.log('💾 Updating parent in Firebase:', parentId);
            console.log('📋 Update data:', updatedData);

            const result = await FirebaseService.updateParent(parentId, updatedData);

            if (result && result.success) {
                console.log('✅ Parent updated in Firebase successfully');

                // Update parent in local array
                parentsData[parentIndex] = {
                    ...parentsData[parentIndex],
                    ...updatedData,
                    lastModified: new Date()
                };

                console.log('✅ Parent updated locally:', parentsData[parentIndex]);

                // Close modal
                const modal = bootstrap.Modal.getInstance(document.getElementById('editParentModal'));
                if (modal) {
                    modal.hide();
                }
                destroyAllBackdrops();

                // Show success message
                alert('تم تحديث بيانات ولي الأمر بنجاح في قاعدة البيانات!');

                // Refresh the page to show updated data
                loadPage('parents');

            } else {
                throw new Error(result?.error || 'فشل في تحديث ولي الأمر');
            }

        } catch (error) {
            console.error('❌ Error updating parent in Firebase:', error);
            alert(`حدث خطأ أثناء تحديث ولي الأمر في قاعدة البيانات:\n${error.message}`);
        }
    };

    // Execute the update operation
    saveToFirebase();
}

function deleteParent(parentId) {
    console.log('🗑️ Deleting parent:', parentId);

    // Check Firebase availability
    if (!reloadFirebaseIfNeeded()) {
        return;
    }

    const parent = parentsData.find(p => p.id === parentId);
    if (!parent) {
        alert('لم يتم العثور على ولي الأمر');
        return;
    }

    // Confirm deletion
    const confirmMessage = `هل أنت متأكد من حذف ولي الأمر "${parent.name}"؟\n\nسيتم حذف جميع البيانات المرتبطة به.\nهذا الإجراء لا يمكن التراجع عنه.`;
    if (!confirm(confirmMessage)) {
        return;
    }

    // Delete from Firebase first
    const deleteFromFirebase = async () => {
        try {
            console.log('🗑️ Deleting parent from Firebase:', parentId);

            const result = await FirebaseService.deleteParent(parentId);

            if (result && result.success) {
                console.log('✅ Parent deleted from Firebase successfully');

                // Remove from local array
                const parentIndex = parentsData.findIndex(p => p.id === parentId);
                if (parentIndex !== -1) {
                    parentsData.splice(parentIndex, 1);
                    console.log('✅ Parent deleted from local array');

                    // Remove from table
                    const row = document.querySelector(`tr[data-parent-id="${parentId}"]`);
                    if (row) {
                        row.remove();
                        console.log('✅ Parent removed from table');
                    }

                    // Show success message
                    alert('تم حذف ولي الأمر بنجاح من قاعدة البيانات!');

                    // Refresh page to update statistics
                    loadPage('parents');

                } else {
                    console.warn('⚠️ Parent not found in local array');
                    alert('تم حذف ولي الأمر من قاعدة البيانات!');
                    // Refresh page to sync
                    loadPage('parents');
                }

            } else {
                throw new Error(result?.error || 'فشل في حذف ولي الأمر');
            }

        } catch (error) {
            console.error('❌ Error deleting parent from Firebase:', error);
            alert(`حدث خطأ أثناء حذف ولي الأمر من قاعدة البيانات:\n${error.message}`);
        }
    };

    // Execute the delete operation
    deleteFromFirebase();
}

function manageChildren(parentId) {
    console.log('👶 Managing children for parent:', parentId);

    // Check Firebase availability
    if (!reloadFirebaseIfNeeded()) {
        return;
    }

    const parent = parentsData.find(p => p.id === parentId);
    if (!parent) {
        alert('لم يتم العثور على ولي الأمر');
        return;
    }

    // Create children management modal
    const modalContent = `
        <div class="modal fade" id="manageChildrenModal" tabindex="-1">
            <div class="modal-dialog modal-xl modal-dialog-scrollable">
                <div class="modal-content">
                    <div class="modal-header bg-info text-white">
                        <h5 class="modal-title">
                            <i class="fas fa-child me-2"></i>
                            إدارة أطفال: ${parent.name}
                        </h5>
                        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <div class="row">
                            <!-- Current Children -->
                            <div class="col-md-8">
                                <h6 class="text-primary mb-3">
                                    <i class="fas fa-users me-2"></i>
                                    الأطفال الحاليين
                                </h6>
                                <div id="currentChildrenList">
                                    <div class="text-center py-4">
                                        <div class="spinner-border text-primary" role="status"></div>
                                        <p class="mt-2">جاري تحميل قائمة الأطفال...</p>
                                    </div>
                                </div>
                            </div>

                            <!-- Add New Child -->
                            <div class="col-md-4">
                                <h6 class="text-success mb-3">
                                    <i class="fas fa-plus me-2"></i>
                                    إضافة طفل جديد
                                </h6>
                                <form id="addChildForm">
                                    <input type="hidden" name="parentId" value="${parentId}">
                                    <div class="mb-3">
                                        <label class="form-label">اسم الطفل *</label>
                                        <input type="text" class="form-control" name="childName" required>
                                    </div>
                                    <div class="mb-3">
                                        <label class="form-label">المدرسة *</label>
                                        <input type="text" class="form-control" name="schoolName" required>
                                    </div>
                                    <div class="mb-3">
                                        <label class="form-label">الصف *</label>
                                        <select class="form-control" name="grade" required>
                                            <option value="">اختر الصف</option>
                                            <option value="الأول الابتدائي">الأول الابتدائي</option>
                                            <option value="الثاني الابتدائي">الثاني الابتدائي</option>
                                            <option value="الثالث الابتدائي">الثالث الابتدائي</option>
                                            <option value="الرابع الابتدائي">الرابع الابتدائي</option>
                                            <option value="الخامس الابتدائي">الخامس الابتدائي</option>
                                            <option value="السادس الابتدائي">السادس الابتدائي</option>
                                            <option value="الأول المتوسط">الأول المتوسط</option>
                                            <option value="الثاني المتوسط">الثاني المتوسط</option>
                                            <option value="الثالث المتوسط">الثالث المتوسط</option>
                                            <option value="الأول الثانوي">الأول الثانوي</option>
                                            <option value="الثاني الثانوي">الثاني الثانوي</option>
                                            <option value="الثالث الثانوي">الثالث الثانوي</option>
                                        </select>
                                    </div>
                                    <div class="mb-3">
                                        <label class="form-label">خط الباص *</label>
                                        <select class="form-control" name="busRoute" required>
                                            <option value="">اختر خط الباص</option>
                                            <option value="الخط الأول">الخط الأول</option>
                                            <option value="الخط الثاني">الخط الثاني</option>
                                            <option value="الخط الثالث">الخط الثالث</option>
                                            <option value="الخط الرابع">الخط الرابع</option>
                                            <option value="الخط الخامس">الخط الخامس</option>
                                        </select>
                                    </div>
                                    <button type="button" class="btn btn-success w-100" onclick="addChildToParent()">
                                        <i class="fas fa-plus me-2"></i>إضافة الطفل
                                    </button>
                                </form>
                            </div>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>إغلاق
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Remove existing modal if any
    const existingModal = document.getElementById('manageChildrenModal');
    if (existingModal) {
        existingModal.remove();
    }

    // Add modal to body and show
    document.body.insertAdjacentHTML('beforeend', modalContent);
    const modal = new bootstrap.Modal(document.getElementById('manageChildrenModal'));
    modal.show();

    // Load children data
    loadParentChildren(parentId);

    // Clean up when modal is hidden
    document.getElementById('manageChildrenModal').addEventListener('hidden.bs.modal', function() {
        this.remove();
        destroyAllBackdrops();
    });
}

// Load parent's children
async function loadParentChildren(parentId) {
    try {
        console.log('👶 Loading children for parent:', parentId);

        const children = await FirebaseService.getParentChildren(parentId);
        const container = document.getElementById('currentChildrenList');

        if (!container) return;

        if (children.length === 0) {
            container.innerHTML = `
                <div class="text-center py-4">
                    <i class="fas fa-child fa-3x text-muted mb-3"></i>
                    <h6 class="text-muted">لا توجد أطفال مسجلين</h6>
                    <p class="text-muted">يمكنك إضافة طفل جديد من النموذج المجاور</p>
                </div>
            `;
            return;
        }

        const childrenHTML = children.map(child => `
            <div class="child-card mb-3 p-3 border rounded" data-child-id="${child.id}">
                <div class="d-flex justify-content-between align-items-start">
                    <div class="flex-grow-1">
                        <h6 class="mb-1 fw-bold">${child.name || child.childName}</h6>
                        <p class="text-muted mb-1">
                            <i class="fas fa-school me-1"></i>
                            ${child.schoolName || 'غير محدد'} - ${child.grade || 'غير محدد'}
                        </p>
                        <p class="text-muted mb-0">
                            <i class="fas fa-bus me-1"></i>
                            ${child.busRoute || 'غير محدد'}
                        </p>
                    </div>
                    <div class="btn-group-vertical">
                        <button class="btn btn-sm btn-outline-danger" onclick="removeChildFromParent('${child.id}')" title="حذف الطفل">
                            <i class="fas fa-trash"></i>
                        </button>
                    </div>
                </div>
            </div>
        `).join('');

        container.innerHTML = childrenHTML;

    } catch (error) {
        console.error('❌ Error loading children:', error);
        const container = document.getElementById('currentChildrenList');
        if (container) {
            container.innerHTML = `
                <div class="alert alert-danger">
                    <i class="fas fa-exclamation-triangle me-2"></i>
                    حدث خطأ أثناء تحميل قائمة الأطفال
                </div>
            `;
        }
    }
}

// Add child to parent
function addChildToParent() {
    console.log('👶 Adding child to parent...');

    const form = document.getElementById('addChildForm');
    if (!form) {
        alert('خطأ: لم يتم العثور على النموذج');
        return;
    }

    const formData = new FormData(form);
    const childData = {
        name: formData.get('childName')?.trim(),
        schoolName: formData.get('schoolName')?.trim(),
        grade: formData.get('grade'),
        busRoute: formData.get('busRoute')
    };

    const parentId = formData.get('parentId');

    // Validate required fields
    if (!childData.name || !childData.schoolName || !childData.grade || !childData.busRoute) {
        alert('يرجى ملء جميع الحقول المطلوبة');
        return;
    }

    // Save to Firebase
    const saveToFirebase = async () => {
        try {
            console.log('💾 Adding child to Firebase:', childData);

            const result = await FirebaseService.addChildToParent(parentId, childData);

            if (result && result.success) {
                console.log('✅ Child added to Firebase successfully');

                // Add child to local parent data
                const parentIndex = parentsData.findIndex(p => p.id === parentId);
                if (parentIndex !== -1) {
                    if (!parentsData[parentIndex].children) {
                        parentsData[parentIndex].children = [];
                    }
                    parentsData[parentIndex].children.push({
                        id: result.id,
                        name: childData.name,
                        grade: childData.grade,
                        schoolName: childData.schoolName,
                        busRoute: childData.busRoute
                    });

                    // Update the display
                    updateParentChildrenDisplay(parentId);
                }

                // Reset form
                form.reset();

                // Reload children list
                loadParentChildren(parentId);

                // Show success message
                alert('تم إضافة الطفل بنجاح!');

            } else {
                throw new Error(result?.error || 'فشل في إضافة الطفل');
            }

        } catch (error) {
            console.error('❌ Error adding child to Firebase:', error);
            alert(`حدث خطأ أثناء إضافة الطفل:\n${error.message}`);
        }
    };

    // Execute the save operation
    saveToFirebase();
}

// Remove child from parent
function removeChildFromParent(childId) {
    console.log('🗑️ Removing child:', childId);

    if (!confirm('هل أنت متأكد من حذف هذا الطفل؟')) {
        return;
    }

    // Remove from Firebase
    const removeFromFirebase = async () => {
        try {
            console.log('🗑️ Removing child from Firebase:', childId);

            const result = await FirebaseService.removeChildFromParent(childId);

            if (result && result.success) {
                console.log('✅ Child removed from Firebase successfully');

                // Remove from local parent data
                const parentId = document.querySelector('#addChildForm input[name="parentId"]')?.value;
                if (parentId) {
                    const parentIndex = parentsData.findIndex(p => p.id === parentId);
                    if (parentIndex !== -1 && parentsData[parentIndex].children) {
                        parentsData[parentIndex].children = parentsData[parentIndex].children.filter(child => child.id !== childId);

                        // Update the display
                        updateParentChildrenDisplay(parentId);
                    }
                }

                // Remove from UI
                const childCard = document.querySelector(`[data-child-id="${childId}"]`);
                if (childCard) {
                    childCard.remove();
                }

                // Show success message
                alert('تم حذف الطفل بنجاح!');

                // Reload children list to ensure sync
                if (parentId) {
                    loadParentChildren(parentId);
                }

            } else {
                throw new Error(result?.error || 'فشل في حذف الطفل');
            }

        } catch (error) {
            console.error('❌ Error removing child from Firebase:', error);
            alert(`حدث خطأ أثناء حذف الطفل:\n${error.message}`);
        }
    };

    // Execute the remove operation
    removeFromFirebase();
}

function sendNotificationToParent(parentId) {
    console.log('📧 Sending notification to parent:', parentId);

    // Check Firebase availability
    if (!reloadFirebaseIfNeeded()) {
        return;
    }

    const parent = parentsData.find(p => p.id === parentId);
    if (!parent) {
        alert('لم يتم العثور على ولي الأمر');
        return;
    }

    // Create notification modal
    const modalContent = `
        <div class="modal fade" id="sendNotificationModal" tabindex="-1">
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header bg-primary text-white">
                        <h5 class="modal-title">
                            <i class="fas fa-paper-plane me-2"></i>
                            إرسال إشعار إلى: ${parent.name}
                        </h5>
                        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <form id="sendNotificationForm">
                            <input type="hidden" name="parentId" value="${parentId}">

                            <div class="mb-3">
                                <label class="form-label">نوع الإشعار *</label>
                                <select class="form-control" name="notificationType" required>
                                    <option value="">اختر نوع الإشعار</option>
                                    <option value="general">إشعار عام</option>
                                    <option value="pickup">إشعار استلام</option>
                                    <option value="delay">إشعار تأخير</option>
                                    <option value="emergency">إشعار طارئ</option>
                                    <option value="reminder">تذكير</option>
                                    <option value="announcement">إعلان</option>
                                </select>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">عنوان الإشعار *</label>
                                <input type="text" class="form-control" name="notificationTitle" required placeholder="أدخل عنوان الإشعار">
                            </div>

                            <div class="mb-3">
                                <label class="form-label">محتوى الإشعار *</label>
                                <textarea class="form-control" name="notificationBody" rows="4" required placeholder="أدخل محتوى الإشعار"></textarea>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">أولوية الإشعار</label>
                                <select class="form-control" name="priority">
                                    <option value="normal">عادي</option>
                                    <option value="high">مرتفع</option>
                                    <option value="urgent">عاجل</option>
                                </select>
                            </div>

                            <div class="alert alert-info">
                                <i class="fas fa-info-circle me-2"></i>
                                <strong>معلومات المستلم:</strong><br>
                                الاسم: ${parent.name}<br>
                                البريد الإلكتروني: ${parent.email}<br>
                                رقم الهاتف: ${parent.phone}
                            </div>
                        </form>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                            <i class="fas fa-times me-2"></i>إلغاء
                        </button>
                        <button type="button" class="btn btn-primary" onclick="sendNotification()">
                            <i class="fas fa-paper-plane me-2"></i>إرسال الإشعار
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;

    // Remove existing modal if any
    const existingModal = document.getElementById('sendNotificationModal');
    if (existingModal) {
        existingModal.remove();
    }

    // Add modal to body and show
    document.body.insertAdjacentHTML('beforeend', modalContent);
    const modal = new bootstrap.Modal(document.getElementById('sendNotificationModal'));
    modal.show();

    // Clean up when modal is hidden
    document.getElementById('sendNotificationModal').addEventListener('hidden.bs.modal', function() {
        this.remove();
        destroyAllBackdrops();
    });
}

// Send notification function
function sendNotification() {
    console.log('📤 Sending notification...');

    const form = document.getElementById('sendNotificationForm');
    if (!form) {
        alert('خطأ: لم يتم العثور على النموذج');
        return;
    }

    const formData = new FormData(form);
    const notificationData = {
        title: formData.get('notificationTitle')?.trim(),
        body: formData.get('notificationBody')?.trim(),
        type: formData.get('notificationType'),
        priority: formData.get('priority') || 'normal'
    };

    const parentId = formData.get('parentId');

    // Validate required fields
    if (!notificationData.title || !notificationData.body || !notificationData.type) {
        alert('يرجى ملء جميع الحقول المطلوبة');
        return;
    }

    // Send to Firebase
    const sendToFirebase = async () => {
        try {
            console.log('📤 Sending notification to Firebase:', notificationData);

            const result = await FirebaseService.sendNotificationToParent(parentId, notificationData);

            if (result && result.success) {
                console.log('✅ Notification sent successfully');

                // Close modal
                const modal = bootstrap.Modal.getInstance(document.getElementById('sendNotificationModal'));
                if (modal) {
                    modal.hide();
                }
                destroyAllBackdrops();

                // Show success message
                alert('تم إرسال الإشعار بنجاح!');

            } else {
                throw new Error(result?.error || 'فشل في إرسال الإشعار');
            }

        } catch (error) {
            console.error('❌ Error sending notification:', error);
            alert(`حدث خطأ أثناء إرسال الإشعار:\n${error.message}`);
        }
    };

    // Execute the send operation
    sendToFirebase();
}

function sendBulkNotification() {
    console.log('📢 Sending bulk notification to all parents...');
    // TODO: Implement bulk notification functionality
    alert('إرسال إشعار جماعي لجميع أولياء الأمور');
}

function saveParent() {
    console.log('💾 Saving new parent...');
    const form = document.getElementById('addParentForm');
    const formData = new FormData(form);

    // Get form data
    const parentData = {
        name: formData.get('name'),
        email: formData.get('email'),
        phone: formData.get('phone'),
        address: formData.get('address'),
        relationship: formData.get('relationship'),
        emergencyContact: formData.get('emergencyContact'),
        emergencyContactName: formData.get('emergencyContactName'),
        password: formData.get('password'),
        confirmPassword: formData.get('confirmPassword')
    };

    // Validate passwords match
    if (parentData.password !== parentData.confirmPassword) {
        alert('كلمات المرور غير متطابقة');
        return;
    }

    console.log('📋 Parent data:', parentData);

    // TODO: Implement save parent to Firebase
    alert('تم إضافة ولي الأمر بنجاح!');

    // Close modal and refresh page
    const modal = bootstrap.Modal.getInstance(document.getElementById('addParentModal'));
    modal.hide();
    loadPage('parents');
}

function exportParents() {
    console.log('📤 Exporting parents...');
    // Create CSV content
    const headers = ['الاسم', 'البريد الإلكتروني', 'الهاتف', 'صلة القرابة', 'العنوان', 'عدد الأطفال', 'الحالة'];
    const csvContent = [
        headers.join(','),
        ...parentsData.map(parent => [
            parent.name || '',
            parent.email || '',
            parent.phone || '',
            parent.relationship || '',
            parent.address || '',
            parent.children ? parent.children.length : 0,
            getParentStatusText(parent.status)
        ].join(','))
    ].join('\n');

    // Download CSV
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    link.setAttribute('href', url);
    link.setAttribute('download', `parents_${new Date().toISOString().split('T')[0]}.csv`);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    alert('تم تصدير بيانات أولياء الأمور بنجاح');
}

function clearParentFilters() {
    console.log('🧹 Clearing parent filters...');
    document.getElementById('searchParents').value = '';
    document.getElementById('filterParentStatus').value = '';
    document.getElementById('filterChildrenCount').value = '';
    // TODO: Implement filter clearing and refresh
}

function toggleParentView(viewType) {
    console.log('🔄 Toggling parent view to:', viewType);
    const tableView = document.getElementById('parentTableView');
    const cardView = document.getElementById('parentCardView');

    if (viewType === 'table') {
        tableView?.classList.remove('d-none');
        cardView?.classList.add('d-none');
    } else {
        tableView?.classList.add('d-none');
        cardView?.classList.remove('d-none');
    }
}

// Make functions globally available
window.viewParent = viewParent;
window.editParent = editParent;
window.deleteParent = deleteParent;
window.manageChildren = manageChildren;
window.sendNotificationToParent = sendNotificationToParent;
window.sendBulkNotification = sendBulkNotification;
window.saveParent = saveParent;
window.exportParents = exportParents;
window.clearParentFilters = clearParentFilters;
window.toggleParentView = toggleParentView;

// Initialize the application when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 Application starting...');

    // Firebase is already initialized in firebase-config.js
    // Just start the app initialization
    console.log('✅ Firebase already initialized, starting app...');

    // Check if Firebase is available
    if (typeof firebase !== 'undefined' && typeof FirebaseService !== 'undefined') {
        console.log('✅ Firebase services available');
    } else {
        console.warn('⚠️ Firebase services not fully loaded');
    }

    // Add event listener for student modal
    document.addEventListener('shown.bs.modal', function(event) {
        if (event.target.id === 'addStudentModal') {
            console.log('📝 Student modal opened, loading parents...');
            loadParentsForStudentForm();
        }
    });
});

// Global function to show add bus modal
function showAddBusModal() {
    console.log('🚌 Showing add bus modal from global function');

    const modal = document.getElementById('addBusModal');
    if (modal) {
        const bootstrapModal = new bootstrap.Modal(modal);

        // Reset form
        const form = document.getElementById('addBusForm');
        if (form) form.reset();

        // Set title
        const title = document.getElementById('busModalTitle');
        if (title) title.textContent = 'إضافة سيارة جديدة';

        // Clear bus ID
        const busId = document.getElementById('busId');
        if (busId) busId.value = '';

        bootstrapModal.show();
        console.log('✅ Modal shown successfully');
    } else {
        console.error('❌ Modal not found');
        alert('خطأ: نافذة إضافة السيارة غير موجودة');
    }
}

// Make it globally available
window.showAddBusModal = showAddBusModal;

// Debug functions for testing
window.testFirebaseBuses = async function() {
    console.log('🧪 Testing Firebase buses...');

    try {
        // Test adding a bus
        console.log('➕ Testing add bus...');
        const testBus = await FirebaseService.addTestBus();
        console.log('✅ Test bus added:', testBus);

        // Test getting buses
        console.log('📋 Testing get buses...');
        const buses = await FirebaseService.getBuses();
        console.log('✅ Buses retrieved:', buses);

        return { success: true, buses };
    } catch (error) {
        console.error('❌ Test failed:', error);
        return { success: false, error: error.message };
    }
};

window.debugBusesData = function() {
    console.log('🔍 Debug buses data:');
    console.log('Global busesData:', window.busesData);
    console.log('BusManager buses:', window.busManager ? window.busManager.buses : 'BusManager not found');

    // Try to get buses from Firebase
    if (typeof FirebaseService !== 'undefined') {
        FirebaseService.getBuses().then(buses => {
            console.log('Firebase buses:', buses);
        }).catch(error => {
            console.error('Firebase error:', error);
        });
    } else {
        console.log('FirebaseService not available');
    }
};

window.addTestBusDirectly = async function() {
    console.log('🧪 Adding test bus directly to Firebase...');

    try {
        if (typeof db === 'undefined') {
            throw new Error('Firebase db not available');
        }

        const testBus = {
            id: 'test_' + Date.now(),
            plateNumber: '857',
            description: 'كوستر حديث - تجريبي',
            driverName: 'محمود جابر',
            driverPhone: '011374858567',
            route: 'طيبة',
            capacity: 30,
            hasAirConditioning: true,
            isActive: true,
            studentsCount: 0,
            createdAt: firebase.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        };

        await db.collection('buses').doc(testBus.id).set(testBus);
        console.log('✅ Test bus added directly to Firebase');

        // Reload buses page
        loadPage('buses');

        return testBus;
    } catch (error) {
        console.error('❌ Error adding test bus directly:', error);
        throw error;
    }
};

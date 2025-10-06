import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/database_service.dart';
import '../../services/enhanced_notification_service.dart';
import '../../models/bus_model.dart';
import '../../widgets/admin_bottom_navigation.dart';
import '../../widgets/admin_bottom_navigation.dart';

// Enum for sorting options
enum BusSortingOption {
  plateNumber,
  driverName,
  route,
  capacity,
  activeFirst,
  inactiveFirst,
  createdDate
}

extension BusSortingOptionExtension on BusSortingOption {
  String get displayName {
    switch (this) {
      case BusSortingOption.plateNumber:
        return 'رقم اللوحة';
      case BusSortingOption.driverName:
        return 'اسم السائق';
      case BusSortingOption.route:
        return 'خط السير';
      case BusSortingOption.capacity:
        return 'السعة';
      case BusSortingOption.activeFirst:
        return 'النشط أولاً';
      case BusSortingOption.inactiveFirst:
        return 'المتوقف أولاً';
      case BusSortingOption.createdDate:
        return 'تاريخ الإنشاء';
    }
  }

  IconData get icon {
    switch (this) {
      case BusSortingOption.plateNumber:
        return Icons.confirmation_number;
      case BusSortingOption.driverName:
        return Icons.person;
      case BusSortingOption.route:
        return Icons.route;
      case BusSortingOption.capacity:
        return Icons.people;
      case BusSortingOption.activeFirst:
        return Icons.check_circle;
      case BusSortingOption.inactiveFirst:
        return Icons.pause_circle;
      case BusSortingOption.createdDate:
        return Icons.date_range;
    }
  }
}

class BusesManagementScreen extends StatefulWidget {
  const BusesManagementScreen({super.key});

  @override
  State<BusesManagementScreen> createState() => _BusesManagementScreenState();
}

class _BusesManagementScreenState extends State<BusesManagementScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final EnhancedNotificationService _notificationService = EnhancedNotificationService();
  String _searchQuery = '';
  BusSortingOption _currentSortOption = BusSortingOption.plateNumber;
  bool _isAscending = true;
  bool _showActiveOnly = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller for card fade-in
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsiveness
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Light modern background
      appBar: AppBar(
        title: Text(
          'إدارة السيارات',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20 * textScaleFactor,
          ),
        ),
        backgroundColor: const Color(0xFF1E88E5), // Modern blue
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort, size: 28),
            onPressed: _showSortingOptions,
            tooltip: 'خيارات الترتيب',
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 28),
            onPressed: _showAddBusDialog,
            tooltip: 'إضافة سيارة جديدة',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'البحث عن سيارة...',
                    hintStyle: GoogleFonts.cairo(
                      color: Colors.grey[600],
                      fontSize: 16 * textScaleFactor,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF1E88E5)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  style: GoogleFonts.cairo(fontSize: 16 * textScaleFactor),
                ),
                SizedBox(height: screenHeight * 0.015),
                // Current Sort Display and Filter
                Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.03,
                          vertical: screenHeight * 0.01,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF1E88E5).withOpacity(0.1), const Color(0xFF42A5F5).withOpacity(0.1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _currentSortOption.icon,
                              size: 18 * textScaleFactor,
                              color: const Color(0xFF1E88E5),
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Text(
                              'مرتب حسب: ${_currentSortOption.displayName}',
                              style: GoogleFonts.cairo(
                                fontSize: 12 * textScaleFactor,
                                color: const Color(0xFF1E88E5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.01),
                            Icon(
                              _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 12 * textScaleFactor,
                              color: const Color(0xFF1E88E5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    // Active Filter Toggle
                    FilterChip(
                      label: Text(
                        'النشط فقط',
                        style: GoogleFonts.cairo(
                          fontSize: 12 * textScaleFactor,
                          color: _showActiveOnly ? Colors.white : const Color(0xFF1E88E5),
                        ),
                      ),
                      selected: _showActiveOnly,
                      onSelected: (selected) {
                        setState(() {
                          _showActiveOnly = selected;
                        });
                      },
                      selectedColor: const Color(0xFF1E88E5),
                      checkmarkColor: Colors.white,
                      backgroundColor: Colors.grey[100],
                      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Buses List
          Expanded(
            child: StreamBuilder<List<BusModel>>(
              stream: _databaseService.getAllBuses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1E88E5)));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64 * textScaleFactor, color: Colors.red),
                        SizedBox(height: screenHeight * 0.02),
                        Text(
                          'خطأ في تحميل السيارات: ${snapshot.error}',
                          style: GoogleFonts.cairo(
                            fontSize: 16 * textScaleFactor,
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                List<BusModel> buses = snapshot.data ?? [];
                // Apply active filter
                if (_showActiveOnly) {
                  buses = buses.where((bus) => bus.isActive).toList();
                }
                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  buses = buses.where((bus) {
                    final query = _searchQuery.toLowerCase();
                    return bus.plateNumber.toLowerCase().contains(query) ||
                           bus.driverName.toLowerCase().contains(query) ||
                           bus.route.toLowerCase().contains(query) ||
                           bus.description.toLowerCase().contains(query) ||
                           bus.driverPhone.toLowerCase().contains(query);
                  }).toList();
                }
                // Apply sorting
                buses = _sortBuses(buses);
                if (buses.isEmpty) {
                  return _buildEmptyState(screenWidth, screenHeight, textScaleFactor);
                }
                return ListView.builder(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  itemCount: buses.length,
                  itemBuilder: (context, index) {
                    final bus = buses[index];
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildBusCard(bus, index + 1, screenWidth, screenHeight, textScaleFactor),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AdminBottomNavigation(
        currentIndex: 2, // الحافلات
      ),
    );
  }

  Widget _buildEmptyState(double screenWidth, double screenHeight, double textScaleFactor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_bus_outlined,
            size: 80 * textScaleFactor,
            color: Colors.grey[400],
          ),
          SizedBox(height: screenHeight * 0.02),
          Text(
            _searchQuery.isEmpty ? 'لا توجد سيارات مسجلة' : 'لا توجد نتائج للبحث',
            style: GoogleFonts.cairo(
              fontSize: 18 * textScaleFactor,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: screenHeight * 0.01),
          Text(
            'اضغط على + لإضافة سيارة جديدة',
            style: GoogleFonts.cairo(
              fontSize: 14 * textScaleFactor,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  List<BusModel> _sortBuses(List<BusModel> buses) {
    buses.sort((a, b) {
      int comparison = 0;
      switch (_currentSortOption) {
        case BusSortingOption.plateNumber:
          comparison = _compareStringsNaturally(a.plateNumber, b.plateNumber);
          break;
        case BusSortingOption.driverName:
          comparison = a.driverName.compareTo(b.driverName);
          break;
        case BusSortingOption.route:
          comparison = a.route.compareTo(b.route);
          break;
        case BusSortingOption.capacity:
          comparison = a.capacity.compareTo(b.capacity);
          break;
        case BusSortingOption.activeFirst:
          comparison = b.isActive.toString().compareTo(a.isActive.toString());
          break;
        case BusSortingOption.inactiveFirst:
          comparison = a.isActive.toString().compareTo(b.isActive.toString());
          break;
        case BusSortingOption.createdDate:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
      }
      return _isAscending ? comparison : -comparison;
    });
    return buses;
  }

  int _compareStringsNaturally(String a, String b) {
    final RegExp numberRegex = RegExp(r'\d+');
    final aNumbers = numberRegex.allMatches(a).map((m) => int.tryParse(m.group(0)!) ?? 0).toList();
    final bNumbers = numberRegex.allMatches(b).map((m) => int.tryParse(m.group(0)!) ?? 0).toList();
    if (aNumbers.isNotEmpty && bNumbers.isNotEmpty) {
      for (int i = 0; i < aNumbers.length && i < bNumbers.length; i++) {
        if (aNumbers[i] != bNumbers[i]) {
          return aNumbers[i].compareTo(bNumbers[i]);
        }
      }
    }
    return a.compareTo(b);
  }

  Widget _buildBusCard(BusModel bus, int index, double screenWidth, double screenHeight, double textScaleFactor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: screenHeight * 0.02),
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: !bus.isActive
            ? Border.all(color: Colors.red.withOpacity(0.3), width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32 * textScaleFactor,
                height: 32 * textScaleFactor,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14 * textScaleFactor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.03),
              Container(
                padding: EdgeInsets.all(screenWidth * 0.02),
                decoration: BoxDecoration(
                  color: bus.isActive
                      ? const Color(0xFF1E88E5).withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.directions_bus,
                  color: bus.isActive ? const Color(0xFF1E88E5) : Colors.red,
                  size: 20 * textScaleFactor,
                ),
              ),
              SizedBox(width: screenWidth * 0.03),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bus.plateNumber,
                      style: GoogleFonts.cairo(
                        fontSize: 18 * textScaleFactor,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A2027),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.005),
                    Text(
                      bus.route,
                      style: GoogleFonts.cairo(
                        fontSize: 14 * textScaleFactor,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.02,
                  vertical: screenHeight * 0.005,
                ),
                decoration: BoxDecoration(
                  color: bus.isActive
                      ? const Color(0xFF1E88E5).withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  bus.isActive ? 'نشط' : 'غير نشط',
                  style: GoogleFonts.cairo(
                    fontSize: 12 * textScaleFactor,
                    color: bus.isActive ? const Color(0xFF1E88E5) : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.02),
          // Bus Details
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  icon: Icons.person,
                  label: 'السائق',
                  value: bus.driverName,
                  screenWidth: screenWidth,
                  textScaleFactor: textScaleFactor,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  icon: Icons.phone,
                  label: 'الهاتف',
                  value: bus.driverPhone,
                  screenWidth: screenWidth,
                  textScaleFactor: textScaleFactor,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.015),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  icon: Icons.badge,
                  label: 'الرقم القومي',
                  value: bus.driverNationalId.isNotEmpty ? bus.driverNationalId : 'غير محدد',
                  screenWidth: screenWidth,
                  textScaleFactor: textScaleFactor,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  icon: Icons.people,
                  label: 'السعة',
                  value: '${bus.capacity} طالب',
                  screenWidth: screenWidth,
                  textScaleFactor: textScaleFactor,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.015),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  icon: Icons.ac_unit,
                  label: 'التكييف',
                  value: bus.hasAirConditioning ? 'متوفر' : 'غير متوفر',
                  screenWidth: screenWidth,
                  textScaleFactor: textScaleFactor,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  icon: Icons.directions_bus,
                  label: 'نوع الباص',
                  value: bus.description.isNotEmpty ? bus.description : 'لا يوجد',
                  screenWidth: screenWidth,
                  textScaleFactor: textScaleFactor,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.02),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.edit,
                  label: 'تعديل',
                  color: const Color(0xFF1E88E5),
                  onPressed: () => _showEditBusDialog(bus),
                  screenWidth: screenWidth,
                  textScaleFactor: textScaleFactor,
                ),
              ),
              SizedBox(width: screenWidth * 0.02),
              Expanded(
                child: _buildActionButton(
                  icon: bus.isActive ? Icons.pause : Icons.play_arrow,
                  label: bus.isActive ? 'إيقاف' : 'تفعيل',
                  color: bus.isActive ? Colors.orange : const Color(0xFF1E88E5),
                  onPressed: () => _toggleBusStatus(bus),
                  screenWidth: screenWidth,
                  textScaleFactor: textScaleFactor,
                ),
              ),
              SizedBox(width: screenWidth * 0.02),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.delete,
                  label: 'حذف',
                  color: Colors.red,
                  onPressed: () => _showDeleteConfirmation(bus),
                  screenWidth: screenWidth,
                  textScaleFactor: textScaleFactor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required double screenWidth,
    required double textScaleFactor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16 * textScaleFactor, color: Colors.grey[600]),
        SizedBox(width: screenWidth * 0.015),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12 * textScaleFactor,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.cairo(
                  fontSize: 14 * textScaleFactor,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1A2027),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required double screenWidth,
    required double textScaleFactor,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: screenWidth * 0.025),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16 * textScaleFactor, color: Colors.white),
            SizedBox(width: screenWidth * 0.01),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 12 * textScaleFactor,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortingOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            final textScaleFactor = MediaQuery.of(context).textScaleFactor;
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.sort, color: Color(0xFF1E88E5)),
                        SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                        Text(
                          'خيارات الترتيب',
                          style: GoogleFonts.cairo(
                            fontSize: 20 * textScaleFactor,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A2027),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    // Sorting Options
                    Text(
                      'ترتيب حسب:',
                      style: GoogleFonts.cairo(
                        fontSize: 16 * textScaleFactor,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A2027),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.015),
                    ...BusSortingOption.values.map((option) => ListTile(
                          leading: Icon(
                            option.icon,
                            color: _currentSortOption == option
                                ? const Color(0xFF1E88E5)
                                : Colors.grey[600],
                            size: 20 * textScaleFactor,
                          ),
                          title: Text(
                            option.displayName,
                            style: GoogleFonts.cairo(
                              color: _currentSortOption == option
                                  ? const Color(0xFF1E88E5)
                                  : const Color(0xFF1A2027),
                              fontSize: 16 * textScaleFactor,
                              fontWeight: _currentSortOption == option
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: _currentSortOption == option
                              ? const Icon(
                                  Icons.check,
                                  color: Color(0xFF1E88E5),
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _currentSortOption = option;
                            });
                            Navigator.of(context).pop();
                          },
                        )),
                    const Divider(),
                    // Sort Direction
                    Text(
                      'اتجاه الترتيب:',
                      style: GoogleFonts.cairo(
                        fontSize: 16 * textScaleFactor,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A2027),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            leading: Icon(
                              Icons.arrow_upward,
                              color: _isAscending
                                  ? const Color(0xFF1E88E5)
                                  : Colors.grey[600],
                              size: 20 * textScaleFactor,
                            ),
                            title: Text(
                              'تصاعدي',
                              style: GoogleFonts.cairo(
                                color: _isAscending
                                    ? const Color(0xFF1E88E5)
                                    : const Color(0xFF1A2027),
                                fontSize: 16 * textScaleFactor,
                                fontWeight: _isAscending
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: _isAscending
                                ? const Icon(
                                    Icons.check,
                                    color: Color(0xFF1E88E5),
                                  )
                                : null,
                            onTap: () {
                              setState(() {
                                _isAscending = true;
                              });
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            leading: Icon(
                              Icons.arrow_downward,
                              color: !_isAscending
                                  ? const Color(0xFF1E88E5)
                                  : Colors.grey[600],
                              size: 20 * textScaleFactor,
                            ),
                            title: Text(
                              'تنازلي',
                              style: GoogleFonts.cairo(
                                color: !_isAscending
                                    ? const Color(0xFF1E88E5)
                                    : const Color(0xFF1A2027),
                                fontSize: 16 * textScaleFactor,
                                fontWeight: !_isAscending
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: !_isAscending
                                ? const Icon(
                                    Icons.check,
                                    color: Color(0xFF1E88E5),
                                  )
                                : null,
                            onTap: () {
                              setState(() {
                                _isAscending = false;
                              });
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAddBusDialog() {
    _showBusDialog();
  }

  void _showEditBusDialog(BusModel bus) {
    _showBusDialog(bus: bus);
  }

  void _showBusDialog({BusModel? bus}) {
    final isEditing = bus != null;
    final plateNumberController = TextEditingController(text: bus?.plateNumber ?? '');
    final descriptionController = TextEditingController(text: bus?.description ?? '');
    final driverNameController = TextEditingController(text: bus?.driverName ?? '');
    final driverPhoneController = TextEditingController(text: bus?.driverPhone ?? '');
    final driverNationalIdController = TextEditingController(text: bus?.driverNationalId ?? '');
    final routeController = TextEditingController(text: bus?.route ?? '');
    final capacityController = TextEditingController(text: bus?.capacity.toString() ?? '30');
    bool hasAirConditioning = bus?.hasAirConditioning ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isEditing ? 'تعديل السيارة' : 'إضافة سيارة جديدة',
            style: GoogleFonts.cairo(
              fontSize: 20 * MediaQuery.of(context).textScaleFactor,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A2027),
            ),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTextField(
                    controller: plateNumberController,
                    label: 'رقم اللوحة',
                    icon: Icons.confirmation_number,
                    textScaleFactor: MediaQuery.of(context).textScaleFactor,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildDialogTextField(
                    controller: routeController,
                    label: 'خط السير',
                    icon: Icons.route,
                    textScaleFactor: MediaQuery.of(context).textScaleFactor,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildDialogTextField(
                    controller: driverNameController,
                    label: 'اسم السائق',
                    icon: Icons.person,
                    textScaleFactor: MediaQuery.of(context).textScaleFactor,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildDialogTextField(
                    controller: driverPhoneController,
                    label: 'هاتف السائق',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    textScaleFactor: MediaQuery.of(context).textScaleFactor,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildDialogTextField(
                    controller: driverNationalIdController,
                    label: 'الرقم القومي للسائق',
                    icon: Icons.badge,
                    keyboardType: TextInputType.number,
                    textScaleFactor: MediaQuery.of(context).textScaleFactor,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildDialogTextField(
                    controller: capacityController,
                    label: 'سعة السيارة',
                    icon: Icons.people,
                    keyboardType: TextInputType.number,
                    textScaleFactor: MediaQuery.of(context).textScaleFactor,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  _buildDialogTextField(
                    controller: descriptionController,
                    label: 'نوع الباص (اختياري)',
                    icon: Icons.directions_bus,
                    maxLines: 2,
                    textScaleFactor: MediaQuery.of(context).textScaleFactor,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  CheckboxListTile(
                    title: Text(
                      'يوجد تكييف',
                      style: GoogleFonts.cairo(
                        fontSize: 16 * MediaQuery.of(context).textScaleFactor,
                        color: const Color(0xFF1A2027),
                      ),
                    ),
                    value: hasAirConditioning,
                    onChanged: (value) {
                      setState(() {
                        hasAirConditioning = value ?? false;
                      });
                    },
                    activeColor: const Color(0xFF1E88E5),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(
                  fontSize: 16 * MediaQuery.of(context).textScaleFactor,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await _saveBus(
                  context: context,
                  isEditing: isEditing,
                  busId: bus?.id,
                  plateNumber: plateNumberController.text,
                  description: descriptionController.text,
                  driverName: driverNameController.text,
                  driverPhone: driverPhoneController.text,
                  driverNationalId: driverNationalIdController.text,
                  route: routeController.text,
                  capacity: int.tryParse(capacityController.text) ?? 30,
                  hasAirConditioning: hasAirConditioning,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.04,
                  vertical: MediaQuery.of(context).size.height * 0.015,
                ),
              ),
              child: Text(
                isEditing ? 'حفظ التعديلات' : 'إضافة السيارة',
                style: GoogleFonts.cairo(
                  fontSize: 16 * MediaQuery.of(context).textScaleFactor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    required double textScaleFactor,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.cairo(
          fontSize: 14 * textScaleFactor,
          color: Colors.grey[600],
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF1E88E5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E88E5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      style: GoogleFonts.cairo(fontSize: 16 * textScaleFactor),
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }

  Future<void> _saveBus({
    required BuildContext context,
    required bool isEditing,
    String? busId,
    required String plateNumber,
    required String description,
    required String driverName,
    required String driverPhone,
    required String driverNationalId,
    required String route,
    required int capacity,
    required bool hasAirConditioning,
  }) async {
    if (plateNumber.trim().isEmpty ||
        driverName.trim().isEmpty ||
        route.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'يرجى ملء جميع الحقول المطلوبة',
              style: GoogleFonts.cairo(fontSize: 14 * MediaQuery.of(context).textScaleFactor),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      if (isEditing && busId != null) {
        final existingBus = await _databaseService.getBus(busId);
        if (existingBus != null) {
          final updatedBus = existingBus.copyWith(
            plateNumber: plateNumber.trim(),
            description: description.trim(),
            driverName: driverName.trim(),
            driverPhone: driverPhone.trim(),
            driverNationalId: driverNationalId.trim(),
            route: route.trim(),
            capacity: capacity,
            hasAirConditioning: hasAirConditioning,
            updatedAt: DateTime.now(),
          );
          await _databaseService.updateBus(updatedBus);
        }
      } else {
        final newBus = BusModel(
          id: _databaseService.generateTripId(),
          plateNumber: plateNumber.trim(),
          description: description.trim(),
          driverName: driverName.trim(),
          driverPhone: driverPhone.trim(),
          driverNationalId: driverNationalId.trim(),
          route: route.trim(),
          capacity: capacity,
          hasAirConditioning: hasAirConditioning,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _databaseService.addBus(newBus);
      }

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing ? 'تم تحديث السيارة بنجاح' : 'تم إضافة السيارة بنجاح',
              style: GoogleFonts.cairo(fontSize: 14 * MediaQuery.of(context).textScaleFactor),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving bus: $e');
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ في حفظ السيارة: $e',
              style: GoogleFonts.cairo(fontSize: 14 * MediaQuery.of(context).textScaleFactor),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleBusStatus(BusModel bus) async {
    final confirmed = await _showBusStatusConfirmation(bus);
    if (!confirmed) return;

    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF1E88E5)),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    Text(
                      'جاري تحديث حالة السيارة...',
                      style: GoogleFonts.cairo(
                        fontSize: 16 * MediaQuery.of(context).textScaleFactor,
                        color: const Color(0xFF1A2027),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final newStatus = !bus.isActive;
      final updatedBus = bus.copyWith(
        isActive: newStatus,
        updatedAt: DateTime.now(),
      );
      await _databaseService.updateBus(updatedBus);

      if (newStatus) {
        await _handleBusActivation(bus);
      } else {
        await _handleBusDeactivation(bus);
      }

      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newStatus ? Icons.check_circle : Icons.pause_circle,
                  color: Colors.white,
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                Text(
                  newStatus ? 'تم تفعيل السيارة بنجاح' : 'تم إيقاف السيارة بنجاح',
                  style: GoogleFonts.cairo(fontSize: 14 * MediaQuery.of(context).textScaleFactor),
                ),
              ],
            ),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ في تغيير حالة السيارة: $e',
              style: GoogleFonts.cairo(fontSize: 14 * MediaQuery.of(context).textScaleFactor),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showBusStatusConfirmation(BusModel bus) async {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              bus.isActive ? Icons.pause_circle : Icons.play_circle,
              color: bus.isActive ? Colors.orange : Colors.green,
            ),
            SizedBox(width: MediaQuery.of(context).size.width * 0.02),
            Text(
              bus.isActive ? 'إيقاف السيارة' : 'تفعيل السيارة',
              style: GoogleFonts.cairo(
                fontSize: 20 * textScaleFactor,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A2027),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'السيارة: ${bus.plateNumber}',
                style: GoogleFonts.cairo(
                  fontSize: 16 * textScaleFactor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
              Text(
                'السائق: ${bus.driverName}',
                style: GoogleFonts.cairo(
                  fontSize: 14 * textScaleFactor,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.02),
              if (bus.isActive) ...[
                Text(
                  '⚠️ عند إيقاف السيارة سيتم:',
                  style: GoogleFonts.cairo(
                    fontSize: 16 * textScaleFactor,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                Text(
                  '• منع تسكين طلاب جدد في هذه السيارة\n• إشعار المشرف المعين للسيارة\n• إشعار أولياء أمور الطلاب المسكنين\n• إيقاف عمليات المسح والرحلات',
                  style: GoogleFonts.cairo(fontSize: 14 * textScaleFactor),
                ),
              ] else ...[
                Text(
                  '✅ عند تفعيل السيارة سيتم:',
                  style: GoogleFonts.cairo(
                    fontSize: 16 * textScaleFactor,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                Text(
                  '• السماح بتسكين طلاب جدد\n• إشعار المشرف بإعادة التفعيل\n• تفعيل عمليات المسح والرحلات',
                  style: GoogleFonts.cairo(fontSize: 14 * textScaleFactor),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(
                fontSize: 16 * textScaleFactor,
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: bus.isActive ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.04,
                vertical: MediaQuery.of(context).size.height * 0.015,
              ),
            ),
            child: Text(
              bus.isActive ? 'إيقاف السيارة' : 'تفعيل السيارة',
              style: GoogleFonts.cairo(
                fontSize: 16 * textScaleFactor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleBusActivation(BusModel bus) async {
    try {
      await _sendBusActivationNotifications(bus);
      debugPrint('✅ Bus activation notifications sent for: ${bus.plateNumber}');
    } catch (e) {
      debugPrint('❌ Error handling bus activation: $e');
    }
  }

  Future<void> _handleBusDeactivation(BusModel bus) async {
    try {
      await _sendBusDeactivationNotifications(bus);
      debugPrint('✅ Bus deactivation notifications sent for: ${bus.plateNumber}');
    } catch (e) {
      debugPrint('❌ Error handling bus deactivation: $e');
    }
  }

  Future<void> _sendBusActivationNotifications(BusModel bus) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .get();
      final adminName = adminDoc.data()?['name'] ?? 'الإدارة';

      await _notificationService.notifyBusActivation(
        busId: bus.id,
        busPlateNumber: bus.plateNumber,
        driverName: bus.driverName,
        adminName: adminName,
        adminId: currentUser?.uid,
      );

      debugPrint('✅ Bus activation notifications sent for: ${bus.plateNumber}');
    } catch (e) {
      debugPrint('❌ Error sending bus activation notifications: $e');
    }
  }

  Future<void> _sendBusDeactivationNotifications(BusModel bus) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .get();
      final adminName = adminDoc.data()?['name'] ?? 'الإدارة';

      await _notificationService.notifyBusDeactivation(
        busId: bus.id,
        busPlateNumber: bus.plateNumber,
        driverName: bus.driverName,
        adminName: adminName,
        adminId: currentUser?.uid,
      );

      debugPrint('✅ Bus deactivation notifications sent for: ${bus.plateNumber}');
    } catch (e) {
      debugPrint('❌ Error sending bus deactivation notifications: $e');
    }
  }

  Future<void> _showDeleteConfirmation(BusModel bus) async {
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('students')
        .where('busId', isEqualTo: bus.id)
        .where('isActive', isEqualTo: true)
        .get();

    final studentsCount = studentsSnapshot.docs.length;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;

    if (mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red),
              SizedBox(width: MediaQuery.of(context).size.width * 0.02),
              Text(
                'تأكيد حذف السيارة',
                style: GoogleFonts.cairo(
                  fontSize: 20 * textScaleFactor,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A2027),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'السيارة: ${bus.plateNumber}',
                  style: GoogleFonts.cairo(
                    fontSize: 16 * textScaleFactor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                Text(
                  'السائق: ${bus.driverName}',
                  style: GoogleFonts.cairo(
                    fontSize: 14 * textScaleFactor,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                if (studentsCount > 0) ...[
                  Container(
                    padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange.shade700, size: 20 * textScaleFactor),
                            SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                            Text(
                              'تنبيه مهم',
                              style: GoogleFonts.cairo(
                                fontSize: 16 * textScaleFactor,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                        Text(
                          'هناك $studentsCount طالب مسكن في هذه السيارة.',
                          style: GoogleFonts.cairo(
                            fontSize: 14 * textScaleFactor,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        Text(
                          'سيتم إلغاء تسكين جميع الطلاب عند حذف السيارة.',
                          style: GoogleFonts.cairo(
                            fontSize: 14 * textScaleFactor,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                ],
                Text(
                  'هل أنت متأكد من حذف هذه السيارة؟\nهذا الإجراء لا يمكن التراجع عنه.',
                  style: GoogleFonts.cairo(
                    fontSize: 14 * textScaleFactor,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(
                  fontSize: 16 * textScaleFactor,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.04,
                  vertical: MediaQuery.of(context).size.height * 0.015,
                ),
              ),
              child: Text(
                'حذف السيارة',
                style: GoogleFonts.cairo(
                  fontSize: 16 * textScaleFactor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _deleteBus(bus, studentsCount);
      }
    }
  }

  Future<void> _deleteBus(BusModel bus, int studentsCount) async {
    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF1E88E5)),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    Text(
                      'جاري حذف السيارة...',
                      style: GoogleFonts.cairo(
                        fontSize: 16 * MediaQuery.of(context).textScaleFactor,
                        color: const Color(0xFF1A2027),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      if (studentsCount > 0) {
        final batch = FirebaseFirestore.instance.batch();
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('students')
            .where('busId', isEqualTo: bus.id)
            .get();

        for (final studentDoc in studentsSnapshot.docs) {
          batch.update(studentDoc.reference, {
            'busId': '',
            'busRoute': '',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        debugPrint('✅ Unassigned $studentsCount students from bus ${bus.plateNumber}');
      }

      await _databaseService.deleteBus(bus.id);
      await _sendBusDeletionNotifications(bus, studentsCount);

      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'تم حذف السيارة ${bus.plateNumber} بنجاح',
                        style: GoogleFonts.cairo(fontSize: 14 * MediaQuery.of(context).textScaleFactor),
                      ),
                      if (studentsCount > 0)
                        Text(
                          'وتم إلغاء تسكين $studentsCount طالب',
                          style: GoogleFonts.cairo(
                            fontSize: 12 * MediaQuery.of(context).textScaleFactor,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطأ في حذف السيارة: $e',
              style: GoogleFonts.cairo(fontSize: 14 * MediaQuery.of(context).textScaleFactor),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _sendBusDeletionNotifications(BusModel bus, int studentsCount) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .get();
      final adminName = adminDoc.data()?['name'] ?? 'الإدارة';

      final assignmentsSnapshot = await FirebaseFirestore.instance
          .collection('supervisor_assignments')
          .where('busId', isEqualTo: bus.id)
          .where('status', isEqualTo: 'active')
          .get();

      for (final assignment in assignmentsSnapshot.docs) {
        final supervisorId = assignment.data()['supervisorId'];
        if (supervisorId != null) {
          await _notificationService.sendNotificationToUser(
            userId: supervisorId,
            title: 'تم حذف السيارة ${bus.plateNumber}',
            body: 'تم حذف السيارة التي كنت مكلف بها من قبل $adminName. يرجى مراجعة الإدارة.',
            type: 'bus_deleted',
            data: {
              'busId': bus.id,
              'busPlateNumber': bus.plateNumber,
              'adminId': currentUser?.uid,
              'studentsAffected': studentsCount,
            },
          );
        }
      }

      if (studentsCount > 0) {
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('students')
            .where('busId', isEqualTo: bus.id)
            .get();

        for (final studentDoc in studentsSnapshot.docs) {
          final studentData = studentDoc.data();
          final parentId = studentData['parentId'];
          final studentName = studentData['name'];

          if (parentId != null && parentId.isNotEmpty) {
            await _notificationService.sendNotificationToUser(
              userId: parentId,
              title: 'تم حذف سيارة النقل',
              body: 'تم حذف السيارة ${bus.plateNumber} التي كان يستخدمها $studentName. سيتم إعادة تسكين الطالب قريباً.',
              type: 'bus_deleted',
              data: {
                'busId': bus.id,
                'busPlateNumber': bus.plateNumber,
                'studentId': studentDoc.id,
                'studentName': studentName,
              },
            );
          }
        }
      }

      debugPrint('✅ Bus deletion notifications sent for: ${bus.plateNumber}');
    } catch (e) {
      debugPrint('❌ Error sending bus deletion notifications: $e');
    }
  }
}
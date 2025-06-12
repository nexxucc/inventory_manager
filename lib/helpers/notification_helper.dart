import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/inventory_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationHelper {
  // Single instance of the plugin
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String lowStockChannelId = 'low_stock_channel';
  static const String lowStockChannelName = 'Low Stock Alerts';
  static const String lowStockChannelDescription = 'Notifications when inventory is low';

  /// Initialize the plugin. Call this in main().
  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle notification tap if needed, e.g., navigate to item detail.
        // payload = item.id as string.
      },
    );
  }

  /// Create Android notification channel. Call once after initialize().
  static Future<void> createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      lowStockChannelId,
      lowStockChannelName,
      description: lowStockChannelDescription,
      importance: Importance.high,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Show immediate notification for low stock.
  static Future<void> showLowStockNotification(InventoryItem item) async {
    if (item.id == null) return;
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      lowStockChannelId,
      lowStockChannelName,
      channelDescription: lowStockChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    final title = 'Low Stock: ${item.name}';
    final body = item.lowStockThreshold != null
        ? 'Only ${item.quantity} left (threshold ${item.lowStockThreshold})'
        : 'Quantity is ${item.quantity}';
    final notificationId = item.id!; // use item ID for uniqueness

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      platformDetails,
      payload: item.id.toString(),
    );
  }

  /// SharedPreferences key prefix for low-stock alerted flags.
  static String _alertedKey(int itemId) => 'low_alerted_$itemId';

  static Future<bool> _wasAlerted(int itemId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_alertedKey(itemId)) ?? false;
  }

  static Future<void> _setAlerted(int itemId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alertedKey(itemId), value);
  }

  /// Check crossing threshold and show notification if needed.
  ///
  /// prevQty: quantity before the change. If null, treat as always notify if <= threshold.
  static Future<void> showLowStockNotificationIfNeeded(
      InventoryItem item, {
      int? prevQty,
  }) async {
    if (item.id == null || item.lowStockThreshold == null) return;
    final threshold = item.lowStockThreshold!;
    final itemId = item.id!;
    final wasAlerted = await _wasAlerted(itemId);

    // If prevQty provided, notify only when crossing from above to ≤ threshold.
    if (prevQty != null) {
      if (prevQty > threshold && item.quantity <= threshold) {
        // crossing downward
        await showLowStockNotification(item);
        await _setAlerted(itemId, true);
      } else if (item.quantity > threshold && wasAlerted) {
        // restocked above threshold: reset flag
        await _setAlerted(itemId, false);
      }
    } else {
      // No prevQty: on creation or unknown prev, if quantity ≤ threshold and not already alerted, notify
      if (item.quantity <= threshold && !wasAlerted) {
        await showLowStockNotification(item);
        await _setAlerted(itemId, true);
      } else if (item.quantity > threshold && wasAlerted) {
        // restocked above threshold: reset flag
        await _setAlerted(itemId, false);
      }
    }
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Farm App'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @herd.
  ///
  /// In en, this message translates to:
  /// **'Herd'**
  String get herd;

  /// No description provided for @feed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get feed;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get health;

  /// No description provided for @tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// No description provided for @finance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get finance;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @teamAndPolicies.
  ///
  /// In en, this message translates to:
  /// **'Team & policies'**
  String get teamAndPolicies;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recentActivity;

  /// No description provided for @growth.
  ///
  /// In en, this message translates to:
  /// **'Growth'**
  String get growth;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @breeding.
  ///
  /// In en, this message translates to:
  /// **'Insemination'**
  String get breeding;

  /// No description provided for @sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get sales;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @customerSupport.
  ///
  /// In en, this message translates to:
  /// **'Customer Support'**
  String get customerSupport;

  /// No description provided for @myTeam.
  ///
  /// In en, this message translates to:
  /// **'My team'**
  String get myTeam;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @farmManagement.
  ///
  /// In en, this message translates to:
  /// **'Farm management'**
  String get farmManagement;

  /// No description provided for @workspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspace;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @openMenu.
  ///
  /// In en, this message translates to:
  /// **'Open menu'**
  String get openMenu;

  /// No description provided for @openNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get openNotifications;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternetConnection;

  /// No description provided for @dismissNotificationBanner.
  ///
  /// In en, this message translates to:
  /// **'Dismiss notification banner'**
  String get dismissNotificationBanner;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change language'**
  String get changeLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @kiswahili.
  ///
  /// In en, this message translates to:
  /// **'Kiswahili'**
  String get kiswahili;

  /// No description provided for @languageChanged.
  ///
  /// In en, this message translates to:
  /// **'Language changed.'**
  String get languageChanged;

  /// No description provided for @languageChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the language preference. Please try again.'**
  String get languageChangeFailed;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account settings'**
  String get accountSettings;

  /// No description provided for @changeProfileName.
  ///
  /// In en, this message translates to:
  /// **'Change profile name'**
  String get changeProfileName;

  /// No description provided for @changeFarmName.
  ///
  /// In en, this message translates to:
  /// **'Change farm name'**
  String get changeFarmName;

  /// No description provided for @setNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get setNewPassword;

  /// No description provided for @farmConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Farm configuration'**
  String get farmConfiguration;

  /// No description provided for @farmLocation.
  ///
  /// In en, this message translates to:
  /// **'Farm location'**
  String get farmLocation;

  /// No description provided for @addFarmLocation.
  ///
  /// In en, this message translates to:
  /// **'Add your farm location'**
  String get addFarmLocation;

  /// No description provided for @herdUnits.
  ///
  /// In en, this message translates to:
  /// **'Herd units'**
  String get herdUnits;

  /// No description provided for @herdUnitsDescription.
  ///
  /// In en, this message translates to:
  /// **'Kg, breeding cycles, and display units'**
  String get herdUnitsDescription;

  /// No description provided for @timezoneAndDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Timezone & date format'**
  String get timezoneAndDateFormat;

  /// No description provided for @localTimeAndReportingFormat.
  ///
  /// In en, this message translates to:
  /// **'Local farm time and reporting format'**
  String get localTimeAndReportingFormat;

  /// No description provided for @billingAndSubscription.
  ///
  /// In en, this message translates to:
  /// **'Billing & subscription'**
  String get billingAndSubscription;

  /// No description provided for @currentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get currentPlan;

  /// No description provided for @starterPlan.
  ///
  /// In en, this message translates to:
  /// **'Starter plan'**
  String get starterPlan;

  /// No description provided for @autoRenewal.
  ///
  /// In en, this message translates to:
  /// **'Auto-renewal'**
  String get autoRenewal;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @billingHistory.
  ///
  /// In en, this message translates to:
  /// **'Billing history'**
  String get billingHistory;

  /// No description provided for @viewInvoicesAndPayments.
  ///
  /// In en, this message translates to:
  /// **'View invoices and payment activity'**
  String get viewInvoicesAndPayments;

  /// No description provided for @securityAndSessions.
  ///
  /// In en, this message translates to:
  /// **'Security & sessions'**
  String get securityAndSessions;

  /// No description provided for @activeDevices.
  ///
  /// In en, this message translates to:
  /// **'Active devices'**
  String get activeDevices;

  /// No description provided for @manageSignIns.
  ///
  /// In en, this message translates to:
  /// **'Manage sign-ins across your devices'**
  String get manageSignIns;

  /// No description provided for @signOutAllDevices.
  ///
  /// In en, this message translates to:
  /// **'Sign out of all devices'**
  String get signOutAllDevices;

  /// No description provided for @requireRelogin.
  ///
  /// In en, this message translates to:
  /// **'Require re-login everywhere'**
  String get requireRelogin;

  /// No description provided for @privacyAndAccess.
  ///
  /// In en, this message translates to:
  /// **'Privacy and access'**
  String get privacyAndAccess;

  /// No description provided for @roleControlsAndSessionPolicy.
  ///
  /// In en, this message translates to:
  /// **'Role-based controls and session policy'**
  String get roleControlsAndSessionPolicy;

  /// No description provided for @notificationSound.
  ///
  /// In en, this message translates to:
  /// **'Notification sound'**
  String get notificationSound;

  /// No description provided for @phoneDefault.
  ///
  /// In en, this message translates to:
  /// **'Phone default'**
  String get phoneDefault;

  /// No description provided for @chime.
  ///
  /// In en, this message translates to:
  /// **'Chime'**
  String get chime;

  /// No description provided for @alert.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get alert;

  /// No description provided for @silent.
  ///
  /// In en, this message translates to:
  /// **'Silent'**
  String get silent;

  /// No description provided for @changeProfileNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Change profile name'**
  String get changeProfileNameTitle;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get profileName;

  /// No description provided for @profileNameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile name updated.'**
  String get profileNameUpdated;

  /// No description provided for @profileNameUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update your profile name.'**
  String get profileNameUpdateFailed;

  /// No description provided for @farmNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Change farm name'**
  String get farmNameTitle;

  /// No description provided for @farmName.
  ///
  /// In en, this message translates to:
  /// **'Farm name'**
  String get farmName;

  /// No description provided for @farmNameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Farm name updated.'**
  String get farmNameUpdated;

  /// No description provided for @farmNameUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the farm name.'**
  String get farmNameUpdateFailed;

  /// No description provided for @passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated.'**
  String get passwordUpdated;

  /// No description provided for @passwordUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the password. Check your current password.'**
  String get passwordUpdateFailed;

  /// No description provided for @farmLocationComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Farm location settings are coming soon.'**
  String get farmLocationComingSoon;

  /// No description provided for @herdUnitsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Herd units settings are coming soon.'**
  String get herdUnitsComingSoon;

  /// No description provided for @timezoneComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Timezone settings are coming soon.'**
  String get timezoneComingSoon;

  /// No description provided for @subscriptionReadyNextMilestone.
  ///
  /// In en, this message translates to:
  /// **'Subscription management is ready for the next milestone.'**
  String get subscriptionReadyNextMilestone;

  /// No description provided for @autoRenewalComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Auto-renewal settings are coming soon.'**
  String get autoRenewalComingSoon;

  /// No description provided for @billingHistoryComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Billing history is coming soon.'**
  String get billingHistoryComingSoon;

  /// No description provided for @deviceManagementComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Device management is coming soon.'**
  String get deviceManagementComingSoon;

  /// No description provided for @sessionResetComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Session reset is coming soon.'**
  String get sessionResetComingSoon;

  /// No description provided for @accessPolicyComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Access policy settings are coming soon.'**
  String get accessPolicyComingSoon;

  /// No description provided for @stepLanguage.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 4 · Language'**
  String get stepLanguage;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguage;

  /// No description provided for @languageIntro.
  ///
  /// In en, this message translates to:
  /// **'Pick the language that feels most natural. You can change it later.'**
  String get languageIntro;

  /// No description provided for @searchLanguages.
  ///
  /// In en, this message translates to:
  /// **'Search languages'**
  String get searchLanguages;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @farmOverview.
  ///
  /// In en, this message translates to:
  /// **'Farm overview'**
  String get farmOverview;

  /// No description provided for @goodDay.
  ///
  /// In en, this message translates to:
  /// **'Good day'**
  String get goodDay;

  /// No description provided for @farmRunningSmoothly.
  ///
  /// In en, this message translates to:
  /// **'Your farm is running smoothly today.'**
  String get farmRunningSmoothly;

  /// No description provided for @overviewLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not load the latest farm overview.'**
  String get overviewLoadFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @herdSize.
  ///
  /// In en, this message translates to:
  /// **'Herd size'**
  String get herdSize;

  /// No description provided for @feedStock.
  ///
  /// In en, this message translates to:
  /// **'Feed stock'**
  String get feedStock;

  /// No description provided for @tasksDue.
  ///
  /// In en, this message translates to:
  /// **'Tasks due'**
  String get tasksDue;

  /// No description provided for @salesThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Sales this week'**
  String get salesThisWeek;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @pregnant.
  ///
  /// In en, this message translates to:
  /// **'Pregnant'**
  String get pregnant;

  /// No description provided for @vaccinated.
  ///
  /// In en, this message translates to:
  /// **'Vaccinated'**
  String get vaccinated;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @registeredHerd.
  ///
  /// In en, this message translates to:
  /// **'Registered herd'**
  String get registeredHerd;

  /// No description provided for @herdStatus.
  ///
  /// In en, this message translates to:
  /// **'Herd status'**
  String get herdStatus;

  /// No description provided for @herdPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Herd'**
  String get herdPageTitle;

  /// No description provided for @refreshHerd.
  ///
  /// In en, this message translates to:
  /// **'Refresh herd'**
  String get refreshHerd;

  /// No description provided for @addPig.
  ///
  /// In en, this message translates to:
  /// **'Add Pig'**
  String get addPig;

  /// No description provided for @searchAnimals.
  ///
  /// In en, this message translates to:
  /// **'Search Pig ID, breed, or pen'**
  String get searchAnimals;

  /// No description provided for @allPigs.
  ///
  /// In en, this message translates to:
  /// **'All pigs'**
  String get allPigs;

  /// No description provided for @yourAnimals.
  ///
  /// In en, this message translates to:
  /// **'Your animals'**
  String get yourAnimals;

  /// No description provided for @shown.
  ///
  /// In en, this message translates to:
  /// **'shown'**
  String get shown;

  /// No description provided for @noPigsFound.
  ///
  /// In en, this message translates to:
  /// **'No pigs found'**
  String get noPigsFound;

  /// No description provided for @noMatchingPigs.
  ///
  /// In en, this message translates to:
  /// **'No matching pigs found'**
  String get noMatchingPigs;

  /// No description provided for @adjustSearchOrFilters.
  ///
  /// In en, this message translates to:
  /// **'Add a pig or adjust your search and filters.'**
  String get adjustSearchOrFilters;

  /// No description provided for @sold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get sold;

  /// No description provided for @deceased.
  ///
  /// In en, this message translates to:
  /// **'Deceased'**
  String get deceased;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get selectLanguage;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @darkModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Use dark theme for reduced eye strain'**
  String get darkModeDescription;

  /// No description provided for @measurementUnits.
  ///
  /// In en, this message translates to:
  /// **'Measurement units'**
  String get measurementUnits;

  /// No description provided for @weightUnit.
  ///
  /// In en, this message translates to:
  /// **'Weight unit'**
  String get weightUnit;

  /// No description provided for @dateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get dateFormat;

  /// No description provided for @selectFormat.
  ///
  /// In en, this message translates to:
  /// **'Select format'**
  String get selectFormat;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @selectCurrency.
  ///
  /// In en, this message translates to:
  /// **'Select currency'**
  String get selectCurrency;

  /// No description provided for @farmTasks.
  ///
  /// In en, this message translates to:
  /// **'Farm tasks'**
  String get farmTasks;

  /// No description provided for @addTask.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get addTask;

  /// No description provided for @dailyFarmPlan.
  ///
  /// In en, this message translates to:
  /// **'Daily farm plan'**
  String get dailyFarmPlan;

  /// No description provided for @dailyFarmPlanDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep the team on track with daily tasks and follow-ups.'**
  String get dailyFarmPlanDescription;

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dueToday;

  /// No description provided for @highPriority.
  ///
  /// In en, this message translates to:
  /// **'High priority'**
  String get highPriority;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @allTasksFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allTasksFilter;

  /// No description provided for @noTasksInView.
  ///
  /// In en, this message translates to:
  /// **'No tasks in this view'**
  String get noTasksInView;

  /// No description provided for @createTaskInstruction.
  ///
  /// In en, this message translates to:
  /// **'Create a new task to plan the next farm activity.'**
  String get createTaskInstruction;

  /// No description provided for @addFarmTask.
  ///
  /// In en, this message translates to:
  /// **'Add farm task'**
  String get addFarmTask;

  /// No description provided for @taskTitle.
  ///
  /// In en, this message translates to:
  /// **'Task title'**
  String get taskTitle;

  /// No description provided for @assignedTo.
  ///
  /// In en, this message translates to:
  /// **'Assigned to'**
  String get assignedTo;

  /// No description provided for @due.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get due;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @feeding.
  ///
  /// In en, this message translates to:
  /// **'Feeding'**
  String get feeding;

  /// No description provided for @salesCategory.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get salesCategory;

  /// No description provided for @taskTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Task title is required.'**
  String get taskTitleRequired;

  /// No description provided for @saveTask.
  ///
  /// In en, this message translates to:
  /// **'Save task'**
  String get saveTask;

  /// No description provided for @unassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get unassigned;

  /// No description provided for @taskExampleFeedCheck.
  ///
  /// In en, this message translates to:
  /// **'Check feed stock for the evening batch'**
  String get taskExampleFeedCheck;

  /// No description provided for @taskExampleVaccination.
  ///
  /// In en, this message translates to:
  /// **'Vaccination follow-up for nursery pigs'**
  String get taskExampleVaccination;

  /// No description provided for @taskExampleGrowthReview.
  ///
  /// In en, this message translates to:
  /// **'Review piglet growth and weight log'**
  String get taskExampleGrowthReview;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @taskNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get taskNotes;

  /// No description provided for @taskLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Farm tasks could not be loaded.'**
  String get taskLoadFailed;

  /// No description provided for @deleteTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete task?'**
  String get deleteTaskTitle;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @urgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get urgent;

  /// No description provided for @otherCategory.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherCategory;

  /// No description provided for @farmSales.
  ///
  /// In en, this message translates to:
  /// **'Farm sales'**
  String get farmSales;

  /// No description provided for @salesIntro.
  ///
  /// In en, this message translates to:
  /// **'Record farm orders, buyers, prices, and delivery status.'**
  String get salesIntro;

  /// No description provided for @salesPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get salesPeriod;

  /// No description provided for @noSalesYet.
  ///
  /// In en, this message translates to:
  /// **'No sales have been recorded for this farm.'**
  String get noSalesYet;

  /// No description provided for @addFarmSale.
  ///
  /// In en, this message translates to:
  /// **'Record sale'**
  String get addFarmSale;

  /// No description provided for @saleBuyer.
  ///
  /// In en, this message translates to:
  /// **'Buyer'**
  String get saleBuyer;

  /// No description provided for @saleItem.
  ///
  /// In en, this message translates to:
  /// **'Pig or product'**
  String get saleItem;

  /// No description provided for @saleQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get saleQuantity;

  /// No description provided for @saleUnitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get saleUnitPrice;

  /// No description provided for @saleCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get saleCurrency;

  /// No description provided for @saleOrderDate.
  ///
  /// In en, this message translates to:
  /// **'Order date'**
  String get saleOrderDate;

  /// No description provided for @saleExpectedDate.
  ///
  /// In en, this message translates to:
  /// **'Expected delivery'**
  String get saleExpectedDate;

  /// No description provided for @saleReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get saleReference;

  /// No description provided for @saleNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get saleNotes;

  /// No description provided for @buyerName.
  ///
  /// In en, this message translates to:
  /// **'Buyer name'**
  String get buyerName;

  /// No description provided for @buyerEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get buyerEmail;

  /// No description provided for @buyerPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get buyerPhone;

  /// No description provided for @buyerCompany.
  ///
  /// In en, this message translates to:
  /// **'Company or shop'**
  String get buyerCompany;

  /// No description provided for @buyerAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get buyerAddress;

  /// No description provided for @buyerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search buyers'**
  String get buyerSearch;

  /// No description provided for @noBuyers.
  ///
  /// In en, this message translates to:
  /// **'No buyers have been added yet.'**
  String get noBuyers;

  /// No description provided for @addBuyer.
  ///
  /// In en, this message translates to:
  /// **'Add buyer'**
  String get addBuyer;

  /// No description provided for @editBuyer.
  ///
  /// In en, this message translates to:
  /// **'Edit buyer'**
  String get editBuyer;

  /// No description provided for @salesPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to manage sales for this farm.'**
  String get salesPermissionDenied;

  /// No description provided for @salesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Farm sales could not be loaded.'**
  String get salesLoadError;

  /// No description provided for @orderStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get orderStatusPending;

  /// No description provided for @orderStatusOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get orderStatusOngoing;

  /// No description provided for @orderStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get orderStatusCompleted;

  /// No description provided for @orderStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get orderStatusCancelled;

  /// No description provided for @buyers.
  ///
  /// In en, this message translates to:
  /// **'Buyers'**
  String get buyers;

  /// No description provided for @selectFarm.
  ///
  /// In en, this message translates to:
  /// **'Select a farm'**
  String get selectFarm;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @salesAnimalsMarkedSold.
  ///
  /// In en, this message translates to:
  /// **'Animals marked sold'**
  String get salesAnimalsMarkedSold;

  /// No description provided for @buyerNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Buyer name is required.'**
  String get buyerNameRequired;

  /// No description provided for @saleItemRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the pig or product being sold.'**
  String get saleItemRequired;

  /// No description provided for @saleReferenceRequired.
  ///
  /// In en, this message translates to:
  /// **'Sale reference is required.'**
  String get saleReferenceRequired;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get invalidEmail;

  /// No description provided for @positiveAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a number greater than zero.'**
  String get positiveAmountRequired;

  /// No description provided for @noBuyersMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'No buyers match this search.'**
  String get noBuyersMatchSearch;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'SpotiFLAC Mobile';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navLibrary => 'المكتبة';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get navStore => 'المستودع';

  @override
  String get homeTitle => 'الصفحة الرئيسية';

  @override
  String get homeSubtitle => 'ألصق عنوان URL مدعوم أو ابحث بالاسم';

  @override
  String get homeEmptyTitle => 'لا يوجد مزودي بحث بعد';

  @override
  String get homeEmptySubtitle => 'قم بتثبيت مكون إضافي للمتابعة.';

  @override
  String get homeSupports =>
      'يدعم: الأغنية، الألبوم، قائمة التشغيل، عناوين URL للفنان';

  @override
  String get homeRecent => 'الأخيرة';

  @override
  String get historyFilterAll => 'الكل';

  @override
  String get historyFilterAlbums => 'الألبومات';

  @override
  String get historyFilterSingles => 'الأغاني';

  @override
  String get historySearchHint => 'سجل البحث...';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsDownload => 'إعدادات التحميل';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsExtensions => 'الإضافات';

  @override
  String get settingsAbout => 'حول البرنامج';

  @override
  String get downloadTitle => 'إعدادات التحميل';

  @override
  String get downloadAskQualitySubtitle => 'إظهار منتقي الجودة لكل تنزيل';

  @override
  String get downloadFilenameFormat => 'تنسيق اسم الملف';

  @override
  String get downloadSingleFilenameFormat => 'تنسيق اسم الملف الفردي';

  @override
  String get downloadSingleFilenameFormatDescription =>
      'نمط اسم الملف للعازفين و EPs. يستخدم نفس العلامات مثل تنسيق الألبوم.';

  @override
  String get downloadFolderOrganization => 'تنظيم المجلدات';

  @override
  String get appearanceTitle => 'المظهر';

  @override
  String get appearanceThemeSystem => 'النظام';

  @override
  String get appearanceThemeLight => 'فاتح';

  @override
  String get appearanceThemeDark => 'مظلم';

  @override
  String get appearanceDynamicColor => 'لون ديناميكي';

  @override
  String get appearanceDynamicColorSubtitle => 'استخدام الألوان من الخلفية';

  @override
  String get appearanceHistoryView => 'عرض السجل';

  @override
  String get appearanceHistoryViewList => 'قائمة';

  @override
  String get appearanceHistoryViewGrid => 'شبكة';

  @override
  String get optionsPrimaryProvider => 'المزود الرئيسي';

  @override
  String get optionsPrimaryProviderSubtitle =>
      'الخدمة المستخدمة للبحث عن طريق اسم الأغنية أو الألبوم';

  @override
  String optionsUsingExtension(String extensionName) {
    return 'استخدام الإضافة: $extensionName';
  }

  @override
  String get optionsDefaultSearchTab => 'تبويب البحث الافتراضي';

  @override
  String get optionsDefaultSearchTabSubtitle =>
      'اختر علامة التبويب التي تفتح أولاً لنتائج البحث الجديدة.';

  @override
  String get optionsAutoFallback => 'التراجع التلقائي';

  @override
  String get optionsAutoFallbackSubtitle => 'تجربة خدمات أخرى إذا فشل التنزيل';

  @override
  String get optionsEmbedLyrics => 'تضمين كلمات الأغنية';

  @override
  String get optionsEmbedLyricsSubtitle =>
      'حفظ كلمات الأغاني المتزامنة جنبا إلى جنب مع المسارات التي تم تنزيلها';

  @override
  String get optionsMaxQualityCover => 'اختيار أعلى جودة للغلاف';

  @override
  String get optionsMaxQualityCoverSubtitle => 'تنزيل أعلى دقة لغلاف الأغنية';

  @override
  String get optionsReplayGain => 'ReplyGain';

  @override
  String get optionsReplayGainSubtitleOn =>
      'مسح الصوت و تضمين علامات ReplayGain (EBU R128)';

  @override
  String get optionsReplayGainSubtitleOff => 'معطل: لا توجد علامات تطبيع للصوت';

  @override
  String get trackReplayGain => 'إعادة مسح ReplyGain';

  @override
  String get trackReplayGainScanning => 'تحليل الصوت...';

  @override
  String get trackReplayGainSuccess => 'تم إضافة وسم ReplyGain';

  @override
  String get trackReplayGainFailed => 'فشل في إضافة علامات ReplayGain';

  @override
  String selectionReplayGainCount(int count) {
    return 'ٌReplyGain ($count)';
  }

  @override
  String get replayGainBatchConfirmTitle => 'إضافة ReplyGain';

  @override
  String replayGainBatchConfirmMessage(int count) {
    return 'تحليل الصوت وكتابة وسوم ReplayGain إلى مسار(مسارات) $count؟';
  }

  @override
  String get replayGainBatchAnalyzing => 'تحليل ReplyGain...';

  @override
  String replayGainBatchSuccess(int success, int total) {
    return 'تمت إضافة وسوم ReplyGain ل $success أغنية من أصل $total';
  }

  @override
  String get optionsArtistTagMode => 'وضع وسم الفنان';

  @override
  String get optionsArtistTagModeDescription =>
      'اختر كيف يتم كتابة العديد من الفنانين في العلامات المضمنة.';

  @override
  String get optionsArtistTagModeJoined => 'قيمة مشتركة واحدة';

  @override
  String get optionsArtistTagModeJoinedSubtitle =>
      'اكتب قيمة ARTIST واحدة مثل \"الفنان A، الفنان B\" لتحقيق التوافق الأقصى لمشغل الأغاني.';

  @override
  String get optionsArtistTagModeSplitVorbis => 'تقسيم العلامات على FLAC/Opus';

  @override
  String get optionsArtistTagModeSplitVorbisSubtitle =>
      'اكتب علامة فنان لكل فنان لـ FLAC و Opus؛ تبقى MP3 و M4A منضمة.';

  @override
  String get optionsExtensionStore => 'مستودع الإضافات';

  @override
  String get optionsExtensionStoreSubtitle =>
      'إظهار صفحة المستودع في شريط التنقل';

  @override
  String get optionsCheckUpdates => 'التحقق من وجود تحديثات';

  @override
  String get optionsCheckUpdatesSubtitle => 'إعلام عند توفر إصدار جديد';

  @override
  String get optionsUpdateChannel => 'قناة التحديث';

  @override
  String get optionsUpdateChannelStable => 'الإصدارات المستقرة فقط';

  @override
  String get optionsUpdateChannelPreview => 'الحصول على إصدارات تجريبية';

  @override
  String get optionsUpdateChannelWarning =>
      'قد تحتوي الإصدارات التجريبية أخطاءً أو ميزات غير مكتملة';

  @override
  String get optionsClearHistory => 'مسح سجل التحميلات';

  @override
  String get optionsClearHistorySubtitle =>
      'إزالة جميع الأغاني التي تم تنزيلها من السجل';

  @override
  String get optionsDetailedLogging => 'تسجيل تفصيلي';

  @override
  String get optionsDetailedLoggingOn => 'يتم تسجيل السجلات التفصيلية';

  @override
  String get optionsDetailedLoggingOff => 'تمكين لتقارير الأخطاء';

  @override
  String get extensionsTitle => 'الإضافات';

  @override
  String get extensionsDisabled => 'معطَّل';

  @override
  String extensionsVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String get extensionsUninstall => 'إلغاء التثبيت';

  @override
  String get storeTitle => 'مستودع الإضافات';

  @override
  String get storeSearch => 'البحث في الإضافات...';

  @override
  String get storeInstall => 'تثبيت';

  @override
  String get storeInstalled => 'مثبت';

  @override
  String get storeUpdate => 'تحديث';

  @override
  String get aboutTitle => 'حول';

  @override
  String get aboutContributors => 'المساهمون';

  @override
  String get aboutMobileDeveloper => 'مطور نسخة الهاتف';

  @override
  String get aboutOriginalCreator => 'منشئ SpotiFLAC';

  @override
  String get aboutLogoArtist => 'الفنان الموهوب الذي أنشأ شعار التطبيق الجميل!';

  @override
  String get aboutTranslators => 'المترجمون';

  @override
  String get aboutSpecialThanks => 'شكر خاص لِ';

  @override
  String get aboutLinks => 'روابط';

  @override
  String get aboutMobileSource => 'كود مصدر برنامج الهاتف';

  @override
  String get aboutPCSource => 'كود مصدر برنامج الكمبيوتر';

  @override
  String get aboutKeepAndroidOpen => 'ابقي اندرويد مفتوحا';

  @override
  String get aboutReportIssue => 'الإبلاغ عن خطأ';

  @override
  String get aboutReportIssueSubtitle => 'الإبلاغ عن أي مشكلة تواجهك';

  @override
  String get aboutFeatureRequest => 'اقتراح ميزة';

  @override
  String get aboutFeatureRequestSubtitle => 'اقتراح ميزات جديدة للتطبيق';

  @override
  String get aboutTelegramChannel => 'قناة تيليجرام';

  @override
  String get aboutTelegramChannelSubtitle => 'الإعلانات والتحديثات';

  @override
  String get aboutTelegramChat => 'مجتمع تليجرام';

  @override
  String get aboutTelegramChatSubtitle => 'الدردشة مع المستخدمين الآخرين';

  @override
  String get aboutSocial => 'التواصل الإجتماعي';

  @override
  String get aboutApp => 'التطبيق';

  @override
  String get aboutVersion => 'الإصدار';

  @override
  String get aboutBinimumDesc =>
      'منشئ API QQDL و HiFi. ساعد هذا المشروع في تشكيل دعم تحميل غير فاقد للجودة.';

  @override
  String get aboutSachinsenalDesc =>
      'منشئ مشروع HiFi الأصلي. مؤسسة للتكامل بدون مصدر.';

  @override
  String get aboutSjdonadoDesc =>
      'منشئ ل I Don\'t Have Spotify (IHDS). محلل الروابط الذي ينقذ اليوم!';

  @override
  String get aboutAppDescription =>
      'البحث عن بيانات التعريف الموسيقي، وإدارة الملحقات، وتنظيم مكتبتك.';

  @override
  String get artistAlbums => 'الألبومات';

  @override
  String get artistSingles => 'الأغاني و ال EPs';

  @override
  String get artistCompilations => 'التجميع';

  @override
  String get artistPopular => 'الأكثر شعبية';

  @override
  String artistMonthlyListeners(String count) {
    return '$count مستمع شهري';
  }

  @override
  String get trackMetadataService => 'الخدمة';

  @override
  String get trackMetadataPlay => 'تشغيل';

  @override
  String get trackMetadataShare => 'مشاركة';

  @override
  String get trackMetadataDelete => 'حذف';

  @override
  String get setupGrantPermission => 'منح الصلاحيات';

  @override
  String get setupSkip => 'التخطي الآن';

  @override
  String get setupStorageAccessRequired => 'إذن دخول وحدة التخزين مطلوب';

  @override
  String get setupStorageAccessMessageAndroid11 =>
      'يتطلب أندرويد 11+ إذن \"الوصول إلى جميع الملفات\" لحفظ الملفات في مجلد التحميل الذي اخترته.';

  @override
  String get setupOpenSettings => 'فتح الإعدادات';

  @override
  String get setupPermissionDeniedMessage =>
      'تم رفض الإذن. الرجاء منح كافة الصلاحيات للمتابعة.';

  @override
  String setupPermissionRequired(String permissionType) {
    return '$permissionType مطلوب الإذن';
  }

  @override
  String setupPermissionRequiredMessage(String permissionType) {
    return 'الإذن $permissionType مطلوب لأفضل التجربة. يمكنك تغيير هذا لاحقاً في الإعدادات.';
  }

  @override
  String get setupUseDefaultFolder => 'استخدام المجلد الافتراضي؟';

  @override
  String get setupNoFolderSelected =>
      'لم يتم تحديد مجلد. هل ترغب في استخدام مجلد الموسيقى الافتراضي؟';

  @override
  String get setupUseDefault => 'استخدم الافتراضي';

  @override
  String get setupDownloadLocationTitle => 'موقع حفظ التنزيلات';

  @override
  String get setupDownloadLocationIosMessage =>
      'على iOS، يتم حفظ التحميلات إلى مجلد مستندات التطبيق. يمكنك الوصول إليها عبر تطبيق الملفات.';

  @override
  String get setupAppDocumentsFolder => 'مجلد مستندات التطبيق';

  @override
  String get setupAppDocumentsFolderSubtitle =>
      'موصى به - يمكن الوصول إليه عبر تطبيق الملفات';

  @override
  String get setupChooseFromFiles => 'اختر من الملفات';

  @override
  String get setupChooseFromFilesSubtitle => 'حدد iCloud أو موقع آخر';

  @override
  String get setupIosEmptyFolderWarning =>
      'حدود iOS: لا يمكن تحديد مجلدات فارغة. اختر مجلدا مع ملف واحد على الأقل.';

  @override
  String get setupIcloudNotSupported =>
      'iCloud Drive غير مدعوم. الرجاء استخدام مجلد مستندات التطبيق.';

  @override
  String get setupDownloadInFlac => 'تحميل اغاني Spotify بصيغة FLAC';

  @override
  String get setupStorageGranted => 'تم منح إذن التخزين!';

  @override
  String get setupStorageRequired => 'الإذن مطلوب للتخزين';

  @override
  String get setupStorageDescription =>
      'SpotiFLAC يحتاج إلى إذن تخزين لحفظ ملفات الموسيقى الخاصة بك التي تم تنزيلها.';

  @override
  String get setupNotificationGranted => 'تم منح إذن الإشعارات!';

  @override
  String get setupNotificationEnable => 'تمكين الإشعارات';

  @override
  String get setupFolderChoose => 'اختر مجلد التحميل';

  @override
  String get setupFolderDescription =>
      'حدد مجلد حيث سيتم حفظ الموسيقى التي تم تنزيلها.';

  @override
  String get setupSelectFolder => 'حدد الملف';

  @override
  String get setupEnableNotifications => 'تمكين الإشعارات';

  @override
  String get setupNotificationBackgroundDescription =>
      'الحصول على إشعار حول تقدم التحميل وإكماله. هذا يساعدك على تتبع التنزيلات عندما يكون التطبيق في الخلفية.';

  @override
  String get setupSkipForNow => 'التخطي الآن';

  @override
  String get setupNext => 'التالي';

  @override
  String get setupGetStarted => 'إبدأ الآن';

  @override
  String get setupAllowAccessToManageFiles =>
      'الرجاء تمكين \"السماح بالوصول لإدارة جميع الملفات\" في الشاشة التالية.';

  @override
  String get setupLanguageTitle => 'اِختر اللغة';

  @override
  String get setupLanguageDescription =>
      'حدد لغتك المفضلة للتطبيق. يمكنك تغيير هذا لاحقًا من الإعدادات.';

  @override
  String get setupLanguageSystemDefault => 'الوضع الافتراضي للنظام';

  @override
  String get dialogCancel => 'إلغاء';

  @override
  String get dialogSave => 'حفظ';

  @override
  String get dialogDelete => 'حذف';

  @override
  String get dialogRetry => 'إعادة المحاولة';

  @override
  String get dialogClear => 'محو';

  @override
  String get dialogDone => 'تم';

  @override
  String get dialogImport => 'استيراد';

  @override
  String get dialogDownload => 'تنزيل';

  @override
  String get previewPlay => 'تشغيل المعاينة';

  @override
  String get previewStop => 'إيقاف المعاينة';

  @override
  String get previewUnavailable => 'المعاينة غير متوفرة';

  @override
  String get dialogDiscard => 'تجاهل';

  @override
  String get dialogRemove => 'إزالة';

  @override
  String get dialogUninstall => 'إلغاء التثبيت';

  @override
  String get dialogDiscardChanges => 'تجاهل التغييرات؟';

  @override
  String get dialogUnsavedChanges =>
      'لديك تغييرات غير محفوظة. هل تريد المتابعة دون حفظها؟';

  @override
  String get dialogClearAll => 'مسح الكل';

  @override
  String get dialogRemoveExtension => 'إزالة إضافة';

  @override
  String get dialogRemoveExtensionMessage =>
      'هل أنت متأكد من أنك تريد إزالة هذه الإضافة؟ لا يمكن التراجع عن ذلك.';

  @override
  String get dialogUninstallExtension => 'إلغاء تثبيت الإضافة؟';

  @override
  String dialogUninstallExtensionMessage(String extensionName) {
    return 'هل أنت متأكد من أنك تريد إزالة $extensionName؟';
  }

  @override
  String get dialogClearHistoryTitle => 'مسح السجل';

  @override
  String get dialogClearHistoryMessage =>
      'هل أنت متأكد من أنك تريد مسح كل سجل التنزيلات؟ لا يمكن التراجع عن هذا.';

  @override
  String get dialogDeleteSelectedTitle => 'حذف المحدد';

  @override
  String dialogDeleteSelectedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الأغاني',
      one: 'أغنية',
    );
    return 'حذف $count $_temp0 من التاريخ؟\n\nسيؤدي هذا أيضا إلى حذف الملفات من وحدة التخزين.';
  }

  @override
  String get dialogImportPlaylistTitle => 'استيراد قائمة تشغيل';

  @override
  String dialogImportPlaylistMessage(int count) {
    return 'تم العثور على $count مسارات في CSV. إضافتها إلى قائمة انتظار التنزيل؟';
  }

  @override
  String csvImportTracks(int count) {
    return '$count مسارات من CSV';
  }

  @override
  String snackbarAddedToQueue(String trackName) {
    return 'تمت إضافة $trackName إلى قائمة الانتظار';
  }

  @override
  String snackbarAddedTracksToQueue(int count) {
    return 'تم إضافة $count أغانٍ إلى قائمة الانتظار';
  }

  @override
  String snackbarAlreadyDownloaded(String trackName) {
    return 'تم تنزيل $trackName بالفعل';
  }

  @override
  String snackbarAlreadyInLibrary(String trackName) {
    return '$trackName موجود بالفعل في مكتبتك';
  }

  @override
  String get snackbarHistoryCleared => 'تم مسح السجل.';

  @override
  String snackbarDeletedTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أغانٍ',
      one: 'أغنية',
    );
    return 'تم حذف $count $_temp0';
  }

  @override
  String snackbarCannotOpenFile(String error) {
    return 'تعذر فتح الملف: $error';
  }

  @override
  String get snackbarViewQueue => 'عرض قائمة الانتظار';

  @override
  String snackbarUrlCopied(String platform) {
    return 'رابط $platform تم نسخه إلى الحافظة';
  }

  @override
  String get snackbarFileNotFound => 'لم يتم العثور على الملف';

  @override
  String get snackbarSelectExtFile => 'الرجاء تحديد ملف .spotiflac-ext';

  @override
  String get snackbarProviderPrioritySaved => 'تم حفظ أولوية المزود';

  @override
  String get snackbarMetadataProviderSaved =>
      'تم حفظ أولوية مزود البيانات الوصفية (metadata)';

  @override
  String snackbarExtensionInstalled(String extensionName) {
    return 'تم تثبيت $extensionName.';
  }

  @override
  String snackbarExtensionUpdated(String extensionName) {
    return 'تم تحديث $extensionName.';
  }

  @override
  String get snackbarFailedToInstall => 'فشل تثبيت الإضافة';

  @override
  String get snackbarFailedToUpdate => 'فشل تحديث الإضافة';

  @override
  String get errorRateLimited => 'تم الوصول للحد الأقصى';

  @override
  String get errorRateLimitedMessage =>
      'طلبات كثيرة جداً. الرجاء الانتظار قليلاً قبل البحث مرة أخرى.';

  @override
  String get errorNoTracksFound => 'لم يتم العثور على الأغنية';

  @override
  String get searchEmptyResultSubtitle => 'جرّب كلمة مفتاحية أخرى';

  @override
  String get errorUrlNotRecognized => 'رابط غير معروف';

  @override
  String get errorUrlNotRecognizedMessage =>
      'هذا الرابط غير مدعوم. تأكد من أن الرابط صحيح وتثبيت إضافة متوافق.';

  @override
  String get errorUrlFetchFailed =>
      'فشل تحميل المحتوى من هذا الرابط. الرجاء المحاولة مرة أخرى.';

  @override
  String errorMissingExtensionSource(String item) {
    return 'لا يمكن تحميل $item: مصدر الإضافة مفقود';
  }

  @override
  String get actionPause => 'إيقاف مؤقت';

  @override
  String get actionResume => 'استئناف';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionSelectAll => 'تحديد الكل';

  @override
  String get actionDeselect => 'إلغاء التحديد';

  @override
  String selectionSelected(int count) {
    return 'تم تحديد $count';
  }

  @override
  String get selectionAllSelected => 'تم اختيار جميع الأغاني';

  @override
  String get selectionSelectToDelete => 'حدد الأغاني المراد حذفها';

  @override
  String progressFetchingMetadata(int current, int total) {
    return 'جلب البيانات الوصفية (metadata)... $current/$total';
  }

  @override
  String get progressReadingCsv => 'جاري قراءة CSV...';

  @override
  String get searchSongs => 'أغاني';

  @override
  String get searchArtists => 'فنانون';

  @override
  String get searchAlbums => 'ألبومات';

  @override
  String get searchPlaylists => 'قوائم التشغيل';

  @override
  String get searchSortTitle => 'فرز النتائج';

  @override
  String get searchSortDefault => 'افتراضي';

  @override
  String get searchSortTitleAZ => 'العنوان (أ-ي)';

  @override
  String get searchSortTitleZA => 'العنوان (ي-أ)';

  @override
  String get searchSortArtistAZ => 'الفنان (أ-ي)';

  @override
  String get searchSortArtistZA => 'الفنان (ي-أ)';

  @override
  String get searchSortDurationShort => 'المدة (الأقصر)';

  @override
  String get searchSortDurationLong => 'المدة (الأطول)';

  @override
  String get searchSortDateOldest => 'تاريخ الإصدار (الأقدم)';

  @override
  String get searchSortDateNewest => 'تاريخ الإصدار (الأحدث)';

  @override
  String get tooltipPlay => 'تشغيل';

  @override
  String get filenameFormat => 'صيغة الملف';

  @override
  String get filenameShowAdvancedTags => 'إظهار العلامات المتقدمة';

  @override
  String get filenameShowAdvancedTagsDescription =>
      'تمكين العلامات المنسقة لحشو المقطع الصوتي وأنماط التاريخ';

  @override
  String get folderOrganizationNone => 'لا توجد منظمة';

  @override
  String get folderOrganizationByPlaylist => 'حسب قائمة التشغيل';

  @override
  String get folderOrganizationByPlaylistSubtitle =>
      'مجلد منفصل لكل قائمة تشغيل';

  @override
  String get folderOrganizationByArtist => 'حسب الفنان';

  @override
  String get folderOrganizationByAlbum => 'حسب الألبوم';

  @override
  String get folderOrganizationByArtistAlbum => 'ألبوم/الفنان';

  @override
  String get folderOrganizationDescription =>
      'تنظيم الملفات التي تم تنزيلها في المجلدات';

  @override
  String get folderOrganizationNoneSubtitle => 'جميع الملفات في مجلد التحميل';

  @override
  String get folderOrganizationByArtistSubtitle => 'مجلد منفصل لكل فنان';

  @override
  String get folderOrganizationByAlbumSubtitle => 'مجلد منفصل لكل قائمة تشغيل';

  @override
  String get folderOrganizationByArtistAlbumSubtitle =>
      'مجلدات متداخلة للفنان و الألبوم';

  @override
  String get updateAvailable => 'هناك تحديث متاح';

  @override
  String get updateLater => 'ذكرني لاحقا';

  @override
  String get updateStartingDownload => 'جاري بدء التنزيل...';

  @override
  String get updateDownloadFailed => 'فشل التنزيل';

  @override
  String get updateFailedMessage => 'فشل تنزيل التحديث';

  @override
  String get updateNewVersionReady => 'إصدار جديد جاهز';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String updateRequiredNotice(int count) {
    return 'This version is $count releases behind and is no longer supported. Update to keep using the app.';
  }

  @override
  String get updateCurrent => 'الحالي';

  @override
  String get updateNew => 'جديد';

  @override
  String get updateDownloading => 'جاري التنزيل...';

  @override
  String get updateWhatsNew => 'ما الجديد';

  @override
  String get updateDownloadInstall => 'تحميل وتثبيت';

  @override
  String get updateDontRemind => 'لا تذكّرني';

  @override
  String get providerPriorityTitle => 'أولوية مقدم الخدمة';

  @override
  String get providerPriorityDescription =>
      'اسحب لإعادة ترتيب مزودي التحميل. سيجرب التطبيق مزودي الخدمات من الأعلى إلى الأسفل عند تحميل المسار.';

  @override
  String get providerPriorityInfo =>
      'إذا كانت الأغنية غير متوفرة عند أول مزود، فإن التطبيق سيجرب تلقائياً المزود التالي.';

  @override
  String get providerPriorityFallbackExtensionsDescription =>
      'اختر إضافات التحميل المثبتة التي يمكن استخدامها أثناء الرجوع التلقائي للمزود الاحتياطي.';

  @override
  String get providerPriorityFallbackExtensionsHint =>
      'الإضافات المفعلة فقط مع قدرة توفير التنزيل مدرجة هنا.';

  @override
  String get providerExtension => 'الإضافة';

  @override
  String get metadataProviderPriorityTitle =>
      'أولوية البيانات الوصفية (metadata)';

  @override
  String get metadataProviderPriorityDescription =>
      'اسحب لإعادة ترتيب موفري البيانات الوصفية (metadata). سيحاول التطبيق موفري البيانات الوصفية (metadata) من الأعلى إلى الأسفل عند البحث عن المسارات وجلب البيانات الوصفية (metadata).';

  @override
  String get metadataProviderPriorityInfo =>
      'Deezer ليس لديه حدود للطلبات ومُوصى به كأساسي. Spotify لديه حد للطلبات وقد لا يعمل بعد عدة عمليات.';

  @override
  String get logTitle => 'السجلات';

  @override
  String get logCopied => 'تم نسخ السجلات إلى الحافظة';

  @override
  String get logSearchHint => 'البحث في السجلات...';

  @override
  String get logFilterLevel => 'المستوى';

  @override
  String get logFilterSection => 'فرز';

  @override
  String get logShareLogs => 'مشاركة السجلات';

  @override
  String get logClearLogs => 'حذف السجل';

  @override
  String get logClearLogsTitle => 'حذف السجل';

  @override
  String get logClearLogsMessage =>
      'هل أنت متأكد من رغبتك في مسح جميع السجلات؟';

  @override
  String get logFilterBySeverity => 'تصفية السجلات حسب الخطورة';

  @override
  String get logNoLogsYet => 'لا توجد سجلات بعد';

  @override
  String get logNoLogsYetSubtitle => 'ستظهر السجلات هنا عند استخدام التطبيق';

  @override
  String logEntriesFiltered(int count) {
    return 'الإدخالات ($count تم تصفيتها)';
  }

  @override
  String logEntries(int count) {
    return 'الإدخالات ($count)';
  }

  @override
  String get channelStable => 'مستقر';

  @override
  String get channelPreview => 'تجريبي';

  @override
  String get sectionSearchSource => 'مصدر البحث';

  @override
  String get sectionDownload => 'التحميل';

  @override
  String get sectionPerformance => 'الأداء';

  @override
  String get sectionApp => 'التطبيق';

  @override
  String get sectionData => 'البيانات';

  @override
  String get sectionDebug => 'تصحيح الأخطاء';

  @override
  String get sectionService => 'الخدمة';

  @override
  String get sectionAudioQuality => 'جودة الصوت';

  @override
  String get sectionFileSettings => 'إعدادات الملف';

  @override
  String get sectionLyrics => 'كلمات الاغنية';

  @override
  String get lyricsMode => 'وضع كلمات الأغنية';

  @override
  String get lyricsModeDescription =>
      'اختر كيفية حفظ كلمات الأغاني مع التنزيلات الخاصة بك';

  @override
  String get lyricsModeEmbed => 'تضمين في الملف';

  @override
  String get lyricsModeEmbedSubtitle =>
      'كلمات الأغاني مخزنة داخل بيانات تعريف FLAC';

  @override
  String get lyricsModeExternal => 'ملف .lrc منفصل';

  @override
  String get lyricsModeExternalSubtitle =>
      'فصل ملف .lrc لمشغلي الأغاني مثل Samsung Music';

  @override
  String get lyricsModeBoth => 'كلاهما';

  @override
  String get lyricsModeBothSubtitle => 'تضمين وحفظ ملف .lrc';

  @override
  String get sectionColor => 'اللون';

  @override
  String get sectionTheme => 'الثيم';

  @override
  String get sectionLayout => 'التخطيط';

  @override
  String get sectionLanguage => 'اللّغة';

  @override
  String get appearanceLanguage => 'لغة التطبيق';

  @override
  String get settingsAppearanceSubtitle => 'السمة والألوان والعرض';

  @override
  String get settingsDownloadSubtitle => 'الخدمة والجودة الأحتياطات';

  @override
  String get settingsExtensionsSubtitle => 'إدارة موفري التحميل';

  @override
  String get settingsLogsSubtitle => 'عرض سجلات التطبيقات لتصحيح الأخطاء';

  @override
  String get loadingSharedLink => 'تحميل الرابط المشترك...';

  @override
  String get pressBackAgainToExit => 'اضغط رجوع مجددًا للخروج';

  @override
  String downloadAllCount(int count) {
    return 'تنزيل الكل ($count)';
  }

  @override
  String tracksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أغانٍ',
      one: 'أغنية واحدة',
      zero: 'لا توجد أغاني محددة',
    );
    return '$_temp0';
  }

  @override
  String get trackCopyFilePath => 'نسخ مسار الملف';

  @override
  String get trackRemoveFromDevice => 'حذف من الجهاز';

  @override
  String get trackLoadLyrics => 'تحميل كلمات الأغاني';

  @override
  String get trackMetadata => 'البيانات الوصفية (Metadata)';

  @override
  String get trackFileInfo => 'معلومات الملف';

  @override
  String get trackLyrics => 'كلمات الاغنية';

  @override
  String get trackFileNotFound => 'لم يتم العثور على الملف';

  @override
  String get trackOpenInDeezer => 'فتح في Deezer';

  @override
  String get trackOpenInSpotify => 'فتح في Spotify';

  @override
  String get trackTrackName => 'اسم الأغنية';

  @override
  String get trackArtist => 'الفنان';

  @override
  String get trackAlbumArtist => 'فنان الألبوم';

  @override
  String get trackAlbum => 'الألبوم';

  @override
  String get trackTrackNumber => 'رقم الأغنية';

  @override
  String get trackDiscNumber => 'رقم القرص';

  @override
  String get trackDuration => 'المدة';

  @override
  String get trackAudioQuality => 'جودة الصوت';

  @override
  String get trackReleaseDate => 'تاريخ الإصدار';

  @override
  String get trackGenre => 'النوع';

  @override
  String get trackLabel => 'تصنيف';

  @override
  String get trackCopyright => 'حقوق الطبع و النشر';

  @override
  String get trackDownloaded => 'تم التنزيل';

  @override
  String get trackCopyLyrics => 'نسخ كلمات الأغنية';

  @override
  String trackLyricsSource(String source) {
    return 'المصدر: $source';
  }

  @override
  String get trackLyricsNotAvailable => 'كلمات الأغنية غير متوفرة لهذه الأغنية';

  @override
  String get trackLyricsNotInFile =>
      'لم يتم العثور على كلمات الأغاني في هذا الملف';

  @override
  String get trackFetchOnlineLyrics => 'جلب من الإنترنت';

  @override
  String get trackLyricsTimeout => 'انتهت مهلة الطلب. حاول مرة أخرى لاحقاً.';

  @override
  String get trackLyricsLoadFailed => 'فشل تحميل كلمات الأغاني';

  @override
  String get trackEmbedLyrics => 'تضمين كلمات الأغنية';

  @override
  String get trackLyricsEmbedded => 'تمت إضافة كلمات الأغنية بنجاح';

  @override
  String get trackInstrumental => 'المسار الآلي';

  @override
  String get trackCopiedToClipboard => 'تم النسخ إلى الحافظة';

  @override
  String get trackDeleteConfirmTitle => 'حذف من الجهاز؟';

  @override
  String get trackDeleteConfirmMessage =>
      'سيؤدي هذا إلى حذف الملف الذي تم تنزيله وإزالته من السجل الخاص بك بشكل دائم.';

  @override
  String get dateToday => 'اليوم';

  @override
  String get dateYesterday => 'الأمس';

  @override
  String dateDaysAgo(int count) {
    return 'قبل $count أيام';
  }

  @override
  String dateWeeksAgo(int count) {
    return 'قبل $count أسابيع';
  }

  @override
  String dateMonthsAgo(int count) {
    return 'منذ $count أشهر';
  }

  @override
  String get storeFilterAll => 'الكل';

  @override
  String get storeFilterMetadata => 'البيانات الوصفية (Metadata)';

  @override
  String get storeFilterDownload => 'التحميل';

  @override
  String get storeFilterUtility => 'الأدوات';

  @override
  String get storeFilterLyrics => 'كلمات الأغنية';

  @override
  String get storeFilterIntegration => 'التكامل';

  @override
  String get storeClearFilters => 'حذف الفلاتر';

  @override
  String get storeAddRepoTitle => 'إضافة مستودع إضافات';

  @override
  String get storeAddRepoDescription =>
      'أدخل عنوان مستودع GitHub الذي يحتوي على ملف registry.json لتصفح وتثبيت الإضافات.';

  @override
  String get storeRepoUrlLabel => 'رابط المستودع';

  @override
  String get storeRepoUrlHint => 'https://github.com/user/repo';

  @override
  String get storeAddRepoButton => 'أضف مستودعًا';

  @override
  String get storeChangeRepoTooltip => 'تغيير المستودع';

  @override
  String get storeRepoDialogTitle => 'مستودع الإضافات';

  @override
  String get storeRepoDialogCurrent => 'المستودع الحالي:';

  @override
  String get storeNewRepoUrlLabel => 'رابط المستودع';

  @override
  String get storeLoadError => 'فشل تحميل المستودع';

  @override
  String get storeEmptyNoExtensions => 'لا توجد إضافات متاحة';

  @override
  String get storeEmptyNoResults => 'لم يتم العثور على إضافات';

  @override
  String get extensionId => 'ID';

  @override
  String get extensionError => 'خطأ';

  @override
  String get extensionCapabilities => 'الإمكانيات';

  @override
  String get extensionMetadataProvider => 'مزود بيانات التعريف';

  @override
  String get extensionDownloadProvider => 'مزود التحميل';

  @override
  String get extensionLyricsProvider => 'موفر كلمات الأغاني';

  @override
  String get extensionUrlHandler => 'معالج الروابط';

  @override
  String get extensionQualityOptions => 'خيارات الجودة';

  @override
  String get extensionPostProcessingHooks => 'روابط المعالجة اللاحقة';

  @override
  String get extensionPermissions => 'الصلاحيات';

  @override
  String get extensionSettings => 'الإعدادات';

  @override
  String get extensionRemoveButton => 'حذف الإضافة';

  @override
  String get extensionUpdated => 'تاريخ التحديث';

  @override
  String get extensionMinAppVersion => 'اصدار التطبيق الأدنى';

  @override
  String get extensionCustomTrackMatching => 'مطابقة المسار المخصص';

  @override
  String get extensionPostProcessing => 'مرحلة ما بعد المعالجة';

  @override
  String extensionHooksAvailable(int count) {
    return 'متاح $count روابط';
  }

  @override
  String extensionPatternsCount(int count) {
    return '$count أنماط';
  }

  @override
  String extensionStrategy(String strategy) {
    return 'الاستراتيجية: $strategy';
  }

  @override
  String get extensionsProviderPrioritySection => 'أولوية مزود الخدمة';

  @override
  String get extensionsInstalledSection => 'الإضافات المُثبّتة';

  @override
  String get extensionsNoExtensions => 'لا توجد إضافات مثبتة';

  @override
  String get extensionsNoExtensionsSubtitle =>
      'تثبيت ملفات .spotiflac-ext لإضافة موفرين جدد';

  @override
  String get extensionsInstallButton => 'تثبيت الإضافة';

  @override
  String get extensionsInfoTip =>
      'يمكن للإضافات تزويدك بموفري بيانات التعريف الجديدة وتحميلها. ثبت الإضافات من مصادر موثوق بها فقط.';

  @override
  String get extensionsInstalledSuccess => 'تم تثبيت الإضافة بنجاح';

  @override
  String extensionsInstalledCount(int count) {
    return 'تم تثبيت $count إضافات بنجاح';
  }

  @override
  String extensionsInstallPartialSuccess(int installed, int attempted) {
    return 'تم تثبيت $installed من أصل $attempted إضافات';
  }

  @override
  String get extensionsDownloadPriority => 'أولوية التحميل';

  @override
  String get extensionsDownloadPrioritySubtitle => 'تعيين ترتيب خدمة التحميل';

  @override
  String get extensionsFallbackTitle => 'الإضافات الاحتياطية';

  @override
  String get extensionsFallbackSubtitle =>
      'اختر إضافات التحميل المثبتة التي يمكن استخدامها أثناء الرجوع التلقائي للمزود الاحتياطي';

  @override
  String get extensionsNoDownloadProvider =>
      'لا توجد إضافات مع إمكانية مزود التحميل';

  @override
  String get extensionsMetadataPriority => 'أولوية البيانات الوصفية (metadata)';

  @override
  String get extensionsMetadataPrioritySubtitle =>
      'تعيين ترتيب مصدر البحث والبيانات الوصفية';

  @override
  String get extensionsNoMetadataProvider =>
      'لا توجد إضافات مع إمكانية مزود البيانات الوصفية';

  @override
  String get extensionsSearchProvider => 'Search Provider';

  @override
  String get extensionsNoCustomSearch => 'No extensions with custom search';

  @override
  String get extensionsSearchProviderDescription =>
      'Choose which service to use for searching tracks';

  @override
  String get extensionsCustomSearch => 'Custom search';

  @override
  String get extensionsErrorLoading => 'Error loading extension';

  @override
  String get qualityFlacLossless => 'FLAC Lossless';

  @override
  String get qualityFlacLosslessSubtitle => '16-bit / 44.1kHz';

  @override
  String get qualityHiResFlac => 'Hi-Res FLAC';

  @override
  String get qualityHiResFlacSubtitle => '24 بت / ما يصل إلى 96 كيلو هرتز';

  @override
  String get qualityHiResFlacMax => 'Hi-Res FLAC Max';

  @override
  String get qualityHiResFlacMaxSubtitle => '24 بت / ما يصل إلى 192 كيلو هرتز';

  @override
  String get downloadLossy320 => '320kbps مضغوط';

  @override
  String get downloadLossyFormat => 'تنسيق مضغوط';

  @override
  String get downloadLossy320Format => 'تنسيق 320kbps مضغوط';

  @override
  String get downloadLossy320FormatDesc =>
      'اختر التنسيق النهائي للتنزيلات المضغوطة 320kbps. سيتم تحويل البث الأصلي إلى التنسيق المحدد عند الحاجة.';

  @override
  String get downloadLossyMp3 => 'MP3 320kbps';

  @override
  String get downloadLossyMp3Subtitle => 'أفضل توافق، ~10 ميغابايت لكل أغنية';

  @override
  String get downloadLossyAac => 'AAC/M4A 320kbps';

  @override
  String get downloadLossyAacSubtitle => 'أفضل توافق للجوال، صيغة M4A';

  @override
  String get downloadLossyOpus256 => 'Opus 256kbps';

  @override
  String get downloadLossyOpus256Subtitle =>
      'أفضل جودة Opus, حوالي 8 ميغابايت لكل أغنية';

  @override
  String get downloadLossyOpus128 => 'Opus 128kbps';

  @override
  String get downloadLossyOpus128Subtitle => 'أصغر حجم, ~4 ميغابايت لكل مسار';

  @override
  String get downloadAskBeforeDownload => 'اسأل قبل التحميل';

  @override
  String get downloadDirectory => 'مسار التنزيل';

  @override
  String get downloadSeparateSinglesFolder => 'فصل مجلد الفرديات';

  @override
  String get downloadAlbumFolderStructure => 'هيكل مجلد الألبوم';

  @override
  String get albumFolderStructureDescription =>
      'Choose how album folders are structured';

  @override
  String get downloadUseAlbumArtistForFolders =>
      'استخدام فنان الألبوم للمجلدات';

  @override
  String get downloadUsePrimaryArtistOnly => 'الفنان الأساسي فقط للمجلدات';

  @override
  String get downloadUsePrimaryArtistOnlyEnabled =>
      'الفنانين المتميزين الذين تمت إزالتهم من اسم المجلد (على سبيل المثال جاستين بيبر، كويفو -> جاستين بيبر)';

  @override
  String get downloadUsePrimaryArtistOnlyDisabled =>
      'اسم الفنان الكامل المستخدمة لاسم المجلد';

  @override
  String get downloadSelectQuality => 'تحديد الجودة';

  @override
  String get downloadFrom => 'تحميل من';

  @override
  String get appearanceAmoledDark => 'الوضع الداكن AMOLED';

  @override
  String get appearanceAmoledDarkSubtitle => 'خلفية سوداء تامة';

  @override
  String get appearanceHeroAnimations => 'Hero animations';

  @override
  String get appearanceHeroAnimationsSubtitle =>
      'Fly covers between screens, e.g. when opening the player';

  @override
  String get queueClearAll => 'مسح الكل';

  @override
  String get queueClearAllMessage =>
      'هل أنت متأكد من أنك تريد مسح جميع التنزيلات؟';

  @override
  String get settingsAutoExportFailed => 'فشل التصدير التلقائي للتنزيلات';

  @override
  String get settingsAutoExportFailedSubtitle =>
      'حفظ التنزيلات التي فشلت إلى ملف TXT تلقائيًا';

  @override
  String get settingsDownloadNetwork => 'تحميل الشبكة';

  @override
  String get settingsDownloadNetworkAny => 'WiFi + بيانات الجوال';

  @override
  String get settingsDownloadNetworkWifiOnly => 'WiFi فقط';

  @override
  String get settingsDownloadNetworkSubtitle =>
      'اختر الشبكة التي تريد استخدامها للتنزيلات. عند تعيين WiFi فقط، التنزيلات لن تعمل على بيانات الجوال.';

  @override
  String get settingsConcurrentDownloads => 'Concurrent downloads';

  @override
  String get settingsConcurrentDownloadsSubtitle =>
      'Downloading several tracks at once is faster, but some providers may rate-limit parallel requests.';

  @override
  String get concurrentDownloadsOne => '1 track at a time';

  @override
  String concurrentDownloadsCount(int count) {
    return 'Up to $count tracks at once';
  }

  @override
  String get albumFolderArtistAlbum => 'ألبوم / الفنان';

  @override
  String get albumFolderArtistAlbumSubtitle =>
      'الألبومات / اسم الفنان / اسم الألبوم';

  @override
  String get albumFolderArtistYearAlbum => 'الفنان / [Year] ألبوم';

  @override
  String get albumFolderArtistYearAlbumSubtitle =>
      'الألبومات/اسم الفنان /[2005] اسم الألبوم/';

  @override
  String get albumFolderAlbumOnly => 'الألبوم فقط';

  @override
  String get albumFolderAlbumOnlySubtitle => 'الألبومات/اسم الألبوم/';

  @override
  String get albumFolderYearAlbum => '[Year] الألبوم';

  @override
  String get albumFolderYearAlbumSubtitle => 'الألبومات/[2005] اسم الألبوم/';

  @override
  String get albumFolderArtistAlbumSingles => 'الفنان / الألبوم + المفردات';

  @override
  String get albumFolderArtistAlbumSinglesSubtitle =>
      'الفنان/الألبوم  و  الفنان / المفردات';

  @override
  String get albumFolderArtistAlbumFlat => 'فنان / ألبوم (منفردات سطحية)';

  @override
  String get albumFolderArtistAlbumFlatSubtitle =>
      'الفنان / الألبوم  والفنان / الأغنية.flac';

  @override
  String get downloadedAlbumDeleteSelected => 'Delete Selected';

  @override
  String downloadedAlbumDeleteMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tracks',
      one: 'track',
    );
    return 'Delete $count $_temp0 from this album?\n\nThis will also delete the files from storage.';
  }

  @override
  String downloadedAlbumSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get downloadedAlbumTapToSelect => 'Tap tracks to select';

  @override
  String downloadedAlbumDeleteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tracks',
      one: 'track',
    );
    return 'Delete $count $_temp0';
  }

  @override
  String get downloadedAlbumSelectToDelete => 'Select tracks to delete';

  @override
  String downloadedAlbumDiscHeader(int discNumber) {
    return 'Disc $discNumber';
  }

  @override
  String get recentTypeArtist => 'Artist';

  @override
  String get recentTypeAlbum => 'Album';

  @override
  String get recentTypeSong => 'Song';

  @override
  String get recentTypePlaylist => 'Playlist';

  @override
  String get recentEmpty => 'No recent items yet';

  @override
  String get recentShowAllDownloads => 'Show All Downloads';

  @override
  String recentPlaylistInfo(String name) {
    return 'Playlist: $name';
  }

  @override
  String get discographyDownload => 'Download Discography';

  @override
  String get discographyDownloadAll => 'Download All';

  @override
  String discographyDownloadAllSubtitle(int count, int albumCount) {
    return '$count tracks from $albumCount releases';
  }

  @override
  String get discographyAlbumsOnly => 'Albums Only';

  @override
  String discographyAlbumsOnlySubtitle(int count, int albumCount) {
    return '$count tracks from $albumCount albums';
  }

  @override
  String get discographySinglesOnly => 'Singles & EPs Only';

  @override
  String discographySinglesOnlySubtitle(int count, int albumCount) {
    return '$count tracks from $albumCount singles';
  }

  @override
  String get discographySelectAlbums => 'Select Albums...';

  @override
  String get discographySelectAlbumsSubtitle =>
      'Choose specific albums or singles';

  @override
  String get discographyFetchingTracks => 'Fetching tracks...';

  @override
  String discographyFetchingAlbum(int current, int total) {
    return 'Fetching $current of $total...';
  }

  @override
  String discographySelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get discographyDownloadSelected => 'Download Selected';

  @override
  String discographyAddedToQueue(int count) {
    return 'Added $count tracks to queue';
  }

  @override
  String discographySkippedDownloaded(int added, int skipped) {
    return '$added added, $skipped already downloaded';
  }

  @override
  String get discographyNoAlbums => 'No albums available';

  @override
  String get discographyFailedToFetch => 'Failed to fetch some albums';

  @override
  String get sectionStorageAccess => 'Storage Access';

  @override
  String get allFilesAccess => 'All Files Access';

  @override
  String get allFilesAccessEnabledSubtitle => 'Can write to any folder';

  @override
  String get allFilesAccessDisabledSubtitle => 'Limited to media folders only';

  @override
  String get allFilesAccessDescription =>
      'Enable this if you encounter write errors when saving to custom folders. Android 13+ restricts access to certain directories by default.';

  @override
  String get allFilesAccessDeniedMessage =>
      'Permission was denied. Please enable \'All files access\' manually in system settings.';

  @override
  String get allFilesAccessDisabledMessage =>
      'All Files Access disabled. The app will use limited storage access.';

  @override
  String get settingsLocalLibrary => 'Local Library';

  @override
  String get settingsLocalLibrarySubtitle => 'Scan music & detect duplicates';

  @override
  String get settingsCache => 'Storage & Cache';

  @override
  String get settingsCacheSubtitle => 'View size and clear cached data';

  @override
  String get libraryTitle => 'Local Library';

  @override
  String get libraryScanSettings => 'Scan Settings';

  @override
  String get libraryEnableLocalLibrary => 'Enable Local Library';

  @override
  String get libraryEnableLocalLibrarySubtitle =>
      'Scan and track your existing music';

  @override
  String get libraryFolder => 'Library Folder';

  @override
  String get libraryFolderHint => 'Tap to select folder';

  @override
  String get libraryShowDuplicateIndicator => 'Show Duplicate Indicator';

  @override
  String get libraryShowDuplicateIndicatorSubtitle =>
      'Show when searching for existing tracks';

  @override
  String get libraryAutoScan => 'Auto Scan';

  @override
  String get libraryAutoScanSubtitle =>
      'Automatically scan your library for new files';

  @override
  String get libraryAutoScanOff => 'Off';

  @override
  String get libraryAutoScanOnOpen => 'Every app open';

  @override
  String get libraryAutoScanDaily => 'Daily';

  @override
  String get libraryAutoScanWeekly => 'Weekly';

  @override
  String get libraryActions => 'Actions';

  @override
  String get libraryScan => 'Scan Library';

  @override
  String get libraryScanSubtitle => 'Scan for audio files';

  @override
  String get libraryScanSelectFolderFirst => 'Select a folder first';

  @override
  String get libraryCleanupMissingFiles => 'Cleanup Missing Files';

  @override
  String get libraryCleanupMissingFilesSubtitle =>
      'Remove entries for files that no longer exist';

  @override
  String get libraryClear => 'Clear Library';

  @override
  String get libraryClearSubtitle => 'Remove all scanned tracks';

  @override
  String get libraryClearConfirmTitle => 'Clear Library';

  @override
  String get libraryClearConfirmMessage =>
      'This will remove all scanned tracks from your library. Your actual music files will not be deleted.';

  @override
  String get libraryAbout => 'About Local Library';

  @override
  String get libraryAboutDescription =>
      'Scans your existing music collection to detect duplicates when downloading. Supports FLAC, M4A, MP3, Opus, and OGG formats. Metadata is read from file tags when available.';

  @override
  String libraryTracksUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tracks',
      one: 'track',
    );
    return '$_temp0';
  }

  @override
  String libraryFilesUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'files',
      one: 'file',
    );
    return '$_temp0';
  }

  @override
  String libraryLastScanned(String time) {
    return 'Last scanned: $time';
  }

  @override
  String get libraryLastScannedNever => 'Never';

  @override
  String get libraryScanning => 'Scanning...';

  @override
  String get libraryScanFinalizing => 'Finalizing library...';

  @override
  String libraryScanProgress(String progress, int total) {
    return '$progress% of $total files';
  }

  @override
  String get libraryInLibrary => 'In Library';

  @override
  String libraryRemovedMissingFiles(int count) {
    return 'Removed $count missing files from library';
  }

  @override
  String get libraryCleared => 'Library cleared';

  @override
  String get libraryStorageAccessRequired => 'Storage Access Required';

  @override
  String get libraryStorageAccessMessage =>
      'SpotiFLAC needs storage access to scan your music library. Please grant permission in settings.';

  @override
  String get libraryFolderNotExist => 'Selected folder does not exist';

  @override
  String get librarySourceDownloaded => 'Downloaded';

  @override
  String get librarySourceLocal => 'Local';

  @override
  String get libraryFilterAll => 'All';

  @override
  String get libraryFilterDownloaded => 'Downloaded';

  @override
  String get libraryFilterLocal => 'Local';

  @override
  String get libraryFilterTitle => 'Filters';

  @override
  String get libraryFilterReset => 'Reset';

  @override
  String get libraryFilterApply => 'Apply';

  @override
  String get libraryFilterSource => 'Source';

  @override
  String get libraryFilterQuality => 'Quality';

  @override
  String get libraryFilterQualityHiRes => 'Hi-Res (24bit)';

  @override
  String get libraryFilterQualityCD => 'CD (16bit)';

  @override
  String get libraryFilterQualityLossy => 'Lossy';

  @override
  String get libraryFilterFormat => 'Format';

  @override
  String get libraryFilterMetadata => 'Metadata';

  @override
  String get libraryFilterMetadataComplete => 'Complete metadata';

  @override
  String get libraryFilterMetadataMissingAny => 'Missing any metadata';

  @override
  String get libraryFilterMetadataMissingYear => 'Missing year';

  @override
  String get libraryFilterMetadataMissingGenre => 'Missing genre';

  @override
  String get libraryFilterMetadataMissingAlbumArtist => 'Missing album artist';

  @override
  String get libraryFilterSort => 'Sort';

  @override
  String get libraryFilterSortLatest => 'Latest';

  @override
  String get libraryFilterSortOldest => 'Oldest';

  @override
  String get libraryFilterSortAlbumAsc => 'Album (A-Z)';

  @override
  String get libraryFilterSortAlbumDesc => 'Album (Z-A)';

  @override
  String get libraryFilterSortGenreAsc => 'Genre (A-Z)';

  @override
  String get libraryFilterSortGenreDesc => 'Genre (Z-A)';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get tutorialWelcomeTitle => 'Welcome to SpotiFLAC!';

  @override
  String get tutorialWelcomeDesc =>
      'Let\'s learn how to download your favorite music in lossless quality. This quick tutorial will show you the basics.';

  @override
  String get tutorialWelcomeTip1 =>
      'Download music from Spotify, Deezer, or paste any supported URL';

  @override
  String get tutorialWelcomeTip2 =>
      'Get FLAC quality audio from installed download extensions';

  @override
  String get tutorialWelcomeTip3 =>
      'Automatic metadata, cover art, and lyrics embedding';

  @override
  String get tutorialSearchTitle => 'Finding Music';

  @override
  String get tutorialSearchDesc =>
      'There are two easy ways to find music you want to download.';

  @override
  String get tutorialDownloadTitle => 'Downloading Music';

  @override
  String get tutorialDownloadDesc =>
      'Downloading music is simple and fast. Here\'s how it works.';

  @override
  String get tutorialLibraryTitle => 'Your Library';

  @override
  String get tutorialLibraryDesc =>
      'All your downloaded music is organized in the Library tab.';

  @override
  String get tutorialLibraryTip1 =>
      'View download progress and queue in the Library tab';

  @override
  String get tutorialLibraryTip2 =>
      'Tap any track to play it with your music player';

  @override
  String get tutorialLibraryTip3 =>
      'Switch between list and grid view for better browsing';

  @override
  String get tutorialExtensionsTitle => 'Extensions';

  @override
  String get tutorialExtensionsDesc =>
      'Extend the app\'s capabilities with community extensions.';

  @override
  String get tutorialExtensionsTip1 =>
      'Browse the Repo tab to discover useful extensions';

  @override
  String get tutorialExtensionsTip2 =>
      'Add new download providers or search sources';

  @override
  String get tutorialExtensionsTip3 =>
      'Get lyrics, enhanced metadata, and more features';

  @override
  String get tutorialSettingsTitle => 'Customize Your Experience';

  @override
  String get tutorialSettingsDesc =>
      'Personalize the app in Settings to match your preferences.';

  @override
  String get tutorialSettingsTip1 =>
      'Change download location and folder organization';

  @override
  String get tutorialSettingsTip2 =>
      'Set default audio quality and format preferences';

  @override
  String get tutorialSettingsTip3 => 'Customize app theme and appearance';

  @override
  String get tutorialReadyMessage =>
      'You\'re all set! Start downloading your favorite music now.';

  @override
  String get libraryForceFullScan => 'Force Full Scan';

  @override
  String get libraryForceFullScanSubtitle => 'Rescan all files, ignoring cache';

  @override
  String get cleanupOrphanedDownloads => 'Cleanup Orphaned Downloads';

  @override
  String get cleanupOrphanedDownloadsSubtitle =>
      'Remove history entries for files that no longer exist';

  @override
  String cleanupOrphanedDownloadsResult(int count) {
    return 'Removed $count orphaned entries from history';
  }

  @override
  String get cleanupOrphanedDownloadsNone => 'No orphaned entries found';

  @override
  String get cacheTitle => 'Storage & Cache';

  @override
  String get cacheSummaryTitle => 'Cache overview';

  @override
  String get cacheSummarySubtitle =>
      'Clearing cache will not remove downloaded music files.';

  @override
  String cacheEstimatedTotal(String size) {
    return 'Estimated cache usage: $size';
  }

  @override
  String get cacheSectionStorage => 'Cached Data';

  @override
  String get cacheSectionMaintenance => 'Maintenance';

  @override
  String get cacheAppDirectory => 'App cache directory';

  @override
  String get cacheAppDirectoryDesc =>
      'HTTP responses, WebView data, and other temporary app data.';

  @override
  String get cacheTempDirectory => 'Temporary directory';

  @override
  String get cacheTempDirectoryDesc =>
      'Temporary files from downloads and audio conversion.';

  @override
  String get cacheCoverImage => 'Cover image cache';

  @override
  String get cacheCoverImageDesc =>
      'Downloaded album and track cover art. Will re-download when viewed.';

  @override
  String get cacheLibraryCover => 'Library cover cache';

  @override
  String get cacheLibraryCoverDesc =>
      'Cover art extracted from local music files. Will re-extract on next scan.';

  @override
  String get libraryPlaybackNormalization => 'Volume normalization';

  @override
  String get libraryPlaybackNormalizationSubtitle =>
      'Even out loudness between tracks using their ReplayGain or R128 tags, when present';

  @override
  String get cacheAudioAnalysis => 'Audio analysis cache';

  @override
  String get cacheAudioAnalysisDesc =>
      'Saved spectrograms and analysis results. Will re-analyze on next open.';

  @override
  String get cacheExploreFeed => 'Explore feed cache';

  @override
  String get cacheExploreFeedDesc =>
      'Explore tab content (new releases, trending). Will refresh on next visit.';

  @override
  String get cacheTrackLookup => 'Track lookup cache';

  @override
  String get cacheTrackLookupDesc =>
      'Spotify/Deezer track ID lookups. Clearing may slow next few searches.';

  @override
  String get cacheCleanupUnusedDesc =>
      'Remove orphaned download history and library entries for missing files.';

  @override
  String get cacheNoData => 'No cached data';

  @override
  String cacheSizeWithFiles(String size, int count) {
    return '$size in $count files';
  }

  @override
  String cacheSizeOnly(String size) {
    return '$size';
  }

  @override
  String cacheEntries(int count) {
    return '$count entries';
  }

  @override
  String cacheClearSuccess(String target) {
    return 'Cleared: $target';
  }

  @override
  String get cacheClearConfirmTitle => 'Clear cache?';

  @override
  String cacheClearConfirmMessage(String target) {
    return 'This will clear cached data for $target. Downloaded music files will not be deleted.';
  }

  @override
  String get cacheClearAllConfirmTitle => 'Clear all cache?';

  @override
  String get cacheClearAllConfirmMessage =>
      'This will clear all cache categories on this page. Downloaded music files will not be deleted.';

  @override
  String get cacheClearAll => 'Clear all cache';

  @override
  String get cacheCleanupUnused => 'Cleanup unused data';

  @override
  String get cacheCleanupUnusedSubtitle =>
      'Remove orphaned download history and missing library entries';

  @override
  String cacheCleanupResult(int downloadCount, int libraryCount) {
    return 'Cleanup completed: $downloadCount orphaned downloads, $libraryCount missing library entries';
  }

  @override
  String get cacheRefreshStats => 'Refresh stats';

  @override
  String get trackSaveCoverArt => 'Save Cover Art';

  @override
  String get trackSaveLyrics => 'Save Lyrics (.lrc)';

  @override
  String get trackSaveLyricsProgress => 'Saving lyrics...';

  @override
  String get trackReEnrich => 'Re-enrich';

  @override
  String get trackReEnrichOnlineSubtitle =>
      'Search metadata online and embed into file';

  @override
  String get trackReEnrichFieldCover => 'Cover Art';

  @override
  String get trackReEnrichFieldLyrics => 'Lyrics';

  @override
  String get trackReEnrichFieldBasicTags => 'Album, Album Artist';

  @override
  String get trackReEnrichFieldTrackInfo => 'Track & Disc Number';

  @override
  String get trackReEnrichFieldReleaseInfo => 'Date & ISRC';

  @override
  String get trackReEnrichFieldExtra => 'Genre, Label, Copyright';

  @override
  String get trackReEnrichSelectAll => 'Select All';

  @override
  String get trackEditMetadata => 'Edit Metadata';

  @override
  String trackCoverSaved(String fileName) {
    return 'Cover art saved to $fileName';
  }

  @override
  String get trackCoverNoSource => 'No cover art source available';

  @override
  String trackLyricsSaved(String fileName) {
    return 'Lyrics saved to $fileName';
  }

  @override
  String get trackReEnrichProgress => 'Re-enriching metadata...';

  @override
  String get trackReEnrichSearching => 'Searching metadata online...';

  @override
  String get trackReEnrichSuccess => 'Metadata re-enriched successfully';

  @override
  String get trackReEnrichFfmpegFailed => 'FFmpeg metadata embed failed';

  @override
  String get queueFlacAction => 'Queue FLAC';

  @override
  String queueFlacConfirmMessage(int count) {
    return 'Search online matches for the selected tracks and queue FLAC downloads.\n\nExisting files will not be modified or deleted.\n\nOnly high-confidence matches are queued automatically.\n\n$count selected';
  }

  @override
  String get queueFlacNoReliableMatches =>
      'No reliable online matches found for the selection';

  @override
  String queueFlacQueuedWithSkipped(int addedCount, int skippedCount) {
    return 'Added $addedCount tracks to queue, skipped $skippedCount';
  }

  @override
  String trackSaveFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get trackConvertFormat => 'Convert Format';

  @override
  String get trackConvertTitle => 'Convert Audio';

  @override
  String get trackConvertTargetFormat => 'Target Format';

  @override
  String get trackConvertBitrate => 'Bitrate';

  @override
  String get trackConvertConfirmTitle => 'Confirm Conversion';

  @override
  String trackConvertConfirmMessage(
    String sourceFormat,
    String targetFormat,
    String bitrate,
  ) {
    return 'Convert from $sourceFormat to $targetFormat at $bitrate?\n\nThe original file will be deleted after conversion.';
  }

  @override
  String trackConvertConfirmMessageLossless(
    String sourceFormat,
    String targetFormat,
  ) {
    return 'Convert from $sourceFormat to $targetFormat? (Lossless — no quality loss)\n\nThe original file will be deleted after conversion.';
  }

  @override
  String get trackConvertLosslessHint =>
      'Lossless conversion — no quality loss';

  @override
  String get trackConvertConverting => 'Converting audio...';

  @override
  String trackConvertSuccess(String format) {
    return 'Converted to $format successfully';
  }

  @override
  String get trackConvertFailed => 'Conversion failed';

  @override
  String get cueSplitTitle => 'Split CUE Sheet';

  @override
  String cueSplitAlbum(String album) {
    return 'Album: $album';
  }

  @override
  String cueSplitArtist(String artist) {
    return 'Artist: $artist';
  }

  @override
  String cueSplitTrackCount(int count) {
    return '$count tracks';
  }

  @override
  String get cueSplitConfirmTitle => 'Split CUE Album';

  @override
  String cueSplitConfirmMessage(String album, int count) {
    return 'Split \"$album\" into $count individual FLAC files?\n\nFiles will be saved to the same directory.';
  }

  @override
  String cueSplitSplitting(int current, int total) {
    return 'Splitting CUE sheet... ($current/$total)';
  }

  @override
  String cueSplitSuccess(int count) {
    return 'Split into $count tracks successfully';
  }

  @override
  String get cueSplitFailed => 'CUE split failed';

  @override
  String get cueSplitNoAudioFile => 'Audio file not found for this CUE sheet';

  @override
  String get cueSplitButton => 'Split into Tracks';

  @override
  String get actionCreate => 'Create';

  @override
  String get collectionFoldersTitle => 'My folders';

  @override
  String get collectionWishlist => 'Wishlist';

  @override
  String get collectionLoved => 'Loved';

  @override
  String get collectionFavoriteArtists => 'Favorite Artists';

  @override
  String get collectionPlaylist => 'Playlist';

  @override
  String get collectionAddToPlaylist => 'Add to playlist';

  @override
  String get collectionCreatePlaylist => 'Create playlist';

  @override
  String get collectionNoPlaylistsYet => 'No playlists yet';

  @override
  String collectionPlaylistTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$_temp0';
  }

  @override
  String collectionArtistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artists',
      one: '1 artist',
    );
    return '$_temp0';
  }

  @override
  String collectionAddedToPlaylist(String playlistName) {
    return 'Added to \"$playlistName\"';
  }

  @override
  String collectionAlreadyInPlaylist(String playlistName) {
    return 'Already in \"$playlistName\"';
  }

  @override
  String get collectionPlaylistNameHint => 'Playlist name';

  @override
  String get collectionPlaylistNameRequired => 'Playlist name is required';

  @override
  String get collectionRenamePlaylist => 'Rename playlist';

  @override
  String get collectionDeletePlaylist => 'Delete playlist';

  @override
  String get collectionPlaylistRenamed => 'Playlist renamed';

  @override
  String get collectionWishlistEmptyTitle => 'Wishlist is empty';

  @override
  String get collectionWishlistEmptySubtitle =>
      'Tap + on tracks to save what you want to download later';

  @override
  String get collectionLovedEmptyTitle => 'Loved folder is empty';

  @override
  String get collectionLovedEmptySubtitle =>
      'Tap love on tracks to keep your favorites';

  @override
  String get collectionFavoriteArtistsEmptyTitle => 'No favorite artists yet';

  @override
  String get collectionFavoriteArtistsEmptySubtitle =>
      'Tap the heart on an artist page to keep them here';

  @override
  String get collectionPlaylistEmptyTitle => 'Playlist is empty';

  @override
  String get collectionPlaylistEmptySubtitle =>
      'Long-press + on any track to add it here';

  @override
  String get collectionRemoveFromPlaylist => 'Remove from playlist';

  @override
  String get collectionRemoveFromFolder => 'Remove from folder';

  @override
  String collectionAddedToLoved(String trackName) {
    return '\"$trackName\" added to Loved';
  }

  @override
  String collectionRemovedFromLoved(String trackName) {
    return '\"$trackName\" removed from Loved';
  }

  @override
  String collectionAddedToWishlist(String trackName) {
    return '\"$trackName\" added to Wishlist';
  }

  @override
  String collectionRemovedFromWishlist(String trackName) {
    return '\"$trackName\" removed from Wishlist';
  }

  @override
  String collectionAddedToFavoriteArtists(String artistName) {
    return '\"$artistName\" added to Favorite Artists';
  }

  @override
  String collectionRemovedFromFavoriteArtists(String artistName) {
    return '\"$artistName\" removed from Favorite Artists';
  }

  @override
  String get trackOptionAddToLoved => 'Add to Loved';

  @override
  String get trackOptionRemoveFromLoved => 'Remove from Loved';

  @override
  String get trackOptionAddToWishlist => 'Add to Wishlist';

  @override
  String get trackOptionRemoveFromWishlist => 'Remove from Wishlist';

  @override
  String get artistOptionAddToFavorites => 'Add to Favorite Artists';

  @override
  String get artistOptionRemoveFromFavorites => 'Remove from Favorite Artists';

  @override
  String get collectionPlaylistChangeCover => 'Change cover image';

  @override
  String get collectionPlaylistRemoveCover => 'Remove cover image';

  @override
  String selectionShareCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tracks',
      one: 'track',
    );
    return 'Share $count $_temp0';
  }

  @override
  String get selectionShareNoFiles => 'No shareable files found';

  @override
  String selectionConvertCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tracks',
      one: 'track',
    );
    return 'Convert $count $_temp0';
  }

  @override
  String get selectionConvertNoConvertible => 'No convertible tracks selected';

  @override
  String get selectionBatchConvertConfirmTitle => 'Batch Convert';

  @override
  String selectionBatchConvertConfirmMessage(
    int count,
    String format,
    String bitrate,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tracks',
      one: 'track',
    );
    return 'Convert $count $_temp0 to $format at $bitrate?\n\nOriginal files will be deleted after conversion.';
  }

  @override
  String selectionBatchConvertConfirmMessageLossless(int count, String format) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tracks',
      one: 'track',
    );
    return 'Convert $count $_temp0 to $format? (Lossless — no quality loss)\n\nOriginal files will be deleted after conversion.';
  }

  @override
  String selectionBatchConvertSuccess(int success, int total, String format) {
    return 'Converted $success of $total tracks to $format';
  }

  @override
  String downloadedAlbumDownloadedCount(int count) {
    return '$count downloaded';
  }

  @override
  String get downloadUseAlbumArtistForFoldersAlbumSubtitle =>
      'Folder named after Album Artist tag';

  @override
  String get downloadUseAlbumArtistForFoldersTrackSubtitle =>
      'Folder named after Track Artist tag';

  @override
  String get lyricsProvidersTitle => 'Lyrics Provider Priority';

  @override
  String get lyricsProvidersDescription =>
      'Enable, disable and reorder lyrics sources. Providers are tried top-to-bottom until lyrics are found.';

  @override
  String get lyricsProvidersInfoText =>
      'Extension lyrics providers run before built-in lyrics providers. At least one provider must remain enabled.';

  @override
  String lyricsProvidersEnabledSection(int count) {
    return 'Enabled ($count)';
  }

  @override
  String lyricsProvidersDisabledSection(int count) {
    return 'Disabled ($count)';
  }

  @override
  String get lyricsProvidersAtLeastOne =>
      'At least one provider must remain enabled';

  @override
  String get lyricsProvidersSaved => 'Lyrics provider priority saved';

  @override
  String get lyricsProvidersDiscardContent =>
      'You have unsaved changes that will be lost.';

  @override
  String get lyricsProviderLrclibDesc => 'Open-source synced lyrics database';

  @override
  String get lyricsProviderNeteaseDesc =>
      'NetEase Cloud Music (good for Asian songs)';

  @override
  String get lyricsProviderMusixmatchDesc =>
      'Largest lyrics database (multi-language)';

  @override
  String get lyricsProviderAppleMusicDesc =>
      'Word-by-word synced lyrics (via proxy)';

  @override
  String get lyricsProviderQqMusicDesc =>
      'QQ Music (good for Chinese songs, via proxy)';

  @override
  String get lyricsProviderLyricsPlusDesc =>
      'Word-by-word karaoke lyrics (Apple/Musixmatch/Spotify/QQ, via proxy)';

  @override
  String get lyricsProviderExtensionDesc => 'Extension provider';

  @override
  String get safMigrationTitle => 'Storage Update Required';

  @override
  String get safMigrationMessage1 =>
      'SpotiFLAC now uses Android Storage Access Framework (SAF) for downloads. This fixes \"permission denied\" errors on Android 10+.';

  @override
  String get safMigrationMessage2 =>
      'Please select your download folder again to switch to the new storage system.';

  @override
  String get safMigrationSuccess => 'Download folder updated to SAF mode';

  @override
  String get settingsDonate => 'Support Development';

  @override
  String get settingsDonateSubtitle => 'Buy the developer a coffee';

  @override
  String get settingsBackup => 'Backup & Restore';

  @override
  String get settingsBackupSubtitle =>
      'Move your library, history and settings to a new device';

  @override
  String get backupTitle => 'Backup & Restore';

  @override
  String get backupExportSectionTitle => 'Create backup';

  @override
  String get backupExportSectionDescription =>
      'Save your settings, download history, liked tracks, wishlist, favorite artists and playlists into a single file you can keep or move to another phone.';

  @override
  String get backupExportButton => 'Create backup file';

  @override
  String get backupImportSectionTitle => 'Restore backup';

  @override
  String get backupImportSectionDescription =>
      'Pick a backup file to restore your data. This replaces the current settings, history and library on this device.';

  @override
  String get backupImportButton => 'Choose backup file';

  @override
  String get backupCreated => 'Backup created';

  @override
  String get backupCreateFailed => 'Failed to create backup';

  @override
  String get backupRestoreConfirmTitle => 'Restore this backup?';

  @override
  String get backupRestoreConfirmMessage =>
      'This will replace your current settings, download history, liked tracks, wishlist and playlists with the contents of the backup. This cannot be undone.';

  @override
  String get backupRestoreConfirmButton => 'Restore';

  @override
  String get backupRestored => 'Backup restored successfully';

  @override
  String get backupRestoreFailed => 'Failed to restore backup';

  @override
  String get backupInvalidFile => 'This file is not a valid SpotiFLAC backup';

  @override
  String get backupRestoreRestartHint =>
      'Restart the app to make sure every change is applied.';

  @override
  String get backupContentsTitle => 'Backup contents';

  @override
  String get backupContentsSettings => 'App settings';

  @override
  String backupContentsHistory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'items',
      one: 'item',
    );
    return '$count history $_temp0';
  }

  @override
  String backupContentsLiked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tracks',
      one: 'track',
    );
    return '$count liked $_temp0';
  }

  @override
  String backupContentsWishlist(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tracks',
      one: 'track',
    );
    return '$count wishlist $_temp0';
  }

  @override
  String backupContentsPlaylists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists',
      one: '1 playlist',
    );
    return '$_temp0';
  }

  @override
  String backupContentsArtists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count favorite artists',
      one: '1 favorite artist',
    );
    return '$_temp0';
  }

  @override
  String backupContentsExtensions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count extensions',
      one: '1 extension',
    );
    return '$_temp0';
  }

  @override
  String get backupIncludeSecrets => 'Include extension credentials';

  @override
  String get backupIncludeSecretsDescription =>
      'Tokens and API keys from extensions will be saved into the backup file. Keep the file private. When off, you re-enter them after restoring.';

  @override
  String backupExtensionsRestoreFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'extensions',
      one: 'extension',
    );
    return '$count $_temp0 could not be reinstalled. Install them manually from the repo.';
  }

  @override
  String get tooltipLoveAll => 'Love All';

  @override
  String get tooltipAddToPlaylist => 'Add to Playlist';

  @override
  String snackbarRemovedTracksFromLoved(int count) {
    return 'Removed $count tracks from Loved';
  }

  @override
  String snackbarAddedTracksToLoved(int count) {
    return 'Added $count tracks to Loved';
  }

  @override
  String get dialogDownloadAllTitle => 'Download All';

  @override
  String dialogDownloadAllMessage(int count) {
    return 'Download $count tracks?';
  }

  @override
  String get homeSkipAlreadyDownloaded => 'Skip already downloaded songs';

  @override
  String get homeGoToAlbum => 'Go to Album';

  @override
  String get homeAlbumInfoUnavailable => 'Album info not available';

  @override
  String get snackbarLoadingCueSheet => 'Loading CUE sheet...';

  @override
  String get snackbarMetadataSaved => 'Metadata saved successfully';

  @override
  String get snackbarFailedToEmbedLyrics => 'Failed to embed lyrics';

  @override
  String get snackbarFailedToWriteStorage => 'Failed to write back to storage';

  @override
  String snackbarError(String error) {
    return 'Error: $error';
  }

  @override
  String get snackbarNoActionDefined => 'No action defined for this button';

  @override
  String get noTracksFoundForAlbum => 'No tracks found for this album';

  @override
  String get downloadLocationSubtitle =>
      'Choose where to save your downloaded tracks';

  @override
  String get storageModeAppFolder => 'App Folder (Recommended)';

  @override
  String get storageModeAppFolderSubtitle =>
      'Saves to Music/SpotiFLAC by default';

  @override
  String get storageModeSaf => 'Custom Folder (SAF)';

  @override
  String get storageModeSafSubtitle => 'Pick any folder, including SD card';

  @override
  String get downloadFolderAccessLostTitle => 'Download folder access lost';

  @override
  String get downloadFolderAccessLostSubtitle =>
      'Downloads will fail until you re-select the folder';

  @override
  String get downloadFolderReselect => 'Re-select folder';

  @override
  String get downloadErrorSafPermissionLost =>
      'SAF permission invalid or revoked. Please reconfigure download location in Settings.';

  @override
  String get downloadErrorFolderAccessLost =>
      'Download folder access lost. Please re-select your download folder in Settings.';

  @override
  String downloadFilenameDescription(
    Object album,
    Object artist,
    Object date,
    Object disc,
    Object title,
    Object track,
    Object year,
  ) {
    return 'Use $artist, $title, $album, $track, $year, $date, $disc as placeholders.';
  }

  @override
  String get downloadFilenameInsertTag => 'Tap to insert tag:';

  @override
  String get downloadSeparateSinglesEnabled =>
      'Singles and EPs saved in a separate folder';

  @override
  String get downloadSeparateSinglesDisabled =>
      'Singles and albums saved in the same folder';

  @override
  String get downloadArtistNameFilters => 'Artist Name Filters';

  @override
  String get downloadCreatePlaylistSourceFolder => 'Playlist Source Folder';

  @override
  String get downloadCreatePlaylistSourceFolderEnabled =>
      'A subfolder is created for each playlist';

  @override
  String get downloadCreatePlaylistSourceFolderDisabled =>
      'All tracks saved directly to download folder';

  @override
  String get downloadCreatePlaylistSourceFolderRedundant =>
      'Handled by folder organization setting';

  @override
  String get downloadSongLinkRegion => 'SongLink Region';

  @override
  String get downloadNetworkCompatibilityMode => 'Network Compatibility Mode';

  @override
  String get downloadNetworkCompatibilityModeEnabled =>
      'Using legacy TLS settings for older networks';

  @override
  String get downloadNetworkCompatibilityModeDisabled =>
      'Using standard network settings';

  @override
  String get downloadAllowLocalNetwork => 'Allow Local Network Access';

  @override
  String get downloadAllowLocalNetworkEnabled =>
      'Requests to local/private addresses are allowed (for local proxy or custom DNS)';

  @override
  String get downloadAllowLocalNetworkDisabled =>
      'Local/private addresses are blocked for security';

  @override
  String get downloadSelectServiceToEnable =>
      'Select a provider with quality options to enable this option';

  @override
  String get downloadEmbedLyricsDisabled => 'Enable metadata embedding first';

  @override
  String get downloadNeteaseIncludeTranslation =>
      'Netease: Include Translation';

  @override
  String get downloadNeteaseIncludeTranslationEnabled =>
      'Chinese translation lines included';

  @override
  String get downloadNeteaseIncludeTranslationDisabled =>
      'Original lyrics only';

  @override
  String get downloadNeteaseIncludeRomanization =>
      'Netease: Include Romanization';

  @override
  String get downloadNeteaseIncludeRomanizationEnabled =>
      'Romanization lines included';

  @override
  String get downloadNeteaseIncludeRomanizationDisabled => 'No romanization';

  @override
  String get downloadAppleQqMultiPerson => 'Apple / QQ: Multi-Person Lyrics';

  @override
  String get downloadAppleQqMultiPersonEnabled =>
      'Speaker labels included for duets and group tracks';

  @override
  String get downloadAppleQqMultiPersonDisabled =>
      'Standard lyrics without speaker labels';

  @override
  String get downloadAppleElrcWordSync => 'Apple Music eLRC Word Sync';

  @override
  String get downloadAppleElrcWordSyncEnabled =>
      'Raw word-by-word timestamps preserved';

  @override
  String get downloadAppleElrcWordSyncDisabled =>
      'Safer line-by-line Apple Music lyrics';

  @override
  String get downloadMusixmatchLanguage => 'Musixmatch Language';

  @override
  String get downloadMusixmatchLanguageAuto => 'Auto (original language)';

  @override
  String get downloadFilterContributing => 'Filter Contributing Artists';

  @override
  String get downloadFilterContributingEnabled =>
      'Contributing artists removed from Album Artist folder name';

  @override
  String get downloadFilterContributingDisabled =>
      'Full Album Artist string used';

  @override
  String get downloadProvidersNoneEnabled => 'No providers enabled';

  @override
  String get downloadMusixmatchLanguageCode => 'Language code';

  @override
  String get downloadMusixmatchLanguageHint => 'e.g. en, de, ja';

  @override
  String get downloadMusixmatchLanguageDesc =>
      'Enter a BCP-47 language code (e.g. en, de, ja) to request translated lyrics from Musixmatch.';

  @override
  String get downloadMusixmatchAuto => 'Auto';

  @override
  String get downloadNetworkAnySubtitle => 'Use WiFi or mobile data';

  @override
  String get downloadNetworkWifiOnlySubtitle =>
      'Downloads pause when on mobile data';

  @override
  String get downloadSongLinkRegionDesc =>
      'Region used when resolving track links via SongLink. Choose the country where your streaming services are available.';

  @override
  String get snackbarUnsupportedAudioFormat => 'Unsupported audio format';

  @override
  String get cacheRefresh => 'Refresh';

  @override
  String dialogDownloadPlaylistsMessage(int trackCount, int playlistCount) {
    String _temp0 = intl.Intl.pluralLogic(
      trackCount,
      locale: localeName,
      other: 'tracks',
      one: 'track',
    );
    String _temp1 = intl.Intl.pluralLogic(
      playlistCount,
      locale: localeName,
      other: 'playlists',
      one: 'playlist',
    );
    return 'Download $trackCount $_temp0 from $playlistCount $_temp1?';
  }

  @override
  String bulkDownloadPlaylistsButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'playlists',
      one: 'playlist',
    );
    return 'Download $count $_temp0';
  }

  @override
  String get bulkDownloadSelectPlaylists => 'Select playlists to download';

  @override
  String get snackbarSelectedPlaylistsEmpty =>
      'Selected playlists have no tracks';

  @override
  String playlistsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists',
      one: '1 playlist',
    );
    return '$_temp0';
  }

  @override
  String get editMetadataAutoFill => 'Auto-fill from online';

  @override
  String get editMetadataAutoFillDesc =>
      'Select fields to fill automatically from online metadata';

  @override
  String get editMetadataAutoFillFetch => 'Fetch & Fill';

  @override
  String get editMetadataAutoFillSearching => 'Searching online...';

  @override
  String get editMetadataAutoFillNoResults =>
      'No matching metadata found online';

  @override
  String editMetadataAutoFillDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fields',
      one: 'field',
    );
    return 'Filled $count $_temp0 from online metadata';
  }

  @override
  String get editMetadataAutoFillNoneSelected =>
      'Select at least one field to auto-fill';

  @override
  String get editMetadataFieldTitle => 'Title';

  @override
  String get editMetadataFieldArtist => 'Artist';

  @override
  String get editMetadataFieldAlbum => 'Album';

  @override
  String get editMetadataFieldAlbumArtist => 'Album Artist';

  @override
  String get editMetadataFieldDate => 'Date';

  @override
  String get editMetadataFieldTrackNum => 'Track #';

  @override
  String get editMetadataFieldDiscNum => 'Disc #';

  @override
  String get editMetadataFieldGenre => 'Genre';

  @override
  String get editMetadataFieldIsrc => 'ISRC';

  @override
  String get editMetadataFieldLabel => 'Label';

  @override
  String get editMetadataFieldCopyright => 'Copyright';

  @override
  String get editMetadataFieldCover => 'Cover Art';

  @override
  String get editMetadataSelectAll => 'All';

  @override
  String get editMetadataSelectEmpty => 'Empty only';

  @override
  String queueDownloadingCount(int count) {
    return 'Downloading ($count)';
  }

  @override
  String get queueFilteringIndicator => 'Filtering...';

  @override
  String queueTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$_temp0';
  }

  @override
  String queueAlbumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums',
      one: '1 album',
    );
    return '$_temp0';
  }

  @override
  String get queueEmptyAlbums => 'No album downloads';

  @override
  String get queueEmptyAlbumsSubtitle =>
      'Download multiple tracks from an album to see them here';

  @override
  String get queueEmptySingles => 'No single downloads';

  @override
  String get queueEmptySinglesSubtitle =>
      'Single track downloads will appear here';

  @override
  String get queueEmptyHistory => 'No download history';

  @override
  String get queueEmptyHistorySubtitle => 'Downloaded tracks will appear here';

  @override
  String get selectionAllPlaylistsSelected => 'All playlists selected';

  @override
  String get selectionTapPlaylistsToSelect => 'Tap playlists to select';

  @override
  String get selectionSelectPlaylistsToDelete => 'Select playlists to delete';

  @override
  String get audioAnalysisTitle => 'Audio Quality Analysis';

  @override
  String get audioAnalysisDescription =>
      'Verify lossless quality with spectrum analysis';

  @override
  String get audioAnalysisAnalyzing => 'Analyzing audio...';

  @override
  String get audioAnalysisSampleRate => 'Sample Rate';

  @override
  String get audioAnalysisCodec => 'Codec';

  @override
  String get audioAnalysisContainer => 'Container';

  @override
  String get audioAnalysisDecodedFormat => 'Decoded Format';

  @override
  String get audioAnalysisBitDepth => 'Bit Depth';

  @override
  String get audioAnalysisChannels => 'Channels';

  @override
  String get audioAnalysisDuration => 'Duration';

  @override
  String get audioAnalysisNyquist => 'Nyquist';

  @override
  String get audioAnalysisFileSize => 'Size';

  @override
  String get audioAnalysisDynamicRange => 'Dynamic Range';

  @override
  String get audioAnalysisPeak => 'Peak';

  @override
  String get audioAnalysisRms => 'RMS';

  @override
  String get audioAnalysisLufs => 'LUFS';

  @override
  String get audioAnalysisTruePeak => 'True Peak';

  @override
  String get audioAnalysisClipping => 'Clipping';

  @override
  String get audioAnalysisNoClipping => 'No clipping';

  @override
  String get audioAnalysisSpectralCutoff => 'Spectral Cutoff';

  @override
  String get audioAnalysisChannelStats => 'Per-channel Stats';

  @override
  String get audioAnalysisSamples => 'Samples';

  @override
  String get audioAnalysisRescan => 'Re-analyze';

  @override
  String get audioAnalysisRescanning => 'Re-analyzing audio...';

  @override
  String get extensionsHomeFeedProvider => 'Home Feed Provider';

  @override
  String get extensionsHomeFeedDescription =>
      'Choose which extension provides the home feed on the main screen';

  @override
  String get extensionsHomeFeedAuto => 'Auto';

  @override
  String get extensionsHomeFeedAutoSubtitle =>
      'Automatically select the best available';

  @override
  String get extensionsHomeFeedOff => 'Off';

  @override
  String get extensionsHomeFeedOffSubtitle =>
      'Do not show the home feed on the main screen';

  @override
  String extensionsHomeFeedUse(String extensionName) {
    return 'Use $extensionName home feed';
  }

  @override
  String get extensionsNoHomeFeedExtensions => 'No extensions with home feed';

  @override
  String get cancelDownloadTitle => 'Cancel download?';

  @override
  String cancelDownloadContent(String trackName) {
    return 'This will cancel the active download for \"$trackName\".';
  }

  @override
  String get cancelDownloadKeep => 'Keep';

  @override
  String get metadataSaveFailedFfmpeg => 'Failed to save metadata via FFmpeg';

  @override
  String get metadataSaveFailedStorage =>
      'Failed to write metadata back to storage';

  @override
  String snackbarFolderPickerFailed(String error) {
    return 'Failed to open folder picker: $error';
  }

  @override
  String notifDownloadingTrack(String trackName) {
    return 'Downloading $trackName';
  }

  @override
  String notifFinalizingTrack(String trackName) {
    return 'Finalizing $trackName';
  }

  @override
  String get notifEmbeddingMetadata => 'Embedding metadata...';

  @override
  String notifAlreadyInLibraryCount(int completed, int total) {
    return 'Already in Library ($completed/$total)';
  }

  @override
  String get notifAlreadyInLibrary => 'Already in Library';

  @override
  String notifDownloadCompleteCount(int completed, int total) {
    return 'Download Complete ($completed/$total)';
  }

  @override
  String get notifDownloadComplete => 'Download Complete';

  @override
  String notifDownloadsFinished(int completed, int failed) {
    return 'Downloads Finished ($completed done, $failed failed)';
  }

  @override
  String get notifVerificationRequiredTitle => 'Verification required';

  @override
  String get notifVerificationRequiredBody =>
      'Open the app to complete verification and resume downloads';

  @override
  String get notifAllDownloadsComplete => 'All Downloads Complete';

  @override
  String notifTracksDownloadedSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks downloaded successfully',
      one: '1 track downloaded successfully',
    );
    return '$_temp0';
  }

  @override
  String notifDownloadsFinishedBody(int completed, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      completed,
      locale: localeName,
      other: '$completed tracks downloaded',
      one: '1 track downloaded',
    );
    String _temp1 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: '$failed failed',
      one: '1 failed',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get notifDownloadsCanceledTitle => 'Downloads canceled';

  @override
  String notifDownloadsCanceledBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads canceled by user',
      one: '1 download canceled by user',
    );
    return '$_temp0';
  }

  @override
  String get notifScanningLibrary => 'Scanning local library';

  @override
  String notifLibraryScanProgressWithTotal(
    int scanned,
    int total,
    int percentage,
  ) {
    return '$scanned/$total files • $percentage%';
  }

  @override
  String notifLibraryScanProgressNoTotal(int scanned, int percentage) {
    return '$scanned files scanned • $percentage%';
  }

  @override
  String get notifLibraryScanComplete => 'Library scan complete';

  @override
  String notifLibraryScanCompleteBody(int count) {
    return '$count tracks indexed';
  }

  @override
  String notifLibraryScanExcluded(int count) {
    return '$count excluded';
  }

  @override
  String notifLibraryScanErrors(int count) {
    return '$count errors';
  }

  @override
  String get notifLibraryScanFailed => 'Library scan failed';

  @override
  String get notifLibraryScanCancelled => 'Library scan cancelled';

  @override
  String get notifLibraryScanStopped => 'Scan stopped before completion.';

  @override
  String notifDownloadingUpdate(String version) {
    return 'Downloading SpotiFLAC Mobile v$version';
  }

  @override
  String notifUpdateProgress(String received, String total, int percentage) {
    return '$received / $total MB • $percentage%';
  }

  @override
  String get notifUpdateReady => 'Update Ready';

  @override
  String notifUpdateReadyBody(String version) {
    return 'SpotiFLAC Mobile v$version downloaded. Tap to install.';
  }

  @override
  String get notifUpdateFailed => 'Update Failed';

  @override
  String get notifUpdateFailedBody =>
      'Could not download update. Try again later.';

  @override
  String get searchTracks => 'Tracks';

  @override
  String get homeSearchHintDefault => 'Paste supported URL or search...';

  @override
  String homeSearchHintProvider(String providerName) {
    return 'Search with $providerName...';
  }

  @override
  String get homeImportCsvTooltip => 'Import CSV';

  @override
  String get homeChangeSearchProviderTooltip => 'Change search provider';

  @override
  String get actionPaste => 'Paste';

  @override
  String get tutorialSearchHint => 'Paste or search...';

  @override
  String get tutorialDownloadCompletedSemantics => 'Download completed';

  @override
  String get tutorialDownloadInProgressSemantics => 'Download in progress';

  @override
  String get tutorialStartDownloadSemantics => 'Start download';

  @override
  String get optionsEmbedMetadata => 'Embed Metadata';

  @override
  String get optionsEmbedMetadataSubtitleOn =>
      'Write metadata, cover art, and embedded lyrics to files';

  @override
  String get optionsEmbedMetadataSubtitleOff =>
      'Disabled (advanced): skip all metadata embedding';

  @override
  String get trackCoverNoEmbeddedArt => 'No embedded album art found';

  @override
  String get trackCoverReplace => 'Replace Cover';

  @override
  String get trackCoverPick => 'Pick Cover';

  @override
  String get trackCoverClearSelected => 'Clear selected cover';

  @override
  String get trackCoverCurrent => 'Current cover';

  @override
  String get trackCoverSelected => 'Selected cover';

  @override
  String get trackCoverReplaceNotice =>
      'The selected cover will replace the current embedded cover when you tap Save.';

  @override
  String get actionStop => 'Stop';

  @override
  String get queueFinalizingDownload => 'Finalizing download';

  @override
  String get queueDownloadedFileMissing => 'Downloaded file missing';

  @override
  String get queueDownloadCompleted => 'Download completed';

  @override
  String get queueRateLimitTitle => 'Service rate limited';

  @override
  String get queueRateLimitMessage =>
      'This track may still be available. Wait a few minutes, reduce parallel downloads, then retry.';

  @override
  String appearanceSelectAccentColor(String hex) {
    return 'Select accent color $hex';
  }

  @override
  String get logAutoScrollOn => 'Auto-scroll ON';

  @override
  String get logAutoScrollOff => 'Auto-scroll OFF';

  @override
  String get logCopyLogs => 'Copy logs';

  @override
  String get logClearSearch => 'Clear search';

  @override
  String get logIssueIspBlockingLabel => 'ISP BLOCKING DETECTED';

  @override
  String get logIssueIspBlockingDescription =>
      'Your ISP may be blocking access to download services';

  @override
  String get logIssueIspBlockingSuggestion =>
      'Try using a VPN or change DNS to 1.1.1.1 or 8.8.8.8';

  @override
  String get logIssueRateLimitedLabel => 'RATE LIMITED';

  @override
  String get logIssueRateLimitedDescription =>
      'Too many requests to the service';

  @override
  String get logIssueRateLimitedSuggestion =>
      'Wait a few minutes before trying again';

  @override
  String get logIssueNetworkErrorLabel => 'NETWORK ERROR';

  @override
  String get logIssueNetworkErrorDescription => 'Connection issues detected';

  @override
  String get logIssueNetworkErrorSuggestion => 'Check your internet connection';

  @override
  String get logIssueTrackNotFoundLabel => 'TRACK NOT FOUND';

  @override
  String get logIssueTrackNotFoundDescription =>
      'Some tracks could not be found on download services';

  @override
  String get logIssueTrackNotFoundSuggestion =>
      'The track may not be available in lossless quality';

  @override
  String get clickableLookingUpArtist => 'Looking up artist...';

  @override
  String clickableInformationUnavailable(String type) {
    return '$type information not available';
  }

  @override
  String get extensionDetailsTags => 'Tags';

  @override
  String get extensionDetailsInformation => 'Information';

  @override
  String get extensionUtilityFunctions => 'Utility Functions';

  @override
  String get actionDismiss => 'Dismiss';

  @override
  String get setupChangeFolderTooltip => 'Change folder';

  @override
  String a11yOpenTrackByArtist(String trackName, String artistName) {
    return 'Open track $trackName by $artistName';
  }

  @override
  String a11yOpenItem(String itemType, String name) {
    return 'Open $itemType $name';
  }

  @override
  String a11yOpenItemCount(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'items',
      one: 'item',
    );
    return 'Open $title, $count $_temp0';
  }

  @override
  String a11yOpenAlbumByArtistTrackCount(
    String albumName,
    String artistName,
    int trackCount,
  ) {
    return 'Open album $albumName by $artistName, $trackCount tracks';
  }

  @override
  String a11yTrackByArtist(String trackName, String artistName) {
    return '$trackName by $artistName';
  }

  @override
  String a11ySelectAlbum(String albumName) {
    return 'Select album $albumName';
  }

  @override
  String a11yOpenAlbum(String albumName) {
    return 'Open album $albumName';
  }

  @override
  String get settingsFiles => 'Files & Folders';

  @override
  String get settingsFilesSubtitle =>
      'Download location, filename, folder structure';

  @override
  String get settingsMetadata => 'Metadata';

  @override
  String get settingsMetadataSubtitle =>
      'Cover art, tags, ReplayGain, providers';

  @override
  String get settingsLyrics => 'Lyrics';

  @override
  String get settingsLyricsSubtitle =>
      'Embed, mode, providers, language options';

  @override
  String get settingsApp => 'App';

  @override
  String get settingsAppSubtitle => 'Updates, data, extension repo, debug';

  @override
  String get sectionMetadataProviders => 'Providers';

  @override
  String get sectionDuplicates => 'Duplicates';

  @override
  String get sectionLyricsProviderOptions => 'Provider Options';

  @override
  String get metadataProvidersTitle => 'Metadata Provider Priority';

  @override
  String get metadataProvidersSubtitle =>
      'Drag to set search and metadata source order';

  @override
  String get downloadDeduplication => 'Skip Duplicate Downloads';

  @override
  String get downloadDeduplicationEnabled =>
      'Already-downloaded tracks will be skipped';

  @override
  String get downloadDeduplicationDisabled =>
      'All tracks will be downloaded regardless of history';

  @override
  String get downloadFallbackExtensions => 'Fallback Extensions';

  @override
  String get downloadFallbackExtensionsSubtitle =>
      'Choose which extensions can be used as fallback';

  @override
  String get editMetadataFieldDateHint => 'YYYY-MM-DD or YYYY';

  @override
  String get editMetadataFieldTrackTotal => 'Track Total';

  @override
  String get editMetadataFieldDiscTotal => 'Disc Total';

  @override
  String get editMetadataFieldComposer => 'Composer';

  @override
  String get editMetadataFieldComment => 'Comment';

  @override
  String get editMetadataAdvanced => 'Advanced';

  @override
  String get libraryFilterMetadataMissingTrackNumber => 'Missing track number';

  @override
  String get libraryFilterMetadataMissingDiscNumber => 'Missing disc number';

  @override
  String get libraryFilterMetadataMissingArtist => 'Missing artist';

  @override
  String get libraryFilterMetadataIncorrectIsrcFormat =>
      'Incorrect ISRC format';

  @override
  String get libraryFilterMetadataMissingLabel => 'Missing label';

  @override
  String collectionDeletePlaylistsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'playlists',
      one: 'playlist',
    );
    return 'Delete $count $_temp0?';
  }

  @override
  String collectionPlaylistsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'playlists',
      one: 'playlist',
    );
    return '$count $_temp0 deleted';
  }

  @override
  String collectionAddedTracksToPlaylist(int count, String playlistName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tracks',
      one: 'track',
    );
    return 'Added $count $_temp0 to $playlistName';
  }

  @override
  String collectionAddedTracksToPlaylistWithExisting(
    int count,
    String playlistName,
    int alreadyCount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tracks',
      one: 'track',
    );
    return 'Added $count $_temp0 to $playlistName ($alreadyCount already in playlist)';
  }

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'items',
      one: 'item',
    );
    return '$count $_temp0';
  }

  @override
  String trackReEnrichSuccessWithFailures(
    int successCount,
    int total,
    int failedCount,
  ) {
    return 'Metadata re-enriched successfully ($successCount/$total) - Failed: $failedCount';
  }

  @override
  String selectionDeleteTracksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tracks',
      one: 'track',
    );
    return 'Delete $count $_temp0';
  }

  @override
  String queueDownloadSpeedStatus(String speed) {
    return 'Downloading - $speed MB/s';
  }

  @override
  String get queueDownloadStarting => 'Starting...';

  @override
  String get a11ySelectTrack => 'Select track';

  @override
  String get a11yDeselectTrack => 'Deselect track';

  @override
  String a11yPlayTrackByArtist(String trackName, String artistName) {
    return 'Play $trackName by $artistName';
  }

  @override
  String storeExtensionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'extensions',
      one: 'extension',
    );
    return '$count $_temp0';
  }

  @override
  String storeRequiresVersion(String version) {
    return 'Requires v$version+';
  }

  @override
  String get actionGo => 'Go';

  @override
  String get logIssueSummary => 'Issue Summary';

  @override
  String logTotalErrors(int count) {
    return 'Total errors: $count';
  }

  @override
  String logAffectedDomains(String domains) {
    return 'Affected: $domains';
  }

  @override
  String get libraryScanCancelled => 'Scan cancelled';

  @override
  String get libraryScanCancelledSubtitle =>
      'You can retry the scan when ready.';

  @override
  String libraryDownloadsHistoryExcluded(int count) {
    return '$count from Downloads history (excluded from list)';
  }

  @override
  String get downloadNativeWorker => 'Native download worker';

  @override
  String get downloadNativeWorkerSubtitle =>
      'Beta Android service worker for extension downloads';

  @override
  String get badgeBeta => 'BETA';

  @override
  String get extensionServiceStatus => 'Service Status';

  @override
  String get extensionServiceHealth => 'Service health';

  @override
  String extensionHealthChecksConfigured(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'checks',
      one: 'check',
    );
    return '$count $_temp0 configured';
  }

  @override
  String get extensionOauthConnectHint =>
      'Tap Connect to Spotify to fill this field.';

  @override
  String extensionLastChecked(String time) {
    return 'Last checked $time';
  }

  @override
  String get extensionRefreshStatus => 'Refresh status';

  @override
  String get extensionCustomUrlHandling => 'Custom URL Handling';

  @override
  String get extensionCustomUrlHandlingSubtitle =>
      'This extension can handle links from these sites';

  @override
  String get extensionCustomUrlHandlingShareHint =>
      'Share links from these sites to SpotiFLAC Mobile and this extension will handle them.';

  @override
  String extensionSettingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'settings',
      one: 'setting',
    );
    return '$count $_temp0';
  }

  @override
  String get extensionHealthOnline => 'Online';

  @override
  String get extensionHealthDegraded => 'Degraded';

  @override
  String get extensionHealthOffline => 'Offline';

  @override
  String get extensionHealthNotConfigured => 'Not configured';

  @override
  String get extensionHealthUnknown => 'Unknown';

  @override
  String get extensionHealthRequired => 'required';

  @override
  String get extensionSettingNotSet => 'Not set';

  @override
  String get extensionActionFailed => 'Action failed';

  @override
  String get extensionEnterValue => 'Enter value';

  @override
  String get extensionHealthServiceOnline => 'Service online';

  @override
  String get extensionHealthServiceDegraded => 'Service degraded';

  @override
  String get extensionHealthServiceOffline => 'Service offline';

  @override
  String get extensionHealthServiceUnknown => 'Service status unknown';

  @override
  String get audioAnalysisStereo => 'Stereo';

  @override
  String get audioAnalysisMono => 'Mono';

  @override
  String trackOpenInService(String serviceName) {
    return 'Open in $serviceName';
  }

  @override
  String get trackLyricsEmbeddedSource => 'Embedded';

  @override
  String get unknownAlbum => 'Unknown Album';

  @override
  String get unknownArtist => 'Unknown Artist';

  @override
  String get permissionAudio => 'Audio';

  @override
  String get permissionStorage => 'Storage';

  @override
  String get permissionNotification => 'Notification';

  @override
  String get errorInvalidFolderSelected => 'Invalid folder selected';

  @override
  String get storeAnyVersion => 'Any';

  @override
  String get storeCategoryMetadata => 'Metadata';

  @override
  String get storeCategoryDownload => 'Download';

  @override
  String get storeCategoryUtility => 'Utility';

  @override
  String get storeCategoryLyrics => 'Lyrics';

  @override
  String get storeCategoryIntegration => 'Integration';

  @override
  String get artistReleases => 'Releases';

  @override
  String get editMetadataSelectNone => 'None';

  @override
  String queueRetryAllFailed(int count) {
    return 'Retry $count failed';
  }

  @override
  String get settingsSaveDownloadHistory => 'Save download history';

  @override
  String get settingsSaveDownloadHistorySubtitle =>
      'Keep completed downloads in history and library views';

  @override
  String get dialogDisableHistoryTitle => 'Turn off download history?';

  @override
  String get dialogDisableHistoryMessage =>
      'Existing history will be cleared. Downloaded files will not be deleted.';

  @override
  String get dialogDisableAndClear => 'Turn off and clear';

  @override
  String get openInOtherServices => 'Open in Other Services';

  @override
  String get shareSheetNoExtensions => 'No other compatible services';

  @override
  String get shareSheetNotFound => 'Not found';

  @override
  String get shareSheetCopyLink => 'Copy Link';

  @override
  String shareSheetLinkCopied(Object service) {
    return '$service link copied';
  }

  @override
  String get libraryPlayback => 'Playback';

  @override
  String get libraryExternalPlayer => 'External player';

  @override
  String get libraryExternalPlayerSubtitle =>
      'Recommended for listening, best quality, gapless playback, EQ, and wider format support';

  @override
  String get libraryBuiltInPreviewPlayer => 'Built-in preview player';

  @override
  String get libraryBuiltInPreviewPlayerSubtitle =>
      'Only for quick local previews inside SpotiFLAC Mobile, not recommended for regular listening';

  @override
  String get libraryBuiltInPlayerInfo =>
      'The built-in player is a preview tool for checking local tracks quickly. Use an external music player for actual listening.';

  @override
  String get nowPlayingTitle => 'Now Playing';

  @override
  String get nowPlayingNothingPlaying => 'Nothing is playing';

  @override
  String get nowPlayingMinimize => 'Minimize';

  @override
  String get nowPlayingUpNext => 'Up next';

  @override
  String get nowPlayingDetails => 'Details';

  @override
  String get nowPlayingOpenInExternalPlayer => 'Open in external player';

  @override
  String get nowPlayingTabPlayer => 'Player';

  @override
  String get nowPlayingTabLyrics => 'Lyrics';

  @override
  String get nowPlayingNoLyrics => 'No lyrics in this file';

  @override
  String get nowPlayingLibraryEmpty => 'Your library is empty';

  @override
  String nowPlayingShuffleLibraryFailed(String error) {
    return 'Could not shuffle library: $error';
  }

  @override
  String get nowPlayingShuffleOn => 'Shuffle on';

  @override
  String get nowPlayingPlayInOrder => 'Play in order';

  @override
  String get nowPlayingShuffleLibrary => 'Shuffle library';

  @override
  String get nowPlayingQueueEmpty => 'Queue is empty';

  @override
  String get nowPlayingNoMetadata => 'No metadata available';

  @override
  String get announcementUnableToOpenLink =>
      'Unable to open link. Please try again.';

  @override
  String trackConvertLosslessOutputWithCap(String quality) {
    return 'Lossless output with $quality cap';
  }

  @override
  String trackConvertConfirmMessageLosslessCapped(
    String sourceFormat,
    String targetFormat,
    String quality,
  ) {
    return 'Convert from $sourceFormat to $targetFormat ($quality)?\n\nThe output stays in a lossless codec, but bit depth/sample rate will be capped. Original file will be deleted after conversion.';
  }

  @override
  String selectionBatchConvertConfirmMessageLosslessCapped(
    int count,
    String format,
    String quality,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tracks',
      one: 'track',
    );
    return 'Convert $count $_temp0 to $format ($quality)?\n\nThe output stays in a lossless codec, but bit depth/sample rate will be capped. Original files will be deleted after conversion.';
  }

  @override
  String trackConvertActionLabelLossless(
    String sourceFormat,
    String targetFormat,
    String quality,
  ) {
    return '$sourceFormat → $targetFormat ($quality)';
  }

  @override
  String trackConvertActionLabelLossy(
    String sourceFormat,
    String targetFormat,
    String bitrate,
  ) {
    return '$sourceFormat → $targetFormat @ $bitrate';
  }

  @override
  String get aboutPaxsenixSubtitle =>
      'Lyrics proxy for Musixmatch, Netease, Apple Music, QQ Music, Spotify, Deezer, YouTube, Kugou, and Genius';

  @override
  String get snackbarPlayingNext => 'Playing next';

  @override
  String get snackbarAddedToQueueGeneric => 'Added to queue';

  @override
  String selectionDeletePlaylistsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'playlists',
      one: 'playlist',
    );
    return 'Delete $count $_temp0';
  }

  @override
  String get actionShuffle => 'Shuffle';

  @override
  String get downloadPrimaryArtistOnlyOn => 'Primary only: On';

  @override
  String get downloadPrimaryArtistOnlyOff => 'Primary only: Off';

  @override
  String get downloadAlbumArtistMetadataPrimaryOnly =>
      'Album Artist metadata: Primary only';

  @override
  String get downloadAlbumArtistMetadataFull => 'Album Artist metadata: Full';

  @override
  String get trackConvertOriginal => 'Original';

  @override
  String get trackConvertOriginalQuality => 'Original quality';

  @override
  String get trackConvertLosslessSuffix => 'Lossless';

  @override
  String get trackConvertDithering => 'Dithering';

  @override
  String get trackConvertResampler => 'Resampler';

  @override
  String get trackConvertDitherNone => 'None';

  @override
  String get trackConvertDitherTriangular => 'TPDF';

  @override
  String get trackConvertDitherTriangularHp => 'Triangular HP';

  @override
  String get trackConvertResamplerSwr => 'SWR';

  @override
  String get trackConvertResamplerSoxr => 'SoXr';

  @override
  String get updateSeeReleaseNotes => 'See release notes for details.';

  @override
  String get unknownTitle => 'Unknown title';

  @override
  String get trackPlayNext => 'Play next';

  @override
  String get trackAddToQueue => 'Add to queue';

  @override
  String snackbarExtensionInstalledEnable(String extensionName) {
    return '$extensionName installed. Enable it in Settings > Extensions';
  }

  @override
  String snackbarExtensionUpdatedVersion(String extensionName, String version) {
    return '$extensionName updated to v$version';
  }

  @override
  String snackbarFailedToInstallNamed(String extensionName) {
    return 'Failed to install $extensionName';
  }

  @override
  String snackbarFailedToUpdateNamed(String extensionName) {
    return 'Failed to update $extensionName';
  }

  @override
  String get releaseTypeEp => 'EP';

  @override
  String get releaseTypeSingle => 'Single';

  @override
  String get trackCoverOnline => 'Online cover';

  @override
  String get regionCountryUS => 'United States';

  @override
  String get regionCountryGB => 'United Kingdom';

  @override
  String get regionCountryFR => 'France';

  @override
  String get regionCountryDE => 'Germany';

  @override
  String get regionCountryJP => 'Japan';

  @override
  String get regionCountryKR => 'South Korea';

  @override
  String get regionCountryIN => 'India';

  @override
  String get regionCountryID => 'Indonesia';

  @override
  String get regionCountryBR => 'Brazil';

  @override
  String get regionCountryMX => 'Mexico';

  @override
  String get regionCountryAU => 'Australia';

  @override
  String get regionCountryCA => 'Canada';

  @override
  String get regionCountryXK => 'Kosovo';

  @override
  String get extensionVerificationBrowserTitle => 'Verification browser';

  @override
  String get extensionVerificationBrowserSubtitleExternal =>
      'Open challenges in the default browser first';

  @override
  String get extensionVerificationBrowserSubtitleInApp =>
      'Open challenges in the in-app browser first';

  @override
  String get extensionVerificationBrowserExternal => 'External';

  @override
  String get extensionVerificationBrowserInApp => 'In-app';

  @override
  String get extensionVerificationHelpTitleManual =>
      'Open verification manually';

  @override
  String get extensionVerificationHelpTitleWaiting =>
      'Verification still waiting';

  @override
  String get extensionVerificationHelpMessageManual =>
      'SpotiFLAC Mobile could not open the browser automatically. Open this link in your browser, or copy it manually.';

  @override
  String get extensionVerificationHelpMessageWaiting =>
      'If the browser did not open, or verification finished but did not return to SpotiFLAC Mobile, open this link again or copy it manually.';

  @override
  String get extensionVerificationClose => 'Close';

  @override
  String get extensionVerificationCopyLink => 'Copy link';

  @override
  String get extensionVerificationLinkCopied => 'Verification link copied';

  @override
  String get extensionVerificationOpenBrowser => 'Open browser';
}

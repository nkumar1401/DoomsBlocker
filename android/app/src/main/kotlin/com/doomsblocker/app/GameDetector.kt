package com.doomsblocker.app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import java.io.File
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import java.util.zip.ZipFile
import kotlin.math.abs

/**
 * Multi-tier, zero-false-positive Android game classifier and synchronizer.
 *
 * Tier 0: Hard non-game safety shield (System, Banking/UPI/2FA per Invariant 6, Browsers, Social/Video, Study/OEM exclusions).
 * Tier 1: Official ApplicationInfo.CATEGORY_GAME / FLAG_IS_GAME metadata.
 * Tier 2: PackageManager manifest metadata & entry-point activity signatures (GPGS, gamepad, Unity/Unreal/Godot/Cocos/Defold/Corona/GameMaker).
 * Tier 3: APK ZIP central directory native .so fingerprinting across publicSourceDir + splitSourceDirs (handles extractNativeLibs="false").
 * Tier 4: Fused Play Store install-time correlation + NativeActivity/landscape + live AccessibilityNodeInfo canvas corroboration (score >= 2).
 */
object GameDetector {
    private const val TAG = "GameDetector"
    private const val PLAY_STORE_PACKAGE = "com.android.vending"
    private const val PLAY_INSTALL_WINDOW_MS = 15 * 60 * 1000L
    private const val PLAY_SESSION_CORRELATION_MS = 2 * 60 * 1000L
    private const val FRESH_INSTALL_GRACE_MS = 90 * 1000L
    private const val TIER1_RECHECK_INTERVAL_MS = 2 * 1000L
    private const val MAX_A11Y_DEPTH = 10
    private const val MAX_A11Y_NODES = 80

    val SYSTEM_BLACKLIST = setOf(
        "com.android.settings",
        "com.google.android.settings",
        "com.android.systemui",
        PLAY_STORE_PACKAGE,
        "com.google.android.googlequicksearchbox",
        "com.google.android.packageinstaller",
        "com.android.packageinstaller",
        "com.google.android.dialer",
        "com.android.dialer",
        "com.android.phone",
        "com.google.android.deskclock",
        "com.android.deskclock",
        "com.google.android.calculator",
        "com.android.calculator2",
        "com.google.android.contacts",
        "com.android.contacts",
        "com.google.android.apps.messaging",
        "com.android.mms",
        "com.android.camera",
        "com.google.android.GoogleCamera"
    )

    private val PAYMENT_AND_BANKING_PACKAGES = setOf(
        "com.google.android.apps.nbu.paisa.user", // Google Pay (Tez)
        "com.google.android.apps.walletnfcrel",   // Google Wallet
        "com.phonepe.app",                        // PhonePe
        "com.phonepe.app.business",               // PhonePe Business
        "net.one97.paytm",                        // Paytm
        "in.org.npci.upiapp",                     // BHIM UPI
        "com.dreamplug.androidapp",               // CRED
        "com.naviapp",                            // Navi
        "com.freecharge.android",                 // Freecharge
        "com.mobikwik_new",                       // MobiKwik
        "com.bharatpe.app",                       // BharatPe
        "com.slice",                              // slice
        "com.fampay.in",                          // FamPay
        "com.jupiter.app",                        // Jupiter
        "com.fi.money",                           // Fi Money
        "money.super.payments",                   // super.money
        "com.paypal.android.p2pmobile",           // PayPal
        "com.sbi.lotusintouch",                   // YONO SBI
        "com.sbi.SBIFreedomPlus",                 // YONO Lite SBI
        "com.msf.kbank.mobile",                   // Kotak 811
        "com.csam.icici.bank.imobile",            // ICICI iMobile
        "com.icicibank.pockets",                  // ICICI Pockets
        "com.snapwork.hdfc",                      // HDFC Bank MobileBanking
        "com.hdfcbank.payzapp",                   // HDFC PayZapp
        "com.enstage.wibmo.hdfc",                 // HDFC PayZapp (Legacy)
        "com.axis.mobile",                        // Axis Mobile
        "com.pnb.pnbone",                         // PNB ONE
        "com.bankofbaroda.mconnect",              // bob World
        "com.canarabank.ai1",                     // Canara ai1
        "com.infrasoft.uboi",                     // Union Bank Vyom
        "com.idfcfirstbank.optimus",              // IDFC FIRST Bank
        "com.indusind.mobile",                    // IndusInd Mobile
        "com.google.android.apps.authenticator2", // Google Authenticator
        "com.azure.authenticator",                // Microsoft Authenticator
        "org.fedorahosted.freeotp",               // FreeOTP
        "com.authy.authy",                        // Authy
        "com.duosecurity.duomobile",              // Duo Mobile
        "com.yubico.yubioath"                     // Yubico Authenticator
    )

    val SUPPORTED_BROWSER_PACKAGES = setOf(
        "com.android.chrome",
        "com.chrome.beta",
        "com.chrome.dev",
        "com.chrome.canary",
        "com.sec.android.app.sbrowser",
        "com.sec.android.app.sbrowser.beta",
        "com.brave.browser",
        "com.microsoft.emmx",
        "org.mozilla.firefox",
        "org.mozilla.firefox_beta",
        "com.opera.browser",
        "com.opera.mini.native",
        "com.opera.gx",
        "com.duckduckgo.mobile.android",
        "com.mi.globalbrowser",
        "com.vivo.browser",
        "com.heytap.browser",
        "com.coloros.browser"
    )

    private val SOCIAL_AND_VIDEO_PACKAGES = setOf(
        AppPreferences.PKG_YOUTUBE,
        "com.google.android.apps.youtube.kids",
        "com.google.android.apps.youtube.music",
        AppPreferences.PKG_INSTAGRAM,
        AppPreferences.PKG_SNAPCHAT,
        AppPreferences.PKG_SHARECHAT,
        AppPreferences.PKG_MOJ,
        AppPreferences.PKG_JOSH,
        "com.zhiliaoapp.musically",
        "com.ss.android.ugc.trill",
        "com.facebook.katana",
        "com.facebook.orca",
        "com.facebook.lite",
        "com.twitter.android",
        "com.reddit.frontpage",
        "com.whatsapp",
        "com.whatsapp.w4b",
        "org.telegram.messenger",
        "com.discord",
        "com.netflix.mediaclient",
        "com.amazon.avod.thirdpartyclient",
        "in.startv.hotstar",
        "com.spotify.music"
    )

    private val HEURISTIC_EXEMPT_PACKAGES = setOf(
        "com.google.android.gms",
        "com.google.android.gsf",
        "com.google.android.play.games",
        "com.google.android.permissioncontroller",
        "com.android.permissioncontroller",
        "com.duolingo",
        "org.khanacademy.android",
        "org.coursera.android",
        "com.udemy.android",
        "org.wikipedia",
        "com.ichi2.anki",
        "notion.id",
        "com.adobe.reader",
        "com.microblink.photomath",
        "com.quizlet.quizletandroid",
        "com.microsoft.office.word",
        "com.microsoft.office.excel",
        "com.microsoft.office.powerpoint",
        "com.microsoft.teams",
        "us.zoom.videomeetings"
    )

    private val HEURISTIC_EXEMPT_PREFIXES = listOf(
        "com.android.",
        "com.google.android.apps.",
        "com.google.android.projection.",
        "com.samsung.",
        "com.sec.",
        "com.miui.",
        "com.xiaomi.",
        "com.coloros.",
        "com.oplus.",
        "com.vivo.",
        "com.oppo.",
        "com.oneplus.",
        "com.huawei."
    )

    private val UNITY_LAUNCHER_ACTIVITIES = setOf(
        "com.unity3d.player.UnityPlayerActivity",
        "com.unity3d.player.UnityPlayerGameActivity",
        "com.unity3d.player.UnityPlayerProxyActivity"
    )

    private val GAME_ENGINE_ACTIVITIES = setOf(
        "com.epicgames.ue4.GameActivity",
        "com.epicgames.ue4.SplashActivity",
        "com.epicgames.unreal.GameActivity",
        "com.epicgames.unreal.SplashActivity",
        "org.godotengine.godot.Godot",
        "org.godotengine.godot.GodotApp",
        "org.godotengine.godot.GodotActivity",
        "com.dynamo.android.DefoldActivity",
        "com.ansca.corona.CoronaActivity",
        "com.yoyogames.runner.RunnerActivity",
        "com.google.androidgamesdk.GameActivity",
        "org.cocos2dx.cpp.AppActivity",
        "org.cocos2dx.lua.AppActivity",
        "org.cocos2dx.javascript.AppActivity",
        "org.cocos2dx.lib.Cocos2dxActivity"
    )

    private val UNAMBIGUOUS_GAME_SO = setOf(
        "libue4.so",
        "libunreal.so",
        "libgodot_android.so",
        "libgodot.so",
        "libcocos2dcpp.so",
        "libcocos2djs.so",
        "libcocos2dlua.so",
        "libcocos2d.so",
        "libcocos.so",
        "libyoyo.so",
        "libcorona.so",
        "libdefold.so",
        "libdmengine.so",
        "libgdx.so",
        "libgdx-box2d.so",
        "libgameactivity.so",
        "liblove.so",
        "libgideros.so",
        "libroblox.so",
        "libminecraftpe.so",
        "libaksoundengine.so"
    )

    private val NON_GAME_FRAMEWORK_SO = setOf(
        "libflutter.so",
        "libreactnativejni.so",
        "libhermes.so"
    )

    private data class StaticAnalysis(
        val versionCode: Long,
        val firstInstallTime: Long,
        val confirmedGame: Boolean,
        val confirmedNonGame: Boolean,
        val isFromPlayStore: Boolean,
        val hasCameraPermission: Boolean,
        val hasNativeOrLandscape: Boolean,
        val hasTier4DomainSignal: Boolean,
        @Volatile var lastTier1CheckMs: Long = 0L
    )

    private data class ApkScanResult(
        val hasUnambiguousGameSo: Boolean = false,
        val hasUnitySo: Boolean = false,
        val hasIl2CppSo: Boolean = false,
        val hasUnityAssets: Boolean = false,
        val hasNonGameFrameworkSo: Boolean = false,
        val hasGameMiddlewareSo: Boolean = false
    )

    private val staticCache = ConcurrentHashMap<String, StaticAnalysis>()

    fun isSystemIgnoredPackage(pkg: String): Boolean {
        return SYSTEM_BLACKLIST.contains(pkg) || pkg.startsWith("com.android.internal")
    }

    fun isPaymentOrBankingApp(pkgName: String): Boolean {
        if (PAYMENT_AND_BANKING_PACKAGES.contains(pkgName)) return true
        val lower = pkgName.lowercase(Locale.US)
        return lower.contains("banking") ||
            lower.contains(".upi") ||
            lower.contains("payment") ||
            lower.contains(".wallet") ||
            lower.contains("paisa") ||
            lower.contains("paytm") ||
            lower.contains("phonepe") ||
            lower.contains("netbanking") ||
            lower.contains("bhim") ||
            lower.contains("authenticator") ||
            lower.endsWith(".bank") ||
            lower.contains(".bank.")
    }

    fun isBrowserPackage(pkg: String): Boolean {
        if (SUPPORTED_BROWSER_PACKAGES.contains(pkg)) return true
        val lower = pkg.lowercase(Locale.US)
        return lower.contains("browser") || lower.contains(".chrome")
    }

    fun invalidateCache(packageName: String) {
        if (packageName.isNotBlank()) {
            staticCache.remove(packageName)
        }
    }

    fun isApplicationGame(appInfo: ApplicationInfo): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            appInfo.category == ApplicationInfo.CATEGORY_GAME ||
                (appInfo.flags and ApplicationInfo.FLAG_IS_GAME) != 0
        } else {
            (appInfo.flags and ApplicationInfo.FLAG_IS_GAME) != 0
        }
    }

    /**
     * Bounded, leak-free runtime check detecting a live game canvas:
     * dominant SurfaceView/GLSurfaceView (>= 75% screen bounds), <= 2 non-empty interactive/text
     * controls, and zero EditText or SeekBar widgets.
     * Note: Caller retains ownership of rootNode and is responsible for recycling rootNode.
     */
    fun isLiveGameAccessibilityTree(rootNode: AccessibilityNodeInfo?): Boolean {
        if (rootNode == null) return false

        val queue = java.util.ArrayDeque<Pair<AccessibilityNodeInfo, Int>>()
        return try {
            val rootBounds = Rect()
            rootNode.getBoundsInScreen(rootBounds)
            if (rootBounds.width() <= 0 || rootBounds.height() <= 0) {
                return false
            }
            val rootArea = rootBounds.width().toLong() * rootBounds.height().toLong()

            var hasDominantSurface = false
            var controlCount = 0
            var visited = 0

            queue.addLast(rootNode to 0)
            while (queue.isNotEmpty() && visited < MAX_A11Y_NODES) {
                val (node, depth) = queue.removeFirst()
                val isRoot = (node === rootNode)
                try {
                    visited++
                    if (!isRoot && !node.isVisibleToUser) {
                        continue
                    }

                    val cls = node.className?.toString() ?: ""
                    if (cls.contains("EditText") || cls.contains("SeekBar")) {
                        return false
                    }

                    val isSurface = cls == "android.view.SurfaceView" ||
                        cls == "android.opengl.GLSurfaceView" ||
                        cls.endsWith(".SurfaceView") ||
                        cls.endsWith(".GLSurfaceView")

                    if (isSurface) {
                        val bounds = Rect()
                        node.getBoundsInScreen(bounds)
                        if (bounds.width() > 0 && bounds.height() > 0) {
                            val area = bounds.width().toLong() * bounds.height().toLong()
                            if (area * 100L >= rootArea * 75L) {
                                hasDominantSurface = true
                            }
                        }
                    } else {
                        val isContainer = cls.endsWith("Layout") || cls.endsWith("ViewGroup")
                        val hasLabel = !node.text.isNullOrBlank() ||
                            (!node.contentDescription.isNullOrBlank() && (!isContainer || node.isClickable))
                        val isInteractiveWidget = (cls.contains("Button") ||
                            cls.contains("TextView") ||
                            cls.contains("CheckBox") ||
                            cls.contains("Switch") ||
                            cls.contains("RadioButton")) && node.isClickable

                        if (hasLabel || isInteractiveWidget) {
                            controlCount++
                            if (controlCount > 2) {
                                return false
                            }
                        }
                    }

                    if (depth < MAX_A11Y_DEPTH && visited < MAX_A11Y_NODES) {
                        val count = node.childCount
                        for (i in 0 until count) {
                            val child = node.getChild(i) ?: continue
                            if (visited + queue.size < MAX_A11Y_NODES) {
                                queue.addLast(child to (depth + 1))
                            } else {
                                child.recycle()
                            }
                        }
                    }
                } finally {
                    if (!isRoot) {
                        node.recycle()
                    }
                }
            }
            hasDominantSurface && controlCount <= 2
        } catch (_: Exception) {
            false
        } finally {
            while (queue.isNotEmpty()) {
                val (remaining, _) = queue.removeFirst()
                if (remaining !== rootNode) {
                    try {
                        remaining.recycle()
                    } catch (_: Exception) {}
                }
            }
        }
    }

    fun isPackageGame(
        context: Context,
        packageName: String,
        rootNode: AccessibilityNodeInfo? = null,
        prefs: AppPreferences? = null
    ): Boolean {
        // Tier 0 (pre-check): Self, system blacklist, Invariant 6 banking/UPI/2FA, browsers, social/video
        if (packageName.isBlank() ||
            packageName == context.packageName ||
            isSystemIgnoredPackage(packageName) ||
            isPaymentOrBankingApp(packageName) ||
            isBrowserPackage(packageName) ||
            SOCIAL_AND_VIDEO_PACKAGES.contains(packageName)
        ) {
            return false
        }

        val pm = context.packageManager
        val now = System.currentTimeMillis()
        var cached = staticCache[packageName]

        if (cached != null) {
            if (cached.confirmedGame) return true
            if (cached.confirmedNonGame) return false

            // Fresh-install window: re-query Tier 1 periodically to catch async Play Store category hints
            if (now - cached.firstInstallTime < FRESH_INSTALL_GRACE_MS &&
                now - cached.lastTier1CheckMs >= TIER1_RECHECK_INTERVAL_MS
            ) {
                cached.lastTier1CheckMs = now
                val freshAppInfo = getApplicationInfoCompat(pm, packageName, 0)
                if (freshAppInfo != null && isApplicationGame(freshAppInfo)) {
                    staticCache[packageName] = cached.copy(confirmedGame = true)
                    return true
                }
            }
        } else {
            val analyzed = analyzePackageStatic(pm, packageName, now) ?: return false
            if (analyzed.confirmedGame) {
                staticCache[packageName] = analyzed
                return true
            }
            if (analyzed.confirmedNonGame) {
                staticCache[packageName] = analyzed
                return false
            }
            staticCache[packageName] = analyzed
            cached = analyzed
        }

        // Tier 4: Fused Play Store correlation + manifest + live Accessibility canvas corroboration (score >= 2)
        val lastPlayTs = prefs?.lastPlayStoreInstallTimestamp ?: 0L
        val isRecentPlayInstall = cached.isFromPlayStore && (
            (now - cached.firstInstallTime) < PLAY_INSTALL_WINDOW_MS ||
                (lastPlayTs > 0L && abs(cached.firstInstallTime - lastPlayTs) < PLAY_SESSION_CORRELATION_MS)
            )

        var score = 0
        if (isRecentPlayInstall) score++
        if (cached.hasNativeOrLandscape && !cached.hasCameraPermission) score++
        if (cached.hasTier4DomainSignal) score++

        // Only traverse live Accessibility tree when at least 1 other signal is present (max score gain is +1)
        if (score >= 1 &&
            !cached.hasCameraPermission &&
            rootNode != null &&
            rootNode.packageName?.toString() == packageName &&
            isLiveGameAccessibilityTree(rootNode)
        ) {
            score++
        }

        if (score >= 2) {
            staticCache[packageName] = cached.copy(confirmedGame = true)
            Log.i(TAG, "Tier 4 multi-signal game match for $packageName (score=$score)")
            return true
        }

        // Only finalize negative cache once past fresh-install grace window and no dormant static candidate signals exist
        if (now - cached.firstInstallTime >= FRESH_INSTALL_GRACE_MS &&
            !isRecentPlayInstall &&
            !cached.hasNativeOrLandscape &&
            !cached.hasTier4DomainSignal
        ) {
            staticCache[packageName] = cached.copy(confirmedNonGame = true)
        }

        return false
    }

    fun syncAllInstalledGames(context: Context, prefs: AppPreferences): Int {
        if (!prefs.isAutoRestrictGamesEnabled) return 0
        return try {
            val pm = context.packageManager
            val launcherIntents = listOf(
                Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER),
                Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LEANBACK_LAUNCHER)
            )
            val seenPackages = HashSet<String>()
            val detectedGames = mutableSetOf<String>()

            for (intent in launcherIntents) {
                val resolveInfos = queryIntentActivitiesCompat(pm, intent, 0)
                for (info in resolveInfos) {
                    val pkg = info.activityInfo?.packageName ?: continue
                    if (!seenPackages.add(pkg)) continue
                    if (isPackageGame(context, pkg, null, prefs)) {
                        detectedGames.add(pkg)
                    }
                }
            }

            val added = prefs.autoRestrictGamesBatch(detectedGames)
            if (added > 0) {
                Log.d(TAG, "Auto-restricted $added installed game(s) into Kids/Study Zone list")
            }
            added
        } catch (e: Exception) {
            Log.e(TAG, "Error syncing installed games: ${e.message}")
            0
        }
    }

    fun syncAndCheckRestricted(
        context: Context,
        prefs: AppPreferences,
        packageName: String,
        rootNode: AccessibilityNodeInfo? = null
    ): Boolean {
        // Invariant 6 & Safety Shield: never treat payment/banking, system, or browser apps as restricted games
        if (packageName.isBlank() ||
            packageName == context.packageName ||
            isSystemIgnoredPackage(packageName) ||
            isPaymentOrBankingApp(packageName) ||
            isBrowserPackage(packageName)
        ) {
            return false
        }
        if (prefs.restrictedApps.contains(packageName)) {
            return true
        }
        if (!prefs.isAutoRestrictGamesEnabled || prefs.exemptedGames.contains(packageName)) {
            return false
        }
        if (isPackageGame(context, packageName, rootNode, prefs)) {
            val added = prefs.autoRestrictGameIfEligible(packageName, true)
            if (added) {
                Log.i(TAG, "Runtime fallback auto-restricted newly detected game: $packageName")
            }
            return prefs.restrictedApps.contains(packageName)
        }
        return false
    }

    private fun analyzePackageStatic(pm: PackageManager, pkg: String, now: Long): StaticAnalysis? {
        val flags = PackageManager.GET_META_DATA or
            PackageManager.GET_ACTIVITIES or
            PackageManager.GET_CONFIGURATIONS or
            PackageManager.GET_PERMISSIONS
        val pkgInfo = getPackageInfoCompat(pm, pkg, flags) ?: return null
        val appInfo = pkgInfo.applicationInfo ?: return null
        val versionCode = getLongVersionCodeCompat(pkgInfo)
        val firstInstallTime = pkgInfo.firstInstallTime

        // Tier 1: Official Android game category or legacy FLAG_IS_GAME
        if (isApplicationGame(appInfo)) {
            return StaticAnalysis(
                versionCode = versionCode,
                firstInstallTime = firstInstallTime,
                confirmedGame = true,
                confirmedNonGame = false,
                isFromPlayStore = false,
                hasCameraPermission = false,
                hasNativeOrLandscape = false,
                hasTier4DomainSignal = false,
                lastTier1CheckMs = now
            )
        }

        // Tier 0 (heuristic guard): never run heuristics on explicit non-game OS categories, system apps, or known study/OEM packages
        if (isExplicitNonGameCategory(appInfo) ||
            (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0 ||
            isHeuristicExemptPackage(pkg)
        ) {
            return StaticAnalysis(
                versionCode = versionCode,
                firstInstallTime = firstInstallTime,
                confirmedGame = false,
                confirmedNonGame = true,
                isFromPlayStore = false,
                hasCameraPermission = false,
                hasNativeOrLandscape = false,
                hasTier4DomainSignal = false,
                lastTier1CheckMs = now
            )
        }

        val appMeta = appInfo.metaData
        val launcherInfo = resolveLauncherActivity(pm, pkg)
        val launcherActivityInfo = launcherInfo?.activityInfo
        val launcherName = launcherActivityInfo?.name
        val launcherMeta = launcherActivityInfo?.metaData
        val declaredActivities = pkgInfo.activities ?: emptyArray()

        // Tier 2A: High-precision manifest metadata & gamepad hardware feature
        val hasPlayGamesMeta = hasAnyMetaKey(appMeta, "com.google.android.gms.games.APP_ID", "com.google.android.gms.games.unityVersion")
        val hasUnrealMeta = hasMetaPrefix(appMeta, "com.epicgames.ue4.", "com.epicgames.unreal.")
        val hasGamepadFeature = pkgInfo.reqFeatures?.any { it.name == "android.hardware.gamepad" } == true

        // Tier 2B: Engine entry-point activities (Unity checked specifically on MAIN/LAUNCHER to exclude UAAL non-game host apps)
        val isLauncherUnity = (launcherName != null && UNITY_LAUNCHER_ACTIVITIES.contains(launcherName)) ||
            launcherMeta?.getBoolean("unityplayer.UnityActivity", false) == true
        val hasEngineActivity = (launcherName != null && GAME_ENGINE_ACTIVITIES.contains(launcherName)) ||
            declaredActivities.any { GAME_ENGINE_ACTIVITIES.contains(it.name) }

        if (hasPlayGamesMeta || hasUnrealMeta || hasGamepadFeature || isLauncherUnity || hasEngineActivity) {
            return StaticAnalysis(
                versionCode = versionCode,
                firstInstallTime = firstInstallTime,
                confirmedGame = true,
                confirmedNonGame = false,
                isFromPlayStore = false,
                hasCameraPermission = false,
                hasNativeOrLandscape = false,
                hasTier4DomainSignal = false,
                lastTier1CheckMs = now
            )
        }

        // Tier 3: APK ZIP central directory native .so fingerprinting (+ nativeLibraryDir fallback)
        val apkScan = inspectApkNativeLibs(appInfo)
        val hasUnityBuildId = hasAnyMetaKey(appMeta, "unity.build-id", "unity.splash-mode", "unity.launch-fullscreen")
        val hasUnityAds = hasMetaOrActivityPrefix(appMeta, declaredActivities, "com.unity3d.services.ads", "com.unity3d.ads")
        val isLauncherLandscape = isLandscapeOrientation(launcherActivityInfo?.screenOrientation)
        val isContextualUnityGame = (apkScan.hasUnitySo || (apkScan.hasIl2CppSo && apkScan.hasUnityAssets)) &&
            !apkScan.hasNonGameFrameworkSo &&
            apkScan.hasUnityAssets &&
            hasUnityBuildId &&
            (declaredActivities.size <= 8 || isLauncherLandscape || hasUnityAds)

        if (apkScan.hasUnambiguousGameSo || isContextualUnityGame) {
            return StaticAnalysis(
                versionCode = versionCode,
                firstInstallTime = firstInstallTime,
                confirmedGame = true,
                confirmedNonGame = false,
                isFromPlayStore = false,
                hasCameraPermission = false,
                hasNativeOrLandscape = false,
                hasTier4DomainSignal = false,
                lastTier1CheckMs = now
            )
        }

        // Tier 4 feature extraction for multi-signal corroboration
        val isFromPlayStore = isInstalledFromPlayStore(pm, pkg)
        val hasCameraPermission = pkgInfo.requestedPermissions?.contains(Manifest.permission.CAMERA) == true
        val hasNativeActivity = launcherName == "android.app.NativeActivity" ||
            declaredActivities.any { it.name == "android.app.NativeActivity" }
        val hasNativeOrLandscape = hasNativeActivity || isLauncherLandscape

        val hasLibNameMeta = hasAnyMetaKey(appMeta, "android.app.lib_name") ||
            launcherMeta?.containsKey("android.app.lib_name") == true
        val hasTier4DomainSignal = apkScan.hasGameMiddlewareSo ||
            hasUnityAds ||
            (hasLibNameMeta && !apkScan.hasNonGameFrameworkSo) ||
            (apkScan.hasUnitySo && !apkScan.hasNonGameFrameworkSo)

        return StaticAnalysis(
            versionCode = versionCode,
            firstInstallTime = firstInstallTime,
            confirmedGame = false,
            confirmedNonGame = false,
            isFromPlayStore = isFromPlayStore,
            hasCameraPermission = hasCameraPermission,
            hasNativeOrLandscape = hasNativeOrLandscape,
            hasTier4DomainSignal = hasTier4DomainSignal,
            lastTier1CheckMs = now
        )
    }

    private fun inspectApkNativeLibs(appInfo: ApplicationInfo): ApkScanResult {
        var hasUnambiguous = false
        var hasUnity = false
        var hasIl2Cpp = false
        var hasUnityAssets = false
        var hasNonGameFramework = false
        var hasGameMiddleware = false
        var foundAnySo = false

        fun classifySoName(rawName: String) {
            foundAnySo = true
            val soName = rawName.lowercase(Locale.US)
            if (NON_GAME_FRAMEWORK_SO.contains(soName)) {
                hasNonGameFramework = true
            }
            if (UNAMBIGUOUS_GAME_SO.contains(soName) ||
                soName.startsWith("libcocos2d") ||
                soName.startsWith("libgodot") ||
                soName.startsWith("libunreal")
            ) {
                hasUnambiguous = true
            }
            if (soName == "libunity.so") {
                hasUnity = true
            }
            if (soName == "libil2cpp.so") {
                hasIl2Cpp = true
            }
            if (soName.startsWith("libfmod") || soName == "libbox2d.so") {
                hasGameMiddleware = true
            }
        }

        val apkPaths = LinkedHashSet<String>()
        appInfo.publicSourceDir?.let { apkPaths.add(it) }
        appInfo.sourceDir?.let { apkPaths.add(it) }
        appInfo.splitSourceDirs?.let { apkPaths.addAll(it) }

        for (apkPath in apkPaths) {
            try {
                ZipFile(apkPath).use { zip ->
                    val entries = zip.entries()
                    while (entries.hasMoreElements()) {
                        val name = entries.nextElement().name
                        if (name.startsWith("lib/") && name.endsWith(".so")) {
                            classifySoName(name.substringAfterLast('/'))
                        } else if (!hasUnityAssets &&
                            (name == "assets/bin/Data/globalgamemanagers" || name == "assets/bin/Data/data.unity3d")
                        ) {
                            hasUnityAssets = true
                        }
                    }
                }
            } catch (_: Exception) {
                // Ignore restricted/inaccessible split paths and fallback below
            }
        }

        if (!foundAnySo && !appInfo.nativeLibraryDir.isNullOrBlank()) {
            try {
                val files = File(appInfo.nativeLibraryDir).listFiles()
                if (files != null) {
                    for (file in files) {
                        if (file.name.endsWith(".so", ignoreCase = true)) {
                            classifySoName(file.name)
                        }
                    }
                }
            } catch (_: Exception) {}
        }

        return ApkScanResult(
            hasUnambiguousGameSo = hasUnambiguous,
            hasUnitySo = hasUnity,
            hasIl2CppSo = hasIl2Cpp,
            hasUnityAssets = hasUnityAssets,
            hasNonGameFrameworkSo = hasNonGameFramework,
            hasGameMiddlewareSo = hasGameMiddleware
        )
    }

    private fun isExplicitNonGameCategory(appInfo: ApplicationInfo): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return appInfo.category != ApplicationInfo.CATEGORY_UNDEFINED &&
            appInfo.category != ApplicationInfo.CATEGORY_GAME
    }

    private fun isHeuristicExemptPackage(pkg: String): Boolean {
        if (HEURISTIC_EXEMPT_PACKAGES.contains(pkg)) return true
        return HEURISTIC_EXEMPT_PREFIXES.any { pkg.startsWith(it) }
    }

    private fun isLandscapeOrientation(orientation: Int?): Boolean {
        return orientation == ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE ||
            orientation == ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE ||
            orientation == ActivityInfo.SCREEN_ORIENTATION_USER_LANDSCAPE ||
            orientation == ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
    }

    private fun hasAnyMetaKey(meta: Bundle?, vararg keys: String): Boolean {
        if (meta == null) return false
        return keys.any { meta.containsKey(it) }
    }

    private fun hasMetaPrefix(meta: Bundle?, vararg prefixes: String): Boolean {
        if (meta == null) return false
        for (key in meta.keySet()) {
            if (prefixes.any { key.startsWith(it) }) return true
        }
        return false
    }

    private fun hasMetaOrActivityPrefix(
        meta: Bundle?,
        activities: Array<ActivityInfo>,
        vararg prefixes: String
    ): Boolean {
        if (hasMetaPrefix(meta, *prefixes)) return true
        return activities.any { act -> prefixes.any { act.name.startsWith(it) } }
    }

    private fun isInstalledFromPlayStore(pm: PackageManager, pkg: String): Boolean {
        return try {
            val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                pm.getInstallSourceInfo(pkg).installingPackageName
            } else {
                @Suppress("DEPRECATION")
                pm.getInstallerPackageName(pkg)
            }
            installer == PLAY_STORE_PACKAGE
        } catch (_: Exception) {
            false
        }
    }

    private fun resolveLauncherActivity(pm: PackageManager, pkg: String): ResolveInfo? {
        val categories = listOf(Intent.CATEGORY_LAUNCHER, Intent.CATEGORY_LEANBACK_LAUNCHER)
        for (category in categories) {
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(category)
                setPackage(pkg)
            }
            val resolved = resolveActivityCompat(pm, intent, PackageManager.GET_META_DATA)
            if (resolved != null) return resolved
        }
        return null
    }

    private fun getApplicationInfoCompat(pm: PackageManager, pkg: String, flags: Int): ApplicationInfo? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getApplicationInfo(pkg, PackageManager.ApplicationInfoFlags.of(flags.toLong()))
            } else {
                @Suppress("DEPRECATION")
                pm.getApplicationInfo(pkg, flags)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun getPackageInfoCompat(pm: PackageManager, pkg: String, flags: Int): PackageInfo? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(flags.toLong()))
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(pkg, flags)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun queryIntentActivitiesCompat(pm: PackageManager, intent: Intent, flags: Int): List<ResolveInfo> {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(flags.toLong()))
            } else {
                @Suppress("DEPRECATION")
                pm.queryIntentActivities(intent, flags)
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun resolveActivityCompat(pm: PackageManager, intent: Intent, flags: Int): ResolveInfo? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.resolveActivity(intent, PackageManager.ResolveInfoFlags.of(flags.toLong()))
            } else {
                @Suppress("DEPRECATION")
                pm.resolveActivity(intent, flags)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun getLongVersionCodeCompat(pkgInfo: PackageInfo): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            pkgInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            pkgInfo.versionCode.toLong()
        }
    }
}

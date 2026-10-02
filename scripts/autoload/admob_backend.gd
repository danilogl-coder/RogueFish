extends Node
## Android rewarded ads. The Ads autoload owns limits and grants rewards.

const TEST_UNIT: String = "ca-app-pub-3940256099942544/5224354917"
const LIVE_UNIT: String = "ca-app-pub-4135973528608195/2395735562"
const RETRY_SECONDS: float = 30.0

var _ad: RewardedAd = null
var _loading: bool = false
var _started: bool = false
var _showing: bool = false
var _pending_done: Callable = Callable()
var _consent_retry_pending: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() != "Android":
		return
	if (
		not Engine.has_singleton("PoingGodotAdMob")
		or not Engine.has_singleton("PoingGodotAdMobRewardedAd")
		or not Engine.has_singleton("PoingGodotAdMobConsentInformation")
		or not Engine.has_singleton("PoingGodotAdMobUserMessagingPlatform")
	):
		push_error("AdMob native Android plugin is missing from this Gradle build")
		return
	_update_consent()


func _update_consent() -> void:
	var request: ConsentRequestParameters = ConsentRequestParameters.new()
	request.tag_for_under_age_of_consent = false
	UserMessagingPlatform.consent_information.update(request, _on_consent_updated, _on_consent_error)


func _on_consent_updated() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_form_loaded, _on_consent_error)
	else:
		_start_if_allowed()
		if not _started:
			_retry_consent()


func _on_form_loaded(form: ConsentForm) -> void:
	var info: ConsentInformation = UserMessagingPlatform.consent_information
	if info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
		form.show(_on_form_dismissed)
	else:
		_start_if_allowed()
		if not _started:
			_retry_consent()


func _on_form_dismissed(error: FormError) -> void:
	if error != null:
		push_warning("AdMob consent form: " + error.message)
	_start_if_allowed()
	if not _started:
		_retry_consent()


func _on_consent_error(error: FormError) -> void:
	push_warning("AdMob consent: " + error.message)
	_start_if_allowed()
	if not _started:
		_retry_consent()


func _retry_consent() -> void:
	if _consent_retry_pending or _started:
		return
	_consent_retry_pending = true
	await get_tree().create_timer(RETRY_SECONDS, true).timeout
	_consent_retry_pending = false
	if is_inside_tree() and not _started:
		_update_consent()


func _start_if_allowed() -> void:
	if _started:
		return
	var status: int = UserMessagingPlatform.consent_information.get_consent_status()
	if status != ConsentInformation.ConsentStatus.NOT_REQUIRED and status != ConsentInformation.ConsentStatus.OBTAINED:
		return
	_started = true
	MobileAds.initialize()
	Ads.set_backend(self)
	_load()


func is_ready() -> bool:
	return _ad != null and not _showing


func _unit_id() -> String:
	return TEST_UNIT if OS.is_debug_build() or OS.has_feature("admob_test_ads") else LIVE_UNIT


func _load() -> void:
	if not _started or _loading or _ad != null or _showing:
		return
	_loading = true
	var callback: RewardedAdLoadCallback = RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		_loading = false
		_ad = ad
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_loading = false
		push_warning("AdMob rewarded load failed: " + error.message)
		_retry_load()
	var loader: RewardedAdLoader = RewardedAdLoader.new()
	loader.load(_unit_id(), AdRequest.new(), callback)


func _retry_load() -> void:
	await get_tree().create_timer(RETRY_SECONDS, true).timeout
	_load()


## Called by Ads.show_rewarded(). Only the native earned-reward callback succeeds.
func show_rewarded(_placement: String, on_done: Callable) -> void:
	if not is_ready():
		on_done.call(false)
		_load()
		return
	_showing = true
	_pending_done = on_done
	var ad: RewardedAd = _ad
	_ad = null
	var callbacks: FullScreenContentCallback = FullScreenContentCallback.new()
	callbacks.on_ad_dismissed_full_screen_content = func() -> void:
		_finish(ad)
	callbacks.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
		push_warning("AdMob rewarded show failed: " + error.message)
		_finish(ad)
	ad.full_screen_content_callback = callbacks
	var listener: OnUserEarnedRewardListener = OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		if _pending_done.is_valid():
			var done: Callable = _pending_done
			_pending_done = Callable()
			done.call(true)
	ad.show(listener)


func _finish(ad: RewardedAd) -> void:
	if not _showing:
		return
	_showing = false
	ad.destroy()
	if _pending_done.is_valid():
		var done: Callable = _pending_done
		_pending_done = Callable()
		done.call(false)
	_load()

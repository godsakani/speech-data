import 'package:get/get.dart';

import '../../domain/entities/speech_item.dart';
import '../../domain/entities/speech_stats.dart';
import '../../data/repositories/audio_repository.dart';

class DashboardController extends GetxController {
  DashboardController() : _repo = Get.find<AudioRepository>();

  final AudioRepository _repo;

  // Tab index: 0 = Home, 1 = Record, 2 = Recordings (list)
  final RxInt currentTabIndex = 0.obs;

  // List tab
  final RxList<SpeechItem> items = <SpeechItem>[].obs;
  final RxInt total = 0.obs;
  final RxInt page = 1.obs;
  static const int limit = 20;

  final RxBool loading = true.obs;
  final RxBool loadingMore = false.obs;
  final RxString error = ''.obs;

  // Home (progress) tab
  final Rxn<SpeechStats> stats = Rxn<SpeechStats>();
  final RxBool statsLoading = true.obs;

  bool get hasMore => (page.value * limit) < total.value;

  @override
  void onReady() {
    loadStats();
    load();
    super.onReady();
  }

  Future<void> loadStats() async {
    statsLoading.value = true;
    try {
      final s = await _repo.getStats();
      stats.value = s;
    } catch (_) {
      stats.value = null;
    } finally {
      statsLoading.value = false;
    }
  }

  Future<void> load({bool append = false}) async {
    if (append) {
      loadingMore.value = true;
    } else {
      loading.value = true;
      page.value = 1;
      items.clear();
    }
    error.value = '';
    try {
      final result = await _repo.getList(page: page.value, limit: limit);
      if (append) {
        items.addAll(result.items);
      } else {
        items.assignAll(result.items);
      }
      total.value = result.total;
      await loadStats();
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
      loadingMore.value = false;
    }
  }

  void loadMore() {
    if (loadingMore.value || loading.value) return;
    if (!hasMore) return;
    page.value++;
    load(append: true);
  }

  void setTab(int index) {
    currentTabIndex.value = index;
    if (index == 0) {
      loadStats();
    } else if (index == 1 && items.isEmpty) {
      load();
    }
  }
}

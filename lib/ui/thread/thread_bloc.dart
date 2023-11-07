import 'package:code/data/_shared_prefs.dart';
import 'package:code/data/api/remote/result.dart';
import 'package:code/data/in_memory_data.dart';
import 'package:code/domain/channel/channel_model.dart';
import 'package:code/domain/message/message_model.dart';
import 'package:code/domain/thread/i_thread_repository.dart';
import 'package:code/domain/thread/thread_model.dart';
import 'package:code/domain/user/user_model.dart';
import 'package:code/ui/_base/bloc_base.dart';
import 'package:code/ui/_base/bloc_error_handler.dart';
import 'package:code/ui/_base/bloc_loading.dart';
import 'package:collection/collection.dart';
import 'package:rxdart/subjects.dart';
import 'package:code/utils/extensions.dart';

enum ThreadMenu { markAll, unfollowAll }

class ThreadBloC extends BaseBloC with LoadingBloC, ErrorHandlerBloC {
  final IThreadRepository _iThreadRepository;
  final InMemoryData _inMemoryData;
  final SharedPreferencesManager _prefs;

  ThreadBloC(this._iThreadRepository, this._inMemoryData, this._prefs);

  @override
  void dispose() {
    _threadsController.close();
    disposeLoadingBloC();
    disposeErrorHandlerBloC();
  }

  final BehaviorSubject<List<ThreadModel>> _threadsController = BehaviorSubject();

  Stream<List<ThreadModel>> get threadsResult => _threadsController.stream;

  List<MemberModel> members = [];
  List<ChannelModel> channels = [];
  String currentTeamId = '';
  String currentUserId = '';

  final maxToShow = 3;
  void loadThreads() async {
    members = _inMemoryData.getMembers();
    channels = _inMemoryData.getChannels();
    isLoading = true;
    currentTeamId = await _prefs.getStringValue(_prefs.currentTeamId);
    currentUserId = await _prefs.getStringValue(_prefs.userId);
    final res = await _iThreadRepository.getThreads();
    if (res is ResultSuccess<List<ThreadModel>>) {
      res.value.sort((v1, v2) {
        {
          if(v1.tsLastReply != null && v2.tsLastReply != null) {
            return v2.tsLastReply!.compareTo(v1.tsLastReply!);
          } else if (v1.tsLastReply == null && v2.tsLastReply != null) {
            return 1;
          } else if (v1.tsLastReply != null && v2.tsLastReply == null) {
            return -1;
          }
          return 0;
        }
      });
      res.value.forEach((element) {
        element.childMessages.sort((v1, v2) {
          if(v1.ts != null && v2.ts != null) {
            return v2.ts!.compareTo(v1.ts!);
          } else if (v1.ts == null && v2.ts != null) {
            return 1;
          } else if (v1.ts != null && v2.ts == null) {
            return -1;
          }
          return 0;
        });
        List<MessageModel> selectedToShow = [];
        Iterator<MessageModel> traversal = element.childMessages.iterator;
        while(traversal.moveNext() && selectedToShow.length < maxToShow) {
          if(selectedToShow.isEmpty){
            selectedToShow.add(traversal.current);
          }else{
            selectedToShow.insert(0, traversal.current);
          }
        }
        element.childMessages = selectedToShow;
      });
      _threadsController.sinkAddSafe(res.value);
    }
    isLoading = false;
  }

  void loadThread(String pmid) async {
    final res = await _iThreadRepository.getThread(currentTeamId, pmid);
    if(res is ResultSuccess<ThreadModel>) {
      res.value.childMessages.sort((v1, v2) {
        if(v1.ts != null && v2.ts != null) {
          return v2.ts!.compareTo(v1.ts!);
        } else if (v1.ts == null && v2.ts != null) {
          return 1;
        } else if (v1.ts != null && v2.ts == null) {
          return -1;
        }
        return 0;
      });
      List<MessageModel> selectedToShow = [];
      Iterator<MessageModel> traversal = res.value.childMessages.iterator;
      while(traversal.moveNext() && selectedToShow.length < maxToShow) {
        if(selectedToShow.isEmpty){
          selectedToShow.add(traversal.current);
        }else{
          selectedToShow.insert(0, traversal.current);
        }
      }
      res.value.childMessages = selectedToShow;
      final threads = _threadsController.valueOrNull ?? [];
      threads.add(res.value);
      threads.sort((v1, v2) {
        {
          if(v1.tsLastReply != null && v2.tsLastReply != null) {
            return v2.tsLastReply!.compareTo(v1.tsLastReply!);
          } else if (v1.tsLastReply == null && v2.tsLastReply != null) {
            return 1;
          } else if (v1.tsLastReply != null && v2.tsLastReply == null) {
            return -1;
          }
          return 0;
        }
      });
      _threadsController.sinkAddSafe(threads);
    }
  }

  void onMessageArrived(MessageModel messageModel)async{
    final threads = _threadsController.valueOrNull ?? [];
    threads.forEach((element) {
      if(messageModel.threadMetaChild != null){
        if(element.pmid == messageModel.threadMetaChild?.pmid){
          element.tsLastReply = DateTime.now();
          threads.sort((v1, v2) {
            if(v1.tsLastReply != null && v2.tsLastReply != null) {
              return v2.tsLastReply!.compareTo(v1.tsLastReply!);
            } else if (v1.tsLastReply == null && v2.tsLastReply != null) {
              return 1;
            } else if (v1.tsLastReply != null && v2.tsLastReply == null) {
              return -1;
            }
            return 0;
          });
          if(element.childMessages.length == maxToShow) element.childMessages.removeAt(0);
          element.childMessages.add(messageModel);
          _threadsController.sinkAddSafe(threads);
          return;
        }
      }
    });
  }

  void removeThread(String pmid){
    List<ThreadModel> threads = _threadsController.valueOrNull ?? [];
    threads.removeWhere((element) => element.pmid == pmid);
    _threadsController.sinkAddSafe(threads);
  }

  Future<void> markAsRead(String threadId, {localOnly = false}) async {
    if(localOnly) {
      final threads = _threadsController.valueOrNull ?? [];
      final model = threads.firstWhereOrNull((element) => element.pmid == threadId);
      if(model != null) {
        model.tsLastReadByUser = DateTime.now();
        _threadsController.sinkAddSafe(threads);
      }
    } else {
      final res = await _iThreadRepository.markAsRead(currentTeamId, threadId);
      if(res is ResultSuccess<bool> && res.value){
        final threads = _threadsController.valueOrNull ?? [];
        final model = threads.firstWhereOrNull((element) => element.pmid == threadId);
        if(model != null) {
          model.tsLastReadByUser = DateTime.now();
          _threadsController.sinkAddSafe(threads);
        }
      }
    }
  }

  Future<void> unfollow(String threadId) async {
    await _iThreadRepository.unFollow(currentTeamId, threadId);
  }

  void markAsReadAll() {
    final List<Future> futures = [];
    (_threadsController.valueOrNull ?? []).forEach((element) {
      futures.add(markAsRead(element.pmid));
    });
    Future.wait(futures);
  }

  void unfollowAll() {
    final List<Future> futures = [];
    (_threadsController.valueOrNull ?? []).forEach((element) {
      futures.add(unfollow(element.pmid));
    });
    Future.wait(futures);
  }
}

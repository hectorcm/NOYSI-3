import 'package:code/data/api/remote/result.dart';
import 'package:code/domain/channel/channel_model.dart';
import 'package:code/domain/channel/i_channel_repository.dart';
import 'package:code/rtc/rtc_manager.dart';
import 'package:code/rtc/rtc_model.dart';
import 'package:code/ui/_base/bloc_base.dart';
import 'package:code/ui/_base/bloc_error_handler.dart';
import 'package:code/ui/_base/bloc_form_validator.dart';
import 'package:code/ui/_base/bloc_loading.dart';
import 'package:flutter/cupertino.dart';
import 'package:rxdart/subjects.dart';
import 'package:code/utils/extensions.dart';

import '../../_res/R.dart';
import '../../data/_shared_prefs.dart';
import '../../data/api/remote/remote_constants.dart';

class ChannelPreferencesBloC extends BaseBloC
    with LoadingBloC, ErrorHandlerBloC, FormValidatorBloC {
  final IChannelRepository _iChannelRepository;
  final SharedPreferencesManager _prefs;

  ChannelPreferencesBloC(this._iChannelRepository, this._prefs);

  @override
  void dispose() {
    _channelController.close();
    _saveButtonNotificationsController.close();
    _saveButtonGeneralController.close();
    disposeLoadingBloC();
    disposeErrorHandlerBloC();
  }

  final BehaviorSubject<ChannelModel> _channelController = BehaviorSubject();
  Stream<ChannelModel> get channelResult => _channelController.stream;

  final BehaviorSubject<int> _pageTabController = BehaviorSubject();
  Stream<int> get pageTabResult => _pageTabController.stream;

  final BehaviorSubject<bool> _saveButtonNotificationsController =
      BehaviorSubject.seeded(false);
  Stream<bool> get saveButtonNotificationsResult =>
      _saveButtonNotificationsController.stream;

  final BehaviorSubject<bool> _saveButtonGeneralController =
      BehaviorSubject.seeded(false);
  Stream<bool> get saveButtonGeneralResult =>
      _saveButtonGeneralController.stream;

  void changePageTab(int tab) => _pageTabController.sinkAddSafe(tab);

  late bool sounds;
  late bool pushesAlways;
  late bool allowEditingMessages;
  late bool allowCalls;
  late ChannelModel channelModel;
  String tid = '';

  TextEditingController nameController = TextEditingController(),
      descriptionController = TextEditingController();

  void initData(ChannelModel channelModel) async {
    channelModel.notifications ??= NotificationModel(sounds: true);
    this.channelModel = channelModel;
    tid = await _prefs.getStringValue(_prefs.currentTeamId);
    sounds = channelModel.notifications!.sounds!;
    pushesAlways = channelModel.notifications!.alwaysPush!;
    allowCalls = channelModel.callsEnabled;
    allowEditingMessages = channelModel.editMessagesEnabled;
    nameController.text = channelModel.title ?? "";
    descriptionController.text = channelModel.description;
    _channelController.sinkAddSafe(channelModel);
  }

  void setNotifications() {
   _iChannelRepository.putChannelMemberNotifications(NotificationModel(
        sounds: channelModel.notifications!.sounds, emails: false, alwaysPush: channelModel.notifications!.alwaysPush));
  }

  void updateChannelProperties() async {
    final res = await _iChannelRepository.updateChannel(
        tid,
        channelModel.id,
        nameController.text,
        descriptionController.text,
        channelModel.editMessagesEnabled,
        channelModel.callsEnabled);
    if(res is ResultError<ChannelModel> && res.code == RemoteConstants.code_conflict) {
      showErrorMessageFromString(R.string.thisNameAlreadyExist);
    }
  }

  void checkNotificationButton() {
    final check = channelModel.notifications!.alwaysPush != pushesAlways ||
        channelModel.notifications!.sounds != sounds;
    _saveButtonNotificationsController.sinkAddSafe(check);
    _channelController.sinkAddSafe(channelModel);
  }

  void checkGeneralButton() {
    _saveButtonGeneralController.sinkAddSafe(
        channelModel.title != nameController.text ||
            channelModel.description != descriptionController.text ||
    channelModel.editMessagesEnabled != allowEditingMessages ||
    channelModel.callsEnabled != allowCalls);
    _channelController.sinkAddSafe(channelModel);
  }

  void onChannelUpdated(RTCChannelUpdated model) {
    channelModel.name = model.name;
    channelModel.title = model.title;
    channelModel.description = model.description;
    channelModel.callsEnabled = model.allowCalls;
    channelModel.editMessagesEnabled = model.editingMessagesEnabled;
    allowCalls = channelModel.callsEnabled;
    allowEditingMessages = channelModel.editMessagesEnabled;
    nameController.text = channelModel.title ?? "";
    descriptionController.text = channelModel.description;
    checkGeneralButton();
  }

  void onChannelNotificationsUpdated(RTCChannelNotificationUpdated model) {
    channelModel.notifications = model.notifications;
    sounds = model.notifications!.sounds!;
    pushesAlways = model.notifications!.alwaysPush!;
    checkNotificationButton();
  }
}

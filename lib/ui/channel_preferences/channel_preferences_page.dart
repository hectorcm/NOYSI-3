import 'dart:async';

import 'package:code/_res/R.dart';
import 'package:code/domain/channel/channel_model.dart';
import 'package:code/rtc/rtc_manager.dart';
import 'package:code/ui/_base/bloc_state.dart';
import 'package:code/ui/_base/navigation_utils.dart';
import 'package:code/ui/_tx_widget/tx_button_widget.dart';
import 'package:code/ui/_tx_widget/tx_checkbox_widget.dart';
import 'package:code/ui/_tx_widget/tx_icon_button_widget.dart';
import 'package:code/ui/_tx_widget/tx_loading_widget.dart';
import 'package:code/ui/_tx_widget/tx_main_app_bar_widget.dart';
import 'package:code/ui/_tx_widget/tx_text_widget.dart';
import 'package:code/ui/channel_preferences/channel_preferences_bloc.dart';
import 'package:flutter/material.dart';

import '../_tx_widget/tx_gesture_hide_key_board.dart';
import '../_tx_widget/tx_textfield_widget.dart';

class ChannelPreferencesPage extends StatefulWidget {
  final ChannelModel channelModel;
  final bool isAdmin;

  const ChannelPreferencesPage({
    Key? key,
    required this.channelModel,
    required this.isAdmin,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ChannelPreferencesState();
}

class _ChannelPreferencesState
    extends StateWithBloC<ChannelPreferencesPage, ChannelPreferencesBloC> {
  late PageController pageController;
  final _keyForm =  GlobalKey<FormState>();
  StreamSubscription? ssNotifications, ssGeneral;

  @override
  void initState() {
    super.initState();
    bloc.initData(widget.channelModel);
    pageController = PageController(
        initialPage: !widget.channelModel.isM1x1 || widget.isAdmin ? 0 : 1);
    ssNotifications = onChannelNotificationsUpdated.listen((value) {
      if(value.tid == bloc.tid && value.cid == bloc.channelModel.id) {
        bloc.onChannelNotificationsUpdated(value);
      }
    });
    ssGeneral = onChannelUpdated.listen((value) {
      if(value.tid == bloc.tid && value.cid == bloc.channelModel.id) {
        bloc.onChannelUpdated(value);
      }
    });
  }

  @override
  void dispose() {
    ssNotifications?.cancel();
    ssGeneral?.cancel();
    super.dispose();
  }

  @override
  Widget buildWidget(BuildContext context) {
    return Stack(
      children: <Widget>[
        TXMainAppBarWidget(
          title: R.string.channelPreferences,
          leading: TXIconButtonWidget(
            icon: const Icon(
              Icons.keyboard_arrow_left,
              size: 30,
            ),
            onPressed: () {
              NavigationUtils.pop(context);
            },
          ),
          body: Column(
            children: [
              StreamBuilder<int>(
                  stream: bloc.pageTabResult,
                  initialData:
                      !widget.channelModel.isM1x1 || widget.isAdmin ? 0 : 1,
                  builder: (context, snapshotTab) {
                    return SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: Row(
                        children: [
                          _getTab(0, snapshotTab.data == 0, R.string.general),
                          _getTab(
                              1, snapshotTab.data == 1, R.string.notifications),
                        ],
                      ),
                    );
                  }),
              Expanded(
                child: StreamBuilder<ChannelModel>(
                  stream: bloc.channelResult,
                  initialData: null,
                  builder: (context, snapshot) {
                    return PageView.builder(
                        controller: pageController,
                        onPageChanged: (index) {
                          bloc.changePageTab(index);
                        },
                        itemCount: 2,
                        itemBuilder: (context, index) {
                          return snapshot.data == null
                              ? Container()
                              : index == 0
                                  ? generalPage(snapshot.data!)
                                  : notificationPage(snapshot.data!);
                        });
                  },
                ),
              )
            ],
          ),
        ),
        TXLoadingWidget(
          loadingStream: bloc.isLoadingStream,
        )
      ],
    );
  }

  Widget generalPage(ChannelModel model) {
    return widget.channelModel.isM1x1 ? Center(
      child: TXTextWidget(text: R.string.noAvailableOptions),
    ) : !widget.isAdmin
        ? SingleChildScrollView(
      padding: const EdgeInsets.only(
          bottom: 30, left: 15, right: 15, top: 20),
      child: Column(
        children: [
          Container(
            alignment: Alignment.centerLeft,
            child: TXTextWidget(
              text: R.string.channelName,
              color: R.color.blackColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 2,
          ),
          Container(
            alignment: Alignment.centerLeft,
            child: TXTextWidget(text: model.titleFixed),
          ),
          model.description.isNotEmpty ? Column(
            children: [
              const SizedBox(
                height: 15,
              ),
              Container(
                alignment: Alignment.centerLeft,
                child: TXTextWidget(
                  text: R.string.channelDescription,
                  color: R.color.blackColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 2,
              ),
              Container(
                alignment: Alignment.centerLeft,
                child: TXTextWidget(text: model.description),
              )
            ],
          ) : Container()
        ],
      ),
    )
        : TXGestureHideKeyBoard(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                  bottom: 30, left: 15, right: 15, top: 20),
              child: Form(
                key: _keyForm,
                child: Column(
                  children: [
                    Container(
                      alignment: Alignment.centerLeft,
                      child: TXTextWidget(
                        text: R.string.channelName,
                        color: R.color.blackColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    TXTextFieldWidget(
                      controller: bloc.nameController,
                      validator: bloc.alphanumericRoomName(),
                      onChanged: (text) {
                        bloc.checkGeneralButton();
                      },
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: TXTextWidget(
                        color: R.color.blackColor,
                        text: R.string.createNameWarning,
                        size: 12,
                      ),
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                    Container(
                      alignment: Alignment.centerLeft,
                      child: TXTextWidget(
                        text: R.string.channelDescription,
                        color: R.color.blackColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    TXTextFieldWidget(
                      minLines: 8,
                      maxLines: 8,
                      controller: bloc.descriptionController,
                      onChanged: (text) {
                        bloc.checkGeneralButton();
                      },
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                    TXCheckBoxWidget(
                      leading: true,
                      text: R.string.allowEditingMessages,
                      value: model.editMessagesEnabled,
                      onChange: (value) {
                        bloc.channelModel.editMessagesEnabled = value;
                        bloc.checkGeneralButton();
                      },
                    ),
                    TXCheckBoxWidget(
                      leading: true,
                      text: R.string.allowCalls,
                      value: model.callsEnabled,
                      onChange: (value) {
                        bloc.channelModel.callsEnabled = value;
                        bloc.checkGeneralButton();
                      },
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    StreamBuilder<bool>(
                        initialData: false,
                        stream: bloc.saveButtonGeneralResult,
                        builder: (context, snapshot) {
                          return TXButtonWidget(
                            mainColor: snapshot.data!
                                ? R.color.secondaryColor
                                : R.color.grayLightColor,
                            splashColor: snapshot.data!
                                ? R.color.secondaryHeaderColor
                                : R.color.grayLightColor,
                            onPressed: () {
                              WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();
                              if (snapshot.data! && _keyForm.currentState!.validate()) {
                                bloc.updateChannelProperties();
                              }
                            },
                            title: R.string.savePreferences,
                          );
                        })
                  ],
                ),
              ),
            ),
          );
  }

  Widget notificationPage(ChannelModel model) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          const SizedBox(
            height: 20,
          ),
          TXCheckBoxWidget(
            leading: true,
            text: R.string.turnOffChannelSounds,
            value: !model.notifications!.sounds!,
            onChange: (value) {
              bloc.channelModel.notifications!.sounds = !value;
              bloc.checkNotificationButton();
            },
          ),
          TXCheckBoxWidget(
            leading: true,
            text: R.string.sendAlwaysAPush,
            value: model.notifications!.alwaysPush!,
            onChange: (value) {
              bloc.channelModel.notifications!.alwaysPush = value;
              bloc.checkNotificationButton();
            },
          ),
          // SizedBox(
          //   height: 10,
          // ),
          // TXCheckBoxWidget(
          //   leading: true,
          //   text: R.string.turnOffChannelEmails,
          //   value: bloc.emails,
          //   onChange: (value) {
          //     setState(() {
          //       bloc.emails = value;
          //     });
          //   },
          // ),
          const SizedBox(
            height: 20,
          ),
          StreamBuilder<bool>(
            initialData: false,
              stream: bloc.saveButtonNotificationsResult,
              builder: (context, snapshot) {
            return TXButtonWidget(
              mainColor: snapshot.data!
                  ? R.color.secondaryColor
                  : R.color.grayLightColor,
              splashColor: snapshot.data!
                  ? R.color.secondaryHeaderColor
                  : R.color.grayLightColor,
              onPressed: () {
                WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();
                if (snapshot.data!) {
                  bloc.setNotifications();
                }
              },
              title: R.string.savePreferences,
            );
          })
        ],
      ),
    );
  }

  Widget _getTab(int tabNumber, bool isActive, String title) {
    return Expanded(
      child: InkWell(
        onTap: () {
          if (!isActive) {
            bloc.changePageTab(tabNumber);
            pageController.jumpToPage(tabNumber);
          }
        },
        child: Container(
          alignment: Alignment.center,
          height: double.infinity,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  width: isActive ? 5.0 : 1,
                  color: isActive
                      ? R.color.secondaryColor
                      : R.color.grayLightestColor),
            ),
          ),
          padding:
              const EdgeInsets.only(bottom: 10, left: 25, right: 25, top: 20),
          child: TXTextWidget(
            text: title.toUpperCase(),
            maxLines: 1,
            textOverflow: TextOverflow.ellipsis,
            fontWeight: FontWeight.normal,
            size: 16,
            color: isActive ? R.color.grayDarkestColor : R.color.grayColor,
          ),
        ),
      ),
    );
  }
}

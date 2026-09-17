// ЭЛЕРОЗ: постоянный доступ одной кнопкой.
// В исходном интерфейсе путь спрятан: «⋮» → Безопасность → разблокировать настройки
// с подтверждением Windows → переключатель → отдельное окно пароля. Без разблокировки
// переключатели молчат, и человек решает, что программа сломана.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/custom_password.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';
import 'package:get/get.dart';

const String kElerozPasswordTip =
    'Не короче 8 знаков, среди них цифра, заглавная и строчная буква.';

bool isPermanentAccessOn() =>
    gFFI.serverModel.verificationMethod == kUsePermanentPassword;

void showPermanentAccessDialog() {
  final password = TextEditingController();
  final repeat = TextEditingController();
  final rules = <ValidationRule>[
    MinCharactersValidationRule(8),
    DigitValidationRule(),
    UppercaseValidationRule(),
    LowercaseValidationRule(),
  ];
  final installed = bind.mainIsInstalled();
  var error = '';
  var busy = false;
  var done = false;
  var doneId = '';

  gFFI.dialogManager.show((setState, close, context) {
    goInstall() async {
      close();
      await rustDeskWinManager.closeAllSubWindows();
      bind.mainGotoInstall();
    }

    submit() async {
      if (busy || done || !installed) return;
      final pass = password.text.trim();
      if (rules.any((rule) => !rule.validate(pass))) {
        setState(() => error = 'Пароль не подходит. $kElerozPasswordTip');
        return;
      }
      if (repeat.text.trim() != pass) {
        setState(() => error = 'Пароли не совпадают.');
        return;
      }
      setState(() {
        error = '';
        busy = true;
      });
      if (!await callMainCheckSuperUserPermission()) {
        setState(() {
          busy = false;
          error = 'Windows не дал разрешение. Нажмите ещё раз и подтвердите запрос.';
        });
        return;
      }
      if (!await bind.mainSetPermanentPasswordWithResult(password: pass)) {
        setState(() {
          busy = false;
          error = 'Пароль сохранить не удалось. Попробуйте ещё раз.';
        });
        return;
      }
      await gFFI.serverModel.setVerificationMethod(kUsePermanentPassword);
      await gFFI.serverModel.setApproveMode('password');
      if (await mainGetBoolOption(kOptionStopService)) {
        await start_service(true);
      }
      await gFFI.serverModel.updatePasswordModel();
      setState(() {
        busy = false;
        done = true;
        doneId = gFFI.serverModel.serverId.text;
      });
    }

    turnOff() async {
      if (busy) return;
      setState(() {
        error = '';
        busy = true;
      });
      if (!await callMainCheckSuperUserPermission()) {
        setState(() {
          busy = false;
          error = 'Windows не дал разрешение. Нажмите ещё раз и подтвердите запрос.';
        });
        return;
      }
      await gFFI.serverModel.setVerificationMethod(kUseTemporaryPassword);
      await gFFI.serverModel.updatePasswordModel();
      close();
    }

    Widget text(String value, {bool bold = false}) => Text(
          value,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          ),
        );

    Widget field(String label, TextEditingController controller) => TextField(
          obscureText: true,
          controller: controller,
          autofocus: controller == password,
          onSubmitted: (_) => submit(),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        );

    late final Widget body;
    late final List<Widget> actions;

    if (!installed) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          text('Сейчас программа запущена без установки.'),
          text('Постоянный доступ работает только на установленной программе: '
                  'она запускается вместе с Windows и отвечает, когда за компьютером никого нет.')
              .marginOnly(top: 8),
        ],
      );
      actions = [
        dialogButton('Закрыть', onPressed: close, isOutline: true),
        dialogButton('Установить программу', onPressed: goInstall),
      ];
    } else if (done) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          text('Постоянный доступ включён.', bold: true),
          text('Номер этого компьютера: $doneId').marginOnly(top: 10),
          text('С другого компьютера введите этот номер, нажмите «Подключиться» '
                  'и укажите пароль, который вы задали. Подтверждать на этом компьютере ничего не нужно.')
              .marginOnly(top: 10),
          text('Запишите номер и пароль. Компьютер должен быть включён, подключён к интернету и не уходить в спящий режим.')
              .marginOnly(top: 10),
        ],
      );
      actions = [
        dialogButton('Скопировать номер', isOutline: true, onPressed: () {
          Clipboard.setData(ClipboardData(text: doneId));
          showToast('Номер скопирован');
        }),
        dialogButton('Готово', onPressed: close),
      ];
    } else {
      final on = isPermanentAccessOn();
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          text(on
              ? 'Придумайте новый пароль для подключения к этому компьютеру.'
              : 'Придумайте пароль для подключения к этому компьютеру. Это не пароль от Windows.'),
          text(kElerozPasswordTip).marginOnly(top: 4),
          field('Пароль', password).marginOnly(top: 16),
          field('Повторите пароль', repeat).marginOnly(top: 12),
          if (error.isNotEmpty)
            Text(
              error,
              style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.redAccent),
            ).marginOnly(top: 12),
          text('Windows спросит разрешение на изменение — подтвердите его.')
              .marginOnly(top: 12),
          if (on)
            TextButton(
              onPressed: busy ? null : turnOff,
              child: const Text('Выключить постоянный доступ'),
            ).marginOnly(top: 8),
        ],
      );
      actions = [
        dialogButton('Отмена', onPressed: close, isOutline: true),
        dialogButton(
          on ? 'Сохранить пароль' : 'Включить постоянный доступ',
          onPressed: busy ? null : submit,
        ),
      ];
    }

    return CustomAlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock_outline, color: MyTheme.accent),
          const Text('Постоянный доступ').paddingOnly(left: 10),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 460),
        child: body,
      ),
      actions: actions,
      onSubmit: submit,
      onCancel: close,
    );
  });
}

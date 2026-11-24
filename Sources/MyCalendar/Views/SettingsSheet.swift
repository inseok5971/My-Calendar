import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: CalendarStore
    @EnvironmentObject private var notificationManager: NotificationManager

    var body: some View {

        VStack(spacing: 0) {
            HStack {
                Text("설정")
                    .font(.headline)
                Spacer()
                Button("닫기") {
                    store.save()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            Form {
                Section("화면 테마") {
                    Picker("테마", selection: $store.settings.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: store.settings.theme) { _, newTheme in
                        AppThemeHelper.applyTheme(newTheme)
                        store.save()
                    }
                }

                Section("창 및 시작 설정") {
                    Picker("기본 창 모드", selection: $store.settings.lastWindowMode) {
                        Text("스케줄러 (큰 창)").tag(WindowDisplayMode.mainCalendar)
                        Text("미니 보드").tag(WindowDisplayMode.miniBoard)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: store.settings.lastWindowMode) { _, _ in
                        store.save()
                    }

                    Toggle("앱 실행 시 상단바 아이콘으로 조용히 시작", isOn: $store.settings.startMinimizedToMenuBar)
                        .onChange(of: store.settings.startMinimizedToMenuBar) { _, _ in
                            store.save()
                        }
                    Text("독(Dock)에는 표시되지 않으며, 창을 닫아도 상단바에 항상 상주합니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("알림 방식") {
                    Toggle("사전 알림(10분 전 등)은 상단바에만 조용히 표시", isOn: $store.settings.preReminderMenuBarOnly)
                        .onChange(of: store.settings.preReminderMenuBarOnly) { _, _ in
                            store.save()
                        }

                    Toggle("macOS 데스크톱 푸시 알림 (정각)", isOn: $store.settings.enableDesktopNotifications)
                        .onChange(of: store.settings.enableDesktopNotifications) { _, _ in
                            store.save()
                        }

                    if notificationManager.isRunningInAppBundle {
                        HStack {
                            Text("시스템 알림 권한")
                                .foregroundStyle(.secondary)
                            Spacer()
                            switch notificationManager.authorizationStatus {
                            case .authorized:
                                Label("허용됨", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            case .denied:
                                Text("거부됨 (시스템 설정에서 허용 필요)")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            default:
                                Button("권한 요청") {
                                    notificationManager.requestPermissionIfNeeded()
                                }
                                .font(.caption)
                            }
                        }
                    }

                    Toggle("앱 내 토스트 팝업", isOn: $store.settings.enableInAppToasts)
                        .onChange(of: store.settings.enableInAppToasts) { _, _ in
                            store.save()
                        }

                    Toggle("알림 사운드", isOn: $store.settings.enableSound)
                        .onChange(of: store.settings.enableSound) { _, _ in
                            store.save()
                        }

                    if store.settings.enableSound {
                        HStack {
                            Picker("사운드 종류", selection: $store.settings.soundName) {
                                ForEach(NotificationManager.availableSounds, id: \.self) { name in
                                    Text(name).tag(name)
                                }
                            }
                            .onChange(of: store.settings.soundName) { _, newValue in
                                store.save()
                                notificationManager.playSound(named: newValue)
                            }
                        }
                    }

                    Button("알림 테스트 보내기") {
                        notificationManager.sendTestNotification(settings: store.settings)
                    }
                }

                Section("오늘의 일정 요약 알림") {
                    Toggle("매일 요약 알림 받기", isOn: $store.settings.enableDailySummary)
                        .onChange(of: store.settings.enableDailySummary) { _, _ in
                            store.save()
                        }

                    if store.settings.enableDailySummary {
                        HStack {
                            Text("요약 알림 시각")
                            Spacer()
                            Picker("시", selection: $store.settings.dailySummaryHour) {
                                ForEach(0..<24, id: \.self) { h in
                                    Text(String(format: "%02d시", h)).tag(h)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 75)
                            .onChange(of: store.settings.dailySummaryHour) { _, _ in store.save() }

                            Picker("분", selection: $store.settings.dailySummaryMinute) {
                                ForEach([0, 15, 30, 45], id: \.self) { m in
                                    Text(String(format: "%02d분", m)).tag(m)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 75)
                            .onChange(of: store.settings.dailySummaryMinute) { _, _ in store.save() }
                        }
                    }
                }

                Section("🤖 AI 스마트 엔진 설정 (공모전 트랙)") {
                    TextField("Google Gemini API Key (선택 사항)", text: $store.settings.geminiApiKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: store.settings.geminiApiKey) { _, _ in
                            store.save()
                        }
                    Text("💡 API 키를 비워두셔도 내장 스마트 규칙 엔진이 100% 오프라인으로 작동합니다. Gemini 키 입력 시 고지능 자연어 파싱 및 폴더 브리핑을 지원합니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 440, height: 520)
        .preferredColorScheme(store.settings.theme.colorScheme)
        .onAppear {
            notificationManager.refreshAuthorizationStatus()
        }
    }
}

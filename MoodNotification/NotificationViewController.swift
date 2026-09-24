import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI

/// Logs from inside a long-pressed reminder, so answering a prompt never opens the app.
///
/// Health writes are blocked while the phone is locked; expanding a notification already
/// requires unlocking, so in practice the save runs with the store available.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private let model = LogEntryModel(confirmationDelay: .seconds(0.6))
    private var notificationIdentifier: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        let host = UIHostingController(rootView: NotificationLogView(model: model) { [weak self] in
            self?.finish()
        })
        host.view.backgroundColor = .clear
        host.sizingOptions = .preferredContentSize
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    override func preferredContentSizeDidChange(forChildContentContainer container: any UIContentContainer) {
        super.preferredContentSizeDidChange(forChildContentContainer: container)
        preferredContentSize = CGSize(width: view.bounds.width, height: container.preferredContentSize.height)
    }

    func didReceive(_ notification: UNNotification) {
        notificationIdentifier = notification.request.identifier
    }

    private func finish() {
        if let notificationIdentifier {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
        }
        extensionContext?.dismissNotificationContentExtension()
    }
}

private struct NotificationLogView: View {
    @Bindable var model: LogEntryModel
    var onLogged: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ValenceSlider(valence: $model.valence, horizontalHitSlop: 20)

            Button {
                Task {
                    if await model.save() { onLogged() }
                }
            } label: {
                Group {
                    switch model.phase {
                    case .saved:
                        Label("Logged", systemImage: "checkmark")
                    case .saving:
                        ProgressView()
                    default:
                        Text("Log")
                    }
                }
                .font(.system(.title3, design: .monospaced).weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(.journalInk)
            .disabled(model.phase == .saving || model.phase == .saved)

            if case .failed(let message) = model.phase {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.journalInk.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .font(.system(.body, design: .monospaced))
        .background(Color.journalBackground)
    }
}

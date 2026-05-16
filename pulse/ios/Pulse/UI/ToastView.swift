import UIKit

enum ToastTone {
    case info, ok, warn
    var borderColor: UIColor {
        switch self {
        case .info: return Theme.border
        case .ok: return Theme.ok.withAlphaComponent(0.4)
        case .warn: return Theme.danger.withAlphaComponent(0.4)
        }
    }
}

final class ToastPresenter {
    private weak var host: UIView?

    init(host: UIView) {
        self.host = host
    }

    func show(_ message: String, tone: ToastTone = .info, duration: TimeInterval = 2.4) {
        guard let host else { return }
        let label = PaddingLabel()
        label.text = message
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = Theme.text
        label.backgroundColor = Theme.backgroundElevated2
        label.layer.cornerRadius = 12
        label.layer.borderWidth = 1
        label.layer.borderColor = tone.borderColor.cgColor
        label.layer.masksToBounds = true
        label.alpha = 0
        label.transform = CGAffineTransform(translationX: 0, y: 12)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: host.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: host.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: host.trailingAnchor, constant: -16),
        ])

        UIView.animate(withDuration: 0.2) {
            label.alpha = 1
            label.transform = .identity
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            UIView.animate(withDuration: 0.2, animations: {
                label.alpha = 0
                label.transform = CGAffineTransform(translationX: 0, y: 12)
            }, completion: { _ in label.removeFromSuperview() })
        }
    }
}

private final class PaddingLabel: UILabel {
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + 32, height: s.height + 20)
    }
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.insetBy(dx: 16, dy: 10))
    }
}

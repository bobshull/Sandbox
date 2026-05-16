import UIKit

final class VolumePopoverViewController: UIViewController {

    var onChange: ((Float) -> Void)?

    private let track: Track
    private var currentValue: Float

    private let panel = UIView()
    private let nameLabel = UILabel()
    private let percentLabel = UILabel()
    private let slider = UISlider()

    init(track: Track, value: Float) {
        self.track = track
        self.currentValue = value
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.35)

        // Tap background to dismiss — sits behind the panel
        let bg = UIButton(type: .custom)
        bg.frame = view.bounds
        bg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        bg.addTarget(self, action: #selector(dismissOverlay), for: .touchUpInside)
        view.addSubview(bg)

        // Panel
        panel.backgroundColor = Theme.backgroundElevated2
        panel.layer.cornerRadius = 14
        panel.layer.borderWidth = 1.5
        panel.layer.borderColor = track.color.withAlphaComponent(0.75).cgColor
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)   // above bg button

        nameLabel.text = track.name
        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = track.color
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(nameLabel)

        percentLabel.text = format(currentValue)
        percentLabel.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        percentLabel.textColor = Theme.text
        percentLabel.textAlignment = .right
        percentLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(percentLabel)

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = Theme.textFaint
        closeButton.addTarget(self, action: #selector(dismissOverlay), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(closeButton)

        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = currentValue
        slider.minimumTrackTintColor = track.color
        slider.maximumTrackTintColor = Theme.border
        slider.thumbTintColor = Theme.text
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        slider.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(slider)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: 380),

            nameLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 18),

            percentLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            percentLabel.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            percentLabel.widthAnchor.constraint(equalToConstant: 54),

            closeButton.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),

            slider.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 14),
            slider.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            slider.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            slider.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16),
        ])
    }

    @objc private func dismissOverlay() { dismiss(animated: true) }

    @objc private func sliderChanged() {
        currentValue = slider.value
        percentLabel.text = format(currentValue)
        onChange?(currentValue)
    }

    private func format(_ v: Float) -> String { "\(Int((v * 100).rounded()))%" }
}

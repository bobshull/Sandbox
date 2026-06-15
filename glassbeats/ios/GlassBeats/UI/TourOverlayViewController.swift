import UIKit

struct TourStep {
    let title: String
    let message: String
    let padding: UIEdgeInsets
    let targetFrames: () -> [CGRect]

    init(title: String, message: String, padding: UIEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12), targetFrame: @escaping () -> CGRect) {
        self.title = title
        self.message = message
        self.padding = padding
        self.targetFrames = { [targetFrame] in [targetFrame()] }
    }

    init(title: String, message: String, padding: UIEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12), targetFrames: @escaping () -> [CGRect]) {
        self.title = title
        self.message = message
        self.padding = padding
        self.targetFrames = targetFrames
    }
}

final class TourOverlayViewController: UIViewController {

    var onFinish: (() -> Void)?

    private let steps: [TourStep]
    private var index = 0

    private let dimLayer = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()
    private let bubble = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let countLabel = UILabel()
    private let skipButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private var bubbleTopConstraint: NSLayoutConstraint?
    private var bubbleLeadingConstraint: NSLayoutConstraint?
    private var bubbleWidthConstraint: NSLayoutConstraint?

    init(steps: [TourStep]) {
        self.steps = steps
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        configureLayers()
        configureBubble()
        syncStep()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutOverlay(animated: false)
    }

    private func configureLayers() {
        dimLayer.fillRule = .evenOdd
        dimLayer.fillColor = UIColor.black.withAlphaComponent(0.72).cgColor
        view.layer.addSublayer(dimLayer)

        highlightLayer.fillColor = UIColor.clear.cgColor
        highlightLayer.strokeColor = ColorTheme.current.primaryColor.cgColor
        highlightLayer.lineWidth = 2
        view.layer.addSublayer(highlightLayer)
    }

    private func configureBubble() {
        bubble.backgroundColor = Theme.backgroundElevated2
        bubble.layer.cornerRadius = 8
        bubble.layer.borderWidth = 1.5
        bubble.layer.borderColor = ColorTheme.current.primaryColor.withAlphaComponent(0.75).cgColor
        bubble.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bubble)

        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = Theme.text
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        messageLabel.font = .systemFont(ofSize: 14, weight: .regular)
        messageLabel.textColor = Theme.textDim
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        countLabel.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        countLabel.textColor = Theme.textFaint
        countLabel.setContentHuggingPriority(.required, for: .horizontal)

        configureButton(skipButton, title: "Skip", filled: false)
        configureButton(nextButton, title: "Next", filled: true)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        skipButton.setContentHuggingPriority(.required, for: .horizontal)
        nextButton.setContentHuggingPriority(.required, for: .horizontal)

        let buttonRow = UIStackView(arrangedSubviews: [countLabel, UIView(), skipButton, nextButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 10
        buttonRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, buttonRow])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(stack)

        let top = bubble.topAnchor.constraint(equalTo: view.topAnchor, constant: 0)
        let leading = bubble.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0)
        let width = bubble.widthAnchor.constraint(equalToConstant: 360)
        bubbleTopConstraint = top
        bubbleLeadingConstraint = leading
        bubbleWidthConstraint = width

        NSLayoutConstraint.activate([
            top,
            leading,
            width,
            stack.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -14),
            skipButton.heightAnchor.constraint(equalToConstant: 34),
            nextButton.heightAnchor.constraint(equalToConstant: 34),
            skipButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 64),
            nextButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 78),
        ])
    }

    private func configureButton(_ button: UIButton, title: String, filled: Bool) {
        var cfg = UIButton.Configuration.plain()
        cfg.title = title
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var out = attrs
            out.font = .systemFont(ofSize: 13, weight: .semibold)
            return out
        }
        cfg.baseForegroundColor = filled ? UIColor(white: 0.1, alpha: 1) : Theme.text
        cfg.background.backgroundColor = filled ? ColorTheme.current.primaryColor : Theme.backgroundElevated
        cfg.background.strokeColor = filled ? .clear : Theme.border
        cfg.background.strokeWidth = filled ? 0 : 1
        cfg.background.cornerRadius = 6
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)
        button.configuration = cfg
    }

    private func syncStep() {
        guard steps.indices.contains(index) else { return }
        titleLabel.text = steps[index].title
        messageLabel.text = steps[index].message
        countLabel.text = "\(index + 1)/\(steps.count)"
        configureButton(nextButton, title: index == steps.count - 1 ? "Done" : "Next", filled: true)
        view.setNeedsLayout()
    }

    private func layoutOverlay(animated: Bool) {
        guard isViewLoaded, steps.indices.contains(index) else { return }

        let step = steps[index]
        let targets = step.targetFrames().map { normalizedTarget($0, padding: step.padding) }
        let target = targets.reduce(CGRect.null) { $0.union($1) }
        let fullPath = UIBezierPath(rect: view.bounds)
        for target in targets {
            fullPath.append(UIBezierPath(roundedRect: target, cornerRadius: 10))
        }

        let highlightPath = UIBezierPath()
        for target in targets {
            highlightPath.append(UIBezierPath(roundedRect: target, cornerRadius: 10))
        }
        let update = {
            self.dimLayer.path = fullPath.cgPath
            self.highlightLayer.path = highlightPath.cgPath
            self.applyBubbleLayout(near: target)
        }

        if animated {
            update()
            UIView.animate(withDuration: 0.18) {
                self.view.layoutIfNeeded()
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            update()
            view.layoutIfNeeded()
            CATransaction.commit()
        }
    }

    private func normalizedTarget(_ rect: CGRect, padding: UIEdgeInsets) -> CGRect {
        guard !rect.isNull, !rect.isEmpty else {
            return safeHighlightBounds().insetBy(dx: 20, dy: 20)
        }

        let padded = CGRect(
            x: rect.minX - padding.left,
            y: rect.minY - padding.top,
            width: rect.width + padding.left + padding.right,
            height: rect.height + padding.top + padding.bottom
        )
        let bounds = safeHighlightBounds()
        let width = min(padded.width, bounds.width)
        let height = min(padded.height, bounds.height)
        let x = min(max(bounds.minX, padded.minX), bounds.maxX - width)
        let y = min(max(bounds.minY, padded.minY), bounds.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func safeHighlightBounds() -> CGRect {
        let insets = view.safeAreaInsets
        return view.bounds.inset(by: UIEdgeInsets(
            top: insets.top,
            left: insets.left + 8,
            bottom: insets.bottom + 8,
            right: insets.right + 8
        ))
    }

    private func applyBubbleLayout(near target: CGRect) {
        let width = min(view.bounds.width - 32, 430)
        bubbleWidthConstraint?.constant = width

        let measured = bubble.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let height = measured.height
        let topInset = view.safeAreaInsets.top + 12
        let bottomInset = view.bounds.height - view.safeAreaInsets.bottom - 12
        let aboveY = target.minY - height - 16
        let belowY = target.maxY + 16
        let y = aboveY >= topInset ? aboveY : min(belowY, bottomInset - height)
        let centeredX = target.midX - width / 2
        let safeBounds = safeHighlightBounds()
        let x = min(max(safeBounds.minX, centeredX), safeBounds.maxX - width)

        bubbleLeadingConstraint?.constant = x
        bubbleTopConstraint?.constant = max(topInset, y)
    }

    @objc private func skipTapped() {
        finish()
    }

    @objc private func nextTapped() {
        guard index < steps.count - 1 else {
            finish()
            return
        }
        index += 1
        syncStep()
        layoutOverlay(animated: true)
    }

    private func finish() {
        onFinish?()
        dismiss(animated: true)
    }
}
